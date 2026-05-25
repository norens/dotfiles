# Cross-OS chezmoi Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate single dotfiles repo to cross-OS templated layout, enabling `chezmoi init --apply` on a fresh CachyOS machine without breaking the working macOS apply.

**Architecture:** Add `.chezmoiignore.tmpl` with OS-conditional guards to skip platform-irrelevant paths per OS. Decompose `.zshrc` into a thin runtime loader (`dot_zshrc`) plus three fragments under `dot_zsh/` (shared/darwin/linux). Convert `.ssh/config` to a `.tmpl` to handle macOS-vs-Linux 1Password agent socket differences. Promote Plan 1 inline-only files (`ollama.container`, `storage.conf`) into the repo under Linux-only paths.

**Tech Stack:** chezmoi (templating, `dot_` prefix, `.chezmoiignore.tmpl`), zsh (sourced fragments, runtime `uname -s`), git, SSH ControlMaster + 1Password agent.

**Source spec:** `docs/cross-os-chezmoi/specs/2026-05-25-cross-os-chezmoi-design.md`

---

## Prerequisites

- ✅ Plan 1 ML Foundation Slice complete (CachyOS reachable via `ssh nazarf@nazarf-cachyos`).
- ✅ Tailscale up on both, SSH ControlMaster cached (1 Touch ID per 10 min).
- ✅ chezmoi source repo on MacBook at `~/.local/share/chezmoi`, pointing at `github.com/norens/dotfiles`, with 130 plain files (no `.tmpl` yet).
- ✅ Inline-only files on CachyOS: `~/.zshrc` (ML env block appended), `~/.config/containers/systemd/ollama.container`, `~/.config/containers/storage.conf`.

**Execution context:** Most commands run on MacBook (where the chezmoi source lives). Steps marked **[CachyOS]** run via `ssh nazarf@nazarf-cachyos '…'` from MacBook (or directly on CachyOS if user is at the box). Steps marked **[BOTH]** are run on each machine independently.

**Test gate after every `dot_zshrc` edit:** open a separate terminal and run `zsh -i -c "echo OK; exit"`. If exit non-zero, the edit broke shell init — **do not commit**, fix in place. The currently-active shell where you're editing is safe because it loaded the old `.zshrc` at startup.

---

## File Structure

### Files created in chezmoi source (`~/.local/share/chezmoi/`)

| Path | Purpose | Task |
|---|---|---|
| `.chezmoiignore.tmpl` | Replaces plain `.chezmoiignore`; OS-conditional path guards | 2 |
| `dot_zsh/shared.zsh` | Cross-OS shell config (history, completion, options, tool inits) | 3 (skeleton), 5 (populate) |
| `dot_zsh/darwin.zsh` | macOS-only shell config (brew, /usr/local/share, macOS env) | 3 (skeleton), 6 (populate) |
| `dot_zsh/linux.zsh` | Linux-only shell config (fzf paths, HF_HOME, PODMAN_USERNS) | 3 (skeleton), 9 (populate) |
| `private_dot_ssh/config.tmpl` | Replaces `private_dot_ssh/config`; IdentityAgent path per OS | 4 |
| `dot_config/containers/systemd/ollama.container` | Promoted from CachyOS local file (Linux-only path) | 10 |
| `dot_config/containers/storage.conf` | Promoted from CachyOS local file (Linux-only path) | 10 |
| `scripts/bootstrap-macos.sh` | macOS bootstrap script for new machine | 11 |

### Files modified in chezmoi source

| Path | Change | Task |
|---|---|---|
| `.chezmoiignore` | DELETE (replaced by `.chezmoiignore.tmpl`) | 2 |
| `dot_zshrc` | Becomes thin loader (~20 lines from ~91) | 7 |
| `docs/cachyos-setup/scripts/00-bootstrap.sh` | Replace chezmoi step with `chezmoi init --apply` | 11 |

### Files touched on CachyOS (not in chezmoi)

| Path | Change | Task |
|---|---|---|
| `~/.zshrc.bak-pre-cross-os-migration` | Created as backup of pre-chezmoi state | 1 |
| `~/.zshrc` | Replaced by `chezmoi apply` (becomes thin loader, sources fragments) | 8 |
| `~/.config/containers/systemd/ollama.container` | Replaced by `chezmoi apply` (same content, now managed) | 10 |
| `~/.config/containers/storage.conf` | Replaced by `chezmoi apply` (same content, now managed) | 10 |

### Files touched on MacBook (not in chezmoi)

| Path | Change | Task |
|---|---|---|
| `~/.local/share/chezmoi.bak-pre-cross-os` | Created as backup of pre-migration repo state | 1 |

---

## Task 1: Pre-migration backups + pre-flight checks

**Files:**
- Create: `~/.local/share/chezmoi.bak-pre-cross-os/` (full copy on MacBook)
- Create: `~/.zshrc.bak-pre-cross-os-migration` (on CachyOS)

**Context:** Migration touches the file that loads the shell (`.zshrc`) on both machines. A bad commit can break interactive login. Backups + a separate non-zsh fallback shell are the safety net.

- [ ] **Step 1: Confirm clean git state on MacBook**

Run on MacBook:

```bash
cd ~/.local/share/chezmoi
git status
git log --oneline -3
```

Expected: working tree clean, branch on `main`, last 3 commits match what was pushed. If any uncommitted changes — stash or commit before starting.

- [ ] **Step 2: Snapshot chezmoi source on MacBook**

```bash
cp -r ~/.local/share/chezmoi ~/.local/share/chezmoi.bak-pre-cross-os
ls -ld ~/.local/share/chezmoi.bak-pre-cross-os
du -sh ~/.local/share/chezmoi.bak-pre-cross-os
```

Expected: directory exists, size matches `du -sh ~/.local/share/chezmoi` within a few KiB. This is the rollback target if migration goes wrong on MacBook.

- [ ] **Step 3: Verify SSH to CachyOS works**

```bash
ssh nazarf@nazarf-cachyos 'echo OK; hostname; uname -s'
```

Expected: prints `OK`, `nazarf-cachyos`, `Linux`. If timeout — wake Tailscale (System Tray → click Tailscale → ensure connected). Once connected, ControlMaster will cache the session (Touch ID once per 10 min).

- [ ] **Step 4: [CachyOS] Snapshot the CachyOS .zshrc**

