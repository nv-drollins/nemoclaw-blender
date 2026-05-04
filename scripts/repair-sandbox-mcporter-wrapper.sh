#!/usr/bin/env bash
set -euo pipefail

HOST_IP="${1:-${NEMOCLAW_BLENDER_HOST_IP:-${SPARK_IP:-}}}"

if [ -z "$HOST_IP" ]; then
  echo "Host IP required. Pass it as arg 1 or set NEMOCLAW_BLENDER_HOST_IP." >&2
  exit 1
fi

mkdir -p /sandbox/bin "$HOME/.mcporter"

CLI="/sandbox/node_modules/mcporter/dist/cli.js"
if [ ! -f "$CLI" ]; then
  echo "mcporter CLI not found at $CLI" >&2
  exit 1
fi

cat >/sandbox/bin/mcporter <<EOF
#!/usr/bin/env bash
exec node "$CLI" "\$@"
EOF
chmod +x /sandbox/bin/mcporter

cat >"$HOME/.mcporter/mcporter.json" <<EOF
{
  "mcpServers": {
    "blender": {
      "type": "http",
      "baseUrl": "http://$HOST_IP:9877/sse"
    }
  }
}
EOF

echo "mcporter wrapper repaired at /sandbox/bin/mcporter"
