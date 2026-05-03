---
name: ngrok-tunnel
description: |
  Use when the user needs a public HTTPS URL for something running on localhost
  — testing webhooks (Stripe, Twilio, OAuth callbacks, GitHub apps), previewing
  a dev server on a phone or another device, or sharing a local app briefly.
  Backed by ngrok's free static domain so the URL stays stable across restarts.
  Use when asked to "open this on my phone", "expose localhost", "ngrok this",
  "test the webhook", or anything requiring an internet-reachable URL for a
  local port.
allowed-tools:
  - Bash
  - Read
  - Write
---

# ngrok-tunnel

Expose a local port on the user's free ngrok static domain. The URL is stable across agent restarts and machine reboots, so phones, webhook providers, and shared links don't break.

## When to use

- "Open this on my phone" / "test on mobile"
- Webhook callbacks (Stripe, Twilio, GitHub, OAuth providers)
- Sharing localhost with another person briefly
- Any task that needs a public HTTPS URL pointing at a local port

**Don't use for:** production traffic, services where the free-tier limit (3 simultaneous online endpoints, ~120 connections/min) would matter, or anything sensitive — ngrok URLs are public.

## Quick reference

`<skill-dir>` below = the directory containing this `SKILL.md`. Claude Code installs put it at `~/.claude/skills/ngrok-tunnel/`; plugin installs at the plugin's cache path. State (`~/.config/ngrok-tunnel-skill/`) is independent of where the skill itself lives.

| Need | Command |
|---|---|
| First-run setup (install + auth + domain) | `bash <skill-dir>/setup.sh` |
| Start tunnel on port `$PORT` | `ngrok http --url="https://$(cat ~/.config/ngrok-tunnel-skill/domain)" $PORT` |
| Stop a running tunnel | `pkill -f "ngrok http"` |
| Show cached domain | `cat ~/.config/ngrok-tunnel-skill/domain` |
| Reset (re-run setup) | `rm -rf ~/.config/ngrok-tunnel-skill` |

## Workflow

1. **Check for cached state.** If `~/.config/ngrok-tunnel-skill/domain` exists, skip to step 3.
2. **Run setup once.** `bash <skill-dir>/setup.sh` — it installs ngrok if missing, prompts the user to paste their authtoken, and prompts for their static domain. Idempotent: re-running skips already-done steps.
3. **Start the tunnel** on the target port using `Bash` with `run_in_background: true`:
   ```bash
   DOMAIN=$(cat ~/.config/ngrok-tunnel-skill/domain)
   ngrok http --url="https://$DOMAIN" <PORT>
   ```
4. **Tell the user the URL.** Always `https://<cached-domain>` — same every time.

## Multi-service apps (auth callbacks, OAuth, dependent services)

When the user is exposing an app that has **dependent services** the phone
also needs to reach — most often an OAuth provider (Google emulator, Auth0,
Clerk dev mode, your own auth API), Stripe webhook receiver, or a separate
backend on its own port — one tunnel isn't enough. The free ngrok account
allows **3 concurrent endpoints**; only one of them can use the reserved
static domain, the other two get random `*.ngrok-free.app` subdomains.

Pattern: tunnel each service separately, then point the primary app at the
other tunnels via env overrides.

```bash
# Reserved tunnel for the user-facing app (stable URL, the one they bookmark)
ngrok http --url="https://$(cat ~/.config/ngrok-tunnel-skill/domain)" 47372 &

# Random tunnel for the dependent service (URL changes each restart, but the
# primary app reads it from env so that's OK)
ngrok http 47374 &
```

Get the random tunnel's URL programmatically from the ngrok agent's
inspector API (each agent process binds 4040/4041/4042 in order):

```bash
curl -s http://127.0.0.1:4041/api/tunnels \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['tunnels'][0]['public_url'])"
```

Then restart the primary app with the dependent service's public URL plumbed
through the right env. For NextAuth + a local OAuth emulator that's:

```bash
AUTH_URL=https://<reserved-domain>.ngrok-free.app \
AUTH_TRUST_HOST=true \
GOOGLE_EMULATOR_URL=https://<random>.ngrok-free.app \
npm run dev
```

`AUTH_TRUST_HOST=true` is what tells NextAuth (and most modern auth
libraries) to honor the `X-Forwarded-Host` header ngrok sends, instead of
defaulting back to `localhost`.

**OAuth `redirect_uri` whitelist.** OAuth providers reject callback URLs
that aren't in their allow-list. The local emulator's config file (often
under `.dev/` or similar) needs the ngrok callback added:

