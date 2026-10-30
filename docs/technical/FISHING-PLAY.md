# Riverside fishing — #14

Take grain/dates from the shared supplies or buy bait, then follow the courtyard's
river path. Use the quiet reed bank or deep channel, select bait and Cast. Watch
for REEL NOW and press Reel during the brief window. Grain at the reeds can yield
silverfish/carp; date bait in the deep channel yields catfish. The spot's label
explains its bait. These are small disposable habitat/species examples.

Catches are normal inventory goods: keep/store/sell them, or prepare any species
at an existing bench into two portions of fish. The river and habitats exist before
knowledge; entering the path records exploration in the existing journal. No NPC
quest or social progression is required.

FishingRules owns one saved attempt per actor and a world cast ordinal. A weighted
selection is committed from world ID, location, bait and ordinal via SHA-256; it
never rerolls on drawing/loading. Bait is consumed at cast, including cancellation
and misses. Early reel or expiration misses. Active milliseconds (not world/offline
time) drive the window; travel away and application pause suspend progress.
Large presentation frame stalls are capped for a fair response window. Cancellation
puts away the line/releases a held catch; there is no bait refund. These policies
are provisional tuning, not a final difficulty/gear design.

Inventory gains two concrete operations: empty-output reserved transformation
consumes bait atomically, and capacity-checked add_goods admits a catch. The fishing
domain has no parallel item ledger. A full bag leaves a successful opportunity ready;
make space, return to the spot and collect once. All failure paths retain the prior
committed state. No fish ecology, spoilage, equipment grind or generic minigame bus.

Compatibility: optional fishing domain v1 and authored fish/region content change
the development fingerprint/domain set. Old development saves are retained but
incompatible; no migration claimed. Existing narrative/work schemas are unchanged.

Final actual Godot 4.7.2.stable.official.ed1daf0bf tools/test-headless.sh PASS:
472 rule/regression assertions, 52 real node/input UI assertions, all original,
connected, region, narrative and fishing separate-process write/read restarts and
startup. No errors/warnings. Includes wrong/remote bait rejection, active-vs-world
time, early/late reel, seeded save tampering, full-bag recovery, touch exploration,
reel feedback, preparation and sale. No GitHub Actions added.

## Platform feasibility evidence

`export_presets.cfg` supplies a bounded non-threaded Web smoke preset with JSON
included. Executed `Godot --headless --path . --export-debug 'Web smoke'
/tmp/btl-web/index.html`. Export failed before packaging: matching
`4.7.2.stable/web_nothreads_debug.zip` and `web_nothreads_release.zip` templates are
not installed. An official release archive selective-range attempt returned HTTP
501; the 1,281,349,702-byte all-platform archive was not downloaded as a fallback.
No Web build/browser execution, memory profile or Web acceptance is claimed.
Existing RecoveryStore deliberately returns web_sync_unverified on Web saves;
that async persistent-filesystem boundary remains a real release blocker.

`adb` is not on PATH and no Android device smoke was performed. Desktop Godot
input tests exercise synthetic screen-touch events, not device ergonomics, safe
areas, suspend/restart durability or Android/iOS packaging. Once templates/tooling
are available, the next platform check should run the exported game, Ink and
fishing on a landscape touch viewport and verify durable browser save handling.
