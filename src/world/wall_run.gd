class_name WallRun
extends Node3D
## One side of the building (front, back, left, right, partition). The low
## `stub` always stays visible so the floor plan reads clearly; the `upper`
## part retracts when the wall stands between the camera and the interior.

var side := ""
var outward := Vector3.FORWARD
var stub: Node3D
var upper: Node3D
var cut := false
var _t := 1.0          # 1 = fully up, 0 = cut down
var _target := 1.0


func setup(side_name: String, out_dir: Vector3) -> void:
	side = side_name
	outward = out_dir
	name = "Wall_" + side_name
	stub = Node3D.new()
	stub.name = "Stub"
	add_child(stub)
	upper = Node3D.new()
	upper.name = "Upper"
	add_child(upper)


func set_cut(value: bool, instant: bool = false) -> void:
	cut = value
	_target = 0.0 if value else 1.0
	if instant:
		_t = _target
		_apply()


func _process(delta: float) -> void:
	if is_equal_approx(_t, _target):
		return
	# Critically damped feel: fast start, soft landing, ~0.25 s overall.
	_t = move_toward(_t, _target, delta * 4.5)
	_apply()


func _apply() -> void:
	var e := _t * _t * (3.0 - 2.0 * _t)
	upper.visible = e > 0.01
	# `upper` is pivoted at the stub top, so it retracts down onto the stub
	# rather than sinking into the floor.
	upper.scale = Vector3(1.0, maxf(e, 0.001), 1.0)
