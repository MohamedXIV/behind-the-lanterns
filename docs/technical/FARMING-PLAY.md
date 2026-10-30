# Cultivation and offscreen world-time growth — #14

Take grain or lotus seeds from the shared supplies or buy them from the merchant,
then approach a plot in the courtyard or along the riverbank and press **Use nearby**
(or `E` / tap). Choose a crop, plant a seed, water the plot across world time, and
harvest the ripe produce.

- **Courtyard garden plot (`loam`, `courtyard`, player-owned):** grows courtyard grain
  from the start (`2` waterings spaced at least `120` world minutes apart, `360` world
  minutes of growth). Rejects river lotus (`incompatible_environment`) while leaving
  the lotus seed intact in your bag.
- **Sandy courtyard bed (`sandy`, `courtyard`, player-owned):** suboptimal soil that
  requires cultivation skill `1` (`skill_required_for_soil`) before grain can be
  planted there.
- **Merchant's private planter (`loam`, `courtyard`, merchant-owned):** rejects
  player planting/care/harvest (`access_denied`) without spending seeds.
- **Riverbank silt bed (`silt`, `riverbank`, public):** grows river lotus (`1`
  watering, `720` world minutes) or grain. Leave the riverbank and advance world
  time (including five-day `7200`-minute skips); when you return, growth is
  reconciled lazily from `WorldClock` timestamps without offscreen crop Nodes or
  frame replay.

Harvested grain and river lotus are ordinary `InventoryRules` goods: store them,
sell them to the merchant, or prepare `1 River lotus + 1 Grain` at any preparation
bench into `2 Packed provisions` for courier deliveries.

## Domain invariants (`FarmingRules`)

- **Three separate things (GDD 08 §8.3):** physical seed items in `InventoryRules`,
  immutable authored crop definitions, and persistent planted plot instances in
  `FarmingRules`.
- **Single-commit seed consumption:** planting atomically reserves and consumes one
  unreserved seed (`farming.seed.<ordinal>`). Failed permission, reach, occupancy,
  environment or soil checks roll back without consuming seeds.
- **Meaningful watering care (D-031, GDD 08 §8.5):** watering records world-clock
  timestamps (`waterings`) and enforces `watering_interval_minutes` between care
  events (`already_watered_recently`) so players cannot click-spam all waterings at
  once. Elapsed world time alone leaves an under-watered crop `parched`
  (`watering_required`) rather than ripe.
- **Bounded cultivation skill (D-010, D-031, D-034):** each completed harvest
  advances actor cultivation skill by `1` up to `max_skill` (`3`). Skill eases soft
  thresholds within explicit bounds—unlocking `skilled_soils` (`sandy`), reducing
  `required_waterings` by at most `max_watering_reduction` (with a hard floor of at
  least `1` watering), and reducing `growth_minutes` down to `min_growth_minutes`.
  Skill never overrides hard `environments` or unlisted `soils` incompatibilities.
- **Full-bag harvest safety:** harvesting a ripe crop when the player's bag is full
  commits `status: "ready"` on the plot without losing or duplicating produce. Free
  space in storage or trade and return to the plot to collect once.
- **Save/load and compatibility:** optional `farming` domain v1 and updated
  `dev/fixtures/linked_world.json` definitions change the development content
  fingerprint/domain set. Prior development saves are preserved on disk and rejected
  cleanly on load; `first_gameplay.json` and `connected_gameplay.json` remain
  unchanged.

## Verification evidence

Executed `bash tools/test-headless.sh` on Godot Standard
`4.7.2.stable.official.ed1daf0bf`:
- `FOUNDATION PASS: 532 assertions, 0 failures`
- `GAMEPLAY UI PASS: 57 assertions, 0 failures`
- Separate-process `RESTART write PASS` and `RESTART read PASS` across foundation,
  gameplay, connected, region, narrative, fishing, and farming suites
- Clean application startup (`--quit-after 2`), zero warnings or script errors

Platform status is unchanged from [FISHING-PLAY.md](FISHING-PLAY.md): Godot 4.7.2
Web export templates and `adb` are not installed in this container, and
`RecoveryStore` retains its `web_sync_unverified` guard until browser IndexedDB
persistence is validated.
