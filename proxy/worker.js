// Cloudflare Worker: holds the Groq key so it never ships in the app.
// Deploy: `wrangler secret put GROQ_API_KEY && wrangler deploy`.
// Lookup text is forwarded to Groq and is never logged here.
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const ALLOWED_MODELS = new Set(["openai/gpt-oss-120b", "openai/gpt-oss-20b"]);
const MAX_TOKENS = 700;
const MAX_BODY_BYTES = 8192;
const DAILY_LIMIT_PER_INSTALL = 200;
const DAILY_LIMIT_GLOBAL = 20000;

const json = (status, body) =>
  new Response(JSON.stringify({ error: body }), { status, headers: { "Content-Type": "application/json" } });

// Best-effort counter in KV (binding: COUNTERS). Not atomic; fine for abuse damping.
async function overLimit(env, key, limit) {
  const day = new Date().toISOString().slice(0, 10);
  const k = `${day}:${key}`;
  const n = parseInt((await env.COUNTERS.get(k)) ?? "0", 10);
  if (n >= limit) return true;
  await env.COUNTERS.put(k, String(n + 1), { expirationTtl: 172800 });
  return false;
}

export default {
  async fetch(request, env) {
    if (request.method === "HEAD") return new Response(null, { status: 204 }); // connection warm-up
    if (request.method !== "POST") return json(405, "method_not_allowed");

    const installID = request.headers.get("X-Install-ID") ?? "";
    if (!/^[0-9A-Fa-f-]{36}$/.test(installID)) return json(401, "missing_install_id");

    const raw = await request.text();
    if (raw.length > MAX_BODY_BYTES) return json(413, "too_large");
    let body;
    try { body = JSON.parse(raw); } catch { return json(400, "bad_json"); }
    if (!ALLOWED_MODELS.has(body.model)) return json(400, "model_not_allowed");
    if (body.stream) return json(400, "stream_not_allowed");
    body.max_completion_tokens = Math.min(body.max_completion_tokens ?? MAX_TOKENS, MAX_TOKENS);

    const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
    if (
      (await overLimit(env, `id:${installID}`, DAILY_LIMIT_PER_INSTALL)) ||
      (await overLimit(env, `ip:${ip}`, DAILY_LIMIT_PER_INSTALL * 2)) ||
      (await overLimit(env, "global", DAILY_LIMIT_GLOBAL))
    ) return json(429, "rate_limited");

    const upstream = await fetch(GROQ_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${env.GROQ_API_KEY}` },
      body: JSON.stringify(body),
    });
    // Groq auth failures are our problem, not the user's key: report as service error.
    const status = upstream.status === 401 || upstream.status === 403 ? 502 : upstream.status;
    return new Response(upstream.body, { status, headers: { "Content-Type": "application/json" } });
  },
};
