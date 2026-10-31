extends RefCounted
## Acceptance and regression tests for Optional Exploration & Dangerous Destinations
## (D-004, D-005, D-006, D-007, D-008, D-016, D-053, GDD 02, GDD 03, F4).

func data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/linked_world.json"))

func model(world_id: String = "world.exploration-tests") -> GameplayModel:
	return GameplayModel.create(data(), world_id)

func run(t) -> void:
	_test_world_truth_and_discovery_before_rumor(t)
	_test_rumor_carrier_refusal_combat_retreat_and_return(t)

func _test_world_truth_and_discovery_before_rumor(t) -> void:
	var m := model("world.explore-truth-first")
	t.check(m != null, "linked_world with outer shoal exploration composes cleanly")
	if m == null: return

	# Objective world truths exist at minute 0 before any rumor or dialogue:
	t.check(m.session.definition().fact("fact.causeway_exists") and m.session.definition().fact("fact.arch_inscription_intact"), "causeway and arch inscription exist in objective world truth from session start")
	t.check(not m.session.definition().fact("claim.shoal_beacon"), "false sailor beacon rumor is never an objective world fact")
	t.check(m.session.snapshot().knowledge.is_empty(), "player knowledge starts empty")

	# Public travel to nearby safe landing (Estuary Quay):
	t.check(m.act("take-grain", "a:player", "a:supplies", "item.grain", 1, "take").ok, "collect grain bait before voyage")
	t.check(m.move_actor("to-boatman", "a:player", 640, 80).ok and m.take_route("to-estuary", "a:player", "route.ship_estuary").ok, "board public packet to Estuary Quay")
	t.check(m.actor_region("a:player") == "region.estuary", "arrive at safe Estuary Quay landing")

	# Discover causeway and outer shoal BEFORE speaking to the estuary boatman:
	t.check(m.move_actor("to-causeway", "a:player", 680, 200).ok and m.enter("cross-causeway", "a:player", "a:shoal-causeway").ok, "walk to and cross low-tide stone causeway without prior rumor")
	var snap := m.session.snapshot()
	t.check(m.actor_region("a:player") == "region.shoal" and snap.knowledge.get("claim.shoal_causeway", "") == "confirmed", "crossing causeway transitions to region.shoal and confirms claim.shoal_causeway")

	# Use the northern shelf (y = 90) behind the reef pillar obstacle to avoid a:reef-warden (at 450, 310) completely:
	t.check(m.move_actor("north-pool", "a:player", 220, 90).ok, "walk to northern tide pool outside shoal crab range")
	t.check(m.cast_line("shoal-cast", "a:player", "a:shoal-pool", "item.grain").ok and m.progress_fishing("shoal-wait", "a:player", 1800).ok and m.reel_line("shoal-reel", "a:player").ok, "brackish tide pool supports fishing in remote exploration region")
	t.check(m.move_actor("north-bypass", "a:player", 500, 90).ok and m.move_actor("at-arch", "a:player", 640, 140).ok, "northern shelf bypasses shoal crab threat without combat")
	t.check(m.combat.encounter(m.session.snapshot(), "a:player").is_empty(), "avoiding threat on northern route never forces combat engagement")
	t.check(m.inspect_object("inspect-arch", "a:player", "a:sunken-arch").ok, "inspect weathered lantern arch")
	snap = m.session.snapshot()
	t.check(snap.knowledge.get("claim.arch_inscription", "") == "confirmed" and not snap.knowledge.has("claim.shoal_beacon"), "firsthand inspection confirms arch inscription without needing prior rumor")

	# Backtrack across causeway to Estuary Quay and speak with the boatman after self-directed discovery:
	t.check(m.move_actor("to-return", "a:player", 100, 220).ok and m.enter("back-estuary", "a:player", "a:shoal-return").ok, "return across causeway to Estuary Quay")
	t.check(m.actor_region("a:player") == "region.estuary" and m.position_of("a:player") == Vector2(640, 200), "causeway return places player at eastern quay")
	t.check(m.move_actor("to-estuary-boatman", "a:player", 360, 200).ok and m.talk("talk-1", "a:player", "a:estuary-boatman").ok, "open Ink dialogue with estuary boatman")
	var conv := m.narrative.conversation(m.session.snapshot(), "a:player")
	t.check(conv.frame.choices.size() == 3 and conv.frame.choices[1].contains("Report the dry bronze brazier"), "boatman dialogue offers arch report choice immediately when already confirmed")
	t.check(m.talk("talk-ask", "a:player", "a:estuary-boatman", 0, conv.turns.size(), NarrativeRules.cursor(conv)).ok, "ask boatman about outer shoals after already crossing causeway")
	conv = m.narrative.conversation(m.session.snapshot(), "a:player")
	t.check(conv.frame.text.contains("already walked the low-water causeway yourself"), "Ink branch recognizes prior self-directed causeway discovery")
	t.check(m.session.snapshot().knowledge.get("claim.shoal_causeway", "") == "confirmed", "confirmed causeway knowledge is never downgraded to heard by later rumor")

	# Report the arch inscription to the boatman:
	t.check(m.talk("talk-2", "a:player", "a:estuary-boatman").ok, "re-open boatman dialogue to report arch")
	conv = m.narrative.conversation(m.session.snapshot(), "a:player")
	t.check(m.talk("talk-report", "a:player", "a:estuary-boatman", 1, conv.turns.size(), NarrativeRules.cursor(conv)).ok, "report dry brazier and tide-mark to boatman")
	t.check(m.session.snapshot().domains.narrative.reports.get("a:player", {}).get("claim.arch_inscription", "") == "a:estuary-boatman", "arch inscription report persisted in narrative domain")
	m.session.close()

