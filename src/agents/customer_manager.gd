class_name CustomerManager
extends Node3D
## Spawns shoppers according to time of day and the shop's pull, runs their
## simulation each fixed step, owns the checkout lanes, and closes the day
## once the last shopper has gone home.

signal customer_left(c: Customer)

const MAX_CUSTOMERS := 80
## Shoppers per in-game hour at neutral reputation, by hour of day.
const HOURLY := {8: 4.0, 9: 5.5, 10: 6.5, 11: 7.5, 12: 10.0, 13: 9.0, 14: 6.5, 15: 6.5, 16: 8.0, 17: 10.5, 18: 10.0, 19: 6.0}

var customers: Array[Customer] = []
var lanes: Dictionary = {}       # fixture uid -> CheckoutLane
var _next_id := 1
var _spawn_acc := 0.0
var _rng := RandomNumberGenerator.new()
var _views_root: Node3D


func _ready() -> void:
	name = "Customers"
	Game.customers = self
	_rng.seed = 1234
	_views_root = Node3D.new()
	_views_root.name = "People"
	add_child(_views_root)
	Game.tick.connect(_tick)
	Game.store.fixture_added.connect(_on_fixture_added)
	Game.store.fixture_removed.connect(_on_fixture_removed)
	Game.grid.layout_changed.connect(_on_layout_changed)
	for f in Game.store.fixtures.values():
		_on_fixture_added(f)
	var door: EntranceDoor = Game.world.world_info.entrance
	if door:
		door.opened.connect(func(): Sfx.play_at("door_chime", door.global_position + Vector3(0, 2, 0), -8.0))


func _on_fixture_added(f: Fixture) -> void:
	if f.def.is_checkout:
		if lanes.has(f.uid):
			lanes[f.uid].refresh_spots()
		else:
			lanes[f.uid] = CheckoutLane.new(f)


func _on_fixture_removed(f: Fixture) -> void:
	if Game.store.fixtures.has(f.uid):
		return   # it was a move
	if lanes.has(f.uid):
		var lane: CheckoutLane = lanes[f.uid]
		lanes.erase(f.uid)
		for c in lane.queue.duplicate():
			c.lane = null
			c._go_to_checkout()
		if lane.cashier:
			lane.cashier.lane_removed()


func _on_layout_changed() -> void:
	for l in lanes.values():
		l.refresh_spots()


func expected_per_hour(hour: int) -> float:
	var base: float = HOURLY.get(hour, 0.0)
	var rep := 0.55 + Game.reputation * 0.9
	var appeal := 1.0 + minf(Game.store.appeal(), 30) * 0.012
	var carried := Game.store.carried_products().size()
	var variety := 0.4 + 0.6 * clampf(float(carried) / maxf(Game.catalog.products.size(), 1), 0.0, 1.0)
	return base * rep * appeal * variety


func _tick(dt: float) -> void:
	var clock := Game.clock
	if clock.is_open() and customers.size() < MAX_CUSTOMERS:
		var hour := int(clock.minute / 60.0)
		var per_minute := expected_per_hour(hour) / 60.0
		_spawn_acc += per_minute * dt * SimClock.MINUTES_PER_SECOND
		while _spawn_acc >= 1.0:
			_spawn_acc -= 1.0
			# Small random gaps so arrivals don't look metronomic.
			if _rng.randf() < 0.92:
				spawn()
	for l in lanes.values():
		l.step(dt)
	for c in customers.duplicate():
		c.step(dt)
		if c.state == Customer.S.GONE:
			_retire(c)
	if clock.phase == SimClock.Phase.CLOSING and customers.is_empty():
		clock.finish_closing()


func spawn() -> Customer:
	var c := Customer.new()
	var from_left := _rng.randf() < 0.5
	var spawn_cell := Lot.SPAWN_LEFT if from_left else Lot.SPAWN_RIGHT
	# Most passers-by carry on in the direction they were walking.
	var other := Lot.SPAWN_RIGHT if from_left else Lot.SPAWN_LEFT
	var exit_cell := other if _rng.randf() < 0.65 else spawn_cell
	c.setup(_next_id, _rng.randi(), spawn_cell, exit_cell)
	_next_id += 1
	customers.append(c)
	var v := PersonView.new()
	_views_root.add_child(v)
	v.setup(c, c.look, true)
	c.view = v
	return c


func _retire(c: Customer) -> void:
	customers.erase(c)
	if c.lane:
		c.lane.leave(c)
	if c._entered:
		var r: Dictionary = Game.economy.report
		r.satisfaction_sum += c.satisfaction
		if not c.paid:
			r.lost += 1
		Game.reputation = clampf(lerpf(Game.reputation, c.satisfaction, 0.008), 0.05, 1.0)
	customer_left.emit(c)
	if c.view:
		c.view.queue_free()
		c.view = null


func clear_all() -> void:
	for c in customers.duplicate():
		if c.basket_count() > 0:
			Game.inventory.return_basket(c.basket)
			c.basket.clear()
		if c.lane:
			c.lane.leave(c)
		if c.view:
			c.view.queue_free()
	customers.clear()


func pick(screen_pos: Vector2, cam: Camera3D) -> Customer:
	var best: Customer = null
	var best_d := 28.0
	for c in customers:
		if c.view == null:
			continue
		var head: Vector3 = c.view.global_position + Vector3(0, 1.1, 0)
		if cam.is_position_behind(head):
			continue
		var sp := cam.unproject_position(head)
		var d := sp.distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = c
	return best


func in_store_count() -> int:
	var n := 0
	for c in customers:
		if c._entered and c.state != Customer.S.EXIT:
			n += 1
	return n
