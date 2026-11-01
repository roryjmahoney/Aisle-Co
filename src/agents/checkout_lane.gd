class_name CheckoutLane
extends RefCounted
## One till: its queue, who's staffing it, and the scanning process.

const SCAN_SECONDS := 0.42
const PAY_SECONDS := 1.1
const MAX_SPOTS := 8

var fixture: Fixture
var queue: Array = []          # Customers, index 0 is at the till
var cashier: RefCounted = null # Staff assigned (walking or present)
var cashier_present := false
var _spots: Array[Vector3] = []
var _scan_t := 0.0
var _scan_index := 0
var _paying := false
var idle_time := 0.0


func _init(f: Fixture) -> void:
	fixture = f
	refresh_spots()


func refresh_spots() -> void:
	## Queue positions: the pay spot beside the till, then back along the lane
	## for as long as the floor is open.
	_spots.clear()
	var d := fixture.def
	var lane_x := d.footprint.x
	for i in MAX_SPOTS:
		var lc := Vector2i(lane_x, 2 - i)
		var c := d.local_to_cell(fixture.anchor, fixture.rot, lc)
		if not Game.grid.is_walkable(c) and i > 0:
			break
		var local := Vector3((lc.x + 0.5) * StoreGrid.CELL - d.footprint.x * StoreGrid.CELL * 0.5, 0.0,
				(lc.y + 0.5) * StoreGrid.CELL - d.footprint.y * StoreGrid.CELL * 0.5)
		var p := fixture.to_world(local)
		p.y = Lot.FLOOR_Y
		_spots.append(p)


func spot(i: int) -> Vector3:
	if _spots.is_empty():
		refresh_spots()
	if i < _spots.size():
		return _spots[i]
	# Overflow: shoppers bunch loosely behind the last proper spot.
	var last := _spots[_spots.size() - 1]
	var back := (_spots[_spots.size() - 1] - _spots[0]).normalized() if _spots.size() > 1 else Vector3.FORWARD
	return last + back * 0.45 * (i - _spots.size() + 1)


func capacity() -> int:
	return _spots.size()


func till_position() -> Vector3:
	return fixture.to_world(Vector3(0.1, 0, 0.4)) + Vector3(0, Lot.FLOOR_Y, 0)


func cashier_spot() -> Vector3:
	return fixture.to_world(Vector3(-0.5, 0, 0.4)) + Vector3(0, Lot.FLOOR_Y, 0)


func is_open() -> bool:
	return cashier != null


func join(c: RefCounted) -> int:
	queue.append(c)
	return queue.size() - 1


func leave(c: RefCounted) -> void:
	var i := queue.find(c)
	if i == -1:
		return
	queue.remove_at(i)
	if i == 0:
		_scan_t = 0.0
		_scan_index = 0
		_paying = false
	for j in queue.size():
		queue[j].queue_moved(j)


func step(dt: float) -> void:
	if queue.is_empty():
		idle_time += dt
		return
	idle_time = 0.0
	if not cashier_present:
		return
	var c = queue[0]
	if not c.ready_at_till():
		return
	var items: Array = c.basket_items()
	_scan_t += dt
	if not _paying:
		if _scan_t >= SCAN_SECONDS / maxf(cashier.skill, 0.2):
			_scan_t = 0.0
			if _scan_index < items.size():
				_scan_index += 1
				c.scanned(_scan_index)
				Sfx.play_at("scan", till_position(), -10.0)
			if _scan_index >= items.size():
				_paying = true
	elif _scan_t >= PAY_SECONDS:
		_scan_t = 0.0
		_scan_index = 0
		_paying = false
		c.pay()
		Sfx.play_at("register", till_position(), -6.0)
		queue.pop_front()
		for j in queue.size():
			queue[j].queue_moved(j)


func is_scanning() -> bool:
	return cashier_present and not queue.is_empty() and queue[0].ready_at_till()
