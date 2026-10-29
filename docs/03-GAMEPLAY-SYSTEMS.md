# GDD 03 — Gameplay and Simulation Systems
**Status:** initial design · **Updated:** 2026-10-29

## Governing principle
Systems create a believable possibility space; authored content fills it. Avoid a bespoke one-off script for every quest, NPC, or discovery.

## Time and life
- World clock, day/night cycle, rest/sleep, shop hours, NPC routines and relevant needs.
- **Skyrim-lite**, not a demanding survival sim. Exact day length, fatigue, hunger/thirst, seasons, and penalties are **Open**.
- Time advances consistently when traveling, resting, jailed, or away from a location. Offscreen NPCs do not require constant full-fidelity simulation.
- A player on mobile must be able to safely suspend/resume. Do not impose real-world attendance schedules.

## Work, items, economy
Early low-paid work can include stable chores, cleaning, carrying parcels, courier errands, gathering and simple services. Inventory, ownership, currency and services should be data-defined. Different regions may have differing legal rules, economic opportunities, and currencies later (**Provisional**, not first-build implementation scope).

Small practical skills can influence combat, crafting, speech and livelihood such as farming/fishing. Learn new recipes, crops, methods and opportunities from people and discovery, not exclusively by points on a skill tree.

## Housing and livelihoods
Start sleeping in/around the stable; later rent a room in an inn and acquire a small house, optionally with adjoining land for cultivation and selling crops. Home interiors, furniture, ownership, storage, and farming must not require a full Sims building simulator. Important future home: ownable, upgradeable traveling boat.

## NPC simulation and relationships
Schedules should be defined as data, with lightweight remote simulation. Relationships are shaped by interactions and story consequences. Do not prebuild a full personality psychology engine; start with the smallest state model that can accurately support authored conditions and consequences. Characters can have routines and independent activities when the player is elsewhere.

## Adventure, stealth and combat
Combat is **lightweight, readable, player-skill based**, relying more on timing and spatial awareness than equipment stats:
- Dodge, roll, defensive block of selected lighter attacks.
- Enemy weak spots and readable enemy tells where appropriate.
- Fleeing, avoiding, hiding or bargaining is frequently the better outcome.
- Use weapon **families** to share coherent movement/animation sets rather than unique rigs per item.
- Equipment changes must respect 2D sprite/animation limitations; no cloth/hair physics.

**Absolute rule:** city guards/soldiers/security are not normal damageable combat targets. Attempt to attack them → scripted arrest/consequences, no guard battle. This is not encouragement to become an outlaw.

## Law, pursuit, prison
Trespassing or prohibited goods/actions can lead to suspicion and pursuit. Hiding/escaping lets the wanted level cool down under fair, communicated rules. Arrest can mean short imprisonment (e.g., one or two in-world days), fine, confiscation where warranted, and repeat-offense consequences. Ability to persuade, use contacts, or negotiate is a design direction.

The prison is a real social space with NPCs, stories, rumors, and opportunities, **not** a blank punishment timer. Do not gate essential world truths exclusively behind getting arrested or allow prison to become a repeatable reward farm. Attacking guards must lead to scripted arrest rather than ordinary combat.

## Death, checkpoints and saves
**Locked:** death/defeat reloads a previous save or checkpoint; it is distinct from legal arrest.
**Open:** exact checkpoint policy. Desired balance is meaningful danger and avoiding F5/save-scumming *while still protecting mobile progress*. Separate technical recovery/autosave from the in-game defeat/rollback point. Avoid arbitrary long replays or punitive save loss.

## Magic
Ordinary human character. Magical effects/abilities may be temporary, conditional, consumable, or attached to objects. No assumed permanent spell tree.

## Cross-system examples (not hardcoded quests)
- A sailor mentions a passage; knowledge changes but the passage was always there.
- A rare seed brought from another land remains in inventory even if local soil cannot grow it.
- A forbidden item at a port may prompt inspection and legal risk based on local law; do not ambush players with unfair randomness.
- A failed clandestine errand can lead to a jail acquaintance and a new rumor rather than a Game Over.

## Work still open
Exact control mappings and combat states; clock pacing and needs; inventory/economy formulas; relationships representation; number of skills; law thresholds; death rollback rules. Build contracts and tests before multiplying data instances.
