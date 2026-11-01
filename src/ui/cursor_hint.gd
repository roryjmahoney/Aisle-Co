class_name CursorHint
extends PanelContainer
## A small label that follows the cursor during construction: what you're
## placing and its price, or exactly why it can't go there.

var _dot: Panel
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UITheme.flat(Color(UITheme.INK, 0.94), 99, 10, 5)
	add_theme_stylebox_override("panel", sb)
	var row := UIKit.hbox(7)
	_dot = Panel.new()
	_dot.custom_minimum_size = Vector2(8, 8)
	_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_dot)
	_label = UIKit.label("", "Body")
	_label.add_theme_font_size_override("font_size", 13)
	row.add_child(_label)
	add_child(row)
	visible = false


func show_hint(text: String, ok: bool, show_it: bool) -> void:
	visible = show_it and text != ""
	_label.text = text
	var dsb := UITheme.flat(UITheme.POSITIVE if ok else UITheme.NEGATIVE, 99, 0, 0)
	_dot.add_theme_stylebox_override("panel", dsb)
	reset_size()


func _process(_d: float) -> void:
	if visible:
		var m := get_viewport().get_mouse_position()
		position = (m + Vector2(18, 20)).round()
