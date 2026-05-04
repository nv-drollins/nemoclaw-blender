#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${NEMOCLAW_BLENDER_DEMO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SANDBOX="${NEMOCLAW_SANDBOX_NAME:-blender-agent}"
DESTROY_SANDBOX=0
STOP_GATEWAY=0

usage() {
  cat <<EOF
Usage: $0 [--stop-gateway] [--destroy-sandbox]

Stops host-side Blender demo services started by this repo:
  - mcp-proxy on port 9877
  - Blender MCP/Blender process recorded in logs/blender.pid

Options:
  --stop-gateway      Stop the in-sandbox OpenClaw gateway, but keep the sandbox.
  --destroy-sandbox   Permanently destroy the NemoClaw sandbox and its volume.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --stop-gateway) STOP_GATEWAY=1 ;;
    --destroy-sandbox) DESTROY_SANDBOX=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

stop_pid_file() {
  local name="$1"
  local pid_file="$2"

  if [ ! -f "$pid_file" ]; then
    echo "$name: no pid file at $pid_file"
    return 0
  fi

  local pid
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
    echo "$name: not running"
    rm -f "$pid_file"
    return 0
  fi

  echo "$name: stopping pid $pid"
  kill "$pid" 2>/dev/null || true
  for _ in $(seq 1 10); do
    if ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$pid_file"
      echo "$name: stopped"
      return 0
    fi
    sleep 1
  done

  echo "$name: forcing pid $pid"
  kill -9 "$pid" 2>/dev/null || true
  rm -f "$pid_file"
}

stop_port_processes() {
  local name="$1"
  local port="$2"
  local pids

  pids="$(lsof -ti ":$port" 2>/dev/null || true)"
  if [ -z "$pids" ]; then
    echo "$name: no process listening on port $port"
    return 0
  fi

  echo "$name: stopping process(es) on port $port: $pids"
  for pid in $pids; do
    kill "$pid" 2>/dev/null || true
  done
}

stop_pid_file "mcp-proxy" "$ROOT/logs/mcp-proxy.pid"
stop_port_processes "mcp-proxy" 9877

stop_pid_file "Blender" "$ROOT/logs/blender.pid"
stop_port_processes "Blender MCP" 9876

export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

if [ "$STOP_GATEWAY" -eq 1 ]; then
  if command -v openshell >/dev/null 2>&1; then
    ssh_config="/tmp/${SANDBOX}.ssh_config"
    if openshell sandbox ssh-config "$SANDBOX" > "$ssh_config" 2>/dev/null; then
      echo "OpenClaw gateway: stopping inside sandbox $SANDBOX"
      ssh -F "$ssh_config" "openshell-$SANDBOX" openclaw gateway stop || true
    else
      echo "OpenClaw gateway: could not resolve sandbox SSH config for $SANDBOX"
    fi
  else
    echo "OpenClaw gateway: openshell not on PATH"
  fi
fi

if [ "$DESTROY_SANDBOX" -eq 1 ]; then
  if command -v nemoclaw >/dev/null 2>&1; then
    echo "Destroying sandbox $SANDBOX. This deletes its persistent volume."
    nemoclaw "$SANDBOX" destroy --yes
  else
    echo "Sandbox destroy requested, but nemoclaw is not on PATH" >&2
    exit 1
  fi
fi

echo "Demo services stopped."