```yaml
oauth_clients:
  - redirect_uris:
      - http://localhost:47372/api/auth/callback/google
      - https://<reserved-domain>.ngrok-free.app/api/auth/callback/google
```

For real providers (Google, GitHub, etc.) add the ngrok callback in their
dashboard. Real Google rejects free-tier ngrok subdomains for non-test
client IDs — use a separate test OAuth client when tunneling.

## Listing reserved domains via the dashboard API

If the user has multiple ngrok accounts, lost track of their reserved
domain, or wants to script tunnel orchestration, the dashboard API (separate
from the agent authtoken) lists everything:

```bash
curl -s https://api.ngrok.com/reserved_domains \
  -H "Authorization: Bearer $NGROK_API_KEY" \
  -H "Ngrok-Version: 2" \
  | python3 -c "import json,sys; [print(r['domain']) for r in json.load(sys.stdin)['reserved_domains']]"
```

The API key is generated at `dashboard.ngrok.com/api-keys` and is **not**
the same as the agent authtoken from `dashboard.ngrok.com/get-started/your-authtoken`.

## Setup details (what the script does)

The script can't fully automate ngrok signup — that requires CAPTCHA + email verification — but it walks the user through the minimum browser steps:

1. **Install ngrok** if missing. Uses `brew` on macOS, `apt` on Debian/Ubuntu, prints manual instructions otherwise.
2. **Configure authtoken** if missing. Opens (or prints) `https://dashboard.ngrok.com/get-started/your-authtoken`, prompts for paste, runs `ngrok config add-authtoken <TOKEN>`.
3. **Cache static domain.** Opens `https://dashboard.ngrok.com/domains`. Free accounts get one domain; if the page is empty, the user clicks "+ New Domain" → picks a `*.ngrok-free.app` subdomain → "Continue". User pastes the domain; script writes it to `~/.config/ngrok-tunnel-skill/domain`.

## Notes

- ngrok agent v3+ uses `--url=` (older flags `--domain=`/`--hostname=` are deprecated; `--subdomain=` is removed). Always use `--url=`.
- The free static domain is yours indefinitely while the account exists, even across long pauses.
- Config file: `~/Library/Application Support/ngrok/ngrok.yml` (macOS) or `~/.config/ngrok/ngrok.yml` (Linux).
- ngrok serves a "Visit Site" interstitial to first-time browser visitors on `*.ngrok-free.app`. This is a free-plan thing; webhook callers (Stripe, Twilio) bypass it because they send `User-Agent` strings ngrok recognizes.

## Common issues

| Symptom | Fix |
|---|---|
| `ERR_NGROK_320` "domain reserved for another account" | The authtoken on disk belongs to a different ngrok account than the one that owns the cached domain. Either re-paste the correct authtoken (`ngrok config add-authtoken <TOKEN>`) or update the cached domain (`rm ~/.config/ngrok-tunnel-skill/domain` and re-run setup). |
| `ERR_NGROK_3200` "domain not found" | Domain isn't reserved on this account. Visit `dashboard.ngrok.com/domains`, click "+ New Domain", retry. |
| `ERR_NGROK_108` "session limit" | Another ngrok process is already running. `pkill -f ngrok` then retry. |
| `command not found: ngrok` | Setup hasn't run. `bash <skill-dir>/setup.sh`. |
| `ERR_NGROK_105` "auth failed" | Token wrong/expired. Re-run setup or `ngrok config add-authtoken <NEW_TOKEN>`. |
| Tunnel comes up but page shows ngrok interstitial | Expected on free plan for browser visits. Click "Visit Site" once. Webhook providers are unaffected. |
| Skip the interstitial in scripts/headless tests | Send the header `ngrok-skip-browser-warning: 1` (any value works). |
| Tapping buttons does nothing on the ngrok URL (Next.js dev) | Next 16+ blocks cross-origin requests to `/_next/*` from non-localhost hosts, which silently breaks React hydration → onClick never wires up. Add the ngrok host to `experimental.allowedDevOrigins` in `next.config.ts` and restart the dev server. |
| OAuth flow lands on `chrome-error://chromewebdata/` after sign-in | The provider redirected to `localhost:<port>` because the auth library doesn't know its public URL. Set the canonical URL env (NextAuth: `AUTH_URL` + `AUTH_TRUST_HOST=true`; other libs vary) and bounce the app. |
| OAuth provider returns `redirect_uri_mismatch` | The ngrok callback URL isn't whitelisted. Add `https://<your-domain>/api/auth/callback/<provider>` to the OAuth client's allowed redirect_uris (provider dashboard for real Google/GitHub/etc., the local emulator's config file for dev emulators). |
