#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${NEMOCLAW_BLENDER_DEMO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SANDBOX="${NEMOCLAW_SANDBOX_NAME:-blender-agent}"
HOST_IP_ARG="${NEMOCLAW_BLENDER_HOST_IP:-${SPARK_IP:-}}"
RUN_SMOKE=0
RESTART_GATEWAY=1

usage() {
  cat <<EOF
Usage: $0 [--sandbox NAME] [--host-ip IP] [--smoke] [--skip-gateway-restart]

Starts an already-installed NemoClaw Blender demo:
  - verifies the NemoClaw sandbox exists
  - starts Blender MCP on localhost:9876
  - starts mcp-proxy on 0.0.0.0:9877
  - reapplies the Blender MCP sandbox policy
  - verifies / repairs mcporter in the sandbox
  - reinstalls the Blender skill and restarts OpenClaw gateway

Options:
  --sandbox NAME           NemoClaw sandbox name. Default: $SANDBOX
  --host-ip IP             Host IP used by sandbox mcporter config. Default: auto-detect
  --spark-ip IP            Deprecated alias for --host-ip.
  --smoke                  Run non-mutating and agent smoke checks after start.
  --skip-gateway-restart   Do not restart the in-sandbox OpenClaw gateway.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --sandbox)
      SANDBOX="${2:?missing sandbox name}"
      shift
      ;;
    --host-ip|--spark-ip)
      HOST_IP_ARG="${2:?missing host IP}"
      shift
      ;;
    --smoke) RUN_SMOKE=1 ;;
    --skip-gateway-restart) RESTART_GATEWAY=0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

# shellcheck source=detect-host-ip.sh
. "$SCRIPT_DIR/detect-host-ip.sh"

HOST_IP="$(resolve_host_ip "$HOST_IP_ARG")"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need nemoclaw
need openshell
need blender
need uvx

if [ ! -d "$ROOT" ]; then
  echo "Demo repo not found: $ROOT" >&2
  exit 1
fi

cd "$ROOT"

if ! openshell sandbox get "$SANDBOX" >/dev/null 2>&1; then
  echo "Sandbox '$SANDBOX' was not found." >&2
  echo "If it was destroyed, re-run: ./scripts/onboard-nemoclaw.sh" >&2
  exit 1
fi

if [ ! -f "$ROOT/assets/blender_mcp_addon.py" ]; then
  mkdir -p "$ROOT/assets"
  curl -fsSL https://raw.githubusercontent.com/ahujasid/blender-mcp/main/addon.py \
    -o "$ROOT/assets/blender_mcp_addon.py"
fi

echo "[1/6] Starting Blender MCP"
"$ROOT/scripts/start-host-blender-mcp.sh"

echo "[2/6] Starting mcp-proxy"
"$ROOT/scripts/start-mcp-proxy.sh"

echo "[3/6] Applying Blender MCP policy"
"$ROOT/scripts/apply-blender-policy.sh" "$SANDBOX" "$HOST_IP"

SSH_CONFIG="/tmp/${SANDBOX}.ssh_config"
openshell sandbox ssh-config "$SANDBOX" > "$SSH_CONFIG"

echo "[4/6] Checking mcporter"
if ! ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" test -x /sandbox/bin/mcporter; then
  "$ROOT/scripts/vendor-mcporter-to-sandbox.sh" "$SANDBOX" "$HOST_IP"
else
  scp -F "$SSH_CONFIG" "$ROOT/scripts/repair-sandbox-mcporter-wrapper.sh" "openshell-$SANDBOX:/tmp/"
  ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" bash /tmp/repair-sandbox-mcporter-wrapper.sh "$HOST_IP"
  ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" /sandbox/bin/mcporter --help >/dev/null
  echo "mcporter already available in sandbox $SANDBOX; config refreshed for $HOST_IP"
fi

echo "[5/6] Installing Blender skill"
if [ "$RESTART_GATEWAY" -eq 1 ]; then
  "$ROOT/scripts/install-blender-skill.sh" "$SANDBOX"
else
  ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" mkdir -p /sandbox/.openclaw/skills/blender
  scp -F "$SSH_CONFIG" "$ROOT/blender-skill/SKILL.md" \
    "openshell-$SANDBOX:/sandbox/.openclaw/skills/blender/SKILL.md"
  echo "Blender skill copied; gateway restart skipped"
fi

echo "[6/6] Verifying scene access"
ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" \
  /sandbox/bin/mcporter call blender.get_scene_info user_prompt=start-demo-check

if [ "$RUN_SMOKE" -eq 1 ]; then
  scp -F "$SSH_CONFIG" "$ROOT/scripts/run-openclaw-agent-smoke.sh" "openshell-$SANDBOX:/tmp/"
  ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" bash /tmp/run-openclaw-agent-smoke.sh
fi

cat <<EOF

Demo is running.

Sandbox: $SANDBOX
Blender MCP: localhost:9876
mcp-proxy: http://$HOST_IP:9877/sse

OpenClaw token:
  nemoclaw $SANDBOX gateway-token --quiet
EOF
