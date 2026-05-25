# CachyOS Desktop UX — Design

**Date:** 2026-05-25
**Status:** Draft, awaiting user review
**Scope:** Complete the macOS-feel desktop on CachyOS: kanata keyboard remap, Hyprland status-bar / notifications / idle-lock / wallpaper / screenshot polish, Ukrainian input toggle.
**Tracking:** New Linux-only configs land under `dot_config/{hypr,waybar,mako,kanata,...}` already guarded by `.chezmoiignore.tmpl` from Plan 2.
**Theme:** Gruvbox Dark Hard (locked).

This design closes original `~/cachyos-setup-tasks.md` Phase 3 (Keyboard parity) + parts of Phase 5 (Desktop polish) and inserts Waybar / notifications / idle infrastructure that wasn't in the original 20-task plan.

---

## 1. Scope

### In scope

- **kanata**: Caps→Esc/Ctrl, lAlt→Super (Cmd-analog), rAlt→AltGr. systemd-managed service that survives Keychron K3 KVM unplug/replug.
- **Waybar**: top status bar, single per monitor, Gruvbox-themed. Modules: workspaces · window-title · clock · GPU temp · CPU · memory · network · pulseaudio · tray. (No battery — desktop PC.)
- **Notification daemon**: `swaync` with control-center panel (DND toggle, persistent history).
- **Idle / lock**: `hypridle` policy (5min dim → 10min lock → 30min DPMS off) wired to existing `hyprlock`.
- **Wallpaper**: `swww` daemon serving Gruvbox-themed wallpaper(s) from a curated set.
- **Screenshot**: `hyprshot` (region/window/output) → file + clipboard, optionally piped through `satty` for annotation.
- **Ukrainian input**: Hyprland `kb_layout = us,ua` with `grp:rctrl_toggle` (Right-Ctrl switches layout — no conflict with kanata Caps and Cmd+Space launcher).
- **autostart**: `waybar`, `swaync`, `hypridle`, `swww-daemon` + `swww img <wallpaper>`, `hyprpolkitagent` (GUI sudo prompts), `wl-paste --watch cliphist store` (clipboard history).
- **Theme application**: Gruvbox Dark Hard palette applied consistently across Waybar / swaync / hyprlock / Ghostty / starship / bat (existing) / lazygit (override or accept current Catppuccin).

### Out of scope

- **Walker launcher migration** — keep wofi (already in `hyprland.conf` as `$menu`); revisit when Walker leaves beta.
- **AltTab-style window switcher** — Cmd+Tab cycles via Hyprland `cyclenext`; full thumbnail switcher (`hyprswitch`, `sherlock`) deferred.
- **Per-workspace wallpapers** — single global wallpaper for now.
- **Conky / system-info overlays** — out of scope.
- **Compositor effects (blur, animations)** beyond Hyprland defaults — accept defaults, polish only if performance allows.
- **Migration of macOS Ghostty / lazygit themes to Gruvbox** — separate trivial sub-task if user wants visual parity across machines.
- **Plan 3 Dev IDE** (Cursor / Zed / VSCode + 1Password Linux + git signing setup) — distinct subsequent plan.

---

## 2. kanata — keyboard remap

### Profile (matches macOS Karabiner conventions per `docs/macos-audit/SPEC.md`)

| Physical key | Tap output | Hold output | Rationale |
|---|---|---|---|
| **Caps Lock** | Esc | LCtrl | macOS-style; ergonomic for vim/Emacs |
| **Left Alt** | LSuper | LSuper | Becomes "Cmd-analog" matching `$mainMod=SUPER` in `hyprland.conf` |
| **Right Alt** | RAlt (AltGr) | RAlt | Preserved for umlauts + Ukrainian layout (ŕ, ç, ñ etc.) |
| **Left Super (Win key)** | LAlt | LAlt | Swapped with lAlt so the cluster matches macOS Cmd/Opt order (Cmd inside, Opt outside) |

