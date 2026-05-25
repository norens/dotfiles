# Cross-OS chezmoi Templating — Design

**Date:** 2026-05-25
**Status:** Draft, awaiting user review
**Scope:** Single chezmoi source repo (`norens/dotfiles`) serving both macOS (MacBook) and Linux (CachyOS PC). Future-ready for additional machines.
**Approach:** Minimal viable migration (~30 files) + modular sourced fragments for `.zshrc`.

This design retires the deferred "Cross-OS chezmoi templating" sub-project. After completion, new Linux-only configs (Hyprland, kanata, Waybar — written in Plan 2 Desktop UX) and macOS-only configs land in the same repo without conflict.

---

## 1. Scope

### In scope (this iteration)

- Add templating infrastructure to existing repo: `.chezmoiignore.tmpl` with OS guards, modular `~/.zsh/` directory.
- Migrate ~30 files (out of 130 managed) — those needed for CachyOS to apply cleanly without breaking macOS.
- Establish file-classification conventions (taxonomy of buckets A-F, §4 below).
- Modular shell architecture: `dot_zshrc` thin loader → `dot_zsh/{shared,darwin,linux}.zsh`.
- Update bootstrap scripts (`docs/cachyos-setup/scripts/00-bootstrap.sh` + a new `scripts/bootstrap-macos.sh`) to use `chezmoi init --apply`.
- Verify `chezmoi diff` clean on both machines after migration.
- Promote into chezmoi the inline-only files added on CachyOS during Plan 1 (Ollama Quadlet, `containers/storage.conf`, ML env block).

### Out of scope (later or separate)

- **Brewfile vs Pacman list parity** — distinct package-manager strategies; needs its own design.
- **Linux-only configs not yet created** — Hyprland, Waybar, mako, kanata. They land in the repo when Plan 2 Desktop UX writes them, using the conventions established here.
- **Per-host (machine-specific) `chezmoi.toml [data]`** — adopt when a 3rd machine joins, not before.
- **Secrets via `onepasswordRead`** — deferred until a template actually needs a secret (no current candidate).
- **Migration of `cachyos-setup-tasks.md`** from `~/` to `docs/cachyos-setup/` — cosmetic, separate cleanup.
- **`Library/Preferences/com.apple.HIToolbox.plist`** — input-source bplist; tracked but binary, no templating sense. Keep as-is, guard from Linux via chezmoiignore.

---

## 2. File taxonomy

130 currently-managed files fall into six buckets. Action per bucket is the same across files in that bucket.

### Bucket A — Pure shared (no templating)

Identical on both OSes; kept as plain (no `.tmpl` extension).

- `.config/starship.toml`
- `.config/mise/config.toml`
- `.config/lazygit/config.yml`
- `.config/git/ignore`
- `.config/git/allowed_signers`
- `.gitconfig` (signing key is platform-neutral SSH reference)
- `.gitignore`
- `CLAUDE.md`, `HOTKEYS.md`, `README.md`
- `docs/**`
- `scripts/merge_pr.sh`, `scripts/script_manager.sh`
- `cachyos-setup-tasks.md`

### Bucket B — Shared with minimal templating

≥80% shared with a small OS-specific snippet. Convert to `.tmpl` with a single conditional block.

- `.ssh/config` → `IdentityAgent` differs: macOS uses `~/Library/Group Containers/.../Agent`, Linux uses `~/.1password/agent.sock` (or none). One `{{ if eq .chezmoi.os "darwin" }}…{{ else }}…{{ end }}` block. **MUST be converted before CachyOS apply** — otherwise broken socket path lands on Linux.
- `.config/sesh/sesh.toml` → project-dir source paths differ (`~/IdeaProjects` only exists on macOS; CachyOS may use different layout). Small `if` block.
- `.tmux.conf` → predominantly shared (vi keys, TPM); any macOS-specific clipboard binds (`pbcopy`/`pbpaste`) go in a small `if`. Plain until first real diff surfaces.
- `.config/ghostty/config` → likely 95% shared; if any Linux-vs-macOS diff appears (font fallback, theme path), add small `if`. Defer .tmpl conversion until first real diff surfaces; until then plain.

### Bucket C — macOS-only (guarded via .chezmoiignore on Linux)

- `.config/aerospace/`
- `.config/karabiner/`
- `.config/goku/`
- `.config/sketchybar/`
- `.config/jetbrains-keymaps/`
- `Library/LaunchAgents/`
- `Library/Preferences/`
- `.config/restic/` (driven by LaunchAgent which is macOS-only; restic itself works on Linux but our current backup setup is macOS-bound)
- `scripts/setup.sh` (macOS-specific bootstrap)
- `.config/gh/config.yml` (no harm sharing, but keep simple — macOS-only for now)
- `.config/ghostty/shaders/` (Ghostty only on macOS currently; if installed on CachyOS later, revisit)

