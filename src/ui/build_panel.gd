class_name BuildPanel
extends PanelContainer
## Construction catalogue, shown above the dock in build mode.

signal pick(def: FixtureDef)
signal tool(id: String)

const CATEGORIES := [["fixtures", "Fixtures"], ["storage", "Stockroom"], ["decor", "Decor"]]

var thumbs: Thumbnails
var _category := "fixtures"
var _cards: HBoxContainer
var _tabs: Dictionary = {}
var _card_buttons: Dictionary = {}
var _selected_id: StringName = &""
var _move_btn: Button
var _sell_btn: Button
var _help: Label


func _ready() -> void:
	var v := UIKit.vbox(UIKit.GAP_M)
	add_child(v)
	var head := UIKit.hbox(UIKit.GAP_S)
	var group := ButtonGroup.new()
	for c in CATEGORIES:
		var b := UIKit.button(c[1], "", "Segment")
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 30)
		var cid: String = c[0]
		b.pressed.connect(func():
			_category = cid
			_rebuild()
			Sfx.play("ui_click", -6.0))
		head.add_child(b)
		_tabs[cid] = b
	_tabs[_category].set_pressed_no_signal(true)
	head.add_child(UIKit.spacer())
	_help = UIKit.label("R rotate  ·  Right-click or Esc to stop", "Muted")
	_help.add_theme_font_size_override("font_size", 12)
	head.add_child(_help)
	head.add_child(UIKit.vsep())
	_move_btn = UIKit.button("Move", "move", "Quiet")
	_move_btn.toggle_mode = true
	_move_btn.tooltip_text = "Pick up a fixture and put it somewhere else (free)"
	_move_btn.pressed.connect(func(): tool.emit("move"))
	head.add_child(_move_btn)
	_sell_btn = UIKit.button("Sell", "bulldoze", "Quiet")
	_sell_btn.toggle_mode = true
	_sell_btn.tooltip_text = "Sell fixtures for 75% of their price  (X)"
	_sell_btn.pressed.connect(func(): tool.emit("sell"))
	head.add_child(_sell_btn)
	v.add_child(head)
	_cards = UIKit.hbox(UIKit.GAP_S)
	v.add_child(_cards)
	_rebuild()
	Game.economy.cash_changed.connect(func(_c): _refresh_affordability())


func set_tool_state(mode: int, def: FixtureDef) -> void:
	_move_btn.set_pressed_no_signal(mode == BuildController.Mode.MOVE)
	_sell_btn.set_pressed_no_signal(mode == BuildController.Mode.BULLDOZE)
	_selected_id = def.id if def != null and mode == BuildController.Mode.PLACE else &""
	for id in _card_buttons:
		_card_buttons[id].set_pressed_no_signal(id == _selected_id)


func _rebuild() -> void:
	UIKit.clear(_cards)
	_card_buttons.clear()
	for id in Game.catalog.fixture_order:
		var def: FixtureDef = Game.catalog.fixture(id)
		if def.category != _category:
			continue
		_cards.add_child(_card(def))
	_refresh_affordability()


func _card(def: FixtureDef) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 168)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := UITheme.flat(UITheme.SURFACE_2, UITheme.RADIUS_SMALL, 8, 8)
	var hover := UITheme.flat(UITheme.SURFACE_3, UITheme.RADIUS_SMALL, 8, 8)
	var on := UITheme.flat(UITheme.SURFACE_3, UITheme.RADIUS_SMALL, 8, 8)
	on.border_color = UITheme.ACCENT
	on.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("disabled", normal)
	var size_m := "%.1f × %.1f m" % [def.footprint.x * StoreGrid.CELL, def.footprint.y * StoreGrid.CELL]
	b.tooltip_text = "%s\n%s\n%s%s" % [def.display_name, def.description, size_m,
			("  ·  %s/day upkeep" % Fmt.money(def.upkeep_cents_per_day)) if def.upkeep_cents_per_day > 0 else ""]
	var v := UIKit.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	var img := TextureRect.new()
	img.texture = thumbs.get_tex(def)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(134, 100)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(img)
	var name_l := UIKit.label(def.display_name, "Subheading")
	name_l.add_theme_font_size_override("font_size", 13)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(name_l)
	var row := UIKit.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var price := UIKit.label(Fmt.money(def.price_cents, false), "Number")
	price.add_theme_color_override("font_color", UITheme.ACCENT)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.name = "Price"
	row.add_child(price)
	row.add_child(UIKit.spacer())
	var sz := UIKit.label(size_m, "Muted")
	sz.add_theme_font_size_override("font_size", 11)
	sz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sz)
	v.add_child(row)
	b.add_child(v)
	b.set_meta("price", price)
	b.set_meta("def", def)
	b.pressed.connect(func():
		Sfx.play("ui_click", -4.0)
		pick.emit(def))
	_card_buttons[def.id] = b
	return b


func _refresh_affordability() -> void:
	for id in _card_buttons:
		var b: Button = _card_buttons[id]
		var def: FixtureDef = b.get_meta("def")
		var ok := def.price_cents <= Game.economy.cash
		var l: Label = b.get_meta("price")
		l.add_theme_color_override("font_color", UITheme.ACCENT if ok else UITheme.NEGATIVE)
		b.modulate = Color(1, 1, 1, 1.0 if ok else 0.6)
