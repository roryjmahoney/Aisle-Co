class_name Fonts
extends RefCounted
## Typography. Two families, deliberately paired:
##  * Bricolage Grotesque — condensed, heavy, a little quirky. Reads like
##    hand-painted grocer signage. Used for titles, figures and 3D signs.
##  * Figtree — warm, open geometric sans for everything you read at length.
## Both are SIL OFL (see assets/fonts/).

const DISPLAY_PATH := "res://assets/fonts/BricolageGrotesque.ttf"
const BODY_PATH := "res://assets/fonts/Figtree.ttf"

static var _cache: Dictionary = {}


static func display(weight: int = 800, width: int = 82) -> FontVariation:
	return _var(DISPLAY_PATH, weight, {"wdth": width, "opsz": 48})


static func body(weight: int = 500) -> FontVariation:
	return _var(BODY_PATH, weight, {})


static func numeric(weight: int = 600) -> FontVariation:
	## Body face with tabular figures so ticking money doesn't jitter.
	var key := "num_%d" % weight
	if _cache.has(key):
		return _cache[key]
	var f := body(weight).duplicate() as FontVariation
	var ts := TextServerManager.get_primary_interface()
	f.opentype_features = {ts.name_to_tag("tnum"): 1}
	_cache[key] = f
	return f


static func _var(path: String, weight: int, axes: Dictionary) -> FontVariation:
	var key := "%s_%d_%s" % [path, weight, str(axes)]
	if _cache.has(key):
		return _cache[key]
	var base: FontFile = load(path)
	var f := FontVariation.new()
	f.base_font = base
	var ts := TextServerManager.get_primary_interface()
	var coords := {ts.name_to_tag("wght"): weight}
	for k in axes:
		coords[ts.name_to_tag(k)] = axes[k]
	f.variation_opentype = coords
	_cache[key] = f
	return f