### Bucket D — Linux-only (guarded via .chezmoiignore on Darwin)

Currently empty in the repo (nothing tracked yet). Will be populated as Plan 2 Desktop UX writes configs:

- `.config/hypr/` (Hyprland)
- `.config/waybar/`
- `.config/mako/`
- `.config/kanata/`
- `.config/containers/systemd/ollama.container` (promote from CachyOS local file)
- `.config/containers/storage.conf` (promote from CachyOS local file)

### Bucket E — Split via modular fragments

Files almost entirely different per OS. Replace single file with thin loader + per-OS fragments.

- `.zshrc` — primary case; see §4.

`.tmux.conf`, `.zsh_aliases`, `.config/ghostty/config` are NOT in this bucket — they're predominantly shared (B-style, not E-style). Keep them as single files; add small `.tmpl` conditionals only if/when a real diff appears.

### Bucket F — Decide case-by-case

- `.tmux/plugins/tmux-ghostty-theme/` — currently committed as a snapshot. Could become a git submodule, but no functional reason now. Stay as snapshot, guard from Linux (Ghostty-tied).

---

## 3. Templating conventions

| Convention | Choice | Rationale |
|---|---|---|
| File suffix | `.tmpl` for templated, plain otherwise | chezmoi default |
| OS detection | `{{ if eq .chezmoi.os "darwin" }}` / `{{ else if eq .chezmoi.os "linux" }}` | Built-in, no extra config |
| Per-host data | `~/.config/chezmoi/chezmoi.toml` `[data]` block | Per-machine runtime values stay out of repo |
| Secrets | `onepasswordRead` template func | Defer to first need |
| Wholesale dir skip | `.chezmoiignore.tmpl` lists paths per-OS | Cleaner than per-file ignore |
| `dot_` prefix | Already used; keep | Existing convention |
| `private_` prefix (mode 0600) | Already used for `.ssh/`; keep | Existing convention |

### `.chezmoiignore.tmpl` (canonical template)

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

---

## 4. ZSH modular architecture

### Repo source layout (chezmoi)

```
dot_zshrc                ← thin loader, plain (no .tmpl)
dot_zsh/
├── shared.zsh           ← cross-OS: history, completion, options, tool inits
├── darwin.zsh           ← macOS-only: brew, /usr/local/share, macOS aliases
└── linux.zsh            ← Linux-only: /usr/share/fzf, HF_HOME, Podman, Linux aliases
```

### `dot_zshrc` (thin loader)

```sh
# ~/.zshrc — thin loader; real config in ~/.zsh/{shared,darwin,linux}.zsh
# Managed by chezmoi. Do not add config logic here; add it to the appropriate
# fragment under ~/.zsh/.

ZSH_DIR="${ZDOTDIR:-$HOME}/.zsh"

# 1. Shared (history, completion, basic options, cross-OS tool inits)
[ -f "$ZSH_DIR/shared.zsh" ] && source "$ZSH_DIR/shared.zsh"

# 2. OS-specific
case "$(uname -s)" in
  Darwin) [ -f "$ZSH_DIR/darwin.zsh" ] && source "$ZSH_DIR/darwin.zsh" ;;
  Linux)  [ -f "$ZSH_DIR/linux.zsh" ]  && source "$ZSH_DIR/linux.zsh" ;;
esac

# 3. Host-local override (optional, NOT chezmoi-tracked, in .gitignore)
[ -f "$ZSH_DIR/local.zsh" ] && source "$ZSH_DIR/local.zsh"
```

`uname -s` at runtime instead of chezmoi templating: simpler, shell-portable, no `.tmpl` rendering needed for this entrypoint.

### Decomposition of current macOS `~/.zshrc`

| Current section | Lands in |
|---|---|
| `set -o vi` | `shared.zsh` |
| `export GOKU_EDN_CONFIG_FILE` | `darwin.zsh` |
| `. ~/.zsh_aliases` | `shared.zsh` (`.zsh_aliases` stays as a single file, sourced as-is) |
| `eval "$(/usr/local/bin/brew shellenv)"` + `FPATH` brew completions | `darwin.zsh` |
| `source /usr/local/share/zsh-{autosuggestions,syntax-highlighting}/...` | `darwin.zsh` |
| `compinit` + `zstyle ':completion:*'` blocks | `shared.zsh` |
| `PATH` cross-OS (`$HOME/.local/bin`, `.cargo/bin`, `go/bin`, `bin`) | `shared.zsh` |
| `PATH` macOS-specific brew tools | `darwin.zsh` |
| `eval "$(starship init zsh)"` | `shared.zsh` |
| `eval "$(zoxide init zsh)"`, `eval "$(mise activate zsh)"`, `eval "$(atuin init zsh ...)"`, `eval "$(direnv hook zsh)"` | `shared.zsh` |
| `MANPAGER`, `LESS`, `EDITOR`, `VISUAL`, `PAGER` | Mostly `shared.zsh`. `EDITOR`/`VISUAL`: macOS = `nano`, Linux = `nvim` → land in respective per-OS files. |
| Aliases macOS-specific (e.g. `pbcopy`) | `darwin.zsh` |

