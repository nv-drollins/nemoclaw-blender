#!/usr/bin/env bash
set -euo pipefail

SPARK_IP="${1:-192.168.1.164}"

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
      "baseUrl": "http://$SPARK_IP:9877/sse"
    }
  }
}
EOF

echo "mcporter wrapper repaired at /sandbox/bin/mcporter"
