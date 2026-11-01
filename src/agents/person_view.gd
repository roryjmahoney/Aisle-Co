class_name PersonView
extends Node3D
## Draws and animates one person. Reads the agent's simulated position each
## frame (interpolated between fixed simulation steps) and derives a walk
## cycle from distance actually travelled, so feet never skate.

enum Anim { IDLE, WALK, BROWSE, REACH, QUEUE, SCAN, CARRY }

var agent: RefCounted   # anything with pos, prev_pos, face_dir, anim, basket_items
var skel: Skeleton3D
var body: MeshInstance3D
var basket: Node3D
var _basket_items: Node3D
var _carry_box: MeshInstance3D
var _phase := 0.0
var _walk_amt := 0.0
var _yaw := 0.0
var _reach := 0.0
var _idle_t := 0.0
var _rng := RandomNumberGenerator.new()
var _shown_items := -1
var _height := 1.0
var _highlight := false


func setup(p_agent: RefCounted, look: Dictionary, with_basket: bool) -> void:
	agent = p_agent
	_rng.randomize()
	_idle_t = _rng.randf() * 10.0
	_height = look.height
	skel = PersonArt.skeleton()
	skel.scale = Vector3.ONE * look.height
	add_child(skel)
	body = MeshInstance3D.new()
	body.mesh = PersonArt.mesh(look)
	skel.add_child(body)
	body.skeleton = NodePath("..")
	if with_basket:
		var att := BoneAttachment3D.new()
		att.bone_name = "arm_r"
		skel.add_child(att)
		basket = Node3D.new()
		# Hang from the right hand: hand is ~0.41 m below the shoulder joint.
		basket.position = Vector3(-0.04, -0.4, 0.02)
		att.add_child(basket)
		var bm := MeshInstance3D.new()
		bm.mesh = PersonArt.basket_mesh()
		bm.position = Vector3(0, -0.16, 0)
		basket.add_child(bm)
		_basket_items = Node3D.new()
		_basket_items.position = Vector3(0, -0.15, 0)
		basket.add_child(_basket_items)
	var carry_att := BoneAttachment3D.new()
	carry_att.bone_name = "chest"
	skel.add_child(carry_att)
	_carry_box = MeshInstance3D.new()
	_carry_box.position = Vector3(0, 0.02, 0.26)
	_carry_box.visible = false
	carry_att.add_child(_carry_box)
	position = agent.pos
	_yaw = atan2(agent.face_dir.x, agent.face_dir.z)


func set_highlight(on: bool) -> void:
	if _highlight == on:
		return
	_highlight = on
	body.material_overlay = Materials.highlight() if on else null


func _process(delta: float) -> void:
	if agent == null:
		return
	var a: float = Game.alpha
	var target: Vector3 = agent.prev_pos.lerp(agent.pos, a)
	var moved := Vector2(target.x - position.x, target.z - position.z).length()
	position = target

	# Facing: towards travel when moving, else towards the agent's focus.
	var fd: Vector3 = agent.face_dir
	if fd.length_squared() > 0.0001:
		var want := atan2(fd.x, fd.z)
		_yaw = lerp_angle(_yaw, want, 1.0 - exp(-10.0 * delta))
	rotation.y = _yaw

	var anim: int = agent.anim
	var walking := anim == Anim.WALK or anim == Anim.CARRY
	_walk_amt = move_toward(_walk_amt, 1.0 if walking and moved > 0.0005 else 0.0, delta * 5.0)
	var stride := 0.62 * _height
	_phase += moved / stride * PI
	_idle_t += delta
	var reach_target := 1.0 if anim == Anim.REACH or anim == Anim.SCAN else 0.0
	_reach = move_toward(_reach, reach_target, delta * 4.0)
	_pose(anim)
	_update_basket()
	_update_carry()


