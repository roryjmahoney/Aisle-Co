class_name GameUI
extends Control
## UI root. Lays out the HUD around the edges so the store stays visible,
## keeps at most one tool window open at a time, and routes hotkeys.

var main: Node3D
var build: BuildController
var selection: SelectionController

var status: StatusBar
var speed: SpeedBar
var dock: Dock
var toasts: Toasts
var hint: CursorHint
var build_panel: BuildPanel
var inspector: Inspector
var windows: Dictionary = {}
var day_report: DayReport
var pause_menu: PauseMenu
var _modal_dim: ColorRect
var _active := ""
var thumbs: Thumbnails


func setup(p_main: Node3D, p_build: BuildController, p_sel: SelectionController) -> void:
	main = p_main
	build = p_build
	selection = p_sel


func _ready() -> void:
	name = "GameUI"
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbs = Thumbnails.new()
	add_child(thumbs)

	status = StatusBar.new()
	_anchor(status, Control.PRESET_TOP_LEFT, Vector2(16, 14))
	speed = SpeedBar.new()
	_anchor(speed, Control.PRESET_TOP_RIGHT, Vector2(-16, 14))
	speed.menu_pressed.connect(_open_pause)
	toasts = Toasts.new()
	add_child(toasts)
	toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toasts.position.y = 86
	toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH

	dock = Dock.new()
	_anchor(dock, Control.PRESET_CENTER_BOTTOM, Vector2(0, -14))
	dock.tool_selected.connect(_on_tool)

	build_panel = BuildPanel.new()
	build_panel.thumbs = thumbs
	build_panel.visible = false
	_anchor(build_panel, Control.PRESET_CENTER_BOTTOM, Vector2(0, -96))
	build_panel.pick.connect(func(d): build.begin_place(d))
	build_panel.tool.connect(_on_build_tool)

	inspector = Inspector.new()
	inspector.visible = false
	_anchor(inspector, Control.PRESET_TOP_RIGHT, Vector2(-16, 84))
	inspector.close_requested.connect(func(): selection.select(null))
	inspector.move_requested.connect(func(uid):
		selection.select(null)
		_set_active("build")
		build.begin_move(uid))
	inspector.sell_requested.connect(func(uid):
		build.bulldoze(uid))

	for spec in [["stock", StockWindow], ["prices", PricesWindow], ["staff", StaffWindow], ["finance", FinanceWindow]]:
		var w: PanelContainer = spec[1].new()
		w.visible = false
		_anchor(w, Control.PRESET_TOP_LEFT, Vector2(16, 96))
		w.close_requested.connect(func(): _set_active(""))
		windows[spec[0]] = w
	windows.staff.select_requested.connect(func(s): selection.select(s))

	hint = CursorHint.new()
	add_child(hint)
	build.hint_changed.connect(hint.show_hint)
	build.mode_changed.connect(_on_build_mode)

	_modal_dim = ColorRect.new()
	_modal_dim.color = Color(0.03, 0.07, 0.06, 0.5)
	_modal_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_dim.visible = false
	_modal_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal_dim)
	day_report = DayReport.new()
	day_report.visible = false
	_anchor(day_report, Control.PRESET_CENTER, Vector2.ZERO)
	day_report.grow_horizontal = Control.GROW_DIRECTION_BOTH
	day_report.grow_vertical = Control.GROW_DIRECTION_BOTH
	day_report.next_day.connect(_on_next_day)

	pause_menu = PauseMenu.new()
	pause_menu.visible = false
	add_child(pause_menu)
	pause_menu.closed.connect(_close_pause)

	Game.selection_changed.connect(_on_selection)
	Game.day_report_ready.connect(_on_day_report)
	Game.settings.changed.connect(_on_setting)
	_apply_all_settings()


func _anchor(c: Control, preset: int, offset: Vector2) -> void:
	add_child(c)
	c.set_anchors_and_offsets_preset(preset)
	match preset:
		Control.PRESET_TOP_RIGHT:
			c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_BOTTOM:
			c.grow_horizontal = Control.GROW_DIRECTION_BOTH
			c.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER:
			c.grow_horizontal = Control.GROW_DIRECTION_BOTH
			c.grow_vertical = Control.GROW_DIRECTION_BOTH
	c.position += offset


# --- Tools & windows ---------------------------------------------------------

func _on_tool(id: String) -> void:
	Sfx.play("ui_click", -4.0)
	match id:
		"walls":
			Game.say(main.cycle_wall_mode(), "info")
		"undo":
			build.undo()
		_:
			_set_active("" if _active == id else id)


