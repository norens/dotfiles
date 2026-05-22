#!/usr/bin/env bash
#
# CachyOS bootstrap — run ONCE on a fresh CachyOS install after first login.
#
# What it does:
#   1. System update (pacman -Syu)
#   2. Install + enable Tailscale  (waits for `tailscale up` interactively)
#   3. Install + harden sshd       (pubkey-only, no root, no password)
#   4. Install paru                (AUR helper)
#   5. Install Node.js + claude-code via npm (official upstream)
#   6. Install chezmoi + clone dotfiles
#   7. Print next steps
#
# This script is idempotent. Safe to re-run.
#
# Requirements:
#   - CachyOS installed, you're logged in as a non-root user with sudo rights
#   - Internet connection
#   - GitHub account with SSH keys in 1Password (for chezmoi clone)
#
# Usage:
#   curl -O https://raw.githubusercontent.com/norens/dotfiles/main/docs/cachyos-setup/scripts/00-bootstrap.sh
#   chmod +x 00-bootstrap.sh
#   ./00-bootstrap.sh
#
# NOTE: review this file before running it. Don't blindly trust scripts from the internet.

set -euo pipefail

# ---------- helpers ----------

log()  { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }
ask()  { read -rp "$(printf '\033[1;36m[?]\033[0m %s ' "$1")" "$2"; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

# Don't run as root — we want $HOME/etc. of the regular user
[[ $EUID -ne 0 ]] || die "run as your regular user (not root). sudo is invoked where needed."

require_cmd sudo
require_cmd curl

# ---------- 1. system update ----------

log "Updating system (pacman -Syu)..."
sudo pacman -Syu --noconfirm

# ---------- 2. Tailscale ----------

log "Installing Tailscale..."
if ! command -v tailscale >/dev/null 2>&1; then
  sudo pacman -S --noconfirm --needed tailscale
fi

log "Enabling tailscaled service..."
sudo systemctl enable --now tailscaled

log ""
log "Tailscale: time to sign in."
log "  Run:  sudo tailscale up --ssh"
log "Open the URL it prints in a browser, sign in with your SSO."
log "Use the SAME account as on macOS (so both vuzli on the same tailnet)."
log ""
ask "Press ENTER when 'tailscale up' has completed successfully." _

if ! tailscale status >/dev/null 2>&1; then
  die "tailscale status failed — did you complete 'tailscale up'?"
fi
log "Tailscale state:"
tailscale status

# ---------- 3. SSH server + hardening ----------

log "Installing openssh..."
sudo pacman -S --noconfirm --needed openssh

# Drop a hardened sshd config snippet (does NOT overwrite main sshd_config)
SSHD_DROPIN="/etc/ssh/sshd_config.d/99-hardening.conf"
log "Writing $SSHD_DROPIN..."
sudo tee "$SSHD_DROPIN" >/dev/null <<'EOF'
# CachyOS bootstrap — sshd hardening
# Pubkey only, no root, modern crypto.

PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
PermitEmptyPasswords no
X11Forwarding no
AllowAgentForwarding yes
ClientAliveInterval 60
ClientAliveCountMax 3

# Modern crypto first
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
EOF

log "Validating sshd config..."
sudo sshd -t || die "sshd_config has errors"

log "Enabling sshd service..."
sudo systemctl enable --now sshd

# ---------- 4. authorized_keys ----------

log ""
log "SSH authorized_keys setup."
log "On your MacBook, copy the SSH PUBLIC key from 1Password (the 'public_key' field of your SSH Key item)."
log "Paste it below. Multiple keys allowed (one per line). End with empty line."
log ""

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
AUTH_KEYS="$HOME/.ssh/authorized_keys"
touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

# Read multiple lines until empty line, append non-empty/non-comment lines
PASTED_KEYS_COUNT=0
while IFS= read -rp '> ' line; do
  [[ -z "$line" ]] && break
  # Skip if already present
  if grep -qxF "$line" "$AUTH_KEYS" 2>/dev/null; then
    warn "key already in authorized_keys, skipping"
    continue
  fi
  echo "$line" >> "$AUTH_KEYS"
  PASTED_KEYS_COUNT=$((PASTED_KEYS_COUNT + 1))
done

log "Added $PASTED_KEYS_COUNT new key(s). Total lines in authorized_keys: $(wc -l < "$AUTH_KEYS")"

# ---------- 5. paru (AUR helper) ----------

if ! command -v paru >/dev/null 2>&1; then
  log "Installing paru from AUR..."
  sudo pacman -S --noconfirm --needed base-devel git
  tmpdir="$(mktemp -d)"
  git clone https://aur.archlinux.org/paru.git "$tmpdir/paru"
  ( cd "$tmpdir/paru" && makepkg -si --noconfirm )
  rm -rf "$tmpdir"
fi

# ---------- 6. Node.js + Claude Code ----------

log "Installing Node.js (for claude-code)..."
sudo pacman -S --noconfirm --needed nodejs npm

# Configure npm to install global packages without sudo
NPM_PREFIX="$HOME/.npm-global"
mkdir -p "$NPM_PREFIX"
npm config set prefix "$NPM_PREFIX"

if ! echo "$PATH" | grep -q "$NPM_PREFIX/bin"; then
  log "Adding $NPM_PREFIX/bin to PATH in ~/.zshrc (or ~/.bashrc)..."
  RCFILE="$HOME/.zshrc"
  [[ -f "$HOME/.zshrc" ]] || RCFILE="$HOME/.bashrc"
  echo "" >> "$RCFILE"
  echo "# Added by CachyOS bootstrap" >> "$RCFILE"
  echo "export PATH=\"$NPM_PREFIX/bin:\$PATH\"" >> "$RCFILE"
  export PATH="$NPM_PREFIX/bin:$PATH"
fi

log "Installing @anthropic-ai/claude-code..."
npm install -g @anthropic-ai/claude-code

# ---------- 7. chezmoi + dotfiles ----------

log "Installing chezmoi..."
sudo pacman -S --noconfirm --needed chezmoi

log ""
log "Cloning dotfiles repo (norens/dotfiles)."
log "If your GitHub access requires a key, ensure it's loaded via Tailscale-bridged 1Password agent, OR"
log "use HTTPS clone (will prompt for PAT)."
log ""
ask "Use SSH (git@github.com) or HTTPS clone? [ssh/https]:" CLONE_MODE
CLONE_MODE="${CLONE_MODE:-https}"

if [[ "$CLONE_MODE" == "ssh" ]]; then
  CHEZMOI_REPO="git@github.com:norens/dotfiles.git"
else
  CHEZMOI_REPO="https://github.com/norens/dotfiles.git"
fi

log "Initializing chezmoi from $CHEZMOI_REPO ..."
# NOTE: --apply might fail if cross-OS templates aren't ready yet. We do init-only here.
chezmoi init "$CHEZMOI_REPO"

log "chezmoi source ready at: ~/.local/share/chezmoi"
log "Run 'chezmoi diff' to see what would be applied, then 'chezmoi apply' when ready."
warn "Some dotfiles assume macOS (paths, brew). Cross-OS templating is a separate sub-project."
warn "Don't blindly 'chezmoi apply' — review diff first."

# ---------- 8. Final report ----------

log ""
log "=========================================="
log "  Bootstrap complete!"
log "=========================================="
log ""
log "Verify from MacBook:"
log "  tailscale status               # should list this CachyOS hostname"
log "  ssh nazar@$(hostname)          # should login без password (Touch ID via 1P agent)"
log ""
log "Then on CachyOS:"
log "  claude                          # start Claude Code, login to Anthropic account"
log "  cd ~/.local/share/chezmoi/docs/cachyos-setup && claude"
log "                                  # continue with CC tasks #2-#20 from PLAN.md"
log ""
log "Tailnet info: \$(tailscale status --self=true --peers=false 2>/dev/null | head -1)"
