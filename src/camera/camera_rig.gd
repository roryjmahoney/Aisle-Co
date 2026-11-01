class_name CameraRig
extends Node3D
## Management camera.
##
## Every degree of freedom (focus point, yaw, pitch, distance) has a *goal*
## and a *current* value; input moves goals and the current values chase them
## with frame-rate independent exponential damping. That is what makes the
## camera feel weighty and smooth instead of twitchy.
##
##   WASD / arrows   pan (accelerates, speed scales with zoom)
##   Q / E           rotate
##   Right drag      orbit + tilt
##   Middle drag     grab-pan: the point under the cursor stays under it
##   Wheel           zoom towards the cursor
##   F               focus selection        T  toggle top-down

signal moved

@export var min_distance := 5.5
@export var max_distance := 52.0
@export var min_pitch := 18.0
@export var max_pitch := 84.0
@export var fov := 34.0

# Tunables exposed through Settings.
var pan_speed := 1.0
var orbit_sensitivity := 1.0
var zoom_speed := 1.0
var invert_orbit := false

var camera: Camera3D
var bounds := Rect2(0, 0, 28, 20)
var ground_y := 0.12

var focus := Vector3(10, 0.12, 8)
var yaw := deg_to_rad(-28.0)
var pitch := deg_to_rad(42.0)
var distance := 22.0
var _focus_goal := focus
var _yaw_goal := yaw
var _pitch_goal := pitch
var _dist_goal := distance
var _pan_vel := Vector3.ZERO
var _orbiting := false
var _grabbing := false
var _grab_point := Vector3.ZERO
var _saved_pitch := -1.0
var _input_enabled := true


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = fov
	camera.near = 0.1
	camera.far = 220.0
	add_child(camera)
	_apply()


func set_input_enabled(v: bool) -> void:
	_input_enabled = v
	if not v:
		_orbiting = false
		_grabbing = false


func snap_to(f: Vector3, yaw_deg: float, pitch_deg: float, dist: float) -> void:
	focus = f
	_focus_goal = f
	yaw = deg_to_rad(yaw_deg)
	_yaw_goal = yaw
	pitch = deg_to_rad(pitch_deg)
	_pitch_goal = pitch
	distance = dist
	_dist_goal = dist
	_apply()


func focus_on(p: Vector3, dist: float = -1.0) -> void:
	_focus_goal = Vector3(p.x, ground_y, p.z)
	if dist > 0.0:
		_dist_goal = clampf(dist, min_distance, max_distance)
	_clamp_goals()


func toggle_top_down() -> void:
	if _saved_pitch < 0.0:
		_saved_pitch = _pitch_goal
		_pitch_goal = deg_to_rad(max_pitch)
	else:
		_pitch_goal = _saved_pitch
		_saved_pitch = -1.0


func is_top_down() -> bool:
	return _saved_pitch >= 0.0


func zoom_t() -> float:
	## 0 at closest zoom, 1 at furthest.
	return inverse_lerp(min_distance, max_distance, distance)


func ground_point_at(screen_pos: Vector2) -> Variant:
	## World point on the floor plane under a screen position, or null.
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 1e-4:
		return null
	var t := (ground_y - origin.y) / dir.y
	if t < 0.0:
		return null
	return origin + dir * t


