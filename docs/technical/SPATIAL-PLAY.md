# Spatial playground — Issue #14

The connected fixture now has an authored obstacle. Tap/click routes around it with
actor clearance and a visible route; WASD/arrows slide along its edges. Blocked
or disconnected destinations produce feedback. E / Use nearby opens the nearest
unobstructed holder, preparation bench or person's controls. Actions remain explicit;
approaching a merchant never spends money or accepts work automatically.

`WorldGeometry` is shared by the map and interaction rules. Distance and region
checks still apply; walls additionally block transfers, trading, preparation and
delivery through the existing reach contract. NPC routine destinations must be
walkable. Positions remain session state; routes are transient and discarded on
load. Movement commands validate walkable, connected endpoints, not elapsed speed;
this is a local game, not a network anti-cheat boundary.

Rectangular authored obstacles and a visibility graph suit this small disposable
map. Dynamic obstacles, moving NPC collisions, cross-region navigation, mobile
safe areas, Web exports and device usability remain unverified/deferred. The
fixture content fingerprint changes; earlier development saves are rejected safely
rather than migrated. No persistent domain schema changed.

Verification: full `tools/test-headless.sh` on Godot 4.7.2, including regression,
real node/input UI tests and separate-process native restart. New coverage includes
clearance, deterministic routed segments, unreachable destinations, transaction
rollback, through-wall permission, invalid NPC destinations, touch routing,
keyboard collision and contextual bench access. No GitHub Actions used.

## Linked rooms (#14)

The default `linked_world.json` adds a courtyard/workshop pair. Door use commits
actor region and destination position in the same transaction. Each region can
override collision geometry; other rules use the actor's current region. The
reusable `game/world/world_view.gd` renders and picks only current-region entities.
Local navigation paths reset on entry/load. Indoor storage and a second usable
preparation bench share the existing inventory, reservations and active seconds.
Temporary silhouettes/shadows/front faces preserve oblique 2D intent without final
art. NPC routines remain discrete in-region projections, not simulated walking.

No new persistent domain/schema or scene manager. Rooms currently share a logical
extent; regions are composed from data by one reusable view. Prior development
content saves are retained but rejected by fingerprint. Dynamic doors, cross-region
NPC routines, device/Web acceptance and Ink remain future work.

Final linked-room evidence: Godot 4.7.2.stable.official.ed1daf0bf,
`tools/test-headless.sh`: 370 regression assertions, 39 actual node/input UI
assertions, original/connected/region separate-process restart and startup PASS.
No warnings/errors. Tests cover indoor custody, partial preparation leaving and
returning, door replay/invalid destinations, touch entry/exit, interior load and
fresh-process region restoration. Screen conversion exposed a pre-existing float
JSON readback mismatch: committed movement now uses binary-exact 1/256-unit
coordinates, checked against collision after rounding, with exact codec coverage.
