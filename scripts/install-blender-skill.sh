#!/usr/bin/env bash
set -euo pipefail

SANDBOX="${1:-blender-agent}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=resolve-demo-root.sh
. "$SCRIPT_DIR/resolve-demo-root.sh"
ROOT="$(resolve_demo_root "$SCRIPT_DIR")"
SSH_CONFIG="/tmp/${SANDBOX}.ssh_config"

export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

openshell sandbox ssh-config "$SANDBOX" > "$SSH_CONFIG"
ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" mkdir -p /sandbox/.openclaw/skills/blender
scp -F "$SSH_CONFIG" "$ROOT/blender-skill/SKILL.md" \
  "openshell-$SANDBOX:/sandbox/.openclaw/skills/blender/SKILL.md"

nemoclaw "$SANDBOX" gateway-token --quiet > /tmp/openclaw-token
scp -F "$SSH_CONFIG" /tmp/openclaw-token "openshell-$SANDBOX:/tmp/openclaw-token"
scp -F "$SSH_CONFIG" "$ROOT/scripts/restart-openclaw-gateway.sh" "openshell-$SANDBOX:/tmp/"
ssh -F "$SSH_CONFIG" "openshell-$SANDBOX" bash /tmp/restart-openclaw-gateway.sh /tmp/openclaw-token

echo "Blender skill installed in sandbox $SANDBOX"
