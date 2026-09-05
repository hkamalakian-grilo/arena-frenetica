"""Build the original 3D dragon egg and dragon for Arena Frenética.

Run with Blender 5.2+:
    blender --background --python tools/build_dragon_family.py

The script produces editable .blend sources, runtime GLBs and transparent
preview renders. No external mesh, texture or animation is used.
"""

from pathlib import Path
import math

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "dragon"
ASSET_DIR.mkdir(parents=True, exist_ok=True)

DRAGON_BLEND = ASSET_DIR / "dragon_source.blend"
DRAGON_GLB = ASSET_DIR / "dragon_3d.glb"
DRAGON_PREVIEW = ASSET_DIR / "dragon_3d_preview.png"
EGG_BLEND = ASSET_DIR / "dragon_egg_source.blend"
EGG_GLB = ASSET_DIR / "dragon_egg_3d.glb"
EGG_PREVIEW = ASSET_DIR / "dragon_egg_3d_preview.png"


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for blocks in (
        bpy.data.meshes, bpy.data.curves, bpy.data.materials,
        bpy.data.cameras, bpy.data.lights, bpy.data.armatures,
    ):
        for block in list(blocks):
            blocks.remove(block)
    # Actions are not owned by scene objects. Keeping them here would make the
    # second GLB export inherit clips and bone tracks from the first creature.
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)


