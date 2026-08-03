"""Render transparent, eight-direction animation frames for the web game.

Run after build_brutus.py by opening brutus_source.blend in Blender:
  blender brutus_source.blend --background --python render_brutus_web_frames.py
"""

from pathlib import Path
import math
import os
import sys

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[3]
FRAME_ROOT = ROOT / "assets" / "heroes" / ".brutus_3d_frames"
CELL_WIDTH = 288
CELL_HEIGHT = 192

CLIPS = {
    "idle": ("idle", [1, 9, 17, 25, 33, 41]),
    "walk": ("walk", [1, 5, 9, 13, 17, 21, 25, 29]),
    "run": ("run", [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23]),
    "attack": ("attack", [1, 3, 5, 7, 9, 10, 11, 14, 18, 22]),
    "attack_alt": ("attack_alt", [1, 4, 7, 9, 10, 11, 13, 15, 19, 23]),
    "q": ("q", [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 32, 36]),
    "r": ("ultimate", [1, 5, 9, 13, 16, 18, 21, 25, 30, 36, 42, 48]),
    # The first half is rendered without the shield; frame 45 is the authored
    # hand contact and the last frames visibly settle the caught disc.
    "catch": ("ultimate", [34, 39, 42, 45, 46, 48]),
    "hurt": ("hurt", [1, 3, 4, 6, 8, 11, 14, 16]),
    "death": ("death", [1, 5, 9, 13, 17, 21, 25, 29, 33, 36, 39, 42]),
    "idle_no_shield": ("idle", [1, 9, 17, 25, 33, 41]),
    "walk_no_shield": ("walk", [1, 5, 9, 13, 17, 21, 25, 29]),
    "run_no_shield": ("run", [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23]),
    "attack_no_shield": ("attack", [1, 3, 5, 7, 9, 10, 11, 14, 18, 22]),
    "attack_alt_no_shield": ("attack_alt", [1, 4, 7, 9, 10, 11, 13, 15, 19, 23]),
    "q_no_shield": ("q", [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 32, 36]),
    "r_no_shield": ("ultimate", [1, 5, 9, 13, 16, 18, 21, 25, 30, 36, 42, 48]),
    "hurt_no_shield": ("hurt", [1, 3, 4, 6, 8, 11, 14, 16]),
    "death_no_shield": ("death", [1, 5, 9, 13, 17, 21, 25, 29, 33, 36, 39, 42]),
}

# JS direction order: E, SE, S, SW, W, NW, N, NE. Brutus faces Blender -Y
# at zero rotation, which is the screen-down/front view from this camera.
DIRECTION_ROTATIONS = [90, 45, 0, -45, -90, -135, -180, 135]


def command_arg(name):
    """Read a renderer argument placed after Blender's `--` separator."""
    if "--" not in sys.argv:
        return None
    args = sys.argv[sys.argv.index("--") + 1:]
    if name not in args:
        return None
    index = args.index(name)
    if index + 1 >= len(args):
        raise ValueError(f"Missing value for {name}")
    return args[index + 1]


def point_camera(camera, target):
    direction = Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def configure_scene():
    scene = bpy.context.scene
    # Workbench entrega leitura de forma muito superior quando o resultado será
    # reduzido para dezenas de pixels: cor plana, cavidades claras e zero ruído.
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.fps = 30
    scene.render.resolution_x = CELL_WIDTH
    scene.render.resolution_y = CELL_HEIGHT
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.look = "AgX - Medium High Contrast"
    shading = scene.display.shading
    shading.light = "FLAT"
    shading.color_type = "MATERIAL"
    shading.show_shadows = False
    shading.show_cavity = True
    shading.cavity_type = "WORLD"
    shading.cavity_ridge_factor = 1.65
    shading.cavity_valley_factor = 1.35
    shading.show_specular_highlight = False
    shading.show_object_outline = False
    # O contorno final é aplicado sobre o alpha no empacotamento. É mais limpo
    # em tamanho mobile e evita linhas internas ruidosas do Freestyle.
    scene.render.use_freestyle = False

    for obj in bpy.data.objects:
        if obj.name.startswith("PREVIEW_ONLY_Ground"):
            obj.hide_render = True

    camera = bpy.data.objects.get("WEB_SPRITE_Camera")
    if camera is None:
        bpy.ops.object.camera_add(location=(0.0, -9.5, 14.0))
        camera = bpy.context.object
        camera.name = "WEB_SPRITE_Camera"
    camera.data.type = "ORTHO"
    # Extra margin is required by side-on shield poses and the horizontal death
    # silhouette. Never crop a frame; the web renderer can scale the full cell.
    # Blender's orthographic scale follows the horizontal dimension for this
    # 3:2 render. The 9.90 view preserves every action silhouette, including
    # the fully extended shield and the horizontal death pose.
    camera.data.ortho_scale = 9.90
    camera.location = (0.0, -9.5, 14.0)
    point_camera(camera, (0.0, 0.0, 1.48))
    scene.camera = camera
    return scene


