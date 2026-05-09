# NemoClaw Blender Demo on GB10

This repo installs and runs a NemoClaw/OpenClaw sandbox that controls a
host-side Blender session through Blender MCP, `mcp-proxy`, and `mcporter`.

The flow was verified on a DGX Spark GB10 with:

- Ubuntu 24.04.4 LTS on `aarch64`
- Docker 29.2.1 with the NVIDIA container runtime
- Node 22.22.2 and npm 10.9.7
- Ollama 0.22.1 on `127.0.0.1:11434`
- `nemotron-3-nano:30b`
- Blender 4.0.2

The scripts also support a local x86 Ubuntu host with Docker, the NVIDIA
container runtime, Ollama, and a desktop display.

## Before You Begin

Use a local Ubuntu machine with:

- an NVIDIA GPU and working NVIDIA driver
- Docker and the NVIDIA container runtime
- Ollama running on `127.0.0.1:11434`
- a local desktop display for Blender
- passwordless `sudo` for package installation

### Install and expose Ollama

The NemoClaw sandbox must be able to reach the host Ollama server. Install
Ollama on the host, then configure the systemd service to listen on all
interfaces:

```bash
curl -fsSL https://ollama.com/install.sh | sh

sudo mkdir -p /etc/systemd/system/ollama.service.d
printf '[Service]\nEnvironment="OLLAMA_HOST=0.0.0.0"\n' | sudo tee /etc/systemd/system/ollama.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

Verify Ollama is running:

```bash
curl http://0.0.0.0:11434
```

Expected response:

```text
Ollama is running
```

If it is not running, start it with:

```bash
sudo systemctl start ollama
```

Always start Ollama through systemd with `sudo systemctl restart ollama` or
`sudo systemctl start ollama`. Do not use `ollama serve &` for this demo. A
manually started Ollama process will not use the `OLLAMA_HOST=0.0.0.0`
systemd override, and the NemoClaw sandbox will not be able to reach the
inference server.

`OLLAMA_HOST=0.0.0.0` exposes Ollama on the host network. Use this on a trusted
local network, or apply host firewall rules appropriate for your environment.

Do not run the NemoClaw onboarding step from an active Python virtual
environment. The onboarding script strips active venv settings before invoking
the NemoClaw installer and skips the upstream installer's optional model-router
`pip3 install --user` step for this Ollama-based demo. That avoids Ubuntu
24.04's PEP 668 `externally-managed-environment` warning for an unused router
component.

Quick checks:

```bash
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu24.04 nvidia-smi
ollama list
```

On GPU hosts that use Docker CDI device injection, `onboard-nemoclaw.sh`
generates `/etc/cdi/nvidia.yaml` automatically if the NVIDIA CDI specs are
missing.

## Quick Path

If the checks in Before You Begin pass, the commands below install, configure,
start, and smoke-test the demo. Run everything from the target machine that
will display Blender.

```bash
git clone https://github.com/nv-drollins/nemoclaw-blender.git
cd nemoclaw-blender
ollama pull nemotron-3-nano:30b
./scripts/install-host-prereqs.sh
NEMOCLAW_MODEL=nemotron-3-nano:30b ./scripts/onboard-nemoclaw.sh
./scripts/start-demo.sh
./scripts/show-openclaw-dashboard.sh --show-token
```

When Blender opens, press `N` if the right sidebar is hidden, open the
`BlenderMCP` tab, and click `Connect to Claude` if it is not already connected.

Open the OpenClaw dashboard URL printed by `show-openclaw-dashboard.sh`, sign in
with the gateway token if prompted, and send this as a new prompt:

```text
Using mcporter to connect to blender, create a red cube in the center of the blender scene.
```

Blender's default workspace already has a gray cube at the center of the scene.
Delete that cube first if you want the red cube to be immediately visible; if
both cubes occupy the same spot, the gray cube can hide the newly-created red
one.

Use `./scripts/stop-demo.sh` when you are done. For more detail or finer
control, follow the numbered sections below.

## 1. Clone the Repo

```bash
git clone https://github.com/nv-drollins/nemoclaw-blender.git
cd nemoclaw-blender
```

The shell scripts are committed with executable permissions, so a normal
`git clone` lets you run them directly. If you downloaded a ZIP or copied the
files manually, repair the permissions:

```bash
chmod +x scripts/*.sh
```

Run the rest of this guide from the repo root.

## 2. Confirm the Local Model

This demo uses `nemotron-3-nano:30b` through Ollama.

```bash
ollama list
```

If the model is missing:

```bash
ollama pull nemotron-3-nano:30b
```

## 3. Install Host Prerequisites

```bash
./scripts/install-host-prereqs.sh
```

This installs Ubuntu Blender, installs `uv/uvx`, and downloads the Blender MCP
add-on to `assets/blender_mcp_addon.py`.

You do not need to install the add-on manually inside Blender. The startup
script launches Blender with `scripts/start_blender_mcp.py`, which loads and
registers the downloaded add-on for that Blender session.

## 4. Install and Onboard NemoClaw

```bash
NEMOCLAW_SANDBOX_NAME=blender-agent \
NEMOCLAW_MODEL=nemotron-3-nano:30b \
./scripts/onboard-nemoclaw.sh
```

The onboarding script forces the selected `NEMOCLAW_MODEL` during NemoClaw's
initial Ollama model pre-pull. This prevents large-memory x86 hosts from
auto-selecting `nemotron-3-super:120b` when this demo is configured for
`nemotron-3-nano:30b`.

### NemoClaw onboarding variables

`scripts/onboard-nemoclaw.sh` is an Ollama-focused wrapper. It always calls the
official NemoClaw installer with `--non-interactive`,
`--yes-i-accept-third-party-software`, and `--fresh`.

| Variable | Default | Available options / examples | Purpose |
|---|---:|---|---|
| `NEMOCLAW_MODEL` | `nemotron-3-nano:30b` | Any Ollama model name from `ollama list`; examples: `nemotron-3-nano:30b`, `qwen3.6:35b` | Selects the local Ollama model NemoClaw/OpenClaw should use. |
| `NEMOCLAW_SANDBOX_NAME` | `blender-agent` | Any valid sandbox name, for example `my-blender-agent` | Names the NemoClaw sandbox. Use a unique name to avoid replacing another sandbox. |
| `NEMOCLAW_POLICY_TIER` | `balanced` | `restricted`, `balanced`, `open` | Selects NemoClaw's baseline policy tier during onboarding. |
| `NEMOCLAW_LOCAL_INFERENCE_TIMEOUT` | `300` | Seconds, for example `600` | Wait time for local inference validation and model warm-up. |
| `NEMOCLAW_SANDBOX_READY_TIMEOUT` | NemoClaw default | Seconds, for example `600` | Optional override for slow first-time sandbox startup. |
| `NEMOCLAW_OLLAMA_BIN` | auto-detected | Full path to `ollama` | Overrides which real Ollama binary the wrapper calls. |
| `NEMOCLAW_PIP3_BIN` | auto-detected | Full path to `pip3` | Overrides which real `pip3` binary the router-bypass shim delegates to. |

| Setting | Source | Available options | Notes |
|---|---|---|---|
| `--fresh` | Official NemoClaw installer | Always passed by this demo wrapper | Creates a fresh demo-oriented NemoClaw/OpenShell setup. |
| `--no-fresh` | Not supported by this demo wrapper | N/A | The vanilla repo has this convenience option if you need to preserve an existing setup. |
| `NEMOCLAW_PROVIDER` | Demo wrapper | `ollama` only | This Blender demo is wired for local Ollama inference. |

| Script-set variable | Value | Notes |
|---|---:|---|
| `NEMOCLAW_ACCEPT_THIRD_PARTY_SOFTWARE` | `1` | Accepts the official installer's third-party software prompt for non-interactive setup. |
| `NEMOCLAW_NON_INTERACTIVE` | `1` | Keeps the installer in scripted mode. |

Verify the sandbox:

```bash
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
nemoclaw blender-agent status
nemoclaw blender-agent doctor --json
```

Expected: sandbox `Ready`, provider `ollama-local`, inference healthy.

## 5. Start and Configure the Demo

```bash
./scripts/start-demo.sh
```

This one command starts and configures the working demo:

- starts Blender MCP on `localhost:9876`
- starts `mcp-proxy` on `0.0.0.0:9877`
- applies the sandbox policy that allows access to Blender MCP
- installs or repairs `mcporter` inside the sandbox
- installs the Blender skill and restarts the OpenClaw gateway
- verifies that the sandbox can read the Blender scene

When Blender opens, confirm the Blender MCP panel is connected:

1. In the Blender 3D Viewport, press `N` if the right sidebar is hidden.
2. Open the `BlenderMCP` tab.
3. Click `Connect to Claude` if it is not already connected.

To start and run a basic smoke check:

```bash
./scripts/start-demo.sh --smoke
```

The scripts are designed for a local desktop host with a display. The normal
Blender MCP command is:

```bash
./scripts/start-host-blender-mcp.sh
```

Blender MCP listens on `localhost:9876`. Check it from the repo root:

```bash
ss -ltn | grep 9876
tail -40 ./logs/blender.log
```

`mcp-proxy` listens on `9877`:

```bash
ss -ltn | grep 9877
tail -80 ./logs/mcp-proxy.log
```

If a service does not become ready, the startup script prints the absolute log
path and tails the log automatically.

## 6. Run the Demo

Print the OpenClaw dashboard URL from inside the sandbox:

```bash
./scripts/show-openclaw-dashboard.sh
```

The helper runs `openclaw dashboard --no-open` inside the sandbox using
OpenShell SSH. It also prints the token command. To print the token in the same
terminal:

```bash
./scripts/show-openclaw-dashboard.sh --show-token
```

Open the dashboard URL, use the gateway token to sign in if prompted, then try
this prompt:

```text
Using mcporter to connect to blender, create a red cube in the center of the blender scene.
```

Blender's default workspace already has a gray cube at the center of the scene.
Delete that cube first if you want the red cube to be immediately visible; if
both cubes occupy the same spot, the gray cube can hide the newly-created red
one.

You can also run the included red-cube smoke test:

```bash
openshell sandbox ssh-config blender-agent > /tmp/blender-agent.ssh_config
scp -F /tmp/blender-agent.ssh_config scripts/run-openclaw-red-cube-smoke.sh \
  openshell-blender-agent:/tmp/
ssh -F /tmp/blender-agent.ssh_config openshell-blender-agent \
  bash /tmp/run-openclaw-red-cube-smoke.sh
```

Expected: OpenClaw creates `OpenClawRedCube`, and the verification call reports
the object with material `OpenClawRedMaterial`.

## 7. Check Services

```bash
nemoclaw blender-agent status
ss -ltn | grep 9876
ss -ltn | grep 9877
tail -80 ./logs/blender.log
tail -80 ./logs/mcp-proxy.log
```

Direct sandbox-to-Blender check:

```bash
openshell sandbox ssh-config blender-agent > /tmp/blender-agent.ssh_config
ssh -F /tmp/blender-agent.ssh_config openshell-blender-agent \
  /sandbox/bin/mcporter call blender.get_scene_info user_prompt=scene-check
```

Expected: JSON describing the Blender scene.

## 8. Stop the Demo

Stop host-side Blender and MCP services:

```bash
./scripts/stop-demo.sh
```

Stop host-side services and the in-sandbox OpenClaw gateway:

```bash
./scripts/stop-demo.sh --stop-gateway
```

Permanently remove the NemoClaw sandbox and its persistent volume:

```bash
./scripts/stop-demo.sh --destroy-sandbox
```

## 9. Restart the Demo

After a normal stop:

```bash
./scripts/start-demo.sh
```

After stopping the in-sandbox gateway too:

```bash
./scripts/start-demo.sh
```

After destroying the sandbox, recreate it first:

```bash
NEMOCLAW_MODEL=nemotron-3-nano:30b ./scripts/onboard-nemoclaw.sh
./scripts/start-demo.sh
```

## Useful Overrides

Use a different sandbox name:

```bash
NEMOCLAW_SANDBOX_NAME=my-blender-agent ./scripts/onboard-nemoclaw.sh
NEMOCLAW_SANDBOX_NAME=my-blender-agent ./scripts/start-demo.sh
```

Override host IP auto-detection for unusual network setups:

```bash
NEMOCLAW_BLENDER_HOST_IP=<host-ip> ./scripts/start-demo.sh
```

Connect to the sandbox:

```bash
nemoclaw blender-agent connect
```

Run a one-off command inside the sandbox from the host:

```bash
openshell sandbox ssh-config blender-agent > /tmp/blender-agent.ssh_config
ssh -F /tmp/blender-agent.ssh_config openshell-blender-agent \
  openclaw dashboard --no-open
```

## Troubleshooting

- If `ss -ltn | grep 9876` has no output, Blender MCP is not listening. Check
  `./logs/blender.log`, then in Blender open the `BlenderMCP` sidebar tab and
  click `Connect to Claude`.
- If `ss -ltn | grep 9877` has no output, `mcp-proxy` is not listening. Check
  `./logs/mcp-proxy.log`.
- If `mcporter` cannot reach Blender, check host ports `9876` and `9877`, then
  rerun `./scripts/start-demo.sh`.
- If OpenShell logs show policy denials for `<host-ip>:9877`, rerun
  `./scripts/start-demo.sh` or `./scripts/apply-blender-policy.sh blender-agent`.
- If the OpenClaw UI reports a timeout or says it lacks permission to run
  `mcporter`, rerun `./scripts/start-demo.sh`. It refreshes `mcporter`, installs
  the Blender skill, and restarts the in-sandbox gateway.
- If a script looks for `/home/nvidia/nemoclaw-blender-demo` while your checkout
  is somewhere else, pull the latest repo and clear any stale override:
  `unset NEMOCLAW_BLENDER_DEMO_ROOT`.
- If onboarding fails with `unresolvable CDI devices nvidia.com/gpu=all`, run:
  `sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml`, then verify with
  `nvidia-ctk cdi list`.
- If onboarding prints `externally-managed-environment` or `Can not perform a
  '--user' install` from `pip`, pull the latest repo and rerun
  `NEMOCLAW_MODEL=nemotron-3-nano:30b ./scripts/onboard-nemoclaw.sh`. Older
  runs may print this while skipping NemoClaw's optional model router, but the
  Ollama-based Blender demo does not require that component.
- If `openshell sandbox exec` hangs, use the SSH config path:
  `openshell sandbox ssh-config blender-agent > /tmp/blender-agent.ssh_config`.
