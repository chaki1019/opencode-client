// OpenCode v2 plugin: forwards "agent finished / needs you" events to the
// opencode-client push relay, which delivers them to the phone over FCM.
//
// Install: copy this single file to ~/.config/opencode/plugins/ and add to
// ~/.config/opencode/opencode.json (the app shows this snippet with your key):
//
//   "plugins": [{
//     "package": "./plugins/opencode-push.js",
//     "options": { "relay": "https://<your-relay>", "key": "<pairing key>" }
//   }]
//
// The file has no imports on purpose: plugins load from a folder without
// node_modules, and a failed import makes OpenCode skip the plugin silently.
// Checked against @opencode/plugin 2.0.22 (event names and payloads).

const PLUGIN_ID = "opencode-push";
const DEDUPE_MS = 15_000;
const BACKOFFS_MS = [2_000, 5_000, 10_000, 30_000];

// Module-level so that several locations loading the same file in one
// process still send each event once.
const seenEvents = new Map();
const sentKeys = new Map();

function remember(map, key, now) {
  for (const [k, at] of map) {
    if (now - at > DEDUPE_MS) map.delete(k);
  }
  if (map.has(key)) return false;
  map.set(key, now);
  return true;
}

function readOptions(raw) {
  const options = raw ?? {};
  const relay = typeof options.relay === "string" ? options.relay.trim().replace(/\/+$/, "") : "";
  const key = typeof options.key === "string" ? options.key.trim() : "";
  const flag = (name) => options[name] !== false;
  return {
    relay,
    key,
    includeTitle: flag("includeTitle"),
    kinds: {
      completed: flag("notifyOnComplete"),
      failed: flag("notifyOnError"),
      permission: flag("notifyOnPermission"),
      question: flag("notifyOnQuestion"),
    },
  };
}

/** Maps a v2 event to a notification kind and its session, or null. */
function classify(event) {
  const data = event?.data ?? {};
  switch (event?.type) {
    case "session.execution.succeeded":
      return { kind: "completed", sessionID: data.sessionID };
    case "session.execution.failed":
      return { kind: "failed", sessionID: data.sessionID, detail: data.error?.message };
    case "permission.asked":
      return { kind: "permission", sessionID: data.sessionID, detail: data.action };
    case "form.created":
      return { kind: "question", sessionID: data.form?.sessionID, detail: data.form?.title };
    default:
      return null;
  }
}

const HEADLINES = {
  completed: "応答が完了しました",
  failed: "エラーで停止しました",
  permission: "許可を待っています",
  question: "質問に回答を待っています",
};

function basename(path) {
  if (typeof path !== "string") return "";
  const parts = path.split(/[\\/]/).filter(Boolean);
  return parts[parts.length - 1] ?? "";
}

async function sessionInfo(ctx, sessionID) {
  try {
    return await ctx.session.get({ sessionID });
  } catch {
    return undefined;
  }
}

async function post(options, payload) {
  const response = await fetch(`${options.relay}/v1/notify`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${options.key}`,
    },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    throw new Error(`relay responded ${response.status}`);
  }
}

async function handle(ctx, options, event) {
  const match = classify(event);
  if (!match || !options.kinds[match.kind]) return;
  const { kind, sessionID } = match;
  if (typeof sessionID !== "string" || !sessionID.startsWith("ses")) return;

  const now = Date.now();
  if (typeof event.id === "string" && !remember(seenEvents, event.id, now)) return;

  const session = await sessionInfo(ctx, sessionID);
  // Subagent runs finish many times per turn; only the session the user
  // talks to is worth a notification.
  if (session?.parentID) return;
  // execution.failed is often preceded by step.failed for the same cause;
  // collapse repeats of one kind per session.
  if (!remember(sentKeys, `${kind}:${sessionID}`, now)) return;

  const directory = event.location?.directory ?? session?.location?.directory ?? ctx.location?.directory;
  const project = basename(directory) || "OpenCode";
  const title = options.includeTitle && session?.title ? session.title : undefined;
  await post(options, {
    kind,
    title: `${project}: ${HEADLINES[kind]}`,
    body: title ?? (options.includeTitle && match.detail ? String(match.detail) : ""),
    sessionID,
    directory: directory ?? "",
  });
}

function sleep(ms, signal) {
  return new Promise((resolve) => {
    const timer = setTimeout(resolve, ms);
    signal.addEventListener("abort", () => {
      clearTimeout(timer);
      resolve();
    }, { once: true });
  });
}

export default {
  id: PLUGIN_ID,
  async setup(ctx) {
    const options = readOptions(ctx.options);
    if (!options.relay || !options.key) {
      console.error(`[${PLUGIN_ID}] "relay" and "key" options are required; notifications are off.`);
      return;
    }

    const controller = new AbortController();
    const { signal } = controller;
    // Subscribe before any other await: the stream does not replay events,
    // so a late subscription misses the first turn.
    void (async () => {
      let failures = 0;
      while (!signal.aborted) {
        try {
          for await (const event of ctx.event.subscribe({ signal })) {
            failures = 0;
            handle(ctx, options, event).catch((error) => {
              console.error(`[${PLUGIN_ID}] notify failed: ${error?.message ?? error}`);
            });
          }
        } catch (error) {
          if (signal.aborted) break;
          failures += 1;
          console.error(`[${PLUGIN_ID}] event stream dropped: ${error?.message ?? error}`);
        }
        if (signal.aborted) break;
        await sleep(BACKOFFS_MS[Math.min(failures, BACKOFFS_MS.length - 1)], signal);
      }
    })();

    return () => controller.abort();
  },
};
