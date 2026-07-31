#!/bin/bash
#
# claude-local — run Claude Code against the local model on the CachyOS box
# instead of the Anthropic API.
#
# Plan: ~/.claude/plans/floating-wiggling-creek.md
#
# Everything is scoped to this subprocess: ~/.claude/settings.json is never
# touched, so a plain `claude` keeps talking to Anthropic with your normal
# model, plugins, and statusline. Nothing here persists after the process exits.
#
# Usage:
#   claude-local                                   # default model
#   CLAUDE_LOCAL_MODEL=qwen3.6:35b claude-local    # try another candidate
#   claude-local -p "explain this repo"            # args pass through to claude
#
# Env:
#   CLAUDE_LOCAL_MODEL   Ollama model tag (default: gpt-oss:20b)
#   CLAUDE_LOCAL_HOST    Ollama host:port (default: the box's Tailscale address)
#
# Expect this to be slower and less reliable at tool calls than the real thing —
# a 16 GiB card is the constraint, not the client. If tool calls come back as
# plain text instead of structured calls, that's the model, not the wiring.
#
# Model choice here is decided by prefill, not by generation speed. Claude Code
# sends a ~37K-token system prompt every turn, so a model whose weights spill into
# RAM pays for that spill across all 37K tokens before emitting a thing. Measured
# on the same "read this file, find the bug" task, 2026-07-31:
#   gpt-oss:20b      14.5 GB, 100% on GPU   168 tok/s      15s end-to-end
#   qwen3-coder:30b  22.6 GB,  66% on GPU    33 tok/s    2m15s end-to-end
# A 5x gap in generation became a 9x gap on the clock. qwen3-coder is the better
# coder on paper (256K ctx, RL-trained on SWE-bench) and is worth switching to for
# one hard question, but it is not what you want in an interactive loop.

set -euo pipefail

MODEL="${CLAUDE_LOCAL_MODEL:-gpt-oss:20b}"
HOST="${CLAUDE_LOCAL_HOST:-100.104.21.28:11434}"

die() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

command -v claude >/dev/null || die "claude not found on PATH"

# Fail here with a clear message rather than letting Claude Code report a
# confusing auth or connection error against a box that is simply off.
if ! curl -sf --max-time 5 "http://${HOST}/api/tags" >/dev/null 2>&1; then
  die "Ollama unreachable at ${HOST} — run 'cachy status' (box off, or Tailscale stopped?)"
fi

if ! curl -sf --max-time 5 "http://${HOST}/api/tags" | grep -q "\"${MODEL}\""; then
  die "model '${MODEL}' not pulled on the box — run: ollama pull ${MODEL}"
fi

printf '\033[1;34m[claude-local]\033[0m %s via %s\n' "$MODEL" "$HOST"

# ANTHROPIC_API_KEY must be empty, not merely unset: an inherited key would
# otherwise take precedence over ANTHROPIC_AUTH_TOKEN and send requests to
# Anthropic instead of the box.
exec env \
  ANTHROPIC_BASE_URL="http://${HOST}" \
  ANTHROPIC_AUTH_TOKEN=ollama \
  ANTHROPIC_API_KEY= \
  claude --model "$MODEL" "$@"
