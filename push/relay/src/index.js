// Push relay for opencode-client (Cloudflare Worker).
//
// The app registers its FCM token under an auth key derived from its
// pairing key; the OpenCode plugin posts events with the same auth key as a
// bearer token, and the relay forwards them to every device registered for
// it. Auth keys are stored only as SHA-256 hashes.
//
// The relay cannot read notifications: what they say (project, session
// title) arrives as `enc`, AES-GCM ciphertext under a key that is derived
// from the pairing key and never sent here. The phone decrypts it before
// showing anything; until then the relay only knows the kind of event.
//
//   POST   /v1/devices  {key, token, platform}  register (idempotent)
//   DELETE /v1/devices  {key, token}            unregister
//   POST   /v1/notify   Authorization: Bearer <key>
//                       {kind, sessionID, enc}
//
// Bindings: D1 database DB (schema in migrations/), rate limiters
// IP_LIMIT and KEY_LIMIT, secret FCM_SERVICE_ACCOUNT (the Firebase service
// account JSON). An optional KV namespace DEVICES holds registrations from
// before D1; they move to D1 the first time their key is used.

const MIN_KEY_LENGTH = 32;
const MAX_DEVICES_PER_KEY = 10;
const KINDS = new Set(["completed", "failed", "permission", "question"]);
// FCM data payloads are capped at 4 KB.
const MAX_ENC_LENGTH = 3000;

export default {
  fetch: (request, env) => handle(request, env),
};

export async function handle(request, env, deps = {}) {
  const url = new URL(request.url);
  try {
    // Per client address on every route, so neither registrations nor
    // guessed keys can be sprayed from one place.
    await limit(env.IP_LIMIT, request.headers.get("cf-connecting-ip") ?? "unknown");
    if (url.pathname === "/v1/devices" && request.method === "POST") {
      return await register(request, env);
    }
    if (url.pathname === "/v1/devices" && request.method === "DELETE") {
      return await unregister(request, env);
    }
    if (url.pathname === "/v1/notify" && request.method === "POST") {
      return await notify(request, env, deps);
    }
    return json({ error: "not_found" }, 404);
  } catch (error) {
    if (error instanceof HttpError) return json({ error: error.message }, error.status);
    console.error(error);
    return json({ error: "internal" }, 500);
  }
}

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function json(body, status = 200) {
  const headers = { "content-type": "application/json" };
  if (status === 429) headers["retry-after"] = "60";
  return new Response(JSON.stringify(body), { status, headers });
}

/** Throws 429 when [limiter] (a Workers rate limiting binding) says so. */
async function limit(limiter, key) {
  if (!limiter) return;
  const { success } = await limiter.limit({ key });
  if (!success) throw new HttpError(429, "rate_limited");
}

async function readJson(request) {
  try {
    const body = await request.json();
    if (body && typeof body === "object") return body;
  } catch {
    // fall through
  }
  throw new HttpError(400, "invalid_json");
}

function requireKey(key) {
  if (typeof key !== "string" || key.length < MIN_KEY_LENGTH) {
    throw new HttpError(400, "invalid_key");
  }
  return key;
}

function requireToken(token) {
  if (typeof token !== "string" || token.length === 0 || token.length > 4096) {
    throw new HttpError(400, "invalid_token");
  }
  return token;
}

/** Hex SHA-256; the app derives the same id to tell which server sent a push. */
export async function keyId(key) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(key));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function loadDevices(env, id) {
  const { results } = await env.DB.prepare(
    "SELECT token, platform FROM devices WHERE key_id = ? ORDER BY updated_at DESC",
  )
    .bind(id)
    .all();
  if (results.length > 0 || !env.DEVICES) return results;
  return migrateFromKv(env, id);
}

/** Moves a key's devices from the pre-D1 KV store, keeping their order. */
async function migrateFromKv(env, id) {
  const raw = await env.DEVICES.get(`key:${id}`);
  if (!raw) return [];
  const devices = JSON.parse(raw).slice(0, MAX_DEVICES_PER_KEY);
  const now = Date.now();
  await env.DB.batch(
    devices.map((d, i) => upsert(env, id, d.token, d.platform, now - i)),
  );
  await env.DEVICES.delete(`key:${id}`);
  return devices.map((d) => ({ token: d.token, platform: d.platform }));
}

function upsert(env, id, token, platform, at) {
  return env.DB.prepare(
    `INSERT INTO devices (key_id, token, platform, updated_at) VALUES (?, ?, ?, ?)
     ON CONFLICT (key_id, token) DO UPDATE SET platform = excluded.platform, updated_at = excluded.updated_at`,
  ).bind(id, token, platform, at);
}

function removeDevice(env, id, token) {
  return env.DB.prepare("DELETE FROM devices WHERE key_id = ? AND token = ?").bind(id, token);
}

