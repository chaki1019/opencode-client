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
// Bindings: KV namespace DEVICES, secret FCM_SERVICE_ACCOUNT (the Firebase
// service account JSON).

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
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
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
  const raw = await env.DEVICES.get(`key:${id}`);
  return raw ? JSON.parse(raw) : [];
}

async function saveDevices(env, id, devices) {
  if (devices.length === 0) {
    await env.DEVICES.delete(`key:${id}`);
  } else {
    await env.DEVICES.put(`key:${id}`, JSON.stringify(devices));
  }
}

async function register(request, env) {
  const body = await readJson(request);
  const id = await keyId(requireKey(body.key));
  const token = requireToken(body.token);
  const platform = body.platform === "ios" ? "ios" : "android";
  const devices = (await loadDevices(env, id)).filter((d) => d.token !== token);
  devices.unshift({ token, platform });
  await saveDevices(env, id, devices.slice(0, MAX_DEVICES_PER_KEY));
  return json({ ok: true });
}

async function unregister(request, env) {
  const body = await readJson(request);
  const id = await keyId(requireKey(body.key));
  const token = requireToken(body.token);
  const devices = await loadDevices(env, id);
  await saveDevices(env, id, devices.filter((d) => d.token !== token));
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
    await saveDevices(env, id, devices.filter((d) => !stale.includes(d)));
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
