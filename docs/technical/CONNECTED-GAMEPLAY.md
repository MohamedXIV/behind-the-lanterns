# Connected livelihood gameplay — Issue #14

Built code-first from main `4dce8e6212b81bda659b24086eb00b4f2e9bb557`.
Rules and player-facing integration were completed before the comprehensive tests
were added/run. Only import/compilation checks were used during implementation.

## Player capabilities

Accept optional supply deliveries near their giver, collect or buy materials,
prepare provisions at a bench over active-play seconds, find a scheduled recipient,
deliver and receive a one-time payment. Ordinary storage/trade remain available.
The journal supports abandonment. Preparation supports interruption, resumption,
cancellation and collection after making space. Wait controls advance the world
through NPC routines and job deadlines without simulating remote actors per frame.

## Connected rules and boundaries

- Inventory remains the sole goods ledger. Reservations lock quantities already
  in the bag, so they occupy capacity and cannot also be sold/delivered. Cancel
  simply unlocks them. Completion transforms the reserved inputs atomically.
- Commerce remains the sole currency ledger. Accepting work debits the giver into
  a payment hold; completion settles it, cancellation/expiry returns it. Outstanding
  refunds count toward balance limits so an expiry cannot overflow and block time.
- Work records one-shot offers per actor and durable completion/expiry evidence.
  Delivery requires actual unreserved goods, capacity, proximity, same region,
  recipient availability and completion strictly before the deadline.
- Consequential expiry uses the existing Scheduler/Coordinator at its exact due
  minute. Equal deadlines, retries and later failed events preserve transaction
  atomicity. No new transaction framework or foundation rebuild was introduced.
- NPC routines are immutable periodic in-region slot data, queried at world time.
  They control position/availability for trade and delivery. No remote actor Nodes,
  pathfinding, cross-region travel or history/event log is fabricated.
- Crafting uses active seconds, not WorldClock minutes or wall-clock absence.
  Leaving the station pauses progress. Progress is committed in small active chunks,
  flushed on explicit save/focus suspension; the view resumes saved work after load.
  Insufficient output space preserves a ready craft and its inputs until collection
  or cancellation. Inputs, progress, outcomes and receipts persist together.

These are bounded engineering choices for usable gameplay, not blanket approval of
the entire GDD. Recipe learning, skills and advanced crafting workflows are deferred.

## Executed verification

Godot Standard `4.7.2.stable.official.ed1daf0bf`, Linux x86_64:

```text
FOUNDATION PASS: 334 assertions, 0 failures
GAMEPLAY UI PASS: 28 assertions, 0 failures
GAMEPLAY RESTART write PASS
CONNECTED RESTART write PASS
RESTART write PASS
GAMEPLAY RESTART read PASS
CONNECTED RESTART read PASS
RESTART read PASS
HEADLESS VERIFICATION PASS
```

Run `GODOT_BIN=/path/to/Godot bash tools/test-headless.sh`. The combined command
imports the project, runs existing/new rules, actual input/button UI flows, fresh
processes for saved worlds, and application startup. It rejects Godot errors or
warnings even when the process exits zero. No GitHub Actions were added.

Coverage includes the complete collect–prepare–wait–deliver flow; duplicate reward
protection; reservation/trade interference; cancellation; ready-output capacity;
partial/ready preparation saves; NPC shop closure; equal deadlines; refund overflow
prevention; rollback when a later event fails; malformed cross-domain saves; and
restart with a held reward plus incomplete preparation, followed by safe completion.
Author review also checked transient same-minute event states and malformed status
types. A dependency type-inference error found in final execution was corrected.

## Compatibility and remaining limits

Inventory/Commerce schemas are now version 2; old development saves are rejected
rather than coerced. The connected playground uses `user://connected-gameplay-playground`
and preserves the previous profile. There is no production-save migration claim.
The original fixture remains available for regression coverage.

Headless input/UI behavior was verified, not final art or physical-device UX.
World time advances explicitly; the final active-play/world-time rate remains open.
Native manual saving is tested; automatic suspend-file saving, browser filesystem
sync, Android/iOS exports, device performance and BTL-specific Ink remain unverified.
Nearby movement still has no collision/navigation obstacles. NPC travel between
routine points is coarse. No farming, fishing, combat, unique-item state, recurring
job economy or generic quest/trait framework was added.
