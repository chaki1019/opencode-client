// Run with: node --test push/plugin/*.test.js
import assert from "node:assert/strict";
import { afterEach, beforeEach, test } from "node:test";

import plugin from "./opencode-push.js";

let sent;
const realFetch = globalThis.fetch;

beforeEach(() => {
  sent = [];
  globalThis.fetch = async (url, init) => {
    sent.push({ url, headers: init.headers, body: JSON.parse(init.body) });
    return new Response(null, { status: 202 });
  };
});

afterEach(() => {
  globalThis.fetch = realFetch;
});

let counter = 0;
const ev = (type, data, directory = "/Users/me/work/app") => ({
  id: `evt_${++counter}`,
  type,
  data,
  location: { directory },
});

/** Runs the plugin over [events] and waits for the notifications to go out. */
async function run(events, { options, sessions = {} } = {}) {
  const ctx = {
    options: options ?? { relay: "https://relay.example/", key: "k".repeat(43) },
    location: { directory: "/fallback" },
    session: {
      get: async ({ sessionID }) => {
        const info = sessions[sessionID];
        if (!info) throw new Error("not found");
        return info;
      },
    },
    event: {
      async *subscribe() {
        for (const event of events) yield event;
        await new Promise(() => {});
      },
    },
  };
  const cleanup = await plugin.setup(ctx);
  await new Promise((resolve) => setTimeout(resolve, 20));
  cleanup?.();
  return sent;
}

test("completed root session posts title and session", async () => {
  const sessions = { ses_1: { id: "ses_1", title: "Fix login" } };
  const out = await run([ev("session.execution.succeeded", { sessionID: "ses_1" })], { sessions });
  assert.equal(out.length, 1);
  assert.equal(out[0].url, "https://relay.example/v1/notify");
  assert.equal(out[0].headers.authorization, `Bearer ${"k".repeat(43)}`);
  assert.deepEqual(out[0].body, {
    kind: "completed",
    title: "app: 応答が完了しました",
    body: "Fix login",
    sessionID: "ses_1",
    directory: "/Users/me/work/app",
  });
});

test("subagent sessions are skipped", async () => {
  const sessions = { ses_2: { id: "ses_2", parentID: "ses_1" } };
  const out = await run([ev("session.execution.succeeded", { sessionID: "ses_2" })], { sessions });
  assert.equal(out.length, 0);
});

test("the same event delivered twice notifies once", async () => {
  const sessions = { ses_3: { id: "ses_3" } };
  const event = ev("permission.asked", { sessionID: "ses_3", id: "per_1", action: "bash", resources: [] });
  const out = await run([event, event], { sessions });
  assert.equal(out.length, 1);
  assert.equal(out[0].body.kind, "permission");
  assert.equal(out[0].body.body, "bash");
});

test("question uses the form's session and title", async () => {
  const out = await run([ev("form.created", { form: { id: "frm_1", sessionID: "ses_4", title: "Which DB?" } })]);
  assert.equal(out.length, 1);
  assert.equal(out[0].body.kind, "question");
  assert.equal(out[0].body.body, "Which DB?");
});

test("disabled kinds and unrelated events send nothing", async () => {
  const options = { relay: "https://r", key: "k", notifyOnComplete: false };
  const out = await run(
    [
      ev("session.execution.succeeded", { sessionID: "ses_5" }),
      ev("session.text.delta", { sessionID: "ses_5" }),
    ],
    { options },
  );
  assert.equal(out.length, 0);
});

test("includeTitle: false keeps session content out of the payload", async () => {
  const sessions = { ses_6: { id: "ses_6", title: "Secret project" } };
  const options = { relay: "https://r", key: "k", includeTitle: false };
  const out = await run([ev("session.execution.succeeded", { sessionID: "ses_6" })], { options, sessions });
  assert.equal(out[0].body.body, "");
});

test("missing options disable the plugin", async () => {
  const out = await run([ev("session.execution.succeeded", { sessionID: "ses_7" })], { options: {} });
  assert.equal(out.length, 0);
});
