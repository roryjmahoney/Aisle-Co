class_name BuildController
extends Node3D
## Construction tool: place, move and bulldoze fixtures on the grid.
##
## The ghost glides towards the snapped cell rather than teleporting, rotates
## with a short ease, and shows the footprint plus the aisle cells that must
## stay clear. Validation always goes through Store.check_placement so the
## tool can never create a layout the simulation considers invalid.

signal mode_changed(mode: int)
signal hint_changed(text: String, ok: bool, visible: bool)
signal placed(f: Fixture)

enum Mode { NONE, PLACE, MOVE, BULLDOZE }

const REFUND_RATE := 0.75
const MAX_UNDO := 40

var main: Node3D
var rig: CameraRig
var mode := Mode.NONE
var def: FixtureDef
var rot := 0
var move_uid := -1
var anchor := Vector2i(-999, -999)
var valid := false
var reason := ""

var _ghost: Node3D
var _ghost_body: MeshInstance3D
var _ghost_plate: MeshInstance3D
var _ghost_target := Vector3.ZERO
var _ghost_yaw := 0.0
var _ghost_yaw_target := 0.0
var _hover_uid := -1
var _undo: Array[Dictionary] = []
var _right_press := Vector2.ZERO
var _mouse := Vector2.ZERO
var _plate_mat: StandardMaterial3D


func setup(p_main: Node3D, p_rig: CameraRig) -> void:
	main = p_main
	rig = p_rig
	name = "BuildController"
	_ghost = Node3D.new()
	_ghost.name = "Ghost"
	add_child(_ghost)
	_ghost_body = MeshInstance3D.new()
	_ghost_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.add_child(_ghost_body)
	_ghost_plate = MeshInstance3D.new()
	_ghost_plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.add_child(_ghost_plate)
	_ghost.visible = false


# --- Mode changes ------------------------------------------------------------

func begin_place(d: FixtureDef) -> void:
	cancel(false)
	mode = Mode.PLACE
	def = d
	_prepare_ghost()
	_refresh(true)
	mode_changed.emit(mode)


func begin_move(uid: int) -> void:
	var f: Fixture = Game.store.fixtures.get(uid)
	if f == null:
		return
	cancel(false)
	mode = Mode.MOVE
	move_uid = uid
	def = f.def
	rot = f.rot
	_prepare_ghost()
	var v: FixtureView = main.view_for(uid)
	if v:
		v.visible = false
	_refresh(true)
	mode_changed.emit(mode)


func begin_bulldoze() -> void:
	cancel(false)
	mode = Mode.BULLDOZE
	mode_changed.emit(mode)


func cancel(emit: bool = true) -> void:
	if mode == Mode.MOVE and move_uid != -1:
		var v: FixtureView = main.view_for(move_uid)
		if v:
			v.visible = true
	_set_hover(-1)
	mode = Mode.NONE
	move_uid = -1
	def = null
	_ghost.visible = false
	hint_changed.emit("", true, false)
	if emit:
		mode_changed.emit(mode)


func is_active() -> bool:
	return mode != Mode.NONE


func rotate_ghost(dir: int = 1) -> void:
	if mode != Mode.PLACE and mode != Mode.MOVE:
		return
	rot = posmod(rot + dir, 4)
	_ghost_yaw_target = def.yaw(rot)
	_build_plate()
	_refresh(false)
	Sfx.play("rotate")


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.NONE:
		return
	if event is InputEventMouseMotion:
		_mouse = event.position
		_refresh(false)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_mouse = mb.position
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_commit()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_right_press = mb.position
			elif mb.position.distance_to(_right_press) < 5.0:
				cancel()
	elif event.is_action_pressed(&"rotate_object"):
		rotate_ghost(-1 if Input.is_key_pressed(KEY_SHIFT) else 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"cancel"):
		cancel()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _ghost.visible:
		return
	var k := 1.0 - exp(-22.0 * delta)
	_ghost.position = _ghost.position.lerp(_ghost_target, k)
	_ghost_yaw = lerp_angle(_ghost_yaw, _ghost_yaw_target, 1.0 - exp(-16.0 * delta))
	_ghost_body.rotation.y = _ghost_yaw
	# A gentle hover bob makes the ghost read as "held", not placed.
	_ghost_body.position.y = 0.04 + sin(Time.get_ticks_msec() * 0.004) * 0.012


