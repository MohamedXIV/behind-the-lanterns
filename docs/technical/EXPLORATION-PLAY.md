# Optional Exploration and Dangerous Destinations — #14

**Authority:** `00-CONSTITUTION.md` (§1, §3, §5), `D-004`, `D-005`, `D-006`, `D-007`, `D-008`, `D-016`, `GDD 02` ("The familiar and the hidden" & "Journey and travel"), `GDD 03`, `System Catalog` (`A05`, `A06`, `A07`, `N01`–`N05`), `Production F4`, and [GitHub Issue #14](https://github.com/MohamedXIV/behind-the-lanterns/issues/14). The linked-world regions, landmarks, rumors, and hostile creature in `dev/fixtures/linked_world.json` are disposable noncanonical test content, not a canonical world map or mandatory quest chain.

## Player-facing capability

- **Journey from safe public landing to remote hazard (`D-006`, `D-007`):**
  - The player can board the scheduled public packet (`route.ship_estuary`) from the Courtyard (`region.playground`) to the safe landing at **Estuary Quay** (`region.estuary`).
  - At Estuary Quay, `a:estuary-boatman` lists the charted return packet (`route.ship_return`) alongside the hazardous outer passage (`route.ship_sunken_arch` → `region.shoal`). Selecting or attempting to board `route.ship_sunken_arch` displays a clear hazardous-destination refusal notice (`carrier_refuses_hazard`) without deducting coins, advancing world time, or stranding the player, explaining that no deep-hulled public packet will steer among the jagged outer shoals and pointing toward the low-water stone causeway at the east end of the quay (`a:shoal-causeway`).
- **World truth independent of player knowledge (`00-CONSTITUTION.md` §3, `D-004`, `D-005`):**
  - Objective world facts (`fact.causeway_exists: true`, `fact.arch_inscription_intact: true`) and physical entities in **Outer Shoal Ruins** (`region.shoal`: `a:shoal-causeway`, `a:shoal-return`, `a:sunken-arch`, `a:tidal-cache`, `a:shoal-pool`, `a:reef-warden`) exist from session start regardless of whether the player has spoken to any NPC.
  - **Discovery before rumor:** The player can walk directly across `a:shoal-causeway` (`claim.shoal_causeway` → `"confirmed"`) and inspect the weathered lantern arch (`a:sunken-arch`, `claim.arch_inscription` → `"confirmed"`). If the player later asks `a:estuary-boatman` about the outer shoals in Ink dialogue, `WorldTransaction.discover()` preserves `"confirmed"` certainty for `claim.shoal_causeway` rather than downgrading firsthand knowledge to `"heard"`, and `a:estuary-boatman` acknowledges that the player has already walked the causeway.
  - **Discovery after rumor:** Alternatively, the player can speak with `a:estuary-boatman` first (`claim.shoal_causeway`: `"heard"`, `claim.shoal_beacon`: `"heard"`), see `"Rumored approach"` / `"Rumored · Use to inspect"` indicators in `WorldView`, and then cross the causeway and inspect `a:sunken-arch` to confirm the physical truth (a dry bronze brazier and carved low-water tide-mark rather than the rumored magic flame) and report that observation (`report_arch`) back to the boatman.
- **Spatial exploration, avoidance, retreat, and optional combat (`D-008`, `D-016`, `A05`–`A07`):**
  - `region.shoal` features a central reef pillar obstacle (`x: 320..400, y: 150..260`) dividing a clear northern shelf (`y = 90`, with the brackish tide pool `a:shoal-pool`) from the southern drift-ledge guarded by `a:reef-warden` (`"Shoal crab"`, weak spot `"exposed shell seam"`, pattern `["heavy", "light", "heavy"]`) near the salt-crusted drift chest (`a:tidal-cache`, holding `item.river_lotus` and `item.vessel`).
  - Players can **avoid combat entirely** along the northern shelf to reach `a:sunken-arch` and fish at `a:shoal-pool`, **engage and retreat** (`RetreatCombat` or spatial outspacing/portal return) to the safe western ledge `(200, 290)` without requiring victory, or **exploit weak-spot windows** to defeat `a:reef-warden` and collect salvage from `a:tidal-cache`.

## Domain and cross-system invariants

- **No generic Exploration Manager:** Exploration is composed directly from existing `TravelRules`, `InteractionRules`, `NarrativeRules` + `InkDialogue`, `FishingRules`, `InventoryRules`, and `CombatRules`.
- **Provisional carrier hazard refusal (`D-053`):** `TravelRules` (`game/travel/travel_rules.gd`) validates an optional non-empty `"hazard_refusal"` string on route definitions and exposes `is_hazardous(route_id)` and `hazard_refusal_text(route_id)`. `TravelRules.board()` rejects hazardous routes with `"carrier_refuses_hazard"` before any fare transfer, active-journey write, or arrival scheduling. This proves the `D-007` public-carrier boundary cleanly without inventing a global danger-rating system, mandatory reputation gate, or private-vessel navigation framework.
- **Portal and landmark discovery presentation:** `NarrativeRules.discovery_claim(target_id)` exposes the authored claim ID for a discoverable portal or object so `WorldView` and `GameplayPlayground` can surface non-gating discovery state (`Explored`, `Rumored approach`, `Confirmed · Landmark`, `Rumored · Use to inspect`) and concise entry feedback (`"Entered Outer Shoal Ruins · Discovered: ..."`).

## Save and compatibility boundary

- The outer save container (`SessionCodec`, `RecoveryStore`, `WebSaveAck`) and all domain schema versions (`inventory: 1`, `economy: 1`, `work: 1`, `crafting: 1`, `interactions: 1`, `npcs: 1`, `narrative: 3`, `fishing: 1`, `farming: 1`, `law: 1`, `travel: 1`, `housing: 1`, `combat: 1`) are unchanged.
- `dev/fixtures/linked_world.json` adds `region.shoal`, its portals/objects/threat, `route.ship_sunken_arch`, `a:shoal-pool`, `a:estuary-boatman` Ink dialogue, and shoal facts/claims, changing the authored content fingerprint. Older linked-world development saves are preserved on disk and rejected safely by content-fingerprint checks; `GameplayPlayground` uses `"user://exploration-gameplay-playground"` with no migration claimed.

## Verification evidence

Executed `bash tools/test-headless.sh` on Godot Standard `4.7.2.stable.official.ed1daf0bf`:

- `FOUNDATION PASS: 892 assertions, 0 failures` (including `tests/test_exploration.gd` covering pre-rumor discovery, rumor-then-discovery, carrier hazard refusal atomicity, northern avoidance + tide-pool fishing, shoal crab engagement/telegraph/retreat/weak-spot victory, salvage collection, Ink reporting, and save/load round-trip)
- `GAMEPLAY UI PASS: 130 assertions, 0 failures` (including `_exploration_ui` in `tests/gameplay_ui.gd`)
- Separate-process write/read restart verification (`tests/restart.gd`) across **13 suites** (`foundation`, `gameplay`, `connected`, `regions`, `narrative`, `fishing`, `farming`, `web_ack`, `law`, `travel`, `housing`, `combat`, and `exploration`)
- Clean startup and `HEADLESS VERIFICATION PASS`

## Remaining boundaries

- Public carrier refusal (`hazard_refusal`) is a data-defined route property (`D-053`, Provisional); broader danger conditions, private decoratable boat ownership (`D-007`), and expanded adventure regions remain future scope.
- Detailed defeat/checkpoint rollback policy under `D-016` remains **Open** pending owner decision.
