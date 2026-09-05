"""Cartoon ("chibi") proportion warp shared by the character builders.

Mobile brawlers read at a glance because heads are huge, legs are short and
hands and feet are oversized. Instead of re-authoring every armour piece, the
builders create the character with the original heroic proportions and then
run this warp: a piecewise vertical remap plus a radial (x, y) scale that
depends on height, and optional per-part scaling for hands and feet.

Bones and vertices are warped together so every authored animation keeps
working: rotations are unchanged, only rest lengths move.
"""

import bpy
from mathutils import Vector


def _smoothstep(edge0, edge1, value):
    if edge1 <= edge0:
        return 1.0 if value >= edge1 else 0.0
    t = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


class Warp:
    """bands: list of (z_start, z_end, z_scale, xy_scale) covering the model.

    Vertical positions are remapped cumulatively so bands stay contiguous; the
    radial scale blends smoothly across band borders (`blend` units).
    """

    def __init__(self, bands, blend=0.12):
        self.bands = sorted(bands, key=lambda band: band[0])
        self.blend = blend
        self.starts = []
        cursor = self.bands[0][0]
        for z0, z1, zs, _xy in self.bands:
            self.starts.append(cursor)
            cursor += (z1 - z0) * zs

    def map_z(self, z):
        if z <= self.bands[0][0]:
            return self.starts[0] + (z - self.bands[0][0]) * self.bands[0][2]
        for (z0, z1, zs, _xy), start in zip(self.bands, self.starts):
            if z <= z1:
                return start + (z - z0) * zs
        z0, z1, zs, _xy = self.bands[-1]
        return self.starts[-1] + (z - z0) * zs

    def xy_scale(self, z):
        value = self.bands[0][3]
        for index in range(1, len(self.bands)):
            border = self.bands[index][0]
            weight = _smoothstep(border - self.blend, border + self.blend, z)
            value = value + (self.bands[index][3] - value) * weight
        return value

    def point(self, world):
        z = world.z
        scale = self.xy_scale(z)
        return Vector((world.x * scale, world.y * scale, self.map_z(z)))


def warp_character(rig, meshes, warp, part_scales=None, axis_x=0.0, axis_y=0.0):
    """Warp rig bones and mesh vertices in world space.

    part_scales: {name_substring: (sx, sy, sz)} applied around each matching
    object's own centre after the global warp (big hands, big boots).
    """
    part_scales = part_scales or {}
    bpy.context.view_layer.update()
    # 1. Target world positions for every vertex before bones move.
    targets = {}
    for obj in meshes:
        matrix = obj.matrix_world.copy()
        if obj.type == "CURVE":
            targets[obj.name] = [
                warp.point(matrix @ point.co.xyz) for spline in obj.data.splines
                for point in _curve_points(spline)]
        else:
            targets[obj.name] = [warp.point(matrix @ v.co) for v in obj.data.vertices]
    # 2. Warp the armature rest pose.
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for bone in rig.data.edit_bones:
        head = warp.point(Vector(bone.head))
        tail = warp.point(Vector(bone.tail))
        if (tail - head).length < 0.02:
            tail = head + Vector((0, 0, 0.05))
        bone.head = head
        bone.tail = tail
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()
    # 3. Write warped positions back through the (possibly changed) matrices.
    for obj in meshes:
        inverse = obj.matrix_world.inverted()
        if obj.type == "CURVE":
            points = [point for spline in obj.data.splines for point in _curve_points(spline)]
            for point, world in zip(points, targets[obj.name]):
                local = inverse @ world
                if hasattr(point, "handle_left"):
                    point.co = local
                    point.handle_left = local
                    point.handle_right = local
                else:
                    point.co = (local.x, local.y, local.z, 1.0)
            continue
        for v, world in zip(obj.data.vertices, targets[obj.name]):
            v.co = inverse @ world
        obj.data.update()
    # 4. Per-part emphasis (hands, feet) around each object's centre.
    for obj in meshes:
        if obj.type != "MESH":
            continue
        for key, scale in part_scales.items():
            if key in obj.name:
                _scale_about_center(obj, scale)
                break
    bpy.context.view_layer.update()


def _curve_points(spline):
    return list(spline.bezier_points) if spline.type == "BEZIER" else list(spline.points)


def _scale_about_center(obj, scale):
    verts = obj.data.vertices
    if not verts:
        return
    center = Vector((0, 0, 0))
    for v in verts:
        center += v.co
    center /= len(verts)
    for v in verts:
        offset = v.co - center
        v.co = center + Vector((offset.x * scale[0], offset.y * scale[1], offset.z * scale[2]))
    obj.data.update()
