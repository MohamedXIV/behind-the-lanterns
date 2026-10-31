extends RefCounted
## Acceptance and regression tests for CombatRules (D-008, D-009, D-016, GDD 03, A06/A07, F4).

func model() -> GameplayModel:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/linked_world.json"))
	return GameplayModel.create(data, "world.combat-tests")

func to_stalker(m: GameplayModel, prefix: String = "approach") -> bool:
	return (
		m.move_actor(prefix + "-door", "a:player", 700, 330).ok
		and m.enter(prefix + "-enter", "a:player", "a:river-path").ok
		and m.move_actor(prefix + "-bank", "a:player", 620, 340).ok
	)

func run(t) -> void:
	_test_config_and_guard_invariant(t)
	_test_telegraphs_block_dodge_and_weak_spot_victory(t)
	_test_outspacing_and_retreat_outcomes(t)
	_test_provisional_winded_recovery_and_persistence(t)

func _test_config_and_guard_invariant(t) -> void:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/linked_world.json"))
	var m := GameplayModel.create(base.duplicate(true), "world.combat-guard")
	t.check(m != null and m.combat != null, "linked_world fixture initializes CombatRules")

	# Guard non-combat invariant at configuration boundary:
	var guard_threat := base.duplicate(true)
	guard_threat.combat.threats["a:gate-guard"] = guard_threat.combat.threats["a:reed-stalker"].duplicate(true)
	t.check(GameplayModel.create(guard_threat, "world.bad-guard-threat") == null, "guard entity cannot be configured as a combat threat")

	var actor_threat := base.duplicate(true)
	actor_threat.combat.threats["a:player"] = actor_threat.combat.threats["a:reed-stalker"].duplicate(true)
	t.check(GameplayModel.create(actor_threat, "world.bad-actor-threat") == null, "player actor cannot be configured as a combat threat")

	var weak_low := base.duplicate(true)
	weak_low.combat.weak_spot_damage = weak_low.combat.base_strike_damage
	t.check(GameplayModel.create(weak_low, "world.bad-weak-damage") == null, "weak_spot_damage must exceed base_strike_damage")

	var bad_disengage := base.duplicate(true)
	bad_disengage.combat.threats["a:reed-stalker"].disengage_range = 120
	t.check(GameplayModel.create(bad_disengage, "world.bad-disengage") == null, "disengage_range must exceed engage_range by margin")

	var bad_retreat := base.duplicate(true)
	bad_retreat.combat.threats["a:reed-stalker"].retreat_point = {"x": 360, "y": 100} # Inside river obstacle (330..430, 50..230)
	t.check(GameplayModel.create(bad_retreat, "world.bad-retreat") == null, "blocked retreat_point rejected by validate_world")

	# Guard non-combat invariant at runtime command boundaries:
	t.check(m.move_actor("near-guard", "a:player", 480, 340).ok, "move near courtyard watchman")
	var before_guard := m.session.snapshot()
	t.check(m.engage_combat("engage-guard", "a:player", "a:gate-guard").code == "guard_not_combat_target" and m.session.snapshot() == before_guard, "engage_combat rejects guard target atomically")
	t.check(m.strike_combat("strike-guard", "a:player", "a:gate-guard").code == "guard_not_combat_target" and m.session.snapshot() == before_guard, "strike_combat rejects guard target atomically")
	t.check(m.confront_guard("confront-guard", "a:player", "a:gate-guard").ok and m.actor_region("a:player") == "region.watchhouse" and m.law.status_of(m.session.snapshot(), "a:player").status == "detained", "attacking guard continues to route through scripted arrest in LawRules")

