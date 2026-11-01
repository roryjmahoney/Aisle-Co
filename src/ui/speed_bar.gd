class_name SpeedBar
extends PanelContainer
## Top-right: open-early action, pause/speed segmented control, menu.

signal menu_pressed

var _buttons: Array[Button] = []
var _open_btn: Button


func _ready() -> void:
	var row := UIKit.hbox(UIKit.GAP_S)
	add_child(row)
	_open_btn = UIKit.button("Open doors", "door", "Primary")
	_open_btn.tooltip_text = "Skip the setup hour and start trading now"
	_open_btn.pressed.connect(func():
		Game.clock.open_now()
		Sfx.play("ui_click"))
	row.add_child(_open_btn)
	var seg := UIKit.hbox(2)
	var group := ButtonGroup.new()
	var specs := [["pause", "Pause  (Space)", 0], ["play", "Normal speed  (1)", 1], ["fast", "Fast  (2)", 2], ["faster", "Fastest  (3)", 4]]
	for sp in specs:
		var b := UIKit.icon_button(sp[0], sp[1], "Segment")
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(38, 32)
		var speed: int = sp[2]
		b.pressed.connect(func():
			Game.set_speed(speed)
			Sfx.play("ui_click", -4.0))
		b.set_meta("speed", speed)
		seg.add_child(b)
		_buttons.append(b)
	row.add_child(seg)
	row.add_child(UIKit.vsep())
	var menu := UIKit.icon_button("settings", "Menu  (Esc)")
	menu.pressed.connect(func(): menu_pressed.emit())
	row.add_child(menu)
	Game.speed_changed.connect(_sync)
	_sync(Game.speed)


func _sync(speed: int) -> void:
	for b in _buttons:
		b.set_pressed_no_signal(b.get_meta("speed") == speed)
	# Icons on the selected segment switch to ink so they read on marigold.
	for b in _buttons:
		var icon_name: String = ["pause", "play", "fast", "", "faster"][b.get_meta("speed")]
		b.icon = Icons.tex(icon_name, 20 * UITheme.ICON_RES, Color.WHITE)


func _process(_d: float) -> void:
	_open_btn.visible = Game.clock.phase == SimClock.Phase.PREOPEN
