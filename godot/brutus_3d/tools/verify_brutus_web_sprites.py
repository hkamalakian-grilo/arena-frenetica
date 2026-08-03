"""Validate every Brutus atlas, direction, frame margin and locomotion seam."""

from pathlib import Path
import json

from PIL import Image, ImageChops, ImageStat


ROOT = Path(__file__).resolve().parents[3]
HERO_DIR = ROOT / "assets" / "heroes"
MANIFEST_PATH = HERO_DIR / "brutus_3d_manifest.json"
EXPECTED_CLIPS = {
    "idle", "walk", "run", "attack", "attack_alt", "q", "r", "catch", "hurt", "death",
    "idle_no_shield", "walk_no_shield", "run_no_shield", "attack_no_shield",
    "attack_alt_no_shield", "q_no_shield", "r_no_shield", "hurt_no_shield",
    "death_no_shield",
}
MAX_BOTTOM_RANGE = {
    "walk": 2, "walk_no_shield": 2,
    "run": 7, "run_no_shield": 7,
    "q": 7, "q_no_shield": 7,
}
LOOPS = {"idle", "walk", "run", "idle_no_shield", "walk_no_shield", "run_no_shield"}


def difference_amount(first, second):
    stats = ImageStat.Stat(ImageChops.difference(first, second))
    return sum(stats.sum)


def main():
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    clips = manifest["clips"]
    if set(clips) != EXPECTED_CLIPS:
        raise AssertionError(f"Unexpected clip set: {sorted(set(clips) ^ EXPECTED_CLIPS)}")
    worst_bottom_range = 0
    worst_locomotion_bottom_range = 0
    minimum_margin = min(manifest["cellWidth"], manifest["cellHeight"])
    worst_loop_ratio = 0.0

    for name, config in clips.items():
        width = config.get("cellWidth", manifest["cellWidth"])
        height = config.get("cellHeight", manifest["cellHeight"])
        path = ROOT / config["src"]
        with Image.open(path) as source:
            atlas = source.convert("RGBA")
        expected_size = (width * config["frames"], height * config["rows"])
        if atlas.size != expected_size:
            raise AssertionError(f"{name}: expected {expected_size}, got {atlas.size}")

        for direction in range(config["rows"]):
            tiles = []
            bottoms = []
            alpha_areas = []
            for frame in range(config["frames"]):
                tile = atlas.crop((frame * width, direction * height,
                                   (frame + 1) * width, (direction + 1) * height))
                bounds = tile.getchannel("A").getbbox()
                if bounds is None:
                    raise AssertionError(f"{name} direction={direction} frame={frame} is empty")
                margins = (bounds[0], bounds[1], width - bounds[2], height - bounds[3])
                minimum_margin = min(minimum_margin, *margins)
                if min(margins) < 1:
                    raise AssertionError(f"{name} direction={direction} frame={frame} is cropped: {bounds}")
                bottoms.append(bounds[3])
                alpha_areas.append(sum(tile.getchannel("A").histogram()[1:]))
                tiles.append(tile)

            bottom_range = max(bottoms) - min(bottoms)
            worst_bottom_range = max(worst_bottom_range, bottom_range)
            limit = MAX_BOTTOM_RANGE.get(name)
            if limit is not None:
                worst_locomotion_bottom_range = max(worst_locomotion_bottom_range, bottom_range)
            if limit is not None and bottom_range > limit:
                raise AssertionError(
                    f"{name} direction={direction} foot baseline varies {bottom_range}px (limit {limit})"
                )

            if name == "catch":
                if config.get("contactFrame") != 3:
                    raise AssertionError("catch: contactFrame must identify authored frame 3")
                before = sum(alpha_areas[:3]) / 3
                after = sum(alpha_areas[3:]) / 3
                if after - before < 150:
                    raise AssertionError(
                        f"catch direction={direction} does not visibly add the shield at contact"
                    )

            if name in LOOPS:
                internal = [difference_amount(tiles[index], tiles[index + 1])
                            for index in range(len(tiles) - 1)]
                seam = difference_amount(tiles[-1], tiles[0])
                ratio = seam / max(max(internal), 1)
                worst_loop_ratio = max(worst_loop_ratio, ratio)
                if ratio > 1.2:
                    raise AssertionError(
                        f"{name} direction={direction} loop seam ratio {ratio:.3f} is discontinuous"
                    )

    recorded_margin = min(manifest["minimumTransparentMargins"].values())
    if recorded_margin != minimum_margin:
        raise AssertionError(
            f"manifest minimum margin {recorded_margin} differs from measured {minimum_margin}"
        )
    print(json.dumps({
        "brutusSpriteQA": "ok",
        "clips": len(clips),
        "directions": 8,
        "minimumMargin": minimum_margin,
        "worstBottomRange": worst_bottom_range,
        "worstLocomotionBottomRange": worst_locomotion_bottom_range,
        "worstLoopRatio": round(worst_loop_ratio, 3),
    }))


if __name__ == "__main__":
    main()
