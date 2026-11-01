class_name SelectionController
extends Node
## Hover and click selection of fixtures and people when not building.

var main: Node3D
var rig: CameraRig
var build: BuildController
var selected: Variant = null      # Fixture, Customer or Staff
var _hover: Variant = null
var _press_pos := Vector2.ZERO
var _pressed := false


func setup(p_main: Node3D, p_rig: CameraRig, p_build: BuildController) -> void:
	main = p_main
	rig = p_rig
	build = p_build
	name = "Selection"


func _unhandled_input(event: InputEvent) -> void:
	if build.is_active():
		_set_hover(null)
		return
	if event is InputEventMouseMotion:
		_set_hover(_pick(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_press_pos = event.position
		elif _pressed:
			_pressed = false
			if event.position.distance_to(_press_pos) < 6.0:
				select(_pick(event.position))
	elif event.is_action_pressed(&"focus_selection"):
		focus()
	elif event.is_action_pressed(&"cancel") and selected != null:
		select(null)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Drop selections whose object has gone (fixture sold, shopper left).
	if selected is Fixture and not Game.store.fixtures.has(selected.uid):
		select(null)
	elif selected is Customer and selected.state == Customer.S.GONE:
		select(null)
	elif selected is Staff and not Game.staff.staff.has(selected):
		select(null)


func _pick(screen: Vector2) -> Variant:
	var person: Variant = Game.customers.pick(screen, rig.camera)
	if person == null:
		var best: Staff = null
		var best_d := 28.0
		for s in Game.staff.staff:
			if s.view == null:
				continue
			var head: Vector3 = s.view.global_position + Vector3(0, 1.1, 0)
			if rig.camera.is_position_behind(head):
				continue
			var d := rig.camera.unproject_position(head).distance_to(screen)
			if d < best_d:
				best_d = d
				best = s
		person = best
	if person != null:
		return person
	var gp: Variant = rig.ground_point_at(screen)
	if gp == null:
		return null
	# Ray-march a little above the floor so tall fixtures pick where they look.
	var origin := rig.camera.project_ray_origin(screen)
	var dir := rig.camera.project_ray_normal(screen)
	for h in [1.6, 1.0, 0.5, 0.0]:
		var t: float = (Lot.FLOOR_Y + h - origin.y) / dir.y if absf(dir.y) > 1e-4 else -1.0
		if t > 0.0:
			var f := Game.store.fixture_at(StoreGrid.world_to_cell(origin + dir * t))
			if f and f.def.height >= h:
				return f
	return null


func _outline(obj: Variant, on: bool, strong: bool) -> void:
	if obj is Fixture:
		var v: FixtureView = main.view_for(obj.uid)
		if v:
			v.body.material_overlay = (Materials.highlight() if strong else Materials.hover()) if on else null
	elif obj is Walker and obj.view:
		obj.view.body.material_overlay = (Materials.highlight() if strong else Materials.hover()) if on else null


func _set_hover(obj: Variant) -> void:
	if obj == _hover:
		return
	if _hover != null and _hover != selected:
		_outline(_hover, false, false)
	_hover = obj
	if _hover != null and _hover != selected:
		_outline(_hover, true, false)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if obj != null else Input.CURSOR_ARROW)


func select(obj: Variant) -> void:
	if obj == selected:
		return
	if selected != null:
		_outline(selected, false, true)
	selected = obj
	if selected != null:
		_outline(selected, true, true)
		Sfx.play("ui_click", -6.0)
	Game.selection_changed.emit(selected)


func focus() -> void:
	if selected is Fixture:
		rig.focus_on(selected.world_center(), 10.0)
	elif selected is Walker:
		rig.focus_on(selected.pos, 8.0)
