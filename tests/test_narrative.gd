extends RefCounted

func _model() -> GameplayModel:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/linked_world.json"))
	return GameplayModel.create(data, "world.narrative")

func _discover(m: GameplayModel, prefix: String) -> bool:
	if not m.move_actor(prefix + "door", "a:player", 100, 300).ok: return false
	if not m.enter(prefix + "inside", "a:player", "a:workshop-door").ok: return false
	if not m.move_actor(prefix + "passage", "a:player", 650, 330).ok: return false
	if not m.enter(prefix + "alcove", "a:player", "a:side-passage").ok: return false
	if not m.move_actor(prefix + "basin", "a:player", 260, 220).ok: return false
	return m.inspect_object(prefix + "inspect", "a:player", "a:dry-basin").ok

func _return(m: GameplayModel, prefix: String) -> bool:
	return m.move_actor(prefix + "exit", "a:player", 100, 300).ok and m.enter(prefix + "workshop", "a:player", "a:alcove-exit").ok and m.move_actor(prefix + "door", "a:player", 100, 300).ok and m.enter(prefix + "courtyard", "a:player", "a:workshop-exit").ok and m.move_actor(prefix + "merchant", "a:player", 620, 160).ok

func run(t) -> void:
	var m := _model()
	t.check(m != null, "narrative world composes")
	if m == null: return
	var initial := m.session.snapshot()
	t.check(not m.talk("remote", "a:player", "a:merchant").ok and initial == m.session.snapshot(), "remote conversation cannot mutate")
	t.check(_discover(m, "first"), "secret discovered before rumor")
	t.check(m.session.snapshot().knowledge == {"claim.passage": "confirmed", "claim.dry_basin": "confirmed"}, "physical discoveries confirm only observed facts")
	t.check(_return(m, "return"), "return from secret to merchant")
	t.check(m.talk("greet", "a:player", "a:merchant").ok, "real Ink opens contextual conversation")
	var record := m.narrative.conversation(m.session.snapshot(), "a:player")
	t.check(record.frame.text.contains("fallen silent"), "Ink reacts to dry basin discovery")
	t.check(m.talk("rumor", "a:player", "a:merchant", 0, 1).ok, "discovery-first rumor discussion")
	t.check(m.session.snapshot().knowledge["claim.passage"] == "confirmed" and m.session.snapshot().knowledge["claim.water"] == "heard", "rumor cannot downgrade confirmed knowledge or become truth")
	t.check(m.narrative.conversation(m.session.snapshot(), "a:player").frame.text.contains("found the side passage"), "discovery-first branch is coherent")
	var saved := m.session.snapshot()
	t.check(not m.talk("bad-choice", "a:player", "a:merchant", 99, 2).ok and saved == m.session.snapshot(), "invalid choice rolls back")
	t.check(not m.talk("stale", "a:player", "a:merchant", 0, 1).ok and saved == m.session.snapshot(), "stale choice cannot apply")
	var restored := SessionCodec.decode(SessionCodec.encode(m.session), m.session)
	t.check(restored != null and restored.snapshot() == saved, "story and displayed choice roundtrip")
	if restored != null: restored.close()
	var corrupt := saved.duplicate(true)
	corrupt.domains.narrative.conversations["a:player"].frame.text = "invented"
	t.check(m.session.restore_candidate(corrupt) == null, "forged displayed frame rejected")
	corrupt = saved.duplicate(true)
	corrupt.domains.narrative.conversations["a:player"].turns[0].context["unknown"] = true
	t.check(m.session.restore_candidate(corrupt) == null, "unknown saved context rejected before Ink")
	m.session.close()
	m = _model()
	t.check(m.move_actor("shop", "a:player", 620, 160).ok and m.talk("hello", "a:player", "a:merchant").ok and m.talk("hear", "a:player", "a:merchant", 0, 1).ok, "rumor-first sequence")
	t.check(m.session.snapshot().knowledge == {"claim.passage": "heard", "claim.water": "heard"}, "hearsay remains uncertain")
	t.check(_discover(m, "later"), "hearing first leaves discovery physically accessible")
	t.check(m.session.definition().fact("fact.basin_dry"), "false water rumor never changes static world truth")
	t.check(_return(m, "later-return") and m.talk("job-greet", "a:player", "a:merchant").ok and m.talk("job-accept", "a:player", "a:merchant", 1, 1).ok, "Ink choice accepts existing funded job")
	t.check(m.work.job_for(m.session.snapshot(), "a:player", "work.provisions").status == "accepted", "dialogue uses work domain and holds reward")
	var accepted := m.session.snapshot()
	t.check(not m.talk("again", "a:player", "a:merchant", 1, 1).ok and m.session.snapshot() == accepted, "repeated dialogue cannot fund duplicate work")
	t.check(m.wait_minutes("night", "a:player", 720).ok and not m.talk("night-talk", "a:player", "a:merchant").ok, "schedule still controls conversation access")
	m.session.close()

	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/linked_world.json"))
	data.narrative.discoveries["a:dry-basin"].claim_id = "claim.missing"
	t.check(GameplayModel.create(data, "world.bad-claim") == null, "unknown semantic claim rejected")
	data = JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/linked_world.json"))
	data.narrative.conversations["a:merchant"].actions.erase("water_rumor")
	m = GameplayModel.create(data, "world.unknown-action")
	t.check(m.move_actor("shop", "a:player", 620, 160).ok and m.talk("hello", "a:player", "a:merchant").ok, "open restricted command story")
	var before := m.session.snapshot()
	t.check(not m.talk("unknown-action", "a:player", "a:merchant", 0, 1).ok and m.session.snapshot() == before, "unknown story command rolls back earlier knowledge and cursor")
	m.session.close()
	data.narrative.conversations["a:merchant"].queries["undefined_global"] = {"kind": "confirmed", "id": "claim.passage"}
	t.check(GameplayModel.create(data, "world.bad-global") == null, "unknown Ink query global rejected")
