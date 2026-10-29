class_name InventoryRules
extends SessionDomain
## Sole commodity ledger. Container custody is not legal ownership of each item.

const DOMAIN: String = "inventory"
var _items: Dictionary
var _containers: Dictionary

static func create(config: Dictionary) -> InventoryRules:
	if not WorldData.valid(config) or not WorldData.keys(config, ["items", "containers"]): return null
	if not config.items is Dictionary or config.items.is_empty() or not config.containers is Dictionary: return null
	var rules := InventoryRules.new()
	rules._items = config.items.duplicate(true)
	rules._containers = config.containers.duplicate(true)
	for id in rules._items:
		var item: Variant = rules._items[id]
		if not WorldData.id(id) or not WorldData.keys(item, ["label", "stack_limit"]): return null
		if not item.label is String or item.label.is_empty() or not WorldData.integer(item.stack_limit, 1): return null
	for id in rules._containers:
		var container: Variant = rules._containers[id]
		if not WorldData.id(id) or not WorldData.keys(container, ["slots", "owner_id", "access", "items"]): return null
		if not WorldData.integer(container.slots, 1) or not container.owner_id is String: return null
		if not container.access in ["public", "owner", "trade"]: return null
		if container.access != "public" and not WorldData.id(container.owner_id): return null
		if not rules._valid_contents(container.items) or rules.slots_used(container.items) > container.slots: return null
	return rules

func domain_id() -> String:
	return DOMAIN

func schema_version() -> int:
	return 2

func initial_state() -> Dictionary:
	var contents: Dictionary = {}
	for id in _containers: contents[id] = _containers[id].items.duplicate(true)
	return {"contents": contents, "reservations": {}}

func validate(state: Dictionary, snapshot: Dictionary) -> String:
	if not WorldData.keys(state, ["contents", "reservations"]) or not state.contents is Dictionary or not state.reservations is Dictionary: return "inventory_schema"
	if state.contents.size() != _containers.size(): return "container_set"
	for id in _containers:
		if not snapshot.entities.has(id) or not state.contents.has(id): return "container_reference"
		var owner: String = _containers[id].owner_id
		if not owner.is_empty() and not snapshot.entities.has(owner): return "container_owner"
		if not _valid_contents(state.contents[id]): return "invalid_contents"
		if slots_used(state.contents[id]) > _containers[id].slots: return "container_full"
	var reserved: Dictionary = {}
	for id in state.reservations:
		var reservation: Variant = state.reservations[id]
		if not WorldData.id(id) or not WorldData.keys(reservation, ["container_id", "owner_domain", "goods"]): return "reservation_schema"
		if not reservation.container_id is String or not _containers.has(reservation.container_id): return "reservation_container"
		if not reservation.owner_domain is String or not snapshot.domains.has(reservation.owner_domain): return "reservation_owner"
		if not _valid_contents(reservation.goods) or reservation.goods.is_empty(): return "reservation_goods"
		if not reserved.has(reservation.container_id): reserved[reservation.container_id] = {}
		for item in reservation.goods:
			reserved[reservation.container_id][item] = reserved[reservation.container_id].get(item, 0) + reservation.goods[item]
			if reserved[reservation.container_id][item] > state.contents[reservation.container_id].get(item, 0): return "over_reserved_goods"
	return ""

func item_definition(item_id: String) -> Dictionary:
	return _items.get(item_id, {}).duplicate(true)

func container_definition(container_id: String) -> Dictionary:
	return _containers.get(container_id, {}).duplicate(true)

func item_ids() -> Array:
	var ids := _items.keys()
	ids.sort()
	return ids

func container_ids() -> Array:
	return _containers.keys()

func contents(snapshot: Dictionary, container_id: String) -> Dictionary:
	return snapshot.domains[DOMAIN].contents.get(container_id, {}).duplicate(true)

func available_contents(snapshot: Dictionary, container_id: String) -> Dictionary:
	var state: Dictionary = snapshot.domains[DOMAIN]
	var result := contents(snapshot, container_id)
	for record in state.reservations.values():
		if record.container_id != container_id: continue
		for item in record.goods:
			result[item] -= record.goods[item]
			if result[item] == 0: result.erase(item)
	return result

