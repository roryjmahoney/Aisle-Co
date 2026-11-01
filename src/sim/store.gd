class_name Store
extends RefCounted
## The layout of the business: which fixtures exist where, plus store policy
## (prices). Owns placement validation so *every* way of changing the layout
## (build tool, loading a save, tests) obeys the same rules.

signal fixture_added(f: Fixture)
signal fixture_removed(f: Fixture)
signal prices_changed

var grid: StoreGrid
var catalog: Catalog
var fixtures: Dictionary = {}   # uid -> Fixture
var prices: Dictionary = {}     # pid -> cents
var _next_uid := 1

## Cells that must stay clear so doors keep working.
var keep_clear: Dictionary = {}


func setup(g: StoreGrid, c: Catalog) -> void:
	grid = g
	catalog = c
	for pid in catalog.products:
		prices[pid] = catalog.products[pid].reference_price_cents
	for x in range(Lot.ENTRANCE.x - 1, Lot.ENTRANCE.y + 1):
		for z in [Lot.FRONT_Z - 1, Lot.FRONT_Z - 2]:
			keep_clear[Vector2i(x, z)] = true
	for x in range(Lot.STAFF_DOOR.x, Lot.STAFF_DOOR.y):
		keep_clear[Vector2i(x, Lot.PARTITION_Z)] = true
		keep_clear[Vector2i(x, Lot.PARTITION_Z - 1)] = true
	for z in range(Lot.LOADING_DOOR.x, Lot.LOADING_DOOR.y):
		keep_clear[Vector2i(Lot.LEFT_X, z)] = true


func price_of(pid: StringName) -> int:
	return prices.get(pid, 0)


func set_price(pid: StringName, cents: int) -> void:
	prices[pid] = clampi(cents, 1, 99999)
	prices_changed.emit()


# --- Validation ------------------------------------------------------------

func check_placement(def: FixtureDef, anchor: Vector2i, rot: int, ignore_uid: int = -1) -> String:
	## Returns "" when placement is valid, otherwise a short, human reason.
	var cells := def.cells_for(anchor, rot)
	var own := {}
	for c in cells:
		own[c] = true
		if not grid.in_bounds(c):
			return "Outside the property"
		var z := grid.zone_at(c)
		if z == StoreGrid.Zone.SHOP and not def.allow_shop:
			return "Stockroom only"
		if z == StoreGrid.Zone.BACKROOM and not def.allow_backroom:
			return "Shop floor only"
		if z != StoreGrid.Zone.SHOP and z != StoreGrid.Zone.BACKROOM:
			return "Must be inside the store"
		var occ := grid.occupant[grid.idx(c)]
		if occ != -1 and occ != ignore_uid:
			return "Overlaps something"
		if keep_clear.has(c):
			return "Keep the doorway clear"
	# Footprint mustn't straddle a wall.
	for c in cells:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var n: Vector2i = c + d
			if own.has(n) and grid.edge_blocked(c, n):
				return "Can't straddle a wall"
	# Access cells must be open floor on the same side of any wall.
	var acc := def.access_for(anchor, rot)
	var any_open := acc.is_empty()
	for c in acc:
		if own.has(c):
			continue
		if grid.in_bounds(c) and grid.is_indoor(c):
			var occ2 := grid.occupant[grid.idx(c)]
			if occ2 == -1 or occ2 == ignore_uid or grid.walkable_occupant[grid.idx(c)] == 1:
				any_open = true
	if not any_open:
		return "Needs a clear aisle in front"
	if def.is_checkout:
		var pay := def.local_to_cell(anchor, rot, Vector2i(def.footprint.x, 2))
		if not _cell_open(pay, ignore_uid):
			return "Checkout lane is blocked"
	# Global check: everything must still be reachable.
	return _connectivity_with(def, cells, acc, ignore_uid)


func _cell_open(c: Vector2i, ignore_uid: int) -> bool:
	if not grid.in_bounds(c) or not grid.is_indoor(c):
		return false
	var occ := grid.occupant[grid.idx(c)]
	return occ == -1 or occ == ignore_uid or grid.walkable_occupant[grid.idx(c)] == 1


