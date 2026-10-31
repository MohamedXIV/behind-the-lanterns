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
| D-022 | Open | BTL-specific Ink binding/runtime validation and native Android/iOS export; foundation language and engine version accepted in ADR-001 (D-037). |
| D-023 | Open | Specific day length, needs penalties, checkpoints, autosave, prison duration/fines, control mapping. |
| D-024 | Open | What exact features are in first public mobile release and minimum shippable content. |
| D-025 | Deferred | Broad character appearance editor, full 3D world, cloth/hair physics, complex vessel navigation and large generative city tooling. |
| D-026 | Locked | **Web is a target platform** as well as native mobile and later desktop/Steam. |
| D-027 | Locked | Typed GDScript-first is the production default; C++/Rust GDExtension only for measured bottlenecks with Web/mobile portability verified. See ADR-001. |
| D-028 | Provisional (reference evidence; not a BTL feature decision) | **Kiosk on the Nile** has working Godot 4.7.2 + GDScript + Godot-4 inkgd + Ink JSON workflow and Web previews; BTL-specific integration/mobile export are not verified. |
| D-029 | Open | Approve the shared Inventory/Crafting/Cooking/Farming/Fishing/Housing/Trade boundaries in GDD 08; gameplay directions in D-030–033 are confirmed, but precise schemas, tuning and launch scope remain open. |
| D-030 | Locked | Fishing begins with bait choice and a small timing minigame, with fish availability strongly differentiated by location; start with limited species, expand later into exotic/fantasy fish and sea life. |
| D-031 | Locked | Farming supports crop-specific environment, soil, required watering and growth time. Skills may ease selected requirements within believable limits; basic environmental impossibilities remain meaningful. |
| D-032 | Locked | Crafting actions take a few seconds of active play, not return-later mobile timers. Exact duration/cancellation details are open. |
| D-033 | Locked | Home furniture/decor placement will be deliberately simple and constrained for fixed 2D; avoid complex construction/build-mode scope. |
| D-034 | Provisional | Prefer shallow inheritance and focused composition of reusable item capabilities (e.g. future spoilage, durability, placement, consumability), plus bounded action-specific skill modifiers; no universal trait/effects engine is approved. |
| D-035 | Open | Spoilage feature launch inclusion, storage effects and item expiry policies; farm watering cadence/failure, fish timing details, furniture snap model, and craft interruption rules. |
| D-036 | Locked | Adopt selective offscreen simulation as the **foundational execution policy**: active loaded-scene behavior, durable scheduled consequential events, lazy time-anchored state reconciliation, and unticked static world facts. Fine-grained policy, clock rate and event schemas remain tunable. See ADR-001/RFC-002. |
| D-037 | Locked | ADR-001: Godot Standard 4.7.2, typed GDScript, one composition root and session-scoped service state, minimal Autoloads, manual wiring, WorldClock + SimulationCoordinator + due-event Scheduler, state-owning domains and scene-local presentation; no mandatory DI framework or all-global managers. |

## Runtime implementation review

