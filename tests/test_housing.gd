extends RefCounted

func data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/linked_world.json"))

func run(t) -> void:
	var m := GameplayModel.create(data(), "world.housing-test")
	t.check(m != null and m.housing != null, "housing composes with existing livelihood domains")
	if m == null: return
	var before := m.session.snapshot()
	t.check(m.acquire_housing("remote-booking", "a:player", "property.inn").code == "out_of_reach" and m.session.snapshot() == before, "room access cannot be bought remotely")
	t.check(m.move_actor("inn-door", "a:player", 40, 60).ok, "approach optional inn")
	before = m.session.snapshot()
	t.check(m.enter("locked", "a:player", "a:inn-door").code == "housing_access_denied" and m.session.snapshot() == before, "unassigned lodging denies door entry atomically")
	t.check(m.move_actor("provider", "a:player", 620, 160).ok, "approach housing provider")
	before = m.session.snapshot()
	var rolled_back := m.session.transact("housing-validation-rollback", func(tx: WorldTransaction) -> String:
		var error := m.housing.acquire(tx, "a:player", "property.inn")
		if error != "": return error
		var state := tx.read_domain("housing")
		state.placements["a:housing-chest"].cell_id = "cell.missing"
		tx.write_domain("housing", state)
		return "")
	t.check(not rolled_back.ok and m.session.snapshot() == before, "failed whole-candidate validation rolls back both paid access and furniture mutation")
	var coins := m.wallet("a:player")
	t.check(m.acquire_housing("access", "a:player", "property.inn").ok and m.wallet("a:player") == coins - 3, "optional lodging access transfers finite payment once")
	before = m.session.snapshot()
	t.check(m.acquire_housing("access", "a:player", "property.inn").ok and m.session.snapshot() == before, "housing intent replay cannot charge twice")
	t.check(m.acquire_housing("already", "a:player", "property.inn").code == "property_already_assigned" and m.session.snapshot() == before, "new intent cannot repurchase assigned room")
	coins = m.wallet("a:player")
	t.check(m.acquire_housing("poor", "a:player", "property.home").code == "insufficient_funds" and m.wallet("a:player") == coins and not m.housing.can_access(m.session.snapshot(), "a:player", "property.home"), "unaffordable property preserves money and access")
	m.move_actor("gather", "a:player", 160, 160)
	t.check(m.act("dates", "a:player", "a:supplies", "item.dates", 2, "take").ok, "furniture storage uses ordinary inventory goods")
	m.move_actor("stable-door", "a:player", 100, 330)
	t.check(m.enter("stable", "a:player", "a:workshop-door").ok, "existing stable accommodation is available")
	m.move_actor("chest", "a:player", 208, 100)
	t.check(m.act("store", "a:player", "a:housing-chest", "item.dates", 2, "store").ok, "placeable chest stores through authoritative inventory interaction")
	before = m.session.snapshot()
	t.check(not m.move_actor("through-chest", "a:player", 208, 60).ok and m.session.snapshot() == before, "placed furniture blocks authoritative actor movement")
	t.check(m.place_furnishing("overlap", "a:player", "a:housing-chest", "property.stable", "cell.1").code == "placement_occupied" and m.session.snapshot() == before, "overlapping furniture rejected without losing chest goods")
	t.check(m.place_furnishing("move", "a:player", "a:housing-chest", "property.stable", "cell.3").ok, "full chest moves to a constrained available space")
	t.check(m.position_of("a:housing-chest") == Vector2(608, 60) and m.inventory.contents(m.session.snapshot(), "a:housing-chest").get("item.dates") == 2, "moving chest preserves container identity and contents")
	before = m.session.snapshot()
	t.check(not m.act("remote-take", "a:player", "a:housing-chest", "item.dates", 1, "take").ok and m.session.snapshot() == before, "old chest position no longer provides remote contents")
	m.move_actor("new-chest", "a:player", 608, 100)
	t.check(m.pack_furnishing("pack", "a:player", "a:housing-chest").ok, "full chest packs without converting goods or container")
	before = m.session.snapshot()
	t.check(m.act("packed-take", "a:player", "a:housing-chest", "item.dates", 1, "take").code == "housing_access_denied" and m.session.snapshot() == before, "packed storage cannot be accessed remotely or locally")
	m.move_actor("exit", "a:player", 100, 330)
	m.enter("leave", "a:player", "a:workshop-exit")
	m.move_actor("inn-door-again", "a:player", 40, 60)
	t.check(m.enter("enter-inn", "a:player", "a:inn-door").ok and m.place_furnishing("unpack", "a:player", "a:housing-chest", "property.inn", "cell.0").ok, "same furniture can move between authorized accommodations")
	m.move_actor("unpacked", "a:player", 208, 100)
	t.check(m.act("take-again", "a:player", "a:housing-chest", "item.dates", 1, "take").ok and m.inventory.contents(m.session.snapshot(), "a:housing-chest").get("item.dates") == 1, "relocated chest remains usable with exactly conserved goods")
	var encoded := SessionCodec.encode(m.session)
	var loaded := SessionCodec.decode(encoded, m.session)
	t.check(loaded != null and loaded.snapshot() == m.session.snapshot(), "housing grants and furniture identity roundtrip")
	if loaded != null: loaded.close()
	before = m.session.snapshot()
	t.check(not m.place_furnishing("unknown-cell", "a:player", "a:housing-chest", "property.inn", "cell.missing").ok and m.session.snapshot() == before, "arbitrary space cannot bypass constrained placement")
	var invalid := before.duplicate(true)
	invalid.domains.housing.placements["a:housing-chest"].cell_id = "cell.missing"
	t.check(m.housing.validate(invalid.domains.housing, invalid) != "", "restored undefined furniture cell rejected")
	invalid = before.duplicate(true)
	invalid.domains.housing.residents["property.inn"] = ""
	t.check(m.housing.validate(invalid.domains.housing, invalid) != "", "restored unauthorized room/furniture occupancy rejected")
	invalid = before.duplicate(true)
	invalid.entities["a:housing-chest"].region_id = "region.workshop"
	t.check(m.housing.validate(invalid.domains.housing, invalid) != "", "restored chest region mismatch rejected")
	var old_data := data()
	old_data.erase("housing")
	var old_game := GameplayModel.create(old_data, "world.housing-test")
	var old_bytes := SessionCodec.encode(old_game.session)
	var preserved_bytes := old_bytes
	t.check(SessionCodec.decode(old_bytes, m.session) == null and old_bytes == preserved_bytes, "pre-housing domain/content save rejects without mutating original bytes")
	old_game.session.close()
	m.session.close()
	var purchased_data := data()
	purchased_data.economy.wallets["a:player"] = 30
	var purchaser := GameplayModel.create(purchased_data, "world.property-purchase")
	purchaser.move_actor("provider", "a:player", 620, 160)
	t.check(purchaser.acquire_housing("purchase", "a:player", "property.home").ok and purchaser.wallet("a:player") == 18, "optional property grants access through the same finite transactional contract")
	purchaser.session.close()
	var broken := data()
	broken.housing.properties["property.stable"].cells["cell.0"].x = 100
	broken.housing.properties["property.stable"].cells["cell.0"].y = 300
	t.check(GameplayModel.create(broken, "world.blocked-entry") == null, "authored placement cannot obstruct portal entry/exit usable space")
	broken = data()
	broken.housing.properties["property.stable"].cells["cell.0"].x = 340
	broken.housing.properties["property.stable"].cells["cell.0"].y = 160
	t.check(GameplayModel.create(broken, "world.blocked-obstacle") == null, "authored placement overlapping solid geometry rejected")
	broken = data()
	broken.inventory.containers["a:housing-chest"].owner_id = "a:merchant"
	t.check(GameplayModel.create(broken, "world.storage-owner") == null, "furniture storage identity must match inventory legal access owner")

	var occlusion_data := data()
	occlusion_data.housing.properties["property.stable"].cells["cell.0"] = {"x": 180, "y": 40, "width": 24, "height": 24}
	occlusion_data.housing.properties["property.stable"].cells["cell.1"] = {"x": 230, "y": 40, "width": 24, "height": 24}
	occlusion_data.housing.furnishings["a:housing-chest"].cell_id = "cell.2"
	occlusion_data.housing.furnishings["a:cushion"].cell_id = "cell.0"
	var occluded := GameplayModel.create(occlusion_data, "world.furniture-occlusion")
	t.check(occluded != null, "separate nonoverlapping small furnishings compose for reach obstruction proof")
	if occluded != null:
		occluded.move_actor("door", "a:player", 100, 330)
		occluded.enter("stable", "a:player", "a:workshop-door")
		t.check(occluded.move_actor("beside-lamp", "a:player", 275, 52).ok, "actor approaches from beyond intervening furnishing")
		var unchanged := occluded.session.snapshot()
		t.check(occluded.pack_furnishing("blocked-pack", "a:player", "a:cushion").code == "interaction_obstructed" and occluded.session.snapshot() == unchanged, "other furniture still blocks reach while target's own footprint is excluded")
		occluded.session.close()
