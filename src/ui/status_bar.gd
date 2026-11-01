class_name StatusBar
extends PanelContainer
## Top-left: cash, today's result, clock, trading status, footfall, reputation.

var _cash: Label
var _delta: Label
var _time: Label
var _day: Label
var _time_icon: TextureRect
var _phase_chip: PanelContainer
var _phase: Label
var _people: Label
var _rep: Label
var _shown_cash := 0.0
var _target_cash := 0


func _ready() -> void:
	var row := UIKit.hbox(UIKit.GAP_M)
	add_child(row)
	# Cash
	var cash_box := UIKit.vbox(0)
	cash_box.add_child(UIKit.caption("Cash"))
	_cash = UIKit.label("", "MoneyLarge")
	cash_box.add_child(_cash)
	row.add_child(cash_box)
	_delta = UIKit.label("", "Number")
	_delta.size_flags_vertical = Control.SIZE_SHRINK_END
	_delta.tooltip_text = "Change in cash since the start of today"
	_delta.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(_delta)
	row.add_child(UIKit.vsep())
	# Clock
	var time_box := UIKit.vbox(0)
	_day = UIKit.caption("Day 1")
	time_box.add_child(_day)
	var trow := UIKit.hbox(6)
	_time_icon = UIKit.icon("sun", 18, Palette.MARIGOLD)
	trow.add_child(_time_icon)
	_time = UIKit.label("07:00", "Money")
	trow.add_child(_time)
	time_box.add_child(trow)
	row.add_child(time_box)
	_phase_chip = UIKit.panel("Chip")
	_phase_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_phase = UIKit.label("", "Caption")
	_phase_chip.add_child(_phase)
	row.add_child(_phase_chip)
	row.add_child(UIKit.vsep())
	# Footfall + reputation
	var p_row := UIKit.hbox(5)
	p_row.add_child(UIKit.icon("person", 16))
	_people = UIKit.label("0", "Number")
	p_row.add_child(_people)
	p_row.tooltip_text = "Shoppers in the store right now"
	p_row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(p_row)
	var r_row := UIKit.hbox(5)
	r_row.add_child(UIKit.icon("star", 16, Palette.MARIGOLD))
	_rep = UIKit.label("", "Number")
	r_row.add_child(_rep)
	r_row.tooltip_text = "Reputation — how the neighbourhood feels about your shop.\nHappy shoppers raise it and bring more footfall."
	r_row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(r_row)
	_shown_cash = Game.economy.cash
	Game.economy.cash_changed.connect(func(c):
		_target_cash = c)
	_target_cash = Game.economy.cash


func _process(delta: float) -> void:
	# Money counts up/down briefly rather than jumping — satisfying, readable.
	_shown_cash = lerpf(_shown_cash, _target_cash, 1.0 - exp(-10.0 * delta))
	if absf(_shown_cash - _target_cash) < 1.0:
		_shown_cash = _target_cash
	_cash.text = Fmt.money(int(round(_shown_cash)), false)
	var d := Game.economy.cash - Game.economy.opening_cash
	_delta.text = Fmt.money_signed(d) if d != 0 else ""
	_delta.add_theme_color_override("font_color", UITheme.POSITIVE if d > 0 else UITheme.NEGATIVE)
	var clock := Game.clock
	_time.text = clock.time_string()
	_day.text = "DAY %d" % clock.day
	var night := clock.minute < 390.0 or clock.minute > 1200.0
	_time_icon.texture = Icons.tex("moon" if night else "sun", 18 * UITheme.ICON_RES, UITheme.INFO if night else Palette.MARIGOLD)
	var txt := ""
	var col := UITheme.TEXT_MUTED
	match clock.phase:
		SimClock.Phase.PREOPEN:
			txt = "SETTING UP"
			col = UITheme.INFO
		SimClock.Phase.OPEN:
			txt = "OPEN"
			col = UITheme.POSITIVE
		SimClock.Phase.CLOSING:
			txt = "CLOSING"
			col = Palette.MARIGOLD
		SimClock.Phase.CLOSED:
			txt = "CLOSED"
	_phase.text = txt
	_phase.add_theme_color_override("font_color", col)
	_people.text = str(Game.customers.in_store_count() if Game.customers else 0)
	_rep.text = Fmt.percent(Game.reputation)
