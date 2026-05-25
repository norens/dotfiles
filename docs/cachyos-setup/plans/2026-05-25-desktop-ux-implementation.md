# CachyOS Desktop UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete macOS-feel desktop on CachyOS — kanata Caps→Esc/Ctrl + lAlt→Super remap, Waybar top bar, swaync notifications, hypridle lock policy, swww wallpaper, hyprshot screenshots, Ukrainian input toggle — all Gruvbox Dark Hard themed.

**Architecture:** All config files land in chezmoi source under `dot_config/{hypr,waybar,swaync,kanata}/...` (already Linux-guarded by `.chezmoiignore.tmpl` from Plan 2; needs one-line extension for `swaync`). One-shot installer script handles system-level kanata bits (`/etc/udev/rules.d`, `/etc/systemd/system/`, `uinput` group). MacBook is the chezmoi commit origin; CachyOS pulls + applies.

**Tech Stack:** Hyprland (Wayland), kanata (keyboard remap), Waybar (status bar), swaync (notif center), hypridle + hyprlock (idle/lock), swww (wallpaper), hyprshot + satty (screenshot), chezmoi (cross-OS-templated dotfiles from Plan 2).

**Source spec:** `docs/cachyos-setup/specs/2026-05-25-desktop-ux-design.md`

---

## Prerequisites

- ✅ Plan 1 (ML Foundation Slice) complete — Ollama running, CachyOS reachable via Tailscale.
- ✅ Plan 2 (Cross-OS chezmoi) complete — both machines under one repo, `.chezmoiignore.tmpl` guards Linux-only paths on macOS.
- ✅ Hyprland session active on CachyOS via SDDM (user `nazarf`).
- ✅ Existing `~/.config/hypr/hyprland.conf` (CachyOS-local, 128 lines, macOS-parity binds) — will be promoted into chezmoi as part of Task 4.
- ✅ Keychron K3 connected via BenQ monitor's KVM (USB-wired path when KVM is on CachyOS).
- ⚠️ User AWAY from physical PC during Tasks 1-9; **Task 10 requires user at the CachyOS keyboard** for hand-on verification (kanata Caps→Esc, layout toggle, screenshot binds).

**Execution context:** Most commands run via `ssh nazarf@nazarf-cachyos '...'` from MacBook. Commits originate on MacBook (chezmoi source canonical there), `chezmoi update` on CachyOS pulls + applies.

---

## File Structure

### Files created/modified in chezmoi source

| Path | Purpose | Task |
|---|---|---|
| `dot_config/hypr/hyprland.conf` | Promote CachyOS-local + extend (input block, exec-once additions, screenshot bind replacements, swaync bind) | 4, 5 |
| `dot_config/hypr/hyprlock.conf` | Promote CachyOS-local + restyle Gruvbox | 4, 5 |
| `dot_config/hypr/hypridle.conf` | NEW — 5/10/30 idle policy + before_sleep lock | 3 |
| `dot_config/hypr/scripts/wallpaper-init.sh` | NEW — `swww img` one-liner called from exec-once | 3 |
| `dot_config/waybar/config.jsonc` | NEW — modules layout per spec §4 | 3 |
| `dot_config/waybar/style.css` | NEW — Gruvbox Dark Hard styling | 3 |
| `dot_config/swaync/config.json` | NEW — DND default off, history 100, top-right toasts | 3 |
| `dot_config/swaync/style.css` | NEW — Gruvbox styling | 3 |
| `dot_config/kanata/keychron.kbd` | NEW — Caps→Esc/Ctrl, lAlt↔lSuper swap, rAlt preserved | 3 |
| `scripts/setup-kanata-cachyos.sh` | NEW — idempotent installer for udev rule + uinput group + systemd unit | 3 |
| `.chezmoiignore.tmpl` | Add `.config/swaync` to Linux-only block | 6 |

### Files touched on CachyOS (not in chezmoi)

| Path | Change | Task |
|---|---|---|
| `/etc/udev/rules.d/99-uinput.rules` | Created by installer script | 8 |
| `/etc/systemd/system/kanata.service` | Created by installer script | 8 |
| `~/Pictures/Wallpapers/gruvbox/*.png` | Fetched binaries (NOT chezmoi-managed) | 7 |
| `~/Pictures/Wallpapers/gruvbox-default.png` | Symlink to chosen wallpaper | 7 |
| All chezmoi-managed paths above | Created by `chezmoi apply` after Task 6 push | 6 |

---

## Task 1: Install AUR packages on CachyOS

**Files:** none in chezmoi — installs system packages.

**Context:** Most packages are in pacman official repos; a few (kanata, satty, hyprshot) live in AUR. CachyOS already has `paru` installed (verified in Plan 1 audit). Install all at once to minimize round-trips.

- [ ] **Step 1: Pre-flight — confirm paru works**

```bash
ssh nazarf@nazarf-cachyos 'paru --version'
```

Expected: paru version printed.

- [ ] **Step 2: Install pacman packages (official repos)**

```bash
ssh nazarf@nazarf-cachyos 'sudo pacman -S --needed --noconfirm \
  waybar \
  hypridle \
  swww \
  hyprpolkitagent \
  cliphist \
  wl-clipboard \
  pavucontrol \
  playerctl \
  pamixer \
  brightnessctl \
  jq'
```

Expected: all installed (or already present). `jq` is for Waybar custom modules; `pamixer` and `brightnessctl` are Waybar audio/backlight helpers.

- [ ] **Step 3: Install AUR packages via paru**

```bash
ssh nazarf@nazarf-cachyos 'paru -S --needed --noconfirm kanata-bin swaync hyprshot satty'
```

Expected: all installed. `kanata-bin` is the prebuilt binary (faster than building from source); `swaync` ships from AUR even though sometimes mirrored to extra; `hyprshot` + `satty` are AUR-only.

- [ ] **Step 4: Verify all binaries on PATH**

```bash
ssh nazarf@nazarf-cachyos 'for cmd in waybar swaync swaync-client hypridle swww hyprshot satty kanata hyprpolkitagent cliphist wl-paste pavucontrol; do
  if command -v "$cmd" >/dev/null; then
    echo "OK: $cmd → $(command -v $cmd)"
  else
    echo "MISSING: $cmd"
  fi
done'
```

Expected: every line starts with `OK:`. Any `MISSING:` line — investigate the package name and retry Step 2 or 3 for that one.

- [ ] **Step 5: No commit (system-state only)**

Nothing in chezmoi changed. Move to Task 2.

---

## Task 2: Discover Keychron device fingerprint

**Files:** none — diagnostic only.

**Context:** kanata config in Task 3 needs to know how to match the Keychron K3 when it appears via KVM. Since user is currently NOT at the PC, the KVM is on MacBook side and Keychron is NOT visible to CachyOS right now. This task is best-effort: probe for any Keychron history (lsusb cache, journal logs), document what we know, and write the kanata config to use a NAME REGEX pattern (`Keychron`) rather than vendor:product IDs. Real verification happens at Task 10 when user is at the PC.

