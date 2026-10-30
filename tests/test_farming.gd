extends RefCounted

func model() -> GameplayModel:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/linked_world.json"))
	return GameplayModel.create(data, "world.farming")

func river_bed(m: GameplayModel, prefix: String = "river") -> bool:
	return m.move_actor(prefix + "-path", "a:player", 700, 330).ok and m.enter(prefix + "-enter", "a:player", "a:river-path").ok and m.move_actor(prefix + "-bed", "a:player", 480, 320).ok

func leave_river(m: GameplayModel, prefix: String = "return") -> bool:
	return m.move_actor(prefix + "-door", "a:player", 100, 300).ok and m.enter(prefix + "-courtyard", "a:player", "a:river-return").ok

func run(t) -> void:
	var m := model()
	t.check(m != null and m.farming != null, "farming composes with linked world")
	if m == null: return
	t.check(m.farming.skill(m.session.snapshot(), "a:player") == 0, "cultivation skill starts at zero")
	t.check(m.act("seeds", "a:player", "a:supplies", "item.grain", 4, "take").ok and m.act("lotus", "a:player", "a:supplies", "item.lotus_seed", 1, "take").ok, "gather real grain and lotus seeds")
	var before := m.session.snapshot()
	t.check(not m.plant_crop("remote-plant", "a:player", "a:garden-plot", "crop.grain").ok and before == m.session.snapshot(), "remote planting rejected atomically")
	t.check(m.move_actor("merchant-plot", "a:player", 500, 60).ok, "walk to private merchant plot")
	before = m.session.snapshot()
	t.check(m.plant_crop("private-plant", "a:player", "a:merchant-plot", "crop.grain").code == "access_denied" and before == m.session.snapshot(), "private plot rejects unpermitted cultivation without spending seed")
	t.check(m.move_actor("garden", "a:player", 240, 60).ok, "walk to owned courtyard loam plot")
	before = m.session.snapshot()
	t.check(m.plant_crop("wrong-env", "a:player", "a:garden-plot", "crop.lotus").code == "incompatible_environment" and before == m.session.snapshot(), "river lotus rejected in courtyard without losing seed")
	t.check(m.move_actor("sandy", "a:player", 360, 60).ok, "walk to sandy courtyard plot")
	before = m.session.snapshot()
	t.check(m.plant_crop("unskilled-soil", "a:player", "a:sandy-plot", "crop.grain").code == "skill_required_for_soil" and before == m.session.snapshot(), "suboptimal sandy soil requires cultivation skill")
	t.check(m.move_actor("back-garden", "a:player", 240, 60).ok and m.plant_crop("plant-grain", "a:player", "a:garden-plot", "crop.grain").ok, "plant grain in compatible loam plot")
	t.check(m.inventory.contents(m.session.snapshot(), "a:player").get("item.grain", 0) == 3, "planting consumes exactly one seed")
	t.check(m.plant_crop("double-plant", "a:player", "a:garden-plot", "crop.grain").code == "plot_occupied", "occupied plot rejects second planting")
	var initial_proj := m.farming.projection(m.session.snapshot(), "a:garden-plot")
	t.check(initial_proj.waterings_needed == 2 and initial_proj.growth_minutes == 360 and initial_proj.stage == "needs_water", "base crop requires two waterings and six hours")
	t.check(m.water_crop("water-1", "a:player", "a:garden-plot").ok, "first watering care event recorded")
	before = m.session.snapshot()
	t.check(m.water_crop("spam-water", "a:player", "a:garden-plot").code == "already_watered_recently" and before == m.session.snapshot(), "immediate second watering rejected to prevent click spam")
	t.check(m.wait_minutes("wait-1h", "a:player", 60).ok and m.water_crop("early-water", "a:player", "a:garden-plot").code == "already_watered_recently", "watering interval enforced across world time")
	t.check(m.harvest_crop("early-harvest", "a:player", "a:garden-plot").code == "crop_not_ripe", "unripe crop cannot be harvested")
	t.check(m.wait_minutes("wait-5h", "a:player", 300).ok, "advance past base growth duration with only one watering")
	var parched := m.farming.projection(m.session.snapshot(), "a:garden-plot")
	t.check(parched.stage == "parched" and not parched.ripe and m.harvest_crop("parched-harvest", "a:player", "a:garden-plot").code == "watering_required", "elapsed time alone cannot ripen under-watered crop")
	t.check(m.water_crop("water-2", "a:player", "a:garden-plot").ok, "second watering completes care requirement")
	var ripe_proj := m.farming.projection(m.session.snapshot(), "a:garden-plot")
	t.check(ripe_proj.ripe and ripe_proj.stage == "ripe", "crop ripens once both growth time and waterings are satisfied")
	var saved := m.session.snapshot()
	var decoded := SessionCodec.decode(SessionCodec.encode(m.session), m.session)
	t.check(decoded != null and decoded.snapshot() == saved, "planted plot state and watering anchors roundtrip")
	if decoded != null: decoded.close()
	for invalid_mutation in [
		func(s): s.domains.farming.plots["a:garden-plot"].crop_id = "crop.lotus",
		func(s): s.domains.farming.plots["a:merchant-plot"] = s.domains.farming.plots["a:garden-plot"].duplicate(true),
		func(s): s.domains.farming.plots["a:garden-plot"].waterings = [480, 500],
		func(s): s.domains.farming.plots["a:garden-plot"].planted_at = s.minute + 10,
		func(s): s.domains.farming.skills["a:player"] = 99,
	]:
		var bad := saved.duplicate(true)
		invalid_mutation.call(bad)
		t.check(m.session.restore_candidate(bad) == null, "corrupt farming save rejected")
	t.check(m.harvest_crop("harvest-grain", "a:player", "a:garden-plot").ok, "harvest ripe grain")
	t.check(m.inventory.contents(m.session.snapshot(), "a:player").get("item.grain", 0) == 6 and m.farming.projection(m.session.snapshot(), "a:garden-plot").is_empty(), "harvest transfers yield once and clears plot")
	t.check(m.farming.skill(m.session.snapshot(), "a:player") == 1, "completed harvest increases bounded cultivation skill")
	t.check(m.harvest_crop("repeat-harvest", "a:player", "a:garden-plot").code == "nothing_to_harvest", "cannot harvest cleared plot twice")
	# Bounded skill modifiers ease soft thresholds without overriding hard environmental impossibilities.
	var skilled_rules := m.farming.effective_rules("crop.grain", 1)
	t.check(skilled_rules.required_waterings == 1 and skilled_rules.growth_minutes == 300 and "sandy" in skilled_rules.soils, "skill 1 eases watering, growth time and tolerated sandy soil")
	var max_rules := m.farming.effective_rules("crop.grain", 99)
	t.check(max_rules.required_waterings == 1 and max_rules.growth_minutes == 240, "high skill respects minimum watering and growth floors")
	t.check(m.farming.compatibility_error("a:garden-plot", "crop.lotus", 99) == "incompatible_environment", "maximum skill never overrides incompatible environment")
	t.check(m.move_actor("sandy-skilled", "a:player", 360, 60).ok and m.plant_crop("sandy-plant", "a:player", "a:sandy-plot", "crop.grain").ok, "skilled player can cultivate sandy courtyard bed")
	t.check(m.water_crop("sandy-water", "a:player", "a:sandy-plot").ok and m.water_crop("sandy-extra", "a:player", "a:sandy-plot").code == "watering_complete", "skilled grain needs only one watering")
	t.check(m.clear_plot("uproot", "a:player", "a:sandy-plot").ok and m.farming.projection(m.session.snapshot(), "a:sandy-plot").is_empty() and m.inventory.contents(m.session.snapshot(), "a:player").get("item.grain", 0) == 5, "clearing plot uproots crop without refunding seed")
	# Selective offscreen simulation: plant at riverbank, leave region for five days, reconcile lazily on return.
	t.check(river_bed(m) and m.inventory.contents(m.session.snapshot(), "a:player").get("item.lotus_seed", 0) == 1, "seed persists across region travel")
	t.check(m.plant_crop("plant-lotus", "a:player", "a:river-bed", "crop.lotus").ok and m.water_crop("water-lotus", "a:player", "a:river-bed").ok, "plant and water river lotus in riverbank silt")
	t.check(leave_river(m), "leave riverbank region while lotus grows")
	t.check(m.wait_minutes("five-days-offscreen", "a:player", 7200).ok, "advance five full world days while riverbank is unloaded")
	t.check(river_bed(m, "after-5d"), "return to riverbank after five days")
	var lotus_proj := m.farming.projection(m.session.snapshot(), "a:river-bed")
	t.check(lotus_proj.ripe and lotus_proj.elapsed_minutes == 7200, "offscreen crop lazily reconciles five-day maturity without frame replay")
	t.check(leave_river(m, "reenter-out") and river_bed(m, "reenter-in") and m.farming.projection(m.session.snapshot(), "a:river-bed") == lotus_proj, "re-entering region twice never double-applies reconciliation")
	t.check(m.harvest_crop("harvest-lotus", "a:player", "a:river-bed").ok and m.inventory.contents(m.session.snapshot(), "a:player").get("item.river_lotus", 0) == 2, "harvest two river lotus into inventory")
	t.check(leave_river(m, "home") and m.move_actor("bench", "a:player", 220, 320).ok, "carry harvested lotus to courtyard workbench")
	t.check(m.start_craft("lotus-craft", "a:player", "recipe.z_lotus_provisions", "a:workbench").ok and m.progress_craft("lotus-done", "a:player", 3).ok, "harvested lotus participates in active preparation")
	t.check(m.inventory.contents(m.session.snapshot(), "a:player").get("item.provisions", 0) == 2, "lotus preparation produces packed provisions")
	t.check(m.move_actor("market", "a:player", 620, 160).ok and m.act("sell-lotus", "a:player", "a:merchant", "item.river_lotus", 1, "sell", 4).ok, "harvested produce sells through finite merchant trade")
	m.session.close()
	# Full-bag harvest holds produce on the plot until bag space is freed.
	m = model()
	t.check(m.act("lotus-1", "a:player", "a:supplies", "item.lotus_seed", 1, "take").ok and m.act("dates-fill", "a:player", "a:supplies", "item.dates", 1, "take").ok and m.act("vessel-fill", "a:player", "a:supplies", "item.vessel", 1, "take").ok, "take lotus seed and two other items")
	t.check(river_bed(m, "full-river") and m.plant_crop("full-plant", "a:player", "a:river-bed", "crop.lotus").ok and m.water_crop("full-water", "a:player", "a:river-bed").ok, "plant lotus leaving two slots used")
	t.check(leave_river(m, "full-out") and m.move_actor("supplies-again", "a:player", 160, 160).ok and m.act("grain-fill", "a:player", "a:supplies", "item.grain", 1, "take").ok, "fill third bag slot with grain")
	t.check(m.wait_minutes("full-grow", "a:player", 720).ok and river_bed(m, "full-back"), "wait for lotus maturity and return with full bag")
	t.check(m.harvest_crop("full-harvest", "a:player", "a:river-bed").ok and m.farming.projection(m.session.snapshot(), "a:river-bed").status == "ready", "full-bag harvest holds produce ready on plot")
	var premature := m.session.snapshot()
	premature.domains.farming.plots["a:river-bed"].waterings = []
	t.check(m.session.restore_candidate(premature) == null, "save cannot claim ready harvest without completed waterings")
	t.check(m.move_actor("away-bed", "a:player", 100, 300).ok and not m.harvest_crop("remote-collect", "a:player", "a:river-bed").ok, "held harvest cannot be collected remotely")
	t.check(leave_river(m, "store-out") and m.move_actor("chest", "a:player", 360, 160).ok and m.act("store-vessel", "a:player", "a:chest", "item.vessel", 1, "store").ok, "free bag slot using owned chest")
	t.check(river_bed(m, "collect-in") and m.harvest_crop("collect-held", "a:player", "a:river-bed").ok and m.inventory.contents(m.session.snapshot(), "a:player").get("item.river_lotus", 0) == 2 and m.farming.projection(m.session.snapshot(), "a:river-bed").is_empty(), "return and collect held harvest once")
	m.session.close()
	var bad_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/linked_world.json"))
	bad_config.farming.crops["crop.grain"].max_watering_reduction = 2
	t.check(GameplayModel.create(bad_config, "world.bad-farming") == null, "crop config cannot allow skill to reduce required waterings to zero")
