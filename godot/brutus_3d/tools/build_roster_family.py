"""Build the final rigged Alpha roster models and team minions.

Uses the same authored low-poly vocabulary as Brutus and the dragon family.
No external mesh, texture, material or animation is consumed.
"""

from pathlib import Path
import math
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

from build_dragon_family import (
    reset_scene, material, ico, uv_sphere, cone, cylinder, torus, box, mesh_object,
    diamond, curve_line, create_rig, parent_to_bone, new_action, key_bone,
    finish_action, export_asset,
)


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "roster"
ASSET_DIR.mkdir(parents=True, exist_ok=True)


def roster_materials(hero):
    common = {
        "skin": material(f"{hero} Warm Skin", (0.56, 0.27, 0.13), roughness=0.72),
        "gold": material(f"{hero} Antique Gold", (0.63, 0.31, 0.055), metallic=0.72, roughness=0.34),
        "leather": material(f"{hero} Leather", (0.20, 0.075, 0.025), roughness=0.80),
        "steel": material(f"{hero} Steel", (0.34, 0.42, 0.50), metallic=0.76, roughness=0.28),
    }
    if hero == "Lyra":
        common.update({
            "primary": material("Lyra Forest Green", (0.045, 0.23, 0.055), roughness=0.62),
            "secondary": material("Lyra Leaf Green", (0.12, 0.42, 0.10), roughness=0.58),
            "glow": material("Lyra Emerald", (0.12, 0.85, 0.24), emission=1.3, roughness=0.25),
        })
    elif hero == "Nix":
        common.update({
            "primary": material("Nix Void Cloth", (0.018, 0.012, 0.035), roughness=0.72),
            "secondary": material("Nix Royal Purple", (0.17, 0.025, 0.34), roughness=0.52),
            "glow": material("Nix Void Crystal", (0.52, 0.08, 1.0), emission=2.2, roughness=0.18),
        })
    else:
        common.update({
            "primary": material("Sol Ivory", (0.50, 0.38, 0.20), roughness=0.65),
            "secondary": material("Sol Sun Gold", (0.92, 0.52, 0.055), metallic=0.55, roughness=0.31),
            "glow": material("Sol Radiance", (1.0, 0.58, 0.06), emission=2.6, roughness=0.16),
        })
    return common


def human_rig(name):
    return create_rig(name, [
        ("root", (0, 0, 0.04), (0, 0, 0.42), None),
        ("hips", (0, 0, 0.48), (0, 0, 0.90), "root"),
        ("torso", (0, 0, 0.86), (0, 0, 1.55), "hips"),
        ("head", (0, 0, 1.50), (0, 0, 2.18), "torso"),
        ("arm.L", (-0.34, 0, 1.43), (-0.48, 0, 0.78), "torso"),
        ("arm.R", (0.34, 0, 1.43), (0.48, 0, 0.78), "torso"),
        ("leg.L", (-0.20, 0, 0.76), (-0.20, 0, 0.08), "hips"),
        ("leg.R", (0.20, 0, 0.76), (0.20, 0, 0.08), "hips"),
    ])


def add_human_limbs(rig, mats, slender=False):
    arm_radius = 0.105 if slender else 0.125
    leg_radius = 0.14 if slender else 0.16
    for side, x in (("L", -0.43), ("R", 0.43)):
        arm = cylinder(f"Arm.{side}", (x, -0.01, 1.10), arm_radius, 0.70, mats["primary"], vertices=8)
        glove = ico(f"Hand.{side}", (x, -0.03, 0.72), (0.13, 0.12, 0.14), mats["leather"], 1)
        parent_to_bone(arm, rig, f"arm.{side}")
        parent_to_bone(glove, rig, f"arm.{side}")
    for side, x in (("L", -0.20), ("R", 0.20)):
        leg = cylinder(f"Leg.{side}", (x, 0, 0.43), leg_radius, 0.64, mats["leather"], vertices=8)
        boot = ico(f"Boot.{side}", (x, -0.12, 0.12), (0.18, 0.27, 0.13), mats["leather"], 1)
        guard = diamond(f"KneeGuard.{side}", (x, -0.18, 0.46), (0.15, 0.055, 0.18), mats["gold"])
        parent_to_bone(leg, rig, f"leg.{side}")
        parent_to_bone(boot, rig, f"leg.{side}")
        parent_to_bone(guard, rig, f"leg.{side}")


