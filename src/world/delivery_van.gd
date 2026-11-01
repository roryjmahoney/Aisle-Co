class_name DeliveryVan
extends Node3D
## Visualises wholesale deliveries. Follows the Inventory delivery states:
## ARRIVING → drives along the street and up the side lane; UNLOADING →
## parked with rear doors open and the shutter up; DONE → drives away.

var shutter: LoadingShutter
var _body: MeshInstance3D
var _doors: Array[Node3D] = []
var _curve := Curve3D.new()
var _t := 0.0           # 0 at street edge, 1 parked
var _target := 0.0
var _speed := 0.0
var _door_open := 0.0
var _active_orders := 0


func setup(p_shutter: LoadingShutter) -> void:
	name = "DeliveryVan"
	shutter = p_shutter
	_body = MeshInstance3D.new()
	_body.mesh = _van_mesh()
	add_child(_body)
	# Sliding side door on the kerb side (local -X faces the shop when parked
	# nose-in), so unloading happens right at the stockroom shutter.
	var dk := MeshKit.new()
	dk.box(Vector3(0, 0.95, 0), Vector3(0.04, 1.2, 1.05), Palette.SNOW, MeshKit.Ch.SATIN, 0.02)
	dk.box(Vector3(-0.022, 1.3, 0.25), Vector3(0.01, 0.3, 0.45), Color(0.28, 0.38, 0.42), MeshKit.Ch.GLOSS)
	dk.box(Vector3(-0.03, 0.95, 0.42), Vector3(0.02, 0.05, 0.14), Palette.STEEL, MeshKit.Ch.METAL)
	var slider := Node3D.new()
	slider.position = Vector3(-0.83, 0.0, -0.1)
	add_child(slider)
	var m := MeshInstance3D.new()
	m.mesh = dk.build()
	slider.add_child(m)
	slider.set_meta("side", 1.0)
	_doors.append(slider)
	# Route: in along the far lane from the right edge, swing into the side
	# lane and reverse-free nose-in to the loading door.
	var y := 0.0
	_curve.add_point(Vector3(Lot.m(Lot.W) + 0.5, y, 16.0), Vector3.ZERO, Vector3(-3, 0, 0))
	_curve.add_point(Vector3(9.0, y, 16.0), Vector3(3, 0, 0), Vector3(-3, 0, 0))
	_curve.add_point(Vector3(2.0, y, 12.5), Vector3(0, 0, 2.5), Vector3(0, 0, -2.5))
	_curve.add_point(Vector3(2.0, y, 4.6), Vector3(0, 0, 2.0), Vector3.ZERO)
	_curve.bake_interval = 0.1
	visible = false
	Game.inventory.delivery_state.connect(_on_state)


func _on_state(o: Dictionary) -> void:
	match o.state:
		Inventory.DeliveryState.ARRIVING:
			_active_orders += 1
			_target = 1.0
			visible = true
			Sfx.play_at("delivery", global_position + Vector3(0, 1, 0), -6.0)
		Inventory.DeliveryState.UNLOADING:
			shutter.set_open(true)
			Sfx.play_at("shutter", shutter.global_position, -8.0)
		Inventory.DeliveryState.DONE:
			_active_orders = maxi(_active_orders - 1, 0)
			Game.say("Delivery unloaded into the stockroom", "truck")
			if _active_orders == 0:
				_target = 0.0
				shutter.set_open(false)


func _process(delta: float) -> void:
	if not visible:
		return
	# Ease along the route; the sim's arrival window is short, so the van
	# moves at a steady pace and simply waits if it gets there early.
	var dir := signf(_target - _t)
	_speed = move_toward(_speed, 0.32 * dir, delta * 0.4)
	if dir == 0.0:
		_speed = 0.0
	var new_t := clampf(_t + _speed * delta, 0.0, 1.0)
	# Slow down for the last metres.
	if dir > 0.0 and _t > 0.85:
		new_t = move_toward(_t, 1.0, delta * 0.12)
	_t = new_t
	var length := _curve.get_baked_length()
	var d := _t * length
	var p := _curve.sample_baked(d)
	var ahead := _curve.sample_baked(minf(d + 0.6, length)) if d < length - 0.05 else p + (p - _curve.sample_baked(d - 0.6))
	position = p
	if ahead.distance_to(p) > 0.01:
		look_at(Vector3(ahead.x, p.y, ahead.z), Vector3.UP)
		rotate_object_local(Vector3.UP, PI)
	# Rear doors open while parked.
	var parked := _t > 0.995 and _target > 0.5
	_door_open = move_toward(_door_open, 1.0 if parked else 0.0, delta * 1.6)
	var e := _door_open * _door_open * (3.0 - 2.0 * _door_open)
	for h in _doors:
		h.position = Vector3(-0.83 - 0.06 * minf(e * 4.0, 1.0), 0.0, -0.1 - 1.0 * e)
	if _t <= 0.0 and _target <= 0.0:
		visible = false


func _van_mesh() -> ArrayMesh:
	# A compact high-roof delivery van, front at +Z.
	var k := MeshKit.new()
	var body := Palette.GROCER
	var C := MeshKit.Ch
	k.box(Vector3(0, 1.05, -0.55), Vector3(1.62, 1.55, 3.2), Palette.SNOW, C.SATIN, 0.08, 2)
	k.box(Vector3(0, 0.82, 1.35), Vector3(1.6, 1.1, 0.95), body, C.SATIN, 0.1, 2)
	k.box(Vector3(0, 0.4, -0.2), Vector3(1.66, 0.28, 4.3), body, C.SATIN, 0.06, 2)
	# Windscreen and side windows.
	k.push(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-22)), Vector3(0, 1.22, 1.72)))
	k.box(Vector3.ZERO, Vector3(1.4, 0.55, 0.04), Color(0.28, 0.38, 0.42), C.GLOSS, 0.02)
	k.pop()
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 0.805, 1.12, 1.2), Vector3(0.02, 0.4, 0.6), Color(0.28, 0.38, 0.42), C.GLOSS)
		# Brand stripe along the side.
		k.box(Vector3(sx * 0.815, 1.02, -0.55), Vector3(0.012, 0.16, 3.0), Palette.MARIGOLD, C.SATIN)
		# Wheels with hubcaps.
		for z in [1.2, -1.45]:
			k.push(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(sx * 0.72, 0.34, z)))
			k.cylinder(Vector3(0, -0.13, 0), 0.34, 0.26, Palette.RUBBER, C.PAINT, 16, 0.05)
			k.cylinder(Vector3(0, -0.135 if sx < 0 else 0.13, 0), 0.17, 0.006, Palette.STEEL, C.METAL, 12)
			k.pop()
	# Lights and bumper.
	for sx in [-0.6, 0.6]:
		k.box(Vector3(sx, 0.72, 1.83), Vector3(0.22, 0.12, 0.03), Palette.LAMP_WARM, C.EMIT, 0.02)
		k.box(Vector3(sx, 0.75, -2.17), Vector3(0.14, 0.2, 0.03), Palette.TOMATO, C.EMIT, 0.02)
	k.box(Vector3(0, 0.38, 1.88), Vector3(1.6, 0.16, 0.1), Palette.INK, C.SATIN, 0.04)
	k.box(Vector3(0, 0.38, -2.2), Vector3(1.6, 0.16, 0.1), Palette.INK, C.SATIN, 0.04)
	return k.build()
