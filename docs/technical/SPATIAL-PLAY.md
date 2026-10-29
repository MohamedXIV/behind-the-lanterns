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
