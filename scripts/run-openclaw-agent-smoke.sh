#!/usr/bin/env bash
set -euo pipefail

openclaw agent \
  --agent main \
  --local \
  --session-id blender-agent-smoke \
  -m "Use the blender skill to inspect the Blender scene with /sandbox/bin/mcporter call blender.get_scene_info user_prompt=agent-smoke. Reply with the object names only."
