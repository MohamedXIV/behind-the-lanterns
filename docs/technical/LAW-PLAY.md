# Law, Pursuit, Scripted Arrest and Jail Opportunities — #7

In the courtyard and connected districts (`dev/fixtures/linked_world.json`), city watchmen
and restricted property enforce local rules without turning guards into ordinary combat
targets:

- **Guard non-combat and scripted arrest (`00-CONSTITUTION.md` §6, `D-008`, `D-009`):**
  Attempting to strike or confront a city guard (`a:gate-guard` or `a:watch-warden`) via
  **Confront guard** or **Strike / Primary (`Space`)** never initiates combat. Instead, it
  commits a scripted arrest (`guard_assault`), relocates the player to the traversable
  watchhouse (`region.watchhouse`), locks the watchhouse exit until release, and schedules
  a release event on the `WorldClock`.
- **Witnessed offenses and pursuit (`A08`):** Tampering with restricted targets
  (`a:private` merchant chest or `a:merchant-plot` private planter) checks whether an
  on-duty guard in the same region has sight of the actor (`sight_range`). Unwitnessed
  attempts (for example, late at night when the courtyard watchman is off duty) remain
  blocked by ownership rules without starting pursuit. Witnessed attempts start active
  pursuit (`status: "pursued"`) with a scheduled `law.cooldown` event on the `WorldClock`.
- **Evasion, cooldown and persuasion (`A08`, `D-048`):**
  - **Refuge evasion:** Moving to an authored refuge (`a:reed-bank` concealing river reeds
    or `a:dry-basin` shadowed stone alcove) when no guard is within interaction reach and
    pressing **Hide / Dodge (`Shift`)** or **Hide in refuge** cancels the pursuit event and
    clears wanted status.
  - **Cooldown expiry:** Remaining out of trouble until `until_minute` resolves the
    scheduled `law.cooldown` event and clears pursuit.
  - **Contextual persuasion:** A pursued player with a first-time non-assault offense can
    talk their way out of pursuit with a guard if they have completed a local work
    commitment (`voucher_jobs`, such as `work.provisions`). Guard assault and repeat
    offenders (`offense_count > 0`) cannot be talked away (`persuasion_refused`).
- **Social watchhouse and release paths (`A09`, `D-009`):**
  - Inside `region.watchhouse`, the player can walk freely, speak with the detained porter
    (`a:detainee`) via compiled Ink dialogue to hear shared world rumors (`claim.water`,
    `claim.passage`), or approach the watchhouse warden (`a:watch-warden`).
  - Jail conversations use shared world claims and grant no coins or items, preventing
    arrest from becoming a farmable reward loop or exclusive progression gate.
  - Release occurs either by **Pay fine** (transferring coins to the local treasury and
    cancelling the release event) or **Serve sentence** (advancing the `WorldClock` to
    `until_minute`, which fires `law.release` and returns the player to the courtyard).

## Domain invariants (`LawRules`)

- **No guard combat:** `confront_guard` rejects non-guard targets (`non_hostile_target`)
  and routes guard targets directly to transactional arrest (`_arrest`).
- **Scheduler integrity:** Active `pursued` and `detained` records always hold a matching
  pending `law.cooldown` or `law.release` event in `snapshot.scheduler.events`. Cancelled
  or completed events are reconciled atomically when pursuit ends, fines are paid, or
  sentences complete.
- **Bounded re-offense escalation:** Repeat offenses increment `offense_count` and scale
  fines and sentence durations up to `max_fine` and `max_sentence_minutes`.
- **Save/load compatibility:** Optional `law` domain v1 and updated `linked_world.json`
  content change the development content fingerprint/domain set. Prior development saves
  are preserved on disk and rejected cleanly on load; `first_gameplay.json` and
  `connected_gameplay.json` remain unchanged.

## Verification evidence

Executed `bash tools/test-headless.sh` on Godot Standard
`4.7.2.stable.official.ed1daf0bf`:
- `FOUNDATION PASS: 654 assertions, 0 failures`
- `GAMEPLAY UI PASS: 77 assertions, 0 failures`
- Separate-process save/restart verification (`FOUNDATION RESTART`, `GAMEPLAY RESTART`,
  `CONNECTED RESTART`, `REGION RESTART`, `NARRATIVE RESTART`, `FISHING RESTART`,
  `FARMING RESTART`, `WEB ACK RESTART`, `LAW RESTART` write/read)
- `HEADLESS VERIFICATION PASS`

