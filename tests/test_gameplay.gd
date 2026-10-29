extends RefCounted

func run(t) -> void:
	if not ResourceLoader.exists("res://game/gameplay/gameplay_model.gd"):
		t.check(false, "collect/store/trade gameplay implementation required")
		return
	var model_script: Script = load("res://game/gameplay/gameplay_model.gd")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/first_gameplay.json"))
	_test_transfers(t, model_script, data)
	_test_commerce(t, model_script, data)
	_test_persistence(t, model_script, data)
	_test_content_and_boundaries(t, model_script, data)

func model(script: Script, data: Dictionary):
	return script.create(data, "world.gameplay-test")

func act(m, intent: String, verb: String, target: String, item: String = "item.dates", amount: Variant = 1, quote: Variant = 0):
	return m.act(intent, "a:player", target, item, amount, verb, quote)

func move_near(m, target: String) -> void:
	var point: Vector2 = m.position_of(target)
	m.move_actor("walk:%d" % m.session.snapshot().revision, "a:player", point.x, point.y)

func count(m, holder: String, item: String = "item.dates") -> int:
	return m.inventory.contents(m.session.snapshot(), holder).get(item, 0)

func total(m, item: String) -> int:
	var result: int = 0
	for contents in m.session.snapshot().domains.inventory.contents.values():
		result += contents.get(item, 0)
	return result

func _test_transfers(t, script: Script, data: Dictionary) -> void:
	var m = model(script, data)
	t.check(m != null, "valid gameplay content composes")
	if m == null: return
	var initial_total := total(m, "item.dates")
	t.check(act(m, "take", "take", "a:supplies", "item.dates", 6).ok, "player takes finite world goods")
	t.check(count(m, "a:player") == 6 and count(m, "a:supplies") == 6, "take transfers rather than clones goods")
	t.check(total(m, "item.dates") == initial_total, "quantity conservation")
	t.check(act(m, "grain", "take", "a:supplies", "item.grain", 5).ok, "different item shares limited bag")
	var before: Dictionary = m.session.snapshot()
	t.check(not act(m, "full", "take", "a:supplies", "item.vessel").ok, "stack-based capacity enforced")
	t.check(m.session.snapshot() == before, "failed capacity leaves source, destination and receipt unchanged")
	t.check(not act(m, "far", "store", "a:chest").ok, "remote storage access rejected")
	move_near(m, "a:chest")
	t.check(act(m, "store", "store", "a:chest", "item.dates", 6).ok, "player stores carried goods")
	t.check(count(m, "a:player") == 0 and count(m, "a:chest") == 6, "storage has sole custody")
	t.check(act(m, "retrieve", "take", "a:chest", "item.dates", 3).ok, "player retrieves partial quantity")
	t.check(count(m, "a:player") == 3 and count(m, "a:chest") == 3, "partial transfer is exact")
	move_near(m, "a:private")
	t.check(not act(m, "private", "take", "a:private").ok, "another owner's storage remains inaccessible")
	move_near(m, "a:merchant")
	t.check(not act(m, "free_shop", "take", "a:merchant").ok, "merchant stock cannot be taken as a free pickup")
	for invalid in [-1, 0, 0.5, true, "2", INF]:
		t.check(not act(m, "invalid:%d" % t._checks, "sell", "a:merchant", "item.dates", invalid, 2).ok, "invalid quantities rejected")
	t.check(not m.move_actor("bad_walk", "a:player", NAN, 10).ok, "nonfinite position rejected")
	t.check(not m.move_actor("out", "a:player", -1, 10).ok, "out-of-bounds position rejected")
	t.check(not m.act("unknown_actor", "unknown", "a:merchant", "item.dates", 1, "buy", 3).ok, "unknown actor rejected")
	t.check(total(m, "item.dates") == initial_total, "all interactions conserve world quantity")

