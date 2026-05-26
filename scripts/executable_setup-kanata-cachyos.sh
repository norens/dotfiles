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
#   5. Drops udev rule to restart kanata when Keychron K3 hotplugs in
#      (KVM toggle disconnect/reconnect — kanata 1.11's internal watch
#      detects the new device but doesn't re-grab it; an explicit restart
#      via udev RUN+= is the reliable fix.)
#   6. Enables and starts the service
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

log "Writing /etc/udev/rules.d/98-kanata-keychron-restart.rules..."
# Match Keychron K3 by USB IDs (Apple VID 05ac since Keychron clones it for
# macOS compatibility, K3 PID 024f). Restart kanata via systemd-run so udev
# doesn't block waiting for the restart to finish.
sudo tee /etc/udev/rules.d/98-kanata-keychron-restart.rules >/dev/null <<'RULE'
ACTION=="add", SUBSYSTEM=="input", ENV{ID_INPUT_KEYBOARD}=="1", \
  ATTRS{idVendor}=="05ac", ATTRS{idProduct}=="024f", \
  RUN+="/usr/bin/systemd-run --no-block /bin/sh -c 'sleep 1 && /usr/bin/systemctl restart kanata.service'"
RULE
sudo udevadm control --reload

log "Writing /etc/systemd/system/kanata.service..."
sudo tee /etc/systemd/system/kanata.service >/dev/null <<UNIT
[Unit]
Description=kanata keyboard remapper
After=systemd-user-sessions.service

[Service]
Type=simple
ExecStart=/usr/bin/kanata --cfg /home/${USER}/.config/kanata/keychron.kbd
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
log "  3. Once Keychron is attached, the udev rule auto-restarts kanata."
log ""
log "If active but Caps doesn't map to Esc:"
log "  - Confirm Keychron device name in /proc/bus/input/devices matches 'Keychron'."
log "  - If USB IDs differ, edit /etc/udev/rules.d/98-kanata-keychron-restart.rules."
