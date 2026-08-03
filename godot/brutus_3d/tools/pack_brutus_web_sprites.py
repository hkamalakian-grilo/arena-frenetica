"""Pack Blender's temporary Brutus renders into web-ready PNG strips."""

from pathlib import Path
import json
import shutil

from PIL import Image, ImageChops, ImageFilter


ROOT = Path(__file__).resolve().parents[3]
HERO_DIR = ROOT / "assets" / "heroes"
FRAME_ROOT = HERO_DIR / ".brutus_3d_frames"
CELL_WIDTH = 288
CELL_HEIGHT = 192
CROP_MARGIN = 4
CROP_BOTTOM = 175
SOURCE_FOOT_Y = CELL_HEIGHT * 0.86

CLIPS = {
    "idle": {"frames": 6, "fps": 6.0, "loop": True},
    "walk": {"frames": 8, "fps": 10.0, "loop": True},
    "run": {"frames": 12, "fps": 15.0, "loop": True},
    "attack": {"frames": 10, "fps": 15.0, "loop": False},
    "attack_alt": {"frames": 10, "fps": 15.0, "loop": False},
    "q": {"frames": 12, "fps": 15.0, "loop": False},
    "r": {"frames": 12, "fps": 10.0, "loop": False},
    "catch": {"frames": 6, "fps": 15.0, "loop": False, "contactFrame": 3},
    "hurt": {"frames": 8, "fps": 15.0, "loop": False},
    "death": {"frames": 12, "fps": 10.0, "loop": False},
    "idle_no_shield": {"frames": 6, "fps": 6.0, "loop": True},
    "walk_no_shield": {"frames": 8, "fps": 10.0, "loop": True},
    "run_no_shield": {"frames": 12, "fps": 15.0, "loop": True},
    "attack_no_shield": {"frames": 10, "fps": 15.0, "loop": False},
    "attack_alt_no_shield": {"frames": 10, "fps": 15.0, "loop": False},
    "q_no_shield": {"frames": 12, "fps": 15.0, "loop": False},
    "r_no_shield": {"frames": 12, "fps": 10.0, "loop": False},
    "hurt_no_shield": {"frames": 8, "fps": 15.0, "loop": False},
    "death_no_shield": {"frames": 12, "fps": 10.0, "loop": False},
}

# Preserve authored body weight but keep the contact foot visually planted.
# 1.0 fully anchors the lowest foot; 0.55 retains a small athletic flight arc.
GROUND_STABILIZATION = {
    "walk": 1.0,
    "walk_no_shield": 1.0,
    "run": 0.55,
    "run_no_shield": 0.55,
    "q": 0.55,
    "q_no_shield": 0.55,
}


def add_mobile_outline(tile):
    """Add a crisp one-pixel silhouette without muddying armor details."""
    alpha = tile.getchannel("A")
    expanded = alpha.filter(ImageFilter.MaxFilter(3))
    border = ImageChops.subtract(expanded, alpha)
    outline = Image.new("RGBA", tile.size, (42, 15, 10, 0))
    outline.putalpha(border)
    composed = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    composed.alpha_composite(outline)
    composed.alpha_composite(tile)
    return composed


def compute_direction_offsets():
    offsets = {}
    idle_frames = CLIPS["idle"]["frames"]
    for direction in range(8):
        left = CELL_WIDTH
        right = 0
        bottom = 0
        for frame in range(idle_frames):
            source = FRAME_ROOT / "idle" / f"d{direction}" / f"f{frame:02d}.png"
            with Image.open(source) as image:
                bounds = image.convert("RGBA").getchannel("A").getbbox()
                if bounds is None:
                    raise ValueError(f"Empty transparent frame {source}")
                left = min(left, bounds[0])
                right = max(right, bounds[2])
                bottom = max(bottom, bounds[3])
        visual_center = (left + right) * 0.5
        offsets[direction] = {
            "x": round(CELL_WIDTH * 0.5 - visual_center),
            "y": 170 - bottom,
        }
    return offsets