func _pose(anim: int) -> void:
	var w := _walk_amt
	var s := sin(_phase)
	var c := cos(_phase)
	var bob := absf(s) * 0.035 * w
	var breathe := sin(_idle_t * 1.9) * 0.012
	var sway := sin(_idle_t * 0.6) * 0.03 * (1.0 - w)
	# Hips carry the bob and a little side-to-side roll; legs swing.
	skel.set_bone_pose_position(PersonArt.B.HIPS, PersonArt.J_HIPS + Vector3(0, bob - 0.012 * w, 0))
	skel.set_bone_pose_rotation(PersonArt.B.HIPS, Quaternion.from_euler(Vector3(0.05 * w, s * 0.08 * w, c * 0.05 * w + sway)))
	skel.set_bone_pose_rotation(PersonArt.B.LEG_L, Quaternion.from_euler(Vector3(s * 0.55 * w, 0, 0)))
	skel.set_bone_pose_rotation(PersonArt.B.LEG_R, Quaternion.from_euler(Vector3(-s * 0.55 * w, 0, 0)))
	# Chest: counter-twist while walking, lean when browsing low shelves.
	var lean := 0.0
	if anim == Anim.BROWSE:
		lean = 0.12 + sin(_idle_t * 0.8) * 0.05
	elif anim == Anim.REACH:
		lean = 0.18
	skel.set_bone_pose_rotation(PersonArt.B.CHEST, Quaternion.from_euler(Vector3(lean + breathe, -s * 0.12 * w, 0)))
	# Arms swing opposite the legs; reaching raises the right arm forward.
	var arm_l := -s * 0.5 * w + breathe
	var arm_r := s * 0.5 * w - breathe
	var basket_hold := 0.0
	if basket != null:
		basket_hold = 0.0
		arm_r *= 0.35
	if anim == Anim.CARRY:
		arm_l = -1.2
		arm_r = -1.2
	arm_l = lerpf(arm_l, -1.25, _reach)
	skel.set_bone_pose_rotation(PersonArt.B.ARM_L, Quaternion.from_euler(Vector3(arm_l, 0, 0.06 + 0.15 * _reach)))
	skel.set_bone_pose_rotation(PersonArt.B.ARM_R, Quaternion.from_euler(Vector3(arm_r + basket_hold, 0, -0.06)))
	# Head: looks around while idle/queuing, scans shelves while browsing.
	var look := 0.0
	var nod := 0.0
	match anim:
		Anim.IDLE, Anim.QUEUE:
			look = sin(_idle_t * 0.45) * 0.35 * smoothstep(0.3, 1.0, sin(_idle_t * 0.21) * 0.5 + 0.5)
		Anim.BROWSE:
			look = sin(_idle_t * 1.1) * 0.4
			nod = 0.18
		Anim.REACH:
			nod = 0.2
		Anim.SCAN:
			nod = 0.3
	skel.set_bone_pose_rotation(PersonArt.B.HEAD, Quaternion.from_euler(Vector3(nod - lean * 0.5, look, 0)))


func _update_basket() -> void:
	if _basket_items == null:
		return
	var items: Array = agent.basket_items()
	if items.size() == _shown_items:
		return
	_shown_items = items.size()
	UIKit.clear(_basket_items)
	var n := mini(items.size(), 8)
	for i in n:
		var p: ProductDef = items[i]
		var m := MeshInstance3D.new()
		m.mesh = ProductArt.unit_mesh(p)
		var sc := 0.85
		if p.unit_size.y > 0.18:
			# Tall items lie down in the basket.
			m.rotation = Vector3(PI * 0.5, 0, 0)
			sc = 0.75
		m.scale = Vector3.ONE * sc
		var col := i % 3
		var row := i / 3
		m.position = Vector3(-0.08 + col * 0.08, 0.012 + row * 0.04, -0.04 + (row % 2) * 0.06)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_basket_items.add_child(m)


func _update_carry() -> void:
	var pid: StringName = agent.carrying() if agent.has_method("carrying") else &""
	if pid == &"":
		if _carry_box.visible:
			_carry_box.visible = false
		return
	var p := Game.catalog.product(pid)
	if p:
		_carry_box.mesh = ProductArt.case_mesh(p)
		_carry_box.scale = Vector3.ONE * 0.8
		_carry_box.visible = true