### Decomposition of current CachyOS `~/.zshrc`

| Current section | Lands in |
|---|---|
| `HISTFILE`/`HISTSIZE`/setopt history blocks | `shared.zsh` (single canonical source) |
| `setopt AUTO_CD AUTO_PUSHD …` behavior | `shared.zsh` |
| `compinit` + zstyle | `shared.zsh` |
| `export EDITOR=nvim` / `VISUAL=nvim` | `linux.zsh` |
| `export PAGER=less` + `LESS='-R …'` + `MANPAGER` | `shared.zsh` |
| `eval starship/zoxide/mise/direnv/atuin` | `shared.zsh` (overlap with macOS — single source) |
| `source /usr/share/fzf/key-bindings.zsh` | `linux.zsh` |
| `FZF_DEFAULT_OPTS` + `FZF_*_COMMAND` | `shared.zsh` (theme is cross-OS) |
| zsh-syntax-highlighting / history-substring-search source (Linux paths) | `linux.zsh` |
| ML env block (`HF_HOME`, `TRANSFORMERS_CACHE`, `HF_DATASETS_CACHE`, `PODMAN_USERNS`) | `linux.zsh` |

### `.zsh/local.zsh` opt-out

A host-specific file at `~/.zsh/local.zsh` (in `.gitignore`, never tracked) lets one machine override anything from `shared`/`darwin`/`linux` without polluting the repo. Used only when needed.

---

## 5. Migration strategy

**Incremental file-by-file commits with verify after each.** Never push without `zsh -i -c "echo OK"` passing on at least the active OS.

1. **Backups** before any apply:
   - MacBook: `cp -r ~/.local/share/chezmoi ~/.local/share/chezmoi.bak-pre-cross-os`
   - CachyOS: existing `~/.zshrc.bak-pre-ml-env` from Plan 1; add `cp ~/.zshrc ~/.zshrc.bak-pre-cross-os-migration`
2. **Add infrastructure commits FIRST** (no behavior change):
   - Commit 1: `.chezmoiignore.tmpl` replacing plain `.chezmoiignore`
   - Commit 2: Empty `dot_zsh/{shared,darwin,linux}.zsh` skeletons
3. **Verify on MacBook after each commit**: `chezmoi diff` shows only the new file additions; `chezmoi apply` succeeds; `zsh -i -c "echo OK"` returns OK.
4. **File-by-file decomposition of `.zshrc`**, one commit per logical section:
   - Move history setopts → `shared.zsh` (commit; verify)
   - Move tool inits → `shared.zsh` (commit; verify)
   - Move brew/macOS paths → `darwin.zsh` (commit; verify)
   - … continue until `dot_zshrc` is the thin loader from §4
   - Final commit replaces `dot_zshrc` content with loader stub
5. **Convert Bucket B files to `.tmpl` BEFORE first CachyOS apply** — otherwise platform-specific paths (e.g. macOS `IdentityAgent` socket in `.ssh/config`) would land on Linux verbatim and break SSH agent. Per file: rename to `.tmpl`, wrap the platform-specific lines in `{{ if eq .chezmoi.os "darwin" }}…{{ end }}` or `{{ else }}…{{ end }}` blocks, commit, verify `chezmoi apply` on MacBook still produces an identical `~/.ssh/config`.

   Order: `.ssh/config` first (highest risk if wrong); `.config/sesh/sesh.toml` second; others B-bucket only if/when needed.

6. **Initialize chezmoi on CachyOS**:
   - `pacman -S --needed chezmoi` (likely already there from bootstrap script attempts)
   - `chezmoi init git@github.com:norens/dotfiles.git` (no `--apply` yet)
   - `chezmoi diff` — review what would change
   - Specifically verify the diff DOES NOT include any macOS-only paths (the `.chezmoiignore.tmpl` is working)
   - `chezmoi apply`
   - `zsh -i -c "echo OK"` from a NEW shell
