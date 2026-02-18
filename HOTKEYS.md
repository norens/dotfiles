# Hotkeys & Usage Reference

## AeroSpace (Tiling Window Manager)

**super** = `ctrl + alt + cmd`

### Main Mode

| Hotkey | Action |
|---|---|
| `alt-tab` | Toggle between last two workspaces |
| `super + h/j/k/l` | Focus window left/down/up/right |
| `super + shift + h/j/k/l` | Move window left/down/up/right |
| `super + f` | Fullscreen |
| `super + q` | Close window |
| `super + [` / `super + ]` | Focus prev/next monitor |
| `super + shift + [` / `super + shift + ]` | Move window to prev/next monitor |
| `super + 1-9` | Switch to workspace 1-9 |
| `super + shift + 1-9` | Move window to workspace 1-9 |
| `super + w` | Open Ghostty |
| `super + shift + w` | Open new Ghostty instance |
| `super + b` | Open Arc |
| `super + ;` | Enter service mode |

### Service Mode (enter via `super + ;`)

| Hotkey | Action |
|---|---|
| `h/j/k/l` | Resize width/height |
| `/` | Toggle tiles layout |
| `,` | Toggle accordion layout |
| `f` | Toggle floating/tiling |
| `w` | Fullscreen |
| `b` | Balance sizes |
| `esc` or `enter` | Back to main mode |

### Behaviors

- **Mouse follows focus** between monitors automatically
- **SketchyBar updates** on workspace change and window focus change
- IntelliJ auto-moves to workspace 3, Telegram to workspace 4

---

## tmux

**prefix** = `ctrl + b` (default)

### Navigation

| Hotkey | Action |
|---|---|
| `alt + j` / `alt + k` | Previous / next window (no prefix) |
| `prefix + g` | Split horizontal |
| `prefix + b` | Split vertical |
| `prefix + J` / `prefix + K` | Move window left / right |
| `prefix + shift + arrows` | Move pane in direction |
| `prefix + M-y` / `prefix + M-i` | Rotate panes |
| `prefix + @` | Join pane to chosen window |
| `prefix + M-@` | Pull pane from chosen window |
| `prefix + r` | Reload config |

### Ghostty Theme Plugin

tmux status bar colors are **automatically** derived from your active Ghostty theme (`~/.config/ghostty/config` -> `theme = "..."`). Currently using **TokyoNight Storm**.

Options in `~/.tmux.conf`:
- `@ghostty-show-powerline on` — powerline separators
- `@ghostty-transparent-status on` — transparent background
- `@ghostty-left-icon 'none'` — no left icon
- `@ghostty-right-format 'claude-5h | claude-7d'` — Claude usage bars on the right

### Claude Usage Bars (status bar, right side)

Shows Claude Code API usage with colored progress bars:
- **5h bar** — 5-hour rolling limit (countdown to reset)
- **7d bar** — 7-day weekly limit (countdown to reset)
- Colors: gray (<60%), yellow (60-80%), red (>80%)
- Data from macOS Keychain (`Claude Code-credentials`)
- Cached 60s, rate-limited 30s

Manual test: `~/.tmux/plugins/tmux-ghostty-theme/claude-usage.sh 5h`

---

## What Was Added (from wierdbytes/dotfiles)

1. **tmux-ghostty-theme plugin** — reads Ghostty theme file and applies matching colors to tmux (status bar, panes, windows, messages)
2. **claude-usage.sh** — queries Claude API usage via Keychain, renders progress bars in tmux
3. **AeroSpace**: `alt-tab` workspace toggle, mouse follows focus, SketchyBar focus trigger
4. **Removed**: old `scripts/tmux-quota.sh` (replaced by claude-usage.sh)