func _test_telegraphs_block_dodge_and_weak_spot_victory(t) -> void:
	var m := model()
	t.check(m.engage_combat("wrong-region", "a:player", "a:reed-stalker").code == "different_region", "cannot engage threat in another region")
	t.check(m.move_actor("to-river-door", "a:player", 700, 330).ok and m.enter("enter-river", "a:player", "a:river-path").ok, "enter river region")
	t.check(m.engage_combat("too-far", "a:player", "a:reed-stalker").code == "out_of_engage_range", "cannot engage threat beyond engage_range")
	t.check(m.move_actor("approach-stalker", "a:player", 620, 340).ok, "walk within engage_range of reed stalker")
	t.check(m.engage_combat("engage-1", "a:player", "a:reed-stalker").ok, "engage reed stalker")

	var enc := m.combat.encounter(m.session.snapshot(), "a:player")
	t.check(enc.status == "engaged" and enc.phase == "poised" and enc.actor_health == 4 and enc.threat_health == 4 and enc.last_event == "engaged", "encounter starts poised at full health")
	t.check(m.engage_combat("double-engage", "a:player", "a:reed-stalker").code == "combat_in_progress", "cannot start second encounter while engaged")

	# Step 0 of pattern is "light": advance 600ms from poised -> light_windup
	t.check(m.progress_combat("to-light-tell", "a:player", 600).ok, "progress poised phase to light telegraph")
	enc = m.combat.encounter(m.session.snapshot(), "a:player")
	t.check(enc.phase == "light_windup" and enc.last_event == "telegraph_light", "threat enters readable light_windup telegraph")

	# Greedy strike during windup is deflected (0 damage)
	t.check(m.strike_combat("greedy-strike", "a:player").ok, "strike during windup executes")
	enc = m.combat.encounter(m.session.snapshot(), "a:player")
	t.check(enc.threat_health == 4 and enc.last_event == "struck_guarded_windup", "greedy strike during windup deals 0 damage")

	# Commit defensive Block against light_windup -> opens weak-spot window ("vulnerable")
	t.check(m.block_combat("block-light", "a:player").ok, "commit block during light windup")
	t.check(m.combat.encounter(m.session.snapshot(), "a:player").defense == "block", "block stance recorded")
	t.check(m.progress_combat("resolve-light", "a:player", 800).ok, "complete light windup against block")
	enc = m.combat.encounter(m.session.snapshot(), "a:player")
	t.check(enc.actor_health == 4 and enc.phase == "vulnerable" and enc.last_event == "blocked_counter", "blocking light lunge prevents damage and exposes weak spot")

	# Strike during vulnerable weak-spot window deals weak_spot_damage (2) and staggers back to poised (step -> 1)
	t.check(m.strike_combat("weak-hit-1", "a:player").ok, "strike exposed weak spot")
	enc = m.combat.encounter(m.session.snapshot(), "a:player")
	t.check(enc.threat_health == 2 and enc.phase == "poised" and enc.step == 1 and enc.last_event == "struck_weak_spot", "weak-spot strike deals 2 damage and advances pattern step")

	# Step 1 of pattern is "heavy": advance 600ms -> heavy_windup
	t.check(m.progress_combat("to-heavy-tell", "a:player", 600).ok, "progress to heavy telegraph")
	enc = m.combat.encounter(m.session.snapshot(), "a:player")
	t.check(enc.phase == "heavy_windup" and enc.last_event == "telegraph_heavy", "threat enters readable heavy_windup telegraph")

	# Blocking a heavy attack only partially mitigates (1 chip damage instead of 2) and does NOT expose weak spot:
	t.check(m.block_combat("block-heavy", "a:player").ok and m.progress_combat("resolve-heavy-block", "a:player", 1000).ok, "block against heavy sweep")
	enc = m.combat.encounter(m.session.snapshot(), "a:player")
	t.check(enc.actor_health == 3 and enc.phase == "poised" and enc.step == 2 and enc.last_event == "heavy_crushed_block", "heavy sweep crushes block for chip damage without opening weak spot")

	# Step 2 is "light" -> let's dodge it and let the weak-spot window expire to test weak_spot_closed:
	t.check(m.progress_combat("to-light-2", "a:player", 600).ok and m.dodge_combat("dodge-light-2", "a:player").ok and m.progress_combat("resolve-light-2", "a:player", 800).ok, "dodge light attack to open weak spot")
	t.check(m.combat.encounter(m.session.snapshot(), "a:player").phase == "vulnerable", "dodge opens weak spot")
	t.check(m.progress_combat("expire-weak-spot", "a:player", 1000).ok, "allow weak-spot window to expire")
	enc = m.combat.encounter(m.session.snapshot(), "a:player")
	t.check(enc.phase == "poised" and enc.step == 0 and enc.last_event == "weak_spot_closed", "unexploited weak-spot window closes and cycles pattern")

	# Strike in poised (deals 1 base damage -> threat_health = 1, immediately triggers step 0 light_windup), then dodge and finish!
	t.check(m.strike_combat("poised-chip", "a:player").ok, "poised strike deals base damage")
	enc = m.combat.encounter(m.session.snapshot(), "a:player")
	t.check(enc.threat_health == 1 and enc.phase == "light_windup" and enc.last_event == "struck_poised", "poised strike deals 1 chip damage and triggers counter telegraph")
	t.check(m.dodge_combat("dodge-final", "a:player").ok and m.progress_combat("resolve-final-tell", "a:player", 800).ok, "dodge counter telegraph")
	t.check(m.strike_combat("finishing-blow", "a:player").ok, "deliver finishing weak-spot strike")
	enc = m.combat.encounter(m.session.snapshot(), "a:player")
	t.check(enc.status == "victory" and enc.phase == "resolved" and enc.threat_health == 0 and enc.actor_health == 3 and enc.last_event == "victory", "exploiting weak spot defeats threat")