async function register(request, env) {
  const body = await readJson(request);
  const id = await keyId(requireKey(body.key));
  const token = requireToken(body.token);
  const platform = body.platform === "ios" ? "ios" : "android";
  // Pull in pre-D1 devices first so they are not stranded in KV.
  if (env.DEVICES) await loadDevices(env, id);
  await env.DB.batch([
    upsert(env, id, token, platform, Date.now()),
    // Keep the newest few; a key shared by many devices is a leaked key.
    env.DB.prepare(
      `DELETE FROM devices WHERE key_id = ? AND token NOT IN
       (SELECT token FROM devices WHERE key_id = ? ORDER BY updated_at DESC LIMIT ?)`,
    ).bind(id, id, MAX_DEVICES_PER_KEY),
  ]);
  return json({ ok: true });
}

async function unregister(request, env) {
  const body = await readJson(request);
  const id = await keyId(requireKey(body.key));
  const token = requireToken(body.token);
  // Pull in pre-D1 devices first so the removed one does not come back.
  if (env.DEVICES) await loadDevices(env, id);
  await removeDevice(env, id, token).run();
  return json({ ok: true });
}

function text(value, max) {
  return typeof value === "string" ? value.slice(0, max) : "";
}

async function notify(request, env, deps) {
  const auth = request.headers.get("authorization") ?? "";
  const key = auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
  if (key.length < MIN_KEY_LENGTH) throw new HttpError(401, "unauthorized");
  const id = await keyId(key);
  await limit(env.KEY_LIMIT, id);
  const devices = await loadDevices(env, id);
  // Unknown keys answer like known ones so the endpoint does not reveal
  // which keys exist.
  if (devices.length === 0) return json({ ok: true, delivered: 0 }, 202);

  const body = await readJson(request);
  if (typeof body.enc === "string" && body.enc.length > MAX_ENC_LENGTH) {
    throw new HttpError(413, "payload_too_large");
  }
  const data = {
    kind: KINDS.has(body.kind) ? body.kind : "completed",
    keyId: id,
    sessionID: text(body.sessionID, 200),
    enc: typeof body.enc === "string" ? body.enc : "",
  };

  const send = deps.sendFcm ?? sendFcm;
  const results = await Promise.all(devices.map((d) => send(env, d, data, deps)));
  const stale = devices.filter((_, i) => results[i] === "unregistered");
  if (stale.length > 0) {
    await env.DB.batch(stale.map((d) => removeDevice(env, id, d.token)));
  }
  const delivered = results.filter((r) => r === "ok").length;
  return json({ ok: true, delivered }, 202);
}

// --- FCM HTTP v1 -----------------------------------------------------------

let cachedToken;

/**
 * The FCM message for one device. Android gets data only and builds the
 * notification itself after decrypting. iOS gets a placeholder alert marked
 * mutable, which the app's Notification Service Extension rewrites.
 */
export function fcmMessage(device, data) {
  if (device.platform === "ios") {
    return {
      token: device.token,
      data,
      apns: {
        headers: { "apns-priority": "10" },
        payload: {
          aps: { alert: { title: "OpenCode" }, sound: "default", "mutable-content": 1 },
        },
      },
    };
  }
  return { token: device.token, data, android: { priority: "high" } };
}

/** Sends one message; returns "ok", "unregistered" or "error". */
export async function sendFcm(env, device, data, deps = {}) {
  const account = JSON.parse(env.FCM_SERVICE_ACCOUNT);
  const fetchFn = deps.fetch ?? fetch;
  const accessToken = await googleAccessToken(account, fetchFn);
  const response = await fetchFn(
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ message: fcmMessage(device, data) }),
    },
  );
  if (response.ok) return "ok";
  const detail = await response.text();
  // 404 UNREGISTERED: the app was uninstalled or the token rotated.
  if (response.status === 404 || detail.includes("UNREGISTERED")) return "unregistered";
  console.error(`FCM ${response.status}: ${detail}`);
  return "error";
}

async function googleAccessToken(account, fetchFn) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.email === account.client_email && cachedToken.expires > now + 60) {
    return cachedToken.value;
  }
  const assertion = await signJwt(account, now);
  const response = await fetchFn("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) throw new Error(`token exchange failed: ${response.status}`);
  const body = await response.json();
  cachedToken = {
    email: account.client_email,
    value: body.access_token,
    expires: now + (body.expires_in ?? 3600),
  };
  return cachedToken.value;
}

function base64url(bytes) {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function signJwt(account, now) {
  const encode = (value) => base64url(new TextEncoder().encode(JSON.stringify(value)));
  const unsigned = `${encode({ alg: "RS256", typ: "JWT" })}.${encode({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })}`;
  const pem = account.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const signingKey = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    signingKey,
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${base64url(new Uint8Array(signature))}`;
}
