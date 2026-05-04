#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=resolve-demo-root.sh
. "$SCRIPT_DIR/resolve-demo-root.sh"
ROOT="$(resolve_demo_root "$SCRIPT_DIR")"
PORT="${BLENDER_MCP_PORT:-9876}"
DISPLAY="${DISPLAY:-:1}"
XAUTHORITY="${XAUTHORITY:-/run/user/$(id -u)/gdm/Xauthority}"

export BLENDER_MCP_ADDON="${BLENDER_MCP_ADDON:-$ROOT/assets/blender_mcp_addon.py}"
export BLENDER_MCP_PORT="$PORT"
export DISPLAY
export XAUTHORITY

mkdir -p "$ROOT/logs"
echo "Blender MCP log: $ROOT/logs/blender.log"

if ss -ltn | grep -q ":$PORT "; then
  echo "Blender MCP socket already listening on localhost:$PORT"
  exit 0
fi

nohup blender --python "$ROOT/scripts/start_blender_mcp.py" \
  >"$ROOT/logs/blender.log" 2>&1 &
echo "$!" >"$ROOT/logs/blender.pid"

for _ in $(seq 1 30); do
  if ss -ltn | grep -q ":$PORT "; then
    echo "Blender MCP socket listening on localhost:$PORT"
    exit 0
  fi
  sleep 1
done

echo "Blender MCP did not become ready; see $ROOT/logs/blender.log" >&2
if [ -f "$ROOT/logs/blender.log" ]; then
  tail -80 "$ROOT/logs/blender.log" >&2
fi
exit 1
