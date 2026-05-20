#!/usr/bin/env bash
# ngrok-tunnel skill — first-run setup
#
# Installs ngrok (if missing), configures the authtoken (if missing),
# and caches the user's free static domain (if missing).
# Idempotent: safe to re-run; skips steps already complete.

set -euo pipefail

STATE_DIR="$HOME/.config/ngrok-tunnel-skill"
DOMAIN_FILE="$STATE_DIR/domain"
mkdir -p "$STATE_DIR"

say() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*" >&2; }
err()  { printf '\033[1;31m%s\033[0m\n' "$*" >&2; }

open_url() {
  case "$(uname -s)" in
    Darwin) open "$1" 2>/dev/null || true ;;
    Linux)  xdg-open "$1" 2>/dev/null || true ;;
  esac
  echo "  → $1"
}

# ----------------------------------------------------------------------------
# 1. Install ngrok if missing
# ----------------------------------------------------------------------------
if ! command -v ngrok >/dev/null 2>&1; then
  say "Installing ngrok…"
  case "$(uname -s)" in
    Darwin)
      if ! command -v brew >/dev/null 2>&1; then
        err "Homebrew not installed. Install it first: https://brew.sh"
        exit 1
      fi
      brew install ngrok
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        curl -fsSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
          | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
        echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
          | sudo tee /etc/apt/sources.list.d/ngrok.list >/dev/null
        sudo apt-get update && sudo apt-get install -y ngrok
      else
        err "Auto-install only supports Homebrew (macOS) and apt (Debian/Ubuntu)."
        err "Install ngrok manually: https://ngrok.com/download"
        exit 1
      fi
      ;;
    *)
      err "Unsupported OS. Install ngrok manually: https://ngrok.com/download"
      exit 1
      ;;
  esac
fi

say "ngrok installed: $(ngrok version | head -1)"

# ----------------------------------------------------------------------------
# 2. Configure authtoken if missing
# ----------------------------------------------------------------------------
# `ngrok config check` exits 0 only if a valid config (with authtoken) exists.
# This is more reliable than guessing the config-file path, which varies
# across macOS / Linux and respects XDG_CONFIG_HOME when set.
if ! ngrok config check >/dev/null 2>&1; then
  say "ngrok authtoken needed."
  echo "  1. If you don't have an account yet, sign up here:"
  open_url "https://dashboard.ngrok.com/signup"
  echo ""
  echo "  2. Then copy your authtoken from:"
  open_url "https://dashboard.ngrok.com/get-started/your-authtoken"
  echo ""
  read -r -p "Paste authtoken here: " TOKEN
  if [ -z "${TOKEN:-}" ]; then
    err "Empty token; aborting."
    exit 1
  fi
  ngrok config add-authtoken "$TOKEN" >/dev/null
  say "Authtoken saved."
fi

# ----------------------------------------------------------------------------
# 3. Cache the free static domain
# ----------------------------------------------------------------------------
if [ ! -s "$DOMAIN_FILE" ]; then
  say "Static domain needed."
  echo "  Open the Domains page:"
  open_url "https://dashboard.ngrok.com/domains"
  echo ""
  echo "  • If a domain is already listed, copy it (e.g. happy-tiger-1234.ngrok-free.app)."
  echo "  • If the page is empty, click '+ New Domain' → choose an ngrok-free.app subdomain → 'Continue'."
  echo ""
  read -r -p "Paste domain here: " DOMAIN
  # Strip protocol / trailing slash if user pasted a full URL
  DOMAIN="${DOMAIN#https://}"
  DOMAIN="${DOMAIN#http://}"
  DOMAIN="${DOMAIN%/}"
  if [ -z "${DOMAIN:-}" ]; then
    err "Empty domain; aborting."
    exit 1
  fi
  if [[ "$DOMAIN" != *.ngrok-free.app && "$DOMAIN" != *.ngrok-free.dev && "$DOMAIN" != *.ngrok.app ]]; then
    warn "Domain '$DOMAIN' doesn't look like an ngrok domain. Saving anyway — re-run setup if it's wrong."
  fi
  echo "$DOMAIN" > "$DOMAIN_FILE"
  say "Domain saved: $DOMAIN"
fi

# ----------------------------------------------------------------------------
# Done.
# ----------------------------------------------------------------------------
DOMAIN=$(cat "$DOMAIN_FILE")
say "Setup complete."
cat <<EOF
  Domain : $DOMAIN
  Start a tunnel:
    ngrok http --url="https://$DOMAIN" <PORT>
  Stop:
    pkill -f "ngrok http"
EOF
