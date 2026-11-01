class_name Walker
extends RefCounted
## Movement for any simulated person. Lives entirely in simulation space:
## positions advance in fixed steps; PersonView interpolates for display.

const Anim := PersonView.Anim

var id := 0
var pos := Vector3.ZERO
var prev_pos := Vector3.ZERO
var face_dir := Vector3.FORWARD
var anim: int = Anim.IDLE
var speed := 1.3
var view: PersonView

var _path: Array[Vector3] = []
var _goal := Vector3.ZERO
var _stuck_t := 0.0
var _repath_t := 0.0
var _goal_cell := Vector2i(-1, -1)
## Set when the agent has failed to make progress for a while; owners decide
## how to recover (shoppers give up, staff drop the task).
var stuck := false
var _progress_pos := Vector3.ZERO
var _progress_t := 0.0


func cell() -> Vector2i:
	return StoreGrid.world_to_cell(pos)


func basket_items() -> Array:
	return []


func carrying() -> StringName:
	return &""


func walk_to_cell(target: Vector2i, jitter: float = 0.0) -> bool:
	## Plans a path; returns false if unreachable.
	var g := Game.grid
	var start := g.nearest_walkable(cell(), 3)
	var end := g.nearest_walkable(target, 2)
	if start.x < 0 or end.x < 0:
		return false
	var cells := g.find_path(start, end)
	if cells.is_empty() and start != end:
		return false
	var pts: Array[Vector3] = []
	for c in cells:
		pts.append(_cell_point(c))
	var goal := _cell_point(end)
	if jitter > 0.0:
		goal += Vector3(randf_range(-jitter, jitter), 0, randf_range(-jitter, jitter))
	if pts.is_empty():
		pts.append(goal)
	else:
		pts[pts.size() - 1] = goal
	_path = _smooth(pts)
	_goal = goal
	_goal_cell = end
	_stuck_t = 0.0
	stuck = false
	_progress_pos = pos
	_progress_t = 0.0
	anim = Anim.WALK
	return true


func walk_to_point(p: Vector3) -> bool:
	var ok := walk_to_cell(StoreGrid.world_to_cell(p))
	if ok and not _path.is_empty():
		_path[_path.size() - 1] = Vector3(p.x, _height_at(p), p.z)
		_goal = _path[_path.size() - 1]
	return ok


func has_path() -> bool:
	return not _path.is_empty()


func stop() -> void:
	_path.clear()


func step_move(dt: float) -> bool:
	## Advances along the path. Returns true on arrival (or if idle).
	prev_pos = pos
	if _path.is_empty():
		return true
	var target := _path[0]
	var to := target - pos
	to.y = 0.0
	var dist := to.length()
	var step := speed * dt
	if dist <= step:
		pos = Vector3(target.x, pos.y, target.z)
		_path.pop_front()
	else:
		var dir := to / dist
		pos += dir * step
		face_dir = face_dir.lerp(dir, 0.35).normalized()
	# Ease onto kerb / floor heights instead of popping.
	pos.y = lerpf(pos.y, _height_at(pos), 0.25)
	# Ask the automatic doors to open as we approach.
	var door: EntranceDoor = Game.world.world_info.entrance if Game.world else null
	if door:
		var dp := Vector3(Lot.m(Lot.ENTRANCE.x + 1.5), pos.y, Lot.m(Lot.FRONT_Z))
		if pos.distance_squared_to(dp) < 2.6 * 2.6:
			door.request()
	if _path.is_empty():
		anim = Anim.IDLE
		return true
	# Watchdog: if we haven't covered half a metre in 6 s, something is wrong
	# (e.g. the route was walled in). Stop and let the owner recover.
	_progress_t += dt
	if pos.distance_squared_to(_progress_pos) > 0.25:
		_progress_pos = pos
		_progress_t = 0.0
	elif _progress_t > 6.0:
		stuck = true
		_path.clear()
		anim = Anim.IDLE
		return true
	# If the layout changed under us (a shelf placed on our route), replan.
	_repath_t += dt
	if _repath_t > 0.5:
		_repath_t = 0.0
		var c := StoreGrid.world_to_cell(_path[0])
		if not Game.grid.is_walkable(c) and c != _goal_cell:
			if not walk_to_cell(_goal_cell):
				_path.clear()
				return true
	return false


func face(p: Vector3) -> void:
	var d := p - pos
	d.y = 0.0
	if d.length_squared() > 0.0001:
		face_dir = d.normalized()


func _cell_point(c: Vector2i) -> Vector3:
	var p := StoreGrid.cell_center(c)
	p.y = Lot.ground_height(c)
	return p


func _height_at(p: Vector3) -> float:
	return Lot.ground_height(StoreGrid.world_to_cell(p))


func _smooth(pts: Array[Vector3]) -> Array[Vector3]:
	## String-pulling: skip waypoints we can see past, so routes are natural
	## diagonals rather than grid staircases.
	if pts.size() <= 2:
		return pts
	var out: Array[Vector3] = []
	var anchor := pos
	var i := 0
	while i < pts.size():
		var j := pts.size() - 1
		while j > i and not Game.grid.line_of_sight(anchor, pts[j]):
			j -= 1
		out.append(pts[j])
		anchor = pts[j]
		i = j + 1
	return out
