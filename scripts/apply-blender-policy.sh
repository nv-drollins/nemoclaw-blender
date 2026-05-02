#!/usr/bin/env bash
set -euo pipefail

SANDBOX="${1:-blender-agent}"
ROOT="${NEMOCLAW_BLENDER_DEMO_ROOT:-$HOME/nemoclaw-blender-demo}"

export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
nemoclaw "$SANDBOX" policy-add --from-file "$ROOT/policies/blender-mcp.yaml" --yes
