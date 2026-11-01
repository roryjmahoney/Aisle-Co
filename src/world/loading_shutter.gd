class_name LoadingShutter
extends Node3D
## Roll-up shutter on the stockroom's side wall. Slats rise into the roll box
## when a delivery arrives.

var curtain: Node3D
var height := 2.0
var _open := 0.0
var _target := 0.0


func set_open(v: bool) -> void:
	_target = 1.0 if v else 0.0


func _process(delta: float) -> void:
	if is_equal_approx(_open, _target):
		return
	_open = move_toward(_open, _target, delta * 0.55)
	var e := _open * _open * (3.0 - 2.0 * _open)
	curtain.scale.y = maxf(1.0 - e, 0.04)
