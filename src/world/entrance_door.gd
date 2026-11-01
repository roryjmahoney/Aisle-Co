class_name EntranceDoor
extends Node3D
## Automatic sliding doors. Anyone who wants to pass calls `request()` while
## nearby; the doors ease open, hold briefly, then ease shut.

signal opened

var left_panel: Node3D
var right_panel: Node3D
var travel := 0.7
var _open := 0.0
var _hold := 0.0


func request() -> void:
	if _hold <= 0.0 and _open < 0.05:
		opened.emit()
	_hold = 0.9


func _process(delta: float) -> void:
	_hold = maxf(_hold - delta, 0.0)
	var target := 1.0 if _hold > 0.0 else 0.0
	if is_equal_approx(_open, target):
		return
	var speed := 2.6 if target > _open else 1.6
	_open = move_toward(_open, target, delta * speed)
	var e := _open * _open * (3.0 - 2.0 * _open)
	left_panel.position.x = -e * travel
	right_panel.position.x = e * travel