All other keys pass through unchanged.

### Service architecture

- Install via `paru -S kanata` (AUR) or fall back to `cargo install kanata` if AUR unavailable on first attempt.
- Run as a **system service** (not user) because kanata needs read access to `/dev/uinput`:
  - Create `uinput` group; add `nazarf` to it.
  - udev rule: `KERNEL=="uinput", GROUP="uinput", MODE="0660"`.
  - `kanata.service` runs as user `nazarf` via `SupplementaryGroups=input uinput`.
- Config at `~/.config/kanata/keychron.kbd` (Lisp-style DSL).
- Device matching: `--watch-devices` flag plus a `(devices ...)` selector in config that matches Keychron USB vendor:product (`05ac` and a Keychron-specific product ID — verify on first KVM switch to CachyOS via `lsusb` and `cat /proc/bus/input/devices`). Survives KVM disconnect/reconnect because kanata re-attaches when device re-appears.
- Service unit at `/etc/systemd/system/kanata.service`, `WantedBy=graphical.target`.

### Verification

- `systemctl status kanata` reports active.
- Press Caps Lock → Esc registered (test in any text field).
- Hold Caps + L → text app receives Ctrl-L (clear in shells, or browser address-bar focus).
- Press left Alt → application receives Super (Hyprland `$mainMod` binds fire).
- Press left Alt + Space → wofi opens.
- KVM-toggle to MacBook, then back to CachyOS → kanata still works without restart.

### Risk + rollback

If kanata config has a bug and breaks all keys: the user can still SSH from MacBook and `sudo systemctl stop kanata.service` to recover. KVM-switch to MacBook is an instant escape hatch.

---

## 3. Hyprland additions

The existing `~/.config/hypr/hyprland.conf` (128 lines) is well-organized macOS-parity binds. This design **adds** infrastructure without touching the binds.

### New sections to append

```
# ──────────────────────────────────────────────────────────────────────
# Input — Ukrainian layout toggle (Right Ctrl)
# ──────────────────────────────────────────────────────────────────────
input {
    kb_layout = us,ua
    kb_options = grp:rctrl_toggle
    repeat_rate = 50
    repeat_delay = 250
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}

# ──────────────────────────────────────────────────────────────────────
# Autostart (extend existing exec-once)
# ──────────────────────────────────────────────────────────────────────
exec-once = waybar
exec-once = swaync
exec-once = hypridle
exec-once = hyprpolkitagent
exec-once = swww-daemon
exec-once = sleep 1 && swww img ~/Pictures/Wallpapers/gruvbox-default.png --transition-type any
exec-once = wl-paste --type text  --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
```

### Replace existing screenshot binds

The existing config uses inline `grim+slurp` heredocs. Replace with `hyprshot` for cleaner DSL + add a Cmd+Shift+5 → annotate-with-satty bind:

```
bind = $mainMod SHIFT, 3, exec, hyprshot -m output -o $screenshots
bind = $mainMod SHIFT, 4, exec, hyprshot -m region -o $screenshots
bind = $mainMod CTRL SHIFT, 4, exec, hyprshot -m region --clipboard-only
bind = $mainMod SHIFT, 5, exec, hyprshot -m region -r | satty --filename - --output-dir $screenshots --early-exit --actions-on-enter save-to-clipboard
```

### swaync trigger bind

```
bind = $mainMod, N, exec, swaync-client -t -sw   # toggle notification panel (Cmd+N = Notifications)
```

### Reload bind already present (keep)

`bind = $mainMod SHIFT, R, exec, hyprctl reload` — already in current config.

---

## 4. Waybar

### Layout

Top bar, single per monitor (Waybar auto-replicates per output if `output` filter omitted).

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│ [1] 2 3 4 5  ·  ● Ghostty — ~/.local/share/chezmoi    14:23 Mon 25 May    72° CPU 23% 12G ↓1M  │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
   workspaces        window title (center)        clock         GPU CPU RAM net audio tray
