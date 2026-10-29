# Decision Register
**As of:** 2026-10-29 · **Working title:** Behind the Lanterns

Legend: **Locked** explicit user decision; **Provisional** direction but adjustable; **Open** must be decided during design or feasibility; **Deferred** out of first scope.

| ID | Status | Decision |
| --- | --- | --- |
| D-001 | Locked | Timeless Arabian fantasy inspired by One Thousand and One Nights; real named countries and legendary freedom; no exact historical date. |
| D-002 | Locked | Open sandbox; no mandatory central quest or forced ending. |
| D-003 | Locked | Player begins as modest free stable worker; errands and curiosity lead into travel/adventure. Stable is only the start. |
| D-004 | Locked | World truths exist before and independent of player knowledge/quest flags; discoverable without NPC hints. |
| D-005 | Locked | Ink for dialogue and wider narrative logic, integrated with semantic Knowledge and objective World State. |
| D-006 | Locked | Public boats for sea routes and caravans for land; ordinary travel primarily fast travel with concise narrative logs. |
| D-007 | Locked | Dangerous destinations may require independent exploration after carriers refuse; personal decoratable boat is an important progression goal. |
| D-008 | Locked | Lightweight skill-based combat with dodge/block/roll/weak spots; guards and soldiers never normal combat targets. |
| D-009 | Locked | Guard aggression results in scripted arrest; pursuit, hiding, cooling wanted status, jail/fines and social jail encounters are part of the design. |
| D-010 | Locked | Light progression branches for combat, craft, speech, and everyday activities. |
| D-011 | Locked | Time, day/night, NPC routines, and everyday needs; Skyrim-lite feel, not a heavy survival sim. |
| D-012 | Locked | Protagonist is ordinarily human; magical powers are temporary/conditional, not permanent. |
| D-013 | Locked | Appearance customization deferred initially; stable room → inn room → owned home/land; optional growing/selling produce. |
| D-014 | Locked | Godot; 2D fixed 3/4 top-down oblique; high-resolution pixel-art direction; mobile-first landscape touch controls. |
| D-015 | Locked | Build extensible systems with very little replaceable content; do not create a canonical vertical slice. |
| D-016 | Locked | Death/defeat returns to previous save or checkpoint; detailed rollback policy remains open. |
| D-017 | Locked | Gentle free/mobile monetization with optional advertising disabled free in settings; possible Patreon, Steam later. |
| D-018 | Locked | Invented gibberish vocalizations + localizable text; no dependence on voiced player name. |
| D-019 | Provisional | Alexandria is candidate first city; exact starting city/name not finally approved. |
| D-020 | Provisional | Systems use explicit state/knowledge/Ink command boundaries and deterministic seeds when appropriate. |
| D-021 | Provisional | Blender geometry-authoritative render pipeline for 2D buildings and character portraits for important dialogue. |
| D-022 | Open | Final Godot version/language ADR, mobile export, BTL-specific inkgd/Ink binding interoperability; GDScript is preferred and Web target confirmed (see D-026–028). |
| D-023 | Open | Specific day length, needs penalties, checkpoints, autosave, prison duration/fines, control mapping. |
| D-024 | Open | What exact features are in first public mobile release and minimum shippable content. |
| D-025 | Deferred | Broad character appearance editor, full 3D world, cloth/hair physics, complex vessel navigation and large generative city tooling. |
| D-026 | Locked | **Web is a target platform** as well as native mobile and later desktop/Steam. |
| D-027 | Provisional | **Typed GDScript-first** is owner's preferred approach; final lifetime/DI and language ADR remains open. C++/Rust extension only if measured need and platform support are confirmed. |
| D-028 | Verified reference (not a BTL feature decision) | **Kiosk on the Nile** has working Godot 4.7.2 + GDScript + Godot-4 inkgd + Ink JSON workflow and Web previews; BTL-specific integration/mobile export are not verified. |
| D-029 | Open | Adopt, revise or reject the proposed Inventory/Crafting/Cooking/Farming/Fishing/Housing/Trade domain contracts in GDD 08; exact fishing interactions, farming care, placement and launch scope remain undecided. |

## Amendment rules
1. Owner decisions outrank earlier assistant suggestions and example content.
2. When a conflict arises, update this register and the affected GDD together.
3. No auto-upgrade from Provisional to Locked because an agent implemented a prototype.
4. New system work must link to a GitHub Issue with verifiable acceptance conditions.
