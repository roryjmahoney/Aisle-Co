extends Node3D
## Root of the game scene. Assembles the world, camera and UI, and keeps the
## 3D views in sync with the simulation's store layout.

var rig: CameraRig
var atmosphere: Atmosphere
var world_info: Dictionary
var fixtures_root: Node3D
var views: Dictionary = {}   # uid -> FixtureView
var wall_mode := 0           # 0 auto, 1 always up, 2 always cut
var build_active := false
var customers: CustomerManager
var staff: StaffManager
var build: BuildController
var selection: SelectionController
var ui: GameUI
var van: DeliveryVan


func _ready() -> void:
	Game.world = self
	atmosphere = Atmosphere.new()
	atmosphere.setup(self)
	world_info = WorldBuilder.build(self, Game.grid)
	atmosphere.night_lights = world_info.night_lights
	atmosphere.interior_lights = world_info.interior_lights
	atmosphere.apply_settings(Game.settings)

	fixtures_root = Node3D.new()
	fixtures_root.name = "Fixtures"
	add_child(fixtures_root)
	Game.store.fixture_added.connect(_on_fixture_added)
	Game.store.fixture_removed.connect(_on_fixture_removed)
	Game.store.prices_changed.connect(_on_prices_changed)
	Game.inventory.stockroom_changed.connect(_refresh_racks)

	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.bounds = Rect2(1.0, 1.0, Lot.m(Lot.W) - 2.0, Lot.m(Lot.D) - 2.0)
	rig.ground_y = Lot.FLOOR_Y
	rig.snap_to(Vector3(10.2, Lot.FLOOR_Y, 7.4), -24.0, 44.0, 21.0)

	Sfx.init(self)
	customers = CustomerManager.new()
	add_child(customers)
	staff = StaffManager.new()
	add_child(staff)
	StarterStore.populate()
	staff.ensure_owner()
	van = DeliveryVan.new()
	add_child(van)
	van.setup(world_info.shutter)

	build = BuildController.new()
	add_child(build)
	build.setup(self, rig)
	selection = SelectionController.new()
	add_child(selection)
	selection.setup(self, rig, build)
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	ui = GameUI.new()
	ui.setup(self, build, selection)
	layer.add_child(ui)

	Game.clock.phase_changed.connect(func(_p): _update_open_sign())
	_update_open_sign()
	Game.say("Welcome to your corner shop. Press Open doors when you're ready.", "info")

	var cap_args := Capture.parse_args()
	if not cap_args.is_empty():
		var cap := Capture.new()
		add_child(cap)
		cap.run(self, cap_args)


func _process(_delta: float) -> void:
	_update_cutaway()


func _update_cutaway() -> void:
	var cam_pos := rig.camera.global_position
	var near := rig.distance < 25.0 or build_active
	for w in world_info.walls:
		var run: WallRun = w
		var cut := false
		match wall_mode:
			0:
				var center := Vector3(Lot.m(Lot.LEFT_X + Lot.RIGHT_X) * 0.5, 0, Lot.m(Lot.BACK_Z + Lot.FRONT_Z) * 0.5)
				var p := center
				match run.side:
					"front": p.z = Lot.m(Lot.FRONT_Z)
					"back": p.z = Lot.m(Lot.BACK_Z)
					"left": p.x = Lot.m(Lot.LEFT_X)
					"right": p.x = Lot.m(Lot.RIGHT_X)
					"partition": p.z = Lot.m(Lot.PARTITION_Z)
				var to_cam := cam_pos - p
				to_cam.y = 0.0
				cut = near and to_cam.normalized().dot(run.outward) > 0.15
			1:
				cut = false
			2:
				cut = true
		if cut != run.cut:
			run.set_cut(cut)
			if run.side == "front" and world_info.street_occluders:
				world_info.street_occluders.visible = not cut


func _update_open_sign() -> void:
	var open := Game.clock.phase == SimClock.Phase.OPEN
	for l in world_info.open_sign:
		l.text = "OPEN" if open else "CLOSED"
		# Lit neon-style when trading; dull paint when shut.
		l.modulate = Color(1.6, 1.15, 0.45) if open else Color(0.55, 0.6, 0.58)
		l.font_size = 120 if open else 82


func cycle_wall_mode() -> String:
	wall_mode = (wall_mode + 1) % 3
	return ["Walls: automatic", "Walls: up", "Walls: cut away"][wall_mode]


# --- Fixture views -----------------------------------------------------------

func _on_fixture_added(f: Fixture) -> void:
	if views.has(f.uid):
		views[f.uid].relocate()
		return
	var v := FixtureView.new()
	fixtures_root.add_child(v)
	v.setup(f)
	views[f.uid] = v
	if f.def.storage_cases > 0:
		_refresh_racks()


func _on_fixture_removed(f: Fixture) -> void:
	# A move emits removed+added for the same uid; keep the view in that case.
	if Game.store.fixtures.has(f.uid):
		return
	var v: FixtureView = views.get(f.uid)
	if v:
		v.queue_free()
		views.erase(f.uid)
	if f.def.storage_cases > 0:
		_refresh_racks()


func _on_prices_changed() -> void:
	for v in views.values():
		v.refresh_prices()


func _refresh_racks() -> void:
	## Distribute stockroom cases over the racks, product by product, so what
	## you see in the stockroom matches the inventory panel.
	var racks: Array = []
	for v in views.values():
		if v.fixture.def.storage_cases > 0:
			racks.append(v)
	racks.sort_custom(func(a, b): return a.fixture.uid < b.fixture.uid)
	var queue: Array = []
	for pid in Game.catalog.product_order:
		var n := Game.inventory.cases_of(pid, Game.inventory.units(pid))
		if n > 0:
			queue.append([pid, n])
	for r in racks:
		var space: int = r.fixture.def.storage_cases
		var alloc := {}
		while space > 0 and not queue.is_empty():
			var take: int = mini(space, queue[0][1])
			alloc[queue[0][0]] = alloc.get(queue[0][0], 0) + take
			queue[0][1] -= take
			space -= take
			if queue[0][1] <= 0:
				queue.pop_front()
		r.refresh_cases(alloc)


func view_for(uid: int) -> FixtureView:
	return views.get(uid)
