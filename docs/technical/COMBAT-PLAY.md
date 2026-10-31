# Lightweight Non-Guard Combat & Retreat (`CombatRules`, `CombatPanel`, `WorldView`)

**Date:** 31 October 2026  
**Design Authority:** `docs/00-CONSTITUTION.md` (§5, §6, §7), `docs/DECISIONS.md` (`D-008`, `D-009`, `D-016`, `D-052`), `docs/03-GAMEPLAY-SYSTEMS.md` ("Adventure, stealth and combat"), `docs/05-PRODUCTION.md` (`F4`), `docs/07-SYSTEM-CATALOG.md` (`A06`, `A07`), [Issue #14](https://github.com/MohamedXIV/behind-the-lanterns/issues/14).

---

## 1. Purpose & Scope

This batch establishes the game's first playable real-time skill-based combat and retreat loop against an authorized **non-guard threat**:

1. **Readable Telegraphs & Skill-Over-Stats Timing (`D-008`, `GDD 03`):**
   - Threats cycle through deterministic attack patterns (`"light"` vs `"heavy"`) with distinct windup windows (`light_windup_ms`, `heavy_windup_ms`) and visual/textual cues (`LIGHT LUNGE WINDUP` vs `HEAVY SWEEP WINDUP`).
   - Blocking (`PlayerInput.BLOCK` / `F` / `TouchGuard` / `BlockThreat`) or dodging (`PlayerInput.DODGE` / `Q` / `TouchEvade` / `DodgeThreat`) a light lunge prevents all damage and opens a bounded `"vulnerable"` weak-spot window (`weak_spot_ms`).
   - Against a heavy sweep (`"heavy_windup"`), `Block` only partially mitigates the blow (taking chip damage without opening the weak spot), whereas `Dodge` or spatial outspacing (`engage_range < distance <= disengage_range`) completely evades the attack and exposes the threat's weak spot (`weak_spot_label`).
   - Striking (`PlayerInput.PRIMARY_ACTION` / `R` / `TouchStrike` / `StrikeThreat`) during the `"vulnerable"` window deals `weak_spot_damage` (`2`) and staggers the threat back to `"poised"`, whereas greedy strikes during an active windup glance off (`0` damage).
2. **Retreat / Escape as a First-Class Outcome (`00-CONSTITUTION.md` §5, `D-008`):**
   - Players do not need to defeat a hostile creature to resolve an encounter.
   - Pressing `Retreat / Escape` (`RetreatCombat` / `retreat_combat`) relocates the player to the region's authored safe `retreat_point` and resolves the encounter as `status = "retreated"`.
   - Walking or running beyond `disengage_range` (`move_actor`) or stepping through a doorway/portal (`enter`) automatically disengages the encounter via `CombatRules.sync_spatial` (`status = "retreated"`, `last_event = "spatial_retreat"`).
3. **Non-Negotiable Guard Invariant (`00-CONSTITUTION.md` §6, `D-008`, `D-009`):**
   - City guards, soldiers, and watchmen (`LawRules.is_guard(id)`) are **never** ordinary damageable combat targets.
   - `CombatRules.create` rejects any threat configuration referencing a guard entity ID.
   - `CombatRules.engage` and `CombatRules.strike` fail closed with `"guard_not_combat_target"` if passed a guard ID.
   - Triggering `PlayerInput.PRIMARY_ACTION` (`R` or `TouchStrike`) near a guard in `GameplayPlayground` continues to route directly to `LawRules.confront_guard` (scripted arrest and transfer to `region.watchhouse`).
4. **Provisional Defeat / Recovery Boundary (`D-016` Open):**
   - Because the exact checkpoint/autosave rollback penalty on defeat remains **Open** under `D-016`, zero player health transitions to a bounded, non-destructive `"winded"` state at the safe `retreat_point` (`last_event = "winded"`) without deleting saves or inventing unapproved rollback penalties. Players can press `Catch Breath` (`recover_combat`) or load a prior save.

---

## 2. Transactional Domain Contract (`game/combat/combat_rules.gd`)

- **Domain ID:** `"combat"` (`SessionDomain` version `1`).
- **Configuration Schema (`data.combat`):**
  - `actor_max_health`: integer (`1..20`)
  - `base_strike_damage`: integer (`1..10`)
  - `weak_spot_damage`: integer (`base_strike_damage + 1..20`)
  - `threats`: dictionary keyed by entity ID, each containing:
    - `label`, `weak_spot_label`: non-empty strings
    - `max_health`: integer (`1..50`)
    - `engage_range`: float (`40.0..320.0`)
    - `disengage_range`: float (`engage_range + 24.0..600.0`)
    - `poised_ms`, `light_windup_ms`, `heavy_windup_ms`, `weak_spot_ms`: integers (milliseconds)
    - `light_damage`, `heavy_damage`: integers (`heavy_damage >= light_damage`)
    - `pattern`: non-empty array of `"light"` / `"heavy"` strings
    - `retreat_point`: walkable `{"x", "y"}` coordinates in the threat's region
- **Persisted State (`snapshot.domains.combat`):**
  - `next_encounter`: monotonic encounter ordinal counter
  - `encounters`: dictionary keyed by `actor_id` with `threat_id`, `ordinal`, `status` (`"engaged" | "victory" | "retreated" | "winded"`), `actor_health`, `threat_health`, `phase` (`"poised" | "light_windup" | "heavy_windup" | "vulnerable" | "resolved"`), `elapsed_ms`, `step`, `defense` (`"none" | "dodge" | "block"`), and `last_event`.

---

## 3. Disposable Encounter Fixture & UI Integration

- **Disposable Fixture (`dev/fixtures/linked_world.json`):**
  - Adds `"a:reed-stalker"` (`"Reed stalker"`, definition `"actor.threat"`) at `(680, 340)` in `"region.river"` (`engage_range: 120`, `disengage_range: 180`, `retreat_point: {"x": 460, "y": 330}`, `weak_spot_label: "unarmored flank"`).
  - Positioned on the eastern riverbank so peaceful western riverbank activities (`a:reed-bank`, `a:river-bed`) remain undisturbed outside `disengage_range`.
- **Presentation & Controls:**
  - `CombatPanel` (`game/combat/combat_panel.gd`): sidebar tab (`Combat`) with touch-sized (`>= 48px`) buttons (`EngageThreat`, `StrikeThreat`, `DodgeThreat`, `BlockThreat`, `RetreatCombat`, `RecoverStance`), timing progress bar (`CombatTiming`), and telegraph/weak-spot readouts (`CombatStatus`, `CombatTelegraph`, `CombatFeedback`).
  - `TouchControls` (`game/input/touch_controls.gd`): on-screen landscape action cluster includes `TouchEvade` (`PlayerInput.DODGE`), `TouchGuard` (`PlayerInput.BLOCK`), and `TouchStrike` (`PlayerInput.PRIMARY_ACTION`).
  - `WorldView` (`game/world/world_view.gd`): renders threat engage/disengage rings, amber light-windup rings, crimson heavy-windup rings, emerald weak-spot indicators, and player guard/evade stance rings.

---

## 4. Save Compatibility & Verification

- Adding the optional `combat` domain v1 and `a:reed-stalker` entity to `dev/fixtures/linked_world.json` changes the linked-world domain set and content fingerprint.
- `GameplayPlayground.RECOVERY` uses `"user://combat-gameplay-playground"` so prior prototype saves remain untouched on disk and fail closed if loaded into an incompatible session (`docs/VERSIONING.md`).
- Verified via `bash tools/test-headless.sh` across `tests/test_combat.gd`, `tests/gameplay_ui.gd` (`_combat_ui`), and `tests/restart.gd` (`_combat_restart`).
