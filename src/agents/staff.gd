class_name Staff
extends Walker
## An employee (or the owner). Roles decide which duties they take on:
##   OWNER   — runs a till when shoppers queue, otherwise restocks shelves
##   CASHIER — staffs a till all day
##   STOCKER — carries cases from the stockroom and fills shelves

enum Role { OWNER, CASHIER, STOCKER }
enum S { IDLE, TO_TILL, AT_TILL, TO_STOCK, PICKUP, TO_SHELF, STOCKING, RETURN, WANDER }

const ROLE_NAMES := ["Owner", "Cashier", "Stocker"]
const WAGES := [0, 8000, 7500]
const STATE_TEXT := ["Looking for work", "Heading to a till", "On the till", "Fetching stock", "Picking up a case",
		"Carrying stock to a shelf", "Filling a shelf", "Returning stock", "Taking a breather"]
const NAMES := ["Priya", "Tom", "Marisol", "Jonah", "Aiko", "Bram", "Delia", "Felix", "Greta", "Hugo",
		"Ines", "Joel", "Kemi", "Leo", "Maren", "Nico", "Olu", "Petra", "Rafi", "Saoirse"]

var role: int = Role.STOCKER
var display_name := ""
var wage := 0
var skill := 1.0
var look: Dictionary
var state := S.IDLE
var lane: CheckoutLane
var task: Dictionary = {}
var carry_pid: StringName = &""
var carry_n := 0
var hired_day := 1
var manager: Node
var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_id: int, p_role: int, p_name: String, seed_value: int) -> void:
	id = p_id
	role = p_role
	display_name = p_name
	wage = WAGES[role]
	_rng.seed = seed_value
	look = PersonArt.staff_look(_rng)
	if role == Role.OWNER:
		look.shirt = Palette.TOMATO
	speed = 1.45
	skill = 1.0 if role != Role.CASHIER else 1.25


func carrying() -> StringName:
	return carry_pid if carry_n > 0 else &""


func status_text() -> String:
	return STATE_TEXT[state]


func step(dt: float) -> void:
	if stuck:
		stuck = false
		if state == S.TO_TILL:
			_release_lane()
		if carry_n > 0:
			# Nowhere to go with the case: it goes back on the books in the
			# stockroom rather than vanishing.
			Game.inventory.return_transit(carry_pid, carry_n)
			carry_pid = &""
			carry_n = 0
		_abort_task()
		state = S.IDLE
		return
	match state:
		S.IDLE:
			prev_pos = pos
			anim = Anim.IDLE
			_choose()
		S.WANDER:
			if step_move(dt):
				_timer -= dt
				if _timer <= 0.0:
					state = S.IDLE
			if _wants_till() or (_can_stock() and manager.has_task_for(self)):
				stop()
				state = S.IDLE
		S.TO_TILL:
			if lane == null or not Game.store.fixtures.has(lane.fixture.uid):
				_release_lane()
				state = S.IDLE
				return
			if step_move(dt):
				state = S.AT_TILL
				lane.cashier_present = true
				face(lane.till_position())
		S.AT_TILL:
			prev_pos = pos
			if lane == null:
				state = S.IDLE
				return
			face(lane.till_position())
			anim = Anim.SCAN if lane.is_scanning() else Anim.IDLE
			if role == Role.OWNER and lane.queue.is_empty() and lane.idle_time > 5.0:
				if manager.has_task_for(self) or manager.idle_cashier_available():
					_release_lane()
					state = S.IDLE
		S.TO_STOCK:
			if step_move(dt):
				state = S.PICKUP
				_timer = 0.8
				anim = Anim.REACH
		S.PICKUP:
			prev_pos = pos
			_timer -= dt
			if _timer <= 0.0:
				_pick_up()
		S.TO_SHELF:
			if not _task_valid():
				_go_return()
				return
			if step_move(dt):
				var f: Fixture = Game.store.fixtures[task.uid]
				face(f.world_center())
				state = S.STOCKING
				anim = Anim.REACH
				_timer = 0.0
		S.STOCKING:
			prev_pos = pos
			if not _task_valid():
				_go_return()
				return
			_timer -= dt
			if _timer <= 0.0:
				_timer = 0.16
				var f2: Fixture = Game.store.fixtures[task.uid]
				var n := Game.inventory.put_on_shelf(f2, task.slot, carry_pid, 2)
				carry_n -= n
				if n > 0:
					Sfx.play_at("pick", pos + Vector3(0, 1, 0), -20.0, 0.9)
				var s: Dictionary = f2.slots[task.slot]
				if carry_n <= 0 or s.qty >= s.cap or n == 0:
					manager.release_task(task)
					task = {}
					if carry_n > 0:
						_go_return()
					else:
						carry_pid = &""
						carry_n = 0
						state = S.IDLE
		S.RETURN:
			if step_move(dt):
				Game.inventory.return_transit(carry_pid, carry_n)
				carry_pid = &""
				carry_n = 0
				state = S.IDLE