func _set_active(id: String) -> void:
	if _active == id:
		return
	if _active == "build":
		build.cancel()
		build_panel.visible = false
		main.build_active = false
	elif windows.has(_active):
		windows[_active].visible = false
		Sfx.play("ui_close", -10.0)
	_active = id
	dock.set_active(id)
	if id == "build":
		build_panel.visible = true
		main.build_active = true
		UIKit.slide_in(build_panel, Vector2(0, 14))
		selection.select(null)
	elif windows.has(id):
		var w: Control = windows[id]
		w.visible = true
		if w.has_method("_refresh"):
			w._refresh()
		# Autowrapped labels report a tall minimum size before their first
		# layout; shrink-wrap the window once it has real widths.
		w.reset_size()
		w.call_deferred("reset_size")
		UIKit.slide_in(w, Vector2(-10, 0))
		Sfx.play("ui_open", -10.0)


func _on_build_tool(id: String) -> void:
	match id:
		"move":
			if build.mode == BuildController.Mode.MOVE:
				build.cancel()
			else:
				build.cancel(false)
				build.mode = BuildController.Mode.NONE
				_pick_move = true
				Game.say("Click a fixture to pick it up", "info")
				build_panel.set_tool_state(BuildController.Mode.MOVE, null)
		"sell":
			if build.mode == BuildController.Mode.BULLDOZE:
				build.cancel()
			else:
				build.begin_bulldoze()


var _pick_move := false


func _on_build_mode(mode: int) -> void:
	build_panel.set_tool_state(mode, build.def)
	dock.set_undo_enabled(build.can_undo())
	if mode != BuildController.Mode.NONE and _active != "build":
		_set_active("build")


func _on_selection(sel: Variant) -> void:
	if sel == null:
		inspector.visible = false
		return
	if _pick_move and sel is Fixture:
		_pick_move = false
		var uid: int = sel.uid
		selection.select(null)
		build.begin_move(uid)
		return
	inspector.visible = true
	inspector.show_for(sel)
	UIKit.slide_in(inspector, Vector2(10, 0))


# --- Modals ------------------------------------------------------------------

func _on_day_report(r: Dictionary) -> void:
	_set_active("")
	selection.select(null)
	day_report.show_report(r)
	day_report.visible = true
	_modal_dim.visible = true
	day_report.modulate.a = 0.0
	# Measure after one layout pass so wrapped text has its real height.
	await get_tree().process_frame
	day_report.reset_size()
	day_report.position = ((get_viewport_rect().size - day_report.size) * 0.5).round()
	UIKit.slide_in(day_report, Vector2(0, 16), 0.28)
	Sfx.play("day_end", -4.0)


func _on_next_day() -> void:
	day_report.visible = false
	_modal_dim.visible = false
	Game.start_next_day()
	Sfx.play("ui_click")


func _open_pause() -> void:
	Game.modal_open = true
	pause_menu.open()


func _close_pause() -> void:
	pause_menu.visible = false
	Game.modal_open = false


# --- Hotkeys ---------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if day_report.visible or pause_menu.visible:
		return
	if event.is_action_pressed(&"cancel"):
		if build.is_active():
			return   # BuildController handles its own Esc first
		if _active != "":
			_set_active("")
		elif selection.selected != null:
			selection.select(null)
		else:
			_open_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_build"):
		_set_active("" if _active == "build" else "build")
	elif event.is_action_pressed(&"open_orders"):
		_set_active("" if _active == "stock" else "stock")
	elif event.is_action_pressed(&"open_staff"):
		_set_active("" if _active == "staff" else "staff")
	elif event.is_action_pressed(&"bulldoze"):
		_set_active("build")
		build.begin_bulldoze()
	elif event.is_action_pressed(&"toggle_walls"):
		Game.say(main.cycle_wall_mode(), "info")
	elif event.is_action_pressed(&"undo"):
		build.undo()
	elif event.is_action_pressed(&"pause"):
		Game.toggle_pause()
	elif event.is_action_pressed(&"speed_1"):
		Game.set_speed(1)
	elif event.is_action_pressed(&"speed_2"):
		Game.set_speed(2)
	elif event.is_action_pressed(&"speed_3"):
		Game.set_speed(4)
	elif event.is_action_pressed(&"toggle_top_down"):
		main.rig.toggle_top_down()


func _process(_d: float) -> void:
	dock.set_undo_enabled(build.can_undo())


# --- Settings ----------------------------------------------------------------------

func _apply_all_settings() -> void:
	for k in Game.settings.values:
		_on_setting(k)


func _on_setting(key: String) -> void:
	var s := Game.settings
	var rig: CameraRig = main.rig
	match key:
		"pan_speed": rig.pan_speed = s.get_value(key)
		"orbit_sensitivity": rig.orbit_sensitivity = s.get_value(key)
		"zoom_speed": rig.zoom_speed = s.get_value(key)
		"invert_orbit": rig.invert_orbit = s.get_value(key)
		"master_volume", "sfx_volume", "music_volume", "ambience_volume":
			Sfx.apply_volumes(s)
		"shadows", "ssao":
			main.atmosphere.apply_settings(s)
		"fullscreen":
			if not DisplayServer.get_name() == "headless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if s.get_value(key) else DisplayServer.WINDOW_MODE_WINDOWED)
