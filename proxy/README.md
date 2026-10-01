# InstaLingo proxy

Cloudflare Worker that holds the shared default Groq key so it is never shipped in the app.

```bash
cd proxy
npx wrangler kv namespace create COUNTERS   # paste id into wrangler.toml
npx wrangler secret put GROQ_API_KEY
npx wrangler deploy
```

Then set `GroqProvider.defaultProxyEndpoint` to `https://<worker>.workers.dev/v1/lookup`.

- Allowlists `openai/gpt-oss-120b` / `openai/gpt-oss-20b`, caps `max_completion_tokens` at 700, rejects streaming.
- Daily limits per install ID, per IP and globally (edit constants in `worker.js`).
- Lookup text passes through the Worker; it is not logged. Do not add logging of request bodies.
- Set a spend limit on the key in the Groq console; rotate with `wrangler secret put` (no app update needed).