func _choose() -> void:
	if role == Role.CASHIER or _wants_till():
		var l: CheckoutLane = manager.lane_needing_cashier(self)
		if l != null:
			_claim_lane(l)
			return
	if _can_stock():
		var t: Dictionary = manager.claim_task(self)
		if not t.is_empty():
			task = t
			var spot: Vector2i = manager.stockroom_spot(pos)
			if walk_to_cell(spot, 0.15):
				state = S.TO_STOCK
				return
			manager.release_task(task)
			task = {}
	# Nothing to do: drift somewhere sensible and look busy.
	state = S.WANDER
	_timer = _rng.randf_range(2.0, 4.0)
	var home := Vector2i(_rng.randi_range(Lot.LEFT_X + 2, Lot.RIGHT_X - 3), _rng.randi_range(Lot.BACK_Z + 2, Lot.PARTITION_Z - 2))
	if role == Role.CASHIER or role == Role.OWNER:
		var l2: CheckoutLane = manager.any_lane()
		if l2:
			home = StoreGrid.world_to_cell(l2.cashier_spot()) + Vector2i(-1, 0)
	if not walk_to_cell(home, 0.2):
		state = S.IDLE


func _wants_till() -> bool:
	if role == Role.CASHIER:
		return true
	if role != Role.OWNER or carry_n > 0:
		return false
	return manager.lane_needing_cashier(self) != null


func _can_stock() -> bool:
	return role == Role.OWNER or role == Role.STOCKER


func _claim_lane(l: CheckoutLane) -> void:
	lane = l
	l.cashier = self
	l.cashier_present = false
	if walk_to_point(l.cashier_spot()):
		state = S.TO_TILL
	else:
		_release_lane()
		state = S.WANDER
		_timer = 2.0


func _release_lane() -> void:
	if lane and lane.cashier == self:
		lane.cashier = null
		lane.cashier_present = false
	lane = null


func lane_removed() -> void:
	lane = null
	if state == S.TO_TILL or state == S.AT_TILL:
		state = S.IDLE


func _task_valid() -> bool:
	if task.is_empty() or not Game.store.fixtures.has(task.uid):
		return false
	var f: Fixture = Game.store.fixtures[task.uid]
	return task.slot < f.slots.size() and f.slots[task.slot].product == carry_pid


func _pick_up() -> void:
	if task.is_empty() or not Game.store.fixtures.has(task.uid):
		_abort_task()
		return
	var f: Fixture = Game.store.fixtures[task.uid]
	var s: Dictionary = f.slots[task.slot]
	var p := Game.catalog.product(s.product)
	if p == null:
		_abort_task()
		return
	var want := mini(p.case_size, s.cap - s.qty)
	var got := Game.inventory.take_for_restock(s.product, want)
	if got <= 0:
		_abort_task()
		return
	carry_pid = s.product
	carry_n = got
	var target: Vector2i = manager.slot_stand_cell(f, task.slot, cell())
	if target.x < 0 or not walk_to_cell(target, 0.1):
		_go_return()
		return
	state = S.TO_SHELF
	anim = Anim.CARRY


func _abort_task() -> void:
	if not task.is_empty():
		manager.release_task(task)
	task = {}
	state = S.IDLE


func _go_return() -> void:
	if not task.is_empty():
		manager.release_task(task)
		task = {}
	if carry_n <= 0:
		state = S.IDLE
		return
	state = S.RETURN
	if not walk_to_cell(manager.stockroom_spot(pos), 0.15):
		# Can't reach the stockroom (layout changed): put it back on arrival
		# wherever we are — the goods are never lost.
		Game.inventory.return_transit(carry_pid, carry_n)
		carry_pid = &""
		carry_n = 0
		state = S.IDLE
	else:
		anim = Anim.CARRY


func step_move(dt: float) -> bool:
	var arrived := super.step_move(dt)
	if carry_n > 0 and not arrived:
		anim = Anim.CARRY
	return arrived


func dismiss() -> void:
	## Leaving the job: hand back any stock and the till.
	_release_lane()
	if not task.is_empty():
		manager.release_task(task)
		task = {}
	if carry_n > 0:
		Game.inventory.return_transit(carry_pid, carry_n)
		carry_pid = &""
		carry_n = 0