```bash
ssh nazarf@nazarf-cachyos 'cp ~/.zshrc ~/.zshrc.bak-pre-cross-os-migration && ls -la ~/.zshrc.bak-pre-cross-os-migration'
```

Expected: file exists, owner `nazarf:nazarf`. (There may already be `~/.zshrc.bak-pre-ml-env` from Plan 1 — this new backup captures the latest state including the ML env block.)

- [ ] **Step 5: [CachyOS] Verify a fallback shell exists**

```bash
ssh nazarf@nazarf-cachyos 'command -v bash && bash --version | head -1'
```

Expected: bash path and version printed. If migration breaks zsh, you'll log in via TTY (Ctrl+Alt+F2 at CachyOS keyboard) and start `bash` to recover.

- [ ] **Step 6: Commit (no repo changes yet, but record the milestone in STATUS.md)**

No file changes to commit yet. Move to Task 2.

---

## Task 2: Add `.chezmoiignore.tmpl` (replaces plain `.chezmoiignore`)

**Files:**
- Create: `~/.local/share/chezmoi/.chezmoiignore.tmpl`
- Delete: `~/.local/share/chezmoi/.chezmoiignore`

**Context:** chezmoi reads `.chezmoiignore.tmpl` first if present (and ignores plain `.chezmoiignore` when the templated version exists). The template uses OS conditionals to skip platform-irrelevant paths. This is the first infrastructure piece — no behavior change on macOS yet (because all the "macOS-only" paths are still applied on macOS).

- [ ] **Step 1: Write the new `.chezmoiignore.tmpl`**

Create `~/.local/share/chezmoi/.chezmoiignore.tmpl` with this exact content:

```
# Raycast token — never tracked, regardless of OS
.config/raycast/config.json
.DS_Store
**/.DS_Store

{{ if ne .chezmoi.os "darwin" }}
# macOS-only paths — skip on non-Darwin
.config/aerospace
.config/karabiner
.config/goku
.config/sketchybar
.config/jetbrains-keymaps
.config/restic
.config/gh
.config/ghostty/shaders
.tmux/plugins/tmux-ghostty-theme
Library
scripts/setup.sh
{{ end }}

{{ if ne .chezmoi.os "linux" }}
# Linux-only paths — skip on non-Linux
.config/hypr
.config/waybar
.config/mako
.config/kanata
.config/containers
{{ end }}
```

- [ ] **Step 2: Delete the plain `.chezmoiignore`**

```bash
rm ~/.local/share/chezmoi/.chezmoiignore
ls ~/.local/share/chezmoi/.chezmoiignore* 2>&1
```

Expected: only `.chezmoiignore.tmpl` listed (plain is gone).

- [ ] **Step 3: Verify chezmoi parses the template cleanly on macOS**

```bash
cd ~/.local/share/chezmoi
chezmoi execute-template < .chezmoiignore.tmpl
```

Expected: prints the rendered ignore list. Since OS is darwin, the "macOS-only" block is empty (the `{{ if ne … "darwin" }}` evaluates false) and the "Linux-only" block is fully rendered. So the output should be the static lines plus the Linux-only section.

- [ ] **Step 4: Verify `chezmoi diff` shows no behavior change on macOS**

```bash
chezmoi diff
```