def material(name, color, metallic=0.0, roughness=0.55, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if emission > 0.0:
            emission_color = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
            emission_strength = bsdf.inputs.get("Emission Strength")
            if emission_color:
                emission_color.default_value = (*color, 1.0)
            if emission_strength:
                emission_strength.default_value = emission
    return mat


def finish_mesh(obj, mat, bevel=0.0, smooth=False):
    obj.data.materials.append(mat)
    if bevel > 0.0:
        modifier = obj.modifiers.new("Soft authored edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    return obj


def ico(name, loc, scale, mat, subdivisions=2, bevel=0.0):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1.0, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_mesh(obj, mat, bevel)


def uv_sphere(name, loc, scale, mat, segments=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_mesh(obj, mat, smooth=True)


def cone(name, loc, radius1, radius2, depth, mat, rot=(0, 0, 0), vertices=8):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius1, radius2=radius2,
        depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    return finish_mesh(obj, mat, bevel=0.025)


def cylinder(name, loc, radius, depth, mat, rot=(0, 0, 0), vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=depth,
        location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    return finish_mesh(obj, mat, bevel=0.025)


def beam_between(name, start, end, radius, mat, vertices=8):
    """Create an export-safe structural beam that follows authored points."""
    return curve_line(name, [start, end], radius, mat)


def torus(name, loc, major, minor, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor, major_segments=32,
        minor_segments=8, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    return finish_mesh(obj, mat)


def box(name, loc, scale, mat, rot=(0, 0, 0), bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_mesh(obj, mat, bevel)


def mesh_object(name, vertices, faces, mat, bevel=0.0, solidify=0.0):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    finish_mesh(obj, mat, bevel)
    if solidify > 0.0:
        modifier = obj.modifiers.new("Authored thickness", "SOLIDIFY")
        modifier.thickness = solidify
    return obj


def diamond(name, loc, scale, mat, rot=(0, 0, 0)):
    sx, sy, sz = scale
    verts = [
        (0, 0, sz), (sx, 0, 0), (0, sy, 0), (-sx, 0, 0),
        (0, -sy, 0), (0, 0, -sz),
    ]
    faces = [
        (0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 1),
        (5, 2, 1), (5, 3, 2), (5, 4, 3), (5, 1, 4),
    ]
    obj = mesh_object(name, verts, faces, mat, bevel=0.025)
    obj.location = loc
    obj.rotation_euler = rot
    return obj


def diamond_frame(name, loc, outer, inner, mat):
    """Create a planar, solid diamond frame facing the map camera."""
    x, y, z = loc
    ox, oz = outer
    ix, iz = inner
    verts = [
        (x, y, z + oz), (x + ox, y, z), (x, y, z - oz), (x - ox, y, z),
        (x, y, z + iz), (x + ix, y, z), (x, y, z - iz), (x - ix, y, z),
    ]
    faces = [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return mesh_object(name, verts, faces, mat, bevel=0.025, solidify=0.065)


def curve_line(name, points, bevel_depth, mat):
    curve = bpy.data.curves.new(name + "Curve", type="CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = bevel_depth
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, co in zip(spline.points, points):
        point.co = (*co, 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def create_rig(name, bones):
    armature = bpy.data.armatures.new(name + "Armature")
    rig = bpy.data.objects.new(name + "Rig", armature)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    edit_bones = {}
    for bone_name, head, tail, parent_name in bones:
        bone = armature.edit_bones.new(bone_name)
        bone.head = head
        bone.tail = tail
        if parent_name:
            bone.parent = edit_bones[parent_name]
        edit_bones[bone_name] = bone
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def parent_to_bone(obj, rig, bone_name):
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    obj.matrix_world = world


def reset_pose(rig):
    for bone in rig.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = (0, 0, 0)
        bone.location = (0, 0, 0)
        bone.scale = (1, 1, 1)


def new_action(rig, name):
    reset_pose(rig)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = action
    return action


def key_bone(rig, bone_name, frame, rot=(0, 0, 0), loc=(0, 0, 0), scale=(1, 1, 1)):
    bone = rig.pose.bones[bone_name]
    bone.rotation_mode = "XYZ"
    bone.rotation_euler = rot
    bone.location = loc
    bone.scale = scale
    bone.keyframe_insert("rotation_euler", frame=frame, group=bone_name)
    bone.keyframe_insert("location", frame=frame, group=bone_name)
    bone.keyframe_insert("scale", frame=frame, group=bone_name)


def finish_action(action, start, end):
    action.frame_start = start
    action.frame_end = end


def dragon_materials():
    return {
        "violet": material("Dragon Violet", (0.10, 0.025, 0.29), roughness=0.58),
        "purple": material("Dragon Purple", (0.23, 0.045, 0.49), roughness=0.52),
        "indigo": material("Dragon Indigo", (0.025, 0.055, 0.31), metallic=0.15, roughness=0.44),
        "membrane": material("Wing Membrane", (0.13, 0.015, 0.25), roughness=0.70),
        "gold": material("Ancient Gold", (0.73, 0.43, 0.09), metallic=0.72, roughness=0.34),
        "horn": material("Warm Horn", (0.78, 0.70, 0.52), roughness=0.64),
        "eye": material("Arcane Eye", (0.28, 0.78, 1.0), roughness=0.25, emission=2.2),
        "crystal": material("Arcane Crystal", (0.25, 0.35, 1.0), metallic=0.25, roughness=0.24, emission=0.8),
    }


def build_dragon_model():
    reset_scene()
    mats = dragon_materials()
    bones = [
        ("root", (0, 0, 0.15), (0, 0, 1.0), None),
        ("body", (0, 0, 0.8), (0, 0, 1.65), "root"),
        ("neck", (0, -0.65, 1.2), (0, -1.15, 1.55), "body"),
        ("head", (0, -1.1, 1.5), (0, -1.75, 1.58), "neck"),
        ("jaw", (0, -1.42, 1.43), (0, -1.82, 1.35), "head"),
        ("wing.L", (-0.55, 0.0, 1.35), (-2.0, 0.3, 1.72), "body"),
        ("wing.R", (0.55, 0.0, 1.35), (2.0, 0.3, 1.72), "body"),
        ("tail.01", (0, 0.75, 1.05), (0, 1.55, 0.85), "body"),
        ("tail.02", (0, 1.5, 0.86), (0, 2.35, 0.58), "tail.01"),
    ]
    rig = create_rig("Dragon", bones)

    body_parts = [
        ico("Body", (0, 0.05, 1.08), (0.78, 1.02, 0.62), mats["violet"], 3),
        ico("Chest", (0, -0.63, 1.22), (0.65, 0.62, 0.58), mats["purple"], 2),
        ico("Haunch", (0, 0.72, 1.0), (0.70, 0.68, 0.52), mats["indigo"], 2),
    ]
    for part in body_parts:
        parent_to_bone(part, rig, "body")

    for index, y in enumerate((-0.46, -0.72, -0.96)):
        plate = diamond(
            f"ChestCrystal{index+1}", (0, y, 1.27 - index * 0.06),
            (0.22 - index * 0.025, 0.07, 0.30 - index * 0.02), mats["gold"],
            rot=(math.radians(90), 0, 0))
        parent_to_bone(plate, rig, "body")

    neck = ico("Neck", (0, -0.92, 1.43), (0.42, 0.66, 0.42), mats["purple"], 2)
    parent_to_bone(neck, rig, "neck")
    head = ico("Head", (0, -1.46, 1.57), (0.55, 0.72, 0.46), mats["purple"], 2)
    snout = ico("Snout", (0, -1.93, 1.48), (0.42, 0.48, 0.28), mats["indigo"], 2)
    parent_to_bone(head, rig, "head")
    parent_to_bone(snout, rig, "head")
    jaw = ico("Jaw", (0, -1.77, 1.30), (0.38, 0.48, 0.16), mats["violet"], 2)
    parent_to_bone(jaw, rig, "jaw")

    for side in (-1, 1):
        eye = ico(f"Eye.{side}", (0.29 * side, -1.86, 1.67), (0.075, 0.055, 0.075), mats["eye"], 2)
        brow = cone(
            f"BrowHorn.{side}", (0.34 * side, -1.63, 1.88), 0.13, 0.02, 0.52,
            mats["horn"], rot=(math.radians(-18), math.radians(24 * side), 0))
        main_horn = cone(
            f"MainHorn.{side}", (0.34 * side, -1.23, 1.93), 0.18, 0.025, 0.78,
            mats["horn"], rot=(math.radians(-32), math.radians(20 * side), 0))
        parent_to_bone(eye, rig, "head")
        parent_to_bone(brow, rig, "head")
        parent_to_bone(main_horn, rig, "head")

    for index, y in enumerate((-0.48, -0.15, 0.18, 0.50, 0.80)):
        spike = cone(
            f"Spine{index+1}", (0, y, 1.70 - index * 0.06),
            0.16, 0.015, 0.48 - index * 0.035, mats["crystal"],
            rot=(0, 0, 0), vertices=6)
        parent_to_bone(spike, rig, "body")

    wing_specs = {
        "L": [(-0.48, 0.0, 1.45), (-1.58, 0.58, 2.02), (-1.38, 1.38, 1.16), (-0.68, 0.92, 1.05)],
        "R": [(0.48, 0.0, 1.45), (1.58, 0.58, 2.02), (1.38, 1.38, 1.16), (0.68, 0.92, 1.05)],
    }
    for side, verts in wing_specs.items():
        wing = mesh_object(f"WingMembrane.{side}", verts, [(0, 1, 2), (0, 2, 3)], mats["membrane"], bevel=0.035, solidify=0.035)
        parent_to_bone(wing, rig, f"wing.{side}")
        # The spars follow the authored membrane edges exactly, so they read as
        # part of the wing instead of disconnected horizontal rods.
        for spar_index, (start, end) in enumerate(((verts[0], verts[1]), (verts[0], verts[3]), (verts[1], verts[2]))):
            spar = beam_between(
                f"WingSpar.{side}.{spar_index + 1}", start, end,
                0.055 if spar_index < 2 else 0.04, mats["indigo"])
            parent_to_bone(spar, rig, f"wing.{side}")

    tail1 = ico("Tail01", (0, 1.33, 0.88), (0.42, 0.82, 0.36), mats["violet"], 2)
    tail2 = cone(
        "Tail02", (0, 2.13, 0.62), 0.36, 0.035, 1.38, mats["purple"],
        rot=(math.radians(72), 0, 0), vertices=10)
    tail_crystal = diamond("TailCrystal", (0, 2.68, 0.48), (0.26, 0.22, 0.42), mats["crystal"])
    parent_to_bone(tail1, rig, "tail.01")
    parent_to_bone(tail2, rig, "tail.02")
    parent_to_bone(tail_crystal, rig, "tail.02")

    for side in (-1, 1):
        for front, y in ((True, -0.55), (False, 0.65)):
            x = 0.64 * side
            upper = ico(
                f"LegUpper.{side}.{front}", (x, y, 0.80),
                (0.25, 0.27, 0.38), mats["violet"], 1)
            lower_start = (x * 1.02, y - 0.04, 0.66)
            lower_end = (x * 1.14, y - 0.13, 0.43)
            lower = beam_between(
                f"LegLower.{side}.{front}", lower_start, lower_end,
                0.115, mats["indigo"], vertices=7)
            foot = ico(
                f"Foot.{side}.{front}", (x * 1.16, y - 0.17, 0.40),
                (0.24, 0.38, 0.15), mats["purple"], 1)
            parent_to_bone(upper, rig, "body")
            parent_to_bone(lower, rig, "body")
            parent_to_bone(foot, rig, "body")
            for claw_index in (-1, 0, 1):
                claw = cone(
                    f"Claw.{side}.{front}.{claw_index}",
                    (x * 1.16 + claw_index * 0.10, y - 0.46, 0.38),
                    0.045, 0.008, 0.30, mats["horn"],
                    rot=(math.radians(72), 0, 0), vertices=6)
                parent_to_bone(claw, rig, "body")

    build_dragon_animations(rig)
    return rig


def build_dragon_animations(rig):
    idle = new_action(rig, "idle")
    for frame, breath in ((1, 0.0), (24, 1.0), (48, 0.0)):
        key_bone(rig, "root", frame, loc=(0, 0, 0.025 * breath))
        key_bone(rig, "body", frame, scale=(1 + 0.018 * breath, 1 + 0.012 * breath, 1 + 0.025 * breath))
        key_bone(rig, "head", frame, rot=(math.radians(-2 + breath * 4), 0, math.radians(1 - breath * 2)))
        key_bone(rig, "jaw", frame, rot=(math.radians(2 + breath * 3), 0, 0))
        key_bone(rig, "wing.L", frame, rot=(math.radians(2 - breath * 5), math.radians(-2), math.radians(1 + breath * 2)))
        key_bone(rig, "wing.R", frame, rot=(math.radians(2 - breath * 5), math.radians(2), math.radians(-1 - breath * 2)))
        key_bone(rig, "tail.01", frame, rot=(0, math.radians(-4 + breath * 8), 0))
        key_bone(rig, "tail.02", frame, rot=(0, math.radians(7 - breath * 14), 0))
    finish_action(idle, 1, 48)

    roar = new_action(rig, "roar")
    for frame, lift, spread, jaw in ((1, 0, 0, 0), (12, 12, 22, 26), (32, 8, 28, 34), (48, 0, 0, 0)):
        key_bone(rig, "root", frame, loc=(0, 0, 0.08 * (spread / 28.0)))
        key_bone(rig, "neck", frame, rot=(math.radians(lift * 0.45), 0, 0))
        key_bone(rig, "head", frame, rot=(math.radians(lift), 0, 0))
        key_bone(rig, "jaw", frame, rot=(math.radians(jaw), 0, 0))
        key_bone(rig, "wing.L", frame, rot=(0, math.radians(-spread), math.radians(spread * 0.35)))
        key_bone(rig, "wing.R", frame, rot=(0, math.radians(spread), math.radians(-spread * 0.35)))
    finish_action(roar, 1, 48)

    attack = new_action(rig, "attack")
    for frame, thrust, jaw, wings in ((1, 0, 0, 0), (8, 0.08, 18, 8), (17, -0.34, 30, 15), (26, -0.42, 6, 6), (38, 0, 0, 0)):
        key_bone(rig, "body", frame, rot=(math.radians(-thrust * 8), 0, 0))
        key_bone(rig, "neck", frame, loc=(0, thrust * 0.42, 0), rot=(math.radians(-thrust * 18), 0, 0))
        key_bone(rig, "head", frame, loc=(0, thrust, 0), rot=(math.radians(-thrust * 20), 0, 0))
        key_bone(rig, "jaw", frame, rot=(math.radians(jaw), 0, 0))
        key_bone(rig, "wing.L", frame, rot=(0, math.radians(-wings), 0))
        key_bone(rig, "wing.R", frame, rot=(0, math.radians(wings), 0))
    finish_action(attack, 1, 38)

    hurt = new_action(rig, "hurt")
    for frame, recoil in ((1, 0), (6, 1), (13, -0.3), (20, 0)):
        key_bone(rig, "root", frame, loc=(0, 0.10 * recoil, 0), rot=(0, 0, math.radians(7 * recoil)))
        key_bone(rig, "head", frame, rot=(math.radians(9 * recoil), 0, math.radians(-5 * recoil)))
        key_bone(rig, "wing.L", frame, rot=(0, math.radians(8 * recoil), 0))
        key_bone(rig, "wing.R", frame, rot=(0, math.radians(-8 * recoil), 0))
    finish_action(hurt, 1, 20)

    death = new_action(rig, "death")
    for frame, fall in ((1, 0), (12, 0.18), (30, 0.72), (52, 1.0)):
        key_bone(rig, "root", frame, loc=(0.20 * fall, 0.10 * fall, -0.48 * fall), rot=(math.radians(8 * fall), math.radians(10 * fall), math.radians(76 * fall)))
        key_bone(rig, "head", frame, rot=(math.radians(22 * fall), 0, math.radians(-12 * fall)))
        key_bone(rig, "jaw", frame, rot=(math.radians(18 * fall), 0, 0))
        key_bone(rig, "wing.L", frame, rot=(math.radians(18 * fall), math.radians(42 * fall), math.radians(22 * fall)))
        key_bone(rig, "wing.R", frame, rot=(math.radians(18 * fall), math.radians(-42 * fall), math.radians(-22 * fall)))
    finish_action(death, 1, 52)
    rig.animation_data.action = idle


def egg_materials():
    return {
        "shell": material("Egg Deep Violet", (0.075, 0.02, 0.31), metallic=0.10, roughness=0.48),
        "plate": material("Egg Royal Purple", (0.20, 0.055, 0.52), metallic=0.14, roughness=0.42),
        "gold": material("Egg Ancient Gold", (0.74, 0.45, 0.10), metallic=0.78, roughness=0.30),
        "gem": material("Egg Blue Gem", (0.20, 0.48, 1.0), metallic=0.20, roughness=0.20, emission=0.75),
        "crack": material("Egg Arcane Crack", (0.78, 0.18, 1.0), roughness=0.18, emission=2.6),
    }


def build_egg_model():
    reset_scene()
    mats = egg_materials()
    bones = [
        ("root", (0, 0, 0), (0, 0, 0.8), None),
        ("shell", (0, 0, 0.42), (0, 0, 1.45), "root"),
        ("shard.L", (-0.20, 0, 1.35), (-0.65, 0, 1.78), "shell"),
        ("shard.R", (0.20, 0, 1.35), (0.65, 0, 1.78), "shell"),
        ("shard.Top", (0, 0, 1.50), (0, 0, 2.0), "shell"),
    ]
    rig = create_rig("DragonEgg", bones)
    shell = ico("EggShell", (0, 0, 1.0), (0.78, 0.72, 1.02), mats["shell"], 3)
    parent_to_bone(shell, rig, "shell")

    # Overlapping faceted plates create the authored scale-shell silhouette.
    for index in range(12):
        angle = TAU * index / 12.0
        x = math.cos(angle) * 0.62
        y = math.sin(angle) * 0.56
        plate = ico(
            f"ShellPlate{index+1}", (x, y, 0.82 + 0.16 * (index % 3)),
            (0.24, 0.15, 0.38), mats["plate"], 1)
        plate.rotation_euler.z = angle + math.pi * 0.5
        parent_to_bone(plate, rig, "shell")

    top_left = cone("TopShard.L", (-0.24, 0, 1.76), 0.25, 0.025, 0.72, mats["plate"], rot=(0, math.radians(-18), 0), vertices=6)
    top_right = cone("TopShard.R", (0.24, 0, 1.76), 0.25, 0.025, 0.72, mats["plate"], rot=(0, math.radians(18), 0), vertices=6)
    top = cone("TopShard", (0, 0.08, 1.88), 0.27, 0.025, 0.78, mats["plate"], vertices=6)
    parent_to_bone(top_left, rig, "shard.L")
    parent_to_bone(top_right, rig, "shard.R")
    parent_to_bone(top, rig, "shard.Top")

    torus("GoldenCradle", (0, 0, 0.40), 0.72, 0.10, mats["gold"])
    for index in range(8):
        angle = TAU * index / 8.0
        x = math.cos(angle) * 0.69
        y = math.sin(angle) * 0.69
        claw = cone(
            f"CradleClaw{index+1}", (x, y, 0.56), 0.10, 0.025, 0.55,
            mats["gold"], rot=(math.radians(10 * math.sin(angle)), math.radians(-10 * math.cos(angle)), 0), vertices=6)
        gem = diamond(
            f"CradleGem{index+1}", (x * 1.05, y * 1.05, 0.43),
            (0.10, 0.06, 0.15), mats["gem"], rot=(0, 0, angle))
        parent_to_bone(claw, rig, "root")
        parent_to_bone(gem, rig, "root")

    front_gem = diamond("RoyalFrontGem", (0, -0.75, 1.18), (0.20, 0.08, 0.31), mats["gem"])
    front_frame = diamond_frame(
        "RoyalFrontFrame", (0, -0.71, 1.18),
        (0.36, 0.46), (0.23, 0.31), mats["gold"])
    parent_to_bone(front_gem, rig, "shell")
    parent_to_bone(front_frame, rig, "shell")

    crack_paths = [
        [(0.02, -0.716, 1.67), (-0.10, -0.724, 1.48), (0.06, -0.732, 1.32), (-0.04, -0.735, 1.12)],
        [(0.06, -0.710, 1.34), (0.26, -0.680, 1.23), (0.34, -0.620, 1.05)],
        [(-0.04, -0.705, 1.12), (-0.26, -0.655, 0.98), (-0.34, -0.580, 0.79)],
    ]
    for index, path in enumerate(crack_paths):
        crack = curve_line(f"ArcaneCrack{index+1}", path, 0.018, mats["crack"])
        parent_to_bone(crack, rig, "shell")

    build_egg_animations(rig)
    return rig


def build_egg_animations(rig):
    idle = new_action(rig, "idle")
    for frame, pulse in ((1, 0.0), (18, 1.0), (36, 0.0)):
        key_bone(rig, "root", frame, loc=(0, 0, 0.025 * pulse), rot=(0, math.radians(-1.5 + pulse * 3), math.radians(-1 + pulse * 2)))
        key_bone(rig, "shell", frame, scale=(1 + 0.015 * pulse, 1 + 0.015 * pulse, 1 + 0.022 * pulse))
        key_bone(rig, "shard.L", frame, rot=(0, math.radians(-1.5 * pulse), 0))
        key_bone(rig, "shard.R", frame, rot=(0, math.radians(1.5 * pulse), 0))
    finish_action(idle, 1, 36)

    hatch = new_action(rig, "hatch")
    for frame, force in ((1, 0.0), (10, -0.08), (18, 0.18), (28, 0.72), (38, 1.0)):
        compression = 1.0 - 0.08 * max(0.0, -force)
        key_bone(rig, "root", frame, loc=(0, 0, 0.10 * max(force, 0.0)), scale=(compression, compression, 1.0 + 0.10 * max(force, 0.0)))
        key_bone(rig, "shell", frame, scale=(1 + 0.12 * max(force, 0.0), 1 + 0.12 * max(force, 0.0), 1 - 0.10 * max(force, 0.0)))
        key_bone(rig, "shard.L", frame, loc=(-0.65 * max(force, 0.0), 0.10 * force, 0.42 * max(force, 0.0)), rot=(math.radians(-28 * force), math.radians(-40 * force), math.radians(35 * force)))
        key_bone(rig, "shard.R", frame, loc=(0.65 * max(force, 0.0), 0.10 * force, 0.42 * max(force, 0.0)), rot=(math.radians(-28 * force), math.radians(40 * force), math.radians(-35 * force)))
        key_bone(rig, "shard.Top", frame, loc=(0, 0.20 * force, 0.95 * max(force, 0.0)), rot=(math.radians(-65 * force), 0, math.radians(28 * force)))
    finish_action(hatch, 1, 38)
    rig.animation_data.action = idle


def point_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def setup_preview(path, target, camera_location, radius):
    ground_mat = material("PREVIEW Ground", (0.025, 0.045, 0.075), roughness=0.78)
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=radius, depth=0.10, location=(0, 0, 0))
    ground = bpy.context.object
    ground.name = "PREVIEW_ONLY_Ground"
    ground.data.materials.append(ground_mat)

    lights = [
        ((-4.0, -5.0, 6.0), 1000, (0.55, 0.68, 1.0), 4.0),
        ((4.0, -1.0, 4.5), 850, (0.92, 0.40, 1.0), 3.0),
        ((0, 4.0, 5.0), 1100, (1.0, 0.62, 0.25), 2.5),
    ]
    for index, (location, energy, color, size) in enumerate(lights):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = f"PREVIEW_ONLY_Light{index+1}"
        light.data.energy = energy
        light.data.color = color
        light.data.shape = "DISK"
        light.data.size = size
        point_at(light, target)

    bpy.ops.object.camera_add(location=camera_location)
    camera = bpy.context.object
    camera.name = "PREVIEW_ONLY_Camera"
    camera.data.lens = 62
    point_at(camera, target)
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.fps = 30
    scene.render.resolution_x = 720
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    scene.render.filepath = str(path)
    scene.view_settings.look = "AgX - Medium High Contrast"


def export_asset(rig, blend_path, glb_path, preview_path, target, camera_location, radius):
    setup_preview(preview_path, target, camera_location, radius)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    bpy.ops.render.render(write_still=True)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for obj in bpy.data.objects:
        if obj.type in {"MESH", "CURVE"} and not obj.name.startswith("PREVIEW_ONLY_"):
            obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path), export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="ACTIONS",
        export_force_sampling=True, export_frame_step=1,
        export_skins=True, export_def_bones=True, export_materials="EXPORT",
        export_cameras=False, export_lights=False, export_yup=True,
    )


def main():
    dragon = build_dragon_model()
    export_asset(
        dragon, DRAGON_BLEND, DRAGON_GLB, DRAGON_PREVIEW,
        (0, 0.1, 1.1), (5.0, -7.6, 4.8), 3.2)
    egg = build_egg_model()
    export_asset(
        egg, EGG_BLEND, EGG_GLB, EGG_PREVIEW,
        (0, 0, 1.0), (3.7, -6.0, 3.3), 2.0)
    print("DRAGON_FAMILY_BUILD_OK", DRAGON_GLB, EGG_GLB)


TAU = math.tau

if __name__ == "__main__":
    main()
