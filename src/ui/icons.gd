class_name Icons
extends RefCounted
## Original line icons on a 24-unit grid, 1.75 stroke, rounded joins. Drawn as
## SVG paths and rasterised at runtime at whatever size/colour is needed, so
## they stay crisp at any UI scale and match the type weight.

const PATHS := {
	"shelf": "M4 3v18M20 3v18M4 7h16M4 12h16M4 17h16M7 5.5h3M12 10.5h4M7 15.5h5",
	"gondola": "M3 20h18M5 20V8l7-4 7 4v12M12 4v16M5 12h14M5 16h14",
	"fridge": "M6 3h12a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM12 3v18M9.5 9v3M14.5 9v3",
	"register": "M4 20h16M5 20l1-7h12l1 7M8 13V9h8v4M9 6h6v3H9zM9 16.5h2M13 16.5h2",
	"rack": "M4 3v18M20 3v18M4 8h16M4 14h16M4 20h16M7 5h4v3H7zM13 11h4v3h-4zM7 17h5v3H7z",
	"plant": "M8 21h8l1-6H7zM12 15V9M12 11c-3 0-5-2-5-5 3 0 5 2 5 5zM12 9c0-3 2-5 5-5 0 3-2 5-5 5z",
	"lamp": "M12 21v-9M8 21h8M8 4h8l3 8H5zM10 12v2",
	"basket": "M4 9h16l-1.5 10a1 1 0 0 1-1 1h-11a1 1 0 0 1-1-1zM8 9l3-5M16 9l-3-5M9 13v3M15 13v3M12 13v3",
	"sign": "M7 21l3-17h4l3 17M9 13h6M8.5 17h7",
	"build": "M14 4l6 6-3 3-6-6zM11 7L3 15v3h3l8-8M15 15l5 5",
	"bulldoze": "M3 17h11v3H3zM14 17l3-8h3M5 17V12h7l2 5M19 9l2-3",
	"move": "M12 3v18M3 12h18M12 3l-3 3M12 3l3 3M12 21l-3-3M12 21l3-3M3 12l3-3M3 12l3 3M21 12l-3-3M21 12l-3 3",
	"rotate": "M20 12a8 8 0 1 1-2.3-5.6M20 4v4h-4",
	"pause": "M8 5v14M16 5v14",
	"play": "M7 4.5v15l12-7.5z",
	"fast": "M3 5v14l8-7zM12 5v14l8-7z",
	"faster": "M2 6v12l6-6zM9 6v12l6-6zM16 6v12l6-6z",
	"truck": "M2 6h12v10H2zM14 9h4l3 3v4h-7M6 19a2 2 0 1 0 0-.01M17 19a2 2 0 1 0 0-.01",
	"box": "M3 7l9-4 9 4v10l-9 4-9-4zM3 7l9 4 9-4M12 11v10M7.5 5l9 4",
	"staff": "M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM2.5 20c.5-4 3-6 6.5-6s6 2 6.5 6M16 4.5a3.5 3.5 0 0 1 0 6.5M18 14c2 .8 3.3 2.8 3.5 6",
	"tag": "M3 12V4a1 1 0 0 1 1-1h8l9 9-9 9zM7.5 7.5h.01",
	"chart": "M4 20V4M4 20h16M8 16v-4M12 16V8M16 16v-6M20 16v-9",
	"settings": "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z",
	"close": "M6 6l12 12M18 6L6 18",
	"walls": "M3 20h18M4 20V9h7v11M13 20v-6h7v6M4 13h7M4 16.5h7",
	"coin": "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM14.5 9.5c-.5-1-1.5-1.5-2.5-1.5-1.5 0-2.5.8-2.5 2s1 1.7 2.5 2 2.5.8 2.5 2-1 2-2.5 2c-1 0-2-.5-2.5-1.5M12 6.5V8M12 16v1.5",
	"clock": "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v5l3 2",
	"star": "M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8-5.2-2.8-5.2 2.8 1-5.8-4.3-4.1 5.9-.9z",
	"check": "M5 12.5l4.5 4.5L19 7",
	"warning": "M12 4l9 16H3zM12 10v4M12 17h.01",
	"plus": "M12 5v14M5 12h14",
	"minus": "M5 12h14",
	"undo": "M9 14L4 9l5-5M4 9h10a6 6 0 0 1 0 12h-3",
	"person": "M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4.5 21c.6-4.4 3.6-7 7.5-7s6.9 2.6 7.5 7",
	"store": "M3 10h18M4 10l1.5-6h13L20 10M5 10v10h14V10M10 20v-5h4v5M3 10q1.5 2.5 3 0 1.5 2.5 3 0 1.5 2.5 3 0 1.5 2.5 3 0 1.5 2.5 3 0 1.5 2.5 3 0",
	"sun": "M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4",
	"moon": "M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z",
	"door": "M5 21V4a1 1 0 0 1 1-1h12a1 1 0 0 1 1 1v17M3 21h18M15 12h.01",
	"save": "M5 3h11l3 3v14a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM8 3v5h7V3M8 21v-7h8v7",
	"folder": "M3 6a1 1 0 0 1 1-1h5l2 2h9a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z",
	"exit": "M15 4h3a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-3M10 17l5-5-5-5M15 12H3",
	"chevron_right": "M9 6l6 6-6 6",
	"chevron_left": "M15 6l-6 6 6 6",
	"chevron_down": "M6 9l6 6 6-6",
	"restock": "M3 7l9-4 9 4v4M3 7v10l9 4M3 7l9 4 9-4M12 11v10M16 16h6M19 13v6",
	"smile": "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM8.5 14.5c1 1.3 2.2 2 3.5 2s2.5-.7 3.5-2M9 9.5h.01M15 9.5h.01",
	"frown": "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM8.5 16c1-1.3 2.2-2 3.5-2s2.5.7 3.5 2M9 9.5h.01M15 9.5h.01",
	"queue": "M5 8a2 2 0 1 0 0-4 2 2 0 0 0 0 4zM12 8a2 2 0 1 0 0-4 2 2 0 0 0 0 4zM19 8a2 2 0 1 0 0-4 2 2 0 0 0 0 4zM3 14h4M10 14h4M17 14h4M3 19h18",
}

static var _cache: Dictionary = {}


static func tex(icon: String, size: int = 20, color: Color = Color("eef3ec"), stroke: float = 1.75) -> Texture2D:
	var key := "%s_%d_%s_%.2f" % [icon, size, color.to_html(false), stroke]
	if _cache.has(key):
		return _cache[key]
	var path: String = PATHS.get(icon, PATHS["box"])
	var fill := "none"
	var svg := """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
<path d="%s" fill="%s" stroke="#%s" stroke-width="%.2f" stroke-linecap="round" stroke-linejoin="round"/></svg>""" % [
		path, fill, color.to_html(false), stroke]
	var img := Image.new()
	var scale := float(size) / 24.0
	var err := img.load_svg_from_string(svg, scale)
	if err != OK:
		push_warning("Icons: failed to render %s" % icon)
		img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t
