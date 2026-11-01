class_name FinanceWindow
extends PanelContainer
## Today's running P&L, sales by product and the last week at a glance.

signal close_requested

var _body: VBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(560, 0)
	var v := UIKit.vbox(UIKit.GAP_M)
	add_child(v)
	v.add_child(UIKit.window_header("Finances", "chart", func(): close_requested.emit()))
	_body = UIKit.vbox(UIKit.GAP_M)
	v.add_child(_body)
	_rebuild()


func _process(_d: float) -> void:
	if visible and Engine.get_process_frames() % 30 == 0:
		_rebuild()


func _rebuild() -> void:
	UIKit.clear(_body)
	var r: Dictionary = Game.economy.report
	var cols := UIKit.hbox(UIKit.GAP_L)
	var left := UIKit.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(UIKit.caption("Today so far"))
	left.add_child(UIKit.row("Sales", Fmt.money(r.revenue)))
	left.add_child(UIKit.row("Cost of goods sold", Fmt.money(-r.cogs)))
	var gm := UIKit.row("Gross margin", Fmt.money(r.revenue - r.cogs), "Money")
	left.add_child(gm)
	left.add_child(HSeparator.new())
	left.add_child(UIKit.row("Stock purchased", Fmt.money(-r.stock_spend)))
	left.add_child(UIKit.row("Construction", Fmt.money(-(r.build_spend - r.refunds))))
	left.add_child(UIKit.row("Rent (at close)", Fmt.money(-Economy.RENT_PER_DAY)))
	left.add_child(UIKit.row("Utilities & upkeep (at close)", Fmt.money(-(Economy.BASE_UTILITIES + Game.store.upkeep()))))
	left.add_child(UIKit.row("Wages (at close)", Fmt.money(-Game.staff.wages_per_day())))
	cols.add_child(left)
	var right := UIKit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UIKit.caption("Sales by product"))
	var any := false
	for pid in Game.catalog.product_order:
		var row: Dictionary = r.by_product.get(pid, {})
		if row.is_empty():
			continue
		any = true
		var p := Game.catalog.product(pid)
		var h := UIKit.hbox(8)
		h.add_child(UIKit.swatch(p, 14))
		var l := UIKit.label(p.display_name, "Body")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(UIKit.label("%d  ·  %s" % [row.units, Fmt.money(row.revenue)], "Number"))
		right.add_child(h)
	if not any:
		right.add_child(UIKit.label("No sales yet today.", "Muted"))
	right.add_child(HSeparator.new())
	right.add_child(UIKit.row("Shoppers", str(r.customers)))
	right.add_child(UIKit.row("Served", str(r.served)))
	right.add_child(UIKit.row("Items sold", str(r.items_sold)))
	cols.add_child(right)
	_body.add_child(cols)
	# History chart: operating profit per day.
	var hist: Array = Game.economy.history
	_body.add_child(UIKit.caption("Last days  ·  operating profit"))
	if hist.is_empty():
		_body.add_child(UIKit.label("Your first day's results will appear here after closing.", "Muted"))
		return
	var chart := HistoryChart.new()
	chart.data = hist.slice(maxi(0, hist.size() - 10))
	chart.custom_minimum_size = Vector2(0, 120)
	_body.add_child(chart)


class HistoryChart extends Control:
	var data: Array = []

	func _draw() -> void:
		if data.is_empty():
			return
		var w := size.x
		var h := size.y - 18
		var mx := 1
		for d in data:
			mx = maxi(mx, absi(d.operating_profit))
		var bw := minf(42.0, w / data.size() - 10)
		var zero := h * 0.5 if _has_negative() else h
		var scale := (zero - 6) / mx
		draw_line(Vector2(0, zero), Vector2(w, zero), UITheme.LINE, 1.0)
		var font := Fonts.numeric(600)
		for i in data.size():
			var d: Dictionary = data[i]
			var x := i * (w / data.size()) + 5
			var v: int = d.operating_profit
			var bh := absf(v) * scale
			var rect := Rect2(x, zero - bh, bw, bh) if v >= 0 else Rect2(x, zero, bw, bh)
			draw_rect(rect, UITheme.POSITIVE if v >= 0 else UITheme.NEGATIVE)
			draw_string(font, Vector2(x, size.y - 2), "D%d" % d.day, HORIZONTAL_ALIGNMENT_LEFT, bw, 11, UITheme.TEXT_FAINT)

	func _has_negative() -> bool:
		for d in data:
			if d.operating_profit < 0:
				return true
		return false
