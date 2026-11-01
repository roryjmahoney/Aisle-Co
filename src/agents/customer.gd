class_name Customer
extends Walker
## A shopper. Arrives with a list, a budget and a temperament; walks the
## aisles; takes real units off real shelves; queues; pays; goes home with an
## opinion of the shop.

enum S { ARRIVE, DECIDE, TO_SHELF, BROWSE, TO_CHECKOUT, QUEUE, AT_TILL, LEAVE, EXIT, GONE }
const STATE_NAMES := ["Arriving", "Deciding", "Heading to a shelf", "Browsing", "Heading to the till",
		"Queuing", "Paying", "Leaving", "Leaving", "Gone"]

const FIRST_NAMES := ["Ada", "Ben", "Cleo", "Dev", "Esme", "Femi", "Gus", "Hana", "Ivo", "June", "Kofi", "Lena",
		"Milo", "Nell", "Omar", "Pia", "Quinn", "Rosa", "Sami", "Tess", "Uri", "Vera", "Wren", "Yusuf", "Zoe",
		"Arlo", "Bea", "Cyrus", "Dot", "Ezra", "Flo", "Hal", "Iris", "Jude", "Kit", "Lou", "Mae", "Ned", "Ora"]

var state := S.ARRIVE
var display_name := ""
var look: Dictionary
# Traits
var budget := 3000
var price_sensitivity := 1.0
var patience := 60.0
var patience_left := 60.0
var substitution := 0.5
var satisfaction := 0.7
# Shopping
var list: Array[Dictionary] = []     # {pid, qty, status: "todo"|"got"|"missed"|"skipped"}
var basket: Dictionary = {}           # pid -> units
var spent_est := 0
var thoughts: Array[String] = []
var lane: CheckoutLane
var queue_index := -1
var scanned_count := 0
var paid := false
var outcome := ""
var _target_fixture := -1
var _target_slot := -1
var _timer := 0.0
var _exit_cell := Vector2i.ZERO
var _entered := false
var _rng := RandomNumberGenerator.new()


func setup(p_id: int, rng_seed: int, spawn: Vector2i, exit_to: Vector2i) -> void:
	id = p_id
	_rng.seed = rng_seed
	display_name = FIRST_NAMES[_rng.randi() % FIRST_NAMES.size()]
	look = PersonArt.random_look(_rng)
	budget = _rng.randi_range(12, 55) * 100
	price_sensitivity = _rng.randf_range(0.6, 1.5)
	patience = _rng.randf_range(35.0, 80.0)
	patience_left = patience
	substitution = _rng.randf_range(0.15, 0.85)
	speed = _rng.randf_range(1.05, 1.45)
	pos = StoreGrid.cell_center(spawn) + Vector3(0, Lot.ground_height(spawn), _rng.randf_range(-0.3, 0.3))
	prev_pos = pos
	_exit_cell = exit_to
	_make_list()
	walk_to_cell(Lot.ENTRANCE_INSIDE, 0.25)


func _make_list() -> void:
	var cat := Game.catalog
	var weights := []
	var total := 0.0
	for pid in cat.product_order:
		var w: float = cat.product(pid).popularity
		weights.append([pid, w])
		total += w
	var n := 1 + _rng.randi() % 3
	if Game.store.appeal() > 0 and _has_basket_stand():
		n += _rng.randi() % 2
	var chosen := {}
	for i in n:
		var r := _rng.randf() * total
		for w in weights:
			r -= w[1]
			if r <= 0.0:
				chosen[w[0]] = true
				break
	for pid in chosen:
		var p := cat.product(pid)
		var qty := 1 + (_rng.randi() % 2 if p.reference_price_cents < 250 else 0)
		list.append({"pid": pid, "qty": qty, "status": "todo"})


func _has_basket_stand() -> bool:
	for f in Game.store.fixtures.values():
		if f.def.id == &"basket_stand":
			return true
	return false


func think(t: String) -> void:
	thoughts.append(t)
	if thoughts.size() > 5:
		thoughts.pop_front()


func basket_items() -> Array:
	var out := []
	for pid in basket:
		var p := Game.catalog.product(pid)
		for i in basket[pid]:
			out.append(p)
	return out


func basket_count() -> int:
	var n := 0
	for pid in basket:
		n += basket[pid]
	return n


func basket_value() -> int:
	var v := 0
	for pid in basket:
		v += basket[pid] * Game.store.price_of(pid)
	return v


func status_text() -> String:
	return STATE_NAMES[state]


# --- Simulation step -----------------------------------------------------------