def main():
    FRAME_ROOT.mkdir(parents=True, exist_ok=True)
    scene = configure_scene()
    rig = bpy.data.objects["BrutusRig"]
    shield_mesh = bpy.data.objects.get("BrutusShieldMesh")
    if shield_mesh is None:
        raise RuntimeError("Missing detachable BrutusShieldMesh; rebuild brutus_source.blend first")
    rig.animation_data_create()

    rendered = 0
    clip_items = list(CLIPS.items())
    direction_rotations = list(enumerate(DIRECTION_ROTATIONS))
    direction_only = command_arg("--direction-only") or os.environ.get("BRUTUS_RENDER_DIRECTION_ONLY")
    if direction_only is not None:
        direction_index = int(direction_only)
        direction_rotations = [(direction_index, DIRECTION_ROTATIONS[direction_index])]
    if os.environ.get("BRUTUS_RENDER_DIAGNOSTIC") == "1":
        diagnostic_direction = int(os.environ.get("BRUTUS_RENDER_DIRECTION", "0"))
        diagnostic_clip = os.environ.get("BRUTUS_RENDER_CLIP", "idle")
        if diagnostic_clip not in CLIPS:
            raise ValueError(f"Unknown diagnostic clip {diagnostic_clip!r}")
        clip_items = [(diagnostic_clip, CLIPS[diagnostic_clip])]
        diagnostic_frame = os.environ.get("BRUTUS_RENDER_FRAME_INDEX")
        if diagnostic_frame is not None:
            action_name, frames = clip_items[0][1]
            index = int(diagnostic_frame)
            clip_items = [(diagnostic_clip, (action_name, [frames[index]]))]
        direction_rotations = [(diagnostic_direction, DIRECTION_ROTATIONS[diagnostic_direction])]
    for clip_name, (action_name, frames) in clip_items:
        action = bpy.data.actions.get(action_name)
        if action is None:
            raise RuntimeError(f"Missing action {action_name!r}; rebuild brutus_source.blend first")
        rig.animation_data.action = action
        for direction_index, degrees in direction_rotations:
            rig.rotation_euler = (0.0, 0.0, math.radians(degrees))
            output_dir = FRAME_ROOT / clip_name / f"d{direction_index}"
            output_dir.mkdir(parents=True, exist_ok=True)
            for frame_index, source_frame in enumerate(frames):
                # O escudo deixa a mão exatamente no quadro de soltura da ultimate.
                # As variantes sem escudo cobrem todas as ações possíveis enquanto
                # o bumerangue ainda está viajando ou retornando.
                shield_mesh.hide_render = (
                    clip_name.endswith("_no_shield") or
                    (clip_name == "catch" and frame_index < 3)
                )
                scene.frame_set(source_frame)
                scene.render.filepath = str(output_dir / f"f{frame_index:02d}.png")
                bpy.ops.render.render(write_still=True)
                rendered += 1

    shield_mesh.hide_render = False

    print(f"BRUTUS_WEB_FRAMES_OK count={rendered} root={FRAME_ROOT}")


if __name__ == "__main__":
    main()
