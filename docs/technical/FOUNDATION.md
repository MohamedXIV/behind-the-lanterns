# Runtime foundation integration

Read [ADR-002](../adr/ADR-002-TRANSACTIONAL-FOUNDATION.md) for reasoning and invariants,
and [executed evidence](FOUNDATION-VERIFICATION.md) before judging readiness.

## Code map

| File | Responsibility |
| --- | --- |
| `game/app/main.gd` | Retain/replace/close one session; technical-only shell |
| `game_session.gd` | Fixed domain composition, committed aggregate, command/advance boundary and validation |
| `world_transaction.gd` | Detached state access/mutation, identity, knowledge and queue commands |
| `world_clock.gd` | Monotonic world-minute arithmetic inside a candidate |
| `world_scheduler.gd` | Durable descriptors, terminal receipts, due/FIFO selection |
| `simulation_coordinator.gd` | Bounded chronological dispatch; no domain rules |
| `session_domain.gd` | One small extension protocol for stateless domain rules |
| `world_definition.gd`, `world_data.gd` | Authored IDs/fingerprint and strict wire-format rules |
| `operation_result.gd` | Machine-readable command/advance/storage result |
| `game/persistence` | Exact-payload codec and native two-slot recovery |

Foundation filenames above are under `game/foundation` unless qualified.
Test-only crop/payout rules never enter the application shell.

## Add a domain

Extend `SessionDomain`. Implement `domain_id()`, `initial_state()` and
`validate(state, snapshot) -> String`. Return an empty string for success,
a stable diagnostic code on failure. State is a Dictionary containing data only.
Use typed domain methods around its records, not direct UI edits to dictionaries.

For scheduled consequences, implement `event_kinds() -> Array[String]`,
`validate_event(event, snapshot) -> String` and `handle_event(event, tx) -> String`.
Validate payload shapes/references before they enter the queue or restore.
Business preconditions at execution can legitimately produce a domain-defined
consequence; a technical failure returns an error and blocks the entire request.
Validators must not reject terminal records because a business condition later changed.

Compose stateless rule instances explicitly:

```gdscript
var session := GameSession.create(definition, domain_rules, persistent_world_id)
```

No registration during play. Duplicate IDs/kinds and invalid initial data fail
creation. Domain versions must match saved records. Each owner validates its state;
peer-domain interaction uses explicit concrete command methods in the same transaction.
`WorldTransaction.write_domain` is an infrastructure primitive, not permission for
Ink/UI or one domain to bypass another owner's business rules.

```gdscript
var result := session.transact(intent_id, func(tx: WorldTransaction) -> String:
    return concrete_service.apply_player_action(tx, action)
)
if not result.ok:
    show_failure(result.code, result.event_id)
```

A command may also supply a target minute. Stage immediate costs at current time
and schedule arrival at target; the coordinator visits intervening events before
publishing everything together. Do not call `advance_to` recursively from a handler.
Reusing a committed intent ID returns success with `already_applied` without
running the callback. Failed intents leave no receipt and may be explicitly retried.

Pure lazy projection reads domain anchors/history at the requested minute. An
event handler requests state at `tx.now()`, never at a separately cached skip end.
No automatic domain ticking, object scan, weather history service or RNG is invented.
Add only what a domain needs, with deterministic tests for its actual conditions.

## Persistence and lifetime

`SessionCodec.encode(session)` does not mutate it. `decode(text, composition)`
returns a fresh candidate or null. Composition fixes world ID, content and rule set;
use a separate recovery directory per world. Loading another world requires its
correct composition. No silent reset, coercion of IDs or automatic migration.

`RecoveryStore.new("user://<configured recovery directory>")` provides native
`save(session) -> OperationResult` and `load_candidate(composition) -> GameSession`.
`last_error` explains a failed load. This store returns `web_sync_unverified` on
Web; a verified asynchronous browser adapter is follow-up work. Native mobile
device-kill/storage behavior also needs on-device acceptance.

Call the root's `replace_session(candidate)` only after candidate validation.
Replacement closes the old session; stale references cannot issue commands.
Future region/UI Nodes must be torn down/rebuilt at the same boundary. Queries
return copies and can safely inspect a closed session's last committed state.

Limits are explicit engineering budgets: 512 consequential events per request by
default (configurable at composition), 8 MiB encoded saves, 128-character IDs,
16 nested data levels and bounded exact integer counters. They are not gameplay
tuning. A budget failure rolls back the request; choose a smaller target or adjust
the measured budget explicitly. No automatic retry every frame.
