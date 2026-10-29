# ADR-002 — Transactional session foundation

**Status: Implementation decision proposed for review in this PR** · 2026-10-29.
Refines ADR-001; no gameplay scope or tuning is ratified by implementation.

## Evidence and audit

Inspected main `4a1f4821b77c9cd3b6c36effdc1e92dc86b1d5f3`, Constitution,
GDDs 01–09, Decision Register, issues #2–9 and PR #10 at
`a3d5c37e2d69f702e1b9faed405d96d1cf674b50`. Main contains documentation only.
PR #10 is an unexecuted candidate, not an ancestor of this implementation.

Confirmed design: persistent authored sandbox; independent world truth/knowledge;
scheduled consequential, lazy and static policies; no offline attendance clock;
GDScript/Standard 4.7.2, mobile/Web, Ink and content-light verification.
Technical choices below are this engineer's proposals. Day length, needs, crop
failure, craft cancellation, defeat rollback and launch scope remain open.

PR #10's public mutable clock/stores permit bypassing chronology. Its handlers
can partially mutate state before failing, while an unsafe flag merely prohibits
saving. That does not provide recovery, atomic effects or a reliable extension
contract. Event IDs alone do not make external effects exactly once. Its JSON
restore does not establish complete domain/identity consistency or disk recovery.

Kiosk reference: inspected README, `game/time/world_scheduler.gd`,
`simulation_coordinator.gd`, `tools/dependencies.lock.json`, and
`addons/inkgd/LOCAL_PATCHES.md`. Carry forward candidate restore, stable IDs,
captured job parameters and exact story hashes. Do not copy its tick graph,
blocked-jobs-allow-time-through policy or broader gameplay state. Ink pin:
`ephread/inkgd@fea9098ee18d6cdbe9a5e25f8f0296bcdf0fd96a`, inklecate 1.2.1.
The local string-reader optimization must be reviewed when vendoring; replacing
Ink's parser with Godot JSON can lose Ink integer semantics. This PR does not
vendor Ink or claim BTL narrative/export verification.

## Alternatives

1. Mutate live services with manual rollback: lower copy cost, but every future
   cross-domain operation must correctly undo every write and callback.
2. **Detached candidate + one publish:** chosen for a small foundation. Copy cost
   is explicit; failures cannot leak canonical writes. No undo journal/framework.
3. Event sourcing/database: excessive operational/schema complexity for this game.

## Lifetimes, ownership and composition

Main is the app-lifetime Node and sole composition root. One GameSession is the
current save/run. Plain RefCounted services have no SceneTree/global lookup.
WorldDefinition is validated immutable authored content shared by a session;
SessionDomain objects are stateless rules, manually supplied by the root.
Their mutable data lives only in the committed session snapshot. A transaction
owns detached clock, scheduler, entity registry, knowledge and domain data.
Region Nodes/UI hold session references and stable IDs, never canonical state.
Replacing/closing a session requires retiring old scene references; no Autoloads,
timers, global event bus or DI container are introduced.

Queries return deep copies. A transaction is single-threaded, synchronous and
must not await, do I/O, mutate Nodes/other services, call Ink continuation or emit
signals. It receives only a detached WorldTransaction. Retaining this object
cannot mutate a published session because publication copies again. GDScript
privacy is conventional, not a security sandbox; underscore members are internal.
Domain validators are pure and see copies. Unknown domains/kinds fail closed.
Each registered kind also requires `validate_event`: descriptor schema and stable
references are checked on commit AND load, including terminal records. Current
business eligibility belongs to execution, not this structural validator.
Domain registration is fixed at creation; no mid-session registry changes.

Commands are direct typed domain methods called inside `session.transact(id,
callable, target)`. A retained command receipt prevents repeated intent IDs.
Use a new ID for a new action; reuse one only for retry of the same intent.
Successful commits emit one session-local `committed(revision)` notification.
No gameplay mutation is permitted in notification callbacks; reentrancy is rejected.
There are no durable signal subscriptions; scheduled records carry those intents.

## Time, scheduler and commit contract

WorldClock owns integer world minutes in a detached transaction. Range is
0..2147483647; day=minute/1440+1. Precision is an engineering choice, not day-length
tuning. All progression enters GameSession, including future play/sleep/travel/jail.
No OS clock, `_process` conversion, active craft timer or automatic retry loop.

Events contain stable occurrence ID, kind, target entity ID, due minute, JSON-only
payload, insertion sequence and pending/completed/cancelled status. Every target
must resolve even if its region has no loaded Node. Ordering is `(due, sequence)`;
sequence is unique, durable and monotonic. No priority system is justified yet.
A handler scheduling at its current minute appends behind already queued peers.
Scheduling in the past and reusing any occurrence ID are rejected. No terminal
record pruning until a future explicit retention/migration policy exists.

One request clones the committed state, applies its command (if any), visits
events chronologically at their actual due timestamps, validates after every
event and at target, then publishes clock, effects and receipts together.
The command runs at the start minute; future arrival effects are scheduled, not
applied early. An explicit target lets payment + travel advance + arrival commit
together. A command may cancel a pending event before draining the target.
Events at the target are included; `advance_to(now)` drains same-minute events.

