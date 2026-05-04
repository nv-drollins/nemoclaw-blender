#!/usr/bin/env bash

detect_host_ip() {
  local probe="${NEMOCLAW_BLENDER_IP_PROBE:-1.1.1.1}"
  local ip_addr=""

  if command -v ip >/dev/null 2>&1; then
    ip_addr="$(
      ip -4 route get "$probe" 2>/dev/null |
        awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }'
    )"
  fi

  if [ -z "$ip_addr" ] && command -v hostname >/dev/null 2>&1; then
    ip_addr="$(
      hostname -I 2>/dev/null |
        tr ' ' '\n' |
        awk 'NF && $1 !~ /^127\./ { print; exit }'
    )"
  fi

  if [ -n "$ip_addr" ]; then
    printf '%s\n' "$ip_addr"
  fi
}

resolve_host_ip() {
  local override="${1:-${NEMOCLAW_BLENDER_HOST_IP:-${SPARK_IP:-}}}"
  local ip_addr=""

  if [ -n "$override" ]; then
    printf '%s\n' "$override"
    return 0
  fi

  ip_addr="$(detect_host_ip || true)"
  if [ -z "$ip_addr" ]; then
    echo "Could not auto-detect host IP. Set NEMOCLAW_BLENDER_HOST_IP or pass --host-ip." >&2
    return 1
  fi

  printf '%s\n' "$ip_addr"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  resolve_host_ip "${1:-}"
fi