func _connectivity_with(def: FixtureDef, cells: Array[Vector2i], acc: Array[Vector2i], ignore_uid: int) -> String:
	# Temporarily apply the change to the occupancy grid, flood fill from the
	# entrance, then restore. No navigation links are touched.
	var saved := {}
	if ignore_uid != -1 and fixtures.has(ignore_uid):
		for c in fixtures[ignore_uid].cells():
			saved[c] = [grid.occupant[grid.idx(c)], grid.walkable_occupant[grid.idx(c)]]
			grid.occupant[grid.idx(c)] = -1
			grid.walkable_occupant[grid.idx(c)] = 0
	for c in cells:
		if not saved.has(c):
			saved[c] = [grid.occupant[grid.idx(c)], grid.walkable_occupant[grid.idx(c)]]
		grid.occupant[grid.idx(c)] = 999999
		grid.walkable_occupant[grid.idx(c)] = 1 if def.walk_through else 0
	var reach := grid.flood_reachable(Lot.ENTRANCE_INSIDE)
	var err := ""
	if not reach.has(Lot.LOADING_INSIDE):
		err = "Blocks the route to the stockroom"
	if err == "":
		for f in fixtures.values():
			if f.uid == ignore_uid or f.def.access_cells.is_empty():
				continue
			var ok := false
			for c in f.access_cells():
				if reach.has(c):
					ok = true
					break
			if not ok:
				err = "Blocks access to %s" % f.def.display_name
				break
	if err == "" and not acc.is_empty():
		# The new fixture's own aisle must be reachable too.
		var ok2 := false
		for c in acc:
			if reach.has(c):
				ok2 = true
				break
		if not ok2:
			err = "Its aisle can't be reached"
	for c in saved:
		grid.occupant[grid.idx(c)] = saved[c][0]
		grid.walkable_occupant[grid.idx(c)] = saved[c][1]
	return err


# --- Mutation ---------------------------------------------------------------

func add(def: FixtureDef, anchor: Vector2i, rot: int, uid: int = -1) -> Fixture:
	if uid < 0:
		uid = _next_uid
	_next_uid = maxi(_next_uid, uid + 1)
	var f := Fixture.new(uid, def, anchor, rot)
	fixtures[uid] = f
	grid.occupy(f.cells(), uid, def.walk_through)
	fixture_added.emit(f)
	return f


func remove(uid: int) -> void:
	var f: Fixture = fixtures.get(uid)
	if f == null:
		return
	fixtures.erase(uid)
	grid.release(f.cells())
	fixture_removed.emit(f)


func move(uid: int, anchor: Vector2i, rot: int) -> void:
	var f: Fixture = fixtures.get(uid)
	if f == null:
		return
	grid.release(f.cells())
	f.anchor = anchor
	f.rot = posmod(rot, 4)
	grid.occupy(f.cells(), uid, f.def.walk_through)
	fixture_removed.emit(f)
	fixture_added.emit(f)


func appeal() -> int:
	var a := 0
	for f in fixtures.values():
		a += f.def.appeal
	return a


func upkeep() -> int:
	var c := 0
	for f in fixtures.values():
		c += f.def.upkeep_cents_per_day
	return c


func checkouts() -> Array[Fixture]:
	var out: Array[Fixture] = []
	for f in fixtures.values():
		if f.def.is_checkout:
			out.append(f)
	return out


func fixture_at(c: Vector2i) -> Fixture:
	if not grid.in_bounds(c):
		return null
	return fixtures.get(grid.occupant[grid.idx(c)])


func slots_with(pid: StringName) -> Array:
	## [[fixture, slot_index], ...] for every tier assigned to this product.
	var out := []
	for f in fixtures.values():
		for i in f.slots.size():
			if f.slots[i].product == pid:
				out.append([f, i])
	return out


func carried_products() -> Array[StringName]:
	var out: Array[StringName] = []
	for f in fixtures.values():
		for s in f.slots:
			if s.product != &"" and not out.has(s.product):
				out.append(s.product)
	return out
