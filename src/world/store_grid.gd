class_name StoreGrid
extends RefCounted
## Authoritative spatial model of the lot.
##
## * Cells are 0.5 m squares. The floor tile shader uses the same size, so the
##   tiles the player sees *are* the build grid.
## * Zones say what each cell is (shop floor, backroom, pavement, road...).
## * Walls live on cell *edges*, not in cells, so fixtures sit flush against
##   them and partitions don't eat a whole row of floor.
## * Navigation is an AStar2D graph over cells. Placing or removing a fixture
##   only re-links the neighbourhood around it.

signal layout_changed

const CELL := 0.5
enum Zone { VOID, OUTSIDE, SHOP, BACKROOM, ROAD, LOADING }

var width: int
var depth: int
var zones := PackedByteArray()
var occupant := PackedInt32Array()      # fixture uid, or -1
var walkable_occupant := PackedByteArray()  # 1 if the occupying object can be walked through (rugs, mats)
var _blocked_edges: Dictionary = {}       # int edge key -> true
var walls: Array[Dictionary] = []         # visual description of wall runs
var astar := AStar2D.new()


func _init(w: int, d: int) -> void:
	width = w
	depth = d
	zones.resize(w * d)
	zones.fill(Zone.VOID)
	occupant.resize(w * d)
	occupant.fill(-1)
	walkable_occupant.resize(w * d)
	walkable_occupant.fill(0)


# --- Coordinates ------------------------------------------------------------

func idx(c: Vector2i) -> int:
	return c.y * width + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < depth


static func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, 0.0, (c.y + 0.5) * CELL)


static func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


# --- Zones ------------------------------------------------------------------

func set_zone_rect(r: Rect2i, z: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if in_bounds(c):
				zones[idx(c)] = z


func zone_at(c: Vector2i) -> int:
	return zones[idx(c)] if in_bounds(c) else Zone.VOID


func is_indoor(c: Vector2i) -> bool:
	var z := zone_at(c)
	return z == Zone.SHOP or z == Zone.BACKROOM


# --- Walls --------------------------------------------------------------------

func _edge_key(c: Vector2i, dir: int) -> int:
	# dir 0: edge between c and c+(1,0); dir 1: between c and c+(0,1)
	return idx(c) * 2 + dir


func add_wall(a: Vector2i, b: Vector2i, kind: String, data: Dictionary = {}) -> void:
	## A wall run along grid lines between two cell *corners*. Kinds:
	## "exterior", "partition", "window" (blocks movement), "door" (passable).
	var run := {"a": a, "b": b, "kind": kind}
	run.merge(data)
	walls.append(run)
	if kind == "door":
		return
	if a.y == b.y:
		for x in range(mini(a.x, b.x), maxi(a.x, b.x)):
			var c := Vector2i(x, a.y - 1)
			if in_bounds(c) and in_bounds(c + Vector2i(0, 1)):
				_blocked_edges[_edge_key(c, 1)] = true
	else:
		for y in range(mini(a.y, b.y), maxi(a.y, b.y)):
			var c := Vector2i(a.x - 1, y)
			if in_bounds(c) and in_bounds(c + Vector2i(1, 0)):
				_blocked_edges[_edge_key(c, 0)] = true


func edge_blocked(from: Vector2i, to: Vector2i) -> bool:
	## True if a wall separates two orthogonally adjacent cells.
	var d := to - from
	if d == Vector2i(1, 0):
		return _blocked_edges.has(_edge_key(from, 0))
	if d == Vector2i(-1, 0):
		return _blocked_edges.has(_edge_key(to, 0))
	if d == Vector2i(0, 1):
		return _blocked_edges.has(_edge_key(from, 1))
	if d == Vector2i(0, -1):
		return _blocked_edges.has(_edge_key(to, 1))
	return false


# --- Occupancy ---------------------------------------------------------------

func is_free(c: Vector2i) -> bool:
	return in_bounds(c) and occupant[idx(c)] == -1


func is_walkable(c: Vector2i) -> bool:
	if not in_bounds(c):
		return false
	var i := idx(c)
	var z := zones[i]
	if z == Zone.VOID or z == Zone.ROAD:
		return false
	return occupant[i] == -1 or walkable_occupant[i] == 1


func occupy(cells: Array[Vector2i], uid: int, walk_through: bool = false) -> void:
	for c in cells:
		occupant[idx(c)] = uid
		walkable_occupant[idx(c)] = 1 if walk_through else 0
	_relink(cells)
	layout_changed.emit()


func release(cells: Array[Vector2i]) -> void:
	for c in cells:
		occupant[idx(c)] = -1
		walkable_occupant[idx(c)] = 0
	_relink(cells)
	layout_changed.emit()


# --- Navigation --------------------------------------------------------------

const _ORTHO: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const _DIAG: Array[Vector2i] = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]


