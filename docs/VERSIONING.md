# Versioning, Releases and Save Compatibility

**Status:** approved lightweight *development-process* policy, established 30 October 2026. No public release is declared here. This file does not authorize new gameplay or change the GDD.

## 1. Separate identifiers

| Identifier | Purpose | Current policy |
| --- | --- | --- |
| **Development revision** | Exact source that was tested | Full Git commit SHA, plus Godot version/platform in test evidence; short SHA only for display |
| **Game/build version** | Human-readable distributable milestone | Optional pre-`1.0.0` SemVer prerelease name **only when a named build is intentionally published** |
| **Save container/file format version** | Outer serialization/recovery contract | Owned by save codec/recovery implementation; bump only when its format changes |
| **Domain schema versions** | Versioned data contracts (e.g., Narrative, Fishing, Farming) | Independent per-domain versions, not derived from the game version |
| **Content fingerprint** | Authored world/rules/Ink definition compatibility | Checked independently of save format/domain versions |

The engine version (currently Godot Standard **4.7.2**) is a **tool/runtime dependency**, not the game's SemVer. A PR number, date or Git SHA is **not** automatically a release.

## 2. Pre-release game versions

Use [Semantic Versioning](https://semver.org/) with pre-`1.0.0` instability explicitly acknowledged. Names such as `0.1.0-dev.1`, `0.1.0-alpha.1`, `0.1.0-beta.1` and `v0.1.0-alpha.1` are **illustrative only**; none is assigned by this document.

- **Ordinary main/PR merges:** no version bump and no new Git tag. The build identity is the exact commit SHA.
- **Deliberately published development/pre-alpha milestones:** owner approves the first actual `0.y.z` version and corresponding prerelease label; repeatable builds of the same milestone may advance `dev.N`/`alpha.N`/`beta.N` as appropriate. Don't manufacture automatic build numbers from PR IDs.
- **Subsequent pre-`1.0` releases:** normally increment the minor component for a material capability milestone and patch for a compatible correction. Record breaking compatibility explicitly; version numbers alone do not promise pre-`1.0` save compatibility.
- **`1.0.0` and future stability guarantees:** require a separate owner decision and actual release readiness, not an automatic consequence of adding systems.

A version tag is written with a leading `v` (e.g., `v0.1.0-alpha.1`) only when its matching **verified build** is intentionally released. A GitHub merge is not a release.

## 3. Changelog policy

- Maintain root [`CHANGELOG.md`](../CHANGELOG.md) in Keep a Changelog-style format, with one **`[Unreleased]`** section at the top.
- Add a short entry in the **same PR** when user-visible mechanics, UI, world behavior, supported platform behavior, important fixes, or data/save compatibility change. Link the actual PR/issue. Optional labels: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`.
- Skip routine internal housekeeping and test-only changes unless they materially alter a public/developer contract. Avoid duplicating an entire PR description in the changelog.
- **Never silently drop history.** When a release is authorized and tested, move its entries from `[Unreleased]` under `## [<version>] - YYYY-MM-DD`, add a fresh `[Unreleased]`, and link the release/tag when it exists.
- The initial `[Unreleased]` section summarizes historical prototype work through PR #23 because no named build has been published; it should not be retrospectively assigned a fictional version.

For current maturity and gaps (rather than history), maintain [`IMPLEMENTATION-STATUS.md`](IMPLEMENTATION-STATUS.md). For design decisions, use [`DECISIONS.md`](DECISIONS.md). For work-in-progress status use Issues/PRs.

## 4. Save and content changes: required disclosure

Each PR changing persisted data, the codec/recovery boundary, domain definitions or compiled Ink content must declare in its PR description and, when meaningful, changelog:

1. **Which boundary changed?** Outer save format, individual domain schema(s), authored content fingerprint, or some combination.
2. **Compatibility outcome?** Existing save loads unchanged; it is migrated by a proven migration; or it is **rejected safely with the old file untouched**. Avoid saying simply “backwards compatible” without evidence.
3. **Verification:** normal save/restart plus relevant negative or cross-version tests. Test migrations using a representative prior saved artifact when any migration is claimed.
4. **User impact:** whether progress is lost, preserved but inaccessible to the new fixture, or migratable. Development fixture saves are not public production saves.

**Current prototype policy:** older incompatible development saves can be refused **without deletion**, with incompatibility recorded. No general migration framework is mandated or claimed. Before sustained player testing, external distribution or a stable save contract, the owner must choose a compatibility/migration policy. A game version bump does not replace schema validation, world/content compatibility checks, or migration tests.

## 5. Minimal release gate (manual, not automated)

To publish a *named* build/release:
1. Obtain owner approval for the version and target platform(s), plus exact Git commit.
2. Confirm the actual target export/build launches, with user-input and persistence smoke checks on that platform. Desktop headless test success **does not prove Web/mobile support**. If only a limited technical build is published, label untested capabilities/platforms clearly and do not claim general acceptance.
3. Run the full relevant Godot regression, gameplay/UI and separate-process save/restart verification; record engine version, target platform, tested SHA and outcomes.
4. Review save compatibility and known blockers; explicitly label disposable content and release limitations.
5. Move `[Unreleased]` notes into the approved dated version section, then create the matching Git tag and optional GitHub Release with concise notes. Never tag an unverified artifact as released.
6. Update the implementation ledger and release links for the new milestone.

**Not included now:** automated release pipelines, GitHub Actions for changelog/version bumps, Changesets, build-number services, automatic migration infrastructure, or per-PR tags. Introduce these only if frequent validated distribution makes them worthwhile.

## 6. Agent responsibilities

The mandatory [`AGENTS.md`](../AGENTS.md) workflow applies to **every** coding model: read actual main, design/roadmap authority, Issues, this policy and existing status before choosing work; implement only authorized gameplay; update change history for qualifying changes; keep Issues/PRs/implementation status current; report verified results vs assumptions. **Engineering freedom does not include silently declaring new release versions.**
