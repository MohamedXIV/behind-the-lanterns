# GDD 08 — Life & Livelihood Systems
**Game:** Behind the Lanterns · **Status:** Detailed design **proposal for owner review** · **Revision:** 0.2 · **Date:** 2026-10-29

> **Design mandate:** Everyday life must be a meaningful way to play, and adventure should naturally enrich it. These systems are designed to interact through a small common foundation, not become six global managers, a generic survival simulator, or a content-heavy vertical slice.

**Implementation update (29 October 2026):** The owner's autonomous gameplay request
authorizes a bounded inventory/container + simple trade/interaction increment (#12)
on merged foundation #11. See `docs/technical/FIRST-GAMEPLAY.md` and D-039 for its
selected engineering subset. This does not approve every proposal below; earlier
statements that no code is authorized are historical and superseded for that subset.

## 0. Source of authority, approval status, and scope

### Already approved in the Constitution / conversation
- Sandbox without mandatory main quest, final ending, job class, or role lock.
- Modest start at an inn/stable; eventual rented room, personal house and optional land cultivation. A movable boat-home is a later progression possibility.
- Farming and selling crops are real options for the player, **not the central genre**.
- Everyday world time, NPC schedules and light needs; the intended feel is **Skyrim-lite**, not a pressure-heavy survival game.
- Discovery, trade, travel and relationships can teach recipes, crops, tools and livelihoods.
- Item/world truth exists independently of player rumors. Knowledge influences understanding and opportunities, not whether an object physically exists.
- Region-specific rules can matter (a seed may physically exist yet fail to grow outside its natural conditions).
- Fixed 2D oblique, mobile-first landscape Godot project; minimize appearance variation and heavy art/runtime production.
- Systems-first and **very little disposable proving content**, with authored worlds growing after contracts are tested.

### Newly confirmed by owner (2026-10-29)
- **Fishing** starts with bait choice and a brief **timing minigame**; species availability is strongly tied to location, with a small initial roster and exotic/fantasy fish and sea creatures added later.
- **Farming** begins small but its extensible crop rules account for **environment, soil, required watering and elapsed in-game growth time**. Skills may reasonably reduce friction in these requirements, not break hard biological/magical incompatibilities.
- **Crafting** takes **a few active-play seconds**, not mobile-style wait-to-return timers. Exact lengths and interruption/cancel rules are still tuning questions.
- **Home decoration** is deliberately constrained by the 2D view. No freeform building/construction simulator is needed.
- User asked for architectural guidance on **composition vs inheritance**, and possible shared traits such as perishability and skill effects. The specific trait implementation remains **proposed**, not locked.

### Proposed here — not automatically approved
- The precise subdivision of Inventory, Crafting, Cooking, Gathering, Fishing, Farming, Housing/Placement, Trade/Work.
- Transaction semantics, instance/stack distinction, state examples, APIs, and dependency boundaries.
- Fishing interaction mechanics, farming growth modeling, housing decoration permissions and first-release inclusion.
- Typed GDScript and lightweight Godot-native composition are **preferences/architecture candidates**, not yet a ratified ADR.

**Do not treat any example numbers, IDs or imagined recipes as content obligations.** This GDD is a system specification for discussion; no production code has been approved.

---

## 1. The player experience we're protecting

The player should be able to spend an ordinary day caring for a small place, selling or producing useful goods, visiting a harbor, helping neighbors, or preparing for travel. None of those acts should feel like mandatory chores before the “real game” begins. A day's adventure can introduce a new ingredient, a craft, a method or a story; those discoveries should be usable in ordinary life without permanently forcing adventuring.

### Example loops (not scripted quests)

**Livelihood → home:** gather ingredients → prepare simple goods → trade for money → rent a room or furnish a home → improve comfort and practical storage.

**Travel → livelihood:** learn about an unfamiliar crop during a voyage → acquire seed → test suitable soil → harvest where conditions allow → cook, trade or gift produce.

**Fishing → relationships:** learn of a fishing spot or stumble upon it → fish if conditions/gear permit → keep, cook, sell or give the catch → a conversation later can acknowledge what occurred.

**Home → travel:** arrange a room, prepare supplies and storage → head out on a journey → come back with discoveries, belongings and better options.

These are *possibility loops*, not fixed unlock trees or a requirement that every subsystem be funneled through crafting.

### Playable without obligation
- The player may ignore farming entirely; no required crop-production gate.
- Fishing must remain optional unless a specific optional narrative makes it relevant.
- Home decoration is expression and utility, not a tax that gates the rest of the game.
- Crafting is one way to obtain some goods, not the only route; trade, gifts and finding things remain valid.
- No real-time offline crop death, daily-login streak, or paid timer acceleration.

---

## 2. Domain map and authoritative responsibility

A “system” is a **cohesive business/gameplay responsibility**, not necessarily a Godot Node, Autoload or file. This is a domain ownership map, not a demand for a giant manager hierarchy.

| Domain / proposed capability | Owns | Must not own | Reused by |
| --- | --- | --- | --- |
| **Item Definitions & Instances** | Definition IDs and properties; unique instance data where needed | Wallets, item prices, story facts | All gameplay |
| **Inventory & Containers** | Which instance/quantity is in which location; capacity, transfers, reservations if justified | Crafting recipes, fish encounters, trade quotes | Crafting, trade, farming, fishing, housing |
| **Ownership & Property Access** | Who may use room/land/furniture/containers; lease/purchase state | Visual wall geometry, prices or physical inventories | Housing, farming, commerce |
| **World Clock / State** | Canonical elapsed game time and persistent world facts | NPC sprites and every visual animation | Growth, production, shops, schedules |
| **Money & Transactions** | Money balances, payments, sale/purchase commit rules | Inventory rendering, vendor dialogue | Trade, work, housing |
| **Gathering / Sources** | Finite or renewable gatherable world source states | Items in bags and farming crop lifecycle | Crafting, trade |
| **Crafting / Recipes** | Learned recipes, input/output transformation, equipment requirements and craft jobs | Container authority or item definition ownership | Cooking and any future workshop |
| **Cooking / Preparation** | Food-specific steps, conditions, outcomes, equipment interactions | A second independent inventory | Home, trade, needs |
| **Farming / Cultivation** | Planted crop state and growth under time/environment | Moving items between bags, terrain artwork | Housing/land, economy |
| **Fishing** | Waterbody/spot state, encounter/catch resolution and fishing activity | Rewriting ItemStore, universal resource spawning | Food, trade, exploration |
| **Housing & Placement** | Which property/room is occupied and where placeable instances are located; spatial validity | Proprietary inventory ledger or whole-world building generator | Decoration, furniture, storage |
| **Trade & Vendors** | Quotes, offers, availability, stock policy, accepted transactions | Creating arbitrary item quantities without payment | All livelihood |
| **Work & Services** | Optional jobs, evidence of completion and rewards | A mandatory profession class or universal quest engine | Everyday loop |
| **Skills & Learning** | What the player has learned/achieved; modest modifiers | Physical existence of items/secrets or all recipe content | Craft, speech, life |
| **Scene Presentation** | UI, drag/placement gestures, sprites, fish animation, crop visuals | Canonical gameplay truth | Every domain |

**Architectural invariant:** exactly one source of truth exists for an item quantity or unique item instance at any point in the game. Other systems request operations against it; they do not maintain shadow inventories.

### Composition versus managers
One game-scoped session/context should give the active region and UI narrow access to relevant gameplay services. Avoid `InventoryManager`, `FarmingManager`, `FishingManager`, `HomeManager`, etc. as globally addressable Autoloads by default. A small coherent feature may live in one module and grow only when evidence requires it.

---

## 3. Shared state: definitions, instances, actions, and saves

### 3.1 Definitions (authored content)
Designers author item types, recipes, crop species, equipment classes, fishing locations, furniture characteristics and property types. These are immutable **content definitions** addressed by stable IDs.

Illustrative candidate definitions:

`ItemDef { id, display_key, category, stack_policy, allowed_uses, tags }`

`RecipeDef { id, ingredients, outcome, optional_station, conditions }`

`CropDef { id, seed_item_id, harvest_item_ids, growth_rules, environmental_conditions }`

`PlaceableDef { id, footprint, attachment_rules, interactions }`

`FishingSpotDef { id, habitat_tags, optional_encounter_table, availability_rules }`

These are **conceptual fields, not an approved schema**. Prefer tagged capabilities over sprawling class inheritance. Source format (Godot Resource, JSON, or hybrid) is still subject to the core architecture ADR.

### 3.2 Persistent instances (run-time truth)
Save the minimum that differs from the static definition:
- Container ID → item stack quantities **or** distinct item instance IDs.
- Unique item state only where meaningful (condition, crafted variant, reserved status, custom appearance).
- Property ownership/lease and placed furniture transforms/slot coordinates.
- Planted crop IDs, species, plot, stage/progress and timestamps or accumulated game-time markers.
- Work orders / ongoing preparation only when actually used.
- Active fishing interaction only if it must survive suspension; otherwise define a safe interruption rule.
- Equipment state and other persistent changes, not transient animations.

**Items, planted crops, placed objects and property holdings must not be duplicated** by save/restore or by unloading/loading a region.

### 3.3 One validated command, one committed result
Gameplay sends a narrow intent; a responsible service validates prerequisites and performs a consistent state transition. For operations that involve several domains (sell an item, plant a seed, craft output), the relevant coordinator must ensure there is no partial success.

Examples of conceptual operations:
- `TryTransferItem(source_container, destination_container, item_reference, quantity)`
- `TryStartCraft(recipe_id, station_id, source_containers)`
- `TryPlant(plot_id, seed_reference)`
- `TryFish(spot_id, equipment_id)`
- `TryPlaceFurniture(property_id, room_id, item_reference, position)`
- `TrySell(vendor_id, item_reference, quantity, current_quote)`

These are **interaction contracts**, not required function names. UI, Ink and the player controller must not edit inventory arrays or wallets directly.

### 3.4 Time-driven work
All cultivation/production timers must use the game's **World Clock**, not wall-clock time while the app is closed. Changes can be evaluated on meaningful world-time advances and on region entry, rather than running every offscreen crop/actor every frame.

The simulation clock belongs to Foundation. Farming and Crafting only read elapsed time and apply their own rules; they must not each increment their own “day counter”.

### 3.5 Knowledge is not physical inventory
A rumor that a certain seed exists does not grant the seed; learning a recipe does not create crafted goods; discovering a market route does not spawn a vendor. Knowledge and learned techniques may change which actions players can deliberately attempt, but the physical world and objects remain independent.

---

## 4. Inventory & Item Foundation (cross-domain)

### 4.1 What the player perceives
A portable bag, perhaps a hand-held item, chests and cupboards at home, a vendor's stock, and eventually boat storage. Items can be moved, used, sold, given, planted or processed as their definitions allow. For mobile, transfers must be quick and intelligible rather than a mandatory drag-and-drop puzzle.

### 4.2 One location for every thing
Inventory is not “the player's one array”. A **container** is a logical holder: player bag, equipment slot, chest, vendor stock, staging/workstation inputs, dropped-item world holder, etc. Containers have an identity, optional capacity rule, and access constraints. A world pickup may be represented as a world-owned item location, not silently cloned on interaction.

### 4.3 Stack versus unique instance
Two identical ordinary dates may share a stack; a distinctive enchanted vessel, a worn tool or a customized rug may need instance identity. Do not force every carrot to be a full independently updated entity or every altered object into an indistinguishable count.

Candidate default:
- Stack simple homogeneous consumables.
- Separate instances only for stateful equipment, furnishings, unique gifts or specific provenance/quality when gameplay truly needs it.
- Do not implement individual item durability/quality on all commodities as a blanket rule.

### 4.4 Ownership and legality
**Inventory location**, **legal owner**, **usable permissions**, and **regional legality** are different concerns. A good may be stored in the player's bag but legally stolen or forbidden in one harbor. The Inventory service should not decide whether customs allows it; Law/Region rules supply that policy when the player attempts the relevant action.

### 4.5 Transfer invariants
- Quantities are nonnegative; transfers cannot exceed available unreserved items.
- Source removal and destination addition succeed or fail as one logical operation.
- Capacity and permissions are checked before commit.
- Equipment/station/furniture does not display a second physical copy of an item stored elsewhere.
- Save/load and region unload/load preserve the same holdings.
- UI observes outcomes, not the reverse.

### 4.6 Reserve inputs only if needed
Reservation of ingredients can prevent using the same seed/ingredient twice during long crafting or cooking. Start with **simple immediate consume-on-start** if all recipes are instantaneous; add reservations and active jobs only for real delayed workflows. We have evidence from Kiosk that reservation is valuable for more complex jobs, not a mandate to replicate it.

---

## 5. Gathering and physical resources

Gathering is a **world interaction** that produces items. It might represent picking herbs, collecting driftwood, gathering reeds or taking produce from a permitted field.

### Contract
- Gatherable **world sources** have authored positions independent of player knowledge.
- A source's current availability may depend on harvest history, environment and time.
- If a source yields an item, Inventory receives it exactly once.
- Gathering can respect land ownership/permission; trespass is handled by Law, not encoded as special gathering combat.
- Regrowth, depletion and seasons are configuration choices, not required first-build mechanics.

**Important distinction:** gathering a naturally occurring plant is not the same as growing a cultivated crop on a player-controlled plot. Shared item outcomes do not require one giant `PlantManager` for both.

---

## 6. Crafting and learning

### 6.1 Player fantasy
Crafting transforms things found, purchased, harvested or received into more useful or valuable things. The player might learn a technique from a traveler, an artisan, an old book or experimentation. Exploration can expand livelihood without reducing the entire discovery system to an RPG perk tree.

### 6.2 Recipe definition versus player learning
A `RecipeDef` exists as world/content data from the start. A separate player record tracks familiarity, teaching, successful attempts or mastery as the design later requires. A recipe can be taught, attempted experimentally if rules allow, or offered by a craftsperson; knowledge does not magically create the recipe in the content library.

**Open design:** must the player explicitly learn a recipe to make it, or may experimentation reveal it? We should not hard-lock the answer in implementation prematurely.

### 6.3 Craft attempt
Validate:
- Available inputs from permitted containers.
- Required tool/station (if any).
- Property/use permissions for the workspace.
- Environmental/time/knowledge constraints only when justified by that recipe.
- Destination space for produced output.

On success, consume/reserve inputs and create output through the same item ledger. Do not lose inputs on a failed validation. If outcomes can vary, define the random seed/quality snapshot at the relevant commit boundary so save/load cannot reroll the same craft.

### 6.4 Workflows — short active-play crafting (approved direction)
Crafting should have a short **visible, in-session** duration measured in seconds, with feedback rather than an instant button press. It is **not** a mobile idle crafting queue requiring the player to return hours later. The world may still advance by an appropriate small amount if the in-world clock is designed to do so.

**Proposed smallest state contract:** `Ready → InProgress → Completed/Cancelled`. A craft attempt validates required inputs and equipment once, captures necessary parameters, then resolves exactly once. Input consumption on start vs completion, refund/cancellation, station occupancy and whether game pause suspends progress remain open until a use case requires them.

Do not introduce a general job scheduler, recipe step graph or offline timer solely to support a two-to-five-second action. Any longer cooking/artisan process is a later special case sharing the inventory/transaction rules, not a reason to complicate the initial craft.

**Save safety:** an app suspension during crafting must neither duplicate output nor swallow ingredients silently. Choose resumable committed job or a documented consistent rollback, and test the interruption boundary. Exact time values are tuning parameters rather than constants embedded in code.

### 6.5 Craft specialization
Cooking, sweets/drinks, textile work or other crafts may extend the same shared Inventory + basic recipe concepts, but unique mechanics are implemented locally. Do not make every craft identical merely to maximize abstraction.

---

## 7. Cooking & food preparation

Cooking is a **specialized livelihood and home activity**. It can turn farmed/fished/bought goods into food, refreshments, gifts, or saleable products. It is not a second duplicate inventory system.

### Candidate ingredients of cooking gameplay
- Recipes with ingredients and equipment requirements.
- Station identity (kitchen, fire, stove, small travel kit when permitted).
- A simple final-product state and optional quality/outcome where it matters.
- Optional duration/heat/step processing only if it makes play better.
- Food can feed the player if needs are approved, be gifted, stocked or sold.

### Specific non-goals
- Don't build Kiosk's whole cooking workflow, step graph and service queue into this game simply because the existing code is available.
- Don't require players to spend lots of time in cook UI to earn basic survival.
- No assumption that every food has spoilage or a five-stage freshness curve.

### Save behavior
For any *actual* timed preparation, save either the in-progress job and a stable snapshot of its inputs/parameters or a well-defined interruption/refund policy. A reload must not multiply meals, re-quote price or regenerate quality for free.

---

## 8. Farming & environmental compatibility

### 8.1 Why it exists
Once the player has access to land, farming can become one self-chosen source of income, food, gifts and domestic routine. It is **not** a Stardew-scale economy or an imposed daily loop.

### 8.2 Suggested cultivation sequence
Acquire seed → establish permission to use plot → prepare/plant → optional care → advance game time → environmental viability and growth → harvest → send output to Inventory → use/trade/replant.

### 8.3 Three separate things
1. **Seed/item:** a physical item with an item ID, stored in an inventory/container.
2. **Crop species definition:** growth and climate/soil requirements (content).
3. **Planted crop instance:** a persistent crop placed on a particular plot with its own stage/progress/history.

Planting consumes one available seed and **creates one persistent planted instance**, not a second copy of the seed. Harvesting yields actual item quantities and changes/removes planted instance according to crop rules.

### 8.4 Local environment matters
- Land may be owned, rented or permitted for use; ownership is **not** an attribute baked into crop logic.
- Soil/water/climate can influence viability/growth.
- A seed from a magical region should remain in inventory even when planted in unsuitable ordinary soil.
- “Cannot grow here” is a local rule, not a reason to delete the seed from a bag on world crossing.
- If an exotic seed is incompatible, clearly communicate that risk where possible; don't surprise-punish the player.
- Rare compatibility variants are possible authored content, **not** a first milestone requirement.

### 8.5 Growth, care, skill and fairness (owner-confirmed design direction)
A crop definition may require a **compatible environment**, **appropriate soil**, **some number of watering events / sufficient moisture during growth**, and **elapsed in-game growth time**. Crop species set their own requirements. Start with a tiny set of crops, then extend definitions rather than copying scripts.

**Hard versus soft conditions:** Some rules are hard constraints (e.g. a realm-exclusive plant cannot grow in ordinary soil); others are improvable thresholds (e.g. the number of adequate watering events, slightly imperfect soil, a modest growth delay). **Skills can make the latter easier within sensible limits.** Skill progression must not arbitrarily turn salt water into freshwater, eliminate every watering event, or cancel all location-specific identity.

**Implementation recommendation, not approved exact formula:** allow a small policy or rules object to evaluate soil, climate and care; compute modifiers through a focused skill query for that action. Apply caps and a clearly defined order so `required_waterings - skill_reduction` cannot become nonsensical. Example skill improvements include one fewer watering at higher expertise, modest tolerance of suboptimal soil, or slightly faster growth; these are **examples, not all promised bonuses**.

A watering requirement is **not** an instruction to make the player click three times in a row. The system should register meaningful care events or environmental moisture across the growth interval, with no artificial UI spam.

Growth uses the **game clock**, never wall-clock time when the mobile app is closed. Death/neglect severity, crop seasons, exact watering counts and yields are **still open**; avoid pressure-driven daily chores by default. Region unload/load reconciles elapsed growth once, not once per frame.

### 8.6 Offscreen rules
Unloaded fields need not run crop Nodes. Record enough per-plot state and time references to deterministically reconcile growth when time passes or the field loads, including cross-region travel and sleep. Never apply the same elapsed interval twice.

### 8.7 Not in the initial farming contract
Farm machinery, workers, genetics, breeding, irrigation engineering, a global commodity futures market, broad land-terrain sculpting, or massive procedural farming regions.

---

## 9. Fishing

Fishing belongs with **Gathering / Livelihood** for its economic and domestic role, and with **Adventure / World Interaction** for location, discovery and the player's actions. It is not just another crafting recipe.

### 9.1 What exists in the world
- Fish species/item definitions, if actual fish become inventory items.
- Waterbodies/accessible fishing spots with physical locations and local rules.
- Equipment/bait where the design warrants them.
- A fishing interaction state with a catch/miss/escape outcome.
- Optional world-time, weather, ecology or regional variations.

### 9.2 A fishing attempt
Player approaches real water/spot → checks permission/gear → begins interaction → responds to understandable feedback → catches or does not catch → successfully caught fish are added **once** to Inventory.

One could fish from the shore, a jetty, or eventually a boat **only if authored locations and controls support it**. A rumor about a fishing spot may help locate it but must not cause the spot to exist.

### 9.3 Fishing activity — bait + short timing interaction (owner-approved direction)
**Initial gameplay:** select or prepare permitted bait, cast at an accessible place, and play a **short timing minigame** with an understandable success window. Timing and bait matter; random outcomes must remain readable rather than pure dice-roll failure. A missed timing attempt should have a clear, tuned result. Mobile landscape touch is the primary control constraint.

**Strong geographic identity:** the available fish differ **substantially** between river, lagoon, harbor, coast, distant island or an otherworldly body of water. Use location/habitat-linked species pools, not one universal catch table with cosmetic name changes. Bait and environment influence eligible catches and probabilities, without guaranteeing a rare result; the location defines what is *possible*. A small authored starting roster is sufficient.

**Future expansion:** unusual fish, mythic aquatic species, and fantasy sea-life encounters are possible later **without redesigning the common item/catch contract**. Not all sea creatures must become catchable inventory items, harmless collectibles or ordinary fish; they may be world actors, hazards, discoveries, or authored narrative encounters.

**Skills:** fishing expertise may modestly widen the timing window, reduce fish escape likelihood, improve relevant feedback, or make bait usage more efficient. It must not cause freshwater species to appear in unrelated environments or guarantee exotic catches. Exact modifiers are not yet selected.

**Single-result boundary:** select/commit a particular catch opportunity under controlled/seeded rules; don't reroll the species repeatedly when a UI redraws, player pauses, or restores a save. Resolve the catch as one item transfer on success. Bait consumption/recovery and session interruption behavior are tuning decisions.

**Not required:** full simulated fish AI ecosystem, fishing skill grind, heavy mini-game variants for each species, hundreds of creatures at launch.

### 9.4 Result integration
Fish can be cooked, sold, gifted, or used in an optional quest. Regional legality and ownership still apply. Fish are items after catch; Fishing does not become a second ItemStore.

---

## 10. Housing, property, decorating and storage

### 10.1 Progression
The stable sleeping space is a **starting condition**, not permanent ownership. Later: rent a room at an inn, and buy or gain access to a small house; it may or may not have an adjoining plot for cultivation. The player may visit, rent or own different places if the world and economy support it. Personal boat-home belongs to later travel/housing design.

Do not force a rigid mandatory chapter sequence; changing housing is a player-directed economic/social opportunity.

### 10.2 Split authority
- **Property/Access:** may this player occupy, decorate, store items, plant, use a workstation?
- **Housing:** what comfort, rest/storage and home-specific interactions apply here?
- **Placement:** is a piece of furniture allowed at this position, on this floor, in this space?
- **Item/Container:** which physical furniture item exists and what does its storage contain?
- **Visual/Building:** sprites, occlusion, cutaway, visible floor. The visual layer never controls ownership.

### 10.3 Decoration, not construction simulation
Allow moving, rotating, placing, removing or replacing appropriate furniture and decor **within valid existing rooms/surfaces**. Do not promise user-constructed walls, free-form architecture remodeling, floorplan editing or a full Sims construction system in the first versions.

### 10.4 Deliberately constrained 2D furniture placement (owner-approved direction)
Home decoration must stay **small in scope**, appropriate to a fixed 2D 3/4 oblique world: move/remove/replace a modest set of furniture and decor in existing rooms, with a simple, touch-friendly preview. No custom walls, freeform house construction, room mesh editing, complicated 3D rotations, physics-based stacking, or a built-in architecture designer.

**Provisional implementation:** a simple logical snap/grid or a small number of permitted placement cells/surfaces. Choose the exact UX after a small touch control test. Validity checks may include property access, indoor/outdoor eligibility, floor index, footprint collision, doorway clearance, attachment surface and interaction reach. Keep dimensions in world/logical space; visual obliqu…10610 tokens truncated…CommerceRules and InteractionRules with proximity/access checks.
3. Compose via GameplayModel; include gameplay definitions in fingerprint; verify
   save/load, repeated intent and a second content fixture.
4. Add a disposable playable Godot presentation; exercise its actual commands and
   movement, then run the complete existing and new tests in Godot 4.7.2.
5. Review concrete failure/extension cases, record evidence here and deliver one PR.

## Executed result

Godot Standard `4.7.2.stable.official.ed1daf0bf`, Linux x86_64:

```text
FOUNDATION PASS: 242 assertions, 0 failures
GAMEPLAY UI PASS: 15 assertions, 0 failures
GAMEPLAY RESTART write PASS
RESTART write PASS
GAMEPLAY RESTART read PASS
RESTART read PASS
HEADLESS VERIFICATION PASS
```

Command: `GODOT_BIN=/path/to/Godot bash tools/test-headless.sh`.
The 242-assertion suite includes the existing foundation and 66 new gameplay checks.
The wrapper also imports the project and runs application startup, failing on any
Godot error/warning even if its process exit code is zero. No GitHub Actions added.

Verified finite transfer/conservation, implicit stack packing, bag and merchant
capacity, access/region/reach, stock/funds, price bounds and quote rejection,
duplicate sales, malformed definitions/state, numeric/position roundtrip, alternate
content, actual mouse/keyboard/screen-touch input and action/Save/Load buttons.
Separate processes verified gameplay depletion, custody, coins, position and receipts.

Author review (not independent peer approval) corrected JSON numeric normalization
and a peer-wallet validation-order dependency, with failing cases reproduced before
fixes. The only foundation change is the optional authored-rules fingerprint input.
Inventory and Commerce remain concrete peers, not a new generic transaction engine.

## Limits and next increment

This UI is a disposable development fixture; no visual/art approval or on-device
touch acceptance is claimed. Walking has no collision/navigation obstacles, commits
on stop/action/save, and does not set the final world-clock rate. Saving is explicit;
automatic mobile suspension saving is not yet connected. Native manual recovery is
tested; Web filesystem synchronization, Android/iOS exports and device performance
remain unverified. The existing native store still rejects Web save requests.

Ordinary commodities only: no unique-item state, reservations, property leases,
legal ownership/theft, dynamic prices, crafting, growth, NPC behavior or Ink adapter.
The most useful next increment is an optional delivery/small job with one-time
completion evidence and a finite reward, reusing these item and wallet rules.