Any handler/validation failure, missing handler, invalid target or event budget
exhaustion discards the WHOLE request, including earlier successful candidate
events. Return code/event ID identifies the blocking work. Live state remains
saveable. Caller chooses retry, smaller target, repair or explicit cancellation;
time never silently passes a failed consequence. A cancelled event is an explicit
domain decision, not a generic expiry. Bounded dispatch prevents event storms.
Failed mutators invalidate the candidate even if a caller ignores their return.
Plan alternatives with read-only queries before mutating; a failed write is not a
try-and-continue operation. An executing occurrence cannot cancel itself.

Logical at-most-once effects follow from terminal event records and atomic
publication with domain effects. Retries after failed requests can rerun pure
handlers but cannot duplicate committed effects. This promises no exactly-once
network/payment/analytics delivery. Future external effects need a durable outbox
and acknowledgments; they are prohibited in foundation callbacks.

## Identity, definitions and lazy state

WorldDefinition declares regions, definition IDs, authored entities (`a:` prefix),
static fact IDs and semantic claim IDs. A claim can be false without creating a
world fact. Runtime IDs use `r:<monotonic counter>` within a persistent world ID.
Counters/registry survive save/load; IDs never depend on NodePath/scene instance.
Region moves preserve identity. Deletion/reuse is intentionally absent; future
deletion needs tombstones and reference policy. No generic component/trait model.

Static facts live in immutable content, not tick handlers. Saves bind to the
exact content fingerprint and domain schema versions; unknown/removed IDs reject
the candidate. Compatible updates require a deliberate migration, not coercion.
No migration is claimed for PR #10's unmerged schema.
The minimal knowledge record uses heard/confirmed claim awareness only; provenance,
contested beliefs and narrative binding remain F2 design work. This representation
does not ratify a complete semantic-knowledge model.

Domains own their record schema, business invariants, reconciliation and RNG
state. Lazy queries project from anchors/history without writes; command/event
handlers reconcile only needed records to `tx.now()`. Never project to skip-end
before resolving an earlier dependency. Variable weather/care requires interval
history; elapsed subtraction alone is only valid under constant conditions.
Persist RNG streams/results in domain state; 64-bit generator states should use
decimal strings to avoid JSON precision loss. Cosmetic randomness is separate.
JSON normalization restores safe integral numbers as integers; continuous-value
domain validators must accept both integer and floating numeric representations.

## Persistence and recovery

Save schema includes version, world ID, content fingerprint, revision, clock,
allocator, entities, knowledge, domains/schema versions, events and command receipts.
Strict data validation rejects unsupported types, nonfinite/unsafe numbers,
fractional counters, missing/extra keys and inconsistent timelines/references.
Codec hashes the exact payload string, then parses/normalizes into a NEW session
using freshly composed rules. Never restore over a live session. Checksums detect
accidental corruption, not malicious tampering/authenticity.

Native RecoveryStore writes an inactive A/B generation via temp file, flush,
readback validation and rename. The last valid slot remains intact on failure.
Load selects the newest fully valid candidate and falls back to the older slot;
orphan temp files are ignored. Save failure is returned, never disguised as success.
Native flush/rename does not promise hardware-fsync power-loss durability.
One writer owns a recovery directory. Equal generations with different payloads
fail closed; wholly invalid existing slots are not overwritten by an ordinary save.
Web requires a platform-specific asynchronous persistent-filesystem sync/ack;
this native store explicitly rejects Web until that adapter is verified.
Mobile kill/device/export and browser retention remain separate acceptance work.
Technical recovery slots do not define gameplay defeat checkpoints.

## Future domain integration (contracts, not scaffolding)

| Domain | Owns | Uses |
| --- | --- | --- |
| Inventory | item instances, containers, single custody, transfers | entity IDs; validated atomic commands |
| Farming | plot/crop anchors, care/environment history, harvest evidence | lazy projection at event time; Inventory command in same transaction |
| Fishing | active action result/bait policy | atomic bait/catch commit; no independent item ledger |
| Crafting | active-play progress, reserved inputs, learned recipes | Inventory and atomic completion; no offline timer |
| NPC | schedule data/exceptions and persistent location | pure routine lookup; consequential appointments scheduled |
| Knowledge/Ink | awareness vs story cursor/hash | read-only world context; validated commands with occurrence IDs |

An Inventory transfer can update two containers and an Economy balance inside
one candidate. Validators enforce custody/payment invariants before publication.
Shared services call concrete peers, not arbitrary event broadcast. No full
Inventory/Farming/Fishing/Crafting/NPC implementation is part of this decision.
Ink cursor/choices and its command receipt must join the same commit to avoid
story/world divergence; advancing a live Ink runtime inside a transaction is
forbidden. The future adapter must stage/restore cursor by exact story hash.

## Extension hazards / deliberate limits

Full snapshot copies, linear queue search and retained receipts are simple but
cost memory/time as a sandbox grows. Profile representative sizes before indexing,
partitioning, copy-on-write or pruning. Event handlers are trusted synchronous
code; Godot script errors are programming defects, not catchable domain failures.
Validation at publication and native tests do not prove mobile/Web performance.
No production gameplay, content pipeline, UI or export acceptance is claimed.
