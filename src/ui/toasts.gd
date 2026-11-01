class_name Toasts
extends VBoxContainer
## Short notices at the top of the screen. Calm by design: they slide in, stay
## a few seconds, fade out; repeats of the same message refresh instead of
## stacking.

const LIFETIME := 3.6
const MAX := 4


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.notify.connect(show_toast)


func show_toast(text: String, kind: String = "info") -> void:
	for c in get_children():
		if c.get_meta("text", "") == text:
			c.set_meta("t", LIFETIME)
			return
	var p := UIKit.panel()
	var sb := UITheme.panel_box()
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.content_margin_left = 12
	sb.content_margin_right = 14
	sb.shadow_size = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := UIKit.hbox(8)
	var icon_name: String = {"info": "store", "positive": "check", "warning": "warning", "money": "coin", "truck": "truck"}.get(kind, "store")
	var col: Color = {"info": UITheme.INFO, "positive": UITheme.POSITIVE, "warning": UITheme.NEGATIVE, "money": Palette.MARIGOLD, "truck": Palette.MARIGOLD}.get(kind, UITheme.INFO)
	row.add_child(UIKit.icon(icon_name, 16, col))
	row.add_child(UIKit.label(text, "Body"))
	p.add_child(row)
	p.set_meta("text", text)
	p.set_meta("t", LIFETIME)
	add_child(p)
	p.modulate.a = 0.0
	while get_child_count() > MAX:
		var old := get_child(0)
		remove_child(old)
		old.queue_free()


func _process(delta: float) -> void:
	for c in get_children():
		var t: float = c.get_meta("t") - delta
		c.set_meta("t", t)
		var age := LIFETIME - t
		c.modulate.a = clampf(minf(age / 0.18, t / 0.4), 0.0, 1.0)
		if t <= 0.0:
			c.queue_free()
