# Default Groq key for all users (safely)

## Context
InstaLingo is a native macOS app. Today each user supplies their own Groq key, stored in Keychain (`Sources/InstaLingo/GroqKeychain.swift`), and `GroqProvider` sends it directly to `https://api.groq.com/openai/v1/chat/completions` (`Sources/InstaLingo/GroqProvider.swift:18,44`). ADR `docs/adr/0001-local-first-lookup.md` says the user must add their own key.

**Core fact:** any secret shipped inside a client app (Keychain seed, Info.plist, xcconfig, obfuscated string, encrypted blob) can be extracted from the binary or by sniffing traffic. Keychain protects a key the *user* enters on their machine; it cannot hide a key *you* ship. So a shared default key must never be in the app.

## Recommended approach: tiny proxy that holds the key
1. **Proxy** (Cloudflare Worker, ~30 lines; free tier is enough). Groq key stored as a Worker secret (`wrangler secret put GROQ_API_KEY`). It accepts the app's lookup request, forwards it to Groq with the real key, returns the response.
   - Allowlist models (`openai/gpt-oss-120b`, `openai/gpt-oss-20b`) and cap `max_completion_tokens`, so it can't be used as a general free LLM endpoint.
   - Rate limit per client (Cloudflare rate-limit binding / KV keyed by a per-install random ID, plus per-IP), and a global daily cap.
   - Optional hardening: Apple App Attest / DeviceCheck token verified by the Worker so only genuine installs of your app can call it.
2. **App changes**
   - `GroqProvider`: make endpoint + auth pluggable. If the user has their own key → current behavior (direct to Groq, Keychain). If not → POST to the proxy URL with no `Authorization: Bearer <groq key>`, only the install ID / attestation.
   - `GroqConfiguration` (`Sources/LookupCore/GroqLookup.swift`): treat "no personal key" as valid (default-key mode) instead of throwing `.missingKey`; keep `hasAPIKey` for personal-key state.
   - `GroqSettingsView.swift`: show "Using built-in key (limited)" with an optional field to add your own key for unlimited use; map proxy 429 to the existing `.quota` error text.
   - Update `GroqLookupTests` for the no-key path; keep tests offline via the injectable `session`/`endpoint`.
3. **Docs**: amend ADR 0001 (user key now optional; lookup text also passes through your proxy — disclose this, don't log lookup text in the Worker). Add proxy README/deploy steps.
4. **Ops**: Set a spend/usage limit on the Groq key in the Groq console; rotate the key if abused (only the Worker secret changes, no app update).

## Alternatives (not recommended)
- Embed key in app / obfuscate: trivially extractable; you would pay for abuse and must ship an update to rotate.
- Per-user Groq keys only (status quo): safest, but no zero-setup default.

## Verification
- `curl` the deployed Worker with a valid body → 200 with a lookup JSON; with a disallowed model or oversized tokens → 4xx; burst requests → 429.
- `strings`/`grep` the built `.app` and `git grep gsk_` → no Groq key present.
- Run app with no personal key: lookup works via proxy; add personal key: requests go straight to Groq; run `swift test`.
