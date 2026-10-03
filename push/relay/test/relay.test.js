// Run with: node --test push/relay/test/*.test.js
import assert from "node:assert/strict";
import { generateKeyPairSync } from "node:crypto";
import { test } from "node:test";

import { fcmMessage, handle, keyId, sendFcm } from "../src/index.js";

const KEY = "a".repeat(43);

function memoryKv() {
  const store = new Map();
  return {
    store,
    get: async (k) => store.get(k) ?? null,
    put: async (k, v) => void store.set(k, v),
    delete: async (k) => void store.delete(k),
  };
}

const req = (method, path, body, headers = {}) =>
  new Request(`https://relay.test${path}`, {
    method,
    headers: { "content-type": "application/json", ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

const notifyReq = (body, key = KEY) =>
  req("POST", "/v1/notify", body, { authorization: `Bearer ${key}` });

test("register, notify and unregister", async () => {
  const env = { DEVICES: memoryKv() };
  const sent = [];
  const deps = {
    sendFcm: async (_env, device, data) => {
      sent.push({ device, data });
      return "ok";
    },
  };

  let res = await handle(req("POST", "/v1/devices", { key: KEY, token: "tok1", platform: "ios" }), env);
  assert.equal(res.status, 200);
  // Registering the same token twice keeps one entry.
  await handle(req("POST", "/v1/devices", { key: KEY, token: "tok1", platform: "ios" }), env);

  res = await handle(
    // Plain-text fields from an old plugin are dropped, not forwarded.
    notifyReq({ kind: "completed", sessionID: "ses_1", enc: "abc", title: "leak", directory: "/w" }),
    env,
    deps,
  );
  assert.equal(res.status, 202);
  assert.deepEqual(await res.json(), { ok: true, delivered: 1 });
  assert.equal(sent.length, 1);
  assert.deepEqual(sent[0].device, { token: "tok1", platform: "ios" });
  assert.deepEqual(sent[0].data, { kind: "completed", keyId: await keyId(KEY), sessionID: "ses_1", enc: "abc" });

  // The raw key is never stored.
  assert.ok(![...env.DEVICES.store.keys()].some((k) => k.includes(KEY)));

  await handle(req("DELETE", "/v1/devices", { key: KEY, token: "tok1" }), env);
  assert.equal(env.DEVICES.store.size, 0);
});

test("oversized ciphertext is refused", async () => {
  const env = { DEVICES: memoryKv() };
  await handle(req("POST", "/v1/devices", { key: KEY, token: "t" }), env);
  const res = await handle(notifyReq({ kind: "completed", sessionID: "s", enc: "x".repeat(3001) }), env, {
    sendFcm: async () => "ok",
  });
  assert.equal(res.status, 413);
});

test("iOS gets a mutable placeholder alert, Android data only", () => {
  const data = { kind: "completed", keyId: "k", sessionID: "s", enc: "e" };
  assert.deepEqual(fcmMessage({ token: "a", platform: "android" }, data), {
    token: "a",
    data,
    android: { priority: "high" },
  });
  const ios = fcmMessage({ token: "i", platform: "ios" }, data);
  assert.equal(ios.notification, undefined);
  assert.equal(ios.apns.payload.aps["mutable-content"], 1);
  assert.deepEqual(ios.apns.payload.aps.alert, { title: "OpenCode" });
  assert.deepEqual(ios.data, data);
});

test("notify rejects short keys and ignores unknown ones", async () => {
  const env = { DEVICES: memoryKv() };
  let res = await handle(notifyReq({ kind: "completed" }, "short"), env);
  assert.equal(res.status, 401);
  res = await handle(notifyReq({ kind: "completed" }, "b".repeat(43)), env);
  assert.equal(res.status, 202);
  assert.deepEqual(await res.json(), { ok: true, delivered: 0 });
});

test("unregistered tokens are dropped after a send", async () => {
  const env = { DEVICES: memoryKv() };
  await handle(req("POST", "/v1/devices", { key: KEY, token: "old" }), env);
  await handle(req("POST", "/v1/devices", { key: KEY, token: "new" }), env);
  const deps = { sendFcm: async (_e, device) => (device.token === "old" ? "unregistered" : "ok") };
  await handle(notifyReq({ kind: "question", title: "t" }), env, deps);
  const stored = JSON.parse(env.DEVICES.store.get(`key:${await keyId(KEY)}`));
  assert.deepEqual(stored.map((d) => d.token), ["new"]);
});

test("register validates input", async () => {
  const env = { DEVICES: memoryKv() };
  assert.equal((await handle(req("POST", "/v1/devices", { key: "short", token: "t" }), env)).status, 400);
  assert.equal((await handle(req("POST", "/v1/devices", { key: KEY }), env)).status, 400);
  assert.equal((await handle(req("GET", "/nope"), env)).status, 404);
});

test("sendFcm signs a JWT, exchanges it and posts the message", async () => {
  const { privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const env = {
    FCM_SERVICE_ACCOUNT: JSON.stringify({
      project_id: "demo",
      client_email: "push@demo.iam.gserviceaccount.com",
      private_key: privateKey.export({ type: "pkcs8", format: "pem" }),
    }),
  };
  const calls = [];
  const fetch = async (url, init) => {
    calls.push({ url, init });
    if (url.startsWith("https://oauth2")) {
      return Response.json({ access_token: "at", expires_in: 3600 });
    }
    return new Response("{}", { status: 200 });
  };
  const device = { token: "tok", platform: "android" };
  const data = { kind: "completed" };
  assert.equal(await sendFcm(env, device, data, { fetch }), "ok");
  assert.equal(calls[0].url, "https://oauth2.googleapis.com/token");
  assert.match(calls[0].init.body.get("assertion"), /^[\w-]+\.[\w-]+\.[\w-]+$/);
  assert.equal(calls[1].url, "https://fcm.googleapis.com/v1/projects/demo/messages:send");
  assert.equal(calls[1].init.headers.authorization, "Bearer at");
  const sent = JSON.parse(calls[1].init.body).message;
  assert.equal(sent.token, "tok");
  assert.deepEqual(sent.data, data);

  // A cached access token skips the exchange; 404 maps to "unregistered".
  const gone = async (url) => (calls.push({ url }), new Response("UNREGISTERED", { status: 404 }));
  assert.equal(await sendFcm(env, device, data, { fetch: gone }), "unregistered");
  assert.equal(calls.at(-1).url, "https://fcm.googleapis.com/v1/projects/demo/messages:send");
});
