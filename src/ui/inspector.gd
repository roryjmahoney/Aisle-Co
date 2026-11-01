class_name Inspector
extends PanelContainer
## Right-hand details panel for whatever is selected: a fixture, a shopper or
## a member of staff. Rebuilt when the selection changes; values refresh live.

signal close_requested
signal move_requested(uid: int)
signal sell_requested(uid: int)

var _content: VBoxContainer
var _target: Variant = null
var _live: Array = []        # [Callable] refreshed every few frames
var _t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(340, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 120)
	add_child(scroll)
	_content = UIKit.vbox(UIKit.GAP_M)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL


func show_for(obj: Variant) -> void:
	_target = obj
	_live.clear()
	UIKit.clear(_content)
	if obj is Fixture:
		_fixture(obj)
	elif obj is Customer:
		_customer(obj)
	elif obj is Staff:
		_staff(obj)
	_refresh()
	call_deferred("_fit")


func _fit() -> void:
	var h := _content.get_combined_minimum_size().y + 32
	var max_h := get_viewport_rect().size.y - 200
	custom_minimum_size.y = minf(h, max_h)
	size.y = custom_minimum_size.y


func _process(delta: float) -> void:
	_t += delta
	if _t > 0.15 and visible:
		_t = 0.0
		_refresh()


func _refresh() -> void:
	for f in _live:
		f.call()


func _header(title: String, icon_name: String, sub: String) -> void:
	_content.add_child(UIKit.window_header(title, icon_name, func(): close_requested.emit()))
	if sub != "":
		var s := UIKit.label(sub, "Muted")
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(s)


# --- Fixture -----------------------------------------------------------------

func _fixture(f: Fixture) -> void:
	var d := f.def
	var sub := d.description
	if d.upkeep_cents_per_day > 0:
		sub += "  Upkeep %s/day." % Fmt.money(d.upkeep_cents_per_day)
	_header(d.display_name, String(d.icon), sub)
	if d.slot_count > 0:
		_content.add_child(UIKit.caption("Shelf tiers  ·  top to bottom"))
		# Show tiers top-down as they appear on the unit; gondola back after front.
		var half := d.slot_count / 2 if d.double_sided else d.slot_count
		var rows := []
		for side in (2 if d.double_sided else 1):
			for i in range(half - 1, -1, -1):
				rows.append(side * half + i)
		var last_side := -1
		for i in rows:
			var side_i := 1 if (d.double_sided and i >= half) else 0
			if d.double_sided and side_i != last_side:
				_content.add_child(UIKit.label("Front" if side_i == 0 else "Back", "Subheading"))
				last_side = side_i
			_content.add_child(_tier_row(f, i))
	if d.storage_cases > 0:
		_content.add_child(UIKit.caption("Stockroom"))
		var used := UIKit.row("Cases stored (all racks)", "")
		var cap_bar := UIKit.bar(0.0, Palette.SKY)
		_content.add_child(used)
		_content.add_child(cap_bar)
		_live.append(func():
			var u := Game.inventory.used_cases()
			var c := Game.inventory.capacity_cases()
			(used.get_child(1) as Label).text = "%d / %d" % [u, c]
			cap_bar.value = float(u) / maxf(c, 1))
	if d.is_checkout:
		_content.add_child(UIKit.caption("Till"))
		var who := UIKit.row("Cashier", "")
		var q := UIKit.row("Waiting", "")
		_content.add_child(who)
		_content.add_child(q)
		_live.append(func():
			var lane: CheckoutLane = Game.customers.lanes.get(f.uid)
			if lane == null:
				return
			var w: Label = who.get_child(1)
			if lane.cashier == null:
				w.text = "Unstaffed"
				w.add_theme_color_override("font_color", UITheme.NEGATIVE)
			else:
				w.text = lane.cashier.display_name + ("" if lane.cashier_present else " (on the way)")
				w.remove_theme_color_override("font_color")
			(q.get_child(1) as Label).text = "%d shopper%s" % [lane.queue.size(), "" if lane.queue.size() == 1 else "s"])
		var note := UIKit.label("The owner steps in whenever shoppers queue. Hire cashiers to keep tills staffed all day.", "Muted")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(note)
	if d.appeal > 0:
		_content.add_child(UIKit.row("Atmosphere", "+%d" % d.appeal))
	_content.add_child(HSeparator.new())
	var actions := UIKit.hbox(UIKit.GAP_S)
	var mv := UIKit.button("Move", "move")
	mv.pressed.connect(func(): move_requested.emit(f.uid))
	actions.add_child(mv)
	var sell := UIKit.button("Sell  +%s" % Fmt.money(int(d.price_cents * BuildController.REFUND_RATE), false), "bulldoze")
	sell.pressed.connect(func(): sell_requested.emit(f.uid))
	actions.add_child(sell)
	_content.add_child(actions)


