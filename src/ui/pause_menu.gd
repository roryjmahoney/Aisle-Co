class_name PauseMenu
extends Control
## Esc menu: resume, save, load, settings, quit. Dims the game behind it.

signal closed

var _main_panel: PanelContainer
var _settings_panel: PanelContainer
var _load_btn: Button
var _save_info: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.07, 0.06, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var stack := Control.new()
	center.add_child(stack)
	_main_panel = _build_main()
	center.add_child(_main_panel)
	_settings_panel = _build_settings()
	_settings_panel.visible = false
	center.add_child(_settings_panel)
	stack.queue_free()


func open() -> void:
	visible = true
	_main_panel.visible = true
	_settings_panel.visible = false
	_load_btn.disabled = not SaveManager.exists("slot1")
	_update_save_info()
	UIKit.slide_in(_main_panel, Vector2(0, 10))


func _update_save_info() -> void:
	if SaveManager.exists("slot1"):
		var d := SaveManager.read("slot1")
		if not d.has("error"):
			_save_info.text = "Saved game: day %d  ·  %s" % [int(d.clock.day), String(d.get("saved_at", "")).replace("T", " ")]
			return
	_save_info.text = "No saved game yet"


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"cancel"):
		if _settings_panel.visible:
			_settings_panel.visible = false
			_main_panel.visible = true
		else:
			closed.emit()
		get_viewport().set_input_as_handled()


func _build_main() -> PanelContainer:
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(320, 0)
	var v := UIKit.vbox(UIKit.GAP_S)
	p.add_child(v)
	var brand := UIKit.label("Aisle & Co.", "Title")
	brand.add_theme_font_size_override("font_size", 30)
	brand.add_theme_color_override("font_color", Palette.MARIGOLD)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(brand)
	var tag := UIKit.caption("Paused")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	v.add_child(UIKit.gap(6))
	var resume := UIKit.button("Resume", "play", "Primary")
	resume.pressed.connect(func(): closed.emit())
	v.add_child(resume)
	var save := UIKit.button("Save game", "save")
	save.pressed.connect(func():
		var err := SaveManager.save("slot1")
		if err == "":
			Game.say("Game saved", "positive")
			Sfx.play("coins")
		else:
			Game.say(err, "warning")
		_load_btn.disabled = not SaveManager.exists("slot1")
		_update_save_info())
	v.add_child(save)
	_load_btn = UIKit.button("Load game", "folder")
	_load_btn.pressed.connect(func():
		var d := SaveManager.read("slot1")
		if d.has("error"):
			Game.say(d.error, "warning")
			return
		var msg := SaveManager.apply(d)
		Game.say(msg if msg != "" else "Welcome back — day %d" % Game.clock.day, "warning" if msg != "" else "positive")
		closed.emit())
	v.add_child(_load_btn)
	var settings := UIKit.button("Settings", "settings")
	settings.pressed.connect(func():
		_main_panel.visible = false
		_settings_panel.visible = true
		UIKit.slide_in(_settings_panel, Vector2(0, 10)))
	v.add_child(settings)
	v.add_child(HSeparator.new())
	var quit := UIKit.button("Save & quit", "exit", "Quiet")
	quit.pressed.connect(func():
		SaveManager.save("slot1")
		get_tree().quit())
	v.add_child(quit)
	_save_info = UIKit.label("", "Muted")
	_save_info.add_theme_font_size_override("font_size", 11)
	_save_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_save_info)
	for b in v.get_children():
		if b is Button:
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size.y = 38
	return p


func _build_settings() -> PanelContainer:
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(440, 0)
	var v := UIKit.vbox(UIKit.GAP_M)
	p.add_child(v)
	v.add_child(UIKit.window_header("Settings", "settings", func():
		_settings_panel.visible = false
		_main_panel.visible = true))
	var s := Game.settings
	v.add_child(UIKit.caption("Camera"))
	v.add_child(_slider("Pan speed", "pan_speed", 0.4, 2.0))
	v.add_child(_slider("Orbit sensitivity", "orbit_sensitivity", 0.4, 2.0))
	v.add_child(_slider("Zoom speed", "zoom_speed", 0.4, 2.0))
	v.add_child(_toggle("Invert orbit", "invert_orbit"))
	v.add_child(UIKit.caption("Sound"))
	v.add_child(_slider("Master", "master_volume", 0.0, 1.0))
	v.add_child(_slider("Effects", "sfx_volume", 0.0, 1.0))
	v.add_child(_slider("Ambience", "ambience_volume", 0.0, 1.0))
	v.add_child(_slider("Music", "music_volume", 0.0, 1.0))
	v.add_child(UIKit.caption("Graphics"))
	var sh := OptionButton.new()
	sh.focus_mode = Control.FOCUS_NONE
	for o in ["Off", "Low", "High"]:
		sh.add_item(o)
	sh.select(int(s.get_value("shadows")))
	sh.item_selected.connect(func(i): s.set_value("shadows", i))
	var shr := UIKit.hbox()
	var shl := UIKit.label("Shadows", "Body")
	shl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shr.add_child(shl)
	shr.add_child(sh)
	v.add_child(shr)
	v.add_child(_toggle("Ambient occlusion", "ssao"))
	v.add_child(_toggle("Fullscreen", "fullscreen"))
	v.add_child(UIKit.caption("Game"))
	v.add_child(_toggle("Autosave at the end of each day", "autosave"))
	return p


func _slider(text: String, key: String, lo: float, hi: float) -> Control:
	var h := UIKit.hbox(UIKit.GAP_M)
	var l := UIKit.label(text, "Body")
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = 0.05
	sl.value = float(Game.settings.get_value(key))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.focus_mode = Control.FOCUS_NONE
	var val := UIKit.label("", "Number")
	val.custom_minimum_size = Vector2(44, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var fmt := func(x: float) -> String:
		return Fmt.percent(x) if hi <= 1.0 else "%.1f×" % x
	val.text = fmt.call(sl.value)
	sl.value_changed.connect(func(x):
		val.text = fmt.call(x)
		Game.settings.set_value(key, x))
	h.add_child(sl)
	h.add_child(val)
	return h


func _toggle(text: String, key: String) -> Control:
	var c := CheckButton.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.button_pressed = bool(Game.settings.get_value(key))
	c.toggled.connect(func(on): Game.settings.set_value(key, on))
	return c
