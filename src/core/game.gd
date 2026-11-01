extends Node
## The one autoload. Owns the simulation systems and drives them with a
## fixed-step loop, independent of frame rate and of the chosen game speed:
## speeding up runs *more* identical steps, never bigger ones, so customers
## and finances behave exactly the same at 1x and 4x.

signal tick(dt: float)
signal speed_changed(speed: int)
signal notify(text: String, kind: String)
signal selection_changed(sel: Variant)
signal day_report_ready(report: Dictionary)

const SIM_HZ := 30.0
const STEP := 1.0 / SIM_HZ
const SPEEDS := [0, 1, 2, 4]
const MAX_STEPS_PER_FRAME := 24

var catalog := Catalog.new()
var grid: StoreGrid
var store := Store.new()
var inventory := Inventory.new()
var economy := Economy.new()
var clock := SimClock.new()
var settings := Settings.new()

## Registered by the main scene.
var customers: Node
var staff: Node
var world: Node

var speed := 1
var _speed_before_pause := 1
var _acc := 0.0
## Fraction of a step elapsed since the last tick, for render interpolation.
var alpha := 0.0
var sim_time := 0.0
var reputation := 0.5
var modal_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()
	settings.load_settings()
	catalog.load_all()
	new_world()


func new_world() -> void:
	grid = StoreGrid.new(Lot.W, Lot.D)
	Lot.apply(grid)
	grid.build_nav()
	store = Store.new()
	store.setup(grid, catalog)
	economy = Economy.new()
	clock = SimClock.new()
	inventory = Inventory.new()
	inventory.setup(catalog, store, economy, clock)
	reputation = 0.5
	speed = 1
	_acc = 0.0
	clock.phase_changed.connect(_on_phase)


func _on_phase(p: int) -> void:
	match p:
		SimClock.Phase.OPEN:
			say("Doors open — welcome in!", "positive")
		SimClock.Phase.CLOSING:
			say("Closing time. Serving the last shoppers…", "info")
		SimClock.Phase.CLOSED:
			_close_day()


func _close_day() -> void:
	var wages: int = staff.wages_per_day() if staff else 0
	var r := economy.close_day(store.upkeep(), wages)
	r["reputation"] = reputation
	var err := inventory.audit()
	if err != "":
		push_error("Inventory audit failed at close: " + err)
	day_report_ready.emit(r)


func start_next_day() -> void:
	clock.start_next_day()
	economy.start_day(clock.day)
	if settings.get_value("autosave"):
		var err := SaveManager.save("slot1")
		if err != "":
			say(err, "warning")


func _process(delta: float) -> void:
	if speed <= 0 or modal_open:
		alpha = 0.0
		return
	_acc += minf(delta, 0.1) * speed
	var steps := 0
	while _acc >= STEP and steps < MAX_STEPS_PER_FRAME:
		_acc -= STEP
		steps += 1
		_step(STEP)
	if steps >= MAX_STEPS_PER_FRAME:
		_acc = 0.0
	alpha = clampf(_acc / STEP, 0.0, 1.0)


func _step(dt: float) -> void:
	sim_time += dt
	clock.step(dt)
	inventory.step(dt)
	tick.emit(dt)


# --- Speed -------------------------------------------------------------------

func set_speed(s: int) -> void:
	s = clampi(s, 0, 4)
	if s == speed:
		return
	if s == 0:
		_speed_before_pause = maxi(speed, 1)
	speed = s
	speed_changed.emit(speed)


func toggle_pause() -> void:
	set_speed(_speed_before_pause if speed == 0 else 0)


func say(text: String, kind: String = "info") -> void:
	notify.emit(text, kind)


# --- Input map ----------------------------------------------------------------

func _register_input() -> void:
	var keys := {
		&"cam_forward": [KEY_W, KEY_UP], &"cam_back": [KEY_S, KEY_DOWN],
		&"cam_left": [KEY_A, KEY_LEFT], &"cam_right": [KEY_D, KEY_RIGHT],
		&"cam_rotate_left": [KEY_Q], &"cam_rotate_right": [KEY_E],
		&"focus_selection": [KEY_F], &"toggle_top_down": [KEY_T],
		&"rotate_object": [KEY_R], &"cancel": [KEY_ESCAPE],
		&"toggle_build": [KEY_B], &"toggle_walls": [KEY_V], &"bulldoze": [KEY_X],
		&"pause": [KEY_SPACE], &"speed_1": [KEY_1], &"speed_2": [KEY_2], &"speed_3": [KEY_3],
		&"open_orders": [KEY_O], &"open_staff": [KEY_H], &"open_stock": [KEY_I],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action(&"undo"):
		InputMap.add_action(&"undo")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_Z
		ev.ctrl_pressed = true
		InputMap.action_add_event(&"undo", ev)