```

### Modules

| Section | Module | Notes |
|---|---|---|
| Left | `hyprland/workspaces` | Active highlighted (Gruvbox `yellow #fabd2f` bg); empty hidden |
| Left | `hyprland/window` | Truncated to 60 chars |
| Center | `clock` | Format `%H:%M  %a %d %b`; tooltip shows full calendar via `cal` |
| Right | `custom/gpu-temp` | `nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader` every 5s; orange >75°, red >85° |
| Right | `cpu` | Compact "CPU 23%" |
| Right | `memory` | "12.4G/64G" used/total |
| Right | `network` | Wifi SSID or eth name; rate counter on tooltip |
| Right | `pulseaudio` | Volume %, mute icon; click → open `pavucontrol` |
| Right | `tray` | System tray (1Password, Tailscale, Steam, etc.) |

### Files

- `~/.config/waybar/config.jsonc` — modules + behavior
- `~/.config/waybar/style.css` — Gruvbox Dark Hard styling

### Theme tokens (Gruvbox Dark Hard)

| Role | Hex |
|---|---|
| bg0_h (bar) | `#1d2021` |
| bg1 | `#3c3836` |
| fg | `#ebdbb2` |
| yellow (accent / active) | `#fabd2f` |
| red (alerts) | `#fb4934` |
| green (ok) | `#b8bb26` |
| blue (info) | `#83a598` |
| orange (warning) | `#fe8019` |

Bar height: 32px. Font: `JetBrainsMonoNL Nerd Font Propo` 13px (already installed).

---

## 5. swaync — notification center

### Why swaync over mako

mako is one-toast-at-a-time, no center, no DND toggle. swaync provides:
- Persistent history panel (Cmd+N to open)
- DND toggle (silence everything during meetings / training runs)
- Notification grouping
- CSS-styleable (matches Gruvbox)
- Active development

### Files

- `~/.config/swaync/config.json` — behavior (positioning right, history limit 100, DND default off)
- `~/.config/swaync/style.css` — Gruvbox styling matching Waybar

### Behavior

- Toast position: top-right, anchored under Waybar.
- Toast timeout: 5s default, 10s for critical (per `urgency`).
- Control center panel: opens on Cmd+N (Hyprland bind §3); also accessible via Waybar tray icon.
- Notifications muted while DND is on.

---

## 6. hypridle + hyprlock — idle policy

### Policy

| Idle (min) | Action | Reversible |
|---|---|---|
| 5 | Dim screen to 30% | Yes (any input restores) |
| 10 | Run `hyprlock` (lock screen) | Requires password |
| 30 | DPMS off (monitor sleep) | Any input wakes |

### Files

- `~/.config/hypr/hypridle.conf` — three `listener` blocks for the timeouts above + a `before_sleep` listener that locks before system suspend.
- `~/.config/hypr/hyprlock.conf` — already exists (CachyOS default from 2026-05-15); revise to Gruvbox-themed centered-input layout.

### Hyprlock revision (Gruvbox)

Background: solid Gruvbox `#1d2021` (or blurred wallpaper if user prefers — start solid for performance).
Input field: Gruvbox `#3c3836` background, `#ebdbb2` text, `#fabd2f` outline on focus.
Time/date display: large centered `JetBrainsMono Nerd Font` 64px.

---

## 7. swww — wallpaper daemon

### Why swww (vs hyprpaper)

swww supports smooth transitions, multi-output handled cleanly, daemon-based (no per-monitor config). Hyprpaper is simpler but static-only.

### Initial wallpaper set

- Fetch 3-5 favorites from <https://github.com/AngelJumbo/gruvbox-wallpapers> (curated Gruvbox-themed)
- Store under `~/Pictures/Wallpapers/gruvbox/`
- Default symlink: `~/Pictures/Wallpapers/gruvbox-default.png` → first pick
- Future: simple `wallpaper-cycle.sh` to rotate via cron (out of scope here)