func step(dt: float) -> void:
	if stuck:
		_recover_from_stuck()
		return
	match state:
		S.ARRIVE:
			if step_move(dt):
				_on_entered()
				state = S.DECIDE
		S.DECIDE:
			prev_pos = pos
			_decide()
		S.TO_SHELF:
			if step_move(dt):
				_arrive_at_shelf()
		S.BROWSE:
			prev_pos = pos
			_timer -= dt
			if _timer <= 0.0:
				if anim == Anim.BROWSE:
					anim = Anim.REACH
					_timer = 0.55
					var v: FixtureView = Game.world.view_for(_target_fixture)
					if v:
						var f: Fixture = Game.store.fixtures.get(_target_fixture)
						if f:
							var local := f.to_world(Vector3.ZERO).direction_to(pos)
							v.open_door_near(local.rotated(Vector3.UP, -f.yaw()).x)
				else:
					_take_from_shelf()
					state = S.DECIDE
		S.TO_CHECKOUT:
			if lane == null or not Game.store.fixtures.has(lane.fixture.uid):
				_go_to_checkout()
				return
			if step_move(dt):
				state = S.QUEUE
				anim = Anim.QUEUE
				face(lane.till_position())
			_wait(dt)
		S.QUEUE:
			prev_pos = pos
			if lane == null or not Game.store.fixtures.has(lane.fixture.uid):
				_go_to_checkout()
				return
			if has_path():
				step_move(dt)
				if not has_path():
					anim = Anim.QUEUE
					face(lane.till_position())
			_wait(dt)
		S.AT_TILL:
			prev_pos = pos
			face(lane.till_position())
		S.LEAVE:
			if step_move(dt):
				state = S.EXIT
				walk_to_cell(_exit_cell, 0.4)
		S.EXIT:
			if step_move(dt):
				state = S.GONE


func _on_entered() -> void:
	_entered = true
	var report: Dictionary = Game.economy.report
	report.customers += 1
	var appeal := Game.store.appeal()
	satisfaction = clampf(satisfaction + minf(appeal * 0.008, 0.12), 0.0, 1.0)
	if appeal >= 8:
		think("What a lovely little shop.")


func _decide() -> void:
	var item: Dictionary = {}
	for it in list:
		if it.status == "todo":
			item = it
			break
	if item.is_empty():
		if basket_count() > 0:
			_go_to_checkout()
		else:
			if outcome == "":
				outcome = "empty"
			think("Nothing here for me today.")
			_leave()
		return
	var best: Array = _find_stock(item.pid)
	if best.is_empty():
		var p := Game.catalog.product(item.pid)
		var carried := not Game.store.slots_with(item.pid).is_empty()
		# Try a substitute from the same category.
		if _rng.randf() < substitution:
			for alt in Game.catalog.product_order:
				if alt == item.pid or Game.catalog.product(alt).category != p.category:
					continue
				if not _find_stock(alt).is_empty() and not _list_has(alt):
					think("No %s… I'll take %s instead." % [p.display_name, Game.catalog.product(alt).display_name])
					item.status = "skipped"
					list.append({"pid": alt, "qty": 1, "status": "todo"})
					satisfaction -= 0.03
					return
		item.status = "missed"
		satisfaction -= 0.12
		if carried:
			think("%s is sold out." % p.display_name)
			_complain("out_of_stock")
		else:
			think("They don't sell %s." % p.display_name)
			_complain("not_carried")
		return
	_target_fixture = best[0].uid
	_target_slot = best[1]
	var stand: Vector2i = best[2]
	if walk_to_cell(stand, 0.12):
		state = S.TO_SHELF
	else:
		item.status = "missed"
		think("I can't reach the %s." % Game.catalog.product(item.pid).display_name)
		_complain("blocked")


func _list_has(pid: StringName) -> bool:
	for it in list:
		if it.pid == pid:
			return true
	return false


func _find_stock(pid: StringName) -> Array:
	## Nearest reachable tier with this product in stock: [fixture, slot, cell].
	var best: Array = []
	var best_d := INF
	var here := cell()
	for pair in Game.store.slots_with(pid):
		var f: Fixture = pair[0]
		var slot: int = pair[1]
		if f.slots[slot].qty <= 0:
			continue
		for c in f.access_for_slot(slot):
			if not Game.grid.is_walkable(c):
				continue
			var d := Vector2(c - here).length() + _rng.randf() * 1.5
			if d < best_d:
				best_d = d
				best = [f, slot, c]
	return best


func _arrive_at_shelf() -> void:
	var f: Fixture = Game.store.fixtures.get(_target_fixture)
	if f == null or _target_slot >= f.slots.size():
		state = S.DECIDE
		return
	face(f.world_center())
	state = S.BROWSE
	anim = Anim.BROWSE
	_timer = _rng.randf_range(1.0, 2.4) / speed


