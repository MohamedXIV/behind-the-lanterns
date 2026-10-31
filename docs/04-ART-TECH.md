# GDD 04 — Art and Technical Direction
**Status:** initial design · **Updated:** 2026-10-29

## Locked rendering direction
**Godot**, mobile-first, **landscape**, on-screen controls; detailed stylized **2D pixel art** viewed from a fixed elevated **3/4 top-down oblique** perspective. Strong readable building fronts, some roof visibility, an organic world plane, and expressive dialogue portraits. Avoid true isometric coordinates, rotating perspectives, 3D shipping environments, and soft generic illustration.

City scenery should feel lived in: dense streets, markets, awnings, walls, rooftops, animals, lanterns, sandy or muddy ground with patchy stone and greenery. Not an endless uniform cobblestone plaza.

## Architectural assets and cutaway
Enterable buildings should preserve coherent interior and exterior footprints. Keep structural shell, opening/roof/front occluders, interior, and independent props logically separable. Favor compatible **building shells/variants + reusable architectural/dressing modules** over an impossibly fine AI-generated wall-by-wall Lego kit.

Use global **floor index/visibility** independently of camera-side **occlusion**. Roofs, front walls, slabs, and partitions hide/fade where they block the current player view. Floors can be managed globally in a Sims-like fashion; occlusion remains a separate problem. Specific renderer implementation is TBD for Godot.

**Implementation subset (#8 / #14, 31 October 2026):** `D-051` and [BUILDING-CUTAWAY.md](technical/BUILDING-CUTAWAY.md) validate a disposable noncanonical 3/4 oblique building (`building.inn_pavilion`) with matching exterior/interior footprints, separable `shell`/`interior`/`front_wall`/`roof`/`upper_floor` 2D passes, detachable furniture sprites (`a:housing-chest`, `a:lamp`, `a:cushion`), and independent global `visible_floor` vs local player-relative roof/front-wall occlusion in `BuildingCutaway` + `WorldView`. Final pixel density (PPU), shipping art bible, and canonical building catalog remain open for owner approval.


## Art production pipeline (direction, not dependency)
Early attempts at independent AI exterior/interior generation suffered projection drift and geometry inconsistency. Preferred authoring strategy:
`parametric 3D blockout in Blender (Python / Geometry Nodes / Buildify as appropriate) → fixed orthographic camera and matching interior/exterior passes → stylization/cleanup → coherent 2D sprite assets → Godot`.

**Blender is an authoring aid, not a runtime dependency.** Source geometry owns structure; images do not invent spatial topology. Manual cleanup is normal. Do not require an expensive 3D production workflow; avoid overbuilding a generator before validated demand.

Characters: coherent 2D animation with limited modular equipment and **weapon-family** motion sets. Visual customization deferred initially; hair and clothing physics explicitly avoided. Portraits can have a small set of expressive faces rather than full-frame animation.

## Runtime architecture — proposals to validate
- Separate **definitions** (content assets) from **instances** (saved persistent state).
- A shared world-state and semantic knowledge API; no direct Ink mutation of arbitrary nodes.
- Explicit commands/events for legal, economic, travel, social, and narrative consequences.
- Save/load stable IDs and schema versioning; serialize deterministic state, not ephemeral scene-node addresses.
- Scene streaming/loading for discrete regions; do not assume the entire extended world is contiguous.
- Keep content definitions, test fixtures, and runtime services distinct.

## Important decisions still open
- Exact Godot 4.x version and **GDScript vs C# vs a limited hybrid** (including native mobile export/tooling implications).
- Ink runtime/library integration and supported export targets: validate with a functioning compatibility probe.
- Pixel density/PPU and working frame size; collision/y-sort/oblique picking conventions.
- Touch UI layout, button placement and accessibility; keyboard/controller input fallback.
- Asset source formats and optional data localization pipeline.

Do not bootstrap a giant codebase until these choices and minimal system interfaces have been verified.
