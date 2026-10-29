# First Godot runtime foundation — technical harness
**Status:** Implementation candidate, not production gameplay. See ADR-001.

## Structure
- `game/app`: a technical-only Main scene and GameSession composition (no production town).
- `game/world`: authoritative world minute, static factual truth, independent player knowledge.
- `game/simulation`: durable due-event descriptors plus chronological coordinator.
- `game/persistence`: JSON snapshot codec. **Not yet** device file I/O, reliable disk recovery, gameplay checkpoints or save migrations.
- `tests/fixtures`: disposable crop projection used to test lazy elapsed-time behavior. **Not** a farming system.
- `tests/run_all.gd`: bounded, headless contract checks. Not a mobile/Web/export acceptance suite.

## How to run
Install **Godot Standard 4.7.2** (not the .NET build), then from the repository root:
```sh
godot --headless --path . --script res://tests/run_all.gd
# or:
GODOT_BIN=/path/to/Godot bash tools/test-headless.sh
godot --path . --editor
```
The main scene is only a technical screen with an in-game day-advance button.

## What the tests should establish
- A secret physically exists regardless of rumors and survives world-time advancement.
- Events in an unloaded world model execute chronologically, with stable same-time ordering.
- A distant crop may be evaluated after five in-game days without simulating every frame.
- JSON snapshot/restore retains world state and separate player knowledge.
- Completed event identities do not re-execute after load; pending ones still do.
- Invalid time, save version and missing handler are rejected.
- Separate sessions never share world-state dictionaries.

## Deliberate limits
- **No full Farming, Inventory, Crafting, Fishing, NPC or Ink runtime implemented.** The crop is an explicitly disposable proof fixture.
- Scheduler uses a small linear scan when *advancing time*, not every frame. A heap is premature until profiling.
- Handlers must validate and apply coherent state changes; the coordinator marks completion after success. Failure poisons the current in-memory GameSession against further advancement/saves; reload last committed snapshot. A future transaction layer must cover rollback/atomicity before live economic effects.
- No persistence-to-disk yet. JSON snapshot codec does not implement mobile-safe save writes, recovery, encryption or defeat checkpoint policy.
- No export templates, Android SDK or device integration included. Actual Web and native builds still require hands-on verification.
- Domain-specific condition histories (weather, soil moisture), subscription by world-event rather than due timestamp, cancellation/retry strategies, and large skip aggregation are **not implemented**.
- This is a foundation, not a vertical slice. Do not build game content directly into these fixtures.
