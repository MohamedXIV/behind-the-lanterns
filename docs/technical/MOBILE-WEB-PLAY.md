# Mobile-First Player Interaction & Web Persistence — Verification Evidence

## Scope and Authorization

- **Issues:** [#6 — Mobile-first player interaction and input abstraction](https://github.com/MohamedXIV/behind-the-lanterns/issues/6), [#2 — F0: Decide Godot language, DI/lifetimes and Ink/mobile compatibility](https://github.com/MohamedXIV/behind-the-lanterns/issues/2), and [#14 — Connected gameplay batches](https://github.com/MohamedXIV/behind-the-lanterns/issues/14).
- **Design & Architecture Authority:**
  - `docs/00-CONSTITUTION.md` (§5 Mobile-first landscape touch controls; §6 Extensible systems with replaceable fixtures)
  - `docs/DECISIONS.md` (`D-014`, `D-022`, `D-023`, `D-026`, `D-027`, `D-037`, `D-038`, `D-047`)
  - `docs/03-GAMEPLAY-SYSTEMS.md` & `docs/04-ART-TECH.md` (mobile landscape ergonomics, safe-area layout, pause/resume)
  - `docs/07-SYSTEM-CATALOG.md` (`P01` Mobile-first input & interaction, `A01` Combat/evasion action intents, `X01` Accessibility & UI scaling, `X02` Flexible layout containers)
  - `docs/adr/ADR-001-RUNTIME-FOUNDATION.md` & `docs/adr/ADR-002-TRANSACTIONAL-FOUNDATION.md` (two-slot A/B recovery and Web IndexedDB `/userfs` persistence acknowledgment)

---

## Implemented Capabilities

1. **Mobile-First Input Abstraction (`game/input/player_input.gd`, `class_name PlayerInput`):**
   - Registers and manages semantic actions in Godot's `InputMap` (`btl_move_left`, `btl_move_right`, `btl_move_up`, `btl_move_down`, `btl_run`, `btl_interact`, `btl_talk`, and decoupled combat/evasion action intents `btl_dodge`, `btl_block`, `btl_primary_action`) without coupling gameplay logic to physical keys or specific UI buttons.
   - Supports runtime keyboard remapping (`remap_key`, `bound_keys`, `reset_default_bindings`) with validation against unknown actions and invalid keycodes.
   - Combines virtual touch directional inputs (`set_touch_button`, `set_touch_vector`) with keyboard/action vectors, normalizes diagonal movement to unit length, and provides a toggleable/momentary running pace multiplier (`WALK_SPEED_MULTIPLIER = 1.0`, `RUN_SPEED_MULTIPLIER = 1.65`).
   - Provides `release_all()` to clear held touch buttons, vectors, and queued intents whenever the application pauses or loses focus.

2. **Landscape On-Screen Touch Controls & Accessibility (`game/input/touch_controls.gd`, `class_name TouchControls`):**
   - Provides touch-sized (`>= 48px` minimum height) directional pad buttons (`TouchLeft`, `TouchUp`, `TouchDown`, `TouchRight`), a latching `TouchRun` pace toggle (`Run: Off` / `Run: On`), and context/evasion action buttons (`TouchUse`, `TouchTalk`, `TouchEvade`).
   - Supports one-tap visibility toggling (`TouchVisibility`: `Touch: On` / `Touch: Off`) and left/right-handed layout swapping (`SwapHands`: `Hands: R` standard D-pad-left / actions-right vs `Hands: L` swapped actions-left / D-pad-right).

3. **Safe-Area Insets, Compact Landscape Viewports & Suspend/Resume Lifecycle (` game/world/world_view.gd`, `dev/gameplay_playground.gd`, `project.godot`):**
   - Configures `window/stretch/aspect="expand"`, `window/handheld/orientation=0` (landscape), and `pointing/emulate_touch_from_mouse=false` in `project.godot`.
   - `PlayerInput.compute_safe_margins(viewport_size, safe_rect, base_margin)` and `GameplayPlayground.apply_viewport_layout(...)` adapt outer margins to hardware display cutouts (`DisplayServer.get_display_safe_area()`) and switch to compact landscape geometry on smaller screens (e.g., `844x390` and `800x480`).
   - `WorldView` and `GameplayPlayground` handle `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_APPLICATION_RESUMED`, `NOTIFICATION_APPLICATION_FOCUS_OUT`, and `NOTIFICATION_WM_WINDOW_FOCUS_OUT` by halting active movement, releasing held inputs, flushing active preparation/fishing progress, and committing the actor's safe position.

4. **Browser Save Durability & IndexedDB (`/userfs`) Acknowledgment (`game/persistence/web_save_ack.gd`, `game/persistence/recovery_store.gd`):**
   - `WebSaveAck` provides a read-only IndexedDB `/userfs` `FILE_DATA` verification bridge (`window.__btlSaveAck`) with monotonic `writeId` protection against stale callbacks and a `beforeunload` warning while a flush is in flight, paired with `JavaScriptBridge.force_fs_sync()`.
   - **Strict Completion/Failure Boundary:** `WebSaveAck.sync_and_verify()` and `RecoveryStore.save()` never report success while IndexedDB verification is `"pending"` (synchronous `save()` fails closed with `web_sync_pending` and rolls back the unconfirmed slot).
   - **Delayed Asynchronous Polling & In-Flight Guards:** `RecoveryStore.begin_save()` + `poll_save(step_ms)` support multi-frame IndexedDB commits, reject overlapping saves with `web_save_in_flight`, ignore unconfirmed in-flight slots during `load_candidate()`, and roll back unconfirmed slots on error (`web_sync_failed`) or timeout (`web_sync_timeout`) while preserving prior confirmed A/B generations.
   - Added `tools/export-web.sh` to automate `Web smoke` export when Godot 4.7.2 Web export templates are installed and report an explicit blocker code when templates are absent.

---

## Platform & Environment Assessment (Honest Evidence vs Blockers)

| Check | Status | Evidence / Environment Blocker |
| --- | --- | --- |
| Godot Standard 4.7.2 headless regression, UI & restart suite | **Verified** | `bash tools/test-headless.sh` passes with 0 errors and 0 warnings (`FOUNDATION PASS: 601 assertions, 0 failures`, `GAMEPLAY UI PASS: 69 assertions, 0 failures`, 8 multi-process `RESTART` suites). |
| `inkgd` + GDScript runtime compatibility | **Verified (desktop headless)** | Real Ink stories compile and execute through `NarrativeRules` and `ConversationPanel` in Godot 4.7.2; reference project `MohamedXIV/kiosk-on-the-nile` confirms the same GDScript `inkgd` runtime on Godot 4.7.2 Web. |
| Web persistence (`RecoveryStore` + `WebSaveAck`) contract | **Verified (simulated IndexedDB `/userfs` + restart)** | Tested persistent A/B slot rotation, byte-level `/userfs` `FILE_DATA` verification, non-persistent storage rejection (`web_storage_unavailable`), and rollback on sync failure (`web_sync_failed`). |
| Actual `.wasm`/`.pck` Web export & live browser execution | **Blocked in container** | `~/.local/share/godot/export_templates/4.7.2.stable/web_nothreads_*.zip` and browser binaries (`chromium`/`firefox`) are not pre-installed in this container (`tools/export-web.sh` exits with code 2 diagnostic). |
| Physical Android / iOS / mobile browser device testing | **Blocked in container** | No physical device, Android SDK/NDK, `adb`, or iOS toolchain is attached to the container environment. |