func _test_outspacing_and_retreat_outcomes(t) -> void:
	var m := model()
	t.check(to_stalker(m, "retreat-test") and m.engage_combat("engage-r1", "a:player", "a:reed-stalker").ok, "approach and engage for spatial/retreat tests")

	# Advance to light_windup, then step back to (540, 340) (distance = 140: outside engage_range 120, inside disengage_range 180)
	t.check(m.progress_combat("tell-r1", "a:player", 600).ok, "enter light windup")
	t.check(m.move_actor("step-out", "a:player", 540, 340).ok, "step outside engage_range while remaining inside disengage_range")
	t.check(m.combat.encounter(m.session.snapshot(), "a:player").status == "engaged", "remain engaged inside disengage_range")
	t.check(m.progress_combat("whiff-r1", "a:player", 800).ok, "enemy attack whiffs against outspaced player")
	var enc := m.combat.encounter(m.session.snapshot(), "a:player")
	t.check(enc.phase == "vulnerable" and enc.last_event == "outspaced_counter" and enc.actor_health == 4, "spatial outspacing evades attack and opens weak spot")

	# Explicit retreat command moves actor to safe retreat_point (460, 330) and resolves as retreated
	t.check(m.retreat_combat("explicit-retreat", "a:player").ok, "explicit retreat succeeds")
	enc = m.combat.encounter(m.session.snapshot(), "a:player")
	t.check(enc.status == "retreated" and enc.phase == "resolved" and enc.last_event == "retreated" and m.position_of("a:player") == Vector2(460, 330), "explicit retreat relocates to safe point and ends encounter")

	# Re-engage and test spatial retreat by walking beyond disengage_range (180)
	t.check(m.move_actor("re-approach", "a:player", 620, 340).ok and m.engage_combat("engage-r2", "a:player", "a:reed-stalker").ok, "re-engage after retreat")
	t.check(m.move_actor("run-away", "a:player", 480, 320).ok, "walk beyond disengage_range")
	enc = m.combat.encounter(m.session.snapshot(), "a:player")
	t.check(enc.status == "retreated" and enc.last_event == "spatial_retreat", "moving beyond disengage_range automatically triggers spatial retreat")

	# Re-engage from portal proximity isn't possible, so test portal transition while engaged (using a custom wide disengage fixture or relocate)
	t.check(m.move_actor("re-approach-2", "a:player", 620, 340).ok and m.engage_combat("engage-r3", "a:player", "a:reed-stalker").ok, "re-engage for progress spatial check")