# --- Input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				_orbiting = mb.pressed
			MOUSE_BUTTON_MIDDLE:
				_grabbing = mb.pressed
				if mb.pressed:
					var gp: Variant = ground_point_at(mb.position)
					_grabbing = gp != null
					if gp != null:
						_grab_point = gp
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					var dir := -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
					_zoom(dir * mb.factor if mb.factor > 0.0 else dir, mb.position)
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _orbiting:
			var s := 0.0055 * orbit_sensitivity
			var inv := -1.0 if invert_orbit else 1.0
			_yaw_goal -= mm.relative.x * s * inv
			_pitch_goal = clampf(_pitch_goal + mm.relative.y * s * 0.8 * inv, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
			_saved_pitch = -1.0
			get_viewport().set_input_as_handled()
		elif _grabbing:
			# Re-project with the *current* camera so the grabbed point stays
			# glued to the cursor, then move both goal and current focus.
			var gp: Variant = ground_point_at(mm.position)
			if gp != null:
				var delta: Vector3 = _grab_point - (gp as Vector3)
				delta.y = 0.0
				_focus_goal += delta
				focus += delta
				_clamp_goals()
				focus = _clamp_focus(focus)
				_apply()
			get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		_zoom((1.0 - (event as InputEventMagnifyGesture).factor) * 4.0, get_viewport().get_mouse_position())
	elif event is InputEventPanGesture:
		_zoom((event as InputEventPanGesture).delta.y * 0.5, get_viewport().get_mouse_position())


func _zoom(steps: float, at_screen: Vector2) -> void:
	var old := _dist_goal
	var factor := pow(1.13, steps * zoom_speed)
	_dist_goal = clampf(_dist_goal * factor, min_distance, max_distance)
	# Zoom towards (or away from) the point under the cursor, like a map.
	var gp: Variant = ground_point_at(at_screen)
	if gp != null and steps < 0.0:
		var pull := 1.0 - _dist_goal / old
		var p: Vector3 = gp
		_focus_goal += Vector3(p.x - _focus_goal.x, 0, p.z - _focus_goal.z) * pull * 0.85
	_clamp_goals()


# --- Update ----------------------------------------------------------------

func _process(delta: float) -> void:
	if _input_enabled:
		_keyboard(delta)
	var before := camera.global_transform
	var kf := 1.0 - exp(-14.0 * delta)
	var kr := 1.0 - exp(-11.0 * delta)
	var kz := 1.0 - exp(-10.0 * delta)
	focus = focus.lerp(_focus_goal, kf)
	yaw = lerp_angle(yaw, _yaw_goal, kr)
	pitch = lerpf(pitch, _pitch_goal, kr)
	distance = lerpf(distance, _dist_goal, kz)
	_apply()
	if not camera.global_transform.is_equal_approx(before):
		moved.emit()


func _keyboard(delta: float) -> void:
	var in_x := Input.get_axis(&"cam_left", &"cam_right")
	var in_z := Input.get_axis(&"cam_forward", &"cam_back")
	var basis := Basis(Vector3.UP, yaw)
	var wish := (basis * Vector3(in_x, 0, in_z))
	if wish.length() > 1.0:
		wish = wish.normalized()
	# Speed scales with zoom so panning covers the same *screen* distance.
	var speed := (4.0 + distance * 0.75) * pan_speed
	var accel := 9.0 if wish.length() > 0.01 else 12.0
	_pan_vel = _pan_vel.lerp(wish * speed, 1.0 - exp(-accel * delta))
	if _pan_vel.length() > 0.001:
		_focus_goal += _pan_vel * delta
		_clamp_goals()
	var rot := Input.get_axis(&"cam_rotate_left", &"cam_rotate_right")
	if absf(rot) > 0.01:
		_yaw_goal += rot * delta * 1.9


func _clamp_goals() -> void:
	_focus_goal = _clamp_focus(_focus_goal)
	_dist_goal = clampf(_dist_goal, min_distance, max_distance)


func _clamp_focus(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, bounds.position.x, bounds.end.x), ground_y,
			clampf(p.z, bounds.position.y, bounds.end.y))


func _apply() -> void:
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var pos := focus + dir * distance
	# Never dip below a comfortable height over the floor.
	pos.y = maxf(pos.y, ground_y + 1.2)
	camera.global_position = pos
	camera.look_at(focus + Vector3(0, 0.4 * (1.0 - zoom_t()), 0), Vector3.UP)


func forward_flat() -> Vector3:
	var f := -camera.global_transform.basis.z
	f.y = 0.0
	return f.normalized()
