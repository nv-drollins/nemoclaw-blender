#!/usr/bin/env bash
set -euo pipefail

SANDBOX="${NEMOCLAW_SANDBOX_NAME:-blender-agent}"
MODEL="${NEMOCLAW_MODEL:-nemotron-3-nano:30b}"
OLLAMA_WRAPPER_DIR="$(mktemp -d)"
REAL_OLLAMA_BIN="${NEMOCLAW_OLLAMA_BIN:-}"
if [ -z "$REAL_OLLAMA_BIN" ]; then
  REAL_OLLAMA_BIN="$(command -v ollama 2>/dev/null || true)"
fi

cleanup() {
  rm -rf "$OLLAMA_WRAPPER_DIR"
}
trap cleanup EXIT

export NEMOCLAW_PROVIDER=ollama
export NEMOCLAW_MODEL="$MODEL"
export NEMOCLAW_SANDBOX_NAME="$SANDBOX"
export NEMOCLAW_POLICY_TIER="${NEMOCLAW_POLICY_TIER:-balanced}"
export NEMOCLAW_ACCEPT_THIRD_PARTY_SOFTWARE=1
export NEMOCLAW_NON_INTERACTIVE=1
export NEMOCLAW_LOCAL_INFERENCE_TIMEOUT="${NEMOCLAW_LOCAL_INFERENCE_TIMEOUT:-300}"
if [ -n "$REAL_OLLAMA_BIN" ]; then
  export NEMOCLAW_OLLAMA_BIN="$REAL_OLLAMA_BIN"
fi

cat >"$OLLAMA_WRAPPER_DIR/ollama" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

find_real_ollama() {
  local self candidate resolved
  self="$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")"

  if [ -n "${NEMOCLAW_OLLAMA_BIN:-}" ] && [ -x "$NEMOCLAW_OLLAMA_BIN" ]; then
    resolved="$(readlink -f "$NEMOCLAW_OLLAMA_BIN" 2>/dev/null || printf '%s' "$NEMOCLAW_OLLAMA_BIN")"
    if [ "$resolved" != "$self" ]; then
      printf '%s\n' "$NEMOCLAW_OLLAMA_BIN"
      return 0
    fi
  fi

  for candidate in /usr/local/bin/ollama /usr/bin/ollama /bin/ollama; do
    if [ -x "$candidate" ]; then
      resolved="$(readlink -f "$candidate" 2>/dev/null || printf '%s' "$candidate")"
      if [ "$resolved" != "$self" ]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    fi
  done

  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    resolved="$(readlink -f "$candidate" 2>/dev/null || printf '%s' "$candidate")"
    if [ "$resolved" != "$self" ] && [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(type -P -a ollama 2>/dev/null | awk '!seen[$0]++')
}

desired_model="${NEMOCLAW_MODEL:-}"
if [ "$#" -ge 2 ] && [ "$1" = "pull" ] && [ -n "$desired_model" ]; then
  requested_model="$2"
  case "$requested_model" in
    nemotron-3-nano:30b|nemotron-3-super:120b)
      if [ "$requested_model" != "$desired_model" ]; then
        echo "Redirecting NemoClaw installer model pull from $requested_model to $desired_model" >&2
        shift 2
        set -- pull "$desired_model" "$@"
      fi
      ;;
  esac
fi

real_ollama="$(find_real_ollama || true)"
if [ -z "$real_ollama" ]; then
  echo "real ollama binary not found yet" >&2
  exit 127
fi

exec "$real_ollama" "$@"
EOF
chmod +x "$OLLAMA_WRAPPER_DIR/ollama"
export PATH="$OLLAMA_WRAPPER_DIR:$PATH"

echo "Onboarding sandbox '$SANDBOX' with Ollama model '$MODEL'"
curl -fsSL https://www.nvidia.com/nemoclaw.sh -o /tmp/nemoclaw.sh
bash /tmp/nemoclaw.sh --non-interactive --yes-i-accept-third-party-software --fresh
