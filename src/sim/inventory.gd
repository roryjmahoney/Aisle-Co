class_name Inventory
extends RefCounted
## Physical stock. Units exist in exactly one place at a time:
##   supplier → (delivery) → stockroom → (restock) → shelf → (pick) → basket → (sale) → gone
## Every move is an explicit method that checks quantities first, so stock can
## never go negative or be duplicated. `audit()` verifies the books.

signal stockroom_changed
signal order_placed(order: Dictionary)
signal delivery_state(order: Dictionary)
signal delivered(order: Dictionary)

enum DeliveryState { ORDERED, ARRIVING, UNLOADING, DONE }

const LEAD_MINUTES := 60.0
const ARRIVE_MINUTES := 4.0    # van drives in
const UNLOAD_MINUTES := 6.0    # cases carried in

var catalog: Catalog
var store: Store
var economy: Economy
var clock: SimClock

var stockroom: Dictionary = {}       # pid -> units
var orders: Array[Dictionary] = []   # active deliveries
var _next_order := 1
## Running totals for audit.
var total_received := 0
var total_sold := 0
var total_written_off := 0
var in_baskets := 0


func setup(c: Catalog, s: Store, e: Economy, k: SimClock) -> void:
	catalog = c
	store = s
	economy = e
	clock = k


# --- Capacity ------------------------------------------------------------

func capacity_cases() -> int:
	var n := 0
	for f in store.fixtures.values():
		n += f.def.storage_cases
	return n


func cases_of(pid: StringName, units: int) -> int:
	var p := catalog.product(pid)
	return int(ceil(float(units) / p.case_size)) if units > 0 else 0


func used_cases() -> int:
	var n := 0
	for pid in stockroom:
		n += cases_of(pid, stockroom[pid])
	return n


func incoming_cases() -> int:
	var n := 0
	for o in orders:
		for pid in o.items:
			n += o.items[pid]
	return n


func free_cases() -> int:
	return capacity_cases() - used_cases() - incoming_cases()


func units(pid: StringName) -> int:
	return stockroom.get(pid, 0)


func shelf_units(pid: StringName) -> int:
	var n := 0
	for f in store.fixtures.values():
		for s in f.slots:
			if s.product == pid:
				n += s.qty
	return n


func shelf_capacity(pid: StringName) -> int:
	var n := 0
	for f in store.fixtures.values():
		for s in f.slots:
			if s.product == pid:
				n += s.cap
	return n


# --- Ordering ---------------------------------------------------------------

func order_cost(items: Dictionary) -> int:
	var total := 0
	for pid in items:
		var p := catalog.product(pid)
		total += items[pid] * p.case_size * p.unit_cost_cents
	return total


func validate_order(items: Dictionary) -> String:
	var cases := 0
	for pid in items:
		if catalog.product(pid) == null:
			return "Unknown product"
		if items[pid] < 0:
			return "Invalid quantity"
		cases += items[pid]
	if cases == 0:
		return "Nothing to order"
	if cases > free_cases():
		return "Not enough stockroom space (%d free)" % maxi(free_cases(), 0)
	if not economy.can_afford(order_cost(items)):
		return "Not enough cash"
	return ""


func place_order(items: Dictionary) -> Dictionary:
	var err := validate_order(items)
	if err != "":
		return {"error": err}
	var clean := {}
	for pid in items:
		if items[pid] > 0:
			clean[pid] = int(items[pid])
	var cost := order_cost(clean)
	economy.charge(Economy.Kind.STOCK, cost, "Wholesale order #%d" % _next_order)
	var eta := clock.absolute_minute() + LEAD_MINUTES
	# Suppliers deliver during the day: late orders arrive next morning.
	var day_min := fmod(eta, 1440.0)
	if day_min > SimClock.CLOSE_AT + 60 or day_min < SimClock.DAY_START:
		eta = floor(eta / 1440.0 + (1.0 if day_min > SimClock.DAY_START else 0.0)) * 1440.0 + SimClock.DAY_START + 20.0
	var o := {"id": _next_order, "items": clean, "cost": cost, "eta": eta,
			"state": DeliveryState.ORDERED, "t": 0.0}
	_next_order += 1
	orders.append(o)
	order_placed.emit(o)
	return o


func step(dt: float) -> void:
	if orders.is_empty():
		return
	var now := clock.absolute_minute()
	var dm := dt * SimClock.MINUTES_PER_SECOND
	for o in orders.duplicate():
		match o.state:
			DeliveryState.ORDERED:
				if now >= o.eta - ARRIVE_MINUTES:
					o.state = DeliveryState.ARRIVING
					o.t = 0.0
					delivery_state.emit(o)
			DeliveryState.ARRIVING:
				o.t += dm
				if o.t >= ARRIVE_MINUTES:
					o.state = DeliveryState.UNLOADING
					o.t = 0.0
					delivery_state.emit(o)
			DeliveryState.UNLOADING:
				o.t += dm
				if o.t >= UNLOAD_MINUTES:
					_receive(o)


func _receive(o: Dictionary) -> void:
	for pid in o.items:
		var p := catalog.product(pid)
		var n: int = o.items[pid] * p.case_size
		stockroom[pid] = units(pid) + n
		total_received += n
	o.state = DeliveryState.DONE
	orders.erase(o)
	delivery_state.emit(o)
	delivered.emit(o)
	stockroom_changed.emit()


func next_delivery() -> Dictionary:
	var best := {}
	for o in orders:
		if best.is_empty() or o.eta < best.eta:
			best = o
	return best


# --- Moving stock -----------------------------------------------------------