### Files

- No config file — swww-daemon takes commands via `swww img`. Wallpaper choice baked into `exec-once` in hyprland.conf (§3).

---

## 8. Screenshot — hyprshot + satty

### Why upgrade

Current `hyprland.conf` inlines `grim` + `slurp` + `wl-copy` + `notify-send` in heredocs. Works but verbose and missing window-mode + annotation. hyprshot wraps these with cleaner CLI and adds:
- `-m window` (active window only)
- `-m output` (full monitor)
- `-m region` (with slurp)
- Automatic copy-to-clipboard + file + notification

satty adds post-capture annotation (arrows, text, blur — for screenshots of UI bugs / Slack messages).

### Bind cheat sheet (from §3)

| Bind | Action |
|---|---|
| Cmd+Shift+3 | Full output → file + clipboard + notif |
| Cmd+Shift+4 | Region → file + clipboard + notif |
| Cmd+Ctrl+Shift+4 | Region → clipboard only (no file) |
| Cmd+Shift+5 | Region → satty annotation → file + clipboard |

---

## 9. Ukrainian input layout

`grp:rctrl_toggle` chosen because:
- Caps Lock is busy with kanata (Esc/Ctrl)
- Cmd+Space is busy with wofi launcher
- Right Ctrl on Keychron K3 is rarely used in muscle memory
- Right Ctrl is a single press, no chord — easier to switch mid-typing

Indicator: Waybar `hyprland/language` module displays current layout ("EN" / "UA") in the right cluster. Click to toggle (alternative to Right Ctrl).

---

## 10. File structure (chezmoi)

All under existing Linux-guard in `.chezmoiignore.tmpl` (Plan 2 already added `.config/hypr` + others; need to extend for `.config/waybar`, `.config/swaync`, `.config/kanata`, `.config/hypr/hypridle.conf`).

Wait — re-checking `.chezmoiignore.tmpl` from Plan 2:

```
{{ if ne .chezmoi.os "linux" }}
.config/hypr
.config/waybar
.config/mako
.config/kanata
.config/containers
{{ end }}
```

`hypr`, `waybar`, `kanata` already covered. **Add** `.config/swaync` (we chose swaync over mako). `.config/mako` can stay in the ignore list as future-safe (no harm).

| chezmoi source path | Purpose |
|---|---|
| `dot_config/hypr/hyprland.conf` | promote existing CachyOS file; add §3 sections via Edit |
| `dot_config/hypr/hyprlock.conf` | promote existing; restyle to Gruvbox |
| `dot_config/hypr/hypridle.conf` | NEW |
| `dot_config/waybar/config.jsonc` | NEW |
| `dot_config/waybar/style.css` | NEW |
| `dot_config/swaync/config.json` | NEW |
| `dot_config/swaync/style.css` | NEW |
| `dot_config/kanata/keychron.kbd` | NEW |
| `dot_config/hypr/scripts/wallpaper-init.sh` | one-line `swww img …` (called from exec-once) |
| `scripts/setup-kanata-cachyos.sh` | NEW one-shot installer for system-level kanata bits (udev rule, uinput group, `/etc/systemd/system/kanata.service`). chezmoi can't manage `/etc/` paths via `dot_` prefix — script handles them idempotently. Re-run safely after kanata upgrades. |
| `~/Pictures/Wallpapers/gruvbox/*.png` | NOT chezmoi-managed (binary blobs); bootstrap script fetches them |

System-level files (kanata systemd service, udev rule, uinput group setup) live in a one-shot install script at `scripts/setup-kanata-cachyos.sh`, run during implementation.

---

## 11. Implementation phases (for the Plan)

The Plan (writing-plans skill, next step) will decompose into ~10-12 tasks of roughly:

