#!/usr/bin/env bash
set -euo pipefail

SANDBOX="${1:-${NEMOCLAW_SANDBOX_NAME:-blender-agent}}"
HOST_IP_ARG="${2:-${NEMOCLAW_BLENDER_HOST_IP:-${SPARK_IP:-}}}"
ROOT="${NEMOCLAW_BLENDER_DEMO_ROOT:-$HOME/nemoclaw-blender-demo}"
MCPORTER_VERSION="${MCPORTER_VERSION:-0.9.0}"
SSH_CONFIG="/tmp/${SANDBOX}.ssh_config"
INSTALL_DIR="$ROOT/mcporter-node"
TGZ="$ROOT/assets/mcporter-${MCPORTER_VERSION}.tgz"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

# shellcheck source=detect-host-ip.sh
. "$SCRIPT_DIR/detect-host-ip.sh"

HOST_IP="$(resolve_host_ip "$HOST_IP_ARG")"

mkdir -p "$ROOT/assets"
curl -fsSL "https://github.com/steipete/mcporter/releases/download/v${MCPORTER_VERSION}/mcporter-${MCPORTER_VERSION}.tgz" \
  -o "$TGZ"

openshell sandbox ssh-config "$SANDBOX" > "$SSH_CONFIG"

ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" killall npm 2>/dev/null || true

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
npm install --prefix "$INSTALL_DIR" "$TGZ"

scp -F "$SSH_CONFIG" -r "$INSTALL_DIR/node_modules" "openshell-$SANDBOX:/sandbox/"
scp -F "$SSH_CONFIG" "$ROOT/scripts/repair-sandbox-mcporter-wrapper.sh" "openshell-$SANDBOX:/tmp/"
ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" bash /tmp/repair-sandbox-mcporter-wrapper.sh "$HOST_IP"

ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" /sandbox/bin/mcporter --help >/dev/null
echo "mcporter installed in sandbox $SANDBOX using host $HOST_IP"
