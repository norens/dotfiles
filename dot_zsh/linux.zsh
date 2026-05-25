# ~/.zsh/linux.zsh — Linux-only shell config sourced by ~/.zshrc loader
# when uname -s = "Linux". Managed by chezmoi.

# --- Editor (Linux uses nvim instead of nano) ---
export EDITOR=nvim
export VISUAL=nvim

# --- fzf keybindings (Linux package path) ---
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/fzf/completion.zsh ]   && source /usr/share/fzf/completion.zsh

# --- zsh plugins (Linux package paths — installed via pacman) ---
# Order matters: syntax-highlighting must come before history-substring-search.
[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] \
  && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] \
  && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -f /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ] && {
  source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
}

# --- npm-global (Linux user-level npm prefix) ---
export PATH="$HOME/.npm-global/bin:$PATH"

# --- ML / HuggingFace cache redirection ---
# Spec: docs/cachyos-setup/specs/2026-05-24-ml-robotics-stack-design.md §2
export HF_HOME="$HOME/ml-data/hf-cache"
export TRANSFORMERS_CACHE="$HF_HOME/hub"
export HF_DATASETS_CACHE="$HF_HOME/datasets"

# --- Podman rootless: explicit userns for predictable UID mapping ---
export PODMAN_USERNS="keep-id"