func _take_from_shelf() -> void:
	anim = Anim.IDLE
	var f: Fixture = Game.store.fixtures.get(_target_fixture)
	var item: Dictionary = {}
	for it in list:
		if it.status == "todo":
			item = it
			break
	if f == null or item.is_empty() or _target_slot >= f.slots.size():
		return
	var s: Dictionary = f.slots[_target_slot]
	if s.product != item.pid or s.qty <= 0:
		# Someone beat us to it; decide again (will look elsewhere).
		return
	var p := Game.catalog.product(item.pid)
	var price := Game.store.price_of(item.pid)
	var ratio := float(price) / float(p.reference_price_cents)
	# Willingness to pay falls off above the reference price.
	var willing := 1.0
	if ratio > 1.0:
		willing = clampf(1.0 - (ratio - 1.0) * p.price_elasticity * price_sensitivity * 1.8, 0.0, 1.0)
	if _rng.randf() > willing:
		item.status = "skipped"
		satisfaction -= 0.1
		think("%s at %s? No thanks." % [p.display_name, Fmt.money(price)])
		_complain("price")
		return
	var qty: int = item.qty
	if ratio < 0.85 and _rng.randf() < 0.5:
		qty += 1
		think("%s is a bargain!" % p.display_name)
		satisfaction += 0.04
	var affordable := (budget - spent_est) / maxi(price, 1)
	qty = mini(qty, affordable)
	if qty <= 0:
		item.status = "skipped"
		think("Over my budget today.")
		return
	var got := Game.inventory.pick(f, _target_slot, qty)
	if got <= 0:
		return
	basket[item.pid] = basket.get(item.pid, 0) + got
	spent_est += got * price
	item.status = "got"
	satisfaction += 0.04 if ratio <= 1.05 else 0.0
	Sfx.play_at("pick", pos + Vector3(0, 1, 0), -16.0)


func _go_to_checkout() -> void:
	if lane:
		lane.leave(self)
		lane = null
	var lanes: Array = Game.customers.lanes.values()
	if lanes.is_empty():
		think("There's nowhere to pay!")
		_complain("no_till")
		_abandon()
		return
	# Prefer staffed tills, then the shortest queue.
	lanes.sort_custom(func(a, b):
		var sa: int = a.queue.size() + (0 if a.is_open() else 4)
		var sb: int = b.queue.size() + (0 if b.is_open() else 4)
		return sa < sb)
	var best: CheckoutLane = lanes[0]
	var tolerance := int(patience / 12.0) + 2
	if best.queue.size() > tolerance:
		think("That queue is far too long.")
		_complain("queue")
		_abandon()
		return
	lane = best
	queue_index = lane.join(self)
	state = S.TO_CHECKOUT
	if not walk_to_point(lane.spot(queue_index)):
		lane.leave(self)
		lane = null
		think("I can't get to the till.")
		_complain("blocked")
		_abandon()


func queue_moved(i: int) -> void:
	queue_index = i
	if state == S.QUEUE or state == S.TO_CHECKOUT:
		walk_to_point(lane.spot(i))
		if state == S.QUEUE:
			anim = Anim.WALK


func ready_at_till() -> bool:
	if state == S.QUEUE and queue_index == 0 and not has_path():
		state = S.AT_TILL
		anim = Anim.QUEUE
	return state == S.AT_TILL


func scanned(n: int) -> void:
	scanned_count = n


func pay() -> void:
	var units := 0
	for pid in basket:
		var p := Game.catalog.product(pid)
		var n: int = basket[pid]
		Game.economy.record_sale(p, n, Game.store.price_of(pid))
		units += n
	Game.inventory.sell_from_basket(units)
	basket.clear()
	paid = true
	outcome = "served"
	Game.economy.report.served += 1
	var got_all := true
	for it in list:
		if it.status != "got":
			got_all = false
	if got_all:
		satisfaction += 0.08
		think("Got everything I came for.")
	lane = null
	_leave()


func _wait(dt: float) -> void:
	patience_left -= dt
	if patience_left < patience * 0.5:
		satisfaction -= dt * 0.004
	if patience_left <= 0.0:
		think("I've waited long enough.")
		_complain("queue")
		_abandon()


func _abandon() -> void:
	if lane:
		lane.leave(self)
		lane = null
	if basket_count() > 0:
		Game.inventory.return_basket(basket)
		basket.clear()
	satisfaction -= 0.25
	outcome = "abandoned"
	_leave()


func _complain(kind: String) -> void:
	var c: Dictionary = Game.economy.report.complaints
	c[kind] = c.get(kind, 0) + 1


func _leave() -> void:
	satisfaction = clampf(satisfaction, 0.0, 1.0)
	state = S.LEAVE
	if not walk_to_cell(Lot.ENTRANCE_OUTSIDE, 0.3):
		state = S.EXIT
		walk_to_cell(_exit_cell)


func _recover_from_stuck() -> void:
	stuck = false
	match state:
		S.LEAVE, S.EXIT, S.ARRIVE:
			# Can't get in or out: quietly head off (outside the shop).
			if _entered and basket_count() > 0:
				Game.inventory.return_basket(basket)
				basket.clear()
			state = S.GONE
		S.TO_SHELF:
			think("I can't get to that shelf.")
			state = S.DECIDE
			for it in list:
				if it.status == "todo":
					it.status = "missed"
					break
		_:
			_complain("blocked")
			_abandon()


func force_leave() -> void:
	## Closing time / reload: drop everything and head out.
	if state in [S.LEAVE, S.EXIT, S.GONE]:
		return
	if state == S.AT_TILL:
		return
	_abandon()
