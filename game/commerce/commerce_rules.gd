class_name CommerceRules
extends SessionDomain
## Finite wallets and simple merchant prices. No dynamic market simulation.

const DOMAIN: String = "commerce"
var _wallets: Dictionary
var _shops: Dictionary
var _inventory: InventoryRules

static func create(config: Dictionary, inventory: InventoryRules) -> CommerceRules:
	if inventory == null or not WorldData.valid(config) or not WorldData.keys(config, ["wallets", "shops"]): return null
	if not config.wallets is Dictionary or not config.shops is Dictionary: return null
	for id in config.wallets:
		if not WorldData.id(id) or not WorldData.integer(config.wallets[id]): return null
	for id in config.shops:
		var shop: Variant = config.shops[id]
		if not config.wallets.has(id) or not WorldData.keys(shop, ["prices"]) or not shop.prices is Dictionary: return null
		var container := inventory.container_definition(id)
		if container.is_empty() or container.access != "trade": return null
		for item_id in shop.prices:
			var price: Variant = shop.prices[item_id]
			if inventory.item_definition(item_id).is_empty() or not WorldData.keys(price, ["buy_price", "sell_price"]): return null
			if not WorldData.integer(price.buy_price) or not WorldData.integer(price.sell_price): return null
			if price.buy_price < price.sell_price or price.buy_price == 0: return null
	var rules := CommerceRules.new()
	rules._wallets = config.wallets.duplicate(true)
	rules._shops = config.shops.duplicate(true)
	rules._inventory = inventory
	return rules

func domain_id() -> String:
	return DOMAIN

func schema_version() -> int:
	return 2

func initial_state() -> Dictionary:
	return {"wallets": _wallets.duplicate(true), "holds": {}}

func validate(state: Dictionary, snapshot: Dictionary) -> String:
	if not WorldData.keys(state, ["wallets", "holds"]) or not state.wallets is Dictionary or not state.holds is Dictionary or state.wallets.size() != _wallets.size(): return "wallet_schema"
	for id in _wallets:
		if not snapshot.entities.has(id) or not state.wallets.has(id) or not WorldData.integer(state.wallets[id]): return "wallet_reference_or_balance"
	for id in state.holds:
		var hold: Variant = state.holds[id]
		if not WorldData.id(id) or not WorldData.keys(hold, ["payer", "payee", "amount", "owner_domain"]): return "payment_hold_schema"
		if not hold.payer is String or not hold.payee is String or not state.wallets.has(hold.payer) or not state.wallets.has(hold.payee): return "payment_hold_party"
		if hold.payer == hold.payee or not WorldData.integer(hold.amount, 1): return "payment_hold_amount"
		if not hold.owner_domain is String or not snapshot.domains.has(hold.owner_domain): return "payment_hold_owner"
	for id in state.wallets:
		if _owned_balance(state, id) > WorldData.MAX_COUNTER: return "balance_overflow"
	return ""

func has_wallet(entity_id: String) -> bool:
	return _wallets.has(entity_id)

func _owned_balance(state: Dictionary, entity_id: String) -> int:
	var total: int = state.wallets[entity_id]
	for hold in state.holds.values():
		if hold.payer == entity_id: total += hold.amount
	return total

func is_shop(entity_id: String) -> bool:
	return _shops.has(entity_id)

func quote(shop_id: String, item_id: String, buying: bool) -> int:
	if not _shops.has(shop_id) or not _shops[shop_id].prices.has(item_id): return 0
	# Price names describe the PLAYER's buy/sell direction.
	return _shops[shop_id].prices[item_id].buy_price if buying else _shops[shop_id].prices[item_id].sell_price

func exchange(tx: WorldTransaction, actor_id: String, shop_id: String, item_id: String, amount: Variant, unit_quote: Variant, buying: bool) -> String:
	if not _wallets.has(actor_id) or actor_id == shop_id or not _shops.has(shop_id): return "unknown_trade_party"
	if not WorldData.integer(amount, 1): return "invalid_quantity"
	var price := quote(shop_id, item_id, buying)
	if price == 0: return "item_not_traded"
	if not WorldData.integer(unit_quote, 1) or int(unit_quote) != price: return "quote_changed"
	var total: int = price * int(amount)
	if total > WorldData.MAX_COUNTER: return "price_overflow"
	var state := tx.read_domain(DOMAIN)
	var payer: String = actor_id if buying else shop_id
	var payee: String = shop_id if buying else actor_id
	if state.wallets[payer] < total: return "insufficient_funds"
	if _owned_balance(state, payee) > WorldData.MAX_COUNTER - total: return "balance_overflow"
	var error := _inventory.transfer(tx, shop_id if buying else actor_id, actor_id if buying else shop_id, item_id, amount)
	if not error.is_empty(): return error
	state.wallets[payer] -= total
	state.wallets[payee] += total
	return "" if tx.write_domain(DOMAIN, state) else "commerce_write_failed"

func hold_payment(tx: WorldTransaction, hold_id: String, payer: String, payee: String, amount: int, owner_domain: String) -> String:
	if not WorldData.id(hold_id) or not _wallets.has(payer) or not _wallets.has(payee) or payer == payee or not WorldData.integer(amount, 1): return "invalid_payment_hold"
	var state := tx.read_domain(DOMAIN)
	if state.holds.has(hold_id): return "duplicate_payment_hold"
	if state.wallets[payer] < amount: return "insufficient_funds"
	state.wallets[payer] -= amount
	state.holds[hold_id] = {"payer": payer, "payee": payee, "amount": amount, "owner_domain": owner_domain}
	return "" if tx.write_domain(DOMAIN, state) else "commerce_write_failed"

func resolve_payment(tx: WorldTransaction, hold_id: String, pay_recipient: bool) -> String:
	var state := tx.read_domain(DOMAIN)
	if not state.holds.has(hold_id): return "unknown_payment_hold"
	var hold: Dictionary = state.holds[hold_id]
	var recipient: String = hold.payee if pay_recipient else hold.payer
	# Pending refunds count toward the payer's balance, so expiry can always return them.
	if pay_recipient and _owned_balance(state, recipient) > WorldData.MAX_COUNTER - hold.amount: return "balance_overflow"
	state.holds.erase(hold_id)
	state.wallets[recipient] += hold.amount
	return "" if tx.write_domain(DOMAIN, state) else "commerce_write_failed"