func _tier_row(f: Fixture, i: int) -> Control:
	var card := UIKit.panel("Card")
	var v := UIKit.vbox(6)
	card.add_child(v)
	var top := UIKit.hbox(8)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.fit_to_longest_item = false
	opt.add_item("Empty", 0)
	opt.set_item_metadata(0, &"")
	var idx := 1
	var cur := 0
	for pid in Game.catalog.product_order:
		var p := Game.catalog.product(pid)
		if not Merch.fits(p, f.def):
			continue
		opt.add_icon_item(_swatch_tex(p), p.display_name, idx)
		opt.set_item_metadata(idx, pid)
		if f.slots[i].product == pid:
			cur = idx
		idx += 1
	opt.select(cur)
	opt.item_selected.connect(func(sel):
		var pid: StringName = opt.get_item_metadata(sel)
		var err := Game.inventory.assign_slot(f, i, pid)
		if err != "":
			Game.say(err, "warning")
			opt.select(cur)
		else:
			Sfx.play("ui_click"))
	top.add_child(opt)
	var urgent := UIKit.icon_button("restock", "Restock this tier first")
	urgent.pressed.connect(func():
		if f.slots[i].product == &"":
			return
		if Game.inventory.units(f.slots[i].product) <= 0:
			Game.say("No %s in the stockroom — order some first" % Game.catalog.product(f.slots[i].product).display_name, "warning")
			return
		Game.staff.mark_urgent(f, i)
		Game.say("Staff will restock this tier next", "positive")
		Sfx.play("ui_click"))
	top.add_child(urgent)
	v.add_child(top)
	var bar_row := UIKit.hbox(8)
	var b := UIKit.bar(0.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(b)
	var n := UIKit.label("", "Number")
	n.add_theme_font_size_override("font_size", 12)
	n.custom_minimum_size = Vector2(64, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar_row.add_child(n)
	v.add_child(bar_row)
	_live.append(func():
		var s: Dictionary = f.slots[i]
		var frac := float(s.qty) / maxf(s.cap, 1)
		b.value = frac
		var sb := StyleBoxFlat.new()
		sb.bg_color = UIKit.stock_color(frac) if s.cap > 0 else UITheme.TEXT_FAINT
		sb.set_corner_radius_all(99)
		b.add_theme_stylebox_override("fill", sb)
		n.text = "%d / %d" % [s.qty, s.cap] if s.cap > 0 else "—"
		urgent.disabled = s.product == &"" or s.qty >= s.cap)
	return card


static var _swatches: Dictionary = {}


static func _swatch_tex(p: ProductDef) -> Texture2D:
	if _swatches.has(p.id):
		return _swatches[p.id]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36"><rect x="2" y="2" width="32" height="32" rx="6" fill="#%s"/><rect x="2" y="24" width="32" height="10" rx="0" fill="#%s"/><rect x="2" y="2" width="32" height="32" rx="6" fill="none" stroke="#000" stroke-opacity="0.2"/></svg>' % [
		p.color_main.to_html(false), p.color_second.to_html(false)]
	var img := Image.new()
	img.load_svg_from_string(svg, 1.0)
	var t := ImageTexture.create_from_image(img)
	_swatches[p.id] = t
	return t


# --- Customer --------------------------------------------------------------------

func _customer(c: Customer) -> void:
	_header(c.display_name, "person", "")
	var state := UIKit.row("Doing", "")
	_content.add_child(state)
	var sat_row := UIKit.hbox(8)
	sat_row.add_child(UIKit.icon("smile", 16))
	var sat := UIKit.bar(c.satisfaction)
	sat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sat_row.add_child(sat)
	sat_row.tooltip_text = "Satisfaction"
	sat_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_content.add_child(sat_row)
	var pat_row := UIKit.hbox(8)
	pat_row.add_child(UIKit.icon("clock", 16))
	var pat := UIKit.bar(1.0, Palette.SKY)
	pat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pat_row.add_child(pat)
	pat_row.tooltip_text = "Patience"
	pat_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_content.add_child(pat_row)
	var budget := UIKit.row("Budget", Fmt.money(c.budget, false))
	_content.add_child(budget)
	var basket := UIKit.row("In basket", "")
	_content.add_child(basket)
	_content.add_child(UIKit.caption("Shopping list"))
	var list_box := UIKit.vbox(4)
	_content.add_child(list_box)
	_content.add_child(UIKit.caption("Thinking"))
	var thoughts := UIKit.vbox(4)
	_content.add_child(thoughts)
	var last_sig := [""]
	_live.append(func():
		(state.get_child(1) as Label).text = c.status_text()
		sat.value = c.satisfaction
		pat.value = c.patience_left / c.patience
		(basket.get_child(1) as Label).text = "%d item%s  ·  %s" % [c.basket_count(), "" if c.basket_count() == 1 else "s", Fmt.money(c.basket_value())]
		var sig := str(c.list) + str(c.thoughts)
		if sig == last_sig[0]:
			return
		last_sig[0] = sig
		UIKit.clear(list_box)
		for it in c.list:
			var p := Game.catalog.product(it.pid)
			var r := UIKit.hbox(8)
			r.add_child(UIKit.swatch(p, 16))
			var l := UIKit.label("%d × %s" % [it.qty, p.display_name], "Body")
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(l)
			var icon_name: String = {"got": "check", "missed": "close", "skipped": "minus", "todo": "chevron_right"}[it.status]
			var col: Color = {"got": UITheme.POSITIVE, "missed": UITheme.NEGATIVE, "skipped": Palette.MARIGOLD, "todo": UITheme.TEXT_FAINT}[it.status]
			r.add_child(UIKit.icon(icon_name, 14, col))
			list_box.add_child(r)
		UIKit.clear(thoughts)
		if c.thoughts.is_empty():
			thoughts.add_child(UIKit.label("…", "Muted"))
		for t in c.thoughts:
			var q := UIKit.label("“%s”" % t, "Body")
			q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			q.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
			thoughts.add_child(q))


# --- Staff ---------------------------------------------------------------------

func _staff(s: Staff) -> void:
	var role: String = Staff.ROLE_NAMES[s.role]
	_header(s.display_name, "staff", role + ("" if s.role == Staff.Role.OWNER else "  ·  %s/day" % Fmt.money(s.wage, false)))
	var doing := UIKit.row("Doing", "")
	_content.add_child(doing)
	var carry := UIKit.row("Carrying", "")
	_content.add_child(carry)
	_live.append(func():
		(doing.get_child(1) as Label).text = s.status_text()
		var p := Game.catalog.product(s.carrying()) if s.carrying() != &"" else null
		(carry.get_child(1) as Label).text = ("%d × %s" % [s.carry_n, p.display_name]) if p else "—")
	if s.role != Staff.Role.OWNER:
		_content.add_child(HSeparator.new())
		var fire := UIKit.button("Let go", "exit")
		fire.pressed.connect(func():
			Game.staff.fire(s)
			Game.say("%s has left the shop" % s.display_name, "info")
			close_requested.emit())
		_content.add_child(fire)
	else:
		var note := UIKit.label("That's you. You'll work the till when shoppers queue and restock shelves in between.", "Muted")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(note)