func _test_rumor_carrier_refusal_combat_retreat_and_return(t) -> void:
	# Validate hazard_refusal schema check in TravelRules:
	var bad_hazard := data()
	bad_hazard.travel.routes["route.ship_sunken_arch"].hazard_refusal = ""
	t.check(GameplayModel.create(bad_hazard, "world.bad-hazard") == null, "empty hazard_refusal rejected by TravelRules.create")

	var m := model("world.explore-rumor-first")
	t.check(m.move_actor("to-boatman", "a:player", 640, 80).ok and m.take_route("to-estuary", "a:player", "route.ship_estuary").ok, "arrive at Estuary Quay")
	t.check(m.move_actor("near-estuary-boatman", "a:player", 360, 200).ok, "approach estuary boatman")

	# 1. Hear rumor from boatman BEFORE exploring:
	t.check(m.talk("open-rumor", "a:player", "a:estuary-boatman").ok, "start boatman conversation")
	var conv := m.narrative.conversation(m.session.snapshot(), "a:player")
	t.check(conv.frame.choices.size() == 2, "report choice hidden before arch is inspected")
	t.check(m.talk("hear-rumor", "a:player", "a:estuary-boatman", 0, conv.turns.size(), NarrativeRules.cursor(conv)).ok, "hear boatman's shoal rumor")
	var snap := m.session.snapshot()
	t.check(snap.knowledge.get("claim.shoal_causeway", "") == "heard" and snap.knowledge.get("claim.shoal_beacon", "") == "heard", "boatman conversation records causeway and beacon claims as heard")
	t.check(not m.session.definition().fact("claim.shoal_beacon"), "hearing rumor does not create objective world truth")

	# 2. Public carrier refuses hazardous direct route to Outer Shoal Ruins:
	t.check(m.travel.is_hazardous("route.ship_sunken_arch") and m.travel.hazard_refusal_text("route.ship_sunken_arch").contains("causeway"), "route metadata identifies hazardous destination refusal")
	var before_refusal := m.session.snapshot()
	var refusal := m.take_route("try-sunken-arch", "a:player", "route.ship_sunken_arch")
	t.check(not refusal.ok and refusal.code == "carrier_refuses_hazard" and m.session.snapshot() == before_refusal, "carrier refuses hazardous destination atomically without charging fare or advancing time")

	# 3. Cross causeway on foot, upgrading claim.shoal_causeway from heard -> confirmed:
	t.check(m.move_actor("walk-causeway", "a:player", 680, 200).ok and m.enter("enter-shoal", "a:player", "a:shoal-causeway").ok, "cross causeway on foot")
	t.check(m.session.snapshot().knowledge.get("claim.shoal_causeway", "") == "confirmed", "crossing causeway upgrades knowledge from heard to confirmed")

	# 4. Approach a:reef-warden on southern ledge, read its opening heavy telegraph, and retreat without defeating it:
	t.check(m.move_actor("south-approach", "a:player", 390, 310).ok and m.engage_combat("engage-crab-1", "a:player", "a:reef-warden").ok, "engage shoal crab on southern ledge")
	t.check(m.progress_combat("crab-poised", "a:player", 600).ok, "advance shoal crab to first telegraph")
	var enc := m.combat.encounter(m.session.snapshot(), "a:player")
	t.check(enc.phase == "heavy_windup" and enc.last_event == "telegraph_heavy", "shoal crab opens with heavy claw telegraph")
	t.check(m.retreat_combat("retreat-crab", "a:player").ok, "retreat from shoal crab")
	enc = m.combat.encounter(m.session.snapshot(), "a:player")
	t.check(enc.status == "retreated" and m.position_of("a:player") == Vector2(200, 290), "retreat moves player to safe western ledge")

	# Backtrack to Estuary Quay and re-enter to prove persistence across region transitions:
	t.check(m.move_actor("back-door", "a:player", 100, 220).ok and m.enter("leave-shoal", "a:player", "a:shoal-return").ok and m.actor_region("a:player") == "region.estuary", "can backtrack to Estuary Quay after retreating")
	t.check(m.move_actor("again-door", "a:player", 680, 200).ok and m.enter("reenter-shoal", "a:player", "a:shoal-causeway").ok and m.actor_region("a:player") == "region.shoal", "re-enter Outer Shoal Ruins")

	# 5. Defeat a:reef-warden via skill timing (dodge heavy -> strike weak spot -> block light -> strike weak spot), loot cache, inspect arch, and return home:
	t.check(m.move_actor("re-approach-crab", "a:player", 390, 310).ok and m.engage_combat("engage-crab-2", "a:player", "a:reef-warden").ok, "re-engage shoal crab")
	t.check(m.progress_combat("tell-1", "a:player", 600).ok and m.dodge_combat("dodge-heavy", "a:player").ok and m.progress_combat("resolve-heavy", "a:player", 950).ok, "dodge heavy claw slam to expose shell seam")
	t.check(m.strike_combat("weak-1", "a:player").ok and m.combat.encounter(m.session.snapshot(), "a:player").threat_health == 2, "strike exposed shell seam for 2 damage")
	t.check(m.progress_combat("tell-2", "a:player", 600).ok and m.block_combat("block-light", "a:player").ok and m.progress_combat("resolve-light", "a:player", 750).ok, "block second-step light lunge to expose shell seam")
	t.check(m.strike_combat("weak-2", "a:player").ok and m.combat.encounter(m.session.snapshot(), "a:player").status == "victory", "second weak-spot strike defeats shoal crab")

	t.check(m.move_actor("to-cache", "a:player", 620, 290).ok and m.act("take-salvage", "a:player", "a:tidal-cache", "item.river_lotus", 2, "take").ok, "collect river lotus salvage from tidal cache")
	t.check(m.move_actor("to-arch-2", "a:player", 640, 140).ok and m.inspect_object("inspect-arch-2", "a:player", "a:sunken-arch").ok, "inspect sunken arch after southern approach")
	snap = m.session.snapshot()
	t.check(snap.knowledge.get("claim.arch_inscription", "") == "confirmed" and snap.knowledge.get("claim.shoal_beacon", "") == "heard", "confirmed arch truth coexists with heard beacon rumor without overwriting")

	# Return to Estuary Quay, report truth to boatman, and take return packet to Courtyard:
	t.check(m.move_actor("exit-shoal", "a:player", 100, 220).ok and m.enter("return-quay", "a:player", "a:shoal-return").ok, "return to Estuary Quay with salvage and discovery")
	t.check(m.move_actor("boatman-quay", "a:player", 360, 200).ok and m.talk("open-report", "a:player", "a:estuary-boatman").ok, "talk to boatman to report arch")
	conv = m.narrative.conversation(m.session.snapshot(), "a:player")
	t.check(m.talk("do-report", "a:player", "a:estuary-boatman", 1, conv.turns.size(), NarrativeRules.cursor(conv)).ok, "report arch inscription to boatman")
	t.check(m.take_route("return-courtyard", "a:player", "route.ship_return").ok and m.actor_region("a:player") == "region.playground", "take return packet back to Courtyard")
	snap = m.session.snapshot()
	t.check(m.inventory.contents(snap, "a:player").get("item.river_lotus", 0) == 2 and snap.knowledge.get("claim.arch_inscription", "") == "confirmed" and snap.domains.narrative.reports["a:player"]["claim.arch_inscription"] == "a:estuary-boatman", "salvaged goods, confirmed discoveries, and reported truth persist back in everyday courtyard life")
	m.session.close()
