# Candidate System Catalog — System Boundaries Before Code
**Status:** DRAFT / INVENTORY FOR REVIEW, not an implementation order.
**Updated:** 2026-10-29

## How to read this catalog
A **system** is a meaningful cohesive responsibility, **not** automatically a Godot node, a separate C# project, a singleton, or even a class. A few responsibilities may share a small implementation until complexity justifies division. The category is **Foundation (F)**, **Life (L)**, **Adventure (A)**, **Presentation (P)**, or **Platform (X)**.

Status: **Core candidate**, **Feature candidate**, **Later**, or **Decision needed**. "Core candidate" means central to long-term system boundaries—not that the whole feature is in the first coding milestone.

## A. Application and simulation foundations

| ID | Capability | Owns | Does NOT own | Candidate priority |
| --- | --- | --- | --- | --- |
| F01 | App Bootstrap / Composition | Create/dispose game sessions, wire cross-scope dependencies | Inventory, dialogue, travel logic | Core |
| F02 | Game Session & World State | Authoritative persistent facts and entity/region state | Godot scene tree representation, rumors | Core |
| F03 | Identity & Definitions | Stable IDs, validation and lookup of authored content definitions | A running player's persistent state | Core |
| F04 | World Clock & Time Advancement | Current game time, advancing days/hours from actions | A simulated `_Process` loop per distant actor | Core |
| F05 | Region / Scene Lifecycle | Which region is loaded, spawning/despawning presentations | Owning persistent NPC truth | Core |
| F06 | Save / Load | Save files, schema versions, technical recovery, validation | Defeat penalty design | Core |
| F07 | Checkpoint / Defeat | Approved rollback anchors, loss/retry policy | Technical application recovery alone | Decision needed |
| F08 | Domain Commands / Notifications | Validated mutations and narrow change notifications | Unbounded event-bus magic | Core |
| F09 | Randomness / Determinism | Named seeds/streams for reproducible simulation where needed | Every cosmetic random animation | Candidate |
| F10 | Session Diagnostics | Debug inspection of world/knowledge/time, repeatable test harness | Gameplay decisions | Candidate |

## B. Narrative and social semantics

| ID | Capability | Owns | Does NOT own | Candidate priority |
| --- | --- | --- | --- | --- |
| N01 | Knowledge / Rumors | What player has heard, suspected, verified; sources | Existence/position of actual secret places | Core |
| N02 | Ink Narrative Adapter | Story execution, choices, tags, conditional outputs, commands through gateway | Saving all world facts or editing scenes directly | Core |
| N03 | Conversation Presentation | Text UI, portraits, gibberish audio, localization display | Ink logic and relationships truth | Feature |
| N04 | Opportunities / Activities | Optional tracked jobs, favors and commitments, if needed | Mandatory universal quest list | Feature |
| N05 | Relationships | Affinity/trust/social flags and long-term memories appropriate to content | Full personality simulation | Feature |
| N06 | Actor State & Schedule | Where named NPCs should be and their persistent states | Their active sprite per unloaded region | Core |
| N07 | Social Context / Reputation | Relevant community/legal impressions where actual content requires them | Arbitrary global morality meter | Later |

## C. Everyday livelihood

| ID | Capability | Owns | Does NOT own | Candidate priority |
| --- | --- | --- | --- | --- |
| L01 | Inventory & Items | Stackability, capacity, item instance identity and transfer | Price or legality | Core |
| L02 | Money & Transactions | Balances, transfers, checked payment, price/currency handling | Dialogue or trade UI | Core |
| L03 | Ownership & Access | Which room/house/land/boat the player may use | Construction graphics | Feature |
| L04 | Work / Small Jobs | Pay and proof of service for chores/deliveries | A permanently locked player career | Feature |
| L05 | Trade / Vendors | Buy/sell rules, stock and availability | A fixed economic history of every world market | Feature |
| L06 | Crafting / Learning | Recipes, ingredient requirements, learned techniques, **short active-play production time** | Idle/mobile wait-to-return timers, universal skill-tree gates | Feature |
| L07 | Housing & Placement | Lodging, rooms, storage, and **restricted simple 2D** furniture placement with property validation | A construction simulator or an independent item ledger | Feature |
| L08 | Farming / Growing | Crop-specific soil/biome, watering requirements, growth time, harvest; consult bounded skill modifiers | Making farming mandatory or overriding impossible growing conditions | Feature |
| L09 | Needs / Rest | Rest and light everyday needs if player-approved | Hard survival meters by default | Decision needed |
| L10 | Character Skills | Limited progression in combat/speech/craft/life fields | Permanent supernatural magic mastery | Feature |
| L11 | Companions | Animal bonds, follow behaviors, routine actions, care | Combat pet battalions or collectible rarity economy | Feature |
| L12 | Fishing | Bait + short timing interaction, strongly location-specific fish pools and catch result; expand exotic types later | Item ledger, omnipresent fish pools, every fish as a simulated NPC | Feature |
| L13 | Gathering / World Sources | Physical gatherable source state, harvest availability, regrowth when designed | Inventory ledger or cultivated plot growth | Feature |
| L14 | Cooking / Food Preparation | Food-specific recipes/station interaction and any approved timed processing | Another Inventory manager; forced complex cooking jobs | Feature |

## D. Adventure, travel and consequences

