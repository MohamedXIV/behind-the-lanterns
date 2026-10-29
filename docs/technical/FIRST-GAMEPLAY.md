# First gameplay increment — collect, store, trade

Tracks #12. Owner authorized autonomous gameplay engineering on 29 October 2026.
PR #11 was reviewed against its exact head, rerun in Godot and merged; #10 was
closed as superseded. Keep the foundation and introduce only concrete gameplay needs.

## Scope and engineering decisions

- One canonical commodity ledger, keyed by persistent container entity and item
  definition. Identical goods aggregate; stack limits determine occupied slots.
  Stateful/unique items are deferred instead of allocating an entity per fruit.
- Inventory owns quantities/capacity. Commerce owns finite wallets and authored
  merchant buy/sell prices. Interactions own actor positions and validate region,
  reach and container access before calling those concrete services.
- Take/store/buy/sell are direct commands in the existing transaction. Goods and
  money commit together, including failures and duplicate intent retries.
- Container access permission is not legal item ownership or a theft/law system.
- A small Godot playground uses disposable JSON, keyboard walking, tap-to-walk,
  explicit quantity/actions and native Save/Load. No final city, story, art or
  production movement/collision architecture is implied by its presentation.
- Active walking is scene-local; stop, action and save commit the position. This
  avoids copying the whole session or retaining an intent receipt every frame.
  World-time conversion, needs and actual travel remain open.
- The existing content fingerprint must also bind gameplay definitions. Add an
  optional rules-content argument to WorldDefinition.create, preserving the
  legacy fingerprint when unused. No other foundation redesign is justified.

This is a technical implementation choice, not approval of all GDD 08 proposals.
Simple configurable slot capacity and one currency are sufficient for this batch.
No spoilage, reservations, recipes, jobs, dynamic prices or compulsory progression.

## Implementation/verification plan

1. Test finite transfer, stacking/capacity and failed-operation conservation first;
   implement InventoryRules with data-only state and strict restore validation.
2. Test paid trade, affordability, stock, quote and cross-domain rollback; implement
   CommerceRules and InteractionRules with proximity/access checks.
3. Compose via GameplayModel; include gameplay definitions in fingerprint; verify
   save/load, repeated intent and a second content fixture.
4. Add a disposable playable Godot presentation; exercise its actual commands and
   movement, then run the complete existing and new tests in Godot 4.7.2.
5. Review concrete failure/extension cases, record evidence here and deliver one PR.

## Executed result

Godot Standard `4.7.2.stable.official.ed1daf0bf`, Linux x86_64:

```text
FOUNDATION PASS: 242 assertions, 0 failures
GAMEPLAY UI PASS: 15 assertions, 0 failures
GAMEPLAY RESTART write PASS
RESTART write PASS
GAMEPLAY RESTART read PASS
RESTART read PASS
HEADLESS VERIFICATION PASS
```

Command: `GODOT_BIN=/path/to/Godot bash tools/test-headless.sh`.
The 242-assertion suite includes the existing foundation and 66 new gameplay checks.
The wrapper also imports the project and runs application startup, failing on any
Godot error/warning even if its process exit code is zero. No GitHub Actions added.

Verified finite transfer/conservation, implicit stack packing, bag and merchant
capacity, access/region/reach, stock/funds, price bounds and quote rejection,
duplicate sales, malformed definitions/state, numeric/position roundtrip, alternate
content, actual mouse/keyboard/screen-touch input and action/Save/Load buttons.
Separate processes verified gameplay depletion, custody, coins, position and receipts.

Author review (not independent peer approval) corrected JSON numeric normalization
and a peer-wallet validation-order dependency, with failing cases reproduced before
fixes. The only foundation change is the optional authored-rules fingerprint input.
Inventory and Commerce remain concrete peers, not a new generic transaction engine.

## Limits and next increment

This UI is a disposable development fixture; no visual/art approval or on-device
touch acceptance is claimed. Walking has no collision/navigation obstacles, commits
on stop/action/save, and does not set the final world-clock rate. Saving is explicit;
automatic mobile suspension saving is not yet connected. Native manual recovery is
tested; Web filesystem synchronization, Android/iOS exports and device performance
remain unverified. The existing native store still rejects Web save requests.

Ordinary commodities only: no unique-item state, reservations, property leases,
legal ownership/theft, dynamic prices, crafting, growth, NPC behavior or Ink adapter.
The most useful next increment is an optional delivery/small job with one-time
completion evidence and a finite reward, reusing these item and wallet rules.
