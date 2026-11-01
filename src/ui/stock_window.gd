class_name StockWindow
extends PanelContainer
## Ordering from the wholesaler and an overview of where stock is.

signal close_requested

var _qty: Dictionary = {}          # pid -> cases in the draft order
var _rows: Dictionary = {}
var _total: Label
var _eta: Label
var _place: Button
var _cap_bar: ProgressBar
var _cap_label: Label
var _pending: VBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(640, 0)
	var v := UIKit.vbox(UIKit.GAP_M)
	add_child(v)
	v.add_child(UIKit.window_header("Stock & Orders", "truck", func(): close_requested.emit()))
	var intro := UIKit.label("Order cases from the wholesaler. Deliveries arrive at the side door about an hour later and go onto your stockroom racks.", "Muted")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(custom_minimum_size.x - 40, 0)
	v.add_child(intro)
	# Stockroom capacity
	var cap := UIKit.hbox(UIKit.GAP_S)
	cap.add_child(UIKit.icon("rack", 16))
	cap.add_child(UIKit.label("Stockroom", "Subheading"))
	_cap_bar = UIKit.bar(0.0, Palette.SKY, 8)
	_cap_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.add_child(_cap_bar)
	_cap_label = UIKit.label("", "Number")
	cap.add_child(_cap_label)
	v.add_child(cap)
	# Table
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	for h in ["Product", "On shelves", "Stockroom", "Case", "Order", ""]:
		grid.add_child(UIKit.caption(h))
	for pid in Game.catalog.product_order:
		var p := Game.catalog.product(pid)
		_qty[pid] = 0
		var name_box := UIKit.hbox(8)
		name_box.add_child(UIKit.swatch(p, 22))
		var nv := UIKit.vbox(0)
		nv.add_child(UIKit.label(p.display_name, "Subheading"))
		var brand := UIKit.label("%s  ·  %s" % [p.brand, p.storage.capitalize()], "Muted")
		brand.add_theme_font_size_override("font_size", 11)
		nv.add_child(brand)
		name_box.add_child(nv)
		name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_box)
		var shelf := UIKit.label("", "Number")
		grid.add_child(shelf)
		var room := UIKit.label("", "Number")
		grid.add_child(room)
		var case_l := UIKit.vbox(0)
		case_l.add_child(UIKit.label("%d units" % p.case_size, "Number"))
		var cc := UIKit.label(Fmt.money(p.case_size * p.unit_cost_cents), "Muted")
		cc.add_theme_font_size_override("font_size", 11)
		case_l.add_child(cc)
		grid.add_child(case_l)
		var stepper := UIKit.hbox(4)
		var minus := UIKit.icon_button("minus", "One case fewer", "")
		minus.custom_minimum_size = Vector2(28, 28)
		var n := UIKit.label("0", "Money")
		n.custom_minimum_size = Vector2(28, 0)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var plus := UIKit.icon_button("plus", "One case more", "")
		plus.custom_minimum_size = Vector2(28, 28)
		minus.pressed.connect(func(): _bump(pid, -1))
		plus.pressed.connect(func(): _bump(pid, 1))
		stepper.add_child(minus)
		stepper.add_child(n)
		stepper.add_child(plus)
		grid.add_child(stepper)
		var line := UIKit.label("", "Number")
		line.custom_minimum_size = Vector2(70, 0)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(line)
		_rows[pid] = {"shelf": shelf, "room": room, "n": n, "line": line, "minus": minus}
	v.add_child(grid)
	v.add_child(HSeparator.new())
	var foot := UIKit.hbox(UIKit.GAP_M)
	var fv := UIKit.vbox(0)
	_total = UIKit.label("", "MoneyLarge")
	fv.add_child(_total)
	_eta = UIKit.label("", "Muted")
	fv.add_child(_eta)
	foot.add_child(fv)
	foot.add_child(UIKit.spacer())
	var clear := UIKit.button("Clear", "", "Quiet")
	clear.pressed.connect(func():
		for k in _qty:
			_qty[k] = 0
		_refresh())
	foot.add_child(clear)
	_place = UIKit.button("Place order", "truck", "Primary")
	_place.pressed.connect(_on_place)
	foot.add_child(_place)
	v.add_child(foot)
	_pending = UIKit.vbox(4)
	v.add_child(_pending)
	Game.inventory.stockroom_changed.connect(_refresh)
	Game.inventory.order_placed.connect(func(_o): _refresh())
	Game.inventory.delivered.connect(func(_o): _refresh())
	_refresh()


