class_name DayReport
extends PanelContainer
## End-of-day summary: the result up top, a short P&L, and what shoppers
## actually experienced, written as plain sentences the player can act on.

signal next_day

const COMPLAINTS := {
	"out_of_stock": "found something they wanted sold out",
	"not_carried": "wanted a product you don't sell",
	"price": "walked away from a price they thought too high",
	"queue": "gave up on the queue",
	"no_till": "couldn't find anywhere to pay",
	"blocked": "couldn't reach a shelf or till",
}


func show_report(r: Dictionary) -> void:
	UIKit.clear(self)
	custom_minimum_size = Vector2(520, 0)
	var v := UIKit.vbox(UIKit.GAP_M)
	add_child(v)
	var head := UIKit.hbox(10)
	head.add_child(UIKit.icon("moon", 22, Palette.MARIGOLD))
	head.add_child(UIKit.label("Day %d  ·  Closed" % r.day, "Title"))
	v.add_child(head)
	var profit: int = r.operating_profit
	var big := UIKit.label(Fmt.money_signed(profit), "MoneyLarge")
	big.add_theme_font_size_override("font_size", 40)
	big.add_theme_color_override("font_color", UITheme.POSITIVE if profit >= 0 else UITheme.NEGATIVE)
	v.add_child(big)
	v.add_child(UIKit.label("Operating profit  ·  sales minus cost of goods, rent, utilities and wages", "Muted"))
	var cols := UIKit.hbox(UIKit.GAP_L)
	var a := UIKit.vbox(6)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.add_child(UIKit.row("Sales", Fmt.money(r.revenue)))
	a.add_child(UIKit.row("Cost of goods", Fmt.money(-r.cogs)))
	a.add_child(UIKit.row("Rent", Fmt.money(-r.rent)))
	a.add_child(UIKit.row("Utilities & upkeep", Fmt.money(-r.upkeep)))
	a.add_child(UIKit.row("Wages", Fmt.money(-r.wages)))
	cols.add_child(a)
	var b := UIKit.vbox(6)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_child(UIKit.row("Shoppers", str(r.customers)))
	b.add_child(UIKit.row("Bought something", str(r.served)))
	b.add_child(UIKit.row("Items sold", str(r.items_sold)))
	var avg: float = r.satisfaction_sum / maxf(r.served + r.lost, 1)
	b.add_child(UIKit.row("Average satisfaction", Fmt.percent(avg)))
	b.add_child(UIKit.row("Cash at close", Fmt.money(r.closing_cash, false), "Money"))
	cols.add_child(b)
	v.add_child(cols)
	# Takeaways
	var notes: Array[String] = []
	var best_pid: StringName = &""
	var best_units := 0
	for pid in r.by_product:
		if r.by_product[pid].units > best_units:
			best_units = r.by_product[pid].units
			best_pid = pid
	if best_pid != &"":
		notes.append("Best seller: %s (%d sold)." % [Game.catalog.product(best_pid).display_name, best_units])
	var keys: Array = r.complaints.keys()
	keys.sort_custom(func(x, y): return r.complaints[x] > r.complaints[y])
	for k in keys:
		var n: int = r.complaints[k]
		notes.append("%d shopper%s %s." % [n, "" if n == 1 else "s", COMPLAINTS.get(k, k)])
	if r.stock_spend > 0:
		notes.append("You spent %s on stock today; it counts against profit as it sells." % Fmt.money(r.stock_spend, false))
	if not notes.is_empty():
		v.add_child(HSeparator.new())
		v.add_child(UIKit.caption("What happened"))
		for n in notes.slice(0, 5):
			var l := UIKit.label("·  " + n, "Body")
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(480, 0)
			v.add_child(l)
	var foot := UIKit.hbox()
	foot.add_child(UIKit.spacer())
	var go := UIKit.button("Start day %d" % (r.day + 1), "sun", "Primary")
	go.pressed.connect(func(): next_day.emit())
	foot.add_child(go)
	v.add_child(foot)
