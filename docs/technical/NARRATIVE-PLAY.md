# Narrative play — #5 / #14

Approach the merchant and press Talk. Ask about the workshop to hear uncertain
hearsay, or accept the existing funded provisions job through a dialogue choice.
Explore the workshop's narrow side passage without any rumor prerequisite; use
the old basin in the alcove to observe its dry channel. Return to the merchant:
Ink responds to what you actually found, and to accepted/completed delivery work.
The Conversations tab includes a journal distinguishing Heard and Confirmed.
This small folklore thread is disposable test content, not a canonical storyline.

Static facts and the passage's physical identity are authored at world creation.
Knowledge never spawns a place or changes a fact. Discovery confirms only a
configured observation of a true fact; dialogue can add hearsay, never confirm a
fact or change arbitrary gameplay values. Existing reach/region/obstruction and
NPC availability rules gate conversations and choices. Ink command tags map to
an explicit local allowlist: hear a known claim or request an existing Work action.
Unknown/failed commands roll back the entire beat, including earlier effects and
conversation continuation. No new quest, reward or item ledger.

The only third-party boundary is InkDialogue, using the real vendored inkgd VM and
inklecate 1.2.1 output. NarrativeRules owns a bounded conversation per actor, with
choice indexes and the boolean query context seen at each turn. Saved frames are
verified by replay, not fed to an arbitrary VM-state deserializer. Effects execute
only on the new beat; replay never reapplies them. This intentionally trades some
CPU for a small, verifiable save boundary (32 turns, 128 output lines per beat).
Fresh conversations restart the authored entry point; completed/accepted work and
knowledge still come from their authoritative domains. No randomness/external
callbacks are used by this thread. Long-running serial stories, localization,
voice/gibberish, dialogue cameras and authored random stories require later work.

Compiled bytes are included in the content fingerprint; story edits invalidate
old development content saves rather than silently replaying incompatible history.
The saved journal remains the existing single-player semantic Knowledge store.
There is no claim here of general multiplayer knowledge or a full epistemic logic.

Verification uses tools/test-headless.sh on actual Godot 4.7.2: rule/regression,
real node/button UI and separate-process native restart, including pending Ink
choices and certainty. Mobile exports, Web synchronization and on-device UX remain
unverified. Compiler/runtime provenance is in addons/inkgd/BTL-VENDOR.md.

Final execution: Godot 4.7.2.stable.official.ed1daf0bf; 397 regression assertions,
43 actual gameplay/UI assertions, original/connected/region/narrative separate-process
restart and startup PASS, with no warnings/errors. Unknown story actions roll back
prior hearsay effects and the cursor; malformed frames/contexts and stale choices
are rejected. Vendored runtime sources match the pinned Kiosk tree byte-for-byte.
