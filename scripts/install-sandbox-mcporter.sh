#!/usr/bin/env bash
set -euo pipefail

SPARK_IP="${1:-192.168.1.164}"
TGZ="${2:-/tmp/mcporter-0.9.0.tgz}"

if [ ! -f "$TGZ" ]; then
  echo "mcporter package not found: $TGZ" >&2
  exit 1
fi

mkdir -p /sandbox/node_modules /sandbox/bin "$HOME/.mcporter"

cd /sandbox
npm install --omit=dev "$TGZ"

CLI="/sandbox/node_modules/mcporter/dist/cli.js"
if [ -z "$CLI" ] || [ ! -f "$CLI" ]; then
  echo "Could not find mcporter dist/cli.js after extraction" >&2
  find /sandbox/node_modules -maxdepth 4 -type f | sort >&2
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

echo "mcporter installed at /sandbox/bin/mcporter"
echo "mcporter config written to $HOME/.mcporter/mcporter.json"