- [ ] **Step 1: Check current /proc/bus/input/devices for any Keychron trace**

```bash
ssh nazarf@nazarf-cachyos 'sudo grep -i -B1 -A2 keychron /proc/bus/input/devices 2>&1 || echo "(Keychron not currently attached — expected if KVM is on MacBook)"'
```

Expected: either Keychron device info, or "not currently attached" — both fine for plan purposes.

- [ ] **Step 2: Check journalctl for past Keychron USB attach events**

```bash
ssh nazarf@nazarf-cachyos 'sudo journalctl --since "30 days ago" | grep -i keychron | head -10 || echo "(no historical Keychron attach events in journal)"'
```

Expected: zero or more lines mentioning Keychron product strings. If any found — note vendor:product ID for future config tightening; not blocking.

- [ ] **Step 3: Confirm uinput kernel module loadable**

```bash
ssh nazarf@nazarf-cachyos 'lsmod | grep uinput || sudo modprobe uinput && lsmod | grep uinput'
```

Expected: `uinput` listed. This is required for kanata to inject synthesized key events.

---

## Task 3: Write all chezmoi configs in one batch

**Files (all in `/Users/nazarfedisin/.local/share/chezmoi/`):**
- Create: `dot_config/hypr/hypridle.conf`
- Create: `dot_config/hypr/scripts/wallpaper-init.sh`
- Create: `dot_config/waybar/config.jsonc`
- Create: `dot_config/waybar/style.css`
- Create: `dot_config/swaync/config.json`
- Create: `dot_config/swaync/style.css`
- Create: `dot_config/kanata/keychron.kbd`
- Create: `scripts/setup-kanata-cachyos.sh`

**Context:** Write all NEW config files in chezmoi source on MacBook. These are all Linux-only — `.chezmoiignore.tmpl` Linux-guard (Plan 2) already skips `.config/{hypr,waybar,kanata}` on macOS apply; we'll extend for `.config/swaync` in Task 6. Nothing is applied yet.

- [ ] **Step 1: Create directories**

```bash
mkdir -p /Users/nazarfedisin/.local/share/chezmoi/dot_config/hypr/scripts
mkdir -p /Users/nazarfedisin/.local/share/chezmoi/dot_config/waybar
mkdir -p /Users/nazarfedisin/.local/share/chezmoi/dot_config/swaync
mkdir -p /Users/nazarfedisin/.local/share/chezmoi/dot_config/kanata
ls -la /Users/nazarfedisin/.local/share/chezmoi/dot_config/{hypr,waybar,swaync,kanata}
```

Expected: all four dirs exist; `dot_config/hypr/scripts/` also.

- [ ] **Step 2: Write `dot_config/hypr/hypridle.conf`**

```bash
cat > /Users/nazarfedisin/.local/share/chezmoi/dot_config/hypr/hypridle.conf <<'EOF'
# hypridle — idle policy (5/10/30 minutes)
# Spec: docs/cachyos-setup/specs/2026-05-25-desktop-ux-design.md §6

general {
    lock_cmd = pidof hyprlock || hyprlock                 # ensure single instance
    before_sleep_cmd = loginctl lock-session              # lock before suspend
    after_sleep_cmd = hyprctl dispatch dpms on            # wake monitor on resume
}

# 5 min — dim
listener {
    timeout = 300
    on-timeout = brightnessctl -s set 30%
    on-resume = brightnessctl -r
}

# 10 min — lock
listener {
    timeout = 600
    on-timeout = loginctl lock-session
}

# 30 min — DPMS off
listener {
    timeout = 1800
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}
EOF
```

- [ ] **Step 3: Write `dot_config/hypr/scripts/wallpaper-init.sh`**

```bash
cat > /Users/nazarfedisin/.local/share/chezmoi/dot_config/hypr/scripts/wallpaper-init.sh <<'EOF'
#!/bin/sh
# Called from hyprland.conf exec-once. Waits 1s for swww-daemon, then sets wallpaper.
# If default wallpaper missing, fall back to solid Gruvbox bg color.
sleep 1
if [ -f "$HOME/Pictures/Wallpapers/gruvbox-default.png" ]; then
  swww img "$HOME/Pictures/Wallpapers/gruvbox-default.png" --transition-type any
else
  # Fallback: solid Gruvbox bg0_h via swww's color
  swww clear "1d2021"
fi
EOF
chmod +x /Users/nazarfedisin/.local/share/chezmoi/dot_config/hypr/scripts/wallpaper-init.sh
```

- [ ] **Step 4: Write `dot_config/waybar/config.jsonc`**

```bash
cat > /Users/nazarfedisin/.local/share/chezmoi/dot_config/waybar/config.jsonc <<'EOF'
// Waybar — top bar, Gruvbox-themed.
// Spec: docs/cachyos-setup/specs/2026-05-25-desktop-ux-design.md §4
{
  "layer": "top",
  "position": "top",
  "height": 32,
  "spacing": 6,

  "modules-left":   ["hyprland/workspaces", "hyprland/window"],
  "modules-center": ["clock"],
  "modules-right":  [
    "custom/gpu-temp",
    "cpu",
    "memory",
    "network",
    "pulseaudio",
    "hyprland/language",
    "tray"
  ],

  "hyprland/workspaces": {
    "format": "{name}",
    "on-click": "activate"
  },

  "hyprland/window": {
    "max-length": 60,
    "separate-outputs": true
  },

  "clock": {
    "format": "{:%H:%M  %a %d %b}",
    "tooltip-format": "<tt>{calendar}</tt>"
  },

  "custom/gpu-temp": {
    "exec": "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | awk '{print \"  \" $1 \"°\"}'",
    "interval": 5,
    "tooltip": false
  },

  "cpu": {
    "format": "CPU {usage}%",
    "interval": 5
  },

  "memory": {
    "format": "{used:0.1f}G/{total:0.0f}G",
    "interval": 5
  },

  "network": {
    "format-ethernet": "  {ifname}",
    "format-wifi": "  {essid}",
    "format-disconnected": "  off",
    "tooltip-format": "{ipaddr}  ↓ {bandwidthDownBytes}  ↑ {bandwidthUpBytes}",
    "interval": 5
  },

  "pulseaudio": {
    "format": "{icon}  {volume}%",
    "format-muted": "  muted",
    "format-icons": { "default": ["", "", ""] },
    "on-click": "pavucontrol"
  },

  "hyprland/language": {
    "format": "{short}",
    "format-en": "EN",
    "format-uk": "UA"
  },

  "tray": {
    "spacing": 8,
    "icon-size": 18
  }
}
EOF
```

