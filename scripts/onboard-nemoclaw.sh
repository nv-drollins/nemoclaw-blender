#!/usr/bin/env bash
set -euo pipefail

SANDBOX="${NEMOCLAW_SANDBOX_NAME:-blender-agent}"
MODEL="${NEMOCLAW_MODEL:-nemotron-3-nano:30b}"

export NEMOCLAW_PROVIDER=ollama
export NEMOCLAW_MODEL="$MODEL"
export NEMOCLAW_SANDBOX_NAME="$SANDBOX"
export NEMOCLAW_POLICY_TIER="${NEMOCLAW_POLICY_TIER:-balanced}"
export NEMOCLAW_ACCEPT_THIRD_PARTY_SOFTWARE=1
export NEMOCLAW_NON_INTERACTIVE=1
export NEMOCLAW_LOCAL_INFERENCE_TIMEOUT="${NEMOCLAW_LOCAL_INFERENCE_TIMEOUT:-300}"

curl -fsSL https://www.nvidia.com/nemoclaw.sh -o /tmp/nemoclaw.sh
bash /tmp/nemoclaw.sh --non-interactive --yes-i-accept-third-party-software --fresh
