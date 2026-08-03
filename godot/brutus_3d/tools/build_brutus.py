"""Build Arena Frenetica's original Brutus model, rig, animations and GLB.

Run with Blender 5.2+:
  blender --background --factory-startup --python build_brutus.py
"""

from pathlib import Path
import math

import bpy
from mathutils import Euler, Matrix, Vector


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "brutus"
BLEND_PATH = ASSET_DIR / "brutus_source.blend"
GLB_PATH = ASSET_DIR / "brutus.glb"
SHIELD_GLB_PATH = ASSET_DIR / "brutus_shield.glb"
PREVIEW_PATH = ASSET_DIR / "brutus_preview.png"


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials,
                       bpy.data.cameras, bpy.data.lights, bpy.data.armatures):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def material(name, color, metallic=0.0, roughness=0.45):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


MATS = {}


def make_materials():
    global MATS
    MATS = {
        # Materiais foscos e saturados sobrevivem melhor à redução para 40–70 px.
        # O acabamento antigo era metálico demais e virava um conjunto de brilhos.
        "orange": material("Brutus Orange Enamel", (0.96, 0.24, 0.018), 0.18, 0.46),
        "orange_dark": material("Brutus Burnt Orange", (0.50, 0.055, 0.012), 0.10, 0.56),
        "gold": material("Brutus Warm Gold", (1.0, 0.52, 0.035), 0.35, 0.38),
        "gold_dark": material("Brutus Aged Gold", (0.54, 0.17, 0.012), 0.25, 0.48),
        "steel": material("Brutus Steel", (0.34, 0.40, 0.48), 0.42, 0.40),
        "steel_dark": material("Brutus Dark Steel", (0.045, 0.06, 0.09), 0.20, 0.52),
        "leather": material("Brutus Leather", (0.20, 0.065, 0.025), 0.05, 0.63),
        "red": material("Brutus Plume Red", (0.76, 0.018, 0.012), 0.0, 0.52),
        "red_light": material("Brutus Plume Highlight", (1.0, 0.07, 0.018), 0.0, 0.46),
        "black": material("Brutus Visor Shadow", (0.009, 0.013, 0.022), 0.05, 0.58),
    }


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def finish_mesh(obj, mat_key, bone_name, rig, bevel=0.025, smooth=True):
    obj.data.materials.append(MATS[mat_key])
    select_only(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if bevel > 0.0:
        mod = obj.modifiers.new("Soft forged edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    group = obj.vertex_groups.new(name=bone_name)
    group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    armature = obj.modifiers.new("Brutus Rig", "ARMATURE")
    armature.object = rig
    obj.parent = rig
    obj["rig_bone"] = bone_name
    return obj


def box(name, loc, scale, mat_key, bone, rig, rot=(0, 0, 0), bevel=0.035):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (scale[0] / 2, scale[1] / 2, scale[2] / 2)
    return finish_mesh(obj, mat_key, bone, rig, bevel, smooth=False)


def sphere(name, loc, scale, mat_key, bone, rig, segments=32, rings=18):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    return finish_mesh(obj, mat_key, bone, rig, 0.0, smooth=True)


def cylinder(name, loc, radius, depth, mat_key, bone, rig, rot=(0, 0, 0), vertices=32, bevel=0.025):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                       location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    return finish_mesh(obj, mat_key, bone, rig, bevel, smooth=True)


def cone(name, loc, radius1, radius2, depth, mat_key, bone, rig,
         rot=(0, 0, 0), vertices=24, scale=(1, 1, 1), bevel=0.02):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2,
                                   depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    return finish_mesh(obj, mat_key, bone, rig, bevel, smooth=True)


def torus(name, loc, major, minor, mat_key, bone, rig, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                    major_segments=40, minor_segments=10,
                                    location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    return finish_mesh(obj, mat_key, bone, rig, 0.0, smooth=True)


def create_rig():
    armature = bpy.data.armatures.new("Brutus_Armature")
    armature.display_type = "STICK"
    rig = bpy.data.objects.new("BrutusRig", armature)
    bpy.context.collection.objects.link(rig)
    select_only(rig)
    bpy.ops.object.mode_set(mode="EDIT")

    def bone(name, head, tail, parent=None):
        b = armature.edit_bones.new(name)
        b.head = head
        b.tail = tail
        if parent:
            b.parent = armature.edit_bones[parent]
        return b

    bone("root", (0, 0, 0.06), (0, 0, 0.36))
    bone("pelvis", (0, 0, 0.95), (0, 0, 1.42), "root")
    bone("spine", (0, 0, 1.38), (0, 0, 2.10), "pelvis")
    bone("chest", (0, 0, 1.88), (0, 0, 2.54), "spine")
    bone("head", (0, 0, 2.42), (0, 0, 3.15), "chest")
    bone("plume", (0, 0.10, 3.02), (0, 0.62, 3.45), "head")

    bone("upper_arm.L", (-0.70, 0, 2.25), (-1.05, 0, 1.83), "chest")
    bone("forearm.L", (-1.05, 0, 1.83), (-1.02, -0.03, 1.34), "upper_arm.L")
    bone("hand.L", (-1.02, -0.03, 1.34), (-1.02, -0.12, 1.12), "forearm.L")
    bone("shield", (-1.02, -0.10, 1.55), (-1.02, -0.56, 1.55), "forearm.L")

    bone("upper_arm.R", (0.70, 0, 2.25), (1.05, 0, 1.83), "chest")
    bone("forearm.R", (1.05, 0, 1.83), (1.02, -0.03, 1.34), "upper_arm.R")
    bone("hand.R", (1.02, -0.03, 1.34), (1.02, -0.12, 1.12), "forearm.R")

    bone("thigh.L", (-0.35, 0, 1.13), (-0.35, 0, 0.63), "pelvis")
    bone("shin.L", (-0.35, 0, 0.63), (-0.35, -0.02, 0.20), "thigh.L")
    bone("foot.L", (-0.35, -0.02, 0.20), (-0.35, -0.35, 0.08), "shin.L")
    bone("thigh.R", (0.35, 0, 1.13), (0.35, 0, 0.63), "pelvis")
    bone("shin.R", (0.35, 0, 0.63), (0.35, -0.02, 0.20), "thigh.R")
    bone("foot.R", (0.35, -0.02, 0.20), (0.35, -0.35, 0.08), "shin.R")

    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def build_body(rig):
    # Compact heroic proportions: clear at a portrait mobile camera distance.
    sphere("Torso underarmor", (0, 0.04, 1.91), (0.76, 0.48, 0.77), "steel_dark", "chest", rig)
    sphere("Chest orange shell", (0, -0.18, 2.02), (0.70, 0.35, 0.66), "orange", "chest", rig)
    box("Chest gold rim", (0, -0.50, 2.04), (1.04, 0.10, 0.11), "gold", "chest", rig, bevel=0.025)
    box("Chest center brace", (0, -0.54, 1.93), (0.17, 0.10, 0.58), "gold_dark", "chest", rig, bevel=0.025)
    box("Chest diamond", (0, -0.62, 2.25), (0.30, 0.10, 0.30), "gold", "chest", rig,
        rot=(0, math.radians(45), 0), bevel=0.025)

    # Back plate and shoulder straps keep the model identifiable from every direction.
    sphere("Back plate", (0, 0.32, 2.02), (0.66, 0.20, 0.62), "orange_dark", "chest", rig)
    for x in (-0.42, 0.42):
        box(f"Back strap {x}", (x, 0.48, 2.12), (0.12, 0.08, 0.85), "steel", "chest", rig,
            rot=(0, math.radians(x * 8), 0), bevel=0.025)

    # Belt and four skirt plates.
    cylinder("Belt core", (0, 0, 1.36), 0.66, 0.25, "leather", "pelvis", rig,
             vertices=32, bevel=0.02)
    cylinder("Belt buckle", (0, -0.62, 1.36), 0.20, 0.10, "gold", "pelvis", rig,
             rot=(math.pi / 2, 0, 0), vertices=10, bevel=0.02)
    for x, y, rz in [(-0.38, -0.34, -0.12), (0.38, -0.34, 0.12),
                     (-0.38, 0.26, 0.10), (0.38, 0.26, -0.10)]:
        box(f"Armored skirt {x} {y}", (x, y, 1.12), (0.48, 0.22, 0.54), "orange", "pelvis", rig,
            rot=(0, rz, 0), bevel=0.055)
        box(f"Skirt trim {x} {y}", (x, y - (0.12 if y < 0 else -0.12), 0.91),
            (0.48, 0.07, 0.11), "gold", "pelvis", rig, rot=(0, rz, 0), bevel=0.02)


def build_head(rig):
    sphere("Head shadow", (0, 0, 2.68), (0.39, 0.35, 0.45), "black", "head", rig)
    sphere("Helmet crown", (0, 0.02, 2.82), (0.47, 0.42, 0.49), "gold", "head", rig)
    # The visor sits toward -Y (front).
    box("Visor face", (0, -0.405, 2.69), (0.78, 0.13, 0.43), "gold_dark", "head", rig, bevel=0.045)
    box("Visor eye slit", (0, -0.483, 2.76), (0.61, 0.025, 0.105), "black", "head", rig, bevel=0.015)
    box("Helmet brow", (0, -0.49, 2.91), (0.78, 0.07, 0.11), "gold", "head", rig, bevel=0.02)
    for x in (-0.23, -0.115, 0.0, 0.115, 0.23):
        box(f"Visor bar {x}", (x, -0.492, 2.61), (0.045, 0.025, 0.26), "gold", "head", rig,
            rot=(0, math.radians(x * 25), 0), bevel=0.012)
    for x in (-0.46, 0.46):
        cylinder(f"Helmet ear {x}", (x, 0.0, 2.76), 0.15, 0.10, "gold_dark", "head", rig,
                 rot=(0, math.pi / 2, 0), vertices=20, bevel=0.015)
        cylinder(f"Helmet ear inset {x}", (x + (-0.055 if x < 0 else 0.055), 0.0, 2.76),
                 0.085, 0.025, "orange", "head", rig, rot=(0, math.pi / 2, 0), vertices=20)

    cylinder("Plume socket", (0, 0.08, 3.20), 0.18, 0.16, "gold_dark", "plume", rig,
             rot=(math.pi / 2, 0, 0), vertices=20)
    feathers = [
        ((0, 0.10, 3.38), (0.13, 0.16, 0.34), -10, "red_light"),
        ((0, 0.27, 3.43), (0.15, 0.22, 0.38), -24, "red"),
        ((0, 0.50, 3.39), (0.16, 0.27, 0.34), -40, "red_light"),
        ((0, 0.72, 3.28), (0.14, 0.30, 0.27), -55, "red"),
        ((0, 0.89, 3.12), (0.11, 0.27, 0.20), -65, "red_light"),
    ]
    for i, (loc, scale, angle, mat_key) in enumerate(feathers):
        obj = sphere(f"Plume feather {i}", loc, scale, mat_key, "plume", rig, segments=24, rings=12)
        # Shape was baked; rotate vertices around object origin is not useful after transform.
        # The overlapping tapered silhouette is intentional and reads like layered feathers.


def build_arms(rig):
    for side, x in (("L", -1), ("R", 1)):
        bone_upper = f"upper_arm.{side}"
        bone_fore = f"forearm.{side}"
        bone_hand = f"hand.{side}"
        sphere(f"Pauldron {side}", (0.72 * x, 0.02, 2.28), (0.48, 0.46, 0.39),
               "orange", bone_upper, rig)
        torus(f"Pauldron rim {side}", (0.79 * x, -0.18, 2.28), 0.39, 0.055,
              "gold", bone_upper, rig, rot=(math.pi / 2, 0, 0))
        sphere(f"Upper arm mail {side}", (0.92 * x, 0.0, 1.92), (0.29, 0.27, 0.39),
               "steel_dark", bone_upper, rig)
        cylinder(f"Elbow guard {side}", (1.03 * x, -0.02, 1.66), 0.28, 0.27,
                 "gold_dark", bone_fore, rig, vertices=20, bevel=0.035)
        sphere(f"Forearm plate {side}", (1.03 * x, -0.02, 1.47), (0.30, 0.28, 0.37),
               "orange", bone_fore, rig)
        box(f"Bracer trim {side}", (1.03 * x, -0.29, 1.39), (0.48, 0.08, 0.13),
            "gold", bone_fore, rig, bevel=0.025)
        sphere(f"Gauntlet {side}", (1.03 * x, -0.08, 1.17), (0.30, 0.34, 0.26),
               "leather", bone_hand, rig)
        for finger in range(3):
            sphere(f"Knuckle {side} {finger}",
                   ((0.90 + finger * 0.13) * x, -0.35, 1.18), (0.075, 0.09, 0.075),
                   "gold_dark", bone_hand, rig, segments=16, rings=8)


def build_legs(rig):
    for side, x in (("L", -1), ("R", 1)):
        thigh = f"thigh.{side}"
        shin = f"shin.{side}"
        foot = f"foot.{side}"
        sphere(f"Thigh mail {side}", (0.34 * x, 0.0, 0.95), (0.33, 0.33, 0.39),
               "steel_dark", thigh, rig)
        sphere(f"Knee plate {side}", (0.34 * x, -0.30, 0.67), (0.29, 0.17, 0.24),
               "gold_dark", shin, rig)
        sphere(f"Shin plate {side}", (0.34 * x, -0.16, 0.44), (0.29, 0.27, 0.37),
               "orange_dark", shin, rig)
        box(f"Shin gold ridge {side}", (0.34 * x, -0.43, 0.44), (0.11, 0.07, 0.50),
            "gold", shin, rig, bevel=0.02)
        sphere(f"Boot {side}", (0.34 * x, -0.15, 0.16), (0.36, 0.50, 0.20),
               "leather", foot, rig)
        box(f"Boot toe plate {side}", (0.34 * x, -0.53, 0.17), (0.54, 0.25, 0.17),
            "gold_dark", foot, rig, bevel=0.035)


def build_shield(rig):
    center = Vector((-.96, -.49, 1.63))
    rot = (math.pi / 2, 0, 0)
    cylinder("Shield gold outer", center, 0.88, 0.13, "gold_dark", "shield", rig, rot=rot,
             vertices=40, bevel=0.03)
    cylinder("Shield orange face", center + Vector((0, -0.085, 0)), 0.75, 0.055,
             "orange", "shield", rig, rot=rot, vertices=40, bevel=0.018)
    torus("Shield steel ring", center + Vector((0, -0.13, 0)), 0.55, 0.055,
          "steel", "shield", rig, rot=rot)
    cylinder("Shield boss base", center + Vector((0, -0.16, 0)), 0.30, 0.16,
             "gold", "shield", rig, rot=rot, vertices=24, bevel=0.025)
    cone("Shield boss point", center + Vector((0, -0.29, 0)), 0.21, 0.02, 0.22,
         "gold", "shield", rig, rot=rot, vertices=20, bevel=0.012)
    for index, angle in enumerate((0, math.pi / 2, math.pi, 3 * math.pi / 2)):
        x = center.x + math.cos(angle) * 0.67
        z = center.z + math.sin(angle) * 0.67
        box(f"Shield stud {index}", (x, center.y - 0.16, z), (0.18, 0.09, 0.18),
            "gold", "shield", rig, rot=(0, math.radians(45), 0), bevel=0.025)


def compact_material_slots(character):
    """Remove repeated slots created by joining many authored armor pieces."""
    old_slots = list(character.data.materials)
    unique = []
    index_by_material = {}
    old_to_new = {}
    for old_index, mat in enumerate(old_slots):
        key = mat.name
        if key not in index_by_material:
            index_by_material[key] = len(unique)
            unique.append(mat)
        old_to_new[old_index] = index_by_material[key]
    desired_indices = [old_to_new[polygon.material_index] for polygon in character.data.polygons]
    character.data.materials.clear()
    for mat in unique:
        character.data.materials.append(mat)
    for polygon, desired_index in zip(character.data.polygons, desired_indices):
        polygon.material_index = desired_index


def join_mesh_group(meshes, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    character = bpy.context.object
    character.name = name
    compact_material_slots(character)
    return character


def export_standalone_shield():
    """Export a centered shield scene for the returning projectile visual."""
    shield_center = Vector((-0.96, -0.49, 1.63))
    source_parts = [obj for obj in bpy.context.scene.objects
                    if obj.type == "MESH" and obj.get("rig_bone") == "shield"]
    duplicates = []
    for source in source_parts:
        duplicate = source.copy()
        duplicate.data = source.data.copy()
        duplicate.name = f"Projectile_{source.name}"
        bpy.context.collection.objects.link(duplicate)
        duplicate.parent = None
        duplicate.modifiers.clear()
        duplicate.vertex_groups.clear()
        for vertex in duplicate.data.vertices:
            vertex.co -= shield_center
        duplicates.append(duplicate)
    projectile = join_mesh_group(duplicates, "BrutusShieldProjectile")
    select_only(projectile)
    bpy.ops.export_scene.gltf(
        filepath=str(SHIELD_GLB_PATH),
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_yup=True,
    )
    bpy.data.objects.remove(projectile, do_unlink=True)


def join_character_meshes(rig):
    """Keep the hand shield detachable while batching all other armor for mobile."""
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    shield_meshes = [obj for obj in meshes if obj.get("rig_bone") == "shield"]
    body_meshes = [obj for obj in meshes if obj.get("rig_bone") != "shield"]
    body = join_mesh_group(body_meshes, "BrutusCharacterMesh")
    shield = join_mesh_group(shield_meshes, "BrutusShieldMesh")
    return body, shield


def pose_reset(rig):
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)


def key_bone(rig, bone_name, frame, rot=(0, 0, 0), loc=(0, 0, 0), scale=(1, 1, 1)):
    pb = rig.pose.bones[bone_name]
    pb.rotation_mode = "XYZ"
    pb.rotation_euler = rot
    pb.location = loc
    pb.scale = scale
    pb.keyframe_insert("rotation_euler", frame=frame, group=bone_name)
    pb.keyframe_insert("location", frame=frame, group=bone_name)
    pb.keyframe_insert("scale", frame=frame, group=bone_name)


def new_action(rig, name):
    pose_reset(rig)
    action = bpy.data.actions.new(name)
    # Keep every authored clip in the editable .blend, not only the active idle.
    action.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = action
    return action


def finish_action(action, start, end, linear=False):
    action.frame_start = start
    action.frame_end = end
    for layer in action.layers:
        for strip in layer.strips:
            if hasattr(strip, "keyframe_strip"):
                channel_bag = strip.keyframe_strip.channelbags[0] if strip.keyframe_strip.channelbags else None
                if channel_bag:
                    for fcurve in channel_bag.fcurves:
                        for key in fcurve.keyframe_points:
                            key.interpolation = "LINEAR" if linear else "BEZIER"


RUN_PHASES = [
    # Athletic shield-run gait. Each half-step has contact, compression,
    # passing and a short flight phase. The longer 24-frame cycle deliberately
    # avoids the frantic toy-like cadence of the old 16-frame loop.
    # left thigh/shin/foot, right thigh/shin/foot, pelvis lift, lateral phase
    (29, -10, -15, -20, -37, 17, 0.000, -1.0),   # left contact
    (19, -23, -5, -13, -48, 13, -0.030, -0.55), # left compression
    (1, -39, 9, 7, -20, -4, -0.004, 0.0),       # right passing
    (-19, -51, 17, 23, -8, -12, 0.026, 0.72),   # flight
    (-20, -37, 17, 29, -10, -15, 0.000, 1.0),   # right contact
    (-13, -48, 13, 19, -23, -5, -0.030, 0.55), # right compression
    (7, -20, -4, 1, -39, 9, -0.004, 0.0),       # left passing
    (23, -8, -12, -19, -51, 17, 0.026, -0.72),  # flight
    (29, -10, -15, -20, -37, 17, 0.000, -1.0),  # seamless loop
]


WALK_PHASES = [
    # Full human walk cycle: contact, weight acceptance, passing and push-off.
    # The shield makes the left side quieter while the free arm counter-swings.
    # left thigh/shin/foot, right thigh/shin/foot, pelvis lift, lateral phase
    (20, -6, -10, -18, -30, 12, 0.000, -1.0),
    (13, -17, -4, -10, -38, 10, -0.024, -0.55),
    (-3, -29, 7, 5, -15, -5, -0.004, 0.0),
    (-14, -22, 10, 18, -5, -10, 0.016, 0.72),
    (-18, -30, 12, 20, -6, -10, 0.000, 1.0),
    (-10, -38, 10, 13, -17, -4, -0.024, 0.55),
    (5, -15, -5, -3, -29, 7, -0.004, 0.0),
    (18, -5, -10, -14, -22, 10, 0.016, -0.72),
    (20, -6, -10, -18, -30, 12, 0.000, -1.0),
]


def key_run_legs(rig, frame, phase):
    lt, ls, lf, rt, rs, rf, _lift, _side = phase
    key_bone(rig, "thigh.L", frame, rot=(math.radians(lt), 0, 0))
    key_bone(rig, "shin.L", frame, rot=(math.radians(ls), 0, 0))
    key_bone(rig, "foot.L", frame, rot=(math.radians(lf), 0, 0))
    key_bone(rig, "thigh.R", frame, rot=(math.radians(rt), 0, 0))
    key_bone(rig, "shin.R", frame, rot=(math.radians(rs), 0, 0))
    key_bone(rig, "foot.R", frame, rot=(math.radians(rf), 0, 0))


def build_animations(rig):
    # Idle: restrained breath and armor settling, no vertical bouncing.
    idle = new_action(rig, "idle")
    for frame, breath in ((1, 0.0), (24, 1.0), (48, 0.0)):
        key_bone(rig, "pelvis", frame, rot=(0, 0, math.radians(-1 + breath * 2)))
        key_bone(rig, "spine", frame, rot=(math.radians(1.5 * breath), 0, math.radians(0.7 - breath * 1.4)))
        key_bone(rig, "chest", frame, rot=(math.radians(-1.5 * breath), 0, math.radians(-0.5 + breath)))
        key_bone(rig, "head", frame, rot=(math.radians(-1 + breath), 0, math.radians(0.5 - breath)))
        key_bone(rig, "upper_arm.L", frame, rot=(math.radians(-5 + breath * 2), 0, math.radians(-3)))
        key_bone(rig, "upper_arm.R", frame, rot=(math.radians(4 - breath * 2), 0, math.radians(3)))
        key_bone(rig, "plume", frame, rot=(math.radians(-3 + breath * 5), 0, 0))
    finish_action(idle, 1, 48)

    # Walk: deliberate armored steps for partial analog input. Feet progress
    # through a real contact/down/pass/up cycle instead of swinging like rods.
    walk = new_action(rig, "walk")
    for phase_index, phase in enumerate(WALK_PHASES):
        frame = 1 + phase_index * 4
        lt, ls, lf, rt, rs, rf, lift, side = phase
        key_bone(rig, "root", frame, loc=(0, 0, 0))
        key_bone(rig, "pelvis", frame,
                 rot=(math.radians(2), math.radians(side * 2.4), math.radians(-side * 2.2)),
                 loc=(side * 0.012, -0.008, lift))
        key_bone(rig, "spine", frame,
                 rot=(math.radians(-4), math.radians(-side * 2.2), math.radians(side * 1.8)))
        key_bone(rig, "chest", frame,
                 rot=(math.radians(-1), math.radians(-side * 3.2), math.radians(side * 1.2)))
        key_bone(rig, "head", frame,
                 rot=(math.radians(4), math.radians(side * 0.8), math.radians(-side * 0.8)))
        key_bone(rig, "thigh.L", frame, rot=(math.radians(lt), 0, 0))
        key_bone(rig, "shin.L", frame, rot=(math.radians(ls), 0, 0))
        key_bone(rig, "foot.L", frame, rot=(math.radians(lf), 0, 0))
        key_bone(rig, "thigh.R", frame, rot=(math.radians(rt), 0, 0))
        key_bone(rig, "shin.R", frame, rot=(math.radians(rs), 0, 0))
        key_bone(rig, "foot.R", frame, rot=(math.radians(rf), 0, 0))
        key_bone(rig, "upper_arm.L", frame,
                 rot=(math.radians(-11 - side * 1.5), math.radians(12), math.radians(-15)))
        key_bone(rig, "forearm.L", frame,
                 rot=(math.radians(-22), math.radians(5), math.radians(-7)))
        key_bone(rig, "shield", frame,
                 rot=(math.radians(2 + lift * 70), math.radians(-side * 1.2), math.radians(side)))
        key_bone(rig, "upper_arm.R", frame,
                 rot=(math.radians(side * 18), 0, math.radians(7)))
        key_bone(rig, "forearm.R", frame,
                 rot=(math.radians(-18 - side * 5), 0, math.radians(-side * 2)))
        key_bone(rig, "plume", frame,
                 rot=(math.radians(-8 - max(lift, 0) * 90), 0, math.radians(-side * 2)))
    finish_action(walk, 1, 33)

    # Run: an athletic, shield-led sprint. The shield stays close to the chest
    # while the free arm, shoulders and hips counter-rotate like a human runner.
    run = new_action(rig, "run")
    for phase_index, phase in enumerate(RUN_PHASES):
        frame = 1 + phase_index * 3
        _lt, _ls, _lf, _rt, _rs, _rf, lift, side = phase
        key_bone(rig, "root", frame, loc=(0, 0, 0))
        key_bone(rig, "pelvis", frame,
                 rot=(math.radians(7), math.radians(side * 3.2), math.radians(-side * 2.0)),
                 loc=(side * 0.018, -0.018 + max(lift, 0) * 0.20, lift))
        key_bone(rig, "spine", frame,
                 rot=(math.radians(-12), math.radians(-side * 3.2), math.radians(side * 2.5)))
        key_bone(rig, "chest", frame,
                 rot=(math.radians(-4), math.radians(-side * 4.6), math.radians(side * 1.8)))
        key_bone(rig, "head", frame,
                 rot=(math.radians(10), math.radians(side * 1.2), math.radians(-side * 1.0)))
        key_run_legs(rig, frame, phase)
        # Left arm owns the shield: compact guard, only a little inertial lag.
        key_bone(rig, "upper_arm.L", frame,
                 rot=(math.radians(-18 - side * 2.5), math.radians(18 + side * 1.5),
                      math.radians(-22 - side * 1.5)))
        key_bone(rig, "forearm.L", frame,
                 rot=(math.radians(-29 - abs(side) * 2), math.radians(8), math.radians(-10)))
        key_bone(rig, "shield", frame,
                 rot=(math.radians(2 + lift * 90), math.radians(-side * 1.8), math.radians(side * 1.2)))
        # The free arm drives the stride and bends through the back swing.
        key_bone(rig, "upper_arm.R", frame,
                 rot=(math.radians(side * 38), math.radians(-side * 3), math.radians(8)))
        key_bone(rig, "forearm.R", frame,
                 rot=(math.radians(-32 - side * 10), 0, math.radians(-side * 3)))
        key_bone(rig, "plume", frame,
                 rot=(math.radians(-16 - max(lift, 0) * 130), 0, math.radians(-side * 3)))
    finish_action(run, 1, 25)

    # Ataque básico: golpe descendente com o escudo. A antecipação abre a
    # silhueta acima do ombro; quadril, tronco, braço e escudo chegam ao contato
    # em sequência. É um golpe de corpo inteiro, não um braço girando sozinho.
    attack = new_action(rig, "attack")
    attack_poses = [
        # frame, pitch, yaw, step, braço E, antebraço E, escudo, deslocamento
        (1, 0, 0, 0, (-24, 16, -20), (-20, 6, -9), (4, 0, 0), (0, 0, 0)),
        (3, -4, -12, -6, (-2, 38, -30), (-38, 14, -16), (16, -8, -12), (0, -0.04, 0.08)),
        (5, -8, -24, -12, (30, 54, -46), (-62, 22, -24), (30, -16, -22), (0, -0.10, 0.22)),
        (7, -6, -28, -14, (42, 58, -52), (-70, 24, -28), (34, -18, -24), (0, -0.12, 0.28)),
        (9, 16, 22, 20, (-62, 9, -38), (-25, 2, -14), (-14, 7, -14), (0, 0.22, -0.20)),
        (10, 16, 22, 20, (-62, 9, -38), (-25, 2, -14), (-14, 7, -14), (0, 0.22, -0.20)),
        (12, 11, 16, 15, (-48, 12, -34), (-23, 4, -13), (-9, 5, -11), (0, 0.13, -0.10)),
        (16, 4, 7, 7, (-30, 18, -24), (-20, 6, -10), (1, 1, -4), (0, 0.04, -0.02)),
        (22, 0, 0, 0, (-24, 16, -20), (-20, 6, -9), (4, 0, 0), (0, 0, 0)),
    ]
    for frame, pitch, torso_yaw, step, left_upper, left_fore, shield_rot, shield_loc in attack_poses:
        impact_amount = max(step, 0) / 20.0
        key_bone(rig, "pelvis", frame,
                 rot=(math.radians(pitch * 0.18), math.radians(torso_yaw * 0.30),
                      math.radians(-step * 0.08)),
                 loc=(0, -max(step, 0) * 0.004, -impact_amount * 0.035))
        key_bone(rig, "spine", frame,
                 rot=(math.radians(pitch * 0.36), math.radians(torso_yaw * 0.36),
                      math.radians(-step * 0.05)))
        key_bone(rig, "chest", frame,
                 rot=(math.radians(pitch * 0.30), math.radians(torso_yaw * 0.44),
                      math.radians(step * 0.05)))
        key_bone(rig, "head", frame,
                 rot=(math.radians(-pitch * 0.18), math.radians(-torso_yaw * 0.24), 0))
        key_bone(rig, "upper_arm.L", frame, rot=tuple(math.radians(v) for v in left_upper))
        key_bone(rig, "forearm.L", frame, rot=tuple(math.radians(v) for v in left_fore))
        shield_scale = 1.0 + impact_amount * 0.06
        key_bone(rig, "shield", frame, rot=tuple(math.radians(v) for v in shield_rot),
                 loc=shield_loc, scale=(shield_scale, shield_scale, shield_scale))
        # Braço livre e pernas contrabalançam o peso do disco.
        key_bone(rig, "upper_arm.R", frame,
                 rot=(math.radians(step * 0.72), math.radians(-torso_yaw * 0.12),
                      math.radians(8 + abs(step) * 0.18)))
        key_bone(rig, "forearm.R", frame,
                 rot=(math.radians(-18 - abs(step) * 0.28), 0, math.radians(step * 0.08)))
        key_bone(rig, "thigh.L", frame, rot=(math.radians(-step * 0.52), 0, 0))
        key_bone(rig, "shin.L", frame, rot=(math.radians(-abs(step) * 0.24), 0, 0))
        key_bone(rig, "thigh.R", frame, rot=(math.radians(step * 0.43), 0, 0))
        key_bone(rig, "plume", frame, rot=(math.radians(-pitch * 0.38), 0, 0))
    finish_action(attack, 1, 22)

    # Basic hit 2: a short diagonal shield bash. It shares the planted stance
    # and timing of hit 1, so both attacks can chain without a visible reset.
    attack_alt = new_action(rig, "attack_alt")
    shield_bash_poses = [
        # frame, pitch, torso yaw, step, left upper arm, left forearm, shield
        (1, 0, 0, 0, (-24, 16, -20), (-20, 6, -9), (4, 0, 0)),
        (4, -4, -14, -10, (-10, 43, -17), (-20, 17, -9), (6, -6, -3)),
        (7, 4, 6, 7, (-25, 27, -22), (-20, 9, -11), (3, -2, -4)),
        (9, 13, 24, 18, (-45, 13, -32), (-24, 4, -15), (-8, 5, -10)),
        (10, 13, 24, 18, (-45, 13, -32), (-24, 4, -15), (-8, 5, -10)), # hit stop
        (15, 4, 8, 8, (-28, 20, -22), (-19, 7, -10), (2, 0, -3)),
        (23, 0, 0, 0, (-24, 16, -20), (-20, 6, -9), (4, 0, 0)),
    ]
    for frame, pitch, torso_yaw, step, left_upper, left_fore, shield_rot in shield_bash_poses:
        key_bone(rig, "pelvis", frame,
                 rot=(math.radians(pitch * 0.12), math.radians(torso_yaw * 0.28),
                      math.radians(-step * 0.05)), loc=(0, -max(step, 0) * 0.0025, 0))
        key_bone(rig, "spine", frame,
                 rot=(math.radians(pitch * 0.28), math.radians(torso_yaw * 0.34), 0))
        key_bone(rig, "chest", frame,
                 rot=(math.radians(pitch * 0.22), math.radians(torso_yaw * 0.40), 0))
        key_bone(rig, "head", frame,
                 rot=(math.radians(-pitch * 0.18), math.radians(-torso_yaw * 0.24), 0))
        key_bone(rig, "upper_arm.L", frame, rot=tuple(math.radians(v) for v in left_upper))
        key_bone(rig, "forearm.L", frame, rot=tuple(math.radians(v) for v in left_fore))
        # Push the disc along its own forward axis at contact. A tiny scale accent
        # is intentional impact exaggeration, not a persistent model change.
        shield_push = max(step, 0) * 0.008
        shield_scale = 1.0 + max(step, 0) * 0.0027
        key_bone(rig, "shield", frame, rot=tuple(math.radians(v) for v in shield_rot),
                 loc=(0, shield_push, 0), scale=(shield_scale, shield_scale, shield_scale))
        key_bone(rig, "upper_arm.R", frame,
                 rot=(math.radians(-step * 0.34), math.radians(-torso_yaw * 0.10), math.radians(9)))
        key_bone(rig, "forearm.R", frame, rot=(math.radians(-18 - abs(step) * 0.14), 0, 0))
        key_bone(rig, "thigh.L", frame, rot=(math.radians(-step * 0.44), 0, 0))
        key_bone(rig, "shin.L", frame, rot=(math.radians(-abs(step) * 0.18), 0, 0))
        key_bone(rig, "thigh.R", frame, rot=(math.radians(step * 0.36), 0, 0))
        key_bone(rig, "plume", frame, rot=(math.radians(-pitch * 0.38), 0, 0))
    finish_action(attack_alt, 1, 23)

    # Q — Investida: drop the centre of mass, launch off the rear foot, then
    # keep sprinting behind the shield. The shield never becomes a static sled.
    charge = new_action(rig, "q")
    charge_poses = [
        (1, 0, 0),
        (4, 6, 10),
        (7, 17, 27),
        (25, 17, 27),
        (29, 10, 14),
        (36, 0, 0),
    ]
    for frame, lean, brace in charge_poses:
        key_bone(rig, "pelvis", frame, rot=(math.radians(lean * 0.20), 0, math.radians(-brace * 0.08)))
        key_bone(rig, "spine", frame, rot=(math.radians(-lean * 0.65), 0, math.radians(-brace * 0.12)))
        key_bone(rig, "chest", frame, rot=(math.radians(-lean * 0.35), 0, math.radians(-brace * 0.10)))
        key_bone(rig, "head", frame, rot=(math.radians(lean * 0.38), 0, math.radians(brace * 0.08)))
        key_bone(rig, "upper_arm.L", frame,
                 rot=(math.radians(-brace * 0.92), math.radians(brace * 0.48),
                      math.radians(-8 - brace * 0.48)))
        key_bone(rig, "forearm.L", frame,
                 rot=(math.radians(-brace * 0.52), math.radians(brace * 0.18),
                      math.radians(-brace * 0.25)))
        key_bone(rig, "shield", frame,
                 rot=(math.radians(brace * 0.16), math.radians(-brace * 0.10), 0))
        key_bone(rig, "upper_arm.R", frame,
                 rot=(math.radians(brace * 0.25), 0, math.radians(6 + brace * 0.15)))
        key_bone(rig, "thigh.L", frame, rot=(math.radians(lean * 0.30), 0, 0))
        key_bone(rig, "thigh.R", frame, rot=(math.radians(-lean * 0.22), 0, 0))
        key_bone(rig, "plume", frame, rot=(math.radians(-brace * 0.65), 0, 0))

    # During the actual dash the lower body completes a full, readable running
    # cycle. Pelvis motion is keyed too, so the feet push the body instead of
    # cycling beneath a frozen torso.
    for phase_index, phase in enumerate(RUN_PHASES):
        frame = 7 + phase_index * 2
        _lt, _ls, _lf, _rt, _rs, _rf, lift, side = phase
        key_run_legs(rig, frame, phase)
        key_bone(rig, "pelvis", frame,
                 rot=(math.radians(5), math.radians(side * 2.2), math.radians(-side * 1.6)),
                 loc=(side * 0.012, -0.025, lift * 0.82))
        key_bone(rig, "spine", frame,
                 rot=(math.radians(-9), math.radians(-side * 2.0), math.radians(-3.0)))
        key_bone(rig, "chest", frame,
                 rot=(math.radians(-5), math.radians(-side * 2.5), math.radians(-2.5)))
        key_bone(rig, "head", frame,
                 rot=(math.radians(8), math.radians(side * 1.0), math.radians(2.0)))
        key_bone(rig, "upper_arm.L", frame,
                 rot=(math.radians(-30 - side * 1.5), math.radians(16), math.radians(-24)))
        key_bone(rig, "forearm.L", frame,
                 rot=(math.radians(-18), math.radians(6), math.radians(-10)))
        key_bone(rig, "shield", frame,
                 rot=(math.radians(5 + lift * 80), math.radians(-side), math.radians(side)))
        key_bone(rig, "upper_arm.R", frame,
                 rot=(math.radians(side * 34), 0, math.radians(9)))
        key_bone(rig, "forearm.R", frame,
                 rot=(math.radians(-31 - side * 9), 0, 0))
        key_bone(rig, "plume", frame,
                 rot=(math.radians(-22 - max(lift, 0) * 130), 0, math.radians(-side * 3)))
    finish_action(charge, 1, 36)

    # R — Shield throw: the rear foot and hips start the throw, the chest and
    # shoulder follow, and the arm releases last. This is a step-through throw,
    # not an arm-only swivel.
    ultimate = new_action(rig, "ultimate")
    ultimate_poses = [
        # frame, pitch, torso yaw, step, left upper arm, left forearm, shield
        (1, 0, 0, 0, (0, 0, -3), (0, 0, 0), (0, 0, 0)),
        (6, -4, -10, -8, (-8, 25, -12), (-12, 10, -6), (2, -4, -2)),
        (11, -8, -22, -15, (-12, 42, -18), (-20, 18, -10), (4, -8, -5)),
        (15, 2, -8, -5, (-22, 18, -24), (-28, 10, -16), (2, -3, -4)),
        (18, 12, 18, 18, (-40, 10, -34), (-44, 6, -22), (-8, 6, -10)),
        (24, 8, 12, 12, (-24, 4, -20), (-28, 2, -12), (-4, 3, -6)),
        (34, 0, 0, 0, (-8, 0, -8), (-6, 0, -4), (0, 0, 0)),
        (45, 4, 6, 5, (-18, 18, -20), (-24, 8, -10), (2, -3, -2)),
        (48, 0, 0, 0, (0, 0, -3), (0, 0, 0), (0, 0, 0)),
    ]
    for frame, body_pitch, torso_yaw, step, upper_deg, fore_deg, shield_deg in ultimate_poses:
        # Y rotates the torso around its vertical axis. Z is deliberately kept
        # small so the wind-up does not collapse into a sideways bend.
        key_bone(rig, "pelvis", frame,
                 rot=(math.radians(body_pitch * 0.12), math.radians(torso_yaw * 0.28),
                      math.radians(-step * 0.04)))
        key_bone(rig, "spine", frame,
                 rot=(math.radians(body_pitch * 0.30), math.radians(torso_yaw * 0.34),
                      math.radians(-step * 0.05)))
        key_bone(rig, "chest", frame,
                 rot=(math.radians(body_pitch * 0.24), math.radians(torso_yaw * 0.42),
                      math.radians(step * 0.04)))
        key_bone(rig, "head", frame,
                 rot=(math.radians(-body_pitch * 0.20), math.radians(-torso_yaw * 0.28),
                      math.radians(step * 0.03)))
        key_bone(rig, "upper_arm.L", frame, rot=tuple(math.radians(v) for v in upper_deg))
        key_bone(rig, "forearm.L", frame, rot=tuple(math.radians(v) for v in fore_deg))
        key_bone(rig, "shield", frame, rot=tuple(math.radians(v) for v in shield_deg))
        key_bone(rig, "upper_arm.R", frame,
                 rot=(math.radians(-step * 0.42), math.radians(-torso_yaw * 0.12),
                      math.radians(8 + step * 0.08)))
        key_bone(rig, "forearm.R", frame, rot=(math.radians(-12 - abs(step) * 0.20), 0, 0))
        key_bone(rig, "thigh.L", frame, rot=(math.radians(-step * 0.62), 0, 0))
        key_bone(rig, "shin.L", frame, rot=(math.radians(-abs(step) * 0.32), 0, 0))
        key_bone(rig, "thigh.R", frame, rot=(math.radians(step * 0.52), 0, 0))
        key_bone(rig, "shin.R", frame, rot=(math.radians(-abs(step) * 0.18), 0, 0))
        key_bone(rig, "plume", frame,
                 rot=(math.radians(-body_pitch * 0.42), math.radians(-torso_yaw * 0.08),
                      math.radians(-step * 0.08)))
    finish_action(ultimate, 1, 48)

    # Damage reaction: a short full-body recoil that keeps the shield readable.
    hurt = new_action(rig, "hurt")
    for frame, recoil in ((1, 0.0), (4, 1.0), (8, 0.62), (16, 0.0)):
        key_bone(rig, "root", frame,
                 rot=(math.radians(recoil * 4), 0, math.radians(recoil * -3)))
        key_bone(rig, "pelvis", frame,
                 rot=(math.radians(recoil * -5), math.radians(recoil * -4), 0),
                 loc=(0, recoil * 0.025, recoil * -0.035))
        key_bone(rig, "spine", frame,
                 rot=(math.radians(recoil * 11), math.radians(recoil * 8),
                      math.radians(recoil * -5)))
        key_bone(rig, "chest", frame,
                 rot=(math.radians(recoil * 8), math.radians(recoil * 6),
                      math.radians(recoil * -4)))
        key_bone(rig, "head", frame,
                 rot=(math.radians(recoil * -12), math.radians(recoil * -5),
                      math.radians(recoil * 6)))
        key_bone(rig, "upper_arm.L", frame,
                 rot=(math.radians(-24 - recoil * 8), math.radians(16),
                      math.radians(-20 - recoil * 5)))
        key_bone(rig, "forearm.L", frame,
                 rot=(math.radians(-20 - recoil * 6), math.radians(6), math.radians(-9)))
        key_bone(rig, "upper_arm.R", frame,
                 rot=(math.radians(recoil * 16), 0, math.radians(7 + recoil * 8)))
        key_bone(rig, "forearm.R", frame,
                 rot=(math.radians(-recoil * 18), 0, 0))
        key_bone(rig, "plume", frame,
                 rot=(math.radians(-recoil * 24), 0, math.radians(recoil * 5)))
    finish_action(hurt, 1, 16)

    # Death: stagger, knees buckle, then the whole rig falls forward from its
    # planted root. The last frame is held by the web renderer until respawn.
    death = new_action(rig, "death")
    death_poses = [
        # frame, root fall, body curl, knee bend, vertical drop
        (1, 0, 0, 0, 0.0),
        (8, -4, 8, 8, -0.03),
        (16, -12, 18, 30, -0.18),
        (25, -36, 28, 48, -0.32),
        (34, -68, 18, 34, -0.22),
        (42, -78, 12, 22, -0.18),
    ]
    for frame, root_fall, curl, knee, drop in death_poses:
        key_bone(rig, "root", frame, rot=(math.radians(root_fall), 0, 0), loc=(0, 0, drop))
        key_bone(rig, "pelvis", frame, rot=(math.radians(curl * 0.18), 0, 0))
        key_bone(rig, "spine", frame, rot=(math.radians(curl * 0.46), 0, 0))
        key_bone(rig, "chest", frame, rot=(math.radians(curl * 0.34), 0, 0))
        key_bone(rig, "head", frame, rot=(math.radians(-curl * 0.28), 0, 0))
        key_bone(rig, "thigh.L", frame, rot=(math.radians(knee * 0.55), 0, 0))
        key_bone(rig, "shin.L", frame, rot=(math.radians(-knee), 0, 0))
        key_bone(rig, "thigh.R", frame, rot=(math.radians(knee * 0.48), 0, 0))
        key_bone(rig, "shin.R", frame, rot=(math.radians(-knee * 0.92), 0, 0))
        key_bone(rig, "upper_arm.L", frame,
                 rot=(math.radians(-18 - curl * 0.42), math.radians(12), math.radians(-18)))
        key_bone(rig, "forearm.L", frame, rot=(math.radians(-18), 0, math.radians(-8)))
        key_bone(rig, "upper_arm.R", frame,
                 rot=(math.radians(curl * 0.52), 0, math.radians(8 + curl * 0.20)))
        key_bone(rig, "forearm.R", frame, rot=(math.radians(-curl * 0.38), 0, 0))
        key_bone(rig, "plume", frame, rot=(math.radians(-curl * 0.55), 0, 0))
    finish_action(death, 1, 42)

    rig.animation_data.action = idle
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 48
    bpy.context.scene.frame_set(1)
    return [idle, walk, run, attack, attack_alt, charge, ultimate, hurt, death]


def point_camera(camera, target):
    direction = Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def setup_preview(rig):
    floor_mat = material("Preview Ground", (0.055, 0.075, 0.09), 0.0, 0.72)
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=3.0, depth=0.12, location=(0, 0, -0.08))
    floor = bpy.context.object
    floor.name = "PREVIEW_ONLY_Ground"
    floor.data.materials.append(floor_mat)
    bevel = floor.modifiers.new("Ground bevel", "BEVEL")
    bevel.width = 0.12
    bevel.segments = 3

    bpy.ops.object.light_add(type="AREA", location=(-4.5, -5.5, 7.0))
    key = bpy.context.object
    key.name = "PREVIEW_ONLY_Key"
    key.data.energy = 1100
    key.data.shape = "DISK"
    key.data.size = 4.0
    key.data.color = (1.0, 0.64, 0.34)
    point_camera(key, (0, 0, 1.6))

    bpy.ops.object.light_add(type="AREA", location=(4.0, 1.0, 4.5))
    fill = bpy.context.object
    fill.name = "PREVIEW_ONLY_Fill"
    fill.data.energy = 850
    fill.data.size = 3.0
    fill.data.color = (0.35, 0.55, 1.0)
    point_camera(fill, (0, 0, 1.8))

    bpy.ops.object.light_add(type="AREA", location=(0, 4.5, 5.0))
    rim = bpy.context.object
    rim.name = "PREVIEW_ONLY_Rim"
    rim.data.energy = 1200
    rim.data.size = 2.5
    rim.data.color = (1.0, 0.20, 0.06)
    point_camera(rim, (0, 0, 2.0))

    bpy.ops.object.camera_add(location=(5.2, -7.7, 4.35))
    camera = bpy.context.object
    camera.name = "PREVIEW_ONLY_Camera"
    camera.data.lens = 68
    point_camera(camera, (0, 0, 1.72))
    bpy.context.scene.camera = camera

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.fps = 30
    scene.render.resolution_x = 720
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_PATH)
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = "RGBA"
    scene.world.color = (0.008, 0.012, 0.022)
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.render.render(write_still=True)


def export_glb(rig):
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for obj in bpy.data.objects:
        if obj.type == "MESH" and not obj.name.startswith("PREVIEW_ONLY_"):
            obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_frame_step=1,
        export_skins=True,
        export_def_bones=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_yup=True,
    )


def main():
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    clear_scene()
    make_materials()
    rig = create_rig()
    build_body(rig)
    build_head(rig)
    build_arms(rig)
    build_legs(rig)
    build_shield(rig)
    export_standalone_shield()
    join_character_meshes(rig)
    build_animations(rig)
    setup_preview(rig)
    export_glb(rig)
    print(f"BRUTUS_BUILD_OK blend={BLEND_PATH} glb={GLB_PATH} preview={PREVIEW_PATH}")


if __name__ == "__main__":
    main()
