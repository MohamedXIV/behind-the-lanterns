# Building Art Pipeline & Same-Building Exterior/Cutaway Proof

**Authority:** [Issue #8](https://github.com/MohamedXIV/behind-the-lanterns/issues/8), [Issue #14](https://github.com/MohamedXIV/behind-the-lanterns/issues/14), Locked `D-014`, Provisional `D-021`, [GDD 04 — Art and Technical Direction](../04-ART-TECH.md), [System Catalog P03](../07-SYSTEM-CATALOG.md), and Provisional `D-050` ([HOUSING-PLAY.md](HOUSING-PLAY.md)).

> **Noncanonical Prototype Notice:** The building fixture (`building.inn_pavilion`), pixel proportions, palette, and 2D layer sprites documented here are a **disposable technical-art validation**, not the canonical starting house, inn, or first city, and do not lock final pixel density (PPU), building catalog, or shipping visual identity on the owner's behalf.

---

## 1. Authoring Pipeline Evaluation (`D-021`)

Approved direction under evaluation:
`parametric 3D blockout (Blender / Python) → fixed orthographic projection → coherent exterior/interior 2D render passes → stylization/cleanup → Godot 2D assets`.

### Tooling Evidence & Reproducible Implementation
- **Environment check:** The headless Linux container provides Python 3.14 and Godot Standard `4.7.2.stable.official.ed1daf0bf`, while the `blender` binary is not pre-installed in the default image.
- **Single source of architectural truth:** [`dev/art/building_fixture_spec.json`](../../dev/art/building_fixture_spec.json) defines the exact 3D box coordinates `(x, y, z, width, height, depth)` for the building footprint (`x: 16, y: 14, width: 660, height: 346`), wall thickness (`12`), ground-floor and upper-terrace elevations (`z_base: 0, wall_height: 36` and `z_base: 36, wall_height: 18`), doorway and mashrabiya window openings, camera/player occlusion zones, and detachable furnishing dimensions.
- **Blender Python blockout generator:** [`tools/blender_building_blockout.py`](../../tools/blender_building_blockout.py) consumes `building_fixture_spec.json` and constructs the corresponding 3D collections (`shell`, `interior`, `front_wall`, `roof`, `upper_floor`) with an orthographic camera pitched at `45°` (`--dry-run` validates and emits the exact 3D scene plan when `bpy` is absent; running inside Blender writes `building_fixture.blend`).
- **Deterministic 2D orthographic pass renderer:** [`tools/build-cutaway-assets.py`](../../tools/build-cutaway-assets.py) reads the same `building_fixture_spec.json`, projects every 3D structural box and opening through the exact fixed elevated 3/4 oblique orthographic formula (`pixel_x = x - origin_x`, `pixel_y = y - z - origin_y`), applies stylized masonry/tile/timber/mashrabiya pixel-art passes, and writes the separable PNG layers, detachable prop sprites, composite proof sheet, and [`dev/art/cutaway_fixture/manifest.json`](../../dev/art/cutaway_fixture/manifest.json) using only the Python standard library.

### How to Edit or Regenerate the Building
1. Edit dimensions, openings, occlusion zones, or palette colors in [`dev/art/building_fixture_spec.json`](../../dev/art/building_fixture_spec.json).
2. Run the deterministic 2D pass builder:
   ```sh
   python3 tools/build-cutaway-assets.py
   ```
3. (Optional, when Blender is installed locally) Generate or inspect the `.blend` 3D blockout:
   ```sh
   blender --background --python tools/blender_building_blockout.py -- --spec dev/art/building_fixture_spec.json --out dev/art/cutaway_fixture
   ```
   Or preview the 3D collection plan without Blender:
   ```sh
   python3 tools/blender_building_blockout.py --dry-run
   ```

---

## 2. Provisional Technical-Art Conventions (Proposed, Not Locked)

| Parameter | Prototype Value | Status | Notes |
| --- | --- | --- | --- |
| **Perspective** | Elevated 3/4 top-down oblique (`true_isometric: false`) | **Locked (`D-014`)** | Horizontal walls stay parallel to the screen X axis; depth runs along Y; vertical height `Z` projects upward along `-Y` (`pixel_y = y - z`). |
| **Scale / PPU** | `1.0` logical world unit = `1` source texel (`684×434` canvas for `660×346` footprint) | **Provisional (`Open` in GDD 04)** | Matches `linked_world.json` logical room coordinates `1:1` so doorways and `HousingRules` cells align without fractional resampling. Final shipping PPU remains an owner decision. |
| **Separable Building Layers** | `layer_shell.png`, `layer_interior.png`, `layer_front_wall.png`, `layer_roof.png`, `layer_upper_floor.png` | **Provisional (`P03`)** | Exported with identical canvas bounds and world origin `(-4, -62)` so layers register pixel-for-pixel in Godot. |
| **Detachable Furnishings** | `prop_chest.png` (`40×30`), `prop_lamp.png` (`24×24`), `prop_cushion.png` (`24×24`) | **Provisional (`D-033`, `D-050`)** | Rendered as independent sprites anchored to `HousingRules` placement cells; `layer_interior.png` contains zero baked-in furniture. |
| **Surface Readability & Palette** | Warm limestone (`#d9c7a3`–`#9a825c`), plaster (`#e5d7b8`), cedar timber (`#6e472b`), terracotta/ochre/slate floor tiles, brass lantern glow (`#ffe89e`) | **Provisional** | High value contrast between walkable interior tile floor, dark structural wall tops, and warm doorway/window highlights for mobile landscape readability. |

---

## 3. Godot Cutaway Integration & Authority Boundaries

[`BuildingCutaway`](../../game/world/building_cutaway.gd) and [`WorldView`](../../game/world/world_view.gd) implement reusable 2D cutaway presentation without coupling world truth to sprites:

1. **Global Visible Floor vs. Local Camera/Player Occlusion (`GDD 04`, `P03`):**
   - `WorldView.set_visible_floor(floor_index)` (exposed in the **Housing** tab via `VisibleFloor`) controls the **global floor index** (`0` = ground floor, `1` = upper roof terrace & parapet).
   - `BuildingCutaway.evaluate_state(region_id, actor_pos, visible_floor)` independently computes **local player-relative occlusion** when the player walks under the exterior doorway eave (`exterior_eave_occluder` around `a:inn-door` at `40, 60`) or behind the south facade wall inside the room (`interior_front_wall_band`).
2. **Four Distinct Presentation States Demonstrated:**
   - `exterior_normal`: Opaque roof (`1.0`) and front facade (`1.0`), interior hidden (`0.0`).
   - `exterior_occluded`: When the player approaches `a:inn-door` (`40, 60`), the overhanging roof eave (`0.28`) and front wall (`0.38`) fade to keep the player silhouette and doorway threshold readable.
   - `interior_cutaway` / `interior_front_occluded`: Entering `region.inn` hides the roof (`0.0`), displays the full interior tile floor and north wall elevation (`1.0`), Y-sorts the player against detachable furniture (`a:housing-chest`, `a:lamp`, `a:cushion`), and draws the south front-wall occluder in front of the room (fading from `0.42` to `0.22` when the player walks behind the south wall).
   - `exterior_upper_floor` / `interior_upper_floor`: Selecting Floor `1` displays `layer_upper_floor.png` (upper terrace walkway and parapet walls) while preserving local eave/front-wall occlusion and leaving `GameSession` state untouched.
3. **Preserved Gameplay & Save Compatibility:**
   - `HousingRules`, `InteractionRules`, `InventoryRules`, and `CommerceRules` are untouched.
   - No save format, domain schema version, or `linked_world.json` content fingerprint changed; existing housing saves remain compatible.
