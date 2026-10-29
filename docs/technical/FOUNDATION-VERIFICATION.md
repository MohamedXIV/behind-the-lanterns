# Foundation verification and author review — 29 October 2026

## Executed environment

Linux x86_64, **Godot Standard `4.7.2.stable.official.ed1daf0bf`**.
Official Linux archive SHA-256:
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.
It matches the checksum inspected in Kiosk's pinned dependency manifest.

Command from repository root:

```sh
GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64 bash tools/test-headless.sh
```

Observed output (engine banners omitted):

```text
Engine: 4.7.2.stable.official.ed1daf0bf
FOUNDATION PASS: 176 assertions, 0 failures
RESTART write PASS
RESTART read PASS
HEADLESS VERIFICATION PASS
```

The wrapper also executed a fresh editor import and main-scene startup smoke.
No script errors, engine errors, warnings or leaked-resource reports were present.
It explicitly rejects these diagnostics even when Godot returns exit code zero.
There is no GitHub Actions result or mobile/Web export result implied here.

## What was verified

| Contract | Executed evidence |
| --- | --- |
| Static truth/independent awareness | Passage exists before rumor and after five-day skip; false rumor creates no world fact |
| Identity | Authored namespace rejection, runtime allocation, persistent moves, unknown region rejection, two definition fixtures |
| Chronology | Out-of-order enqueues, inclusive boundaries, persisted FIFO ties, observed same-minute causal chains |
| Lazy/scheduled interaction | Early sale sees unripe crop; due-time mature sale commits harvest/payout without offscreen frames |
| Atomic failure | Two-domain handler changes, child enqueue and earlier event all discarded with failed skip |
| Idempotence | Terminal occurrence reuse rejected, repeated intent suppressed, receipts retained across load/restart |
| Safe operations | Negative/backward/oversized time, fractional event times, unknown kind/target, non-data payload, malformed command result |
| Isolation/lifetime | Retained candidate and query-copy mutations cannot touch live state; nested/notification mutation rejected; root replacement closes stale sessions |
| Event storms | Same-minute chain hits configured budget and rolls back whole request |
| Restore validation | Wrong types, unsafe/nonfinite/fractional counters, null fields, schema/content/world/domain mismatches, malformed payloads, stale timelines and duplicate sequence IDs |
| Native recovery | Newest valid slot, corrupt/truncated fallback, ignored orphan temp, actual rename failure, previous generation preserved, repaired retry and existing inactive-file replacement |
| Ambiguous storage | Equal generations with different payloads reject load and preserve files |
| Separate processes | Disk save in process A; process B restores time, awareness, allocator, intent/event receipts and only executes pending work |

## Critical author review

Performed as a separate review pass by the sole implementing engineer, per the
request. This is **author review**, not an independent reviewer or owner approval.
No Critical/Important findings remain known after the fixes below and the full run.

- Rejected PR #10's mutate-then-mark-unsafe model; whole-request candidate rollback
  is now executable, including a failure after an earlier event succeeded.
- Found that an ignored failed sub-operation could allow partial command success.
  Added a failing regression, invalidated failed candidates, reran green.
- Found type comparisons on malformed numeric fields could raise Godot script errors.
  Reordered validation, expanded malformed-state cases and reran green.
- Found generic event schema checks would accept a registered kind with an invalid
  domain payload. Added a failing restore case and required domain descriptor validation.
- Reviewed same-time causality by observed fixture effects, not only queue metadata.
- Reviewed root replacement, stale references and signal reentrancy; no durable
  scene connections or background Node simulation are introduced.

The two small clock/result files express real contracts; no empty gameplay managers
were created. SessionDomain is the only rules-extension protocol, not a DI container,
generic trait engine, event bus or universal gameplay action language.

Tradeoffs retained deliberately: complete candidate copies, linear queue search,
full validation and unpruned receipts. They favor inspectable correctness for this
batch. Profile representative save/event volumes before changing them. Validators
and handlers are trusted synchronous code; underscore privacy is conventional.
They cannot safely perform external side effects. No general event-dependency DAG,
retry worker, migration framework or world-history engine is justified yet.

## Explicitly unverified / follow-up scope

- Android/iOS export, suspend/kill behavior and physical device performance.
- Web export and asynchronous persistent-filesystem sync/acknowledgment; the native
  RecoveryStore refuses Web instead of claiming browser durability.
- BTL-specific inkgd integration, semantic command bridge and transactional story
  cursor/hash restoration. Only Kiosk's pin and lessons were inspected.
- Actual gameplay Inventory/Farming/Fishing/Crafting/NPC systems, variable-environment
  histories, active-play clock conversion and defeat/checkpoint policy.
- Full save-size/event-volume profiling and adversarial input security hardening.

Issues #2, #3 and #4 are partially advanced, not closed. PR #10 was neither merged
nor modified. This evidence supports review of the bounded runtime foundation;
it is not a claim that the complete game or target platforms are production-ready.
