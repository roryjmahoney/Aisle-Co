class_name PricesWindow
extends PanelContainer
## Set shelf prices. Shows margin and how shoppers will perceive each price.

signal close_requested

var _rows: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(600, 0)
	var v := UIKit.vbox(UIKit.GAP_M)
	add_child(v)
	v.add_child(UIKit.window_header("Prices", "tag", func(): close_requested.emit()))
	var intro := UIKit.label("Shoppers compare your price with what they think is fair. Price-sensitive shoppers walk away from expensive shelves; bargains tempt them to buy extra.", "Muted")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(custom_minimum_size.x - 40, 0)
	v.add_child(intro)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	for h in ["Product", "Cost", "Your price", "Margin", "Shoppers think"]:
		grid.add_child(UIKit.caption(h))
	for pid in Game.catalog.product_order:
		var p := Game.catalog.product(pid)
		var nb := UIKit.hbox(8)
		nb.add_child(UIKit.swatch(p, 22))
		var nv := UIKit.vbox(0)
		nv.add_child(UIKit.label(p.display_name, "Subheading"))
		var ref := UIKit.label("Fair price %s" % Fmt.money(p.reference_price_cents), "Muted")
		ref.add_theme_font_size_override("font_size", 11)
		nv.add_child(ref)
		nb.add_child(nv)
		nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(nb)
		grid.add_child(UIKit.label(Fmt.money(p.unit_cost_cents), "Number"))
		var stepper := UIKit.hbox(4)
		var minus := UIKit.icon_button("minus", "−10¢  (Shift: −1¢)", "")
		minus.custom_minimum_size = Vector2(28, 28)
		var price := UIKit.label("", "Money")
		price.custom_minimum_size = Vector2(64, 0)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var plus := UIKit.icon_button("plus", "+10¢  (Shift: +1¢)", "")
		plus.custom_minimum_size = Vector2(28, 28)
		minus.pressed.connect(func(): _nudge(pid, -1))
		plus.pressed.connect(func(): _nudge(pid, 1))
		stepper.add_child(minus)
		stepper.add_child(price)
		stepper.add_child(plus)
		grid.add_child(stepper)
		var margin := UIKit.label("", "Number")
		grid.add_child(margin)
		var chip := UIKit.panel("Chip")
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var verdict := UIKit.label("", "Caption")
		chip.add_child(verdict)
		grid.add_child(chip)
		_rows[pid] = {"price": price, "margin": margin, "verdict": verdict}
	v.add_child(grid)
	var foot := UIKit.hbox()
	foot.add_child(UIKit.spacer())
	var reset := UIKit.button("Reset to fair prices", "undo", "Quiet")
	reset.pressed.connect(func():
		for pid in Game.catalog.product_order:
			Game.store.set_price(pid, Game.catalog.product(pid).reference_price_cents)
		_refresh())
	foot.add_child(reset)
	v.add_child(foot)
	_refresh()


func _nudge(pid: StringName, dir: int) -> void:
	var step := 1 if Input.is_key_pressed(KEY_SHIFT) else 10
	var p := Game.catalog.product(pid)
	var cur := Game.store.price_of(pid)
	var next := cur + dir * step
	if step == 10:
		# Coarse steps land on "charm" prices ending in 9.
		next = roundi((next + 1) / 10.0) * 10 - 1
	Game.store.set_price(pid, clampi(next, maxi(p.unit_cost_cents / 2, 1), p.reference_price_cents * 4))
	Sfx.play("tick", -8.0)
	_refresh()


func _refresh() -> void:
	for pid in _rows:
		var p := Game.catalog.product(pid)
		var r: Dictionary = _rows[pid]
		var price := Game.store.price_of(pid)
		(r.price as Label).text = Fmt.money(price)
		var m := price - p.unit_cost_cents
		var pct := float(m) / maxf(price, 1)
		(r.margin as Label).text = "%s  ·  %d%%" % [Fmt.money(m), roundi(pct * 100)]
		(r.margin as Label).add_theme_color_override("font_color", UITheme.NEGATIVE if m <= 0 else UITheme.TEXT)
		var ratio := float(price) / p.reference_price_cents
		var verdict := "Fair"
		var col := UITheme.TEXT_MUTED
		if ratio < 0.85:
			verdict = "Bargain"
			col = UITheme.POSITIVE
		elif ratio <= 1.06:
			verdict = "Fair"
			col = UITheme.INFO
		elif ratio <= 1.25:
			verdict = "Pricey"
			col = Palette.MARIGOLD
		else:
			verdict = "Too expensive"
			col = UITheme.NEGATIVE
		(r.verdict as Label).text = verdict.to_upper()
		(r.verdict as Label).add_theme_color_override("font_color", col)
