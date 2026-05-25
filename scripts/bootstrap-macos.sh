#!/bin/bash
#
# Bootstrap a fresh macOS machine from this dotfiles repo.
#
# What it does:
#   1. Install Homebrew if missing
#   2. Install chezmoi via brew
#   3. chezmoi init --apply with the repo URL — pulls + applies dotfiles
#      (.chezmoiignore.tmpl filters out Linux-only paths)
#
# Run from anywhere:
#   curl -fsSL https://raw.githubusercontent.com/norens/dotfiles/main/scripts/bootstrap-macos.sh | bash
# Or after cloning:
#   bash scripts/bootstrap-macos.sh

set -euo pipefail

log() { printf '\033[1;34m[bootstrap-macos]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# Sanity
[[ "$(uname -s)" == "Darwin" ]] || die "This script is for macOS only."

# Homebrew
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  log "Homebrew already installed."
fi

# Ensure brew on PATH for this session
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# chezmoi
log "Installing chezmoi..."
brew install chezmoi

# Bootstrap dotfiles
log "Running chezmoi init --apply..."
log "  Source: github.com/norens/dotfiles"
log "  Linux-only paths filtered out by .chezmoiignore.tmpl"

chezmoi init --apply git@github.com:norens/dotfiles.git || {
  warn "chezmoi init via SSH failed."
  warn "If 1Password Desktop SSH agent isn't set up yet, retry over HTTPS:"
  warn "  chezmoi init --apply https://github.com/norens/dotfiles.git"
  die "Bootstrap incomplete."
}

log "Done. Open a NEW terminal to load the new ~/.zshrc."
log "Next: run brew bundle --file=~/.config/brewfile/Brewfile to install GUI apps + CLI tools."
