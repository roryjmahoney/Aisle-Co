class_name Dock
extends PanelContainer
## Bottom-centre tool dock. Each entry opens one panel; only one is active.

signal tool_selected(id: String)

const ITEMS := [
	["build", "build", "Build", "B"],
	["stock", "truck", "Stock", "O"],
	["prices", "tag", "Prices", ""],
	["staff", "staff", "Staff", "H"],
	["finance", "chart", "Finances", ""],
]

var _buttons: Dictionary = {}
var _walls: Button
var _undo: Button


func _ready() -> void:
	var row := UIKit.hbox(2)
	add_child(row)
	for it in ITEMS:
		var b := Button.new()
		b.theme_type_variation = "Dock"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.icon = Icons.tex(it[1], 22 * UITheme.ICON_RES, Color.WHITE)
		b.text = it[2]
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 22)
		b.custom_minimum_size = Vector2(74, 58)
		b.tooltip_text = it[2] + ("  (%s)" % it[3] if it[3] != "" else "")
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var id: String = it[0]
		b.pressed.connect(func(): _on_pressed(id))
		row.add_child(b)
		_buttons[id] = b
	row.add_child(UIKit.vsep())
	_walls = _small("walls", "Walls")
	_walls.tooltip_text = "Cycle walls: automatic / up / cut away  (V)"
	_walls.pressed.connect(func(): tool_selected.emit("walls"))
	row.add_child(_walls)
	_undo = _small("undo", "Undo")
	_undo.tooltip_text = "Undo last construction  (Ctrl+Z)"
	_undo.pressed.connect(func(): tool_selected.emit("undo"))
	row.add_child(_undo)


func _small(icon_name: String, text: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = "Dock"
	b.focus_mode = Control.FOCUS_NONE
	b.icon = Icons.tex(icon_name, 22 * UITheme.ICON_RES, Color.WHITE)
	b.text = text
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 22)
	b.custom_minimum_size = Vector2(62, 58)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _on_pressed(id: String) -> void:
	tool_selected.emit(id)


func set_active(id: String) -> void:
	for k in _buttons:
		_buttons[k].set_pressed_no_signal(k == id)


func set_undo_enabled(on: bool) -> void:
	_undo.disabled = not on
