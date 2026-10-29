# GDD 02 — World, Narrative, Knowledge and Travel
**Status:** initial design · **Updated:** 2026-10-29

## Geography and time
**Locked:** recognizably named real countries/lands (Egypt, the Levant, Baghdad/Basra and trade routes as appropriate) alongside mythical or unknown locations. The world is **timeless Arabian fantasy**, informed by the atmosphere of *One Thousand and One Nights*: rich real-world grounding, legendary freedom, no exact century or historical ruler.

**Provisional:** Alexandria as the opening city. Its name, layout, and starting-neighborhood map are not yet formally locked. A legendary Alexandria need not reproduce one archaeological period.

## The familiar and the hidden
The everyday world has coherent economy, customs, travel, law, and social life. Otherworldly or remote places may have distinct ecology, danger, economy, currency, laws, and attitudes toward magic. The boundary may be geographic, social, secret, or mythic; do not force every wonder behind a portal.

A secret entrance, hidden island, artifact, or person **exists independent of whether the player has heard of it**. A warning can make finding something easier, but never creates it. Knowledge can be false, contested, or partial.

## Narrative system
**Ink is the authoring/runtime narrative language**, used for dialogue and broader story flow, conditions, rumors, opportunities, and reactions. It does not directly own simulation data.

Suggested separation:
- **World State:** objective physical/social facts and their persistence.
- **Knowledge State:** what this player has heard, inferred, verified, and from whom.
- **Ink narrative content:** conditions, text, choices, and narrative consequences.
- **Gameplay services:** authorized commands to move items/money, adjust relationships, register discoveries, trigger travel/arrest, etc.

Use stable semantic fact IDs, not a hardcoded dialogue tree of quest toggles. Example: `old_harbor_passage` may be Unknown/Heard/Suspected/Confirmed; this is about player awareness, not whether the passage exists. The enum is a **candidate modeling approach**; representations stay open until contract design.

Narrative events can emerge from imprisonment, missed meetings, overheard tales, a repaired relationship, a sailor's log, or self-directed exploration. Dialogue text supports localization; voices are invented nonverbal/gibberish sounds. Keep player naming flexible in text if later supported.

## Journey and travel
- Public **ships** on maritime routes and **caravans** on land routes (including travel between cities within a country).
- Most scheduled/ordinary transport uses fast travel and an optional concise illustrated/written **travel log** (approximately 1–2 minutes of storytelling at most, not a compulsory two-minute delay).
- Navigators generally refuse dangerous/unknown destinations. A ship may land nearby, leaving the player to cross in a small craft or on foot.
- A privately owned boat is an important later progression path: travel freedom, upgrades, decorations, storage, and the feeling of a mobile home. It should not magically remove all geographic and logistical rules.
- Distant places should be designed as appropriate locations/regions, not demand a fully continuous world map.

## Social meaning
NPCs have routines and relationships and are not interchangeable quest kiosks. Gossip, trust, disputes, kindness, speech, and imprisonment can expose different stories. Narrative paths are optional; knowledge gained in one context can affect another without compelling the player to follow a specific chain.

## Open design work
Exact starting location; density/size of each region; route availability and travel-log format; levels of uncertainty in knowledge; scheduling for offscreen NPCs; cross-region item/law/currency rules; authored narrative content count. None should be hardcoded into core systems.
