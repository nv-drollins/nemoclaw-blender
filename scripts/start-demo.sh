#!/usr/bin/env bash
set -euo pipefail

ROOT="${NEMOCLAW_BLENDER_DEMO_ROOT:-$HOME/nemoclaw-blender-demo}"
SANDBOX="${NEMOCLAW_SANDBOX_NAME:-blender-agent}"
SPARK_IP="${SPARK_IP:-192.168.1.164}"
RUN_SMOKE=0
RESTART_GATEWAY=1

usage() {
  cat <<EOF
Usage: $0 [--sandbox NAME] [--spark-ip IP] [--smoke] [--skip-gateway-restart]

Starts an already-installed NemoClaw Blender demo:
  - verifies the NemoClaw sandbox exists
  - starts Blender MCP on localhost:9876
  - starts mcp-proxy on 0.0.0.0:9877
  - reapplies the Blender MCP sandbox policy
  - verifies / repairs mcporter in the sandbox
  - reinstalls the Blender skill and restarts OpenClaw gateway

Options:
  --sandbox NAME           NemoClaw sandbox name. Default: $SANDBOX
  --spark-ip IP            Host IP used by sandbox mcporter config. Default: $SPARK_IP
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
    --spark-ip)
      SPARK_IP="${2:?missing Spark IP}"
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
"$ROOT/scripts/apply-blender-policy.sh" "$SANDBOX"

SSH_CONFIG="/tmp/${SANDBOX}.ssh_config"
openshell sandbox ssh-config "$SANDBOX" > "$SSH_CONFIG"

echo "[4/6] Checking mcporter"
if ! ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" test -x /sandbox/bin/mcporter; then
  "$ROOT/scripts/vendor-mcporter-to-sandbox.sh" "$SANDBOX" "$SPARK_IP"
else
  ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" /sandbox/bin/mcporter --help >/dev/null
  echo "mcporter already available in sandbox $SANDBOX"
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
mcp-proxy: http://$SPARK_IP:9877/sse

OpenClaw token:
  nemoclaw $SANDBOX gateway-token --quiet
EOF
