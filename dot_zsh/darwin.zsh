# ~/.zsh/darwin.zsh — macOS-only shell config sourced by ~/.zshrc loader
# when uname -s = "Darwin". Managed by chezmoi.

# --- Goku (Karabiner config generator) ---
export GOKU_EDN_CONFIG_FILE=~/.config/goku/karabiner.edn

# --- Homebrew ---
eval "$(/usr/local/bin/brew shellenv)"

# --- Completions (brew + docker; docker fpath kept for backwards-compat) ---
FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fpath=($HOME/.docker/completions $fpath)

# --- zsh plugins (Homebrew install paths) ---
source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# --- pnpm (macOS uses ~/Library/pnpm) ---
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# --- Legacy Python/Ruby version managers (macOS only — not on CachyOS) ---
eval "$(pyenv init -)"
eval "$(rbenv init - zsh)"

# --- 1Password SSH agent socket (macOS Group Containers path) ---
# Used by tools that read SSH_AUTH_SOCK (git signing). ssh(1) itself uses
# IdentityAgent from ~/.ssh/config and doesn't need this.
export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# --- Editor (macOS user preference: nano per CLAUDE.md) ---
export EDITOR=nano
export VISUAL=nano

# --- fzf keybindings (Homebrew install) ---
source <(fzf --zsh)