| ID | Status | Decision |
| --- | --- | --- |
| D-038 | Provisional | ADR-002 is the engineering baseline merged in #11 after review and executed Godot tests: detached candidates, whole-request rollback, due/FIFO ordering, stable IDs, strict validation and native A/B recovery. It remains open to evidence-based technical refinement and is not a completed platform acceptance claim. |
| D-039 | Provisional | Owner-authorized first gameplay increment (#12): aggregate ordinary goods in one container ledger, data-defined stacking/capacity, static container access, finite wallets/stock and atomic quoted trade, with region/reach checks. The disposable playground's values and movement presentation are not final game design. Unique items, legal ownership/theft, jobs, crafting and dynamic economy remain future scope. |
| D-040 | Provisional | #14 connected gameplay batch: optional one-shot supply jobs hold their reward in Commerce; active preparation reserves inputs in Inventory, pauses away from its station and releases inputs on cancellation. Output-space failure leaves preparation ready to collect. World-time waiting resolves deadlines; in-region NPC routines are pure time lookups. Sample tuning and these bounded policies do not ratify every livelihood proposal or final release scope. |

| D-041 | Provisional | #14 linked rooms: data-defined doors atomically relocate actor region and position; region-local collision and a shared reusable 2D view compose modest temporary rooms. Interior storage/preparation reuse existing domains. Rooms share a logical extent; no scene framework, final city art or cross-region NPC walking is implied. |

| D-042 | Provisional | #5/#14: real inkgd drives contextual conversation; immutable world facts and existing semantic knowledge remain authoritative. Whitelisted story commands can add hearsay or request existing work. Bounded choice/context replay persists conversation continuation and verifies frames, with no raw VM save injection or general quest framework. |

| D-043 | Provisional | #5/#14: reporting requires inspected evidence and records whom the player told; NPC dialogue can request existing atomic delivery. Reporting does not rewrite static facts or introduce a gossip/quest simulation. Conversation restart refreshes context and exact cursor checks reject stale UI choices. |

| D-044 | Provisional | #14: NPC shared commitment memory derives from Work outcomes; explicit acknowledgement is recorded per affected person without erasing failure or granting rewards. Kept work may enable an optional same-giver favor. No relationship score, mandatory progression or town-wide psychology is implied. |

| D-045 | Provisional | #14 fishing: authored habitat/bait pools, seeded saved opportunities, short active-time reel windows, bait spent on cast, full-bag catches held for collection at the spot. Fish reuse ordinary inventory, trade and preparation. No ecology/gear grind or platform acceptance is implied. |

| D-046 | Provisional | #14 farming: data-defined plots and crops, ownership/access validation, hard environment/soil viability preserving seeds on failure, interval-spaced world-time watering, lazy time-anchored offscreen growth reconciliation, full-bag held harvests and bounded cultivation skill easing only soft thresholds. Harvests reuse ordinary inventory, preparation and trade. No farming-sim obligation or platform acceptance is implied. |

| D-047 | Provisional | #6/#2 mobile-first interaction & Web recovery: semantic `PlayerInput` actions decouple movement, running, context interaction and combat/evasion intents from physical buttons; `TouchControls` provides landscape D-pad, run toggle, visibility and left/right handedness swap; safe-area margins and pause/focus notifications halt movement and commit safe state. `RecoveryStore` integrates `WebSaveAck` (`/userfs` IndexedDB sync/verification, failing closed when pending/failed and preserving the prior confirmed A/B generation). Desktop/simulated verification does not replace physical mobile or live browser acceptance. |

| D-048 | Provisional | #7 law, pursuit, scripted arrest & watchhouse: guards (`LawRules`) are never normal combat targets (`confront_guard` commits scripted arrest); witnessed tampering starts pursuit with scheduled `law.cooldown` events; refuges clear pursuit when guards are out of reach; completed local work commitments vouch for first-time non-assault offenses; repeat offenses scale fines and sentences; `region.watchhouse` provides a traversable social jail with Ink conversation (`a:detainee`) using shared world claims without exclusive gating or reward farming. Sample tuning is not final city balance. |
| D-049 | Provisional | #14 public travel: data-defined ships/caravans use scheduled carriers, origin/reach/availability/fare checks and explicit confirmation. One transaction pays once, schedules a stable arrival, advances world time through ordinary due events, relocates once and records an optional concise persistent log; any failure rolls back the whole journey. Carriers refuse active pursuit/detention without changing local evasion. Disposable bidirectional route pairs prove the contract; no canonical city, continuous world, vehicle simulator, mandatory quest or private boat system is implied. |

| D-050 | Provisional | #14 housing subset under locked D-013/D-033: authored property/room/floor access grants via atomic finite payment and provider reach; constrained numbered furnishing cells with touch preview, collision/usable-route checks; stable physical furniture/container identity across packing and relocation, including full chests. Sample access costs and no-expiry fixture grants do not approve rent duration, eviction, title-transfer policy, construction or final housing economy. See `technical/HOUSING-PLAY.md`. |
| D-051 | Provisional | #8/#14 building art pipeline & cutaway proof under locked D-014 and provisional D-021: parametric 3D building spec (`dev/art/building_fixture_spec.json`), Blender blockout script (`tools/blender_building_blockout.py`), and deterministic 2D elevated 3/4 oblique pass generator (`tools/build-cutaway-assets.py`) produce separable `shell`/`interior`/`front_wall`/`roof`/`upper_floor` layers and detachable furnishing sprites (`a:housing-chest`, `a:lamp`, `a:cushion`) with zero baked room furniture. `BuildingCutaway` and `WorldView` keep global `visible_floor` selection separate from local player-relative roof/front-wall occlusion and preserve all `HousingRules`/`InteractionRules`/`InventoryRules` authority. Does not lock final PPU, shipping art bible, or canonical building catalog. See `technical/BUILDING-CUTAWAY.md`. |
| D-052 | Provisional | #14 lightweight non-guard combat & retreat under locked D-008/D-009 and open D-016: `CombatRules` (`game/combat/combat_rules.gd`) implements data-driven non-guard threat encounters with readable light/heavy attack telegraphs, active-time progression, block vs dodge differentiation, bounded weak-spot vulnerability windows rewarding timing over equipment stats, spatial outspacing, and first-class explicit/spatial retreat (`retreat` + `sync_spatial`). Guards are rejected at configuration and runtime combat boundaries (`guard_not_combat_target`), preserving scripted arrest in `LawRules`. Zero player health transitions to a bounded non-destructive `winded` state at the safe `retreat_point` without deleting saves or finalizing the open D-016 checkpoint/rollback policy. See `technical/COMBAT-PLAY.md`. |
| D-053 | Provisional | #14 optional exploration & dangerous destinations under locked D-004/D-005/D-006/D-007/D-008 and open D-016: `TravelRules` supports optional data-defined `hazard_refusal` on routes so public carriers refuse unsafe/uncharted passages (`carrier_refuses_hazard`) before any fare or time mutation, leaving the player at a nearby safe landing (`region.estuary`) to approach on foot (`a:shoal-causeway` → `region.shoal`). Objective world facts and remote locations exist from session start independent of rumors; `WorldTransaction.discover()` preserves `"confirmed"` firsthand discovery when an NPC rumor (`"heard"`) is encountered later. Spatial layout and `CombatRules` allow avoiding threats (`a:reef-warden`), engaging and retreating, or exploiting weak spots without a generic Exploration Manager or mandatory quest chain. See `technical/EXPLORATION-PLAY.md`. |


## Amendment rules
1. Owner decisions outrank earlier assistant suggestions and example content.
2. When a conflict arises, update this register and the affected GDD together.
3. No auto-upgrade from Provisional to Locked because an agent implemented a prototype.
4. New system work must link to a GitHub Issue with verifiable acceptance conditions.

