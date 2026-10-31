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

**Implementation subset (#14, 31 October 2026):** D-050 and [HOUSING-PLAY.md](technical/HOUSING-PLAY.md) document optional authored access grants and constrained placement. This does not approve tenancy expiry/eviction or final property economics.

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

**Provisional implementation:** a simple logical snap/grid or a small number of permitted placement cells/surfaces. Choose the exact UX after a small touch control test. Validity checks may include property access, indoor/outdoor eligibility, floor index, footprint collision, doorway clearance, attachment surface and interaction reach. Keep dimensions in world/logical space; visual oblique sprites are not the placement authority.

Use the **same small placement-validation capability** where it genuinely applies to chests, furniture, and stations, but don't conflate placing a rug with farming soil/plant biology. The underlying floor index and stored placement persist regardless of camera-side cutaway/roof fading.

### 10.5 Furniture instance versus contained items
A chest is one placeable object that *provides* a container. Moving that chest must not copy or erase the items inside. If the design forbids moving a full chest, reject the operation with feedback; if allowed, persist the same container identity across moves. A rug or lantern may be purely decorative and need no storage system.

### 10.6 Multi-floor houses
The already established view rule distinguishes **global visible floor** from **camera-side occlusion**. Placement state must preserve the floor; hide/fade rendering may change, but it must not delete or move underlying furniture.

### 10.7 Persistence and relocation
Placed objects are persistent by stable property/room/floor and instance references. Renting a new room or moving out may trigger authored tenancy rules (leave, reclaim or pack furniture) but those are **Open gameplay policy**, not an invitation to silently lose items.

---

## 11. Trade, vendors, work, and money

These activities are an economic **bridge**, not an all-consuming market simulator.

### 11.1 Vendor exchanges
Vendor policy can decide whether an item is accepted, available stock, price quote and whether trade is currently possible (shop hours, reputation, region restrictions, etc.). The transaction boundary validates stock, money, available items and permissions; then commits both halves **exactly once**.

An item sold to a merchant may cease being the player's property, but should not disappear by an Inventory UI side effect. Vendor availability can be light and authored; no need to simulate every price/production chain daily across the entire fantasy world.

### 11.2 Small paid jobs
Courier deliveries, chores, assistance and collection jobs use an **opportunity/task contract**: source, requirements, optional deadline, evidence of completion, reward and social consequences. Jobs may reference Item, Time, Region or NPC state but should not own those systems. A job is not the same as a global mandatory quest.

### 11.3 Economic growth
Home rent/purchase, tools, seeds, stations, furniture and travel can be plausible ways to spend income. Earning money through fishing/farming/cooking/trade should be a valid option, **not** a necessity for every player.

### 11.4 Rules to defer
Dynamic currency exchange rates, global supply chains, persistent vendor economics, sophisticated inflation and business-worker management are **not approved initial features**. Region-specific currencies/legality may be added through data-driven policies later.

---

## 12. Connections to skills, companions, Ink and law

### Skills — contextual modifiers, not copied formulas
Owner confirmed skill expertise should apply **across livelihoods**, e.g. it may ease certain crop-care requirements and also help fishing. The skill system **does not own the action**: Farming owns the crop growth decision; Fishing owns catch/timing; Crafting owns its production rules. Each asks a narrow skill/progression service for **relevant modifiers** within domain-defined limits.

**Candidate contract:** evaluate `effective_rules = domain_base_rules + bounded_modifiers(actor, action_context)` in a deterministic order. Allow only explicit eligible modifier types; do not invent a universal reflection-driven effect language or global stat modifier bus.

Examples (not guaranteed progression bonuses):
- `Farming`: one fewer required watering event (with sensible minimum), limited soil tolerance, small growth-speed increase.
- `Fishing`: slightly wider timing window, clearer bite feedback, reduced escape probability or modest bait efficiency.
- `Cooking/Crafting`: short preparation improvement or reduced chance of a failed outcome where failure is genuinely designed.

**Hard rules survive:** fishing skill cannot conjure fish at the wrong place; farming skill cannot automatically cultivate realm-bound seeds in incompatible ordinary soil. There should be no global stat that turns every action into `+10% success`.

### Animal companions
Companions are social characters and travel partners, not automated mining/crafting bots or combat builds. They may interact with the world in authored circumstances, but every such interaction must use the same Inventory/World State rules as the player. No mandatory animal labor economy.

### Ink and Knowledge
The story system can acknowledge learning, cooking, a gift, a rent payment or a discovered fishing spot. Ink may **request** an authorized gameplay command; it should never set wallet totals or spawn physical goods by writing to an unrelated Ink variable. Physical goods remain world facts; knowledge stores awareness.

### Law
Gathering from another person's property, carrying contraband, or entering a forbidden workshop might be illegal depending on place/context. The law system decides consequences; livelihood systems report actions/results instead of duplicating guard logic.

---

## 12A. Architecture design — focused composition and reusable behavior policies

### 12A.1 Why favor composition?
**Candidate architectural policy, awaiting owner acceptance:** use shallow inheritance for genuine *is-a* relationships (e.g., a definition is a Resource, an item definition is a kind of authored definition), and **composition** for independent cross-cutting capabilities such as perishability, durability, placeability, and consumability. A future cooked meal, raw fish, herbal bundle and flower bouquet could all expire without inheriting from the same `CookedFood` class.

**Do not** model each combination through subclass pyramids such as `Item → Food → CookedFood → PerishableCookedFood` or attach a Node to every static item stack.

### 12A.2 Two kinds of composition
1. **Definition composition:** inspector/data-authored capability policies. Example `ItemDef` optionally references a `PerishabilityPolicy` with an in-game lifetime, storage/environment rules and expiry outcome. Other independent policies could describe equipment durability or placement constraints.
2. **Runtime composition:** an Item Instance/stack records only mutable state that policy needs, e.g. `created_at_world_minutes`, `expires_at_world_minutes` or a `freshness_state`. The authoritative ItemStore persists it; no new global SpoilageManager is required at first.

Prefer small typed Godot **Resource** policies for authored reusable data, or plain `RefCounted` rule objects for pure calculations if the overall architecture agrees. A `Resource` definition may be shared across many instances: **never mutate a shared definition when one meal spoils**.

### 12A.3 Spoilage (future capability, not automatic launch feature)
A prepared meal might be fresh for eight *in-game hours* (example value). So could a raw fish or a medicinal plant use the same capability with different data. The item store need not run 1 timer/Node/`_process()` per item:
- Record a stable world-clock timestamp or deadline on acquisition/creation, and persistent per-item state where justified.
- On a meaningful query/use/transfer, or a targeted schedule/reconciliation point, derive whether the item is fresh, stale or spoiled.
- If a state transition has gameplay consequences, apply it **once** through the owning inventory/item state service. A visual UI update must not perform the mutation.
- Storage could later alter the time policy (e.g. a cool cupboard prolongs freshness). Define how elapsed time under multiple environments accumulates **before** using such mechanics.
- Some expiry outcomes may replace one definition with another (fresh fish → spoiled fish); keep the **same authoritative item ledger**, not a duplicate and not an out-of-band object swap.

**Save/load:** store enough time and mutable state to reproduce the same expiry result. Reopening a bag must not trigger multiple spoilage conversions or effectively reset an expiration clock. Spoilage is strictly **game-time-based** for our cozy mobile release, not real-world offline decay.

**Open:** which actual items spoil, whether food spoilage ships in v1, whether players get warnings, which storage modifiers exist and whether spoiled goods are unusable or still have secondary uses.

### 12A.4 Reuse by rules, not one magical effects engine
The same composition principle can apply to:
- `Perishable` — food, some fish, herbs and flowers.
- `Durable` — a tool or fishing rod *if* gear wear adds interesting choices; don't force all items to have durability.
- `Placeable` — furniture, lamps, containers and maybe crafting stations, with spatial validity handled by Placement.
- `Consumable` — food and appropriate single-use items.
- `TemporaryEffect` — specific potions or artifacts whose magic expires.

These are **capability examples** to guide extensible data design, not an order to implement five behavior frameworks up front. Traits are not a replacement for coherent service ownership: Inventory transfers items; Farming grows crops; Fishing resolves catches; Placement validates furniture.

### 12A.5 Tests required before implementing shared policies
- Two unrelated items share `Perishable` with distinct durations but no inheritance dependency.
- Many item instances share one immutable definition without sharing runtime spoilage state.
- Region unload, travel and sleep advance the same canonical clock; no realtime offline decay.
- Opening inventory repeatedly or saving/reloading cannot duplicate spoilage effects.
- High Farming/Fishing skill changes permitted thresholds but cannot override disallowed species/biome/location.
- A canceled/failed short craft never consumes ingredients without the promised result.

### 12A.6 Minimal GDScript sketch (conceptual only)

```gdscript
# Authored data (shared among instances; exact schema TBD)
class_name PerishabilityPolicy
extends Resource

@export var lifetime_game_minutes: int = 480

# ItemDefinition references an OPTIONAL PerishabilityPolicy.
# The save records the individual item's creation/deadline.
# Querying an item calls a pure calculator with the WorldClock:
#   calculate_freshness(policy, item_state, world_clock_time)
# The owning ItemStore commits a transition if one is required.
```

This sketch is not a real code file and does not constitute an approved project structure. Use `Resource` for authored policy and serializable data, not as a universal substitute for `WorldState` or `SaveService`.

---

## 13. Cross-system interactions that need to be coherent

| Scenario | Requested intent | Affected authoritative domains | Success condition / failure mode |
| --- | --- | --- | --- |
| Plant purchased seed | `Plant(plot, seed)` | Inventory, Ownership, Farming, Clock | Seed consumed once, crop placed once; deny if plot unavailable |
| Harvest an herb | `Harvest(source)` | World Source, Inventory, Time | Source updated and item granted once; no duplicate on re-entry |
| Catch and cook fish | `Fish → Craft` | Fishing, Inventory, Cooking | One catch followed by one food output, with valid input consumption |
| Sell a prepared sweet | `Sell(quote, items)` | Trade, Money, Inventory | Goods and payment change together; no duplication on reload |
| Move chest in home | `Place/Relocate` | Housing, Placement, Inventory | Chest retains identity and contents; no blocked doorway |
| Leave a region while crops grow | `AdvanceTime / EnterRegion` | World Clock, Farming, Persistence | Deterministic reconciliation; no per-frame offscreen processing |
| Learn unfamiliar recipe | `Teach/Discover` | Narrative, Knowledge/Skills, Crafting | Recipe availability changes; no free production/inventory creation |
| Bring seed from distant realm | `Travel → Plant` | Travel, Inventory, Farming, Environment | Seed persists across travel; local cultivation result follows environment |
| Sleep during a timed batch | `Rest` | Clock, Crafting, Inventory, Needs | One consistent resolved state; no double completion |
| Move out of rented room | `EndLease` | Property, Placement, Inventory | Declared policy handles furniture safely; never implicit deletion |

These are specification/verification scenarios, not launch-content commitments.

---

## 14. Save/load, transaction safety and determinism

**Required invariants for any implementation:**
1. **No item duplication** by repeated UI signals, scene reload, craft completion, harvest, trade, or save/restore.
2. **No partial transactions:** a failed sale or craft cannot consume goods without the corresponding result.
3. **Single elapsed-time application:** growth, preparation and daily charges are reconciled at most once per in-world interval/event.
4. **Scene-independent state:** game-session ownership is not destroyed when leaving the room, land, harbor or fishing spot.
5. **Knowledge/world separation:** hearing a rumor never changes the physical existence of a resource/secret.
6. **Meaningful failure feedback:** capacity, permission, recipe, weather or soil failure should be understandable to a human player.
7. **No clock-driven offline punishments:** in-game progress uses world time; real life doesn't silently destroy crops because the app was closed.
8. **Versioned persistent references:** saves refer to stable content/entity IDs, not merely node paths or current UI indices.
9. **Save consistency:** do not save half-completed multi-domain operations.
10. **Repeatable tests:** seeded random outcomes should not be re-rolled by opening menus/reloading when the outcome was already committed.

### Fixture-based verification (not a vertical slice)
A tiny non-shipping test set is sufficient: two container types, two item varieties, one recipe, one crop with compatible/incompatible terrain, one fishing spot, one furnished room and one vendor. These are **illustrative counts for tests only**, not the official game content inventory.

Test cases should cover success/failure, repeated commands, reload and cross-region travel. Tests should assert **state invariants** rather than pixel-perfect menu screenshots.

---

## 15. Proposed implementation sequence (systems first, content light)

**L0 — Shared item/ownership contract.** Define stable IDs, item quantities/instances, container transfer, ownership check, persistence roundtrip. Test without polished graphics.

**L1 — Commerce + transformation contract.** One paid exchange and one simple recipe; atomic trade and craft, consistent inputs/outputs. Avoid real NPC market AI.

**L2 — Persistent spatial placement.** One property/room and a placeable object with container identity. Show move/save/reload validity in a disposable Godot test scene.

**L3 — Clock-dependent livelihood.** Add one growing crop and one time-based preparation *only if the latter is approved*. Test sleep/travel/unload/reload reconciliation.

**L4 — Fishing/gathering interaction.** Prove world spot → interaction → result → Inventory, and that learning a rumor doesn't spawn the spot. Touch UX can be separately tuned.

**L5 — Increase real content.** Add authored recipes/crops/fishing places/homes/stalls **after** schemas, behavior and UX prove themselves. The art pipeline can advance in parallel without blocking business rules.

This is a **dependency-based roadmap**, not a commitment to implement every feature now.

---

## 16. Design decisions needing owner approval

| Question | Options / why it matters | Default recommendation **for discussion** |
| --- | --- | --- |
| Is there a general item/container model? | Separate bag/chest/shop ledgers vs one shared model | **One shared model** with explicit location/ownership boundaries |
| How granular are item instances? | Every fruit unique vs simple stacks + unique stateful goods | Stack ordinary goods; instances when genuinely stateful |
| Is crafting instant or timed? | **Approved:** short active-play seconds; no idle/mobile waiting | Tune exact seconds and cancellation/interrupt policy |
| Must recipes be learned? | Experimentation versus knowledge-gated actions | Support discovery, but decide restrictions per feature/content |
| What does fishing feel like? | **Approved:** bait + short timing minigame; location-specific catch pools, exotic aquatic life later | Tune timing, bait consumption and touchscreen feedback |
| Do crops require watering / can they die? | **Approved:** soil/environment + watering requirement + growth time + bounded skill assistance | Exact water intervals, failure/death pressure and growth pacing open |
| Is home placement gridded? | **Approved:** deliberately constrained simple 2D furniture placement | Snap/grid/cells choice open pending quick touch test |
| Furniture in rented spaces? | Lease expiration and property ownership implications | Preserve item identity and plan a safe relocation rule |
| Vendor economy complexity? | Static quotes vs simulated stock/markets | Simple data-driven stock/quotes to start |
| Which livelihoods ship in v1? | A catalog is not release scope | Decide after system contracts and player UX tests |
| Do we use composition or deep inheritance? | **Proposed:** shallow inheritance + optional data-driven capabilities (e.g. future perishability) | Owner review; no generic trait engine yet |
| How do Skills share behavior? | **Approved direction:** expertise helps multiple activities; **proposed:** each system applies bounded contextual modifiers | Decide concrete bonuses by skill and ensure non-negotiable ecology/biome requirements remain |

## 17. Acceptance criteria for adopting this GDD
- Owner agrees to the **domain separation**, not necessarily each proposed mechanic.
- The architecture ADR explains how these domains live within a Godot GameSession and SceneTree.
- All multi-system operations have a clear **authority and validation path**.
- There is a small testing strategy for transaction/clock/persistence correctness.
- Optional activities remain optional; the sandbox can expand without a different `*Manager` for every plant, fish or house.
- Decisions and open questions are recorded centrally before implementation.

---

## Appendix A — Evidence from our existing Godot work (not a code migration order)

The public repository [Kiosk on the Nile](https://github.com/MohamedXIV/kiosk-on-the-nile) uses Godot Standard **4.7.2**, GDScript, a vendored Godot-4 `inkgd` adapter and a compiled Ink JSON workflow. Its README describes separate `game/items`, `game/cooking`, `game/spaces`, `game/time`, `game/economy` and `game/persistence` responsibilities; current tree contains an item store/service, recipe/station/job logic and shared placement rules.

**Lessons worth carrying forward:**
- Keep item ownership/transfers canonical and prevent duplicate ingredient usage.
- Separate actual spatial rules from visual arrangement.
- Time-advanced jobs should survive saves and snapshot committed inputs/parameters.
- A shared clock and declared update order avoid duplicate or inconsistent progression.
- Narrative runtime is viable in Godot/GDScript/Web, though **Behind the Lanterns** still requires integration, UX and mobile export checks.

**Do not automatically transplant** Kiosk's cooking complexity, entire dependency scheduler, APIs or content schemas: this game's world, pace and production needs differ.

## Appendix B — Related documents

- `docs/00-CONSTITUTION.md` — non-negotiable design pillars.
- `docs/03-GAMEPLAY-SYSTEMS.md` — gameplay overview and adventure/law context.
- `docs/06-ARCHITECTURE-RFC.md` — unratified language/DI/lifecycle tradeoffs.
- `docs/07-SYSTEM-CATALOG.md` — responsibility inventory (this GDD expands the livelihood part).
- `docs/DECISIONS.md` — authoritative decision status.

