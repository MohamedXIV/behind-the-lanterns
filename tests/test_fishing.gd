extends RefCounted

func model() -> GameplayModel:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/linked_world.json"))
	return GameplayModel.create(data, "world.fishing")

func river(m: GameplayModel) -> bool:
	return m.move_actor("river-path", "a:player", 700, 330).ok and m.enter("river-enter", "a:player", "a:river-path").ok and m.move_actor("bank", "a:player", 220, 180).ok

func run(t) -> void:
	var m := model()
	t.check(m != null and m.fishing != null, "fishing composes with existing world")
	if m == null: return
	t.check(m.act("bait", "a:player", "a:supplies", "item.grain", 3, "take").ok and m.act("dates", "a:player", "a:supplies", "item.dates", 1, "take").ok, "gather real bait")
	var before := m.session.snapshot()
	t.check(not m.cast_line("remote", "a:player", "a:reed-bank", "item.grain").ok and before == m.session.snapshot(), "remote cast atomic rejection")
	t.check(river(m) and m.session.snapshot().knowledge.get("claim.riverbank") == "confirmed", "physical river exploration confirms existing geography")
	before = m.session.snapshot()
	t.check(not m.cast_line("wrong-bait", "a:player", "a:reed-bank", "item.dates").ok and before == m.session.snapshot(), "unsuitable bait neither spent nor rerolls seed")
	t.check(m.cast_line("cast", "a:player", "a:reed-bank", "item.grain").ok, "cast with permitted bait")
	var selected: String = m.fishing.attempt(m.session.snapshot(), "a:player").fish
	t.check(m.inventory.contents(m.session.snapshot(), "a:player")["item.grain"] == 2, "bait consumed exactly at cast")
	t.check(m.progress_fishing("partial", "a:player", 1000).ok, "active timing progress")
	var saved := m.session.snapshot()
	var loaded := SessionCodec.decode(SessionCodec.encode(m.session), m.session)
	t.check(loaded != null and loaded.snapshot() == saved, "saved opportunity and timing roundtrip")
	if loaded != null: loaded.close()
	t.check(m.wait_minutes("skip", "a:player", 1440).ok and m.fishing.attempt(m.session.snapshot(), "a:player").elapsed_ms == 1000, "world time does not play timing minigame")
	t.check(m.progress_fishing("bite", "a:player", 1000).ok and m.reel_line("reel", "a:player").ok, "reel inside timing window")
	t.check(m.inventory.contents(m.session.snapshot(), "a:player").get(selected, 0) == 1, "one selected local fish enters inventory")
	var caught := m.session.snapshot()
	t.check(not m.reel_line("repeat", "a:player").ok and caught == m.session.snapshot(), "cannot duplicate catch")
	var corrupt := saved.duplicate(true)
	corrupt.domains.fishing.attempts["a:player"].fish = "item.catfish"
	t.check(m.session.restore_candidate(corrupt) == null, "save cannot reroll geographic species")
	corrupt.domains.fishing.attempts["a:player"].fish = ""
	corrupt.domains.fishing.attempts["a:player"].bait = "item.vessel"
	t.check(m.session.restore_candidate(corrupt) == null, "save cannot forge empty unsuitable opportunity")
	t.check(m.cast_line("early", "a:player", "a:reed-bank", "item.grain").ok and m.reel_line("early-reel", "a:player").ok and m.fishing.attempt(m.session.snapshot(), "a:player").status == "missed", "early reel spends bait and misses")
	t.check(m.cast_line("late", "a:player", "a:reed-bank", "item.grain").ok and m.progress_fishing("late-progress", "a:player", 4000).ok and m.fishing.attempt(m.session.snapshot(), "a:player").status == "missed", "late reaction misses")
	t.check(m.move_actor("deep", "a:player", 600, 180).ok and m.cast_line("deep-cast", "a:player", "a:deep-pool", "item.dates").ok and m.fishing.attempt(m.session.snapshot(), "a:player").fish == "item.catfish", "deep habitat and bait yield distinct species")
	t.check(m.cancel_fishing("put-away", "a:player").ok and not m.inventory.contents(m.session.snapshot(), "a:player").has("item.dates"), "cancellation does not refund spent bait")
	t.check(m.move_actor("river-exit", "a:player", 100, 300).ok and m.enter("outside", "a:player", "a:river-return").ok and m.move_actor("bench", "a:player", 220, 320).ok, "carry catch home")
	var species: String = selected.trim_prefix("item.")
	t.check(m.start_craft("fish-cook", "a:player", "recipe.z_fish_" + species, "a:workbench").ok and m.progress_craft("fish-done", "a:player", 3).ok, "catch uses existing active preparation")
	t.check(m.move_actor("market", "a:player", 620, 160).ok and m.act("sell-meal", "a:player", "a:merchant", "item.fish_meal", 1, "sell", 3).ok, "prepared catch participates in finite commerce")
	m.session.close()
	m = model()
	t.check(m.act("grain", "a:player", "a:supplies", "item.grain", 2, "take").ok and m.act("dates", "a:player", "a:supplies", "item.dates", 1, "take").ok and m.act("vessel", "a:player", "a:supplies", "item.vessel", 1, "take").ok and river(m), "fill bag and reach bank")
	t.check(m.cast_line("full-cast", "a:player", "a:reed-bank", "item.grain").ok and m.progress_fishing("full-bite", "a:player", 2000).ok and m.reel_line("full-reel", "a:player").ok and m.fishing.attempt(m.session.snapshot(), "a:player").status == "ready", "successful full-bag catch stays collectable")
	t.check(m.move_actor("away", "a:player", 100, 300).ok and not m.reel_line("remote-collect", "a:player").ok, "catch cannot be collected remotely")
	t.check(m.enter("leave", "a:player", "a:river-return").ok and m.move_actor("chest", "a:player", 360, 160).ok and m.act("store-vessel", "a:player", "a:chest", "item.vessel", 1, "store").ok, "make space through storage")
	t.check(m.move_actor("back-path", "a:player", 700, 330).ok and m.enter("back", "a:player", "a:river-path").ok and m.move_actor("back-bank", "a:player", 220, 180).ok and m.reel_line("collect", "a:player").ok and m.fishing.attempt(m.session.snapshot(), "a:player").status == "caught", "return and collect held catch exactly once")
	m.session.close()
