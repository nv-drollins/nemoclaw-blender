#!/usr/bin/env bash
set -euo pipefail

SESSION_ID="${OPENCLAW_RED_CUBE_SESSION_ID:-blender-red-cube-smoke-$(date +%s)}"

openclaw agent \
  --agent main \
  --session-id "$SESSION_ID" \
  --timeout 600 \
  -m "Use the blender skill and /sandbox/bin/mcporter to create a red cube at the center of the Blender scene. Name it OpenClawRedCube. Reply briefly with what you did."

/sandbox/bin/mcporter call blender.get_object_info \
  object_name=OpenClawRedCube \
  user_prompt=red-cube-smoke
