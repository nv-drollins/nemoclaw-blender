#!/usr/bin/env bash
set -euo pipefail

CODE="bpy=__import__('bpy');bpy.ops.mesh.primitive_cube_add(size=1.5,location=(0,0,1));obj=bpy.context.object;obj.name='CodexRedCube';mat=bpy.data.materials.new('CodexRed');mat.diffuse_color=(1,0,0,1);obj.data.materials.append(mat)"

/sandbox/bin/mcporter call blender.execute_blender_code \
  code="$CODE" \
  user_prompt=create-red-cube-smoke-test

/sandbox/bin/mcporter call blender.get_scene_info \
  user_prompt=scene-info-after-smoke-test
