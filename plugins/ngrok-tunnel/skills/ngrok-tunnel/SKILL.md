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
