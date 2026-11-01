class_name Palette
extends RefCounted
## The single source of truth for colour in Aisle & Co.
##
## Nothing in the game should invent an ad-hoc colour. Environment, fixtures,
## packaging and UI all draw from these named swatches so the whole store
## reads as one deliberate, cohesive place. See docs/ART_DIRECTION.md.

# --- Core identity --------------------------------------------------------
const PINE := Color("1d3b33")          # deep grocer green, near-ink
const GROCER := Color("2f7a57")        # signature storefront green
const LEAF := Color("5fa86f")          # brighter living green
const MINT := Color("bfe6d2")          # floor tile, soft highlights
const SNOW := Color("f4f7f2")          # cool white (never cream)
const TOMATO := Color("e2553a")        # warm red accent
const MARIGOLD := Color("f2b33d")      # price tags, selection, primary action
const SKY := Color("8cc8dc")           # cool accent, chilled goods
const PLUM := Color("74405f")          # deep packaging accent
const INK := Color("142120")           # functional dark contrast

# --- Architecture -----------------------------------------------------------
const BRICK := Color("b85b3f")
const BRICK_DARK := Color("98472f")
const MORTAR := Color("d9d6cf")
const PLASTER := Color("eef3ee")
const WAINSCOT := Color("2f7a57")
const TRIM := Color("1d3b33")
const CONCRETE := Color("b8bcb6")
const CONCRETE_DARK := Color("9a9f99")
const ASPHALT := Color("3b4045")
const ROAD_PAINT := Color("f3efe2")
const GRASS := Color("7db36a")
const GRASS_DARK := Color("5d9452")
const SOIL := Color("6a4b3a")
const PLINTH := Color("1b2d29")

# --- Materials --------------------------------------------------------------
const WOOD := Color("c98b55")
const WOOD_DARK := Color("8e5a34")
const STEEL := Color("c9cfd2")
const STEEL_DARK := Color("4b555a")
const RUBBER := Color("2a2f33")
const GLASS := Color(0.78, 0.9, 0.93, 0.22)
const CARDBOARD := Color("c49a63")
const CARDBOARD_DARK := Color("a37c4b")
const LAMP_WARM := Color("ffd9a0")
const LAMP_COOL := Color("e8f6ff")

# --- People -----------------------------------------------------------------
const SKIN_TONES: Array[Color] = [
	Color("f2d3bd"), Color("e7b896"), Color("c98e67"),
	Color("a26a45"), Color("7a4a2f"), Color("553220"),
]
const HAIR_TONES: Array[Color] = [
	Color("2b211c"), Color("4a3326"), Color("7a5236"),
	Color("c4934f"), Color("9a9a96"), Color("b5462c"),
]
const CLOTHING: Array[Color] = [
	Color("e2553a"), Color("f2b33d"), Color("8cc8dc"), Color("74405f"),
	Color("5fa86f"), Color("3e5f8a"), Color("f4f7f2"), Color("d98aa0"),
	Color("2a3e52"), Color("c98b55"),
]
const STAFF_SHIRT := Color("2f7a57")
const STAFF_APRON := Color("1d3b33")


static func shade(c: Color, amount: float) -> Color:
	## Darken (negative) or lighten (positive) while preserving hue.
	if amount >= 0.0:
		return c.lerp(Color(1, 1, 1, c.a), amount)
	return c.lerp(Color(0, 0, 0, c.a), -amount)


static func jitter(c: Color, rng: RandomNumberGenerator, amount: float = 0.04) -> Color:
	## Small, believable variation so repeated objects don't look cloned.
	var v := rng.randf_range(-amount, amount)
	return Color(clampf(c.r + v, 0, 1), clampf(c.g + v, 0, 1), clampf(c.b + v, 0, 1), c.a)
