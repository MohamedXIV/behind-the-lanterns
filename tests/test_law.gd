extends RefCounted
## Acceptance tests for Issue #7 (Law, Pursuit, Scripted Arrest & Jail Opportunities).

func model() -> GameplayModel:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/linked_world.json"))
	return GameplayModel.create(data, "world.law-test")

func run(t) -> void:
	_test_guard_non_combat_and_scripted_arrest(t)
	_test_witness_pursuit_evasion_and_cooldown(t)
	_test_persuasion_escalation_and_reoffense(t)
	_test_validation(t)

func _test_guard_non_combat_and_scripted_arrest(t) -> void:
	var m := model()
	t.check(m != null and m.law != null, "law domain composed from authored fixture")
	if m == null or m.law == null: return
	t.check(m.move_actor("near-merchant", "a:player", 620, 160).ok, "walk to merchant")
	t.check(m.confront_guard("not-guard", "a:player", "a:merchant").code == "non_hostile_target", "ordinary NPCs do not use guard arrest path")
	t.check(m.confront_guard("far-guard", "a:player", "a:gate-guard").code == "out_of_reach", "confronting guard requires reach")
	t.check(m.move_actor("near-guard", "a:player", 480, 340).ok, "walk to courtyard watchman")
	var wallet_before := m.wallet("a:player")
	t.check(m.confront_guard("strike-guard", "a:player", "a:gate-guard").ok, "striking guard triggers scripted arrest without combat")
	var rec := m.law.status_of(m.session.snapshot(), "a:player")
	t.check(rec.status == "detained" and rec.offense == "guard_assault" and rec.offense_count == 1, "guard assault records detained status and offense count")
	t.check(rec.fine == 6 and rec.until_minute == m.session.now() + 540, "guard assault applies scaled fine and sentence")
	t.check(m.actor_region("a:player") == "region.watchhouse" and m.position_of("a:player") == Vector2(220, 220), "scripted arrest relocates actor to traversable watchhouse")
	t.check(m.wallet("a:player") == wallet_before, "arrest does not grant or silently delete coins")
	t.check(m.move_actor("walk-door", "a:player", 100, 330).ok, "detained player can walk inside watchhouse")
	t.check(m.enter("locked-exit", "a:player", "a:watchhouse-exit").code == "detained_until_release", "watchhouse door is locked while sentence is active")
	# Social Ink conversation in jail without exclusive gating or reward farming.
	t.check(m.move_actor("walk-detainee", "a:player", 520, 220).ok, "walk to detained porter in watchhouse")
	t.check(m.talk("jail-open", "a:player", "a:detainee").ok and m.talk("jail-rumor", "a:player", "a:detainee", 0, 1).ok, "detainee shares Ink dialogue in watchhouse")
	t.check(m.session.snapshot().knowledge.get("claim.water") == "heard" and m.wallet("a:player") == wallet_before, "jail rumor uses shared world claim and grants no farmable reward")
	t.check(m.serve_sentence("serve", "a:player").ok, "serving sentence advances world time to release")
	t.check(m.law.status_of(m.session.snapshot(), "a:player").status == "clear" and m.actor_region("a:player") == "region.playground", "sentence completion releases player back to courtyard")
	m.session.close()

func _test_witness_pursuit_evasion_and_cooldown(t) -> void:
	var m := model()
	t.check(m.move_actor("near-private", "a:player", 360, 310).ok, "walk to private merchant chest")
	# Wait until 23:00 (minute 1380) when courtyard watchman is off duty.
	t.check(m.wait_minutes("to-night", "a:player", 900).ok, "wait until night")
	t.check(m.tamper_restricted("unwitnessed", "a:player", "a:private").code == "restricted_unwitnessed", "unwitnessed tampering stays locked without pursuit")
	t.check(m.law.status_of(m.session.snapshot(), "a:player").status == "clear", "unwitnessed attempt leaves standing clear")
	# Wait until morning duty hours (07:00 next day, +480 min).
	t.check(m.wait_minutes("to-morning", "a:player", 480).ok, "wait until watchman is on duty")
	t.check(m.tamper_restricted("witnessed", "a:player", "a:private").ok, "witnessed tampering triggers pursuit")
	var rec := m.law.status_of(m.session.snapshot(), "a:player")
	t.check(rec.status == "pursued" and rec.offense == "trespass_goods" and rec.fine == 4, "pursued status records offense and base fine")
	t.check(m.evade_pursuit("not-refuge", "a:player", "a:private").code == "not_refuge", "cannot hide at a non-refuge object")
	# Escape to the riverbank reed refuge and hide.
	t.check(m.move_actor("to-river-door", "a:player", 700, 330).ok and m.enter("enter-river", "a:player", "a:river-path").ok, "flee to riverbank")
	t.check(m.move_actor("to-reeds", "a:player", 220, 180).ok and m.evade_pursuit("hide-reeds", "a:player", "a:reed-bank").ok, "concealing river reeds clear active pursuit")
	t.check(m.law.status_of(m.session.snapshot(), "a:player").status == "clear", "standing is clear after successful evasion")
	# Trigger pursuit again and let wanted cooldown expire via world time.
	t.check(m.move_actor("back-door", "a:player", 100, 330).ok and m.enter("leave-river", "a:player", "a:river-return").ok, "return to courtyard")
	t.check(m.move_actor("near-planter", "a:player", 500, 60).ok and m.tamper_restricted("witnessed-planter", "a:player", "a:merchant-plot").ok, "witnessed planter trespass starts pursuit")
	t.check(m.wait_minutes("cooldown-wait", "a:player", 180).ok, "advance world time through cooldown window")
	t.check(m.law.status_of(m.session.snapshot(), "a:player").status == "clear", "scheduled cooldown event clears wanted status")
	m.session.close()