- [ ] **Step 5: Write `dot_config/waybar/style.css`** (Gruvbox Dark Hard)

```bash
cat > /Users/nazarfedisin/.local/share/chezmoi/dot_config/waybar/style.css <<'EOF'
/* Waybar — Gruvbox Dark Hard
 * Spec: docs/cachyos-setup/specs/2026-05-25-desktop-ux-design.md §4
 */

* {
  font-family: "JetBrainsMonoNL Nerd Font Propo", monospace;
  font-size: 13px;
  border-radius: 0;
}

window#waybar {
  background: #1d2021;
  color: #ebdbb2;
  border-bottom: 1px solid #3c3836;
}

#workspaces button {
  padding: 0 8px;
  margin: 2px 2px;
  color: #928374;
  background: transparent;
  border-radius: 4px;
}
#workspaces button.active {
  color: #1d2021;
  background: #fabd2f;
  font-weight: 700;
}
#workspaces button:hover {
  background: #3c3836;
  color: #ebdbb2;
}

#window {
  padding: 0 10px;
  color: #d5c4a1;
}

#clock {
  padding: 0 12px;
  font-weight: 600;
  color: #ebdbb2;
}

#custom-gpu-temp,
#cpu,
#memory,
#network,
#pulseaudio,
#language {
  padding: 0 10px;
  margin: 4px 2px;
  background: #3c3836;
  color: #ebdbb2;
  border-radius: 4px;
}

#custom-gpu-temp.warning { color: #fe8019; }
#custom-gpu-temp.critical { color: #fb4934; }
#network.disconnected,
#pulseaudio.muted { color: #928374; }

#tray { padding: 0 8px; }
#tray > .needs-attention { background: #fb4934; }
EOF
```

- [ ] **Step 6: Write `dot_config/swaync/config.json`**

```bash
cat > /Users/nazarfedisin/.local/share/chezmoi/dot_config/swaync/config.json <<'EOF'
{
  "$schema": "/etc/xdg/swaync/configSchema.json",
  "positionX": "right",
  "positionY": "top",
  "control-center-positionX": "right",
  "control-center-positionY": "top",
  "control-center-margin-top": 8,
  "control-center-margin-right": 8,
  "control-center-margin-bottom": 8,
  "control-center-margin-left": 8,
  "control-center-width": 380,
  "control-center-height": 600,
  "fit-to-screen": false,
  "image-visibility": "when-available",
  "transition-time": 200,
  "hide-on-clear": true,
  "hide-on-action": true,
  "timeout": 5,
  "timeout-low": 3,
  "timeout-critical": 10,
  "notification-window-width": 380,
  "notification-2fa-action": true,
  "notification-inline-replies": false,
  "keyboard-shortcuts": true,
  "notification-grouping": true,
  "notification-visibility": {
    "Spotify-Music": { "state": "muted", "app-name": "Spotify" }
  },
  "widgets": [
    "title",
    "dnd",
    "mpris",
    "notifications"
  ],
  "widget-config": {
    "title": {
      "text": "Notifications",
      "clear-all-button": true,
      "button-text": "Clear all"
    },
    "dnd": { "text": "Do Not Disturb" },
    "mpris": { "image-size": 96, "image-radius": 8 }
  }
}
EOF
```

- [ ] **Step 7: Write `dot_config/swaync/style.css`** (Gruvbox)

```bash
cat > /Users/nazarfedisin/.local/share/chezmoi/dot_config/swaync/style.css <<'EOF'
/* swaync — Gruvbox Dark Hard
 * Spec: docs/cachyos-setup/specs/2026-05-25-desktop-ux-design.md §5
 */

* {
  font-family: "JetBrainsMonoNL Nerd Font Propo", system-ui, sans-serif;
  font-size: 13px;
}

.notification-row {
  outline: none;
  margin: 6px 8px;
}

.notification-background .notification {
  background: #282828;
  color: #ebdbb2;
  border: 1px solid #3c3836;
  border-radius: 8px;
  padding: 12px;
}
.notification-background .notification.critical {
  border-color: #fb4934;
}

.notification .summary {
  color: #fabd2f;
  font-weight: 700;
}

.notification .body { color: #ebdbb2; }

.control-center {
  background: #1d2021;
  color: #ebdbb2;
  border: 1px solid #3c3836;
  border-radius: 12px;
  padding: 12px;
}

.control-center .widget-title { color: #fabd2f; font-weight: 700; }
.control-center button {
  background: #3c3836;
  color: #ebdbb2;
  border: none;
  border-radius: 6px;
  padding: 6px 12px;
}
.control-center button:hover { background: #504945; }

.control-center .notification-row .notification {
  background: #282828;
  border: 1px solid #3c3836;
}

.widget-dnd > switch {
  background: #3c3836;
  border-radius: 12px;
}
.widget-dnd > switch:checked { background: #fabd2f; }
EOF
```

- [ ] **Step 8: Write `dot_config/kanata/keychron.kbd`**

```bash
cat > /Users/nazarfedisin/.local/share/chezmoi/dot_config/kanata/keychron.kbd <<'EOF'
;; kanata — Keychron K3 macOS-parity remap
;; Spec: docs/cachyos-setup/specs/2026-05-25-desktop-ux-design.md §2
;;
;; Match by device NAME REGEX so it survives KVM disconnect/reconnect
;; without needing hardcoded /dev/input/eventN.

(defcfg
  process-unmapped-keys yes
  log-layer-changes no
  ;; Match any device whose name contains "Keychron" (case-insensitive).
  ;; --watch-devices flag on the kanata daemon hot-attaches when the
  ;; Keychron re-appears via KVM toggle.
  linux-dev-names-include ("Keychron" "keychron")
)

(defsrc
  caps  lalt  lmet  ralt
)

(defalias
  cesc (tap-hold 200 200 esc lctl)   ;; Caps Lock: tap=Esc, hold=LCtrl
)

(deflayer base
  ;; Caps     left-Alt   left-Super   right-Alt
  @cesc       lmet       lalt         ralt
)
EOF
```

- [ ] **Step 9: Write `scripts/setup-kanata-cachyos.sh`** (system installer)

