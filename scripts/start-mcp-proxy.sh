#!/usr/bin/env bash
set -euo pipefail

ROOT="${NEMOCLAW_BLENDER_DEMO_ROOT:-$HOME/nemoclaw-blender-demo}"
PORT="${BLENDER_MCP_PROXY_PORT:-9877}"

export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
export BLENDER_HOST="${BLENDER_HOST:-localhost}"
export BLENDER_PORT="${BLENDER_PORT:-9876}"
export DISABLE_TELEMETRY="${DISABLE_TELEMETRY:-true}"

mkdir -p "$ROOT/logs"

if ss -ltn | grep -q ":$PORT "; then
  echo "mcp-proxy already listening on 0.0.0.0:$PORT"
  exit 0
fi

nohup uvx mcp-proxy --host 0.0.0.0 --port "$PORT" uvx blender-mcp \
  >"$ROOT/logs/mcp-proxy.log" 2>&1 &
echo "$!" >"$ROOT/logs/mcp-proxy.pid"

for _ in $(seq 1 45); do
  if ss -ltn | grep -q ":$PORT "; then
    echo "mcp-proxy listening on 0.0.0.0:$PORT"
    exit 0
  fi
  sleep 1
done

echo "mcp-proxy did not become ready; see $ROOT/logs/mcp-proxy.log" >&2
exit 1
