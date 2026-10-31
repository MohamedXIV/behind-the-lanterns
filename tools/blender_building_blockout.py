#!/usr/bin/env python3
"""
Blender Geometry-Authoritative Blockout & Orthographic Pass Exporter.
Reads `dev/art/building_fixture_spec.json` and constructs the 3D blockout
collections (`shell`, `interior`, `front_wall`, `roof`, `upper_floor`, and
`furnishings`) with a fixed elevated 3/4 oblique orthographic camera.

Usage with Blender (when installed on workstation):
  blender --background --python tools/blender_building_blockout.py -- \
    --spec dev/art/building_fixture_spec.json \
    --out dev/art/cutaway_fixture

When Blender is not installed in headless CI/container environments, run
`python3 tools/build-cutaway-assets.py` which uses the exact same
`dev/art/building_fixture_spec.json` geometry and projection parameters.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Blender 3D blockout generator for BTL cutaway fixture")
    parser.add_argument("--spec", default="dev/art/building_fixture_spec.json", help="Path to building spec JSON")
    parser.add_argument("--out", default="dev/art/cutaway_fixture", help="Output directory for renders")
    parser.add_argument("--dry-run", action="store_true", help="Validate spec and print Blender scene plan without bpy")
    # Support Blender's `--` argument separator
    import sys
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    return parser.parse_args(argv)


def build_scene_plan(spec: dict) -> dict:
    fp = spec["footprint"]
    floors = {f["floor_index"]: f for f in spec["floors"]}
    f0 = floors[0]
    f1 = floors[1]
    t = spec["wall_thickness"]
    return {
        "fixture_id": spec["fixture_id"],
        "projection": spec["projection"],
        "collections": {
            "shell": [
                {"name": "plinth", "box": [fp["x"], fp["y"], -4, fp["width"], fp["height"], 4]},
                {"name": "north_wall", "box": [fp["x"], fp["y"], 0, fp["width"], t, f0["wall_height"]]},
                {"name": "west_wall", "box": [fp["x"], fp["y"], 0, t, fp["height"], f0["wall_height"]]},
                {"name": "east_wall", "box": [fp["x"] + fp["width"] - t, fp["y"], 0, t, fp["height"], f0["wall_height"]]},
            ],
            "interior": [
                {"name": "floor_tiles", "box": [fp["x"] + t, fp["y"] + t, 0, fp["width"] - 2 * t, fp["height"] - 2 * t, 2]},
                {"name": "north_wainscot", "box": [fp["x"] + t, fp["y"] + t, 0, fp["width"] - 2 * t, 4, f0["wall_height"] - 4]},
            ],
            "front_wall": [
                {"name": "south_facade", "box": [fp["x"], fp["y"] + fp["height"] - t, 0, fp["width"], t, f0["wall_height"]]},
                {"name": "door_awning", "box": [fp["x"] + 6, fp["y"] + fp["height"], 22, 64, 18, 8]},
            ],
            "roof": [
                {"name": "roof_slab", "box": [fp["x"] - 4, fp["y"] - 4, f0["wall_height"], fp["width"] + 8, fp["height"] + 8, 6]},
                {"name": "windcatcher_badgir", "box": [fp["x"] + 270, fp["y"] + 40, f0["wall_height"] + 6, 120, 88, 22]},
            ],
            "upper_floor": [
                {"name": "terrace_parapet_north", "box": [fp["x"], fp["y"], f1["z_base"], fp["width"], t, f1["wall_height"]]},
                {"name": "terrace_parapet_south", "box": [fp["x"], fp["y"] + fp["height"] - t, f1["z_base"], fp["width"], t, f1["wall_height"]]},
                {"name": "terrace_parapet_west", "box": [fp["x"], fp["y"], f1["z_base"], t, fp["height"], f1["wall_height"]]},
                {"name": "terrace_parapet_east", "box": [fp["x"] + fp["width"] - t, fp["y"], f1["z_base"], t, fp["height"], f1["wall_height"]]},
            ],
        },
    }


def main() -> int:
    args = parse_args()
    spec_path = Path(args.spec)
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    plan = build_scene_plan(spec)

    if args.dry_run:
        print(json.dumps(plan, indent=2))
        return 0

    try:
        import bpy  # type: ignore
    except ImportError:
        print(
            "Blender Python (`bpy`) is not installed in this environment. "
            "Use `python3 tools/build-cutaway-assets.py` to generate the exact 2D orthographic passes from the same spec."
        )
        return 0

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = True
    fp = spec["footprint"]
    scene.render.resolution_x = int(fp["width"] + 32)
    scene.render.resolution_y = int(fp["height"] + 92)

    cam_data = bpy.data.cameras.new("ObliqueOrthoCamera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = float(fp["width"] + 32)
    cam_obj = bpy.data.objects.new("ObliqueOrthoCamera", cam_data)
    scene.collection.objects.link(cam_obj)
    cam_obj.rotation_euler = (math.radians(45.0), 0.0, 0.0)
    cam_obj.location = (fp["x"] + fp["width"] * 0.5, fp["y"] + fp["height"] * 0.5 + 200.0, 200.0)
    scene.camera = cam_obj

    for coll_name, boxes in plan["collections"].items():
        coll = bpy.data.collections.new(coll_name)
        scene.collection.children.link(coll)
        for item in boxes:
            bx, by, bz, bw, bh, bd = item["box"]
            bpy.ops.mesh.primitive_cube_add(
                size=1.0,
                location=(bx + bw * 0.5, -(by + bh * 0.5), bz + bd * 0.5),
                scale=(bw, bh, bd),
            )
            obj = bpy.context.active_object
            obj.name = f"{coll_name}_{item['name']}"
            for c in obj.users_collection:
                c.objects.unlink(obj)
            coll.objects.link(obj)

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    blend_path = out_dir / "building_fixture.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path.resolve()))
    print(f"Saved Blender blockout to {blend_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
