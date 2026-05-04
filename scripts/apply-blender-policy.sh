#!/usr/bin/env bash
set -euo pipefail

SANDBOX="${1:-${NEMOCLAW_SANDBOX_NAME:-blender-agent}}"
ROOT="${NEMOCLAW_BLENDER_DEMO_ROOT:-$HOME/nemoclaw-blender-demo}"
HOST_IP_ARG="${2:-${NEMOCLAW_BLENDER_HOST_IP:-${SPARK_IP:-}}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_FILE="/tmp/${SANDBOX}.blender-mcp.yaml"

export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

# shellcheck source=detect-host-ip.sh
. "$SCRIPT_DIR/detect-host-ip.sh"

HOST_IP="$(resolve_host_ip "$HOST_IP_ARG")"
sed "s/__HOST_IP__/$HOST_IP/g" "$ROOT/policies/blender-mcp.yaml" > "$POLICY_FILE"

echo "Applying Blender MCP policy for host $HOST_IP"
nemoclaw "$SANDBOX" policy-add --from-file "$POLICY_FILE" --yes