def add_hero_animations(rig, hero):
    idle = new_action(rig, "idle")
    for frame, pulse in ((1, 0.0), (20, 1.0), (40, 0.0)):
        key_bone(rig, "root", frame, loc=(0, 0, 0.025 * pulse))
        key_bone(rig, "torso", frame, rot=(math.radians(1.5 * pulse), 0, math.radians(-1.5 + 3 * pulse)))
        key_bone(rig, "head", frame, rot=(math.radians(-1 + 2 * pulse), 0, math.radians(1 - 2 * pulse)))
        key_bone(rig, "arm.L", frame, rot=(math.radians(-3 + pulse * 3), 0, math.radians(-5)))
        key_bone(rig, "arm.R", frame, rot=(math.radians(3 - pulse * 3), 0, math.radians(5)))
    finish_action(idle, 1, 40)

    run = new_action(rig, "run")
    for frame, phase in ((1, 0), (8, 1), (16, 0), (24, -1), (32, 0)):
        key_bone(rig, "root", frame, loc=(0, -0.04 * abs(phase), 0.055 * abs(phase)), rot=(math.radians(7), 0, 0))
        key_bone(rig, "torso", frame, rot=(math.radians(-5), 0, math.radians(4 * phase)))
        key_bone(rig, "arm.L", frame, rot=(math.radians(-34 * phase), 0, math.radians(-6)))
        key_bone(rig, "arm.R", frame, rot=(math.radians(34 * phase), 0, math.radians(6)))
        key_bone(rig, "leg.L", frame, rot=(math.radians(38 * phase), 0, 0))
        key_bone(rig, "leg.R", frame, rot=(math.radians(-38 * phase), 0, 0))
    finish_action(run, 1, 32)

    attack = new_action(rig, "attack")
    for frame, force in ((1, 0.0), (8, -0.35), (16, 1.0), (26, 0.0)):
        key_bone(rig, "root", frame, loc=(0, -0.12 * max(force, 0), 0))
        key_bone(rig, "torso", frame, rot=(math.radians(-8 * max(force, 0)), 0, math.radians(18 * force)))
        if hero == "Lyra":
            key_bone(rig, "arm.L", frame, rot=(math.radians(-70 * max(force, 0)), math.radians(-12), math.radians(-42)))
            key_bone(rig, "arm.R", frame, rot=(math.radians(-78 * max(force, 0)), math.radians(15), math.radians(32 + 38 * force)))
        elif hero == "Nix":
            key_bone(rig, "arm.L", frame, rot=(math.radians(-105 * force), 0, math.radians(-24)))
            key_bone(rig, "arm.R", frame, rot=(math.radians(92 * force), 0, math.radians(24)))
        else:
            key_bone(rig, "arm.L", frame, rot=(math.radians(-18), 0, math.radians(-16)))
            key_bone(rig, "arm.R", frame, rot=(math.radians(-115 * max(force, 0)), 0, math.radians(16)))
    finish_action(attack, 1, 26)

    q = new_action(rig, "q")
    ultimate = new_action(rig, "ultimate")
    for action, power, end in ((q, 1.0, 34), (ultimate, 1.5, 52)):
        rig.animation_data.action = action
        for frame, force in ((1, 0.0), (10, -0.18), (22, power), (end, 0.0)):
            key_bone(rig, "root", frame, loc=(0, -0.12 * max(force, 0), 0.10 * max(force, 0)))
            key_bone(rig, "torso", frame, rot=(math.radians(-7 * force), 0, math.radians(14 * force)))
            key_bone(rig, "head", frame, rot=(math.radians(8 * force), 0, 0))
            key_bone(rig, "arm.L", frame, rot=(math.radians(-65 * force), math.radians(-20 * force), math.radians(-30)))
            key_bone(rig, "arm.R", frame, rot=(math.radians(-105 * force), math.radians(18 * force), math.radians(30)))
        finish_action(action, 1, end)

    hurt = new_action(rig, "hurt")
    for frame, recoil in ((1, 0), (6, 1), (13, -0.2), (20, 0)):
        key_bone(rig, "root", frame, loc=(0, 0.10 * recoil, 0), rot=(0, 0, math.radians(8 * recoil)))
        key_bone(rig, "torso", frame, rot=(math.radians(13 * recoil), 0, math.radians(-8 * recoil)))
        key_bone(rig, "head", frame, rot=(math.radians(-8 * recoil), 0, 0))
    finish_action(hurt, 1, 20)

    death = new_action(rig, "death")
    for frame, fall in ((1, 0), (12, 0.2), (28, 0.75), (46, 1.0)):
        key_bone(rig, "root", frame, loc=(0.18 * fall, 0.08 * fall, -0.36 * fall), rot=(math.radians(8 * fall), 0, math.radians(82 * fall)))
        key_bone(rig, "torso", frame, rot=(math.radians(16 * fall), 0, 0))
        key_bone(rig, "head", frame, rot=(math.radians(-20 * fall), 0, math.radians(10 * fall)))
        key_bone(rig, "arm.L", frame, rot=(math.radians(-22 * fall), 0, math.radians(-35 * fall)))
        key_bone(rig, "arm.R", frame, rot=(math.radians(18 * fall), 0, math.radians(30 * fall)))
    finish_action(death, 1, 46)
    rig.animation_data.action = idle


