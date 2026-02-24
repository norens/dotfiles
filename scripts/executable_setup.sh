#!/bin/bash
set -euo pipefail

# Bootstrap script for a new Mac
# Idempotent — safe to re-run at any time

CHEZMOI_REPO="norens/dotfiles"

info()  { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
ok()    { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
warn()  { printf "\033[1;33m[WARN]\033[0m  %s\n" "$1"; }
err()   { printf "\033[1;31m[ERR]\033[0m   %s\n" "$1"; }

# -------------------------------------------------------------------
# 1. Homebrew
# -------------------------------------------------------------------
if command -v brew &>/dev/null; then
  ok "Homebrew already installed"
else
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/usr/local/bin/brew shellenv 2>/dev/null || /opt/homebrew/bin/brew shellenv)"
fi

# -------------------------------------------------------------------
# 2. chezmoi + dotfiles
# -------------------------------------------------------------------
if command -v chezmoi &>/dev/null && [ -d "$HOME/.local/share/chezmoi" ]; then
  ok "chezmoi already initialized"
  info "Applying latest dotfiles..."
  chezmoi apply
else
  info "Installing chezmoi and applying dotfiles..."
  brew install chezmoi
  chezmoi init --apply "$CHEZMOI_REPO"
fi
ok "Dotfiles applied"

# -------------------------------------------------------------------
# 3. Brewfile
# -------------------------------------------------------------------
BREWFILE="$HOME/.config/brewfile/Brewfile"
if [ -f "$BREWFILE" ]; then
  info "Installing packages from Brewfile..."
  brew bundle install --file="$BREWFILE"
  ok "Brewfile installed"
else
  warn "Brewfile not found at $BREWFILE — skipping"
fi

# -------------------------------------------------------------------
# 4. Default shell
# -------------------------------------------------------------------
if [ "$SHELL" = "$(which zsh)" ]; then
  ok "zsh is already the default shell"
else
  info "Setting zsh as default shell..."
  chsh -s "$(which zsh)"
  ok "Default shell set to zsh"
fi

# -------------------------------------------------------------------
# 5. JetBrains keymaps
# -------------------------------------------------------------------
KEYMAP_SRC="$HOME/.config/jetbrains-keymaps/macOS_mod.xml"
if [ -f "$KEYMAP_SRC" ]; then
  info "Distributing JetBrains keymaps..."
  for ide_dir in "$HOME/Library/Application Support/JetBrains"/*/; do
    keymap_dir="${ide_dir}keymaps"
    if [ -d "$keymap_dir" ]; then
      cp "$KEYMAP_SRC" "$keymap_dir/macOS_mod.xml"
    fi
  done
  ok "JetBrains keymaps distributed"
else
  warn "No canonical keymap found at $KEYMAP_SRC — skipping"
fi

# -------------------------------------------------------------------
# 6. Services
# -------------------------------------------------------------------
info "Starting services..."
brew services start felixkratz/formulae/sketchybar 2>/dev/null || true
ok "Services started (AeroSpace starts via Login Items)"

# -------------------------------------------------------------------
# 7. tmux plugins
# -------------------------------------------------------------------
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ -d "$TPM_DIR" ]; then
  ok "TPM already installed"
else
  info "Installing tmux plugin manager..."
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
  ok "TPM installed — run prefix+I in tmux to install plugins"
fi

# -------------------------------------------------------------------
# 8. Karabiner (Goku)
# -------------------------------------------------------------------
if command -v goku &>/dev/null; then
  info "Regenerating Karabiner config via Goku..."
  goku
  ok "Karabiner config generated"
fi

# -------------------------------------------------------------------
# 9. SketchyBar helpers
# -------------------------------------------------------------------
SKETCHYBAR_HELPERS="$HOME/.config/sketchybar/helpers"
if [ -d "$SKETCHYBAR_HELPERS" ] && [ -f "$SKETCHYBAR_HELPERS/install.sh" ]; then
  info "Building SketchyBar helpers..."
  cd "$SKETCHYBAR_HELPERS" && bash install.sh
  cd "$HOME"
  ok "SketchyBar helpers built"
fi

# -------------------------------------------------------------------
# 10. macOS defaults
# -------------------------------------------------------------------
info "Applying macOS defaults..."

# Keyboard: disable press-and-hold, enable key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Disable auto-correct, auto-capitalize, smart quotes/dashes
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Full keyboard access for all controls (Tab through UI elements)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Dock: auto-hide, small icons
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int 36
killall Dock 2>/dev/null || true

# Finder: show path bar and status bar
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
killall Finder 2>/dev/null || true

ok "macOS defaults applied"

# -------------------------------------------------------------------
# 11. Version managers
# -------------------------------------------------------------------
if command -v fnm &>/dev/null; then
  info "Installing latest LTS Node.js via fnm..."
  fnm install --lts 2>/dev/null || true
  ok "Node.js LTS installed"
fi

if command -v pyenv &>/dev/null; then
  if [ -z "$(pyenv versions --bare 2>/dev/null)" ]; then
    info "Installing latest Python via pyenv..."
    LATEST_PY=$(pyenv install --list | grep -E "^\s+3\.[0-9]+\.[0-9]+$" | tail -1 | tr -d ' ')
    pyenv install "$LATEST_PY" || true
    pyenv global "$LATEST_PY"
    ok "Python $LATEST_PY installed"
  else
    ok "pyenv already has Python versions installed"
  fi
fi

# -------------------------------------------------------------------
echo ""
ok "Setup complete! Restart your terminal for all changes to take effect."