# --- Core ----------------------------------------------------------------------

func _prepare_ghost() -> void:
	var art := FixtureArt.build(def)
	_ghost_body.mesh = art.mesh
	_ghost_yaw_target = def.yaw(rot)
	_ghost_yaw = _ghost_yaw_target
	_build_plate()
	_ghost.visible = true
	anchor = Vector2i(-999, -999)


func _cursor_anchor() -> Variant:
	var gp: Variant = rig.ground_point_at(_mouse)
	if gp == null:
		return null
	var p: Vector3 = gp
	var s := def.rotated_size(rot)
	return Vector2i(floori(p.x / StoreGrid.CELL - s.x * 0.5 + 0.5), floori(p.z / StoreGrid.CELL - s.y * 0.5 + 0.5))


func _refresh(snap: bool) -> void:
	if mode == Mode.BULLDOZE:
		_update_bulldoze_hover()
		return
	if mode != Mode.PLACE and mode != Mode.MOVE:
		return
	var a: Variant = _cursor_anchor()
	if a == null:
		return
	var na: Vector2i = a
	var changed := na != anchor
	anchor = na
	var ignore := move_uid if mode == Mode.MOVE else -1
	reason = Game.store.check_placement(def, anchor, rot, ignore)
	var cost := def.price_cents if mode == Mode.PLACE else 0
	if reason == "" and cost > Game.economy.cash:
		reason = "Not enough cash"
	var was_valid := valid
	valid = reason == ""
	_ghost_target = def.center_world(anchor, rot) + Vector3(0, Lot.FLOOR_Y, 0)
	if snap:
		_ghost.position = _ghost_target
	if changed or was_valid != valid or snap:
		_ghost_body.material_override = Materials.ghost(valid)
		_build_plate()
		if changed and not snap:
			Sfx.play("tick", -18.0)
	var label := def.display_name
	if mode == Mode.PLACE:
		label += "  ·  " + Fmt.money(def.price_cents, false)
	hint_changed.emit(label if valid else reason, valid, true)


func _commit() -> void:
	match mode:
		Mode.PLACE:
			if not valid:
				Sfx.play("deny")
				Game.say(reason, "warning")
				return
			if not Game.economy.charge(Economy.Kind.BUILD, def.price_cents, "Built %s" % def.display_name):
				Sfx.play("deny")
				return
			var f := Game.store.add(def, anchor, rot)
			_push_undo({"type": "place", "uid": f.uid, "cost": def.price_cents})
			var v: FixtureView = main.view_for(f.uid)
			if v:
				v.play_pop()
			Sfx.play("place")
			placed.emit(f)
			_refresh(false)
		Mode.MOVE:
			if not valid:
				Sfx.play("deny")
				Game.say(reason, "warning")
				return
			var f: Fixture = Game.store.fixtures.get(move_uid)
			_push_undo({"type": "move", "uid": move_uid, "anchor": f.anchor, "rot": f.rot})
			Game.store.move(move_uid, anchor, rot)
			var v: FixtureView = main.view_for(move_uid)
			if v:
				v.visible = true
			Sfx.play("place")
			move_uid = -1
			cancel()
		Mode.BULLDOZE:
			if _hover_uid != -1:
				bulldoze(_hover_uid)


func bulldoze(uid: int) -> bool:
	var f: Fixture = Game.store.fixtures.get(uid)
	if f == null:
		return false
	var err := Game.inventory.clear_fixture(f)
	if err != "":
		Sfx.play("deny")
		Game.say(err, "warning")
		return false
	var products := []
	for s in f.slots:
		products.append(s.product)
	var refund := int(f.def.price_cents * REFUND_RATE)
	_set_hover(-1)
	Game.store.remove(uid)
	Game.economy.credit(Economy.Kind.REFUND, refund, "Sold %s" % f.def.display_name)
	_push_undo({"type": "remove", "uid": uid, "def": f.def.id, "anchor": f.anchor, "rot": f.rot,
			"refund": refund, "products": products})
	Sfx.play("remove")
	Game.say("Sold %s for %s" % [f.def.display_name, Fmt.money(refund, false)], "info")
	return true


# --- Undo --------------------------------------------------------------------

func _push_undo(e: Dictionary) -> void:
	_undo.append(e)
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()


func can_undo() -> bool:
	return not _undo.is_empty()