func _test_commerce(t, script: Script, data: Dictionary) -> void:
	var m = model(script, data)
	t.check(act(m, "collect", "take", "a:supplies", "item.dates", 5).ok, "collect goods to sell")
	move_near(m, "a:merchant")
	var initial_money: int = m.wallet("a:player") + m.wallet("a:merchant")
	t.check(act(m, "sale", "sell", "a:merchant", "item.dates", 3, 2).ok, "sell transfers goods and pays player")
	t.check(m.wallet("a:player") == 16 and count(m, "a:player") == 2, "sale balance and inventory")
	var before: Dictionary = m.session.snapshot()
	t.check(act(m, "sale", "sell", "a:merchant", "item.dates", 3, 2).ok, "same sale intent can be retried")
	t.check(m.session.snapshot() == before, "duplicate sale cannot duplicate payment")
	t.check(act(m, "buy", "buy", "a:merchant", "item.grain", 2, 2).ok, "buy uses finite merchant stock")
	t.check(m.wallet("a:player") == 12 and count(m, "a:player", "item.grain") == 2, "purchase balance and goods")
	t.check(m.wallet("a:player") + m.wallet("a:merchant") == initial_money, "trade conserves currency")
	before = m.session.snapshot()
	t.check(not act(m, "quote", "buy", "a:merchant", "item.dates", 1, 1).ok, "stale or forged quote rejected")
	t.check(not act(m, "too_much", "buy", "a:merchant", "item.vessel", 2, 8).ok, "cannot buy beyond funds")
	t.check(not act(m, "no_goods", "sell", "a:merchant", "item.dates", 9, 2).ok, "cannot sell goods player does not hold")
	t.check(m.session.snapshot() == before, "failed trades change neither wallet nor goods")
	var poor := data.duplicate(true)
	poor.economy.wallets["a:merchant"] = 0
	var poor_model = model(script, poor)
	act(poor_model, "get", "take", "a:supplies")
	move_near(poor_model, "a:merchant")
	before = poor_model.session.snapshot()
	t.check(not act(poor_model, "poor", "sell", "a:merchant", "item.dates", 1, 2).ok, "merchant cannot pay money it does not have")
	t.check(poor_model.session.snapshot() == before, "merchant funds failure keeps player goods")
	var small := data.duplicate(true)
	small.inventory.containers["a:player"].slots = 1
	var small_model = model(script, small)
	act(small_model, "fill", "take", "a:supplies", "item.dates", 5)
	move_near(small_model, "a:merchant")
	before = small_model.session.snapshot()
	t.check(not act(small_model, "full_buy", "buy", "a:merchant", "item.grain", 1, 2).ok, "paid purchase checks bag capacity")
	t.check(small_model.session.snapshot() == before, "full bag cannot lose payment or merchant stock")

func _test_persistence(t, script: Script, data: Dictionary) -> void:
	var m = model(script, data)
	act(m, "collect", "take", "a:supplies", "item.dates", 4)
	move_near(m, "a:chest")
	act(m, "store", "store", "a:chest", "item.dates", 2)
	var saved := SessionCodec.encode(m.session)
	var restored := SessionCodec.decode(saved, m.session)
	t.check(restored != null and restored.snapshot() == m.session.snapshot(), "holdings and actor position roundtrip")
	if restored == null: return
	t.check(m.adopt(restored), "model adopts validated replacement")
	var before: Dictionary = m.session.snapshot()
	t.check(act(m, "store", "store", "a:chest", "item.dates", 2).ok and m.session.snapshot() == before, "loaded intent cannot store a second time")
	var changed := data.duplicate(true)
	changed.economy.shops["a:merchant"].prices["item.dates"].buy_price = 4
	var other = model(script, changed)
	t.check(SessionCodec.decode(saved, other.session) == null, "save binds gameplay definitions as well as entity IDs")
	for alter in [
		func(s): s.domains.inventory.contents["a:player"]["unknown"] = 1,
		func(s): s.domains.inventory.contents["a:player"]["item.dates"] = 0,
		func(s): s.domains.inventory.contents["a:player"]["item.dates"] = 1000,
		func(s): s.domains.commerce.wallets["a:player"] = -1,
		func(s): s.domains.interactions.positions["a:player"].x = -1,
	]:
		var bad: Dictionary = before.duplicate(true)
		alter.call(bad)
		t.check(m.session.restore_candidate(bad) == null, "invalid gameplay state cannot restore")
	var alternate := data.duplicate(true)
	alternate.inventory.items["item.dates"].stack_limit = 7
	alternate.inventory.containers["a:supplies"].items["item.dates"] = 14
	var second = model(script, alternate)
	t.check(second != null and act(second, "second", "take", "a:supplies", "item.dates", 7).ok, "alternate content works without rule changes")