func restock_slot(f: Fixture, slot: int, max_units: int = 1 << 30) -> int:
	## Stockroom → shelf. Returns units moved.
	var s := f.slots[slot]
	if s.product == &"":
		return 0
	var n := mini(mini(s.cap - s.qty, units(s.product)), max_units)
	if n <= 0:
		return 0
	stockroom[s.product] = units(s.product) - n
	s.qty += n
	f.changed.emit(slot)
	stockroom_changed.emit()
	return n


func pick(f: Fixture, slot: int, want: int) -> int:
	## Shelf → shopper's basket. Returns units actually taken.
	var s := f.slots[slot]
	var n := mini(want, s.qty)
	if n <= 0:
		return 0
	s.qty -= n
	in_baskets += n
	f.changed.emit(slot)
	return n


func sell_from_basket(units_sold: int) -> void:
	assert(units_sold <= in_baskets)
	in_baskets -= units_sold
	total_sold += units_sold


func return_basket(contents: Dictionary) -> void:
	## An abandoned basket: staff put the goods back in the stockroom.
	for pid in contents:
		var n: int = contents[pid]
		in_baskets -= n
		stockroom[pid] = units(pid) + n
	stockroom_changed.emit()


func assign_slot(f: Fixture, slot: int, pid: StringName) -> String:
	## Change what a shelf tier sells. Any units already there go back to the
	## stockroom first (refused if there's no room).
	var s := f.slots[slot]
	if s.product == pid:
		return ""
	var p: ProductDef = catalog.product(pid) if pid != &"" else null
	if p != null and not Merch.fits(p, f.def):
		return "%s doesn't fit here" % p.display_name
	if s.qty > 0:
		var back_cases := cases_of(s.product, units(s.product) + s.qty) - cases_of(s.product, units(s.product))
		if back_cases > capacity_cases() - used_cases():
			return "No stockroom space to clear this tier"
		stockroom[s.product] = units(s.product) + s.qty
		s.qty = 0
	s.product = pid
	s.cap = Merch.capacity(p, f.def) if p else 0
	f.changed.emit(slot)
	stockroom_changed.emit()
	return ""


func clear_fixture(f: Fixture) -> String:
	## Before a fixture is removed: return its stock. Refuses if the stockroom
	## cannot take it, so goods are never destroyed by bulldozing.
	var returning := {}
	for s in f.slots:
		if s.qty > 0:
			returning[s.product] = returning.get(s.product, 0) + s.qty
	var extra := 0
	for pid in returning:
		extra += cases_of(pid, units(pid) + returning[pid]) - cases_of(pid, units(pid))
	var cap_after := capacity_cases() - f.def.storage_cases
	if f.def.storage_cases > 0 and used_cases() + extra > cap_after:
		return "Move the cases elsewhere first — the other racks are full"
	if extra > 0 and used_cases() + extra > cap_after:
		return "Not enough stockroom space for this shelf's stock"
	for pid in returning:
		stockroom[pid] = units(pid) + returning[pid]
	for i in f.slots.size():
		f.slots[i].qty = 0
	stockroom_changed.emit()
	return ""


func seed_shelf(f: Fixture, slot: int, qty: int) -> void:
	## Opening inventory that comes with the shop. Counted as received.
	var s := f.slots[slot]
	var n := clampi(qty, 0, s.cap - s.qty)
	s.qty += n
	total_received += n
	f.changed.emit(slot)


func seed_stockroom(pid: StringName, qty: int) -> void:
	stockroom[pid] = units(pid) + qty
	total_received += qty
	stockroom_changed.emit()


func total_units_everywhere() -> int:
	var n := in_baskets
	for pid in stockroom:
		n += stockroom[pid]
	for f in store.fixtures.values():
		n += f.total_units()
	return n


func audit() -> String:
	## Units in the world must equal units received minus units sold.
	for pid in stockroom:
		if stockroom[pid] < 0:
			return "Negative stockroom units for %s" % pid
	for f in store.fixtures.values():
		for s in f.slots:
			if s.qty < 0 or s.qty > s.cap:
				return "Shelf %d holds %d/%d" % [f.uid, s.qty, s.cap]
	if in_baskets < 0:
		return "Negative basket units"
	var expect := total_received - total_sold - total_written_off
	var have := total_units_everywhere()
	if expect != have:
		return "Unit conservation broken: expected %d, found %d" % [expect, have]
	return ""


func to_dict() -> Dictionary:
	var sr := {}
	for pid in stockroom:
		sr[String(pid)] = stockroom[pid]
	var od := []
	for o in orders:
		var items := {}
		for pid in o.items:
			items[String(pid)] = o.items[pid]
		od.append({"id": o.id, "items": items, "cost": o.cost, "eta": o.eta, "state": o.state, "t": o.t})
	return {"stockroom": sr, "orders": od, "next_order": _next_order, "received": total_received,
			"sold": total_sold, "written_off": total_written_off}


func from_dict(d: Dictionary) -> void:
	stockroom.clear()
	for k in d.get("stockroom", {}):
		if catalog.product(StringName(k)):
			stockroom[StringName(k)] = int(d.stockroom[k])
	orders.clear()
	for o in d.get("orders", []):
		var items := {}
		for k in o.items:
			if catalog.product(StringName(k)):
				items[StringName(k)] = int(o.items[k])
		orders.append({"id": int(o.id), "items": items, "cost": int(o.cost), "eta": float(o.eta),
				"state": int(o.state), "t": float(o.t)})
	_next_order = int(d.get("next_order", 1))
	total_received = int(d.get("received", 0))
	total_sold = int(d.get("sold", 0))
	total_written_off = int(d.get("written_off", 0))
	in_baskets = 0
	stockroom_changed.emit()