```bash
cat > /Users/nazarfedisin/.local/share/chezmoi/scripts/setup-kanata-cachyos.sh <<'EOF'
#!/bin/bash
#
# Idempotent installer for system-level kanata bits.
# Run on CachyOS once after kanata is installed. Re-run safely.
#
# What it does:
#   1. Ensures uinput kernel module loads at boot
#   2. Creates 'uinput' group; adds $USER to it
#   3. Drops udev rule so /dev/uinput is group-writable by 'uinput'
#   4. Writes /etc/systemd/system/kanata.service
#   5. Enables and starts the service
#
# Requires: kanata binary on PATH, ~/.config/kanata/keychron.kbd present.

set -euo pipefail

log()  { printf '\033[1;34m[setup-kanata]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Linux" ]] || die "Linux only"
command -v kanata >/dev/null || die "kanata binary not found — install first (paru -S kanata-bin)"

CFG="$HOME/.config/kanata/keychron.kbd"
[[ -f "$CFG" ]] || die "kanata config not found at $CFG — chezmoi apply first"

log "Ensuring uinput module loads at boot..."
echo 'uinput' | sudo tee /etc/modules-load.d/uinput.conf >/dev/null
sudo modprobe uinput

log "Ensuring 'uinput' group exists..."
getent group uinput >/dev/null || sudo groupadd uinput

log "Adding $USER to 'uinput' and 'input' groups..."
sudo usermod -aG uinput,input "$USER"

log "Writing /etc/udev/rules.d/99-uinput.rules..."
sudo tee /etc/udev/rules.d/99-uinput.rules >/dev/null <<'RULE'
KERNEL=="uinput", GROUP="uinput", MODE="0660", TAG+="uaccess"
RULE
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=misc

log "Writing /etc/systemd/system/kanata.service..."
sudo tee /etc/systemd/system/kanata.service >/dev/null <<UNIT
[Unit]
Description=kanata keyboard remapper
After=systemd-user-sessions.service

[Service]
Type=simple
ExecStart=/usr/bin/kanata --cfg /home/${USER}/.config/kanata/keychron.kbd --watch-devices
Restart=on-failure
RestartSec=5
User=${USER}
Group=uinput
SupplementaryGroups=input

[Install]
WantedBy=graphical.target
UNIT

log "Enabling and starting kanata service..."
sudo systemctl daemon-reload
sudo systemctl enable kanata.service
sudo systemctl restart kanata.service
sleep 2

log "Service status:"
sudo systemctl --no-pager status kanata.service | head -15 || true

log ""
log "Done. If kanata is not active:"
log "  1. journalctl -u kanata.service --no-pager -n 30"
log "  2. Likely cause: Keychron not currently attached (KVM on other machine)."
log "  3. Once Keychron is attached, kanata auto-discovers via --watch-devices."
log ""
log "If active but Caps doesn't map to Esc:"
log "  - Confirm Keychron device name in /proc/bus/input/devices matches 'Keychron' regex."
log "  - Adjust linux-dev-names-include in ~/.config/kanata/keychron.kbd accordingly."
EOF
chmod +x /Users/nazarfedisin/.local/share/chezmoi/scripts/setup-kanata-cachyos.sh
```

- [ ] **Step 10: Verify all files present**

```bash
find /Users/nazarfedisin/.local/share/chezmoi/dot_config/{hypr/hypridle.conf,hypr/scripts/wallpaper-init.sh,waybar,swaync,kanata} \
     /Users/nazarfedisin/.local/share/chezmoi/scripts/setup-kanata-cachyos.sh \
     -type f | sort
```

Expected: 8 files listed (hypridle.conf, wallpaper-init.sh, waybar/config.jsonc, waybar/style.css, swaync/config.json, swaync/style.css, kanata/keychron.kbd, setup-kanata-cachyos.sh).

- [ ] **Step 11: Commit (intermediate — easier rollback if issues found later)**

```bash
cd /Users/nazarfedisin/.local/share/chezmoi
git add dot_config/hypr/hypridle.conf \
        dot_config/hypr/scripts/wallpaper-init.sh \
        dot_config/waybar/ \
        dot_config/swaync/ \
        dot_config/kanata/ \
        scripts/setup-kanata-cachyos.sh
git commit --no-gpg-sign -m "feat(desktop-ux): waybar+swaync+hypridle+kanata configs + installer script"
git push origin main
```

Note: not pushing yet — Task 6 will batch with chezmoiignore + hyprland.conf changes.

---

## Task 4: Promote existing CachyOS hypr configs into chezmoi

**Files:**
- Source-of-truth move: CachyOS `~/.config/hypr/hyprland.conf` → chezmoi `dot_config/hypr/hyprland.conf`
- Source-of-truth move: CachyOS `~/.config/hypr/hyprlock.conf` → chezmoi `dot_config/hypr/hyprlock.conf`

**Context:** These files exist on CachyOS but not in chezmoi yet (CachyOS-locals from 2026-05-15 SDDM defaults + our hyprland.conf edits). Promote them so they're under version control before we modify them in Task 5.

- [ ] **Step 1: [CachyOS] Add hyprland.conf to chezmoi source on CachyOS**

```bash
ssh nazarf@nazarf-cachyos 'chezmoi add ~/.config/hypr/hyprland.conf'
ssh nazarf@nazarf-cachyos 'ls -la ~/.local/share/chezmoi/dot_config/hypr/'
```

Expected: `hyprland.conf` appears in chezmoi source on CachyOS. Also `hypridle.conf` should be visible (from Task 3 commit; pull happened automatically? — verify and pull if not).

- [ ] **Step 2: [CachyOS] Add hyprlock.conf to chezmoi source**

```bash
ssh nazarf@nazarf-cachyos 'chezmoi add ~/.config/hypr/hyprlock.conf'
ssh nazarf@nazarf-cachyos 'ls -la ~/.local/share/chezmoi/dot_config/hypr/'
```

Expected: both files present in CachyOS chezmoi source.

- [ ] **Step 3: Copy from CachyOS chezmoi source back to MacBook chezmoi source via SSH**

```bash
ssh nazarf@nazarf-cachyos 'cat ~/.local/share/chezmoi/dot_config/hypr/hyprland.conf' > /Users/nazarfedisin/.local/share/chezmoi/dot_config/hypr/hyprland.conf
ssh nazarf@nazarf-cachyos 'cat ~/.local/share/chezmoi/dot_config/hypr/hyprlock.conf' > /Users/nazarfedisin/.local/share/chezmoi/dot_config/hypr/hyprlock.conf
ls -la /Users/nazarfedisin/.local/share/chezmoi/dot_config/hypr/
wc -l /Users/nazarfedisin/.local/share/chezmoi/dot_config/hypr/{hyprland.conf,hyprlock.conf}
```

Expected: hyprland.conf ~128 lines, hyprlock.conf 20-50 lines. (Both files now in MacBook source.)

