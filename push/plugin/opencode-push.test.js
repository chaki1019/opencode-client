// Run with: node --test push/plugin/*.test.js
import assert from "node:assert/strict";
import { afterEach, beforeEach, test } from "node:test";

import plugin from "./opencode-push.js";

let sent;
const realFetch = globalThis.fetch;
const KEY = "k".repeat(43);
const encoder = new TextEncoder();

async function derive(key, info) {
  const material = await crypto.subtle.importKey("raw", encoder.encode(key), "HKDF", false, ["deriveBits"]);
  return new Uint8Array(
    await crypto.subtle.deriveBits(
      { name: "HKDF", hash: "SHA-256", salt: new Uint8Array(0), info: encoder.encode(info) },
      material,
      256,
    ),
  );
}

const b64 = (bytes) => Buffer.from(bytes).toString("base64url");

/** Opens a payload the way the phone does. */
async function open(key, { kind, sessionID, enc }) {
  const raw = Buffer.from(enc, "base64url");
  const aes = await crypto.subtle.importKey("raw", await derive(key, "opencode-push/enc"), "AES-GCM", false, ["decrypt"]);
  const plain = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: raw.subarray(0, 12), additionalData: encoder.encode(`${kind}:${sessionID}`) },
    aes,
    raw.subarray(12),
  );
  return JSON.parse(new TextDecoder().decode(plain));
}

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
    options: options ?? { relay: "https://relay.example/", key: KEY },
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
  await new Promise((resolve) => setTimeout(resolve, 100));
  cleanup?.();
  return sent;
}

test("completed root session posts an encrypted payload", async () => {
  const sessions = { ses_1: { id: "ses_1", title: "Fix login" } };
  const out = await run([ev("session.execution.succeeded", { sessionID: "ses_1" })], { sessions });
  assert.equal(out.length, 1);
  assert.equal(out[0].url, "https://relay.example/v1/notify");
  // The relay gets the derived token, never the pairing key.
  assert.equal(out[0].headers.authorization, `Bearer ${b64(await derive(KEY, "opencode-push/auth"))}`);
  assert.deepEqual(Object.keys(out[0].body).sort(), ["enc", "kind", "sessionID"]);
  assert.equal(out[0].body.kind, "completed");
  assert.equal(out[0].body.sessionID, "ses_1");
  assert.ok(!JSON.stringify(out[0].body).includes("Fix login"));
  assert.deepEqual(await open(KEY, out[0].body), { project: "app", title: "Fix login" });
});

test("tampering with kind or session breaks decryption", async () => {
  const sessions = { ses_9: { id: "ses_9", title: "t" } };
  const [sent] = await run([ev("session.execution.succeeded", { sessionID: "ses_9" })], { sessions });
  await assert.rejects(open(KEY, { ...sent.body, kind: "failed" }));
  await assert.rejects(open(KEY, { ...sent.body, sessionID: "ses_8" }));
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
  assert.deepEqual(await open(KEY, out[0].body), { project: "app", detail: "bash" });
});

test("question uses the form's session and title", async () => {
  const out = await run([ev("form.created", { form: { id: "frm_1", sessionID: "ses_4", title: "Which DB?" } })]);
  assert.equal(out.length, 1);
  assert.equal(out[0].body.kind, "question");
  assert.deepEqual(await open(KEY, out[0].body), { project: "app", detail: "Which DB?" });
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
  const options = { relay: "https://r", key: KEY, includeTitle: false };
  const out = await run([ev("session.execution.succeeded", { sessionID: "ses_6" })], { options, sessions });
  assert.deepEqual(await open(KEY, out[0].body), { project: "app" });
});

test("missing options disable the plugin", async () => {
  const out = await run([ev("session.execution.succeeded", { sessionID: "ses_7" })], { options: {} });
  assert.equal(out.length, 0);
});

test("matches the shared test vector", async () => {
  const { readFile } = await import("node:fs/promises");
  const vector = JSON.parse(await readFile(new URL("../test-vector.json", import.meta.url)));
  assert.equal(b64(await derive(vector.key, "opencode-push/auth")), vector.auth);
  assert.deepEqual(await open(vector.key, vector), vector.content);
});
