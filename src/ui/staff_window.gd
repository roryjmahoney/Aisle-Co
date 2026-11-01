class_name StaffWindow
extends PanelContainer
## Hiring and the current roster.

signal close_requested
signal select_requested(s: Staff)

var _list: VBoxContainer
var _wages: Label


func _ready() -> void:
	custom_minimum_size = Vector2(520, 0)
	var v := UIKit.vbox(UIKit.GAP_M)
	add_child(v)
	v.add_child(UIKit.window_header("Staff", "staff", func(): close_requested.emit()))
	var hire_row := UIKit.hbox(UIKit.GAP_S)
	for role in [Staff.Role.CASHIER, Staff.Role.STOCKER]:
		var card := UIKit.panel("Card")
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := UIKit.vbox(6)
		card.add_child(cv)
		var t := UIKit.hbox(8)
		t.add_child(UIKit.icon("register" if role == Staff.Role.CASHIER else "box", 18, Palette.MARIGOLD))
		t.add_child(UIKit.label(Staff.ROLE_NAMES[role], "Subheading"))
		cv.add_child(t)
		var desc := UIKit.label("Keeps a till open all day, and scans a little faster than you." if role == Staff.Role.CASHIER
				else "Carries cases from the stockroom and keeps the shelves full.", "Muted")
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(200, 0)
		cv.add_child(desc)
		var b := UIKit.button("Hire  ·  %s/day" % Fmt.money(Staff.WAGES[role], false), "plus", "Primary")
		var r: int = role
		b.pressed.connect(func():
			Game.staff.hire(r)
			Sfx.play("coins")
			_refresh())
		cv.add_child(b)
		hire_row.add_child(card)
	v.add_child(hire_row)
	v.add_child(UIKit.caption("Team"))
	_list = UIKit.vbox(6)
	v.add_child(_list)
	_wages = UIKit.label("", "Muted")
	v.add_child(_wages)
	Game.staff.roster_changed.connect(_refresh)
	_refresh()


func _process(_d: float) -> void:
	if visible and Engine.get_process_frames() % 15 == 0:
		_refresh_status()


func _refresh() -> void:
	if _list == null:
		return
	UIKit.clear(_list)
	for s in Game.staff.staff:
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.theme_type_variation = "Quiet"
		row.custom_minimum_size = Vector2(0, 40)
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var h := UIKit.hbox(10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		h.add_child(UIKit.icon("person", 18, Palette.TOMATO if s.role == Staff.Role.OWNER else UITheme.TEXT_MUTED))
		var n := UIKit.label(s.display_name, "Subheading")
		n.custom_minimum_size = Vector2(90, 0)
		h.add_child(n)
		h.add_child(UIKit.label(Staff.ROLE_NAMES[s.role], "Muted"))
		var st := UIKit.label(s.status_text(), "Muted")
		st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		st.name = "Status"
		h.add_child(st)
		row.add_child(h)
		row.set_meta("staff", s)
		row.set_meta("status", st)
		row.pressed.connect(func(): select_requested.emit(s))
		_list.add_child(row)
	_wages.text = "Wages: %s per day" % Fmt.money(Game.staff.wages_per_day(), false)


func _refresh_status() -> void:
	for row in _list.get_children():
		var s: Staff = row.get_meta("staff")
		(row.get_meta("status") as Label).text = s.status_text()
