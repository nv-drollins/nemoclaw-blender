#!/usr/bin/env bash
set -euo pipefail

SESSION_ID="${OPENCLAW_SMOKE_SESSION_ID:-blender-agent-smoke-$(date +%s)}"

openclaw agent \
  --agent main \
  --session-id "$SESSION_ID" \
  --timeout 600 \
  -m "Use the blender skill to inspect the Blender scene with /sandbox/bin/mcporter call blender.get_scene_info user_prompt=agent-smoke. Reply with the object names only."