def pack_clip(name, config, direction_offsets):
    frame_count = config["frames"]
    atlas = Image.new("RGBA", (CELL_WIDTH * frame_count, CELL_HEIGHT * 8), (0, 0, 0, 0))
    minimum_margin = min(CELL_WIDTH, CELL_HEIGHT)
    clip_offsets = {}
    frame_bottoms = {}
    frame_ground_offsets = {}
    union_bounds = [CELL_WIDTH, CELL_HEIGHT, 0, 0]
    # Cada ação mantém o ponto mais baixo no mesmo chão visual. Poses com joelho
    # dobrado ou queda não podem empurrar o personagem para fora da célula.
    for direction in range(8):
        bottom = 0
        bottoms = []
        for frame in range(frame_count):
            source = FRAME_ROOT / name / f"d{direction}" / f"f{frame:02d}.png"
            with Image.open(source) as image:
                bounds = image.convert("RGBA").getchannel("A").getbbox()
                if bounds is None:
                    raise ValueError(f"Empty transparent frame {source}")
                bottom = max(bottom, bounds[3])
                bottoms.append(bounds[3])
        frame_bottoms[direction] = bottoms
        clip_offsets[direction] = {
            "x": direction_offsets[direction]["x"],
            "y": 170 - bottom,
        }
        strength = GROUND_STABILIZATION.get(name, 0.0)
        frame_ground_offsets[direction] = [round((bottom - value) * strength) for value in bottoms]
    for direction in range(8):
        for frame in range(frame_count):
            source = FRAME_ROOT / name / f"d{direction}" / f"f{frame:02d}.png"
            if not source.exists():
                raise FileNotFoundError(source)
            with Image.open(source) as image:
                tile = add_mobile_outline(image.convert("RGBA"))
                if tile.size != (CELL_WIDTH, CELL_HEIGHT):
                    raise ValueError(f"Unexpected frame size {tile.size} in {source}")
                centered = Image.new("RGBA", (CELL_WIDTH, CELL_HEIGHT), (0, 0, 0, 0))
                offset = clip_offsets[direction]
                ground_y = frame_ground_offsets[direction][frame]
                centered.alpha_composite(tile, (offset["x"], offset["y"] + ground_y))
                bounds = centered.getchannel("A").getbbox()
                if bounds is None:
                    raise ValueError(f"Empty transparent frame {source}")
                margins = (bounds[0], bounds[1], CELL_WIDTH - bounds[2], CELL_HEIGHT - bounds[3])
                minimum_margin = min(minimum_margin, *margins)
                if min(margins) < 1:
                    raise ValueError(f"Cropped sprite in {source}: alpha bounds={bounds}")
                union_bounds[0] = min(union_bounds[0], bounds[0])
                union_bounds[1] = min(union_bounds[1], bounds[1])
                union_bounds[2] = max(union_bounds[2], bounds[2])
                union_bounds[3] = max(union_bounds[3], bounds[3])
                atlas.alpha_composite(centered, (frame * CELL_WIDTH, direction * CELL_HEIGHT))

    # Crop only redundant transparent pixels. Horizontal cropping stays
    # symmetric around the original cell center, so the world-space pivot does
    # not move. A shared bottom line lets the renderer recover the exact scale
    # and foot anchor from the resulting cell height without per-clip tuning.
    center_x = CELL_WIDTH // 2
    half_width = max(center_x - union_bounds[0], union_bounds[2] - center_x) + CROP_MARGIN
    crop_left = max(0, center_x - half_width)
    crop_right = min(CELL_WIDTH, center_x + half_width)
    crop_top = max(0, union_bounds[1] - CROP_MARGIN)
    if union_bounds[3] + CROP_MARGIN > CROP_BOTTOM:
        raise ValueError(f"{name}: content exceeds shared crop bottom {CROP_BOTTOM}")
    crop_box = (crop_left, crop_top, crop_right, CROP_BOTTOM)
    cropped_width = crop_right - crop_left
    cropped_height = CROP_BOTTOM - crop_top
    trimmed = Image.new("RGBA", (cropped_width * frame_count, cropped_height * 8), (0, 0, 0, 0))
    minimum_margin = min(cropped_width, cropped_height)
    for direction in range(8):
        for frame in range(frame_count):
            tile = atlas.crop((frame * CELL_WIDTH, direction * CELL_HEIGHT,
                               (frame + 1) * CELL_WIDTH, (direction + 1) * CELL_HEIGHT))
            tile = tile.crop(crop_box)
            bounds = tile.getchannel("A").getbbox()
            if bounds is None:
                raise ValueError(f"{name} direction={direction} frame={frame} became empty")
            margins = (bounds[0], bounds[1], cropped_width - bounds[2], cropped_height - bounds[3])
            minimum_margin = min(minimum_margin, *margins)
            if min(margins) < CROP_MARGIN:
                raise ValueError(f"{name} direction={direction} frame={frame} lost crop margin: {bounds}")
            trimmed.alpha_composite(tile, (frame * cropped_width, direction * cropped_height))
    atlas = trimmed
    output = HERO_DIR / f"brutus_3d_{name}.png"
    atlas.save(output, format="PNG", optimize=True)
    crop_metadata = {
        "cellWidth": cropped_width,
        "cellHeight": cropped_height,
        "cropTop": crop_top,
        "cropBottom": CROP_BOTTOM,
        "renderScale": round(2.15 * cropped_height / CELL_HEIGHT, 8),
        "footAnchor": round((SOURCE_FOOT_Y - crop_top) / cropped_height, 8),
    }
    return output, minimum_margin, clip_offsets, frame_ground_offsets, crop_metadata


