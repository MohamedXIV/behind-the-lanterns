# Runtime Foundation Implementation Plan

> Execute inline as the sole engineer, per the user's request; review without delegation.

**Goal:** A small transactional persistent simulation with executable contract tests.
**Architecture:** Detached candidate state, manually composed stateless domain rules,
chronological due events and one validated publish. Native two-slot recovery.
**Tech Stack:** Godot Standard 4.7.2, typed GDScript; no addon/test framework dependency.
**Spec:** `docs/adr/ADR-002-TRANSACTIONAL-FOUNDATION.md`

## Global constraints

GDScript-first, native mobile/Web targets, systems-first disposable fixtures,
no gameplay systems or GitHub Actions. No PR #10 ancestry or copied implementation.
No automatic OS-time progression. No unexecuted pass claims.

## Review focus

1. Callback retains candidate or tries reentrancy: canonical state must stay isolated.
2. Event creates same-time work: causality, bounds and retry must be deterministic.
3. Wrong content/domain schema or unresolved entity: reject whole candidate.
4. Crash/corrupt newest save: previous valid generation must remain recoverable.
5. Lazy-dependent payout during a skip: evaluate at event time, not skip end.

## Task 1 — identity and transactional simulation

Files: `game/foundation/{world_data,world_definition,world_clock,world_scheduler,
world_transaction,session_domain,simulation_coordinator,game_session,operation_result}.gd`;
`tests/run_all.gd`, disposable `tests/fixtures/fixture_domain.gd`.

Interfaces: `GameSession.create(definition, domains, world_id)`;
`transact(command_id, command, target=-1) -> OperationResult`;
`advance_to(target) -> OperationResult`; `snapshot() -> Dictionary`.
Domain rules: `domain_id`, `schema_version`, `initial_state`, `validate`,
`event_kinds`, `handle_event(event, tx) -> String` (empty string = success).

- [x] Write failing deterministic tests, execute RED against minimal empty API.
- [x] Implement clock, identity, scheduler, transaction and composition contracts.
- [x] Run GREEN; exercise cross-domain lazy consequences, rollback and isolation.
- [x] Review ordering, reentrancy, same-time chains, identity and schema rejection.

## Task 2 — codec and native recovery

Files: `game/persistence/{session_codec,recovery_store}.gd`, persistence test suite.
Consumes complete validated snapshots; produces new candidate sessions and native
A/B generation storage. No live-session mutation during save/load.

- [x] Add codec corruption/content/schema and disk failure/recovery tests; execute RED.
- [x] Implement exact-payload checksum envelope and inactive-slot persistence.
- [x] Run save/load/new-process GREEN and verify failed writes preserve prior save.

## Task 3 — composition shell, critical review and delivery

Files: `project.godot`, `game/app/{main.gd,main.tscn}`, `tools/test-headless.sh`,
README/decision/technical evidence docs.

- [x] Run actual Godot import, all headless tests and startup smoke.
- [x] Conduct separate author critical review; add regression tests for findings.
- [x] Record executed engine/hash/results and unverified platform/Ink limits.
- [x] Publish through connected integration on the fresh branch; focused PR, no merge.

Execution record: sole engineer; 176 assertions plus separate-process restart, import and startup checks passed in Godot 4.7.2. Detailed author review and limits: `docs/technical/FOUNDATION-VERIFICATION.md`. GitHub delivery is tracked by the PR containing this plan.