func _test_content_and_boundaries(t, script: Script, data: Dictionary) -> void:
	var m = model(script, data)
	t.check(m.move_actor("fractional", "a:player", 123.25, 160.5).ok, "fractional world position accepted")
	t.check(SessionCodec.decode(SessionCodec.encode(m.session), m.session).snapshot() == m.session.snapshot(), "fractional positions retain full precision on load")
	move_near(m, "a:merchant")
	t.check(m.session.transact("remote", func(tx): return tx.move_entity("a:merchant", "region.remote")).ok, "merchant can belong to another unloaded region")
	var before: Dictionary = m.session.snapshot()
	t.check(not act(m, "other_region", "buy", "a:merchant", "item.dates", 1, 3).ok and m.session.snapshot() == before, "same coordinates in another region do not grant access")
	var rich := data.duplicate(true)
	rich.economy.wallets["a:player"] = 200
	var rich_model = model(script, rich)
	move_near(rich_model, "a:merchant")
	before = rich_model.session.snapshot()
	t.check(not act(rich_model, "empty_stock", "buy", "a:merchant", "item.dates", 7, 3).ok, "buy cannot exceed finite merchant stock despite enough money")
	t.check(rich_model.session.snapshot() == before, "out-of-stock purchase preserves money")
	t.check(not act(rich_model, "overflow", "buy", "a:merchant", "item.dates", WorldData.MAX_COUNTER, 3).ok, "price multiplication is bounded")
	var full_shop := data.duplicate(true)
	full_shop.inventory.containers["a:merchant"].slots = 1
	full_shop.inventory.containers["a:merchant"].items = {"item.dates": 5}
	var full_model = model(script, full_shop)
	act(full_model, "grain", "take", "a:supplies", "item.grain")
	move_near(full_model, "a:merchant")
	before = full_model.session.snapshot()
	t.check(not act(full_model, "full_sale", "sell", "a:merchant", "item.grain", 1, 1).ok and full_model.session.snapshot() == before, "merchant capacity failure preserves goods and payment")
	for mutate in [
		func(d): d.inventory.items["item.dates"].stack_limit = 0,
		func(d): d.inventory.containers["a:player"].owner_id = "missing",
		func(d): d.inventory.containers["a:supplies"].items["unknown"] = 1,
		func(d): d.economy.shops["a:merchant"].prices["item.dates"].sell_price = 50,
		func(d): d.interactions.actors.append("a:player"),
		func(d): d.interactions.positions["a:chest"] = {"x": -1, "y": 0},
	]:
		var bad := data.duplicate(true)
		mutate.call(bad)
		t.check(model(script, bad) == null, "malformed gameplay content rejected at composition")
	# Validation must not depend on the registration order of peer domains.
	var reversed := GameSession.create(m.session.definition(), [m.interactions, m.inventory, m.commerce], "world.reordered")
	t.check(reversed != null, "domain composition order is not a gameplay dependency")
	var corrupted := reversed.snapshot()
	corrupted.domains.commerce = {"missing_wallets": true}
	t.check(reversed.restore_candidate(corrupted) == null, "malformed peer state fails validation without script errors")
