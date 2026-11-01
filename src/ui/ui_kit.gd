class_name UIKit
extends RefCounted
## Small constructors for the game's recurring UI parts, so panels are
## composed from the same pieces with the same spacing everywhere.

const GAP_XS := 4
const GAP_S := 8
const GAP_M := 12
const GAP_L := 18


static func label(text: String, variation: String = "Body") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	return l


static func caption(text: String) -> Label:
	return label(text.to_upper(), "Caption")


static func icon(name: String, size: int = 18, color: Color = UITheme.TEXT_MUTED) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Icons.tex(name, size * UITheme.ICON_RES, color)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


static func button(text: String, icon_name: String = "", variation: String = "") -> Button:
	var b := Button.new()
	b.text = text
	if icon_name != "":
		b.icon = Icons.tex(icon_name, 20 * UITheme.ICON_RES, Color.WHITE)
	if variation != "":
		b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func icon_button(icon_name: String, tooltip: String, variation: String = "Quiet") -> Button:
	var b := button("", icon_name, variation)
	b.tooltip_text = tooltip
	b.custom_minimum_size = Vector2(34, 34)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


static func hbox(sep: int = GAP_S) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep: int = GAP_S) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func spacer(horizontal: bool = true) -> Control:
	var c := Control.new()
	if horizontal:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func gap(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	return c


static func vsep() -> VSeparator:
	var s := VSeparator.new()
	s.custom_minimum_size = Vector2(1, 22)
	s.add_theme_constant_override("separation", 14)
	return s


static func panel(variation: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	if variation != "":
		p.theme_type_variation = variation
	return p


static func swatch(p: ProductDef, size: int = 26) -> Control:
	## A tiny package-colour badge used wherever a product is listed.
	var c := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = p.color_main
	sb.set_corner_radius_all(4)
	sb.border_width_bottom = int(size * 0.28)
	sb.border_color = p.color_second
	c.add_theme_stylebox_override("panel", sb)
	c.custom_minimum_size = Vector2(size, size)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


static func bar(value: float, color: Color = UITheme.POSITIVE, height: int = 6) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 1.0
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(99)
	b.add_theme_stylebox_override("fill", fill)
	return b


static func stock_color(frac: float) -> Color:
	if frac <= 0.0:
		return UITheme.NEGATIVE
	if frac < 0.25:
		return Palette.MARIGOLD
	return UITheme.POSITIVE


static func row(left: String, right: String, right_variation: String = "Number") -> HBoxContainer:
	var h := hbox()
	var l := label(left, "Muted")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(label(right, right_variation))
	return h


static func window_header(title: String, icon_name: String, on_close: Callable) -> HBoxContainer:
	var h := hbox(GAP_S)
	h.add_child(icon(icon_name, 20, Palette.MARIGOLD))
	var t := label(title, "Heading")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var x := icon_button("close", "Close (Esc)")
	x.pressed.connect(on_close)
	h.add_child(x)
	return h


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func slide_in(c: Control, from_offset: Vector2 = Vector2(0, 12), duration: float = 0.18) -> void:
	## Short, purposeful entrance: fade + small travel, eased out.
	c.modulate.a = 0.0
	var base := c.position
	c.position = base + from_offset
	var tw := c.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, duration)
	tw.tween_property(c, "position", base, duration)
