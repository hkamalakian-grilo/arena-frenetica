"""Build the modular 3D map kit for Arena Frenética.

Run with Blender 5.2+:
    blender --background --factory-startup --python tools/build_map_kit.py

Every piece is authored from primitives in the same chunky low-poly language
as the roster: soft bevels, flat saturated colours, no textures. One GLB holds
all pieces as separately named meshes; the game instances them on a grid
(scripts/block_map.gd). Tiles are 1 x 1 units with the origin at the cell
centre on ground level (y = 0 in Godot, z = 0 here).
"""

from pathlib import Path
import math
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bpy
from mathutils import Vector

from build_dragon_family import reset_scene, material, ico, uv_sphere, cone, cylinder, box

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "kit"
ASSET_DIR.mkdir(parents=True, exist_ok=True)
BLEND_PATH = ASSET_DIR / "map_kit_source.blend"
GLB_PATH = ASSET_DIR / "map_kit.glb"
PREVIEW_PATH = ASSET_DIR / "map_kit_preview.png"


def mats():
    return {
        "grass": material("Kit Grass", (0.20, 0.48, 0.14), roughness=0.92),
        "grass_dark": material("Kit Grass Dark", (0.13, 0.34, 0.10), roughness=0.92),
        "road": material("Kit Road", (0.62, 0.46, 0.24), roughness=0.90),
        "road_edge": material("Kit Road Edge", (0.50, 0.36, 0.18), roughness=0.90),
        "water": material("Kit Water", (0.10, 0.38, 0.66), roughness=0.35),
        "water_deep": material("Kit Water Deep", (0.06, 0.26, 0.50), roughness=0.35),
        "stone": material("Kit Stone", (0.40, 0.42, 0.46), roughness=0.85),
        "stone_dark": material("Kit Stone Dark", (0.24, 0.26, 0.30), roughness=0.85),
        "wood": material("Kit Wood", (0.42, 0.25, 0.11), roughness=0.80),
        "wood_dark": material("Kit Wood Dark", (0.28, 0.16, 0.07), roughness=0.80),
        "leaf": material("Kit Leaf", (0.13, 0.42, 0.15), roughness=0.85),
        "leaf_light": material("Kit Leaf Light", (0.22, 0.54, 0.20), roughness=0.85),
        "pine": material("Kit Pine", (0.08, 0.32, 0.16), roughness=0.85),
        "trunk": material("Kit Trunk", (0.40, 0.24, 0.12), roughness=0.85),
        "flower": material("Kit Flower", (0.72, 0.40, 0.92), roughness=0.6),
        "lava": material("Kit Lava", (0.62, 0.20, 0.95), roughness=0.3, emission=1.6),
    }


def join(objects, name):
    # Apply each part's bevel before joining so every piece keeps soft edges.
    for obj in objects:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = bpy.context.object
    result.name = name
    result.data.name = name
    for polygon in result.data.polygons:
        polygon.use_smooth = False
    return result


def tile(name, m, top_color, side_color, top_z=0.0, thickness=0.30, inset=None):
    # Slight overlap (0.505) hides seams between neighbouring tiles; the cap
    # is the full tile so the grid reads only as a faint bevel line.
    body = box(f"{name}Body", (0, 0, top_z - thickness * 0.5), (0.505, 0.505, thickness * 0.5), side_color, bevel=0.012)
    parts = [body]
    cap = box(f"{name}Cap", (0, 0, top_z - 0.012), (0.505, 0.505, 0.016), top_color, bevel=0.006)
    parts.append(cap)
    if inset is not None:
        parts.append(box(f"{name}Inset", (0, 0, top_z + 0.003), (0.30, 0.30, 0.006), inset, bevel=0.004))
    return join(parts, name)


