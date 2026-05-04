# NemoClaw Blender Demo on DGX Spark

This repo installs and verifies a NemoClaw/OpenClaw sandbox that can control a
host-side Blender instance through Blender MCP, `mcp-proxy`, and `mcporter`.

The flow was verified on a DGX Spark with:

- Ubuntu 24.04.4 LTS on `aarch64`
- Docker 29.2.1 with the NVIDIA container runtime
- Node 22.22.2 and npm 10.9.7
- Ollama 0.22.1 on `127.0.0.1:11434`
- `nemotron-3-nano:30b`
- Blender 4.0.2

## Layout

```text
.
├── blender-skill/SKILL.md
├── policies/blender-mcp.yaml
└── scripts/
    ├── onboard-nemoclaw.sh
    ├── install-host-prereqs.sh
    ├── start-demo.sh
    ├── start-host-blender-mcp.sh
    ├── start-mcp-proxy.sh
    ├── apply-blender-policy.sh
    ├── vendor-mcporter-to-sandbox.sh
    ├── install-blender-skill.sh
    ├── run-sandbox-blender-smoke.sh
    ├── run-openclaw-agent-smoke.sh
    └── stop-demo.sh
```

## 1. Stage the Repo on the Spark

Clone or copy this repo to:

```bash
/home/nvidia/nemoclaw-blender-demo
```

Run all commands below on the DGX Spark as `nvidia`.

```bash
cd ~/nemoclaw-blender-demo
chmod +x scripts/*.sh
```

## 2. Confirm the Local Model

```bash
ollama list
```

This guide uses:

```text
nemotron-3-nano:30b
```

If it is missing:

```bash
ollama pull nemotron-3-nano:30b
```

## 3. Install and Onboard NemoClaw

```bash
NEMOCLAW_SANDBOX_NAME=blender-agent \
NEMOCLAW_MODEL=nemotron-3-nano:30b \
./scripts/onboard-nemoclaw.sh
```

Verify:

```bash
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
nemoclaw blender-agent status
nemoclaw blender-agent doctor --json
```

Expected: sandbox `Ready`, provider `ollama-local`, inference healthy.

## 4. Install Host-Side Blender and uv

```bash
./scripts/install-host-prereqs.sh
```

The script installs Ubuntu Blender, installs `uv/uvx`, and downloads
`ahujasid/blender-mcp`'s `addon.py` into `assets/blender_mcp_addon.py`.

## 5. Start Blender MCP on the Host

The Spark used for verification had an active X11 desktop at `DISPLAY=:1` and
`XAUTHORITY=/run/user/1000/gdm/Xauthority`.

```bash
DISPLAY=:1 \
XAUTHORITY=/run/user/1000/gdm/Xauthority \
./scripts/start-host-blender-mcp.sh
```

Verify the socket:

```bash
ss -ltn | grep 9876
tail -40 logs/blender.log
```

Expected log lines include:

```text
BlenderMCP server started on localhost:9876
BLENDER_MCP_READY localhost:9876
```

## 6. Start the MCP HTTP/SSE Proxy

```bash
./scripts/start-mcp-proxy.sh
```

Verify:

```bash
ss -ltn | grep 9877
tail -80 logs/mcp-proxy.log
```

Expected: `mcp-proxy` serving `http://0.0.0.0:9877/sse` and connected to
Blender at `localhost:9876`.

## 7. Allow Sandbox Egress to Blender MCP

The script auto-detects the host IPv4 address and injects it into the policy
before applying it. Override detection when needed with
`NEMOCLAW_BLENDER_HOST_IP`.

```bash
./scripts/apply-blender-policy.sh blender-agent
```

Override example:

```bash
NEMOCLAW_BLENDER_HOST_IP=<host-ip> ./scripts/apply-blender-policy.sh blender-agent
```

Verify the live OpenShell policy contains `blender_mcp`:

```bash
openshell policy get blender-agent --full | grep -n blender -C 3
```

## 8. Install mcporter in the Sandbox

The `mcporter-0.9.0.tgz` release package does not include all runtime
dependencies. The reliable path is to install its dependencies on the Spark
host, then copy the resulting `node_modules` into `/sandbox`.

```bash
./scripts/vendor-mcporter-to-sandbox.sh blender-agent
```

This also auto-detects the host IP and writes the sandbox mcporter config to
use `http://<host-ip>:9877/sse`. You can override with:

```bash
NEMOCLAW_BLENDER_HOST_IP=<host-ip> ./scripts/vendor-mcporter-to-sandbox.sh blender-agent
```

Verify from the sandbox:

