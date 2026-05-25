# ~/.zsh/shared.zsh — cross-OS shell config sourced by ~/.zshrc loader.
# Managed by chezmoi. Don't edit the rendered file directly.

# --- Basic options ---
set -o vi

# --- Aliases (file works on both OSes — eza/nvim/lazygit etc. installed everywhere) ---
[ -f "$HOME/.zsh_aliases" ] && . "$HOME/.zsh_aliases"

# --- Completion ---
autoload -Uz compinit
compinit

zstyle ':completion:*' list-prompt ''
zstyle ':completion:*' select-prompt ''
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# --- PATH (cross-OS dirs) ---
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/bin:$PATH"
export PATH="$HOME/.bun/bin:$PATH"
export PATH="./bin:$PATH"

# --- bun ---
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"

# --- mise (Node primarily; reads .nvmrc / .tool-versions / .mise.toml) ---
eval "$(mise activate zsh)"

# --- Pager / editor preferences (cross-OS) ---
export PAGER=less
export MANPAGER="sh -c 'col -bx | bat -l man -p --paging=always'"
export BAT_THEME=gruvbox-dark

# --- Tools (cross-OS init order matters: starship last for prompt) ---
eval "$(zoxide init zsh)"
eval "$(direnv hook zsh)"
eval "$(atuin init zsh --disable-up-arrow)"
# thefuck — guarded since it's not always installed (e.g. fresh CachyOS)
command -v thefuck >/dev/null 2>&1 && eval "$(thefuck --alias f)"
eval "$(starship init zsh)"

# --- fzf (cross-OS env; OS-specific keybinding source lives in darwin.zsh / linux.zsh) ---
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always --icons {} | head -200'"

# --- History ---
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY

# --- Global aliases (zsh-only, cross-OS) ---
alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g ......='../../../../..'
alias clear="printf '\33c\e[3J'"

# --- gem (cross-OS) ---
export GEM_HOME="$HOME/.gem"
export PATH="$PATH:$HOME/.gem/bin"