func undo() -> void:
	if _undo.is_empty():
		Game.say("Nothing to undo", "info")
		return
	var e: Dictionary = _undo.pop_back()
	match e.type:
		"place":
			var f: Fixture = Game.store.fixtures.get(e.uid)
			if f == null:
				return
			var err := Game.inventory.clear_fixture(f)
			if err != "":
				Game.say(err, "warning")
				_undo.append(e)
				return
			Game.store.remove(e.uid)
			Game.economy.credit(Economy.Kind.REFUND, e.cost, "Undid %s" % f.def.display_name)
		"move":
			var f2: Fixture = Game.store.fixtures.get(e.uid)
			if f2 == null:
				return
			var err2 := Game.store.check_placement(f2.def, e.anchor, e.rot, e.uid)
			if err2 != "":
				Game.say("Can't undo: " + err2, "warning")
				return
			Game.store.move(e.uid, e.anchor, e.rot)
		"remove":
			var d: FixtureDef = Game.catalog.fixture(e.def)
			var err3 := Game.store.check_placement(d, e.anchor, e.rot)
			if err3 != "":
				Game.say("Can't undo: " + err3, "warning")
				return
			if not Game.economy.charge(Economy.Kind.BUILD, e.refund, "Rebuilt %s" % d.display_name):
				Game.say("Not enough cash to undo", "warning")
				_undo.append(e)
				return
			var nf := Game.store.add(d, e.anchor, e.rot, e.uid)
			for i in mini(nf.slots.size(), e.products.size()):
				if e.products[i] != &"":
					Game.inventory.assign_slot(nf, i, e.products[i])
	Sfx.play("undo")
	if mode != Mode.NONE:
		_refresh(false)


# --- Bulldoze hover -----------------------------------------------------------

func _update_bulldoze_hover() -> void:
	var gp: Variant = rig.ground_point_at(_mouse)
	var uid := -1
	if gp != null:
		var f := Game.store.fixture_at(StoreGrid.world_to_cell(gp))
		if f:
			uid = f.uid
	_set_hover(uid)
	if uid != -1:
		var f2: Fixture = Game.store.fixtures[uid]
		hint_changed.emit("Sell %s  ·  +%s" % [f2.def.display_name, Fmt.money(int(f2.def.price_cents * REFUND_RATE), false)], true, true)
	else:
		hint_changed.emit("Click a fixture to sell it", true, true)


func _set_hover(uid: int) -> void:
	if uid == _hover_uid:
		return
	var old: FixtureView = main.view_for(_hover_uid) if _hover_uid != -1 else null
	if old:
		old.body.material_overlay = null
	_hover_uid = uid
	var v: FixtureView = main.view_for(uid) if uid != -1 else null
	if v:
		v.body.material_overlay = Materials.danger()


# --- Footprint plate ---------------------------------------------------------

func _build_plate() -> void:
	## Rounded tiles under each footprint cell, plus chevrons on aisle cells.
	var k := MeshKit.new()
	# Marigold = "this is where it goes" (same colour as selection); aisle
	# cells are a lighter outline so the player sees the space to keep clear.
	var col := Color(0.95, 0.70, 0.24, 0.72) if valid else Color(0.89, 0.33, 0.23, 0.72)
	var acc := Color(0.95, 0.70, 0.24, 0.3) if valid else Color(0.89, 0.33, 0.23, 0.3)
	var c := StoreGrid.CELL
	for cell in def.cells_for(Vector2i.ZERO, rot):
		var p := StoreGrid.cell_center(cell) - def.center_world(Vector2i.ZERO, rot)
		k.box(p + Vector3(0, 0.012, 0), Vector3(c - 0.06, 0.01, c - 0.06), col, MeshKit.Ch.PAINT, 0.004)
	for cell in def.access_for(Vector2i.ZERO, rot):
		var p := StoreGrid.cell_center(cell) - def.center_world(Vector2i.ZERO, rot)
		k.box(p + Vector3(0, 0.01, 0), Vector3(c - 0.14, 0.006, c - 0.14), acc, MeshKit.Ch.PAINT, 0.003)
	if _plate_mat == null:
		_plate_mat = StandardMaterial3D.new()
		_plate_mat.vertex_color_use_as_albedo = true
		_plate_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_plate_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_plate.mesh = k.build({MeshKit.Ch.PAINT: _plate_mat})
