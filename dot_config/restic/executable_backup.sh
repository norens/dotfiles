#!/bin/bash
# Daily restic backup to Cloudflare R2.
# Invoked by launchd (com.user.restic-backup) or manually.

set -euo pipefail

CONFIG_DIR="${HOME}/.config/restic"
LOG_DIR="${HOME}/Library/Logs/restic"
mkdir -p "$LOG_DIR"

# Ensure brew + op are in PATH (launchd starts with minimal env)
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Make sure 1Password is unlocked (will fail fast if locked)
if ! op vault list >/dev/null 2>&1; then
  echo "[$(date '+%F %T')] FAIL: 1Password CLI cannot reach desktop. Skipping run."
  exit 1
fi

# Load creds into env
# shellcheck disable=SC1091
source "${CONFIG_DIR}/env.sh"

TARGETS=(
  "${HOME}/.local/share/chezmoi"
)

echo "[$(date '+%F %T')] starting backup, repo=${RESTIC_REPOSITORY}"

restic backup \
  --exclude-file="${CONFIG_DIR}/excludes.txt" \
  --exclude-caches \
  --one-file-system \
  --tag daily \
  --tag macbook \
  "${TARGETS[@]}"

echo "[$(date '+%F %T')] backup complete, applying retention"

# Retention: 7 daily, 4 weekly, 6 monthly
restic forget \
  --prune \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --tag daily

echo "[$(date '+%F %T')] done"
