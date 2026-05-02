# ngrok-tunnel — a Claude skill

Expose a local port to the internet on a stable, free [ngrok](https://ngrok.com) static domain — so you can test webhooks (Stripe, Twilio, OAuth callbacks), preview your dev server on a phone, or share a localhost URL with someone, all without re-pasting URLs every time the agent restarts.

This is a [Claude Code skill](https://docs.anthropic.com/en/docs/claude-code/skills). It works in any environment that loads markdown skills (Claude Code, Codex CLI, Gemini CLI, etc.).

## What it does

- **First run** (`bash setup.sh`): walks the user through a one-time browser dance — sign up at ngrok, paste authtoken, paste your free `*.ngrok-free.app` static domain. Result is cached in `~/.config/ngrok-tunnel-skill/`.
- **Every run after that**: `ngrok http --url="https://<your-domain>" <port>`. Same URL every time. Stable across machine reboots, because the domain is reserved on your ngrok account forever.

## Why a stable URL matters for AI agents

When Claude (or any coding agent) is iterating on a feature you want to test from your phone, the public URL changes every time the agent restarts the dev server through a fresh tunnel. With a free static ngrok domain, the URL never changes — bookmark it once on your phone and forget about it.

Same logic applies to webhook providers (Stripe dashboard, Twilio console, OAuth callback URLs): paste the URL once, never again.

## Install

### Recommended: as a Claude Code plugin (one command)

```
/plugin marketplace add 0xmapachex/ngrok-tunnel-skill
/plugin install ngrok-tunnel@0xmapachex
```

The plugin auto-updates when you push new versions to this repo.

### Alternative: standalone skill (no plugin namespacing)

```bash
git clone https://github.com/0xmapachex/ngrok-tunnel-skill.git /tmp/ngrok-skill
cp -r /tmp/ngrok-skill/plugins/ngrok-tunnel/skills/ngrok-tunnel ~/.claude/skills/
chmod +x ~/.claude/skills/ngrok-tunnel/setup.sh
```

For Codex CLI, install the skill into `~/.agents/skills/` instead. Other markdown-skill loaders: drop `SKILL.md` + `setup.sh` wherever they look. The `description` frontmatter in `SKILL.md` is the trigger.

## Use

Just ask the agent for what you want — the skill description handles the rest:

> "Open this on my phone"
> "Tunnel port 3000"
> "Expose localhost:8080 so I can test the Stripe webhook"

The agent will run `setup.sh` if state is missing, then start the tunnel. The cached URL is the same every time.

## Free-plan reality check

The free ngrok plan gives you:
- ✅ One static domain that's yours forever (`*.ngrok-free.app`)
- ✅ Up to 3 simultaneous online endpoints
- ✅ ~120 connections/min rate limit
- ⚠️ A "Visit Site" interstitial for first-time browser visitors (webhook providers bypass it)
- ❌ No custom domain (paid plans only)

For most local-dev / mobile-preview / webhook-test use cases, this is plenty.

## Repo layout

```
.
├── .claude-plugin/
│   └── marketplace.json                       # marketplace catalog
├── plugins/
│   └── ngrok-tunnel/
│       ├── .claude-plugin/
│       │   └── plugin.json                    # plugin manifest
│       └── skills/
│           └── ngrok-tunnel/
│               ├── SKILL.md                   # the skill (description + workflow)
│               └── setup.sh                   # idempotent first-run installer
├── README.md
└── LICENSE
```

## Contributing

PRs welcome. Especially: better install detection on Linux distros beyond Debian/Ubuntu, and a non-interactive setup mode that takes `NGROK_AUTHTOKEN` / `NGROK_DOMAIN` from env vars (useful for CI / pre-baked dev images).

## License

MIT — see `LICENSE`.