def main():
    HERO_DIR.mkdir(parents=True, exist_ok=True)
    direction_offsets = compute_direction_offsets()
    packed = [pack_clip(name, config, direction_offsets) for name, config in CLIPS.items()]
    outputs = [item[0] for item in packed]
    margins = {name: packed[index][1] for index, name in enumerate(CLIPS)}
    clip_offsets = {name: packed[index][2] for index, name in enumerate(CLIPS)}
    frame_ground_offsets = {name: packed[index][3] for index, name in enumerate(CLIPS)}
    crop_metadata = {name: packed[index][4] for index, name in enumerate(CLIPS)}
    manifest = {
        "version": 1,
        "cellWidth": CELL_WIDTH,
        "cellHeight": CELL_HEIGHT,
        "directions": ["east", "southeast", "south", "southwest",
                       "west", "northwest", "north", "northeast"],
        "footAnchor": 0.86,
        "scale": 2.15,
        "minimumTransparentMargins": margins,
        "directionPixelOffsets": direction_offsets,
        "clipPixelOffsets": clip_offsets,
        "frameGroundOffsets": frame_ground_offsets,
        "groundStabilization": GROUND_STABILIZATION,
        "cropMetadata": crop_metadata,
        "clips": {
            name: {**config, **crop_metadata[name],
                   "src": f"assets/heroes/brutus_3d_{name}.png", "rows": 8}
            for name, config in CLIPS.items()
        },
    }
    manifest_path = HERO_DIR / "brutus_3d_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    # This directory is generated exclusively by render_brutus_web_frames.py.
    # Validate the exact sentinel name before removing temporary frames.
    if FRAME_ROOT.name == ".brutus_3d_frames" and FRAME_ROOT.parent == HERO_DIR:
        shutil.rmtree(FRAME_ROOT)

    print("BRUTUS_WEB_SPRITES_OK", *(str(path) for path in outputs), str(manifest_path))


if __name__ == "__main__":
    main()