- [ ] **Step 4: Reset CachyOS chezmoi source to clean state (we'll pull from MacBook canonical)**

```bash
ssh nazarf@nazarf-cachyos 'cd ~/.local/share/chezmoi && git reset --hard HEAD'
```

Expected: clean working tree on CachyOS chezmoi. The chezmoi-add changes are now ONLY in MacBook source — single canonical commit point.

- [ ] **Step 5: Verify chezmoi diff is clean on MacBook (just adding NEW files)**

```bash
cd /Users/nazarfedisin/.local/share/chezmoi
git status
```

Expected: `Untracked: dot_config/hypr/hyprland.conf, hyprlock.conf` (or `Changes: ...` if they were partially tracked). No surprises elsewhere.

- [ ] **Step 6: NO commit yet** — Task 5 will edit these files before committing, single commit covers promote+edit.

---

## Task 5: Edit hyprland.conf (input + autostart + screenshots + swaync) and restyle hyprlock.conf

**Files:**
- Modify: `/Users/nazarfedisin/.local/share/chezmoi/dot_config/hypr/hyprland.conf`
- Modify: `/Users/nazarfedisin/.local/share/chezmoi/dot_config/hypr/hyprlock.conf`

**Context:** Add input block, exec-once additions, replace inline screenshot binds with hyprshot, add swaync toggle bind. Restyle hyprlock for Gruvbox.

- [ ] **Step 1: Replace the `exec-once = mkdir -p $screenshots` line with the full autostart block**

```bash
# Read current Autostart section to know exact context
grep -n -A3 '^# Autostart' /Users/nazarfedisin/.local/share/chezmoi/dot_config/hypr/hyprland.conf
```

Use the Edit tool to replace:

OLD:
```
exec-once = mkdir -p $screenshots
```

NEW:
```
exec-once = mkdir -p $screenshots

# Background services (Plan 3 Desktop UX)
exec-once = waybar
exec-once = swaync
exec-once = hypridle
exec-once = hyprpolkitagent
exec-once = swww-daemon
exec-once = ~/.config/hypr/scripts/wallpaper-init.sh
exec-once = wl-paste --type text  --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
```

- [ ] **Step 2: Add the Input block right BEFORE the `# Apps — Mac-style launchers` section**

OLD (the section header line for context):
```
# ──────────────────────────────────────────────────────────────────────
# Apps — Mac-style launchers
# ──────────────────────────────────────────────────────────────────────
```

NEW (prepend the input block):
```
# ──────────────────────────────────────────────────────────────────────
# Input — Ukrainian layout toggle on Right Ctrl
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
# Apps — Mac-style launchers
# ──────────────────────────────────────────────────────────────────────
```

- [ ] **Step 3: Replace the inline screenshot binds with hyprshot**

OLD (full Screenshots block):
```
# Whole screen → file + clipboard
bind = $mainMod SHIFT, 3, exec, sh -c 'f=$HOME/Pictures/Screenshots/$(date +%F-%H%M%S).png; grim "$f" && wl-copy < "$f" && notify-send "Screenshot" "$f"'
# Region → file + clipboard
bind = $mainMod SHIFT, 4, exec, sh -c 'f=$HOME/Pictures/Screenshots/$(date +%F-%H%M%S).png; grim -g "$(slurp)" "$f" && wl-copy < "$f" && notify-send "Screenshot" "$f"'
# Region → clipboard only (Mac Cmd+Ctrl+Shift+4 analog)
bind = $mainMod CTRL SHIFT, 4, exec, grim -g "$(slurp)" - | wl-copy
```

NEW:
```
# Cmd+Shift+3 — full output → file + clipboard + notif
bind = $mainMod SHIFT, 3, exec, hyprshot -m output -o $screenshots
# Cmd+Shift+4 — region → file + clipboard + notif
bind = $mainMod SHIFT, 4, exec, hyprshot -m region -o $screenshots
# Cmd+Ctrl+Shift+4 — region → clipboard only (no file)
bind = $mainMod CTRL SHIFT, 4, exec, hyprshot -m region --clipboard-only
# Cmd+Shift+5 — region → satty annotate → save
bind = $mainMod SHIFT, 5, exec, hyprshot -m region -r | satty --filename - --output-dir $screenshots --early-exit --actions-on-enter save-to-clipboard
```

- [ ] **Step 4: Add swaync toggle bind right before `# Misc` section**

OLD:
```
# ──────────────────────────────────────────────────────────────────────
# Misc
# ──────────────────────────────────────────────────────────────────────
bind = $mainMod SHIFT, R, exec, hyprctl reload
```

NEW (insert swaync bind before Misc section):
```
# ──────────────────────────────────────────────────────────────────────
# Notifications (swaync control center)
# ──────────────────────────────────────────────────────────────────────
bind = $mainMod, N, exec, swaync-client -t -sw      # Cmd+N → toggle notification panel

# ──────────────────────────────────────────────────────────────────────
# Misc
# ──────────────────────────────────────────────────────────────────────
bind = $mainMod SHIFT, R, exec, hyprctl reload
```

- [ ] **Step 5: Verify edits**

```bash
grep -c 'exec-once = waybar\|exec-once = swaync\|exec-once = hypridle' /Users/nazarfedisin/.local/share/chezmoi/dot_config/hypr/hyprland.conf
grep -c 'kb_layout = us,ua' /Users/nazarfedisin/.local/share/chezmoi/dot_config/hypr/hyprland.conf
grep -c 'hyprshot' /Users/nazarfedisin/.local/share/chezmoi/dot_config/hypr/hyprland.conf
grep -c 'swaync-client' /Users/nazarfedisin/.local/share/chezmoi/dot_config/hypr/hyprland.conf
```

Expected: 3, 1, 4, 1 (count of each pattern).

- [ ] **Step 6: Replace `hyprlock.conf` content with Gruvbox-themed version**

First inspect current content:
```bash
cat /Users/nazarfedisin/.local/share/chezmoi/dot_config/hypr/hyprlock.conf
```

Then overwrite:
```bash
cat > /Users/nazarfedisin/.local/share/chezmoi/dot_config/hypr/hyprlock.conf <<'EOF'
# hyprlock — Gruvbox Dark Hard styling
# Spec: docs/cachyos-setup/specs/2026-05-25-desktop-ux-design.md §6

general {
    disable_loading_bar = true
    grace = 0
    hide_cursor = true
    no_fade_in = false
}

background {
    monitor =
    path = screenshot                            # blur the current desktop snapshot
    blur_passes = 3
    blur_size = 7
    contrast = 0.85
    brightness = 0.6
    vibrancy = 0.15
    vibrancy_darkness = 0.4
}

input-field {
    monitor =
    size = 320, 50
    outline_thickness = 2
    dots_size = 0.25
    dots_spacing = 0.5
    outer_color = rgba(60, 56, 54, 0.8)          # gruvbox bg1
    inner_color = rgba(40, 40, 40, 0.85)         # gruvbox bg
    font_color = rgb(235, 219, 178)              # gruvbox fg
    check_color = rgb(250, 189, 47)              # gruvbox yellow
    fail_color = rgb(251, 73, 52)                # gruvbox red
    fade_on_empty = true
    placeholder_text = <i><span foreground="##928374">Password…</span></i>
    hide_input = false
    rounding = 12
    position = 0, -80
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:1000] echo "$(date +%H:%M)"
    color = rgb(235, 219, 178)
    font_size = 96
    font_family = JetBrainsMono Nerd Font Bold
    position = 0, 200
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:60000] echo "$(date +'%A, %d %B %Y')"
    color = rgb(189, 174, 147)                   # gruvbox fg2
    font_size = 22
    font_family = JetBrainsMono Nerd Font
    position = 0, 100
    halign = center
    valign = center
}
EOF
```

- [ ] **Step 7: NO commit yet** — Task 6 will bundle these edits with chezmoiignore change.

---

## Task 6: Extend .chezmoiignore.tmpl + commit Tasks 3/4/5 changes

**Files:**
- Modify: `/Users/nazarfedisin/.local/share/chezmoi/.chezmoiignore.tmpl` (add `.config/swaync` to Linux-only block)

**Context:** Plan 2's `.chezmoiignore.tmpl` already lists `.config/hypr`, `.config/waybar`, `.config/mako`, `.config/kanata`, `.config/containers` under the Linux-only `{{ if ne .chezmoi.os "linux" }}` block. We chose swaync over mako (spec §5) but didn't pre-add `swaync` to the ignore. Add it now so MacBook doesn't accidentally try to apply swaync configs.

- [ ] **Step 1: Read current `.chezmoiignore.tmpl`**

```bash
cat /Users/nazarfedisin/.local/share/chezmoi/.chezmoiignore.tmpl
```

- [ ] **Step 2: Insert `.config/swaync` line in the Linux-only block**

Use Edit tool to replace:

OLD:
```
{{ if ne .chezmoi.os "linux" }}
# Linux-only paths — skip on non-Linux
.config/hypr
.config/waybar
.config/mako
.config/kanata
.config/containers
{{ end }}
```

NEW:
```
{{ if ne .chezmoi.os "linux" }}
# Linux-only paths — skip on non-Linux
.config/hypr
.config/waybar
.config/mako
.config/swaync
.config/kanata
.config/containers
{{ end }}
```

- [ ] **Step 3: Verify on macOS that swaync is now ignored**

```bash
cd /Users/nazarfedisin/.local/share/chezmoi
chezmoi managed | grep -E '^\.config/(swaync|hypr|waybar|kanata)' || echo "OK: all Linux-only configs ignored on macOS"
```

Expected: `OK: all Linux-only configs ignored on macOS`.

- [ ] **Step 4: Big batched commit covering Tasks 3 + 4 + 5 + 6**

```bash
cd /Users/nazarfedisin/.local/share/chezmoi
git add .chezmoiignore.tmpl dot_config/hypr/ dot_config/waybar/ dot_config/swaync/ dot_config/kanata/ scripts/setup-kanata-cachyos.sh
git status
git commit --no-gpg-sign -m "feat(desktop-ux): full config set (hypr+waybar+swaync+kanata+wallpaper) + ignore for swaync"
git push origin main
```

- [ ] **Step 5: Verify commit landed**

```bash
git -C /Users/nazarfedisin/.local/share/chezmoi log --oneline -3
```

Expected: top commit is the batched desktop-ux commit, pushed to origin.

---

## Task 7: Fetch Gruvbox wallpapers on CachyOS

**Files:**
- Create on CachyOS: `~/Pictures/Wallpapers/gruvbox/*.png`
- Symlink: `~/Pictures/Wallpapers/gruvbox-default.png`

**Context:** Wallpapers are binary blobs (~1-5 MB each) — don't track in chezmoi. Fetch from `AngelJumbo/gruvbox-wallpapers` and pick 3-5 favorites. Set one as default symlink so `swww img` in exec-once finds it.

- [ ] **Step 1: [CachyOS] Create wallpaper dir**

```bash
ssh nazarf@nazarf-cachyos 'mkdir -p ~/Pictures/Wallpapers/gruvbox && ls -la ~/Pictures/Wallpapers/'
```

- [ ] **Step 2: [CachyOS] Fetch a curated set of 5 wallpapers from the repo**

```bash
ssh nazarf@nazarf-cachyos 'cd ~/Pictures/Wallpapers/gruvbox && \
  for f in mountain.png mountains.png road.png forest.png city.png; do
    curl -sSL -o "$f" "https://raw.githubusercontent.com/AngelJumbo/gruvbox-wallpapers/main/wallpapers/minimalistic/$f" || \
      curl -sSL -o "$f" "https://raw.githubusercontent.com/AngelJumbo/gruvbox-wallpapers/main/wallpapers/nature/$f" || \
      echo "NOTE: $f not found in either path — skipping"
  done && ls -la'
```

Expected: 3-5 PNG files downloaded, each 100KB-3MB. Some may 404 — that's OK as long as at least 1 succeeds.

- [ ] **Step 3: [CachyOS] Set default wallpaper symlink to the first successful download**

```bash
ssh nazarf@nazarf-cachyos 'cd ~/Pictures/Wallpapers && \
  default=$(ls -1 gruvbox/*.png 2>/dev/null | head -1) && \
  ln -sf "$default" gruvbox-default.png && \
  ls -la gruvbox-default.png'
```

Expected: symlink created pointing to first PNG in `gruvbox/`. If no PNGs downloaded — wallpaper-init.sh will fall back to solid Gruvbox color (per Task 3 script).

- [ ] **Step 4: NO commit (binary files not tracked).** Move to Task 8.

---

## Task 8: Apply chezmoi on CachyOS + reload Hyprland (skips kanata)

**Files:**
- All chezmoi-managed files from Tasks 3/4/5/6 applied to live paths on CachyOS.

**Context:** Pull commits from Task 6 on CachyOS, run `chezmoi apply`. New configs land in their live paths. Hyprland needs to reload (or relogin) to pick up exec-once additions (waybar, swaync, hypridle, swww) and updated binds. kanata is NOT touched here — Task 9 handles it.

- [ ] **Step 1: [CachyOS] Pull latest chezmoi source**

```bash
ssh nazarf@nazarf-cachyos 'cd ~/.local/share/chezmoi && git pull --ff-only origin main 2>&1 | tail -5'
```

Expected: fast-forward to top commit from Task 6.

- [ ] **Step 2: [CachyOS] Review chezmoi diff before apply**

```bash
ssh nazarf@nazarf-cachyos 'chezmoi diff' > /tmp/desktop-ux-diff.txt
wc -l /tmp/desktop-ux-diff.txt
head -100 /tmp/desktop-ux-diff.txt
grep -E '^diff --git' /tmp/desktop-ux-diff.txt
```

Expected: diff shows changes ONLY to `.config/{hypr,waybar,swaync,kanata}/...`. No surprise changes to `.zshrc`, `.gitconfig`, etc.

- [ ] **Step 3: [CachyOS] Apply chezmoi**

```bash
ssh nazarf@nazarf-cachyos 'chezmoi apply -v --force 2>&1' | tee /tmp/desktop-ux-apply.log
tail -20 /tmp/desktop-ux-apply.log
```

Expected: all chezmoi-managed files updated. No errors.

- [ ] **Step 4: [CachyOS] Verify files landed**

```bash
ssh nazarf@nazarf-cachyos 'ls -la ~/.config/hypr/ ~/.config/waybar/ ~/.config/swaync/ ~/.config/kanata/'
```

Expected: all expected files in their dirs (hypridle.conf in hypr; config.jsonc + style.css in waybar; config.json + style.css in swaync; keychron.kbd in kanata).

- [ ] **Step 5: [CachyOS] Reload Hyprland**

```bash
ssh nazarf@nazarf-cachyos 'hyprctl reload 2>&1'
sleep 2
ssh nazarf@nazarf-cachyos 'hyprctl reload 2>&1'  # second reload to ensure exec-once fires for new entries
```

Note: `hyprctl reload` re-reads config but does NOT re-run exec-once for entries that were already running pre-reload. NEW exec-once entries (waybar, swaync, etc.) WILL fire on the second reload because they weren't running before.

If user is at the PC, prefer logout/login for clean state.

- [ ] **Step 6: [CachyOS] Verify all desktop services started**

```bash
ssh nazarf@nazarf-cachyos 'for svc in waybar swaync hypridle swww-daemon hyprpolkitagent; do
  if pgrep -x "$svc" >/dev/null; then
    echo "OK: $svc running (pid $(pgrep -x $svc))"
  else
    echo "MISSING: $svc not running"
  fi
done'
```

Expected: all 5 lines start with `OK:`. If any `MISSING:` — debug that one (`journalctl --user --since "5 min ago" | grep <svc>`).

- [ ] **Step 7: NO commit** (system-state only at this point; Task 11 does the final STATUS commit).

---

## Task 9: Install kanata system service (HIGH RISK)

**Files:**
- Created on CachyOS by installer: `/etc/udev/rules.d/99-uinput.rules`, `/etc/systemd/system/kanata.service`, `/etc/modules-load.d/uinput.conf`
- Modified on CachyOS: `nazarf` group membership (added to `uinput`, `input`)

**Context:** HIGH RISK because if kanata config has a bug and intercepts everything, keys may stop working at the OS level. Recovery: SSH from MacBook still works (sshd unaffected) → `sudo systemctl stop kanata.service`. KVM toggle to MacBook is also an instant escape.

Since Keychron is currently NOT attached (KVM on MacBook), kanata will start but find no devices to attach to (via `--watch-devices`). When user is at the PC later and KVM-switches, kanata auto-discovers the Keychron and applies the remap.

- [ ] **Step 1: [CachyOS] Verify kanata binary + config present**

```bash
ssh nazarf@nazarf-cachyos 'command -v kanata && kanata --version'
ssh nazarf@nazarf-cachyos 'ls -la ~/.config/kanata/keychron.kbd'
```

Expected: kanata version printed, keychron.kbd exists.

- [ ] **Step 2: [CachyOS] Test config syntax (dry-run check)**

```bash
ssh nazarf@nazarf-cachyos 'kanata --cfg ~/.config/kanata/keychron.kbd --check 2>&1 | tail -10'
```

Expected: no syntax errors. If errors — fix the kbd config in chezmoi source on MacBook, commit, pull, retry.

- [ ] **Step 3: [CachyOS] Run the installer script (this is what introduces the system service)**

```bash
ssh -t nazarf@nazarf-cachyos 'bash ~/.local/share/chezmoi/scripts/setup-kanata-cachyos.sh'
```

`-t` for TTY because the script uses `sudo` interactively (CachyOS sudo may not be NOPASSWD — verified in Plan 1 it WAS no-prompt; if it prompts here, user needs to be at PC OR enable NOPASSWD).

Expected: script runs through all steps, ends with service status output.

If sudo prompts → see [Sudo handling] note below.

- [ ] **Step 4: [CachyOS] Verify kanata service**

```bash
ssh nazarf@nazarf-cachyos 'systemctl is-active kanata.service && systemctl status kanata.service --no-pager | head -20'
```

Expected: `active` + status block. Note: it may say "waiting for devices" — that's correct because Keychron isn't attached (KVM on MacBook).

- [ ] **Step 5: [CachyOS] Confirm user is in uinput + input groups**

```bash
ssh nazarf@nazarf-cachyos 'groups'
```

Expected: `nazarf wheel uinput input ...` — both `uinput` and `input` listed. If not — the user may need to logout/login (group changes don't apply to existing sessions) or run `newgrp uinput`.

- [ ] **Step 6: [CachyOS] Test that the service DOESN'T loop-fail (give it 30s, then re-check)**

```bash
sleep 30
ssh nazarf@nazarf-cachyos 'systemctl status kanata.service --no-pager | head -5 && systemctl show kanata.service --property=NRestarts'
```

Expected: still `active`, `NRestarts=0` or `1` (one restart is OK; >5 means looping — investigate).

- [ ] **Step 7: NO commit** (system state).

---

### Sudo handling

If `setup-kanata-cachyos.sh` blocks on sudo prompt and user is AFK:
1. Implementer abort with status BLOCKED.
2. Controller messages user: "Need you at CachyOS keyboard to type sudo password for kanata install, OR enable NOPASSWD via `sudo visudo` once."
3. User handles, then re-dispatch Task 9 from Step 3.

---

## Task 10: User-physical verification (REQUIRES USER AT CACHYOS KEYBOARD)

**Files:** none — interactive testing.

**Context:** This task CANNOT be done by a subagent. It requires the user physically at the CachyOS PC with KVM switched to CachyOS. The verification matrix:

| Test | Action | Expected |
|---|---|---|
| Caps→Esc | Press Caps in Ghostty or vim | Cursor exits insert mode (or terminal beeps) |
| Caps→Ctrl (hold) | Hold Caps + press L in Ghostty | Terminal clears (Ctrl-L) |
| lAlt→Super | Press left Alt + Space | wofi launcher opens |
| lAlt→Super for workspace | Press left Alt + 2 | Switches to workspace 2 |
| Win→Alt | Press left Win + Tab | Alt-Tab behavior (or noop if no Alt-tab handler — fine) |
| rAlt→AltGr | Press right Alt + a in text field | German ä (if us(intl) variant) or pass-through |
| Layout toggle | Press Right Ctrl | Waybar language module shows "UA" → next press → "EN" |
| KVM toggle | Switch KVM to MacBook, then back to CachyOS | After return, Caps→Esc still works (kanata reattached via --watch-devices) |
| Screenshot full | Cmd+Shift+3 | PNG saved to ~/Pictures/Screenshots/, swaync toast appears |
| Screenshot region | Cmd+Shift+4 → drag region | PNG saved + clipboard populated + toast |
| Screenshot annotate | Cmd+Shift+5 → drag region | satty opens with the region; arrow/text tools work; Enter saves+copies |
| swaync panel | Cmd+N | Notification center slides in from right; DND toggle visible |
| Idle dim (5min) | Leave PC alone 5 min | Screen dims to 30% |
| Idle lock (10min) | Leave PC alone 10 min | hyprlock appears; password prompt |
| Hyprland reload | Cmd+Shift+R | Hyprland config reloaded (Waybar may flicker) |

- [ ] **Step 1: User at CachyOS — switch KVM to CachyOS, attach Keychron**

User action. No script.

- [ ] **Step 2: User runs each test from the matrix; reports any failure**

For each failure: capture exact action, expected, actual, journalctl output if relevant. Report back to plan controller.

- [ ] **Step 3: Common failures + fixes**

| Failure | Likely cause | Fix |
|---|---|---|
| Caps still types text | kanata not attached to Keychron | `journalctl -u kanata.service --since "1 min ago"` — check device-name regex |
| All keys frozen | kanata config bug intercepting everything | SSH from MacBook: `sudo systemctl stop kanata.service`, fix config, re-apply |
| Layout toggle doesn't work | Right Ctrl rebound somewhere else | Check `hyprctl getoption input:kb_options` |
| Waybar missing | `pgrep waybar` empty | `waybar &` manually; check `~/.config/waybar/config.jsonc` syntax via `waybar -l debug` |
| swaync silent | No daemon running | `pgrep swaync` and start `swaync &` |
| Idle lock doesn't fire | `hypridle` not running | `pgrep hypridle`; check `~/.config/hypr/hypridle.conf` syntax |

- [ ] **Step 4: User reports green/red per test**

---

## Task 11: STATUS update + final commit

**Files:**
- Modify: `/Users/nazarfedisin/.local/share/chezmoi/docs/cachyos-setup/STATUS.md`

**Context:** Mark Phase 3 (Keyboard parity) and parts of Phase 5 (Desktop polish) as complete in STATUS. Add Plan 3 journal entry.

- [ ] **Step 1: Read current STATUS**

```bash
cat /Users/nazarfedisin/.local/share/chezmoi/docs/cachyos-setup/STATUS.md | head -25
```

- [ ] **Step 2: Update progress block**

Use Edit tool to change:

OLD:
```
Phase 2 — NVIDIA + CUDA           █████████░  90% (driver 595.71.05 + nvidia-container-toolkit + CDI; kanata/Hyprland pending)
Phase 3 — Keyboard parity         ░░░░░░░░░░   0%
```

NEW:
```
Phase 2 — NVIDIA + CUDA           ██████████ 100% (driver 595.71.05 + nvidia-container-toolkit + CDI)
Phase 3 — Keyboard parity         ██████████ 100% (kanata Caps→Esc/Ctrl, lAlt→Super, KVM-safe via --watch-devices)
Phase 3b — Desktop polish         ██████████ 100% (Waybar+swaync+hypridle+swww+hyprshot all Gruvbox)
```

- [ ] **Step 3: Add journal entry to the end**

Append:
```
- **2026-05-25** — **Plan 3 Desktop UX COMPLETE** (`docs/cachyos-setup/specs/2026-05-25-desktop-ux-design.md`, plans/2026-05-25-desktop-ux-implementation.md). kanata system service via `scripts/setup-kanata-cachyos.sh` (udev + uinput group + systemd unit), config `~/.config/kanata/keychron.kbd` matches by device-name regex, survives KVM disconnect via `--watch-devices`. Waybar top bar with GPU temp / CPU / RAM / network / audio / layout / tray, Gruvbox Dark Hard styling. swaync replaces basic mako semantics (notification center, DND, history). hypridle 5min dim / 10min lock / 30min DPMS off. swww wallpaper daemon with AngelJumbo gruvbox-wallpapers. hyprshot+satty for screenshots. Ukrainian layout toggle via Right Ctrl. .chezmoiignore.tmpl extended for .config/swaync.
```

- [ ] **Step 4: Commit + push**

```bash
cd /Users/nazarfedisin/.local/share/chezmoi
git add docs/cachyos-setup/STATUS.md
git commit --no-gpg-sign -m "docs(cachyos): Plan 3 Desktop UX complete (kanata + Waybar + swaync + hypridle + swww)"
git push origin main
```

---

## Success criteria — Plan 3 done when:

1. `ssh nazarf@nazarf-cachyos 'systemctl is-active kanata.service'` returns `active`
2. `ssh nazarf@nazarf-cachyos 'pgrep -x waybar swaync hypridle swww-daemon hyprpolkitagent'` shows 5 PIDs
3. User physical verification (Task 10): Caps→Esc works, lAlt→Super opens wofi via Cmd+Space, Right Ctrl toggles UA layout, Cmd+Shift+4 captures region with swaync toast
4. `chezmoi diff` clean on both machines
5. `chezmoi managed` on MacBook does NOT include `.config/swaync` (ignore template working)
6. Waybar renders top bar with all 7 right-cluster modules visible
7. Ollama service from Plan 1 still `active` (not regressed by any Plan 3 change)
8. Final commit pushed to origin

---

## Rollback procedures

### kanata config bug → keyboard frozen

From MacBook:
```bash
ssh nazarf@nazarf-cachyos 'sudo systemctl stop kanata.service && sudo systemctl disable kanata.service'
```
Then fix `dot_config/kanata/keychron.kbd` on MacBook, commit, pull on CachyOS, re-run installer.

### Waybar / swaync / hypridle won't start

Check `journalctl --user --since "10 min ago" | grep <svc>`. Usually CSS/JSON syntax error — fix in chezmoi source, commit, pull, apply.

### Hyprland reload breaks layout

Revert hyprland.conf:
```bash
cd /Users/nazarfedisin/.local/share/chezmoi
git revert HEAD       # the Task 6 batched commit
git push
ssh nazarf@nazarf-cachyos 'chezmoi update && chezmoi apply && hyprctl reload'
```

### Wallpaper missing → swww errors

Re-run Task 7 to fetch wallpapers. If repo URLs changed, find current path in `AngelJumbo/gruvbox-wallpapers` and update Task 7 Step 2.

---

## What's next (out of scope for Plan 3)

- **Plan 4 — Dev IDE on CachyOS:** Cursor / Zed / VSCode + 1Password Linux + git SSH signing
- **Plan 5 — vLLM + HF training stack:** completes the ML capability (Plan 1 only did Ollama)
- **Plan 6 — Isaac Lab/Sim/GR00T:** the original ML/robotics goal
- **Plan 7 — Networking polish:** Tailscale on Hetzner k3s + Cloudflare Tunnel + LiteLLM proxy
- **Plan 8 — Remote training UX + power management:** nvitop, tensorboard via Tailscale, `nvidia-smi -pl 250`, restic for checkpoints
- **Eventual:** Walker launcher migration (when out of beta), per-workspace wallpapers, Conky overlays
