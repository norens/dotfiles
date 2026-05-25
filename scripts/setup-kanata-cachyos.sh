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
log "  3. Once Keychron is attached, kanata auto-discovers via --watch-devices."
log ""
log "If active but Caps doesn't map to Esc:"
log "  - Confirm Keychron device name in /proc/bus/input/devices matches 'Keychron' regex."
log "  - Adjust linux-dev-names-include in ~/.config/kanata/keychron.kbd accordingly."