def add_cape(rig, name, mat, ragged=False):
    bottom = [(-0.48, 0.22, 0.48), (0.48, 0.22, 0.48)]
    if ragged:
        bottom = [(-0.48, 0.24, 0.52), (0.0, 0.32, 0.34), (0.48, 0.24, 0.58)]
        verts = [(-0.38, 0.17, 1.48), (0.38, 0.17, 1.48), *bottom]
        faces = [(0, 1, 3), (0, 3, 2), (1, 4, 3)]
    else:
        verts = [(-0.38, 0.17, 1.48), (0.38, 0.17, 1.48), bottom[1], bottom[0]]
        faces = [(0, 1, 2), (0, 2, 3)]
    cape = mesh_object(name, verts, faces, mat, bevel=0.025, solidify=0.035)
    parent_to_bone(cape, rig, "torso")


def build_lyra():
    reset_scene()
    mats = roster_materials("Lyra")
    rig = human_rig("Lyra")
    add_cape(rig, "LyraCape", mats["primary"])
    torso = ico("LyraTorso", (0, 0, 1.12), (0.36, 0.28, 0.50), mats["primary"], 2)
    belt = box("LyraBelt", (0, -0.01, 0.82), (0.38, 0.19, 0.09), mats["leather"], bevel=0.025)
    head = ico("LyraHead", (0, -0.03, 1.77), (0.27, 0.25, 0.29), mats["skin"], 2)
    hood = ico("LyraHood", (0, 0.04, 1.84), (0.34, 0.30, 0.37), mats["secondary"], 2)
    face = uv_sphere("LyraFace", (0, -0.255, 1.76), (0.22, 0.075, 0.24), mats["skin"], 16, 8)
    for obj, bone in ((torso, "torso"), (belt, "hips"), (head, "head"), (hood, "head"), (face, "head")):
        parent_to_bone(obj, rig, bone)
    for side in (-1, 1):
        ear = cone(f"LyraEar.{side}", (0.27 * side, -0.10, 1.78), 0.09, 0.01, 0.34, mats["skin"], rot=(0, math.radians(78), math.radians(90 * side)), vertices=6)
        shoulder = ico(f"LyraShoulder.{side}", (0.40 * side, 0, 1.40), (0.20, 0.24, 0.16), mats["gold"], 1)
        parent_to_bone(ear, rig, "head")
        parent_to_bone(shoulder, rig, "torso")
        eye = ico(f"LyraEye.{side}", (0.080 * side, -0.326, 1.80), (0.034, 0.018, 0.050), mats["glow"], 1)
        parent_to_bone(eye, rig, "head")
    for index, x in enumerate((-0.10, 0.0, 0.10)):
        bang = ico(f"LyraHair{index+1}", (x, -0.305, 1.94), (0.075, 0.028, 0.105), mats["gold"], 1)
        parent_to_bone(bang, rig, "head")
    add_human_limbs(rig, mats, slender=True)
    bow = curve_line("LyraBow", [(-0.72, -0.16, 1.42), (-0.92, -0.20, 1.05), (-0.74, -0.18, 0.66)], 0.055, mats["gold"])
    string = curve_line("LyraBowString", [(-0.72, -0.16, 1.42), (-0.62, -0.25, 1.04), (-0.74, -0.18, 0.66)], 0.012, mats["steel"])
    arrow = cylinder("LyraArrow", (0.30, -0.33, 0.95), 0.022, 0.94, mats["leather"], rot=(math.radians(90), 0, 0), vertices=6)
    arrowhead = cone("LyraArrowHead", (0.30, -0.82, 0.95), 0.07, 0.01, 0.22, mats["steel"], rot=(math.radians(90), 0, 0), vertices=6)
    for obj in (bow, string): parent_to_bone(obj, rig, "arm.L")
    for obj in (arrow, arrowhead): parent_to_bone(obj, rig, "arm.R")
    quiver = cylinder("LyraQuiver", (0.30, 0.25, 1.17), 0.12, 0.72, mats["leather"], rot=(0, math.radians(18), 0), vertices=8)
    parent_to_bone(quiver, rig, "torso")
    for index in range(3):
        shaft = cylinder(f"LyraQuiverArrow{index+1}", (0.23 + index * 0.07, 0.25, 1.59), 0.015, 0.58, mats["steel"], rot=(0, math.radians(18), 0), vertices=6)
        parent_to_bone(shaft, rig, "torso")
    add_hero_animations(rig, "Lyra")
    return rig


