"""Render Brutus' authored 3D shield as a transparent web projectile sprite.

Run with the editable source open:
  blender brutus_source.blend --background --python render_brutus_shield_projectile.py
"""

from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[3]
OUTPUT = ROOT / "assets" / "heroes" / "brutus_shield_projectile.png"


def point_camera(camera, target):
    direction = Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def main():
    shield = bpy.data.objects.get("BrutusShieldMesh")
    rig = bpy.data.objects.get("BrutusRig")
    if shield is None or rig is None:
        raise RuntimeError("BrutusShieldMesh and BrutusRig are required; rebuild the source first")

    idle = bpy.data.actions.get("idle")
    rig.animation_data_create()
    rig.animation_data.action = idle
    bpy.context.scene.frame_set(1)

    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.hide_render = obj != shield
        elif obj.type in {"LIGHT", "CAMERA"}:
            obj.hide_render = True
    shield.hide_render = False

    # Resolve the evaluated, armature-deformed bounds instead of relying on the
    # rest-pose bone coordinates. This keeps the disc centered if the rig or
    # idle pose is refined later.
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = shield.evaluated_get(depsgraph)
    corners = [evaluated.matrix_world @ Vector(corner) for corner in evaluated.bound_box]
    target = sum(corners, Vector()) / len(corners)
    extent = max(max(point[axis] for point in corners) - min(point[axis] for point in corners)
                 for axis in range(3))
    # The deformed shield lies mostly in the world XY plane. A high three-quarter
    # view keeps its circular heraldry readable while retaining rim thickness.
    bpy.ops.object.camera_add(location=target + Vector((1.4, -2.0, 6.0)))
    camera = bpy.context.object
    camera.name = "PROJECTILE_ONLY_Camera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = max(2.0, extent * 1.38)
    point_camera(camera, target)
    camera.hide_render = False

    scene = bpy.context.scene
    scene.camera = camera
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 192
    scene.render.resolution_y = 192
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.film_transparent = True
    scene.render.filepath = str(OUTPUT)
    scene.view_settings.look = "AgX - Medium High Contrast"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_shadows = False
    shading.show_cavity = True
    shading.cavity_type = "WORLD"
    shading.curvature_ridge_factor = 1.4
    shading.curvature_valley_factor = 1.0

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print(f"BRUTUS_SHIELD_PROJECTILE_OK output={OUTPUT} center={tuple(round(v, 3) for v in target)}")


if __name__ == "__main__":
    main()