func can_access(actor_id: String, container_id: String) -> bool:
	if not _containers.has(container_id): return false
	var container: Dictionary = _containers[container_id]
	return container.access == "public" or (container.access == "owner" and container.owner_id == actor_id)

func slots_used(goods: Dictionary) -> int:
	var used: int = 0
	for id in goods:
		used += ceili(float(goods[id]) / float(_items[id].stack_limit))
	return used

func _valid_contents(goods: Variant) -> bool:
	if not goods is Dictionary: return false
	for id in goods:
		if not _items.has(id) or not WorldData.integer(goods[id], 1): return false
	return true

func transfer(tx: WorldTransaction, source: String, destination: String, item_id: String, amount: Variant) -> String:
	# Logistical primitive. The interaction/trade owner checks permission and reach.
	if source == destination: return "same_container"
	if not _containers.has(source) or not _containers.has(destination) or not _items.has(item_id): return "unknown_inventory_reference"
	if not WorldData.integer(amount, 1): return "invalid_quantity"
	var quantity: int = int(amount)
	var state := tx.read_domain(DOMAIN)
	var from_goods: Dictionary = state.contents[source]
	var to_goods: Dictionary = state.contents[destination]
	var available: int = from_goods.get(item_id, 0)
	if available_contents(tx.snapshot(), source).get(item_id, 0) < quantity: return "insufficient_available_goods"
	var combined: int = to_goods.get(item_id, 0) + quantity
	if combined > WorldData.MAX_COUNTER: return "quantity_overflow"
	to_goods[item_id] = combined
	if slots_used(to_goods) > _containers[destination].slots: return "container_full"
	if available == quantity: from_goods.erase(item_id)
	else: from_goods[item_id] = available - quantity
	return "" if tx.write_domain(DOMAIN, state) else "inventory_write_failed"

func reserve(tx: WorldTransaction, reservation_id: String, holder: String, goods: Dictionary, owner_domain: String) -> String:
	if not WorldData.id(reservation_id) or not _containers.has(holder) or not _valid_contents(goods) or goods.is_empty(): return "invalid_reservation"
	var state := tx.read_domain(DOMAIN)
	if state.reservations.has(reservation_id): return "duplicate_reservation"
	var available := available_contents(tx.snapshot(), holder)
	for item in goods:
		if available.get(item, 0) < goods[item]: return "insufficient_available_goods"
	state.reservations[reservation_id] = {"container_id": holder, "owner_domain": owner_domain, "goods": goods.duplicate(true)}
	return "" if tx.write_domain(DOMAIN, state) else "inventory_write_failed"

func release(tx: WorldTransaction, reservation_id: String) -> String:
	var state := tx.read_domain(DOMAIN)
	if not state.reservations.has(reservation_id): return "unknown_reservation"
	state.reservations.erase(reservation_id)
	return "" if tx.write_domain(DOMAIN, state) else "inventory_write_failed"

func transform_reserved(tx: WorldTransaction, reservation_id: String, outputs: Dictionary) -> String:
	if not _valid_contents(outputs) or outputs.is_empty(): return "invalid_outputs"
	var state := tx.read_domain(DOMAIN)
	if not state.reservations.has(reservation_id): return "unknown_reservation"
	var record: Dictionary = state.reservations[reservation_id]
	var goods: Dictionary = state.contents[record.container_id]
	for item in record.goods:
		goods[item] -= record.goods[item]
		if goods[item] == 0: goods.erase(item)
	for item in outputs:
		var combined: int = goods.get(item, 0) + outputs[item]
		if combined > WorldData.MAX_COUNTER: return "quantity_overflow"
		goods[item] = combined
	if slots_used(goods) > _containers[record.container_id].slots: return "container_full"
	state.reservations.erase(reservation_id)
	return "" if tx.write_domain(DOMAIN, state) else "inventory_write_failed"
