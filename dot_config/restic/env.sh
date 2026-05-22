#!/bin/bash
# Source-only: populates restic + S3 env vars from 1Password via `op read`.
# Requires: 1Password Desktop unlocked, CLI integration enabled.
# Item: Personal vault → "Cloudflare R2 Backup" with custom fields:
#   - Access Key ID
#   - Secret Access Key
#   - Endpoint URL          (e.g. https://<account>.r2.cloudflarestorage.com)
#   - Bucket Name           (e.g. nazar-restic-backup)
#   - Restic Repo Password

set -euo pipefail

OP_ITEM="op://Personal/Cloudflare R2 Backup"

AWS_ACCESS_KEY_ID="$(op read "$OP_ITEM/Access Key ID")"
AWS_SECRET_ACCESS_KEY="$(op read "$OP_ITEM/Secret Access Key")"
RESTIC_PASSWORD="$(op read "$OP_ITEM/Restic Repo Password")"

_endpoint="$(op read "$OP_ITEM/Endpoint URL")"
_bucket="$(op read "$OP_ITEM/Bucket Name")"

RESTIC_REPOSITORY="s3:${_endpoint}/${_bucket}"

export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY RESTIC_PASSWORD RESTIC_REPOSITORY
unset _endpoint _bucket
