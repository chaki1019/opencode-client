// OpenCode v2 plugin: forwards "agent finished / needs you" events to the
// opencode-client push relay, which delivers them to the phone over FCM.
//
// Install from npm (package "opencode-push") or copy this single file to
// ~/.config/opencode/plugins/, then add to ~/.config/opencode/opencode.json
// (the app shows this snippet with your key):
//
//   "plugins": [{
//     "package": "opencode-push",   // or "./plugins/opencode-push.js"
//     "options": { "relay": "https://<your-relay>", "key": "<pairing key>" }
//   }]
//
// The file has no imports on purpose: plugins load from a folder without
// node_modules, and a failed import makes OpenCode skip the plugin silently.
// Checked against @opencode/plugin 2.0.22 (event names and payloads).
//
// The relay never sees what a notification says. Two keys are derived from
// the pairing key with HKDF-SHA256: an auth token the relay knows, and an
// encryption key it never gets. The project name and session title travel
// as AES-256-GCM ciphertext that only the phone can open.

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

const encoder = new TextEncoder();

function base64url(bytes) {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function deriveBytes(key, info) {
  const material = await crypto.subtle.importKey("raw", encoder.encode(key), "HKDF", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "HKDF", hash: "SHA-256", salt: new Uint8Array(0), info: encoder.encode(info) },
    material,
    256,
  );
  return new Uint8Array(bits);
}

const derived = new Map();

/** The relay token and AES key for a pairing key (cached per key). */
function keysFor(key) {
  if (!derived.has(key)) {
    derived.set(key, (async () => {
      const auth = base64url(await deriveBytes(key, "opencode-push/auth"));
      const enc = await crypto.subtle.importKey(
        "raw",
        await deriveBytes(key, "opencode-push/enc"),
        "AES-GCM",
        false,
        ["encrypt"],
      );
      return { auth, enc };
    })());
  }
  return derived.get(key);
}

/** AES-256-GCM over [content]; kind and session are bound as associated data. */
async function seal(encKey, kind, sessionID, content) {
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const sealed = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv: nonce, additionalData: encoder.encode(`${kind}:${sessionID}`) },
    encKey,
    encoder.encode(JSON.stringify(content)),
  );
  const out = new Uint8Array(12 + sealed.byteLength);
  out.set(nonce);
  out.set(new Uint8Array(sealed), 12);
  return base64url(out);
}

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

async function post(options, auth, payload) {
  const response = await fetch(`${options.relay}/v1/notify`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${auth}`,
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
  const content = { project: basename(directory) };
  if (options.includeTitle) {
    if (session?.title) content.title = session.title;
    if (match.detail) content.detail = String(match.detail);
  }
  const keys = await keysFor(options.key);
  await post(options, keys.auth, {
    kind,
    sessionID,
    enc: await seal(keys.enc, kind, sessionID, content),
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
