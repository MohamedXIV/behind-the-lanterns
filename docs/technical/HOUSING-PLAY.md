# Housing, lodging access and constrained placement

Authority: locked D-013/D-033, GDD 08 §10, Issues [#9](https://github.com/MohamedXIV/behind-the-lanterns/issues/9) and [#14](https://github.com/MohamedXIV/behind-the-lanterns/issues/14). Base main: `9bffa81470d74f7927a929420b74897528c53d00`.

## Play the connected loop

Open the disposable playground. The workshop doubles as starting stable accommodation, with a storage chest, lamp and cushion. Housing is optional: existing work, fishing, farming and public travel continue to work.

Use the **Housing** tab. Approach the merchant and select **Optional inn room**, then **Arrange access**. This transfers the displayed coin cost once and grants occupancy/decorating access. The courtyard's inn door now admits the player. A modest property is a separate optional offer. These fixtures are bounded authored access grants; they do not establish rental duration, recurring rent, tenancy expiry or eviction policy.

Enter the workshop and tap a furnishing to approach its usable side. Select a furnishing and a numbered space in the Housing tab. The map outlines permitted cells and highlights the selected preview green/red; the panel reports invalid occupancy, rights, fit or usable-space errors. Confirm moves only after validation. The same touch controls work without precise dragging. Buttons are at least 48 logical pixels high and the panel scrolls.

Put ordinary goods in the travelling chest through **Goods → Store**. Pack it using Housing, visit the inn, and place it in a valid cell. It keeps the same physical entity and Inventory container ID with all goods. Packed storage is inaccessible; the former location cannot provide goods. Other furnishings are physical decorative instances without containers. Packing is a deliberate bounded relocation action rather than a general unique-item inventory framework.

## Integrity and boundaries

`HousingRules` owns occupancy grants and placed/packed references. Commerce alone owns coin wallets. Inventory alone owns goods and container capacity. `InteractionRules` resolves current furniture positions and enforces housing access before container interaction. Its Housing reference is weak, avoiding a RefCounted cycle.

All acquisition, pack and placement commands run in existing detached world transactions. Access, funds, provider reach/availability, source reach, destination permissions and the whole candidate are checked before commit. A rejected operation retains the exact original world, money and goods. Intent receipts prevent duplicate payment. Moving a full chest never destroys/recreates its container or transfers its goods.

Properties identify an authored region and floor index; the sample rooms are all floor zero. Cells specify fixed footprints. Candidate validation checks fit, solid geometry, bounds, distinct occupancy, separated cells, actor clearance, doorway/landing clearance and reachable routes among actors, doors, static interaction anchors and furnishing approach points. Dynamic collision geometry includes placed furniture; packed objects are omitted from picking/rendering. Invalid restore references, mismatched entity regions, undefined residents/cells, revoked occupied-room access, and inconsistent storage ownership reject.

This is a provisional implementation subset. No rotation, stacking, walls, physics construction, sleep/comfort bonuses, rent timer, eviction, public-release housing economy, farming permissions extension or multi-floor renderer is implied. Stable accommodation is a starting access grant, not permanent legal ownership. Broad tenancy policy, furniture acquisition/crafting and property title transfer remain deferred.

## Save compatibility

Optional `housing` domain v1 is added. Outer save container format and existing domain versions are unchanged. Housing definitions, rooms/entities and cells change the linked-world content fingerprint/domain set. Old linked-world prototype saves are rejected safely by existing compatibility checks, with no migration claimed. The playground uses `user://housing-gameplay-playground`, preserving earlier development profile files. Furniture identity, occupancy and packed/placed state survive save/load and process restart; Inventory retains contained items.

Implementation and review: [PR #29](https://github.com/MohamedXIV/behind-the-lanterns/pull/29). Directly tested implementation revision: `b10f6ca351b07375749b111bb2c2f062db54de08`; subsequent evidence-link edits change documentation only.

## Verification

Run from the checkout with Godot Standard `4.7.2.stable.official.ed1daf0bf`:

```sh
GODOT_BIN=/workspace/shared/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 bash tools/test-headless.sh
```

Godot 4.7.2 Linux x86_64 combined run passed: 739 regression/rule assertions, 95 gameplay/UI assertions, eleven separate-process write/read suites (including housing), and clean application startup; runner exited zero with `HEADLESS VERIFICATION PASS`. This workflow includes deterministic regression, actual Godot nodes/input/button signals, separate-process disk saves and application startup. No Web/mobile platform acceptance or named release is claimed.