def build_nix():
    reset_scene()
    mats = roster_materials("Nix")
    rig = human_rig("Nix")
    add_cape(rig, "NixTornCape", mats["secondary"], True)
    torso = ico("NixTorso", (0, 0, 1.12), (0.38, 0.27, 0.50), mats["primary"], 2)
    hood = ico("NixHood", (0, 0.03, 1.82), (0.36, 0.31, 0.39), mats["secondary"], 2)
    void_face = ico("NixVoidFace", (0, -0.23, 1.76), (0.22, 0.075, 0.23), mats["primary"], 2)
    eye = diamond("NixEye", (0, -0.32, 1.80), (0.13, 0.03, 0.065), mats["glow"])
    belt = box("NixBelt", (0, 0, 0.82), (0.40, 0.19, 0.10), mats["gold"], bevel=0.025)
    for obj, bone in ((torso, "torso"), (hood, "head"), (void_face, "head"), (eye, "head"), (belt, "hips")):
        parent_to_bone(obj, rig, bone)
    for side in (-1, 1):
        shoulder = diamond(f"NixShoulder.{side}", (0.42 * side, -0.02, 1.43), (0.23, 0.18, 0.22), mats["secondary"])
        parent_to_bone(shoulder, rig, "torso")
    add_human_limbs(rig, mats, slender=True)
    for side, bone in ((-1, "arm.L"), (1, "arm.R")):
        blade = diamond(f"NixDagger.{side}", (0.44 * side, -0.25, 0.57), (0.15, 0.10, 0.47), mats["glow"], rot=(math.radians(-24), 0, math.radians(12 * side)))
        hilt = box(f"NixHilt.{side}", (0.44 * side, -0.04, 0.75), (0.22, 0.07, 0.06), mats["gold"], bevel=0.02)
        parent_to_bone(blade, rig, bone)
        parent_to_bone(hilt, rig, bone)
    add_hero_animations(rig, "Nix")
    return rig


def build_sol():
    reset_scene()
    mats = roster_materials("Sol")
    rig = human_rig("Sol")
    robe = cone("SolRobe", (0, 0.04, 0.86), 0.52, 0.29, 1.28, mats["primary"], vertices=10)
    mantle = ico("SolMantle", (0, 0, 1.39), (0.50, 0.29, 0.22), mats["secondary"], 2)
    hood = ico("SolHood", (0, 0.03, 1.84), (0.37, 0.32, 0.40), mats["secondary"], 2)
    face = uv_sphere("SolFace", (0, -0.255, 1.76), (0.23, 0.075, 0.24), mats["skin"], 16, 8)
    chest = diamond("SolChestSun", (0, -0.31, 1.38), (0.15, 0.04, 0.18), mats["glow"])
    for obj, bone in ((robe, "hips"), (mantle, "torso"), (hood, "head"), (face, "head"), (chest, "torso")):
        parent_to_bone(obj, rig, bone)
    for side in (-1, 1):
        eye = ico(f"SolEye.{side}", (0.080 * side, -0.326, 1.80), (0.034, 0.018, 0.050), mats["leather"], 1)
        parent_to_bone(eye, rig, "head")
    for index, x in enumerate((-0.10, 0.0, 0.10)):
        bang = ico(f"SolHair{index+1}", (x, -0.305, 1.94), (0.075, 0.028, 0.105), mats["primary"], 1)
        parent_to_bone(bang, rig, "head")
    add_human_limbs(rig, mats, slender=False)
    halo = torus("SolHalo", (0, 0.03, 2.30), 0.35, 0.035, mats["glow"])
    halo.rotation_euler.x = math.radians(12)
    parent_to_bone(halo, rig, "head")
    staff = cylinder("SolStaff", (-0.47, -0.02, 1.02), 0.045, 1.70, mats["gold"], vertices=8)
    staff_orb = ico("SolStaffOrb", (-0.47, -0.02, 1.91), (0.18, 0.18, 0.18), mats["glow"], 2)
    hand_orb = ico("SolHandOrb", (0.47, -0.20, 0.74), (0.13, 0.13, 0.13), mats["glow"], 2)
    rays = []
    for index in range(6):
        angle = math.tau * index / 6
        ray = cone(f"SolRay{index+1}", (-0.47 + math.cos(angle) * 0.28, -0.02, 1.91 + math.sin(angle) * 0.28), 0.055, 0.01, 0.25, mats["glow"], rot=(0, math.radians(90), angle), vertices=5)
        rays.append(ray)
    for obj in (staff, staff_orb, *rays): parent_to_bone(obj, rig, "arm.L")
    parent_to_bone(hand_orb, rig, "arm.R")
    add_hero_animations(rig, "Sol")
    return rig


