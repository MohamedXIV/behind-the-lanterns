# Changelog — Behind the Lanterns

Meaningful player-facing changes and compatibility notes are recorded here using the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) convention.

**Status:** pre-release development. The entries below are a retrospective summary of merged prototype work **through PR #27 (30 October 2026)**, **not a published version or release**. There is deliberately no version tag or release date for these changes.

For current system completeness and test/platform evidence, see [Implementation Status](docs/IMPLEMENTATION-STATUS.md). For release identifiers, tagging and save compatibility, see [Versioning Policy](docs/VERSIONING.md).

## [Unreleased]

### Added
- Optional lodging/property access and touch-friendly constrained furniture placement, with valid-space previews, physical collision, and stable full-chest storage identity across packing, relocation and saves ([#14](https://github.com/MohamedXIV/behind-the-lanterns/issues/14), [#9](https://github.com/MohamedXIV/behind-the-lanterns/issues/9)).
- Transactional world sessions, scheduled consequential events, stable entity IDs, and native save/recovery ([#11](https://github.com/MohamedXIV/behind-the-lanterns/pull/11)).
- Collecting finite supplies, capacity-limited inventory and storage, merchant stock, and atomic buy/sell interactions ([#13](https://github.com/MohamedXIV/behind-the-lanterns/pull/13)).
- Optional funded delivery work, active-play preparation with ingredient reservations, deadlines, and NPC schedule availability ([#15](https://github.com/MohamedXIV/behind-the-lanterns/pull/15)).
- Obstacle-aware tap/keyboard movement and contextual spatial interaction, followed by linked courtyard/workshop interiors with persisted indoor activity ([#16](https://github.com/MohamedXIV/behind-the-lanterns/pull/16), [#17](https://github.com/MohamedXIV/behind-the-lanterns/pull/17)).
- Real Ink dialogue with uncertain rumors, independent physical discovery, semantic knowledge, reporting observations, and transactional delivery through conversation ([#18](https://github.com/MohamedXIV/behind-the-lanterns/pull/18), [#19](https://github.com/MohamedXIV/behind-the-lanterns/pull/19)).
- Contextual memories of kept, cancelled and missed commitments, acknowledgements, and an optional follow-up favor ([#20](https://github.com/MohamedXIV/behind-the-lanterns/pull/20)).
- Location-dependent fishing with bait choice, a short active-time reel window, saved catch opportunities, and ordinary goods/trade/preparation integration ([#21](https://github.com/MohamedXIV/behind-the-lanterns/pull/21)).
- Soil/environment-sensitive cultivation, spaced watering, bounded cultivation skills, lazy offscreen crop growth, and harvest/trade/preparation integration ([#23](https://github.com/MohamedXIV/behind-the-lanterns/pull/23)).
- Mobile-first semantic input abstraction (`PlayerInput`), runtime key remapping, toggleable running pace, on-screen landscape `TouchControls` with visibility and left/right-handed layout swap, safe-area/compact viewport layout adaptation, pause/focus movement halt + safe-state commit, and Web `/userfs` IndexedDB save acknowledgment (`WebSaveAck` + `RecoveryStore`) ([#25](https://github.com/MohamedXIV/behind-the-lanterns/pull/25)).
- Witness-aware law & pursuit (`LawRules`), refuge evasion, wanted-cooldown expiry, local work-commitment voucher persuasion, non-combat guard confrontation routing to scripted arrest, and a traversable social watchhouse (`region.watchhouse`) with Ink detainee dialogue, fine payment and sentence completion ([#7](https://github.com/MohamedXIV/behind-the-lanterns/issues/7), [#27](https://github.com/MohamedXIV/behind-the-lanterns/pull/27)).
- Bidirectional public ship/caravan routes with scheduled carriers, explicit fares, atomic world-time journeys and regional arrivals, pursuit/detention refusal, and optional persistent concise travel logs ([#14](https://github.com/MohamedXIV/behind-the-lanterns/issues/14)).

### Changed
- Added optional `housing` domain v1 and housing room/furniture definitions; older linked-world saves are preserved and rejected by content/domain compatibility checks. The housing playground uses a separate development save profile; no migration is claimed.
- Added enforceable design-authority and progress-reporting guidance for development agents and a central implementation ledger ([#22](https://github.com/MohamedXIV/behind-the-lanterns/pull/22)).
- Development fixture definitions, domain sets and narrative save schemas evolved as gameplay was added. **Older prototype saves can be rejected as incompatible**; they are preserved, not automatically migrated ([#18](https://github.com/MohamedXIV/behind-the-lanterns/pull/18)–[#27](https://github.com/MohamedXIV/behind-the-lanterns/pull/27)).
- Added optional `travel` domain v1 and linked-world route/carrier/destination content; older linked-world development saves are preserved and rejected by existing domain/content compatibility checks, with no migration claimed ([#14](https://github.com/MohamedXIV/behind-the-lanterns/issues/14)).

### Fixed
- Corrected fractional position round-tripping to avoid invalid saved positions during spatial gameplay ([#17](https://github.com/MohamedXIV/behind-the-lanterns/pull/17)).
- Rejected stale dialogue choices and ensured failed narrative handovers preserve goods, payment and conversation state ([#19](https://github.com/MohamedXIV/behind-the-lanterns/pull/19)).
- Enforced strict Web save acknowledgment completion boundary in `WebSaveAck` and `RecoveryStore` so pending IndexedDB flushes never report premature save completion, concurrent saves are rejected with `web_save_in_flight`, and failed/timed-out/reloaded pending writes roll back to the previous confirmed A/B generation ([#26](https://github.com/MohamedXIV/behind-the-lanterns/pull/26)).

### Known limitations
- These features are implemented in **disposable development content**, not a production-quality town or complete game.
- Desktop Godot 4.7.2 headless regression/UI/save-restart checks are recorded in the implementation ledger. **Mobile device acceptance, Web export/browser persistence, and production save migrations are not verified/implemented.**