def build_pieces(m):
    pieces = []
    pieces.append(tile("tile_grass", m, m["grass"], m["grass_dark"]))
    pieces.append(tile("tile_road", m, m["road"], m["road_edge"], inset=m["road_edge"]))
    pieces.append(tile("tile_water", m, m["water"], m["water_deep"], top_z=-0.22, thickness=0.12))
    pieces.append(tile("tile_island", m, m["stone"], m["stone_dark"], top_z=0.06, thickness=0.36))
    pieces.append(tile("tile_bridge", m, m["wood"], m["wood_dark"], top_z=0.04, thickness=0.16,
                       inset=m["wood_dark"]))

    # Wall block: a chunky stone with a slightly narrower cap.
    wall = [
        box("WallBase", (0, 0, 0.42), (0.48, 0.46, 0.42), m["stone"], bevel=0.08),
        box("WallCap", (0, 0, 0.88), (0.40, 0.38, 0.06), m["stone_dark"], bevel=0.04),
    ]
    pieces.append(join(wall, "wall_stone"))

    # Bush: three leafy blobs.
    bush = [
        ico("BushA", (-0.14, 0.05, 0.28), (0.34, 0.32, 0.30), m["leaf"], 2),
        ico("BushB", (0.16, -0.08, 0.30), (0.32, 0.30, 0.32), m["leaf_light"], 2),
        ico("BushC", (0.02, 0.14, 0.44), (0.28, 0.26, 0.26), m["leaf"], 2),
    ]
    pieces.append(join(bush, "bush"))

    # Round tree: trunk and two canopies.
    tree = [
        cylinder("TreeTrunk", (0, 0, 0.35), 0.13, 0.70, m["trunk"], vertices=8),
        ico("TreeCanopyA", (0, 0, 1.05), (0.55, 0.55, 0.50), m["leaf"], 2),
        ico("TreeCanopyB", (0.12, -0.08, 1.38), (0.36, 0.36, 0.32), m["leaf_light"], 2),
    ]
    pieces.append(join(tree, "tree_round"))

    # Pine: three cones.
    pine = [
        cylinder("PineTrunk", (0, 0, 0.25), 0.11, 0.50, m["trunk"], vertices=8),
        cone("PineA", (0, 0, 0.75), 0.55, 0.0, 0.70, m["pine"], vertices=8),
        cone("PineB", (0, 0, 1.15), 0.42, 0.0, 0.62, m["pine"], vertices=8),
        cone("PineC", (0, 0, 1.52), 0.28, 0.0, 0.52, m["pine"], vertices=8),
    ]
    pieces.append(join(pine, "tree_pine"))

    # Rocks.
    pieces.append(join([ico("RockA", (0, 0, 0.22), (0.42, 0.34, 0.26), m["stone"], 1),
                        ico("RockB", (0.18, 0.12, 0.16), (0.22, 0.18, 0.16), m["stone_dark"], 1)], "rock"))

    # Flower patch: a few coloured dots on a leaf blob.
    flower = [ico("FlowerLeaf", (0, 0, 0.10), (0.30, 0.28, 0.10), m["leaf_light"], 1)]
    for index, (x, y) in enumerate(((-0.12, 0.05), (0.10, -0.08), (0.02, 0.14))):
        flower.append(uv_sphere(f"Flower{index}", (x, y, 0.24), (0.07, 0.07, 0.06), m["flower"], 8, 6))
    pieces.append(join(flower, "flower"))

    # Bridge post: short stone pillar for bridge corners.
    pieces.append(join([box("PostBase", (0, 0, 0.30), (0.16, 0.16, 0.30), m["stone_dark"], bevel=0.04),
                        box("PostCap", (0, 0, 0.64), (0.20, 0.20, 0.05), m["stone"], bevel=0.03)], "bridge_post"))

    # Tower platform: stone disc with a rim.
    pieces.append(join([cylinder("PlatformDisc", (0, 0, 0.08), 1.0, 0.16, m["stone"], vertices=24),
                        cylinder("PlatformRim", (0, 0, 0.19), 0.86, 0.06, m["stone_dark"], vertices=24)],
                       "platform_tower"))
    pieces.append(join([cylinder("CoreDisc", (0, 0, 0.10), 1.85, 0.20, m["stone"], vertices=32),
                        cylinder("CoreRim", (0, 0, 0.24), 1.55, 0.08, m["stone_dark"], vertices=32)],
                       "platform_core"))

    # Dragon pit: glowing centre of the island.
    pieces.append(join([cylinder("PitRim", (0, 0, 0.10), 1.15, 0.14, m["stone_dark"], vertices=24),
                        cylinder("PitLava", (0, 0, 0.12), 0.95, 0.08, m["lava"], vertices=24)], "dragon_pit"))
    return pieces


def layout_preview(pieces):
    columns = 5
    for index, piece in enumerate(pieces):
        piece.location = ((index % columns) * 2.2 - 4.4, (index // columns) * -2.2 + 2.2, 0.0)


def reset_positions(pieces):
    for piece in pieces:
        piece.location = (0, 0, 0)


def setup_preview():
    ground = material("PREVIEW Ground", (0.045, 0.06, 0.08), roughness=0.9)
    bpy.ops.mesh.primitive_plane_add(size=18, location=(0, 0, -0.32))
    plane = bpy.context.object
    plane.name = "PREVIEW_ONLY_Ground"
    plane.data.materials.append(ground)
    bpy.ops.object.light_add(type="SUN", location=(4, -4, 8))
    sun = bpy.context.object
    sun.name = "PREVIEW_ONLY_Sun"
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), 0, math.radians(35))
    bpy.ops.object.camera_add(location=(0, -11.5, 9.5))
    camera = bpy.context.object
    camera.name = "PREVIEW_ONLY_Camera"
    camera.data.lens = 40
    direction = Vector((0, 0, 0.3)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene = bpy.context.scene
    scene.camera = camera
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 700
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_PATH)
    scene.view_settings.look = "AgX - Medium High Contrast"


def export(pieces):
    bpy.ops.object.select_all(action="DESELECT")
    for piece in pieces:
        piece.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH), export_format="GLB", use_selection=True,
        export_animations=False, export_materials="EXPORT", export_cameras=False,
        export_lights=False, export_yup=True,
    )


def main():
    reset_scene()
    m = mats()
    pieces = build_pieces(m)
    layout_preview(pieces)
    setup_preview()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.render.render(write_still=True)
    reset_positions(pieces)
    export(pieces)
    print("MAP_KIT_BUILD_OK", GLB_PATH, "pieces=%d" % len(pieces))


if __name__ == "__main__":
    main()