def minion_materials(team):
    blue = team == "blue"
    dark = material(f"Minion {team} Dark", (0.015, 0.07, 0.18) if blue else (0.19, 0.012, 0.02), roughness=0.64)
    return {
        "primary": material(f"Minion {team} Primary", (0.025, 0.28, 0.62) if blue else (0.56, 0.025, 0.055), metallic=0.18, roughness=0.48),
        "dark": dark,
        "leather": dark,
        "steel": material(f"Minion {team} Steel", (0.40, 0.48, 0.55), metallic=0.78, roughness=0.28),
        "gold": material(f"Minion {team} Gold", (0.62, 0.34, 0.06), metallic=0.68, roughness=0.34),
        "skin": material(f"Minion {team} Skin", (0.48, 0.22, 0.10), roughness=0.76),
        "glow": material(f"Minion {team} Glow", (0.12, 0.72, 1.0) if blue else (1.0, 0.16, 0.20), emission=1.5),
    }


def build_minion(team):
    reset_scene()
    mats = minion_materials(team)
    rig = human_rig(f"Minion{team.capitalize()}")
    torso = ico("MinionTorso", (0, 0, 1.04), (0.40, 0.32, 0.47), mats["dark"], 2)
    helmet = ico("MinionHelmet", (0, 0.02, 1.72), (0.34, 0.30, 0.31), mats["primary"], 2)
    face = ico("MinionFace", (0, -0.24, 1.64), (0.23, 0.08, 0.20), mats["skin"], 1)
    visor = box("MinionVisor", (0, -0.32, 1.72), (0.30, 0.05, 0.055), mats["steel"], bevel=0.02)
    crest = cone("MinionCrest", (0, 0.02, 2.03), 0.15, 0.015, 0.55, mats["primary"], vertices=6)
    belt = box("MinionBelt", (0, 0, 0.79), (0.40, 0.20, 0.09), mats["gold"], bevel=0.025)
    for obj, bone in ((torso, "torso"), (helmet, "head"), (face, "head"), (visor, "head"), (crest, "head"), (belt, "hips")):
        parent_to_bone(obj, rig, bone)
    add_human_limbs(rig, mats, slender=False)
    shield = ico("MinionShield", (-0.47, -0.21, 0.91), (0.34, 0.10, 0.43), mats["primary"], 1)
    shield_gem = diamond("MinionShieldGem", (-0.47, -0.32, 0.91), (0.12, 0.03, 0.16), mats["glow"])
    sword = diamond("MinionSword", (0.47, -0.20, 0.56), (0.11, 0.08, 0.52), mats["steel"], rot=(math.radians(-15), 0, 0))
    hilt = box("MinionSwordHilt", (0.47, -0.04, 0.80), (0.22, 0.07, 0.06), mats["gold"], bevel=0.02)
    for obj in (shield, shield_gem): parent_to_bone(obj, rig, "arm.L")
    for obj in (sword, hilt): parent_to_bone(obj, rig, "arm.R")
    add_hero_animations(rig, "Minion")
    # Minions keep the shared locomotion/combat clips; Q/R are intentionally
    # removed so the runtime contract cannot mistake them for heroes.
    for name in ("q", "ultimate"):
        action = __import__("bpy").data.actions.get(name)
        if action: __import__("bpy").data.actions.remove(action)
    return rig


def output(name):
    return (
        ASSET_DIR / f"{name}_source.blend",
        ASSET_DIR / f"{name}.glb",
        ASSET_DIR / f"{name}_preview.png",
    )


def build_and_export(name, builder, camera=(4.0, -6.8, 3.6)):
    rig = builder()
    blend, glb, preview = output(name)
    export_asset(rig, blend, glb, preview, (0, 0, 1.05), camera, 1.65)
    print("ROSTER_ASSET_OK", name, glb)


def main():
    build_and_export("lyra", build_lyra)
    build_and_export("nix", build_nix)
    build_and_export("sol", build_sol)
    build_and_export("minion_blue", lambda: build_minion("blue"))
    build_and_export("minion_red", lambda: build_minion("red"))
    print("ROSTER_FAMILY_BUILD_OK", ASSET_DIR)


if __name__ == "__main__":
    main()