7. **Merge CachyOS-local content into linux.zsh**:
   - `~/.zshrc.bak-pre-cross-os-migration` has the original CachyOS zshrc; lift the Linux-specific bits not yet in `linux.zsh` (anything that wasn't already covered)
   - `chezmoi edit ~/.zsh/linux.zsh` + add; commit; push; `chezmoi update` on CachyOS
8. **Promote inline-only files** into chezmoi:
   - `chezmoi add ~/.config/containers/systemd/ollama.container` (lives under Linux-only path; chezmoiignore'd from macOS)
   - `chezmoi add ~/.config/containers/storage.conf`
   - Commit + push + `chezmoi update` on MacBook to verify it didn't get applied there
9. **Final verification** both machines (§8).

---

## 6. Bootstrap workflow

Update both bootstrap scripts so a fresh machine is one command from a working dotfiles state.

### CachyOS — update `docs/cachyos-setup/scripts/00-bootstrap.sh`

Replace the existing chezmoi step with:

```bash
sudo pacman -S --needed --noconfirm chezmoi
chezmoi init --apply git@github.com:norens/dotfiles.git
# chezmoi reads .chezmoi.os = "linux" via the templated .chezmoiignore.tmpl
# and skips all macOS-only paths. Only Linux-relevant files land in $HOME.
```

### macOS — create `scripts/bootstrap-macos.sh`

```bash
#!/bin/bash
# Bootstrap a fresh macOS machine from this dotfiles repo.
set -euo pipefail

# Homebrew
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# chezmoi
brew install chezmoi

# Bootstrap dotfiles
chezmoi init --apply git@github.com:norens/dotfiles.git

echo "Done. Open a new shell to activate."
```

Both scripts are intentionally minimal — heavy lifting (Brewfile, kanata, Hyprland) lives in subsequent phase-specific scripts.

---

## 7. Rollback / safety

### macOS shell breaks after `chezmoi apply`

1. Open a fresh terminal that doesn't auto-source `.zshrc` (e.g. `bash --noprofile --norc`).
2. `cp -r ~/.local/share/chezmoi.bak-pre-cross-os ~/.local/share/chezmoi`
3. `chezmoi apply --force` to restore old state.
4. Or: in the chezmoi git repo, `git revert <bad-commit>`, then `chezmoi apply`.

### CachyOS shell breaks

1. Login via TTY (Ctrl+Alt+F2) or SSH from MacBook (sshd doesn't depend on user shell).
2. Start `bash` instead of zsh.
3. `cp ~/.zshrc.bak-pre-cross-os-migration ~/.zshrc` (manual restore).
4. Investigate which source line broke; fix in repo on MacBook; push; `chezmoi update` on CachyOS to re-apply.

### Test gate during `.zshrc` migration

After each commit that touches zsh files: `zsh -i -c "echo OK; exit"` in a subshell. If exit non-zero, the new shell fails to initialize — do not push. Fix in-place, then retry.

### Quadlet service safety

When moving `ollama.container` into chezmoi: the file lives at the same path (`~/.config/containers/systemd/ollama.container`), so `systemctl --user daemon-reload` would detect no change. Verify with `systemctl --user is-active ollama.service` after migration that the service stays `active`.

---

## 8. Testing strategy

| Test | Where | Pass criterion |
|---|---|---|
| `chezmoi diff` after final apply | Both | Empty output |
| New shell init | Both | `zsh -i -c "echo OK"` exits 0 |
| Tool init not broken | Both | `starship`, `zoxide`, `mise`, `atuin`, `direnv` versions printable from a freshly-sourced `.zshrc` |
| macOS-only tools | macOS | `brew --version`, `aerospace --version`, `goku -v` accessible from PATH |
| Linux-only env | CachyOS | `echo $HF_HOME` = `/home/nazarf/ml-data/hf-cache`; `echo $PODMAN_USERNS` = `keep-id` |
| `chezmoi managed` count | Both | Within expected delta of pre-migration (no surprise additions/removals) |
| Existing services | CachyOS | `systemctl --user is-active ollama.service` = `active` |
| Git SSH signing | Both | A test commit succeeds with `git commit -S -m test` (then revert) |
| `chezmoiignore` correctly skips | CachyOS | `chezmoi managed` does NOT list `.config/aerospace/*`, `.config/karabiner/*`, etc. |
| `chezmoiignore` correctly skips | MacBook | `chezmoi managed` does NOT list `.config/hypr/*`, `.config/containers/*`, etc. |

---

## References

- chezmoi templating: <https://www.chezmoi.io/user-guide/templating/>
- chezmoi `.chezmoiignore`: <https://www.chezmoi.io/reference/special-files-and-directories/chezmoiignore/>
- Existing chezmoi setup in this repo: `~/.local/share/chezmoi/CLAUDE.md`, `~/CLAUDE.md`
- Spec context: 130 files currently managed (audit run 2026-05-25), no `.tmpl` files yet, single repo `norens/dotfiles`.
- Sibling work: `docs/cachyos-setup/specs/2026-05-24-ml-robotics-stack-design.md` (Plan 1 added inline Linux configs that this migration will promote into the repo).