1. Install AUR packages (`waybar`, `swaync`, `hypridle`, `swww`, `hyprshot`, `satty`, `hyprpolkitagent`, `cliphist`, `wl-clipboard`, `pavucontrol`, `playerctl`, `kanata`).
2. kanata: udev rule + uinput group + systemd service + initial keychron.kbd config. **HIGH RISK** (could brick keyboard if bad config; rollback via SSH).
3. Waybar config + style + verify renders.
4. swaync config + style + verify toast + control-center.
5. hypridle + hyprlock Gruvbox restyle.
6. swww + fetch wallpapers + initial image.
7. Hyprland config edits: input block, exec-once additions, screenshot bind replacements, swaync bind.
8. Ukrainian layout verification (toggle test).
9. Promote everything via `chezmoi add` from CachyOS → MacBook commit fallback path (per Plan 2 Task 10 pattern).
10. Extend `.chezmoiignore.tmpl` to include `.config/swaync` (one-line edit).
11. Test suite: keyboard binds, screenshot flow, idle lock, layout toggle, Waybar modules.
12. STATUS + DECISIONS commit.

Estimated ~2-3h with subagent-driven execution. Some steps need physical presence at CachyOS (testing kanata Caps→Esc, KVM toggle, layout switch) — flag in plan as "requires user at PC".

---

## 12. Decisions log (rationale snapshot)

- **Gruvbox over Catppuccin Mocha** — matches existing BAT/starship/git-delta stack across macOS+Linux. Catppuccin would be more "ricing-default" but breaks visual parity with the rest of user's tools.
- **swaync over mako** — control-center value (DND, history) outweighs mako's minimalism for a "CTO-grade" workspace.
- **wofi kept (no Walker migration)** — wofi works, is in current config, Walker is AUR-beta. Defer.
- **hyprshot over staying with grim+slurp inline** — cleaner DSL, window-mode capability, +satty for annotation.
- **kanata over xkb/keyd alternatives** — only kanata cleanly handles tap-vs-hold semantics (Caps→Esc/Ctrl) cross-platform, matching macOS Karabiner mental model.
- **Left Alt → Super (not left Win → Super)** — preserves the Mac muscle memory where the thumb-adjacent key is "Cmd". User can swap if they prefer Win key.
- **Right Ctrl as layout toggle (vs Caps / Win+Space)** — only free chord-less key after kanata + Hyprland binds claim Caps and Cmd+Space.
- **hypridle 5/10/30 timeline** — 5 min dim is subtle, 10 min lock balances security vs friction at home, 30 min DPMS saves the 5070 Ti from idle-burning the monitor.
- **swww over hyprpaper** — transitions + daemon-based fits future per-workspace / cycling patterns better.

---

## 13. References

- Existing `~/.config/hypr/hyprland.conf` on CachyOS (CachyOS default, last touched 2026-05-15 per `ls`).
- `docs/macos-audit/SPEC.md` — Karabiner+Goku conventions (3-device Caps→Esc, L/R Cmd↔Opt swap) replicated here.
- `docs/cross-os-chezmoi/specs/2026-05-25-cross-os-chezmoi-design.md` — `.chezmoiignore.tmpl` Linux-guard system this plugs into.
- `~/cachyos-setup-tasks.md` Phase 3 (CC TASK #4 + #5) — original prompts; supersedes those.
- `docs/macos-audit/NOTES.md` — ZSA Moonlander parked (out of scope; eventual migration interacts with kanata config when it happens).
- Gruvbox palette: <https://github.com/morhetz/gruvbox> (canonical).
- kanata docs: <https://github.com/jtroo/kanata>.
- Waybar wiki: <https://github.com/Alexays/Waybar/wiki>.
- swaync: <https://github.com/ErikReider/SwayNotificationCenter>.
- Gruvbox wallpapers: <https://github.com/AngelJumbo/gruvbox-wallpapers>.
