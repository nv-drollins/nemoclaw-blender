#!/usr/bin/env bash
set -euo pipefail

TOKEN_FILE="${1:-/tmp/openclaw-token}"

if [ ! -f "$TOKEN_FILE" ]; then
  echo "Token file not found: $TOKEN_FILE" >&2
  exit 1
fi

TOKEN="$(cat "$TOKEN_FILE")"

openclaw gateway stop || true
sleep 3

PATH="/sandbox/bin:$PATH" nohup openclaw gateway run \
  --allow-unconfigured --dev \
  --bind loopback --port 18789 \
  --token "$TOKEN" \
  >/tmp/gateway.log 2>&1 &

echo "OpenClaw gateway restarted with /sandbox/bin on PATH"
