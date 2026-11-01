class_name UITheme
extends RefCounted
## Design tokens and the Godot Theme built from them. Change a token here and
## every panel, button and label in the game follows.

# Surfaces — deep pine ink, never pure black, never beige.
const SURFACE := Color("15231f")
const SURFACE_2 := Color("1d2f29")
const SURFACE_3 := Color("273d36")
const LINE := Color("2f4740")
const LINE_SOFT := Color(1, 1, 1, 0.06)
# Type
const TEXT := Color("eef3ec")
const TEXT_MUTED := Color("9fb7ad")
const TEXT_FAINT := Color("6e877d")
const INK := Color("142120")
# Accents
const ACCENT := Palette.MARIGOLD
const ACCENT_HOVER := Color("f7c35e")
const POSITIVE := Color("7fd3a2")
const NEGATIVE := Color("ef7a62")
const INFO := Palette.SKY

const RADIUS := 7
const RADIUS_SMALL := 5
const ICON_RES := 2   # icons are rasterised at 2x for crisp scaling

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = Fonts.body(500)
	t.default_font_size = 14

	# Panels
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", _flat(SURFACE_2, RADIUS_SMALL, 12, 10, Color(0, 0, 0, 0), 0))
	t.set_type_variation("Inset", "PanelContainer")
	t.set_stylebox("panel", "Inset", _flat(Color(0, 0, 0, 0.18), RADIUS_SMALL, 10, 8, Color(0, 0, 0, 0), 0))
	t.set_type_variation("Chip", "PanelContainer")
	t.set_stylebox("panel", "Chip", _flat(SURFACE_3, 99, 9, 3, Color(0, 0, 0, 0), 0))

	# Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_font("font", "Label", Fonts.body(500))
	_label_var(t, "Title", Fonts.display(800, 82), 24, TEXT)
	_label_var(t, "Heading", Fonts.display(800, 85), 18, TEXT)
	_label_var(t, "Subheading", Fonts.body(700), 14, TEXT)
	_label_var(t, "Body", Fonts.body(500), 14, TEXT)
	_label_var(t, "Muted", Fonts.body(500), 13, TEXT_MUTED)
	_label_var(t, "Caption", caption_font(), 11, TEXT_FAINT)
	_label_var(t, "Money", Fonts.numeric(700), 18, TEXT)
	_label_var(t, "MoneyLarge", Fonts.display(800, 80), 26, TEXT)
	_label_var(t, "Number", Fonts.numeric(600), 14, TEXT)

	# Buttons
	var b_normal := _flat(SURFACE_2, RADIUS_SMALL, 12, 7)
	var b_hover := _flat(SURFACE_3, RADIUS_SMALL, 12, 7)
	var b_pressed := _flat(Color("31493f"), RADIUS_SMALL, 12, 7)
	var b_disabled := _flat(Color(SURFACE_2, 0.5), RADIUS_SMALL, 12, 7)
	var b_focus := _flat(Color(0, 0, 0, 0), RADIUS_SMALL, 12, 7, ACCENT, 1)
	for name in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", name, b_normal)
		t.set_stylebox("hover", name, b_hover)
		t.set_stylebox("pressed", name, b_pressed)
		t.set_stylebox("hover_pressed", name, b_pressed)
		t.set_stylebox("disabled", name, b_disabled)
		t.set_stylebox("focus", name, b_focus)
		t.set_color("font_color", name, TEXT)
		t.set_color("font_hover_color", name, Color.WHITE)
		t.set_color("font_pressed_color", name, ACCENT)
		t.set_color("font_hover_pressed_color", name, ACCENT)
		t.set_color("font_disabled_color", name, TEXT_FAINT)
		t.set_color("icon_normal_color", name, TEXT_MUTED)
		t.set_color("icon_hover_color", name, TEXT)
		t.set_color("icon_pressed_color", name, ACCENT)
		t.set_color("icon_hover_pressed_color", name, ACCENT)
		t.set_color("icon_disabled_color", name, TEXT_FAINT)
		t.set_font("font", name, Fonts.body(600))
		t.set_constant("h_separation", name, 8)
		t.set_constant("icon_max_width", name, 20)

	# Primary action: marigold with ink text.
	t.set_type_variation("Primary", "Button")
	t.set_stylebox("normal", "Primary", _flat(ACCENT, RADIUS_SMALL, 14, 8))
	t.set_stylebox("hover", "Primary", _flat(ACCENT_HOVER, RADIUS_SMALL, 14, 8))
	t.set_stylebox("pressed", "Primary", _flat(Palette.shade(ACCENT, -0.12), RADIUS_SMALL, 14, 8))
	t.set_stylebox("disabled", "Primary", _flat(Color(ACCENT, 0.3), RADIUS_SMALL, 14, 8))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "icon_normal_color",
			"icon_hover_color", "icon_pressed_color"]:
		t.set_color(c, "Primary", INK)
	t.set_color("font_disabled_color", "Primary", Color(INK, 0.6))
	t.set_font("font", "Primary", Fonts.body(700))

	# Quiet buttons: no fill until hovered (toolbars, close buttons).
	t.set_type_variation("Quiet", "Button")
	t.set_stylebox("normal", "Quiet", _flat(Color(0, 0, 0, 0), RADIUS_SMALL, 8, 6))
	t.set_stylebox("hover", "Quiet", _flat(Color(1, 1, 1, 0.06), RADIUS_SMALL, 8, 6))
	t.set_stylebox("pressed", "Quiet", _flat(Color(1, 1, 1, 0.1), RADIUS_SMALL, 8, 6))
	t.set_stylebox("hover_pressed", "Quiet", _flat(Color(1, 1, 1, 0.1), RADIUS_SMALL, 8, 6))
	t.set_stylebox("disabled", "Quiet", _flat(Color(0, 0, 0, 0), RADIUS_SMALL, 8, 6))

	# Dock tool: tall icon-over-label buttons; "toggled on" gets a marigold bar.
	t.set_type_variation("Dock", "Button")
	var dock_on := _flat(Color(1, 1, 1, 0.07), RADIUS_SMALL, 10, 7)
	dock_on.border_width_bottom = 3
	dock_on.border_color = ACCENT
	t.set_stylebox("normal", "Dock", _flat(Color(0, 0, 0, 0), RADIUS_SMALL, 10, 7))
	t.set_stylebox("hover", "Dock", _flat(Color(1, 1, 1, 0.06), RADIUS_SMALL, 10, 7))
	t.set_stylebox("pressed", "Dock", dock_on)
	t.set_stylebox("hover_pressed", "Dock", dock_on)
	t.set_font("font", "Dock", Fonts.body(600))
	t.set_font_size("font_size", "Dock", 12)
	t.set_color("font_pressed_color", "Dock", TEXT)
	t.set_color("font_hover_pressed_color", "Dock", TEXT)

	# Segmented (speed controls)
	t.set_type_variation("Segment", "Button")
	t.set_stylebox("normal", "Segment", _flat(Color(0, 0, 0, 0), RADIUS_SMALL, 8, 6))
	t.set_stylebox("hover", "Segment", _flat(Color(1, 1, 1, 0.06), RADIUS_SMALL, 8, 6))
	t.set_stylebox("pressed", "Segment", _flat(ACCENT, RADIUS_SMALL, 8, 6))
	t.set_stylebox("hover_pressed", "Segment", _flat(ACCENT_HOVER, RADIUS_SMALL, 8, 6))
	t.set_color("icon_pressed_color", "Segment", INK)
	t.set_color("icon_hover_pressed_color", "Segment", INK)
	t.set_color("font_pressed_color", "Segment", INK)

	# Inputs
	var field := _flat(Color(0, 0, 0, 0.25), RADIUS_SMALL, 10, 6, LINE, 1)
	var field_focus := _flat(Color(0, 0, 0, 0.3), RADIUS_SMALL, 10, 6, ACCENT, 1)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_stylebox("read_only", "LineEdit", field)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.35))
	t.set_font("font", "LineEdit", Fonts.numeric(600))

	# Sliders
	var track := _flat(Color(1, 1, 1, 0.1), 99, 0, 2)
	var fill := _flat(ACCENT, 99, 0, 2)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", _flat(ACCENT_HOVER, 99, 0, 2))
	t.set_icon("grabber", "HSlider", _dot(16, TEXT))
	t.set_icon("grabber_highlight", "HSlider", _dot(16, Color.WHITE))
	t.set_icon("grabber_disabled", "HSlider", _dot(16, TEXT_FAINT))

	# Progress bars (stock levels, satisfaction)
	t.set_stylebox("background", "ProgressBar", _flat(Color(1, 1, 1, 0.08), 99, 0, 0))
	t.set_stylebox("fill", "ProgressBar", _flat(POSITIVE, 99, 0, 0))
	t.set_constant("outline_size", "ProgressBar", 0)

	# Check boxes as switches.
	t.set_icon("checked", "CheckButton", _switch(true))
	t.set_icon("unchecked", "CheckButton", _switch(false))
	t.set_icon("checked_disabled", "CheckButton", _switch(true))
	t.set_icon("unchecked_disabled", "CheckButton", _switch(false))
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		t.set_stylebox(s, "CheckButton", _flat(Color(0, 0, 0, 0), 0, 0, 4))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_color("font_hover_pressed_color", "CheckButton", Color.WHITE)

	# Separators, scroll, tooltips, popups
	var sep := StyleBoxLine.new()
	sep.color = LINE
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 12)
	var vsep := StyleBoxLine.new()
	vsep.color = LINE
	vsep.vertical = true
	t.set_stylebox("separator", "VSeparator", vsep)
	t.set_stylebox("scroll", "VScrollBar", _flat(Color(0, 0, 0, 0), 99, 3, 0))
	t.set_stylebox("grabber", "VScrollBar", _flat(Color(1, 1, 1, 0.14), 99, 3, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", _flat(Color(1, 1, 1, 0.24), 99, 3, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", _flat(ACCENT, 99, 3, 0))
	t.set_stylebox("panel", "TooltipPanel", _flat(INK, RADIUS_SMALL, 10, 7, LINE, 1))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font("font", "TooltipLabel", Fonts.body(500))
	t.set_font_size("font_size", "TooltipLabel", 13)
	t.set_stylebox("panel", "PopupMenu", _flat(SURFACE, RADIUS_SMALL, 6, 6, LINE, 1))
	t.set_stylebox("hover", "PopupMenu", _flat(SURFACE_3, 4, 8, 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_font("font", "PopupMenu", Fonts.body(500))
	t.set_constant("v_separation", "PopupMenu", 8)
	t.set_icon("arrow", "OptionButton", Icons.tex("chevron_down", 16 * ICON_RES, TEXT_MUTED, 2.0))
	t.set_constant("icon_max_width", "PopupMenu", 18)

	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("separation", "VBoxContainer", 8)
	_theme = t
	return t


static func panel_box() -> StyleBoxFlat:
	var s := _flat(Color(SURFACE, 0.97), RADIUS, 16, 14, LINE, 1)
	s.shadow_color = Color(0.02, 0.06, 0.05, 0.35)
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 5)
	return s


static func caption_font() -> FontVariation:
	var f := Fonts.body(700).duplicate() as FontVariation
	f.spacing_glyph = 1
	return f


static func _label_var(t: Theme, name: String, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)


static func _flat(bg: Color, radius: int, mx: int, my: int, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.anti_aliasing = true
	s.anti_aliasing_size = 0.8
	return s


static func flat(bg: Color, radius: int = RADIUS_SMALL, mx: int = 10, my: int = 8) -> StyleBoxFlat:
	return _flat(bg, radius, mx, my)


static func _dot(size: int, c: Color) -> Texture2D:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><circle cx="%f" cy="%f" r="%f" fill="#%s"/></svg>' % [
		size, size, size * 0.5, size * 0.5, size * 0.5 - 1, c.to_html(false)]
	var img := Image.new()
	img.load_svg_from_string(svg, 1.0)
	return ImageTexture.create_from_image(img)


static func _switch(on: bool) -> Texture2D:
	var track := ACCENT if on else Color(1, 1, 1, 0.16)
	var knob_x := 25.0 if on else 11.0
	var svg := ('<svg xmlns="http://www.w3.org/2000/svg" width="36" height="22"><rect x="1" y="2" width="34" height="18" rx="9" fill="#%s" fill-opacity="%f"/>' +
		'<circle cx="%f" cy="11" r="7" fill="#%s"/></svg>') % [track.to_html(false), track.a, knob_x, (INK if on else TEXT).to_html(false)]
	var img := Image.new()
	img.load_svg_from_string(svg, 1.0)
	return ImageTexture.create_from_image(img)