func _test_persuasion_escalation_and_reoffense(t) -> void:
	var m := model()
	t.check(m.move_actor("to-private", "a:player", 360, 310).ok and m.tamper_restricted("first-trespass", "a:player", "a:private").ok, "start pursuit")
	t.check(m.move_actor("to-guard", "a:player", 480, 340).ok, "approach watchman")
	t.check(m.persuade_guard("no-voucher", "a:player", "a:gate-guard").code == "voucher_required", "persuasion requires a completed local voucher commitment")
	# Complete the provisions job first, then verify voucher leniency on a first-time trespass.
	var m2 := model()
	t.check(m2.act("g", "a:player", "a:supplies", "item.grain", 2, "take").ok and m2.act("d", "a:player", "a:supplies", "item.dates", 1, "take").ok, "gather craft inputs")
	t.check(m2.move_actor("m", "a:player", 620, 160).ok and m2.accept_job("job", "a:player", "work.provisions").ok, "accept provisions job")
	t.check(m2.move_actor("b", "a:player", 220, 320).ok and m2.start_craft("c", "a:player", "recipe.provisions", "a:workbench").ok and m2.progress_craft("p", "a:player", 3).ok, "craft provisions")
	t.check(m2.wait_minutes("w", "a:player", 60).ok and m2.move_actor("r", "a:player", 600, 320).ok and m2.deliver_job("del", "a:player", "work.provisions").ok, "deliver provisions to earn local voucher")
	t.check(m2.move_actor("tp", "a:player", 360, 310).ok and m2.tamper_restricted("t1", "a:player", "a:private").ok, "first witnessed trespass after earning voucher")
	t.check(m2.move_actor("tg", "a:player", 480, 340).ok and m2.persuade_guard("vouched", "a:player", "a:gate-guard").ok, "completed work commitment vouches for first non-assault offense")
	t.check(m2.law.status_of(m2.session.snapshot(), "a:player").status == "clear" and m2.law.status_of(m2.session.snapshot(), "a:player").offense_count == 0, "vouched persuasion clears pursuit without fine or offense record")
	# Escalation on second witnessed offense while pursued, fine payment, and repeat-offense refusal.
	t.check(m2.move_actor("tp2", "a:player", 360, 310).ok and m2.tamper_restricted("t2", "a:player", "a:private").ok, "pursuit started")
	t.check(m2.tamper_restricted("t3-escalate", "a:player", "a:private").ok, "second witnessed offense while pursued escalates to arrest")
	var detained := m2.law.status_of(m2.session.snapshot(), "a:player")
	t.check(detained.status == "detained" and detained.offense_count == 1 and detained.fine == 4 and m2.actor_region("a:player") == "region.watchhouse", "escalated arrest detains player in watchhouse")
	var coins_before := m2.wallet("a:player")
	t.check(m2.move_actor("to-warden", "a:player", 360, 220).ok and m2.pay_fine("pay", "a:player", "a:watch-warden").ok, "pay fine to watchhouse warden")
	t.check(m2.wallet("a:player") == coins_before - 4 and m2.actor_region("a:player") == "region.playground" and m2.law.status_of(m2.session.snapshot(), "a:player").status == "clear", "paying fine transfers coins and releases player")
	# Re-offense after prior arrest scales fine and refuses persuasion even with voucher.
	t.check(m2.move_actor("tp3", "a:player", 360, 310).ok and m2.tamper_restricted("repeat", "a:player", "a:private").ok, "repeat trespass")
	var repeat_rec := m2.law.status_of(m2.session.snapshot(), "a:player")
	t.check(repeat_rec.status == "pursued" and repeat_rec.fine == 6, "repeat offense increases fine")
	t.check(m2.move_actor("tg2", "a:player", 480, 340).ok and m2.persuade_guard("refused", "a:player", "a:gate-guard").code == "persuasion_refused", "repeat offender cannot talk away pursuit")
	m.session.close()
	m2.session.close()

func _test_validation(t) -> void:
	var m := model()
	t.check(m.move_actor("tp", "a:player", 360, 310).ok and m.tamper_restricted("t", "a:player", "a:private").ok, "setup pursued state for validation")
	var valid := m.session.snapshot()
	var bad_status := valid.duplicate(true)
	bad_status.domains.law.records["a:player"].status = "outlaw"
	t.check(m.session.restore_candidate(bad_status) == null, "invalid law status rejected")
	var bad_event := valid.duplicate(true)
	bad_event.domains.law.records["a:player"].event_id = "missing.event"
	t.check(m.session.restore_candidate(bad_event) == null, "missing scheduled law event rejected")
	m.session.close()