```bash
openshell sandbox ssh-config blender-agent > /tmp/blender-agent.ssh_config
ssh -F /tmp/blender-agent.ssh_config openshell-blender-agent \
  /sandbox/bin/mcporter call blender.get_scene_info user_prompt=scene-check
```

Expected: JSON describing the Blender scene.

## 9. Install the Blender Skill

```bash
./scripts/install-blender-skill.sh blender-agent
```

This copies `blender-skill/SKILL.md` into
`/sandbox/.openclaw/skills/blender/SKILL.md` and restarts the OpenClaw gateway
with `/sandbox/bin` on `PATH`.

## 10. Smoke Tests

Direct sandbox-to-Blender MCP test:

```bash
openshell sandbox ssh-config blender-agent > /tmp/blender-agent.ssh_config
scp -F /tmp/blender-agent.ssh_config scripts/run-sandbox-blender-smoke.sh \
  openshell-blender-agent:/tmp/
ssh -F /tmp/blender-agent.ssh_config openshell-blender-agent \
  bash /tmp/run-sandbox-blender-smoke.sh
```

Expected: Blender creates `CodexRedCube`, and scene info reports it.

OpenClaw agent test:

```bash
scp -F /tmp/blender-agent.ssh_config scripts/run-openclaw-agent-smoke.sh \
  openshell-blender-agent:/tmp/
ssh -F /tmp/blender-agent.ssh_config openshell-blender-agent \
  bash /tmp/run-openclaw-agent-smoke.sh
```

Expected output:

```text
Cube
Light
Camera
CodexRedCube
```

OpenClaw red-cube test:

```bash
scp -F /tmp/blender-agent.ssh_config scripts/run-openclaw-red-cube-smoke.sh \
  openshell-blender-agent:/tmp/
ssh -F /tmp/blender-agent.ssh_config openshell-blender-agent \
  bash /tmp/run-openclaw-red-cube-smoke.sh
```

Expected: OpenClaw creates `OpenClawRedCube`, and the verification call reports
the object with material `OpenClawRedMaterial`.

## Useful Operations

Start the demo after it has already been installed:

```bash
./scripts/start-demo.sh
```

`start-demo.sh` auto-detects the host IP and refreshes both the sandbox policy
and mcporter config. For unusual network setups:

```bash
NEMOCLAW_BLENDER_HOST_IP=<host-ip> ./scripts/start-demo.sh
```

Start and run an OpenClaw agent smoke check:

```bash
./scripts/start-demo.sh --smoke
```

Run the red-cube OpenClaw test:

```bash
openshell sandbox ssh-config blender-agent > /tmp/blender-agent.ssh_config
scp -F /tmp/blender-agent.ssh_config scripts/run-openclaw-red-cube-smoke.sh \
  openshell-blender-agent:/tmp/
ssh -F /tmp/blender-agent.ssh_config openshell-blender-agent \
  bash /tmp/run-openclaw-red-cube-smoke.sh
```

Check services:

```bash
nemoclaw blender-agent status
tail -80 ~/nemoclaw-blender-demo/logs/blender.log
tail -80 ~/nemoclaw-blender-demo/logs/mcp-proxy.log
```

Stop host-side demo services:

```bash
./scripts/stop-demo.sh
```

Stop Blender/MCP services and the in-sandbox OpenClaw gateway:

```bash
./scripts/stop-demo.sh --stop-gateway
```

Permanently remove the NemoClaw sandbox and its persistent volume:

```bash
./scripts/stop-demo.sh --destroy-sandbox
```

Connect to the sandbox:

```bash
nemoclaw blender-agent connect
```

Open the OpenClaw UI:

```bash
nemoclaw blender-agent gateway-token --quiet
```

Use the token with the dashboard URL from `nemoclaw blender-agent status` or
the installer output.

## Troubleshooting

- If `openshell sandbox exec` hangs, use the SSH config path:
  `openshell sandbox ssh-config blender-agent > /tmp/blender-agent.ssh_config`.
- If `mcporter` cannot reach Blender, check host ports `9876` and `9877`.
- If OpenShell logs show policy denials for `<host-ip>:9877`, rerun
  `scripts/apply-blender-policy.sh blender-agent`.
- If the OpenClaw agent does not use the skill, rerun
  `scripts/install-blender-skill.sh blender-agent`.
- If the OpenClaw UI reports a timeout or says it lacks permission to run
  `mcporter`, run `scripts/install-blender-skill.sh blender-agent` again. The
  script force-restarts the in-sandbox gateway, enables `localModelLean`, and
  reloads the Blender skill.
