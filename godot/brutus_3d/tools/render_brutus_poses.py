"""Render representative poses from the generated Brutus source file."""

from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
rig = bpy.data.objects["BrutusRig"]
rig.animation_data_create()

POSES = (
    ("walk", 9, "walk"),
    ("run", 1, "run_contact"),
    ("run", 10, "run_flight"),
    ("attack", 9, "attack_impact"),
    ("attack_alt", 9, "attack_alt_impact"),
    ("q", 13, "q_drive"),
    ("ultimate", 11, "throw_coil"),
    ("ultimate", 18, "throw_release"),
    ("ultimate", 45, "throw_catch"),
)

for action_name, frame, output_name in POSES:
    rig.animation_data.action = bpy.data.actions[action_name]
    bpy.context.scene.frame_set(frame)
    bpy.context.scene.render.filepath = str(ROOT / "assets" / "brutus" / f"brutus_{output_name}_pose.png")
    bpy.ops.render.render(write_still=True)

print("BRUTUS_POSE_RENDERS_OK")