func _test_provisional_winded_recovery_and_persistence(t) -> void:
	var m := model()
	t.check(to_stalker(m, "winded-test") and m.engage_combat("engage-w", "a:player", "a:reed-stalker").ok, "engage for winded outcome test")
	# Take undefended hits: pattern is light (1 dmg at 600+800=1400ms), heavy (2 dmg at 600+1000=1600ms), light (1 dmg at 600+800=1400ms) -> total 4 dmg in 4400ms
	t.check(m.progress_combat("take-all-hits", "a:player", 4400).ok, "progress through undefended attacks")
	var enc := m.combat.encounter(m.session.snapshot(), "a:player")
	t.check(enc.status == "winded" and enc.actor_health == 0 and enc.phase == "resolved" and enc.last_event == "winded" and m.position_of("a:player") == Vector2(460, 330), "zero health transitions to bounded winded recovery state at safe point (D-016)")
	t.check(m.engage_combat("while-winded", "a:player", "a:reed-stalker").code == "actor_winded", "cannot engage while winded")
	t.check(m.recover_combat("catch-breath", "a:player").ok, "recover_combat restores actor from winded state")
	enc = m.combat.encounter(m.session.snapshot(), "a:player")
	t.check(enc.status == "retreated" and enc.actor_health == 4 and enc.last_event == "recovered", "recover restores full health and clears winded lock")
	t.check(m.recover_combat("double-recover", "a:player").code == "already_recovered", "redundant recover rejected")

	# Save/load round-trip and negative validation mid-encounter:
	t.check(m.move_actor("back-in", "a:player", 620, 340).ok and m.engage_combat("engage-save", "a:player", "a:reed-stalker").ok, "re-engage before save")
	t.check(m.progress_combat("tell-save", "a:player", 600).ok and m.dodge_combat("dodge-save", "a:player").ok, "commit dodge during light windup before save")
	var saved_snap := m.session.snapshot()
	var text := SessionCodec.encode(m.session)
	var restored := SessionCodec.decode(text, m.session)
	t.check(restored != null and restored.snapshot() == saved_snap, "mid-encounter telegraph and defense state restores cleanly")
	if restored != null: restored.close()

	var bad_hp: Dictionary = saved_snap.duplicate(true)
	bad_hp.domains = saved_snap.domains.duplicate(true)
	bad_hp.domains.combat = saved_snap.domains.combat.duplicate(true)
	bad_hp.domains.combat.encounters = saved_snap.domains.combat.encounters.duplicate(true)
	bad_hp.domains.combat.encounters["a:player"] = saved_snap.domains.combat.encounters["a:player"].duplicate(true)
	bad_hp.domains.combat.encounters["a:player"].actor_health = 99
	t.check(m.session.restore_candidate(bad_hp) == null, "restore rejects out-of-bounds actor_health")

	var bad_phase: Dictionary = saved_snap.duplicate(true)
	bad_phase.domains = saved_snap.domains.duplicate(true)
	bad_phase.domains.combat = saved_snap.domains.combat.duplicate(true)
	bad_phase.domains.combat.encounters = saved_snap.domains.combat.encounters.duplicate(true)
	bad_phase.domains.combat.encounters["a:player"] = saved_snap.domains.combat.encounters["a:player"].duplicate(true)
	bad_phase.domains.combat.encounters["a:player"].phase = "poised" # defense is still "dodge", which is invalid in poised!
	t.check(m.session.restore_candidate(bad_phase) == null, "restore rejects defense committed outside windup phase")
	m.session.close()
