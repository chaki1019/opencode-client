// Run with: node --test push/relay/test/*.test.js
import assert from "node:assert/strict";
import { generateKeyPairSync } from "node:crypto";
import { test } from "node:test";

import { fcmMessage, handle, keyId, sendFcm } from "../src/index.js";
import { memoryD1, rows } from "./d1.js";

const KEY = "a".repeat(43);

const req = (method, path, body, headers = {}) =>
  new Request(`https://relay.test${path}`, {
    method,
    headers: { "content-type": "application/json", ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

const notifyReq = (body, key = KEY) =>
  req("POST", "/v1/notify", body, { authorization: `Bearer ${key}` });

test("register, notify and unregister", async () => {
  const env = { DB: memoryD1() };
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
  assert.deepEqual(rows(env.DB).map((r) => r.key_id), [await keyId(KEY)]);

  await handle(req("DELETE", "/v1/devices", { key: KEY, token: "tok1" }), env);
  assert.equal(rows(env.DB).length, 0);
});

test("oversized ciphertext is refused", async () => {
  const env = { DB: memoryD1() };
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
  const env = { DB: memoryD1() };
  let res = await handle(notifyReq({ kind: "completed" }, "short"), env);
  assert.equal(res.status, 401);
  res = await handle(notifyReq({ kind: "completed" }, "b".repeat(43)), env);
  assert.equal(res.status, 202);
  assert.deepEqual(await res.json(), { ok: true, delivered: 0 });
});

test("unregistered tokens are dropped after a send", async () => {
  const env = { DB: memoryD1() };
  await handle(req("POST", "/v1/devices", { key: KEY, token: "old" }), env);
  await handle(req("POST", "/v1/devices", { key: KEY, token: "new" }), env);
  const deps = { sendFcm: async (_e, device) => (device.token === "old" ? "unregistered" : "ok") };
  await handle(notifyReq({ kind: "question", title: "t" }), env, deps);
  assert.deepEqual(rows(env.DB).map((d) => d.token), ["new"]);
});

test("only the newest devices per key are kept", async () => {
  const env = { DB: memoryD1() };
  for (let i = 0; i < 12; i++) {
    await handle(req("POST", "/v1/devices", { key: KEY, token: `t${i}` }), env);
    await new Promise((r) => setTimeout(r, 2));
  }
  // Re-registering moves a device back to the front.
  await handle(req("POST", "/v1/devices", { key: KEY, token: "t3" }), env);
  const tokens = rows(env.DB).map((d) => d.token);
  assert.equal(tokens.length, 10);
  assert.equal(tokens[0], "t3");
  assert.ok(!tokens.includes("t0") && !tokens.includes("t1"));
});

test("rate limits answer 429 per address and per key", async () => {
  const limiter = (max) => {
    const counts = new Map();
    return {
      seen: counts,
      limit: async ({ key }) => {
        counts.set(key, (counts.get(key) ?? 0) + 1);
        return { success: counts.get(key) <= max };
      },
    };
  };
  const env = { DB: memoryD1(), IP_LIMIT: limiter(100), KEY_LIMIT: limiter(2) };
  const deps = { sendFcm: async () => "ok" };
  const from = (ip) => ({ "cf-connecting-ip": ip });
  await handle(req("POST", "/v1/devices", { key: KEY, token: "t" }, from("1.1.1.1")), env);
  const statuses = [];
  for (let i = 0; i < 3; i++) {
    const res = await handle(notifyReq({ kind: "completed", sessionID: "s", enc: "e" }), env, deps);
    statuses.push(res.status);
    if (res.status === 429) assert.equal(res.headers.get("retry-after"), "60");
  }
  assert.deepEqual(statuses, [202, 202, 429]);
  // The relay limits by key hash, never by the key itself.
  assert.ok(env.KEY_LIMIT.seen.has(await keyId(KEY)));
  assert.equal(env.IP_LIMIT.seen.get("1.1.1.1"), 1);

  env.IP_LIMIT = limiter(0);
  const res = await handle(req("POST", "/v1/devices", { key: KEY, token: "t" }), env);
  assert.equal(res.status, 429);
});

test("devices registered before D1 move over on first notify", async () => {
  const kv = new Map();
  const env = {
    DB: memoryD1(),
    DEVICES: {
      get: async (k) => kv.get(k) ?? null,
      delete: async (k) => void kv.delete(k),
    },
  };
  const id = await keyId(KEY);
  kv.set(`key:${id}`, JSON.stringify([{ token: "a", platform: "ios" }, { token: "b", platform: "android" }]));
  const sent = [];
  const res = await handle(notifyReq({ kind: "completed", sessionID: "s", enc: "e" }), env, {
    sendFcm: async (_e, device) => (sent.push(device.token), "ok"),
  });
  assert.deepEqual(await res.json(), { ok: true, delivered: 2 });
  assert.deepEqual(sent, ["a", "b"]);
  assert.equal(kv.size, 0);
  assert.deepEqual(rows(env.DB).map((d) => [d.token, d.platform]), [["a", "ios"], ["b", "android"]]);

  // Unregistering a device that is still only in KV removes it for good.
  kv.set(`key:${id}`, JSON.stringify([{ token: "c", platform: "ios" }]));
  const other = { ...env, DB: memoryD1() };
  await handle(req("DELETE", "/v1/devices", { key: KEY, token: "c" }), other);
  assert.equal(rows(other.DB).length, 0);
  assert.equal(kv.size, 0);

  // Registering a new device keeps the ones still in KV.
  kv.set(`key:${id}`, JSON.stringify([{ token: "d", platform: "ios" }]));
  const third = { ...env, DB: memoryD1() };
  await handle(req("POST", "/v1/devices", { key: KEY, token: "e" }), third);
  assert.deepEqual(rows(third.DB).map((d) => d.token).sort(), ["d", "e"]);
});

test("register validates input", async () => {
  const env = { DB: memoryD1() };
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

test("app-version serves the configured minimums", async () => {
  let res = await handle(req("GET", "/v1/app-version"), {});
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), {
    ios: { minimum: null, storeUrl: null },
    android: { minimum: null, storeUrl: null },
    ads: { rewarded: null, freeMessages: null, messagesPerReward: null },
  });

  res = await handle(req("GET", "/v1/app-version"), {
    MIN_VERSION_IOS: "1.2.0",
    STORE_URL_IOS: "https://apps.apple.com/app/id123",
    MIN_VERSION_ANDROID: "1.1.0",
    STORE_URL_ANDROID: "",
  });
  assert.match(res.headers.get("cache-control"), /max-age=/);
  assert.deepEqual(await res.json(), {
    ios: { minimum: "1.2.0", storeUrl: "https://apps.apple.com/app/id123" },
    android: { minimum: "1.1.0", storeUrl: null },
    ads: { rewarded: null, freeMessages: null, messagesPerReward: null },
  });

  res = await handle(req("GET", "/v1/app-version"), {
    ADS_REWARDED: "false",
    ADS_FREE_MESSAGES: "20",
    ADS_MESSAGES_PER_REWARD: "5",
  });
  assert.deepEqual((await res.json()).ads, {
    rewarded: false,
    freeMessages: 20,
    messagesPerReward: 5,
  });

  // Anything that is not a clear value leaves the app's own.
  res = await handle(req("GET", "/v1/app-version"), {
    ADS_REWARDED: "no",
    ADS_FREE_MESSAGES: "0",
    ADS_MESSAGES_PER_REWARD: "ten",
  });
  assert.deepEqual((await res.json()).ads, {
    rewarded: null,
    freeMessages: null,
    messagesPerReward: null,
  });

  // Not rate limited: every app launch asks.
  const blocked = { limit: async () => ({ success: false }) };
  res = await handle(req("GET", "/v1/app-version"), { IP_LIMIT: blocked });
  assert.equal(res.status, 200);
});