func can_step(a: Vector2i, b: Vector2i) -> bool:
	if not is_walkable(a) or not is_walkable(b):
		return false
	var d := b - a
	if absi(d.x) + absi(d.y) == 1:
		return not edge_blocked(a, b)
	# Diagonal: both orthogonal detours must be open, so agents never clip a
	# fixture corner or squeeze through the end of a wall.
	var p := a + Vector2i(d.x, 0)
	var q := a + Vector2i(0, d.y)
	return can_step(a, p) and can_step(p, b) and can_step(a, q) and can_step(q, b)


func build_nav() -> void:
	astar.clear()
	astar.reserve_space(width * depth)
	for y in depth:
		for x in width:
			var c := Vector2i(x, y)
			astar.add_point(idx(c), Vector2(x, y))
	for y in depth:
		for x in width:
			_link_cell(Vector2i(x, y))


func _link_cell(c: Vector2i) -> void:
	var i := idx(c)
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
		var n: Vector2i = c + d
		if not in_bounds(n):
			continue
		var j := idx(n)
		var ok := can_step(c, n)
		var has := astar.are_points_connected(i, j)
		if ok and not has:
			astar.connect_points(i, j)
		elif not ok and has:
			astar.disconnect_points(i, j)


func _relink(cells: Array[Vector2i]) -> void:
	if astar.get_point_count() == 0:
		return
	var seen := {}
	for c in cells:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var n := c + Vector2i(dx, dy)
				if in_bounds(n) and not seen.has(n):
					seen[n] = true
					_link_cell(n)


func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not in_bounds(from) or not in_bounds(to):
		return out
	var ids := astar.get_id_path(idx(from), idx(to))
	for id in ids:
		out.append(Vector2i(id % width, id / width))
	return out


func reachable(from: Vector2i, to: Vector2i) -> bool:
	if from == to:
		return is_walkable(from)
	return astar.get_id_path(idx(from), idx(to)).size() > 0


func flood_reachable(from: Vector2i) -> Dictionary:
	## Every cell reachable from `from`. Used to validate a whole layout at once.
	var seen := {}
	if not is_walkable(from):
		return seen
	var stack: Array[Vector2i] = [from]
	seen[from] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in _ORTHO:
			var n: Vector2i = c + d
			if not seen.has(n) and can_step(c, n):
				seen[n] = true
				stack.append(n)
	return seen


func line_of_sight(a: Vector3, b: Vector3, clearance: float = 0.16) -> bool:
	## Walkable straight line between two world points? Used to smooth paths so
	## agents walk naturally instead of zig-zagging cell to cell.
	var dir := b - a
	dir.y = 0.0
	var length := dir.length()
	if length < 0.01:
		return true
	var side := Vector3(-dir.z, 0, dir.x) / length * clearance
	for off in [Vector3.ZERO, side, -side]:
		var prev := world_to_cell(a + off)
		var steps := int(ceil(length / (CELL * 0.25)))
		for s in range(1, steps + 1):
			var p: Vector3 = a + off + dir * (float(s) / steps)
			var c := world_to_cell(p)
			if c != prev:
				if not can_step(prev, c) and not _diag_ok(prev, c):
					return false
				prev = c
	return true


func _diag_ok(a: Vector2i, b: Vector2i) -> bool:
	var d := b - a
	if absi(d.x) > 1 or absi(d.y) > 1:
		return false
	return can_step(a, b)


func nearest_walkable(c: Vector2i, max_r: int = 6) -> Vector2i:
	if is_walkable(c):
		return c
	for r in range(1, max_r + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if is_walkable(n):
					return n
	return Vector2i(-1, -1)
