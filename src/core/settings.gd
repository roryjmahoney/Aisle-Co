class_name Settings
extends RefCounted
## Player preferences, persisted to user://settings.cfg (separate from saves).

signal changed(key: String)

const PATH := "user://settings.cfg"

var values := {
	"pan_speed": 1.0,
	"orbit_sensitivity": 1.0,
	"zoom_speed": 1.0,
	"invert_orbit": false,
	"edge_scroll": false,
	"master_volume": 0.8,
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	"ambience_volume": 0.6,
	"ui_scale": 1.0,
	"shadows": 2,          # 0 off, 1 low, 2 high
	"msaa": 1,             # 0 off, 1 2x, 2 4x
	"ssao": true,
	"fullscreen": false,
	"autosave": true,
}


func get_value(key: String) -> Variant:
	return values.get(key)


func set_value(key: String, v: Variant) -> void:
	if values.get(key) == v:
		return
	values[key] = v
	changed.emit(key)
	save_settings()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in values:
		if cf.has_section_key("settings", k):
			var v: Variant = cf.get_value("settings", k)
			if typeof(v) == typeof(values[k]) or (typeof(values[k]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				values[k] = v


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("settings", k, values[k])
	cf.save(PATH)