| ID | Capability | Owns | Does NOT own | Candidate priority |
| --- | --- | --- | --- | --- |
| A01 | Player Movement / Interaction | Locomotion, world-space interactions, action intents | Persistence of whole world state | Core |
| A02 | Navigation / Local Perception | Pathfinding and proximity for loaded actors | Entire offscreen world navigation each frame | Feature |
| A03 | Region Travel / Routes | Public routes, capacity/availability checks, transition result | Entire cinematic trip runtime | Feature |
| A04 | Travel Log Presentation | Short optional narrated incidents and records | World state mutation without validated commands | Feature |
| A05 | Stealth / Pursuit | Visibility, detection, escape, suspicion cooldown | Forced combat with city guards | Feature |
| A06 | Combat | Attack/dodge/block/roll, timing, damage against legitimate enemies, weak spots | Damage against security/guards | Feature |
| A07 | Damage / Defeat | Hit points/conditions and appropriate defeat entry | Arbitrary save deletion | Feature |
| A08 | Law / Legal Status | Offenses, witness/inspection rules, wanted status, arrest eligibility | Morality/judging player character | Feature |
| A09 | Jail / Sentencing | Imprisonment duration, fines, release requirements, persistent status | Exclusively gated secrets and repeatable farm rewards | Feature |
| A10 | Temporary Magic / Effects | Timed conditions, consumables, temporary enchantments | Permanent spell-profession | Later |
| A11 | Boat as Mobile Home | Ownership, storage, upgrades, décor and travel capability | Mandatory fully simulated ocean sailing | Later |

## E. Scene/UI/platform responsibility (mostly Godot Nodes)

| ID | Capability | Owns | Does NOT own | Candidate priority |
| --- | --- | --- | --- | --- |
| P01 | Input Mapping | Touch/keyboard/controller mapping and action names | Game rules | Core |
| P02 | HUD / Menus | Display world/knowledge/player states, settings, accessibility | Economic or narrative state | Core |
| P03 | Building Floors / Occlusion | Global visible-floor presentation; camera-relative front-wall/roof hiding | Independent geometry topology and ownership | Feature |
| P04 | Audio & Gibberish | Spatial/UI/audio/music, synthetic character vocalizations | Narrative meaning | Feature |
| P05 | Visual FX & Animation | Animation state, weapon-family visuals, feedback | Weapon/economy rules | Feature |
| P06 | Localization | Text translation, UI language and font fallback | Hardcoded English text in gameplay logic | Core |
| X01 | Platform / Mobile Lifecycle | Suspend/resume, orientation, permissions, export-dependent integrations | Checkpoint penalty | Core |
| X02 | Settings & Accessibility | Audio, vibration, input visibility, text scaling, safe area | Simulation truth | Feature |
| X03 | Monetization Adapters | Optional ads toggle (free disable), platform ad SDK gateway, optional cosmetics | Predatory progression gates or economic simulation | Later |

For the detailed design and authority boundaries of all everyday-life capabilities, read **[GDD 08 — Life & Livelihood Systems](08-LIFE-LIVELIHOOD-GDD.md)**. Its §12A proposes **shallow inheritance + focused composable policy Resources** for cross-cutting qualities such as future perishability; shared skill modifiers are bounded by each activity's domain rules, not a universal effect manager. This table lists domains, **not** mandatory classes or initial-build commitments.

## Do NOT turn this table into 40 managers
This is a **capability inventory**, not a mandate to create 40 subsystems/classes. For example:
- Knowledge + Ink are separate *truth ownership boundaries*, but can initially be wired by one small adapter facade.
- Money and vendor transactions may share code at first while maintaining clear invariants.
- Region scene lifecycle, NPC presentation and camera handling are Godot-side concerns; persistent actor schedules live in simulation.
- Law and jail may share a small rules module while keeping guard attack handling separate from combat.
- Player *technical* recovery and gameplay *defeat checkpoints* must stay conceptually distinct.

## Initial dependency map
```text
Content Definitions ----> World State <---- Save / Load
                                ^
World Clock --------------------|
                                +------> Actor Schedule
                                +------> Inventory / Economy / Ownership
                                +------> Travel / Law / Combat
Player Knowledge ---------------+-----> Narrative Context Adapter
                                         |
                                       Ink Runtime
                                         |
                                   Validated Commands
                                         |
                                     World State

Region Scene  <---- snapshot / notices ---- Game Session
UI/Input      ---- intents/commands ------> Session Services
```
This diagram illustrates **directional ownership**, not every event or class reference.

## Proposed first implementation set (very small)
1. F01/F02/F03: session bootstrap, typed IDs, objective state and definitions.
2. F04/F06: world clock, save/load with deterministic time advancement.
3. N01/N02: semantic knowledge and Ink adapter.
4. P01/A01/F05: one disposable loaded-region fixture with an interactable secret.
5. X01/P02: touch and mobile pause/resume smoke tests.

**Explicitly not first milestone:** marketplace, complete combat, prison, boat ownership, large town, 20 professions, or full farming. These should depend on proven shared state/command contracts.

## Verification scenarios that should drive design, not content
- Discover a hidden passage by walking into it, **then** hear the rumor; knowledge should differ but world existence remain identical.
- Hear a false rumor; no non-existent world object should be conjured.
- Travel with a caravan: pay once, advance time once, update schedules once, arrive once, save/reload reliably.
- Attack a guard: no standard damage exchange; transition to arrest and later appropriate jail content.
- Sell and plant a rare seed in a different region: physical inventory persists; whether it grows follows local farming rules.
- Suspend app during exploration: restore player progress according to recovery contract, not a hack around gameplay checkpoints.

## Questions for owner review
1. Owner prefers **GDScript** and Web is a target; confirm typed GDScript-first, and decide whether any platform-specific native extension is genuinely required.
2. Do you prefer **one composition root + one GameSession**, or multiple global Autoloads?
3. Is **manual DI**, not a generic container, acceptable for the foundation?
4. Should offscreen NPC simulation be lightweight schedule reconciliation by default?
5. Are any systems in the table unnecessary for the intended first public version?
6. Do we distinguish physical world facts, belief/knowledge, and story-local transient variables explicitly?

**This catalog may change significantly after owner review.**