func _bump(pid: StringName, d: int) -> void:
	var cases := 0
	for k in _qty:
		cases += _qty[k]
	if d > 0 and cases >= Game.inventory.free_cases():
		Game.say("The stockroom racks are full — build more racking", "warning")
		Sfx.play("deny")
		return
	_qty[pid] = maxi(_qty[pid] + d, 0)
	Sfx.play("tick", -8.0)
	_refresh()


func _on_place() -> void:
	var items := {}
	for pid in _qty:
		if _qty[pid] > 0:
			items[pid] = _qty[pid]
	var o := Game.inventory.place_order(items)
	if o.has("error"):
		Game.say(o.error, "warning")
		Sfx.play("deny")
		return
	Sfx.play("register", -8.0)
	Game.say("Order #%d placed — arriving around %s" % [o.id, _clock_str(o.eta)], "truck")
	for k in _qty:
		_qty[k] = 0
	_refresh()


func _clock_str(abs_minute: float) -> String:
	var day := int(abs_minute / 1440.0) + 1
	var m := int(fmod(abs_minute, 1440.0))
	var t := "%02d:%02d" % [m / 60, m % 60]
	return t if day == Game.clock.day else "tomorrow %s" % t


func _process(_d: float) -> void:
	if visible and Engine.get_process_frames() % 20 == 0:
		_refresh()


func _refresh() -> void:
	if _total == null:
		return
	var inv := Game.inventory
	var cap := inv.capacity_cases()
	var used := inv.used_cases()
	var incoming := inv.incoming_cases()
	_cap_bar.value = float(used + incoming) / maxf(cap, 1)
	_cap_label.text = "%d stored  ·  %d incoming  ·  %d free" % [used, incoming, maxi(cap - used - incoming, 0)]
	var draft_cases := 0
	for pid in _rows:
		var r: Dictionary = _rows[pid]
		var p := Game.catalog.product(pid)
		var on_shelf := inv.shelf_units(pid)
		var shelf_cap := inv.shelf_capacity(pid)
		(r.shelf as Label).text = "%d / %d" % [on_shelf, shelf_cap] if shelf_cap > 0 else "not stocked"
		(r.shelf as Label).add_theme_color_override("font_color", UITheme.TEXT_FAINT if shelf_cap == 0 else (UITheme.NEGATIVE if on_shelf == 0 else UITheme.TEXT))
		(r.room as Label).text = "%d" % inv.units(pid)
		(r.n as Label).text = str(_qty[pid])
		(r.minus as Button).disabled = _qty[pid] == 0
		(r.line as Label).text = Fmt.money(_qty[pid] * p.case_size * p.unit_cost_cents) if _qty[pid] > 0 else ""
		draft_cases += _qty[pid]
	var cost := inv.order_cost(_draft())
	_total.text = Fmt.money(cost)
	_total.add_theme_color_override("font_color", UITheme.NEGATIVE if cost > Game.economy.cash else UITheme.TEXT)
	_eta.text = "%d case%s  ·  wholesale" % [draft_cases, "" if draft_cases == 1 else "s"]
	_place.disabled = draft_cases == 0 or cost > Game.economy.cash
	UIKit.clear(_pending)
	for o in inv.orders:
		var r := UIKit.hbox(8)
		r.add_child(UIKit.icon("truck", 16, Palette.MARIGOLD))
		var n := 0
		for pid in o.items:
			n += o.items[pid]
		var state: String = ["arriving around %s" % _clock_str(o.eta), "van pulling in", "unloading", "delivered"][o.state]
		r.add_child(UIKit.label("Order #%d  ·  %d cases  ·  %s" % [o.id, n, state], "Muted"))
		_pending.add_child(r)


func _draft() -> Dictionary:
	var d := {}
	for pid in _qty:
		if _qty[pid] > 0:
			d[pid] = _qty[pid]
	return d
