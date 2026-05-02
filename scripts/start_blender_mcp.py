#!/usr/bin/env python3
"""Load the Blender MCP addon and start its socket server.

Run this with Blender:
    blender --python scripts/start_blender_mcp.py
"""

from __future__ import annotations

import importlib.util
import os
import sys
from pathlib import Path

import bpy


def load_addon(path: Path):
    spec = importlib.util.spec_from_file_location("blender_mcp_addon", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load Blender MCP addon from {path}")

    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main() -> None:
    addon_path = Path(
        os.environ.get(
            "BLENDER_MCP_ADDON",
            str(Path.home() / "nemoclaw-blender-demo" / "assets" / "blender_mcp_addon.py"),
        )
    )
    port = int(os.environ.get("BLENDER_MCP_PORT", "9876"))

    if not addon_path.exists():
        raise FileNotFoundError(f"Blender MCP addon not found: {addon_path}")

    addon = load_addon(addon_path)

    if hasattr(addon, "register"):
        try:
            addon.register()
        except Exception as exc:  # Blender raises if classes are already registered.
            if "already registered" not in str(exc).lower():
                raise

    # These properties are added by register(); keep network-using optional
    # integrations off for the base demo.
    scene = bpy.context.scene
    for attr in (
        "blendermcp_use_polyhaven",
        "blendermcp_use_hyper3d",
        "blendermcp_use_sketchfab",
        "blendermcp_use_hunyuan3d",
    ):
        if hasattr(scene, attr):
            setattr(scene, attr, False)

    server = None
    for name in ("server", "mcp_server", "blender_mcp_server"):
        candidate = getattr(addon, name, None)
        if candidate is not None and hasattr(candidate, "start"):
            server = candidate
            break

    if server is None:
        server = addon.BlenderMCPServer(host="localhost", port=port)
        setattr(addon, "server", server)

    if not getattr(server, "running", False):
        server.start()

    print(f"BLENDER_MCP_READY localhost:{port}", flush=True)


if __name__ == "__main__":
    main()
