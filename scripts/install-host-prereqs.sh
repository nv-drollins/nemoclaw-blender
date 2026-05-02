#!/usr/bin/env bash
set -euo pipefail

ROOT="${NEMOCLAW_BLENDER_DEMO_ROOT:-$HOME/nemoclaw-blender-demo}"

sudo apt-get update
sudo apt-get install -y blender python3-requests

curl -LsSf https://astral.sh/uv/install.sh -o /tmp/uv-install.sh
sh /tmp/uv-install.sh

mkdir -p "$ROOT/assets" "$ROOT/logs"
curl -fsSL https://raw.githubusercontent.com/ahujasid/blender-mcp/main/addon.py \
  -o "$ROOT/assets/blender_mcp_addon.py"

echo "Blender: $(blender --version | head -n 1)"
echo "uvx: $("$HOME/.local/bin/uvx" --version)"
