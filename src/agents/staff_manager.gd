class_name StaffManager
extends Node3D
## Employees, wages and the restock task board.

signal roster_changed

const RESTOCK_BELOW := 0.6

var staff: Array[Staff] = []
var urgent: Dictionary = {}      # "uid:slot" -> true (player asked for it)
var _claimed: Dictionary = {}    # "uid:slot" -> staff id
var _next_id := 1
var _views_root: Node3D
var _rng := RandomNumberGenerator.new()
var _used_names: Dictionary = {}


func _ready() -> void:
	name = "Staff"
	Game.staff = self
	_rng.seed = 99
	_views_root = Node3D.new()
	_views_root.name = "StaffPeople"
	add_child(_views_root)
	Game.tick.connect(_tick)


func ensure_owner() -> void:
	for s in staff:
		if s.role == Staff.Role.OWNER:
			return
	var o := _add(Staff.Role.OWNER, "You")
	var lanes: Array = Game.customers.lanes.values()
	if not lanes.is_empty():
		o.pos = lanes[0].cashier_spot()
	else:
		o.pos = StoreGrid.cell_center(Lot.ENTRANCE_INSIDE) + Vector3(0, Lot.FLOOR_Y, -1.0)
	o.prev_pos = o.pos


func hire(role: int) -> Staff:
	var s := _add(role, _pick_name())
	s.pos = StoreGrid.cell_center(Lot.ENTRANCE_OUTSIDE) + Vector3(0, Lot.FLOOR_Y, 0)
	s.prev_pos = s.pos
	s.hired_day = Game.clock.day
	Game.say("%s joined as %s" % [s.display_name, Staff.ROLE_NAMES[role].to_lower()], "positive")
	return s


func fire(s: Staff) -> void:
	if s.role == Staff.Role.OWNER:
		return
	s.dismiss()
	staff.erase(s)
	_used_names.erase(s.display_name)
	if s.view:
		s.view.queue_free()
	roster_changed.emit()


func clear_all() -> void:
	for s in staff.duplicate():
		s.dismiss()
		if s.view:
			s.view.queue_free()
	staff.clear()
	_claimed.clear()
	_used_names.clear()


func _add(role: int, n: String) -> Staff:
	var s := Staff.new()
	s.setup(_next_id, role, n, _rng.randi())
	s.manager = self
	_next_id += 1
	staff.append(s)
	var v := PersonView.new()
	_views_root.add_child(v)
	v.setup(s, s.look, false)
	s.view = v
	roster_changed.emit()
	return s


func _pick_name() -> String:
	var pool := Staff.NAMES.filter(func(x): return not _used_names.has(x))
	var n: String = pool[_rng.randi() % pool.size()] if not pool.is_empty() else "Sam"
	_used_names[n] = true
	return n


func wages_per_day() -> int:
	var w := 0
	for s in staff:
		w += s.wage
	return w


func count(role: int) -> int:
	var n := 0
	for s in staff:
		if s.role == role:
			n += 1
	return n


func _tick(dt: float) -> void:
	for s in staff:
		s.step(dt)


# --- Till assignment -----------------------------------------------------------

func lane_needing_cashier(who: Staff) -> CheckoutLane:
	var best: CheckoutLane = null
	for l in Game.customers.lanes.values():
		if l.cashier != null and l.cashier != who:
			continue
		if who.role == Staff.Role.OWNER:
			# The owner only steps in when somebody is actually waiting, and
			# leaves it to hired cashiers when there are any spare.
			if l.queue.is_empty() or idle_cashier_available():
				continue
		if best == null or l.queue.size() > best.queue.size():
			best = l
	return best


func idle_cashier_available() -> bool:
	for s in staff:
		if s.role == Staff.Role.CASHIER and s.lane == null:
			for l in Game.customers.lanes.values():
				if l.cashier == null or l.cashier.role == Staff.Role.OWNER:
					return true
	return false


func any_lane() -> CheckoutLane:
	for l in Game.customers.lanes.values():
		return l
	return null


# --- Restock tasks -------------------------------------------------------------

func _key(uid: int, slot: int) -> String:
	return "%d:%d" % [uid, slot]


func mark_urgent(f: Fixture, slot: int) -> void:
	urgent[_key(f.uid, slot)] = true


func _candidates() -> Array:
	var out := []
	for f in Game.store.fixtures.values():
		for i in f.slots.size():
			var s: Dictionary = f.slots[i]
			if s.product == &"" or s.cap <= 0:
				continue
			var k := _key(f.uid, i)
			var fill: float = float(s.qty) / s.cap
			var is_urgent := urgent.has(k)
			if s.qty >= s.cap:
				urgent.erase(k)
				continue
			if fill >= RESTOCK_BELOW and not is_urgent:
				continue
			if Game.inventory.units(s.product) <= 0:
				continue
			if _claimed.has(k):
				continue
			out.append({"uid": f.uid, "slot": i, "score": fill - (1.0 if is_urgent else 0.0)})
	out.sort_custom(func(a, b): return a.score < b.score)
	return out


func has_task_for(_who: Staff) -> bool:
	return not _candidates().is_empty()


func claim_task(who: Staff) -> Dictionary:
	for t in _candidates():
		var f: Fixture = Game.store.fixtures[t.uid]
		if slot_stand_cell(f, t.slot, who.cell()).x < 0:
			continue
		_claimed[_key(t.uid, t.slot)] = who.id
		urgent.erase(_key(t.uid, t.slot))
		return {"uid": t.uid, "slot": t.slot}
	return {}


func release_task(t: Dictionary) -> void:
	if t.is_empty():
		return
	_claimed.erase(_key(t.uid, t.slot))


func slot_stand_cell(f: Fixture, slot: int, from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for c in f.access_for_slot(slot):
		if Game.grid.is_walkable(c):
			var d := Vector2(c - from).length()
			if d < best_d:
				best_d = d
				best = c
	return best


func stockroom_spot(from: Vector3) -> Vector2i:
	## Where staff stand to pick up or put back cases: the nearest rack's aisle.
	var here := StoreGrid.world_to_cell(from)
	var best := Lot.LOADING_INSIDE + Vector2i(1, 0)
	var best_d := INF
	for f in Game.store.fixtures.values():
		if f.def.storage_cases <= 0:
			continue
		for c in f.access_cells():
			if Game.grid.is_walkable(c):
				var d := Vector2(c - here).length()
				if d < best_d:
					best_d = d
					best = c
	return best


# --- Persistence -------------------------------------------------------------

func to_array() -> Array:
	var out := []
	for s in staff:
		out.append({"role": s.role, "name": s.display_name, "hired": s.hired_day})
	return out


func from_array(a: Array) -> void:
	clear_all()
	for d in a:
		var s := _add(int(d.role), String(d.name))
		s.hired_day = int(d.get("hired", 1))
		_used_names[s.display_name] = true
		s.pos = StoreGrid.cell_center(Lot.ENTRANCE_INSIDE) + Vector3(0, Lot.FLOOR_Y, -0.5)
		s.prev_pos = s.pos
	ensure_owner()
