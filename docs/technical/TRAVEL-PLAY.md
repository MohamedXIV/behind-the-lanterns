# Public Route Travel and Travel Logs — #14

**Authority:** D-006, GDD 02 Journey & Travel, System Catalog A03/A04, Production F4 and ADR-002. The linked-world routes and place names are disposable test content, not a canonical city or release world map.

## Player-facing capability

- Approach a scheduled public packet boatman or caravan leader and use the existing contextual **Use nearby** interaction. The **Travel** tab lists routes departing the actor's current region, carrier availability, destination, fare and world-time duration.
- Explicitly confirm a fare to travel. The player arrives at a walkable authored position in the destination region; the map, region label, wallet and world clock refresh from committed state.
- Bidirectional disposable fixtures connect the courtyard with **Estuary Quay** by ship and **Red Dune Waystation** by caravan. Return journeys use local public carriers rather than simulating a vehicle or privately owned boat.
- The optional travel log presents concise route-authored journey text and persistent recent journey records. Reading it is not required and travel has no real-time narrative delay.

## Domain and cross-system invariants

- `TravelRules` validates route IDs, ship/caravan mode, carrier/origin identity, destination region and walkable arrival position, positive fare and duration at content ingestion.
- Boarding checks current origin region, carrier reach and unobstructed interaction, NPC schedule availability, sufficient finite funds, and a single active journey per actor. Public carriers refuse active pursuit or detention through a travel-specific law query; local portal evasion behavior is unchanged.
- `GameplayModel.take_route()` executes one `GameSession` transaction. It transfers the fare once, writes an active journey, schedules a stable `travel.arrival` occurrence and advances to that arrival minute. The arrival handler relocates the actor and appends the log record.
- Due work, law and other scheduled consequences execute in normal `(due, sequence)` order during the journey. Any handler, validation or event-budget failure discards the fare, time advancement, earlier candidate events, log and arrival together.
- Completed journeys retain their route, actor, departure/arrival minutes and stable arrival event ID. Active records require matching pending events; completed records require matching completed events. Malformed, duplicated, missing or inconsistent records fail restore validation.
- Reusing a committed journey intent returns `already_applied`, including when the original arrival is exactly at the world-clock limit. Inventory and reservations remain in their existing domains, and crop growth remains a lazy projection from world time rather than loaded-scene frames.

## Save and compatibility boundary

- The outer save container/codec and recovery format are unchanged.
- A new optional **`travel` domain schema v1** is registered for the linked-world fixture. Existing domain schema versions are unchanged.
- `linked_world.json` adds route definitions, carriers and destination content, changing its content fingerprint and domain set. Older linked-world development saves are preserved on disk and rejected safely by existing compatibility checks; no migration is claimed. `first_gameplay.json` and `connected_gameplay.json` are unchanged.
- Fresh-process restart coverage restores remote region/position, exact world time, fares, carried goods, deadline outcomes, travel log and completed arrival receipt, then permits a return journey without replaying the original fare.

## Verification evidence

Executed `bash tools/test-headless.sh` on Godot Standard `4.7.2.stable.official.ed1daf0bf` after the final review fixes:

- `FOUNDATION PASS: 704 assertions, 0 failures`
- `GAMEPLAY UI PASS: 86 assertions, 0 failures`
- Separate-process write/read restart verification for foundation, gameplay, connected, region, narrative, fishing, farming, Web-ack, law and travel suites
- Clean startup and `HEADLESS VERIFICATION PASS`

Coverage includes both transport modes and return journeys, fare/reach/schedule/law refusal with unchanged snapshots, carried inventory, deadline ordering, offscreen crop time, second-journey validation, injected arrival event-budget rollback, malformed restore rejection, clock-limit idempotency, real touch/context/button interaction, optional logs and save/load presentation.

These are native headless Godot results with real nodes and simulated input. Live Web export/browser execution and physical mobile device acceptance remain unverified; no new export or device evidence is claimed.

## Remaining boundaries

No continuous world map, canonical settlement, route capacity simulation, dangerous-destination refusal model, vehicle navigation, mandatory journey/quest chain, or private boat ownership is implemented. The two small route pairs prove the reusable contract; they are not a complete travel network or content-production milestone.