Expected: empty output (no files would change on apply — the macOS-tracked files are still managed, the Linux-only paths weren't in the repo so the new ignore for them is a no-op).

- [ ] **Step 5: Verify `chezmoi managed` count is unchanged**

```bash
chezmoi managed | wc -l
```

Expected: `130` (same as pre-migration baseline). If different — the new `.chezmoiignore.tmpl` is over-ignoring on macOS; revisit Step 1.

- [ ] **Step 6: Commit**

```bash
cd ~/.local/share/chezmoi
git add .chezmoiignore.tmpl
git rm .chezmoiignore
git commit -m "feat(chezmoi): templated .chezmoiignore with OS guards"
git push origin main
```

---

## Task 3: Create skeleton `dot_zsh/` fragments

**Files:**
- Create: `~/.local/share/chezmoi/dot_zsh/shared.zsh`
- Create: `~/.local/share/chezmoi/dot_zsh/darwin.zsh`
- Create: `~/.local/share/chezmoi/dot_zsh/linux.zsh`

**Context:** Create empty (commented-only) fragment files. Once committed and applied, `~/.zsh/` exists on disk with three empty files. The thin-loader `dot_zshrc` (Task 7) sources these. Putting skeletons first lets us validate the infrastructure (empty sources are no-ops) before moving real config into them.

- [ ] **Step 1: Create `dot_zsh/shared.zsh` with a header comment**

```bash
mkdir -p ~/.local/share/chezmoi/dot_zsh
cat > ~/.local/share/chezmoi/dot_zsh/shared.zsh <<'EOF'
# ~/.zsh/shared.zsh — cross-OS shell config sourced by ~/.zshrc loader.
# Managed by chezmoi. Don't edit the rendered file directly.
EOF
```

- [ ] **Step 2: Create `dot_zsh/darwin.zsh` skeleton**

```bash
cat > ~/.local/share/chezmoi/dot_zsh/darwin.zsh <<'EOF'
# ~/.zsh/darwin.zsh — macOS-only shell config sourced by ~/.zshrc loader
# when uname -s = "Darwin". Managed by chezmoi.
EOF
```

- [ ] **Step 3: Create `dot_zsh/linux.zsh` skeleton**

```bash
cat > ~/.local/share/chezmoi/dot_zsh/linux.zsh <<'EOF'
# ~/.zsh/linux.zsh — Linux-only shell config sourced by ~/.zshrc loader
# when uname -s = "Linux". Managed by chezmoi.
EOF
```

- [ ] **Step 4: Verify chezmoi sees them**

```bash
cd ~/.local/share/chezmoi
chezmoi managed | grep '^\.zsh'
```

Expected:
```
.zsh
.zsh/darwin.zsh
.zsh/linux.zsh
.zsh/shared.zsh
```

- [ ] **Step 5: Apply on macOS — creates `~/.zsh/`**

```bash
chezmoi apply -v
ls -la ~/.zsh/
```

Expected: 3 files created at `~/.zsh/{shared,darwin,linux}.zsh` (verbose output shows the "create" actions).

- [ ] **Step 6: Verify shell still works**

```bash
zsh -i -c "echo OK; exit"
```

Expected: prints `OK`, exits 0. (`.zshrc` doesn't source these files yet — they're inert.)

- [ ] **Step 7: Commit**

```bash
git add dot_zsh/
git commit -m "feat(zsh): skeleton dot_zsh/{shared,darwin,linux}.zsh fragments"
git push origin main
```

---

## Task 4: Convert `private_dot_ssh/config` to `.tmpl` (Bucket B)

**Files:**
- Rename: `~/.local/share/chezmoi/private_dot_ssh/config` → `private_dot_ssh/config.tmpl`
- Modify: the `IdentityAgent` line per OS

**Context:** The macOS `~/.ssh/config` references `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock` as the SSH agent socket. On Linux, the 1Password Linux app uses `~/.1password/agent.sock` (or no agent at all — fall back to `ssh-agent`). Convert this file to a template BEFORE we initialize chezmoi on CachyOS, otherwise the macOS path lands on Linux and breaks every SSH connection that relies on the agent.

- [ ] **Step 1: Read the current `.ssh/config` to find the `IdentityAgent` line**

```bash
cd ~/.local/share/chezmoi
grep -n 'IdentityAgent' private_dot_ssh/config
```

Expected: at least one line like `    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"`. Note the surrounding context (it may be inside a `Host *` block at the top, or per-host).

- [ ] **Step 2: Rename to `.tmpl`**

```bash
mv private_dot_ssh/config private_dot_ssh/config.tmpl
```

- [ ] **Step 3: Edit `private_dot_ssh/config.tmpl` — wrap the `IdentityAgent` line in OS conditional**

Find the existing line:

```
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
```

Replace with:

```
{{- if eq .chezmoi.os "darwin" }}
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
{{- else if eq .chezmoi.os "linux" }}
    IdentityAgent ~/.1password/agent.sock
{{- end }}
```

(If the line appears multiple times — repeat the wrap for each occurrence.)

- [ ] **Step 4: Verify the template renders correctly on macOS**

```bash
chezmoi execute-template < private_dot_ssh/config.tmpl | grep -A1 -B1 IdentityAgent
```

Expected: macOS path appears, Linux path does NOT. If both appear or neither — re-check the `{{ if }}` blocks.

- [ ] **Step 5: Verify the rendered `~/.ssh/config` is byte-identical to pre-migration**

```bash
diff <(chezmoi execute-template < private_dot_ssh/config.tmpl) ~/.ssh/config
```

Expected: empty diff (rendered output matches the current `~/.ssh/config` exactly on macOS). If there are unexpected changes (whitespace from `{{- }}` trimming), tweak the `{{- }}` whitespace markers until diff is clean.

- [ ] **Step 6: `chezmoi diff` on macOS**

```bash
chezmoi diff
```

Expected: empty output (templated rendering matches existing file on disk).

- [ ] **Step 7: `chezmoi apply` and verify SSH still works**

```bash
chezmoi apply
ssh -T git@github.com
```

Expected: `Hi norens! You've successfully authenticated, but GitHub does not provide shell access.` (Touch ID prompt may pop). If "Permission denied" — `.ssh/config` was rendered wrong; restore from backup and re-do.

- [ ] **Step 8: Commit**

```bash
git add private_dot_ssh/config.tmpl
git rm --cached private_dot_ssh/config 2>/dev/null || true
git commit -m "feat(ssh): template IdentityAgent per OS (1Password socket path)"
git push origin main
```

---

## Task 5: Decompose `dot_zshrc` — populate `dot_zsh/shared.zsh`

**Files:**
- Modify: `~/.local/share/chezmoi/dot_zsh/shared.zsh`

**Context:** Take the cross-OS content from the current 91-line `dot_zshrc` and move it into `shared.zsh`. DO NOT touch `dot_zshrc` yet — it still loads the old way until Task 7. After this task, `shared.zsh` contains all the lines that should run on BOTH macOS and Linux.

- [ ] **Step 1: Read the current `dot_zshrc` for reference**

```bash
cat ~/.local/share/chezmoi/dot_zshrc
```

Use this as the source-of-truth for what content goes where. The breakdown table:

| Lines (current dot_zshrc) | Content | Goes to |
|---|---|---|
| 1 | `set -o vi` | shared |
| 5 | `. ~/.zsh_aliases` | shared |
| 13-14 | `autoload -Uz compinit; compinit` | shared |
| 16-18 | `zstyle ':completion:*' ...` | shared |
| 25-30 | PATH `$HOME/.local/bin` `.cargo` `go` `bin` `.bun/bin` `./bin` | shared |
| 40-41 | bun completions (`[ -s "$HOME/.bun/_bun" ]`, `BUN_INSTALL`) | shared |
| 45 | `eval "$(mise activate zsh)"` | shared |
| 53,56-58 | `PAGER`, `MANPAGER`, `BAT_THEME` | shared |
| 61-65 | `eval` zoxide / direnv / atuin / thefuck / starship | shared |
| 69-73 | `FZF_DEFAULT_COMMAND`, `FZF_CTRL_T_*`, `FZF_ALT_C_*` (theme + commands) | shared |
| 76-81 | History setopts + HISTFILE/HISTSIZE/SAVEHIST | shared |
| 84-88 | global aliases (`...`, `....`, etc., `clear`) | shared |
| 90-91 | `GEM_HOME` + gem PATH | shared |

- [ ] **Step 2: Replace `dot_zsh/shared.zsh` with this exact content**

```bash
cat > ~/.local/share/chezmoi/dot_zsh/shared.zsh <<'EOF'
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
EOF
```

- [ ] **Step 3: Verify the file**

```bash
wc -l ~/.local/share/chezmoi/dot_zsh/shared.zsh
head -3 ~/.local/share/chezmoi/dot_zsh/shared.zsh
```

Expected: roughly 60 lines, header comment intact.

- [ ] **Step 4: `chezmoi diff` (still no behavior change — `dot_zshrc` unchanged, sources nothing from `~/.zsh/`)**

```bash
cd ~/.local/share/chezmoi
chezmoi diff
```

Expected: shows the change to `~/.zsh/shared.zsh` only. No diff for `~/.zshrc`.

- [ ] **Step 5: Apply and verify**

```bash
chezmoi apply
zsh -i -c "echo OK; exit"
```

Expected: `OK`, exit 0. The new content lives at `~/.zsh/shared.zsh` but `~/.zshrc` doesn't source it yet, so shell behavior is unchanged.

- [ ] **Step 6: Commit**

```bash
git add dot_zsh/shared.zsh
git commit -m "feat(zsh): populate shared.zsh from dot_zshrc cross-OS lines"
git push origin main
```

---

## Task 6: Decompose `dot_zshrc` — populate `dot_zsh/darwin.zsh`

**Files:**
- Modify: `~/.local/share/chezmoi/dot_zsh/darwin.zsh`

**Context:** Take the macOS-only content from the current `dot_zshrc` into `darwin.zsh`. Still no behavior change — `dot_zshrc` doesn't source it yet.

| Lines (current dot_zshrc) | Content | Goes to |
|---|---|---|
| 3 | `GOKU_EDN_CONFIG_FILE` | darwin |
| 7-8 | `eval "$(/usr/local/bin/brew shellenv)"` | darwin |
| 11-12 | brew FPATH + docker completions fpath | darwin (docker line is obsolete post-OrbStack but harmless; keep for now) |
| 21-22 | source `/usr/local/share/zsh-autosuggestions/*` + `zsh-syntax-highlighting/*` | darwin |
| 33-37 | `PNPM_HOME="$HOME/Library/pnpm"` block | darwin (Library is macOS path) |
| 46-47 | `eval "$(pyenv init -)"` + `eval "$(rbenv init -)"` | darwin (not installed on CachyOS) |
| 51 | `SSH_AUTH_SOCK=…Library/Group Containers/…` | darwin |
| 54-55 | `EDITOR=nano` + `VISUAL=nano` (macOS user pref per memory; CachyOS uses nvim) | darwin |
| 64 | `eval $(thefuck --alias f)` | shared actually (thefuck cross-OS) — kept in shared (Task 5 line) |
| 68 | `source <(fzf --zsh)` — Homebrew fzf zsh integration | darwin (Linux uses different source path, set in linux.zsh) |

- [ ] **Step 1: Replace `dot_zsh/darwin.zsh` with this exact content**

```bash
cat > ~/.local/share/chezmoi/dot_zsh/darwin.zsh <<'EOF'
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

# --- thefuck (installed via brew on macOS) ---
eval $(thefuck --alias f)

# --- fzf keybindings (Homebrew install) ---
source <(fzf --zsh)
EOF
```

- [ ] **Step 2: Verify the file**

```bash
wc -l ~/.local/share/chezmoi/dot_zsh/darwin.zsh
```

Expected: ~35 lines.

- [ ] **Step 3: `chezmoi diff` (still no behavior change)**

```bash
chezmoi diff
```

Expected: shows the change to `~/.zsh/darwin.zsh` only.

- [ ] **Step 4: Apply and verify shell unchanged**

```bash
chezmoi apply
zsh -i -c "echo OK; exit"
```

Expected: `OK`, exit 0. Old `~/.zshrc` still in effect; the new fragment is inert until Task 7.

- [ ] **Step 5: Commit**

```bash
git add dot_zsh/darwin.zsh
git commit -m "feat(zsh): populate darwin.zsh from dot_zshrc macOS-only lines"
git push origin main
```

---

## Task 7: Replace `dot_zshrc` with thin loader

**Files:**
- Modify: `~/.local/share/chezmoi/dot_zshrc` (full rewrite)

**Context:** This is the riskiest task — it replaces the working 91-line zshrc with a ~20-line loader. After apply, the next new shell sources `~/.zsh/shared.zsh` and `~/.zsh/darwin.zsh`. If the fragments are missing anything from the old zshrc, shell will be subtly (or not so subtly) broken.

**Crucial test gate:** open a SEPARATE terminal tab/window before applying. The current terminal already loaded the old `.zshrc` and is unaffected by the change. Test in the new window. If broken, you can fix from the old window.

- [ ] **Step 1: Replace `dot_zshrc` content with the thin loader**

```bash
cat > ~/.local/share/chezmoi/dot_zshrc <<'EOF'
# ~/.zshrc — thin loader; real config in ~/.zsh/{shared,darwin,linux}.zsh
# Managed by chezmoi. Don't add config logic here — add it to the appropriate
# fragment under ~/.zsh/.

ZSH_DIR="${ZDOTDIR:-$HOME}/.zsh"

# 1. Shared (history, completion, options, cross-OS tool inits)
[ -f "$ZSH_DIR/shared.zsh" ] && source "$ZSH_DIR/shared.zsh"

# 2. OS-specific
case "$(uname -s)" in
  Darwin) [ -f "$ZSH_DIR/darwin.zsh" ] && source "$ZSH_DIR/darwin.zsh" ;;
  Linux)  [ -f "$ZSH_DIR/linux.zsh" ]  && source "$ZSH_DIR/linux.zsh"  ;;
esac

# 3. Host-local override (NOT chezmoi-tracked; create manually if needed)
[ -f "$ZSH_DIR/local.zsh" ] && source "$ZSH_DIR/local.zsh"
EOF
```

- [ ] **Step 2: `chezmoi diff` — review the rewrite**

```bash
chezmoi diff
```

Expected: large diff showing `~/.zshrc` shrinking from 91 lines to ~20. Eyeball it. The diff should remove all the lines you moved to `shared.zsh` and `darwin.zsh` in Tasks 5-6 — nothing else should disappear.

- [ ] **Step 3: Open a NEW terminal window** (Cmd+N in Ghostty/Terminal/iTerm — don't close the current one). This new window will load the OLD `.zshrc` until we apply, then the NEW one.

- [ ] **Step 4: Apply in the current (old-zshrc-cached) terminal**

```bash
cd ~/.local/share/chezmoi
chezmoi apply
```

Expected: applies the new `dot_zshrc` to `~/.zshrc`. No error.

- [ ] **Step 5: In the NEW terminal, run a fresh shell**

In the second window:

```bash
exec zsh
echo "PROMPT works"
which starship && starship --version
which mise && mise --version
which zoxide && zoxide --version
echo "EDITOR=$EDITOR"   # Expect: nano
echo "PNPM_HOME=$PNPM_HOME"   # Expect: $HOME/Library/pnpm
echo "SSH_AUTH_SOCK=$SSH_AUTH_SOCK"   # Expect: $HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

Expected: prompt renders, all five tool versions print, env vars are set correctly.

- [ ] **Step 6: Verify aliases work in the new shell**

```bash
type cz   # Expect: cz is an alias for chezmoi
type cd   # Expect: cd is an alias for z
type lsa  # Expect: lsa is an alias for eza -la
```

Expected: each `type` output identifies the alias. If "not found" — `.zsh_aliases` isn't being sourced; check `shared.zsh` step 2 in Task 5.

- [ ] **Step 7: Run a non-interactive test from the OLD terminal**

```bash
zsh -i -c "echo OK; type cz; echo \$EDITOR; exit"
```

Expected: prints `OK`, alias info, `nano`, exits 0.

- [ ] **Step 8: If any of the above fails — rollback**

```bash
# In the OLD terminal:
cd ~/.local/share/chezmoi
git revert HEAD
chezmoi apply
exec zsh
```

Then debug what was missing from the fragments before retrying.

- [ ] **Step 9: Commit (only if all verifications pass)**

```bash
git add dot_zshrc
git commit -m "feat(zsh): replace dot_zshrc with thin loader (sources ~/.zsh/{shared,os}.zsh)"
git push origin main
```

---

## Task 8: Initialize chezmoi on CachyOS

**Files:**
- Created on CachyOS: `~/.local/share/chezmoi/` (full clone of repo)
- Modified on CachyOS: `~/.zshrc` (replaced by thin loader via apply)
- Created on CachyOS: `~/.zsh/{shared,linux}.zsh` (darwin.zsh NOT created because `.chezmoiignore.tmpl` would filter it… actually wait — `dot_zsh/darwin.zsh` is INSIDE `dot_zsh/`, not in `.config/aerospace/` etc. The ignore template doesn't list `dot_zsh/darwin.zsh` for Linux. So `darwin.zsh` WILL be created on Linux but the loader's `case $(uname -s)` won't source it.) **Decision:** That's fine — having a dormant `darwin.zsh` on Linux doesn't hurt; loader skips it. No need to add it to `.chezmoiignore.tmpl`. Move on.

**Context:** This is the moment of truth on CachyOS — first `chezmoi init --apply`. With the templated `.chezmoiignore.tmpl`, only Linux-relevant files should land.

- [ ] **Step 1: [CachyOS] Verify chezmoi is installed (was a bootstrap step but may not have completed)**

```bash
ssh nazarf@nazarf-cachyos 'command -v chezmoi && chezmoi --version'
```

Expected: path printed, version line. If "not found":

```bash
ssh nazarf@nazarf-cachyos 'sudo pacman -S --needed --noconfirm chezmoi && chezmoi --version'
```

- [ ] **Step 2: [CachyOS] Confirm there's no existing chezmoi source**

```bash
ssh nazarf@nazarf-cachyos 'ls -la ~/.local/share/chezmoi 2>&1 || echo "(does not exist — good)"'
```

Expected: `(does not exist — good)`. If it exists with content from a prior incomplete init, archive it:

```bash
ssh nazarf@nazarf-cachyos 'mv ~/.local/share/chezmoi ~/.local/share/chezmoi.abandoned-$(date +%s) 2>&1'
```

- [ ] **Step 3: [CachyOS] Initialize chezmoi without apply (clone source only)**

```bash
ssh -t nazarf@nazarf-cachyos 'chezmoi init git@github.com:norens/dotfiles.git'
```

(`-t` for TTY in case GitHub SSH prompts for first-connection accept.)

Expected: clones the repo. SSH-to-GitHub uses 1P agent (assuming 1Password Linux is installed + agent socket exists). If "Permission denied (publickey)" — 1Password CLI/desktop not yet on CachyOS; install with `paru -S 1password 1password-cli`, then retry. Alternative: use HTTPS clone `chezmoi init https://github.com/norens/dotfiles.git` (read-only — fine for now).

- [ ] **Step 4: [CachyOS] `chezmoi diff` — review what would change BEFORE applying**

```bash
ssh nazarf@nazarf-cachyos 'chezmoi diff' | tee /tmp/cachyos-chezmoi-diff.txt
wc -l /tmp/cachyos-chezmoi-diff.txt
```

Expected: diff output shows:
- New files: `~/.zshrc` (will be replaced by thin loader), `~/.zsh/shared.zsh`, `~/.zsh/linux.zsh`, `~/.zsh/darwin.zsh` (dormant), `~/.ssh/config` (from template), `~/.gitconfig`, `~/.config/starship.toml`, `~/.config/mise/config.toml`, `~/.config/lazygit/config.yml`, `~/.config/git/{ignore,allowed_signers}`, `~/CLAUDE.md`, `~/HOTKEYS.md`, etc.
- NOT in diff: anything under `~/.config/aerospace`, `~/.config/karabiner`, `~/.config/goku`, `~/.config/sketchybar`, `~/Library/*`, `~/.config/restic`, `~/.config/gh`. These are macOS-only per `.chezmoiignore.tmpl`.

**STOP and read the diff carefully.** If any macOS-specific file is about to land on CachyOS, the `.chezmoiignore.tmpl` is wrong — abort apply, fix template on MacBook, push, `chezmoi update` on CachyOS, re-diff.

- [ ] **Step 5: [CachyOS] Apply chezmoi**

```bash
ssh nazarf@nazarf-cachyos 'chezmoi apply -v 2>&1' | tee /tmp/cachyos-chezmoi-apply.log
```

Expected: verbose action log showing each file created/modified. No "permission denied" or "error" lines.

- [ ] **Step 6: [CachyOS] Verify new shell loads cleanly**

```bash
ssh nazarf@nazarf-cachyos 'zsh -i -c "echo OK; uname -s; which starship; echo HF_HOME=\$HF_HOME"'
```

Expected: `OK`, `Linux`, starship path, `HF_HOME=` (EMPTY because `linux.zsh` doesn't have the ML env block yet — we add it in Task 9).

- [ ] **Step 7: [CachyOS] Verify `chezmoi managed` shows correct count**

```bash
ssh nazarf@nazarf-cachyos 'chezmoi managed | wc -l'
```

Expected: substantially fewer than 130 — roughly 30-40 (the cross-OS subset plus the dormant `darwin.zsh`). Exact number doesn't matter; verifying it's NOT 130 confirms the ignore template did its job.

- [ ] **Step 8: [CachyOS] Verify SSH still works (test against GitHub)**

```bash
ssh nazarf@nazarf-cachyos 'ssh -T git@github.com 2>&1'
```

Expected: `Hi norens! You've successfully authenticated`. If "Permission denied" — `.ssh/config` template rendered wrong on Linux; investigate the `IdentityAgent` path (Step 3 of Task 4).

- [ ] **Step 9: STATUS update + commit on MacBook**

On MacBook, update `docs/cachyos-setup/STATUS.md` Bootstrap section to mark chezmoi as initialized on CachyOS. Commit:

```bash
cd ~/.local/share/chezmoi
# (edit STATUS.md to note CachyOS chezmoi init + apply done)
git add docs/cachyos-setup/STATUS.md
git commit -m "docs(cachyos): chezmoi initialized and applied on CachyOS"
git push origin main
```

---

## Task 9: Lift CachyOS Linux-specific bits into `linux.zsh`

**Files:**
- Modify: `~/.local/share/chezmoi/dot_zsh/linux.zsh` (populate from CachyOS backup)

**Context:** After Task 8, the new CachyOS `~/.zshrc` is the thin loader sourcing the (mostly empty) `linux.zsh`. The original CachyOS zshrc had Linux-specific things: ML env vars (added in Plan 1), fzf source path, zsh-syntax-highlighting from `/usr/share/`, etc. Lift those into `linux.zsh` from the backup at `~/.zshrc.bak-pre-cross-os-migration`.

- [ ] **Step 1: [CachyOS] Read the backup file to see what Linux-specific content needs lifting**

```bash
ssh nazarf@nazarf-cachyos 'cat ~/.zshrc.bak-pre-cross-os-migration'
```

Save the output to a scratch file on MacBook for reference:

```bash
ssh nazarf@nazarf-cachyos 'cat ~/.zshrc.bak-pre-cross-os-migration' > /tmp/cachyos-old-zshrc.txt
wc -l /tmp/cachyos-old-zshrc.txt
```

Expected: ~90 lines.

- [ ] **Step 2: Identify which lines are NOT already in `shared.zsh` and need to land in `linux.zsh`**

Open `/tmp/cachyos-old-zshrc.txt` and identify lines specific to Linux:

- `export EDITOR=nvim` / `export VISUAL=nvim` (CachyOS preference per CachyOS bootstrap)
- `source /usr/share/fzf/key-bindings.zsh`
- `source /usr/share/fzf/completion.zsh`
- `source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh` (or wherever Linux plugin is — confirm by `ls /usr/share/zsh/plugins/` on CachyOS)
- ML env block: `HF_HOME`, `TRANSFORMERS_CACHE`, `HF_DATASETS_CACHE`, `PODMAN_USERNS`
- Any `npm-global` PATH entries (saw `~/.npm-global/bin` in earlier scan)

Lines in CachyOS backup that overlap with `shared.zsh` (already moved): history setopts, starship/zoxide/mise/direnv/atuin inits, FZF_DEFAULT_OPTS theme. Skip these — already covered.

- [ ] **Step 3: Write `dot_zsh/linux.zsh` with these contents on MacBook**

```bash
cat > ~/.local/share/chezmoi/dot_zsh/linux.zsh <<'EOF'
# ~/.zsh/linux.zsh — Linux-only shell config sourced by ~/.zshrc loader
# when uname -s = "Linux". Managed by chezmoi.

# --- Editor (Linux uses nvim instead of nano) ---
export EDITOR=nvim
export VISUAL=nvim

# --- fzf keybindings (Linux package path) ---
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/fzf/completion.zsh ]   && source /usr/share/fzf/completion.zsh

# --- zsh plugins (Linux package paths — installed via pacman) ---
[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] \
  && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] \
  && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# --- npm-global (Linux user-level npm prefix) ---
export PATH="$HOME/.npm-global/bin:$PATH"

# --- ML / HuggingFace cache redirection ---
# Spec: docs/cachyos-setup/specs/2026-05-24-ml-robotics-stack-design.md §2
export HF_HOME="$HOME/ml-data/hf-cache"
export TRANSFORMERS_CACHE="$HF_HOME/hub"
export HF_DATASETS_CACHE="$HF_HOME/datasets"

# --- Podman rootless: explicit userns for predictable UID mapping ---
export PODMAN_USERNS="keep-id"
EOF
```

**Adjust** if Step 2 found additional Linux-specific lines not in this template — add them before committing.

- [ ] **Step 4: Commit on MacBook**

```bash
cd ~/.local/share/chezmoi
git add dot_zsh/linux.zsh
git commit -m "feat(zsh): populate linux.zsh from CachyOS-specific bits + Plan-1 ML env"
git push origin main
```

- [ ] **Step 5: [CachyOS] Pull and apply**

```bash
ssh nazarf@nazarf-cachyos 'chezmoi update -v 2>&1 | tail -10'
```

Expected: pulls latest commit, applies `~/.zsh/linux.zsh`.

- [ ] **Step 6: [CachyOS] Verify env in fresh shell**

```bash
ssh nazarf@nazarf-cachyos 'zsh -i -c "echo HF_HOME=\$HF_HOME; echo EDITOR=\$EDITOR; echo PODMAN_USERNS=\$PODMAN_USERNS; type fzf-cd-widget"'
```

Expected:
- `HF_HOME=/home/nazarf/ml-data/hf-cache`
- `EDITOR=nvim`
- `PODMAN_USERNS=keep-id`
- `fzf-cd-widget is a shell function` (proves fzf key-bindings sourced)

- [ ] **Step 7: [CachyOS] Confirm Ollama service still active (Quadlet path unchanged)**

```bash
ssh nazarf@nazarf-cachyos 'systemctl --user is-active ollama.service && podman ps --filter name=ollama'
```

Expected: `active` + container `Up`. Quadlet file at `~/.config/containers/systemd/ollama.container` wasn't touched by this task, so service is unaffected.

---

## Task 10: Promote `ollama.container` + `storage.conf` into chezmoi

**Files:**
- Create in chezmoi: `dot_config/containers/systemd/ollama.container`
- Create in chezmoi: `dot_config/containers/storage.conf`
- These paths are guarded by `.chezmoiignore.tmpl`'s `.config/containers` line — present on Linux, hidden on macOS.

**Context:** Plan 1 wrote these directly on CachyOS without chezmoi. Now that Linux-only paths are first-class in the repo, promote them so they're version-controlled and reproducible on a fresh CachyOS install.

- [ ] **Step 1: [CachyOS] Verify the files exist and look as expected**

```bash
ssh nazarf@nazarf-cachyos 'ls -la ~/.config/containers/systemd/ollama.container ~/.config/containers/storage.conf && echo "---" && head -5 ~/.config/containers/systemd/ollama.container'
```

Expected: both files exist; ollama.container starts with the Plan 1 header comment.

- [ ] **Step 2: [CachyOS] Add ollama.container to chezmoi (source)**

```bash
ssh nazarf@nazarf-cachyos 'chezmoi add ~/.config/containers/systemd/ollama.container'
ssh nazarf@nazarf-cachyos 'ls ~/.local/share/chezmoi/dot_config/containers/systemd/'
```

Expected: `ollama.container` appears in chezmoi source dir on CachyOS.

- [ ] **Step 3: [CachyOS] Add storage.conf**

```bash
ssh nazarf@nazarf-cachyos 'chezmoi add ~/.config/containers/storage.conf'
ssh nazarf@nazarf-cachyos 'ls ~/.local/share/chezmoi/dot_config/containers/'
```

Expected: `storage.conf` and `systemd/` listed.

- [ ] **Step 4: [CachyOS] Commit and push from CachyOS chezmoi source**

```bash
ssh -t nazarf@nazarf-cachyos 'cd ~/.local/share/chezmoi && git status'
```

Expected: shows two new files. Then:

```bash
ssh -t nazarf@nazarf-cachyos 'cd ~/.local/share/chezmoi && git add -A && git commit -m "feat(containers): promote ollama.container + storage.conf into chezmoi" && git push origin main'
```

(`-t` because 1P agent will prompt for Touch ID on the push if GPG signing is enabled on CachyOS git.)

- [ ] **Step 5: MacBook — pull the change**

```bash
cd ~/.local/share/chezmoi
git pull origin main
ls dot_config/containers/
```

Expected: pulled commit, `systemd/ollama.container` + `storage.conf` present.

- [ ] **Step 6: MacBook — verify `.chezmoiignore.tmpl` blocks these on macOS**

```bash
chezmoi diff
chezmoi managed | grep -E '^\.config/containers' || echo "(correctly ignored on macOS — none managed)"
```

Expected: `chezmoi diff` is empty (no changes proposed on macOS); `chezmoi managed` does not list `.config/containers/*`.

---

## Task 11: Update bootstrap scripts

**Files:**
- Modify: `~/.local/share/chezmoi/docs/cachyos-setup/scripts/00-bootstrap.sh`
- Create: `~/.local/share/chezmoi/scripts/bootstrap-macos.sh`

**Context:** The original CachyOS bootstrap script tried `chezmoi init --apply git@…` but failed silently. Now that the templated `.chezmoiignore.tmpl` makes that command safe, update the script to point at it explicitly. Also create a parallel macOS bootstrap so a fresh Mac is one command away from a working state.

- [ ] **Step 1: Find the chezmoi section in `00-bootstrap.sh`**

```bash
cd ~/.local/share/chezmoi
grep -n 'chezmoi' docs/cachyos-setup/scripts/00-bootstrap.sh
```

Note the line numbers of the chezmoi-related block.

- [ ] **Step 2: Replace the chezmoi block with the working command**

Edit `docs/cachyos-setup/scripts/00-bootstrap.sh`. Find the existing chezmoi block (likely a section labeled `# Install chezmoi + clone dotfiles` or similar) and replace it with:

```bash
# ---------- chezmoi ----------

log "Installing chezmoi..."
if ! command -v chezmoi >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm chezmoi
fi

log "Bootstrapping dotfiles via chezmoi init --apply..."
log "  (.chezmoiignore.tmpl filters out macOS-only paths.)"
log "  Source: github.com/norens/dotfiles"
chezmoi init --apply git@github.com:norens/dotfiles.git || {
  warn "chezmoi init failed. Common reasons:"
  warn "  - 1Password SSH agent not running (run '1password' to launch GUI + sign in)"
  warn "  - GitHub SSH key not registered on this machine yet"
  warn "Fallback: chezmoi init --apply https://github.com/norens/dotfiles.git (read-only, OK for now)"
  exit 1
}
log "chezmoi apply complete. Open a NEW shell to load the new ~/.zshrc."
```

- [ ] **Step 3: Create `scripts/bootstrap-macos.sh`**

```bash
cat > ~/.local/share/chezmoi/scripts/bootstrap-macos.sh <<'EOF'
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
EOF

chmod +x ~/.local/share/chezmoi/scripts/bootstrap-macos.sh
ls -la ~/.local/share/chezmoi/scripts/bootstrap-macos.sh
```

Expected: file exists, executable.

- [ ] **Step 4: Commit both script changes**

```bash
cd ~/.local/share/chezmoi
git add docs/cachyos-setup/scripts/00-bootstrap.sh scripts/bootstrap-macos.sh
git commit -m "feat(bootstrap): update CachyOS script + add macOS bootstrap (chezmoi init --apply)"
git push origin main
```

---

## Task 12: Final verification suite (both machines)

**Files:**
- Modify: `docs/cross-os-chezmoi/specs/...` only if test reveals an inconsistency to document; otherwise no file changes.

**Context:** Run §8 tests from the spec across both machines and confirm everything's green before declaring migration done.

- [ ] **Step 1: MacBook — `chezmoi diff` clean**

```bash
cd ~/.local/share/chezmoi
chezmoi diff
```

Expected: empty output.

- [ ] **Step 2: [CachyOS] — `chezmoi diff` clean**

```bash
ssh nazarf@nazarf-cachyos 'chezmoi diff'
```

Expected: empty output.

- [ ] **Step 3: Fresh shell init both**

```bash
zsh -i -c "echo OK; exit"
ssh nazarf@nazarf-cachyos 'zsh -i -c "echo OK; exit"'
```

Expected: both print `OK` and exit 0.

- [ ] **Step 4: Tool inits**

```bash
for tool in starship zoxide mise atuin direnv; do
  echo "--- $tool ---"
  zsh -i -c "$tool --version" 2>&1 | head -1
  ssh nazarf@nazarf-cachyos "zsh -i -c '$tool --version'" 2>&1 | head -1
done
```

Expected: each tool reports a version from both machines.

- [ ] **Step 5: macOS-only tools (MacBook only)**

```bash
zsh -i -c "brew --version" | head -1
zsh -i -c "command -v aerospace && aerospace --version"
zsh -i -c "command -v goku && goku -v"
```

Expected: brew + aerospace + goku all available.

- [ ] **Step 6: Linux-only env (CachyOS only)**

```bash
ssh nazarf@nazarf-cachyos 'zsh -i -c "echo HF_HOME=\$HF_HOME; echo PODMAN_USERNS=\$PODMAN_USERNS; echo EDITOR=\$EDITOR"'
```

Expected: `HF_HOME=/home/nazarf/ml-data/hf-cache`, `PODMAN_USERNS=keep-id`, `EDITOR=nvim`.

- [ ] **Step 7: `chezmoi managed` count both**

```bash
echo "--- MacBook ---"
chezmoi managed | wc -l
echo "--- CachyOS ---"
ssh nazarf@nazarf-cachyos 'chezmoi managed | wc -l'
```

Expected: MacBook ~134 (130 baseline + 4 new in `dot_zsh/` and `containers/`); CachyOS ~35-40 (cross-OS subset). Confirm CachyOS is MUCH smaller than MacBook — that proves the ignore template is working.

- [ ] **Step 8: Existing services still alive on CachyOS**

```bash
ssh nazarf@nazarf-cachyos 'systemctl --user is-active ollama.service && podman ps --filter name=ollama'
```

Expected: `active` + Ollama container `Up`.

- [ ] **Step 9: Git SSH signing test (both)**

```bash
# MacBook:
cd /tmp && mkdir -p chezmoi-test && cd chezmoi-test
git init -q
echo test > t
git add t
git commit -m "test signing" -S
git log -1 --show-signature 2>&1 | head -5
cd ~ && rm -rf /tmp/chezmoi-test

# CachyOS — only if 1Password Linux is installed and configured:
ssh nazarf@nazarf-cachyos 'cd /tmp && mkdir -p chezmoi-test && cd chezmoi-test && git init -q && echo test > t && git add t && git commit -m "test signing" -S 2>&1 | head -5; cd ~ && rm -rf /tmp/chezmoi-test'
```

Expected: macOS shows `Good "git" signature for nazarfedishin@gmail.com`. CachyOS may not yet have signing configured — if it errors, note as "Linux signing setup is a future task" and don't block migration.

- [ ] **Step 10: Verify ignore correctness — neither machine has the wrong files**

```bash
# MacBook should NOT manage any Linux-only path:
chezmoi managed | grep -E '^\.config/(hypr|waybar|mako|kanata|containers)' || echo "OK — no Linux-only paths managed on MacBook"

# CachyOS should NOT manage any macOS-only path:
ssh nazarf@nazarf-cachyos 'chezmoi managed | grep -E "^(\\.config/(aerospace|karabiner|goku|sketchybar|jetbrains-keymaps|restic|gh)|Library)" || echo "OK — no macOS-only paths managed on CachyOS"'
```

Expected: both print `OK — no … managed`.

- [ ] **Step 11: Final STATUS update + commit**

Update `docs/cachyos-setup/STATUS.md` (Bootstrap section) noting chezmoi cross-OS migration complete. Also create a brief entry in `docs/cross-os-chezmoi/STATUS.md` (new file) summarizing the outcome.

```bash
cd ~/.local/share/chezmoi
# Edit STATUS files
git add docs/cachyos-setup/STATUS.md docs/cross-os-chezmoi/STATUS.md
git commit -m "docs: cross-OS chezmoi migration complete (Plan 2 done)"
git push origin main
```

---

## Success criteria — migration is "done" when:

1. `chezmoi diff` empty on both machines.
2. `zsh -i -c "echo OK"` exits 0 on both machines.
3. `chezmoi managed | wc -l` on CachyOS is substantially smaller than on MacBook (proves ignore template working).
4. macOS still has working aerospace/karabiner/sketchybar (no regressions to existing setup).
5. CachyOS has working Hyprland session, `HF_HOME` set, Ollama service `active`.
6. Bootstrap scripts (`scripts/bootstrap-macos.sh` + `docs/cachyos-setup/scripts/00-bootstrap.sh`) reference the new `chezmoi init --apply` flow.
7. `ollama.container` + `storage.conf` are in the chezmoi repo, applied on CachyOS, ignored on macOS.
8. SSH to GitHub works from both machines after `chezmoi apply` (1Password agent socket correctly resolved per OS).

---

## Rollback procedures (if any task fails catastrophically)

### MacBook shell broken after Task 7 (zshrc thin loader)

In the OLD terminal (still has old shell loaded):

```bash
cd ~/.local/share/chezmoi
git revert HEAD
chezmoi apply --force
```

If git is also broken: `cp -r ~/.local/share/chezmoi.bak-pre-cross-os/* ~/.local/share/chezmoi/; chezmoi apply --force`.

### CachyOS shell broken after Task 8 (first chezmoi apply)

1. SSH from MacBook still works (sshd doesn't depend on user shell).
2. From MacBook:

```bash
ssh nazarf@nazarf-cachyos 'bash -c "cp ~/.zshrc.bak-pre-cross-os-migration ~/.zshrc && chezmoi unmanaged ~/.zshrc 2>&1 || true"'
```

3. Investigate the broken fragment on MacBook; fix in repo; push; on CachyOS `chezmoi update && chezmoi apply`.

### macOS-only file accidentally applied on CachyOS

Means the `.chezmoiignore.tmpl` has a bug.

1. On MacBook, fix the template (add the missing path to the `{{ if ne .chezmoi.os "darwin" }}` block); commit; push.
2. On CachyOS: `chezmoi update` (pulls the fix), then `rm` the wrongly-applied file manually (chezmoi won't auto-remove unmanaged-now files; use `chezmoi forget` to deregister from source).

### Bad `.ssh/config` template breaks SSH

Login via TTY (Ctrl+Alt+F2 at CachyOS keyboard) or via the still-cached MacBook ControlMaster connection. Restore old `.ssh/config` from `~/.ssh/config` if backed up, or use `chezmoi apply --force` after fixing the template on MacBook.
