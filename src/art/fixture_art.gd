class_name FixtureArt
extends RefCounted
## Builds the 3D models for buildable fixtures.
##
## Every model is authored in the fixture's local space: centred on its
## footprint, front facing +Z, floor at y = 0. Dimensions come from the
## FixtureDef so the simulation and the art can never disagree about where a
## shelf tier is or how deep it is.
##
## Returns a Dictionary:
##   mesh     : ArrayMesh   — the static body of the fixture
##   slots    : Array       — per shelf tier {origin: Vector3 (front-centre of
##                            the deck, local), facing: 1 or -1}
##   parts    : Dictionary  — named extra meshes that animate (doors, etc.)
##   lights   : Array       — {pos, color, energy, range}

const C := MeshKit.Ch

static var _cache: Dictionary = {}


static func build(def: FixtureDef) -> Dictionary:
	if _cache.has(def.id):
		return _cache[def.id]
	var out: Dictionary
	match def.art:
		&"shelf_wall":
			out = _shelf(def, false)
		&"shelf_island":
			out = _shelf(def, true)
		&"fridge":
			out = _fridge(def)
		&"checkout":
			out = _checkout(def)
		&"storage_rack":
			out = _rack(def)
		&"plant":
			out = _plant(def)
		&"floor_lamp":
			out = _lamp(def)
		&"basket_stand":
			out = _baskets(def)
		&"chalkboard":
			out = _chalkboard(def)
		_:
			push_error("FixtureArt: no builder for '%s'" % def.art)
			out = _fallback(def)
	_cache[def.id] = out
	return out


static func _result(k: MeshKit) -> Dictionary:
	return {"mesh": k.build(), "slots": [], "parts": {}, "lights": [], "labels": []}


# --- Shelving ----------------------------------------------------------------

static func _shelf(def: FixtureDef, island: bool) -> Dictionary:
	var k := MeshKit.new()
	var w := def.footprint.x * StoreGrid.CELL
	var d := def.footprint.y * StoreGrid.CELL
	var top := def.height - (0.0 if island else 0.22)
	var deck_d := def.slot_size.z
	var inner_w := def.slot_size.x
	var gable_t := 0.05
	var frame := Palette.GROCER
	var kick := Palette.PINE
	var back := Palette.shade(Palette.SNOW, -0.05)

	# Kick plinth, recessed so the gables read as legs.
	k.box(Vector3(0, 0.07, 0), Vector3(w - 0.08, 0.14, d - 0.1), kick, C.SATIN, 0.012)
	# Gables (end panels) with a softly rounded front edge.
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * (w * 0.5 - gable_t * 0.5 - 0.005), top * 0.5, 0),
				Vector3(gable_t, top, d - 0.02), frame, C.SATIN, 0.014, 2)
	# Back panel / spine.
	if island:
		k.box(Vector3(0, top * 0.5 + 0.06, 0), Vector3(inner_w + 0.02, top - 0.12, 0.05), back, C.PAINT, 0.008)
	else:
		k.box(Vector3(0, top * 0.5 + 0.06, -d * 0.5 + 0.03), Vector3(inner_w + 0.02, top - 0.12, 0.03), back, C.PAINT, 0.006)
	# Top cap.
	k.box(Vector3(0, top + 0.02, 0), Vector3(w + 0.01, 0.04, d), kick, C.SATIN, 0.014, 2)

	var res := {}
	var slots: Array = []
	var sides := [1.0, -1.0] if island else [1.0]
	for side in sides:
		var front_z: float = side * (d * 0.5 - 0.02)
		var deck_cz: float = front_z - side * deck_d * 0.5
		if not island:
			deck_cz = -d * 0.5 + 0.045 + deck_d * 0.5
			front_z = deck_cz + deck_d * 0.5
		for y in def.slot_heights:
			k.box(Vector3(0, y - 0.013, deck_cz), Vector3(inner_w, 0.026, deck_d), Palette.WOOD, C.WOOD, 0.006)
			# White ticket strip along the deck edge (where price tags live).
			k.box(Vector3(0, y - 0.006, front_z + side * 0.006), Vector3(inner_w, 0.04, 0.012),
					Palette.SNOW, C.SATIN, 0.003)
			# Shelf brackets tucked under the deck at each end.
			for sx in [-1.0, 1.0]:
				k.box(Vector3(sx * (inner_w * 0.5 - 0.03), y - 0.05, deck_cz), Vector3(0.012, 0.06, deck_d * 0.9),
						Palette.STEEL_DARK, C.METAL)
			slots.append({"origin": Vector3(0, y, front_z), "facing": side,
					"deck_center": Vector3(0, y, deck_cz)})

	res = _result(k)
	res["slots"] = slots
	# Header board above wall shelving for the aisle/category label.
	if not island:
		var hk := MeshKit.new()
		for sx in [-1.0, 1.0]:
			hk.rod(Vector3(sx * 0.45, top + 0.04, -d * 0.5 + 0.08), Vector3(sx * 0.45, top + 0.12, -d * 0.5 + 0.08),
					0.008, Palette.STEEL_DARK, C.METAL, 6)
		hk.box(Vector3(0, top + 0.21, -d * 0.5 + 0.08), Vector3(1.05, 0.2, 0.03), Palette.PINE, C.SATIN, 0.01, 2)
		hk.box(Vector3(0, top + 0.21, -d * 0.5 + 0.096), Vector3(0.98, 0.15, 0.004), Palette.shade(Palette.PINE, 0.08), C.PAINT)
		res["mesh"] = _merge(res["mesh"], hk.build())
		res["labels"].append({"pos": Vector3(0, top + 0.21, -d * 0.5 + 0.1), "size": 0.10, "kind": "header"})
	else:
		# End-cap category strip on the top of the spine.
		var hk := MeshKit.new()
		hk.box(Vector3(0, top + 0.13, 0), Vector3(0.9, 0.18, 0.03), Palette.PINE, C.SATIN, 0.01, 2)
		res["mesh"] = _merge(res["mesh"], hk.build())
		res["labels"].append({"pos": Vector3(0, top + 0.13, 0.017), "size": 0.09, "kind": "header"})
		res["labels"].append({"pos": Vector3(0, top + 0.13, -0.017), "size": 0.09, "kind": "header", "flip": true})
	return res


# --- Chiller ---------------------------------------------------------------

static func _fridge(def: FixtureDef) -> Dictionary:
	var k := MeshKit.new()
	var w := def.footprint.x * StoreGrid.CELL - 0.04
	var h := def.height
	var back_z := -def.footprint.y * StoreGrid.CELL * 0.5 + 0.02
	var body_d := 0.78
	var front_z := back_z + body_d
	var cz := back_z + body_d * 0.5
	var body := Palette.SNOW
	var inner := Color("dfe8e6")

	# Shell: sides, top canopy, kick grille.
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * (w * 0.5 - 0.035), h * 0.5, cz), Vector3(0.07, h, body_d), body, C.SATIN, 0.016, 2)
	k.box(Vector3(0, h - 0.13, cz), Vector3(w, 0.26, body_d), body, C.SATIN, 0.016, 2)
	k.box(Vector3(0, 0.09, cz + 0.01), Vector3(w - 0.02, 0.18, body_d - 0.02), Palette.PINE, C.SATIN, 0.01)
	# Kick grille slats.
	for i in 9:
		var x := -w * 0.4 + i * (w * 0.8 / 8.0)
		k.box(Vector3(x, 0.09, front_z - 0.005), Vector3(0.012, 0.11, 0.01), Palette.shade(Palette.PINE, -0.3), C.PAINT)
	# Interior: back + floor + a vertical mullion behind the doors.
	k.box(Vector3(0, h * 0.5, back_z + 0.02), Vector3(w - 0.1, h - 0.3, 0.04), inner, C.SATIN)
	k.box(Vector3(0, 0.19, cz), Vector3(w - 0.12, 0.02, body_d - 0.08), inner, C.SATIN)
	# Wire decks.
	var slots: Array = []
	var deck_d := def.slot_size.z
	var deck_cz := back_z + 0.05 + deck_d * 0.5
	for y in def.slot_heights:
		k.box(Vector3(0, y - 0.01, deck_cz), Vector3(w - 0.14, 0.014, deck_d), Palette.STEEL, C.METAL, 0.004)
		k.box(Vector3(0, y + 0.012, deck_cz + deck_d * 0.5 - 0.004), Vector3(w - 0.14, 0.03, 0.008), Palette.STEEL, C.METAL)
		k.box(Vector3(0, y - 0.004, deck_cz + deck_d * 0.5 + 0.006), Vector3(w - 0.14, 0.03, 0.006), Palette.SKY, C.SATIN)
		slots.append({"origin": Vector3(0, y, deck_cz + deck_d * 0.5), "facing": 1.0,
				"deck_center": Vector3(0, y, deck_cz)})
	# Interior light strip under the canopy (self-lit).
	k.box(Vector3(0, h - 0.29, front_z - 0.08), Vector3(w - 0.16, 0.025, 0.04), Palette.LAMP_COOL, C.EMIT)
	# Canopy sign face.
	k.box(Vector3(0, h - 0.13, front_z + 0.004), Vector3(w - 0.24, 0.17, 0.01), Palette.SKY, C.SATIN, 0.004)

	var res := _result(k)
	res["slots"] = slots
	res["labels"].append({"pos": Vector3(0, h - 0.13, front_z + 0.012), "size": 0.085, "kind": "header",
			"text": "CHILLED", "color": Palette.PINE})
	# Doors are separate so they can swing open when someone reaches in.
	var door_w := (w - 0.12) * 0.5
	var door_h := h - 0.5
	var dk := MeshKit.new()
	var fw := 0.035
	var fc := Palette.STEEL_DARK
	dk.box(Vector3(door_w * 0.5, door_h * 0.5, 0), Vector3(door_w, fw, 0.035), fc, C.METAL, 0.006)
	dk.box(Vector3(door_w * 0.5, fw * 0.5, 0), Vector3(door_w, fw, 0.035), fc, C.METAL, 0.006)
	dk.box(Vector3(door_w * 0.5, door_h - fw * 0.5, 0), Vector3(door_w, fw, 0.035), fc, C.METAL, 0.006)
	dk.box(Vector3(fw * 0.5, door_h * 0.5, 0), Vector3(fw, door_h, 0.035), fc, C.METAL, 0.006)
	dk.box(Vector3(door_w - fw * 0.5, door_h * 0.5, 0), Vector3(fw, door_h, 0.035), fc, C.METAL, 0.006)
	dk.box(Vector3(door_w * 0.5, door_h * 0.5, 0), Vector3(door_w - fw, door_h - fw, 0.008), Palette.GLASS, C.GLASS)
	dk.box(Vector3(door_w - 0.07, door_h * 0.55, 0.045), Vector3(0.022, door_h * 0.5, 0.02), Palette.STEEL, C.METAL, 0.008)
	dk.box(Vector3(door_w - 0.07, door_h * 0.55 + door_h * 0.25 - 0.01, 0.028), Vector3(0.016, 0.016, 0.04), Palette.STEEL, C.METAL)
	dk.box(Vector3(door_w - 0.07, door_h * 0.55 - door_h * 0.25 + 0.01, 0.028), Vector3(0.016, 0.016, 0.04), Palette.STEEL, C.METAL)
	var door_mesh := dk.build()
	res["parts"]["doors"] = [
		{"mesh": door_mesh, "hinge": Vector3(-w * 0.5 + 0.07, 0.2, front_z + 0.02), "mirror": false},
		{"mesh": door_mesh, "hinge": Vector3(w * 0.5 - 0.07, 0.2, front_z + 0.02), "mirror": true},
	]
	res["lights"].append({"pos": Vector3(0, h * 0.55, front_z + 0.25), "color": Palette.LAMP_COOL,
			"energy": 0.35, "range": 1.4})
	return res


# --- Checkout --------------------------------------------------------------

static func _checkout(def: FixtureDef) -> Dictionary:
	# Footprint 3 x 4 cells (1.5 m x 2 m). Local column 0 (x < -0.25) is where
	# the cashier stands; the counter fills the rest; shoppers queue along +X.
	var k := MeshKit.new()
	var len_z := def.footprint.y * StoreGrid.CELL - 0.1
	var body_x0 := -0.22
	var body_x1 := 0.72
	var bw := body_x1 - body_x0
	var bx := (body_x0 + body_x1) * 0.5
	var top_h := 0.88

	# Cashier's anti-fatigue mat.
	k.box(Vector3(-0.5, 0.012, 0.1), Vector3(0.42, 0.024, 1.2), Palette.RUBBER, C.PAINT, 0.008)
	# Counter body: wooden front, green kick, laminate top.
	k.box(Vector3(bx, 0.06, 0), Vector3(bw - 0.06, 0.12, len_z - 0.06), Palette.PINE, C.SATIN, 0.01)
	k.box(Vector3(bx, 0.5, 0), Vector3(bw, top_h - 0.16 - 0.06, len_z), Palette.WOOD, C.WOOD, 0.016, 2)
	k.box(Vector3(bx, top_h - 0.03, 0), Vector3(bw + 0.04, 0.06, len_z + 0.04), Palette.GROCER, C.SATIN, 0.016, 2)
	# Vertical panel grooves on the shopper-facing side.
	for i in 5:
		var z := -len_z * 0.5 + (i + 1) * len_z / 6.0
		k.box(Vector3(body_x1 + 0.002, 0.5, z), Vector3(0.006, 0.6, 0.014), Palette.WOOD_DARK, C.PAINT)

	# Conveyor belt (shopper side, entry end) with steel rails and end roller.
	var belt_x := 0.42
	var belt_len := 1.15
	var belt_z := -len_z * 0.5 + belt_len * 0.5 + 0.08
	k.box(Vector3(belt_x, top_h + 0.012, belt_z), Vector3(0.42, 0.02, belt_len), Palette.RUBBER, C.SATIN, 0.008)
	for sx in [-1.0, 1.0]:
		k.box(Vector3(belt_x + sx * 0.23, top_h + 0.025, belt_z), Vector3(0.03, 0.04, belt_len + 0.02), Palette.STEEL, C.METAL, 0.008)
	k.rod(Vector3(belt_x - 0.2, top_h + 0.02, belt_z + belt_len * 0.5 + 0.01), Vector3(belt_x + 0.2, top_h + 0.02, belt_z + belt_len * 0.5 + 0.01), 0.02, Palette.STEEL, C.METAL, 10)
	# Divider bar resting on the belt.
	k.box(Vector3(belt_x, top_h + 0.05, belt_z - 0.15), Vector3(0.34, 0.035, 0.035), Palette.TOMATO, C.SATIN, 0.008)

	# Scanner glass flush in the counter.
	var reg_z := len_z * 0.5 - 0.55
	k.box(Vector3(0.3, top_h + 0.002, reg_z), Vector3(0.22, 0.004, 0.2), Color("2c3b3e"), C.GLOSS)
	# Till: drawer box, column, angled screen.
	k.box(Vector3(-0.05, top_h + 0.07, reg_z), Vector3(0.3, 0.14, 0.36), Palette.INK, C.SATIN, 0.02, 2)
	k.box(Vector3(0.11, top_h + 0.07, reg_z), Vector3(0.01, 0.04, 0.2), Palette.STEEL, C.METAL)
	k.rod(Vector3(-0.05, top_h + 0.14, reg_z), Vector3(-0.05, top_h + 0.3, reg_z), 0.025, Palette.STEEL_DARK, C.METAL)
	k.push(Transform3D(Basis(Vector3.FORWARD, deg_to_rad(-20)), Vector3(-0.04, top_h + 0.36, reg_z)))
	k.box(Vector3.ZERO, Vector3(0.04, 0.2, 0.28), Palette.INK, C.SATIN, 0.012, 2)
	k.box(Vector3(0.021, 0, 0), Vector3(0.002, 0.16, 0.24), Color("9fd6c6"), C.EMIT)
	k.pop()
	# Card reader on a little stalk, facing the shopper.
	k.rod(Vector3(0.62, top_h, reg_z + 0.05), Vector3(0.62, top_h + 0.12, reg_z + 0.05), 0.012, Palette.STEEL_DARK, C.METAL)
	k.push(Transform3D(Basis(Vector3.FORWARD, deg_to_rad(25)), Vector3(0.63, top_h + 0.16, reg_z + 0.05)))
	k.box(Vector3.ZERO, Vector3(0.03, 0.14, 0.09), Palette.INK, C.SATIN, 0.01)
	k.box(Vector3(0.016, 0.02, 0), Vector3(0.002, 0.05, 0.06), Palette.MINT, C.EMIT)
	k.pop()
	# Bagging shelf at the exit end with a stack of paper bags.
	var bag_z := len_z * 0.5 - 0.15
	k.box(Vector3(0.38, top_h + 0.06, bag_z), Vector3(0.12, 0.12, 0.2), Palette.CARDBOARD, C.PAINT, 0.004)
	k.box(Vector3(0.38, top_h + 0.123, bag_z), Vector3(0.12, 0.006, 0.2), Palette.shade(Palette.CARDBOARD, 0.1), C.PAINT)

	# Lane light: pole with a numbered lamp box at the entry end.
	var pole := Vector3(0.62, 0, -len_z * 0.5 + 0.06)
	k.rod(pole + Vector3(0, top_h, 0), pole + Vector3(0, 1.85, 0), 0.016, Palette.STEEL_DARK, C.METAL)
	k.box(pole + Vector3(0, 1.95, 0), Vector3(0.2, 0.2, 0.08), Palette.PINE, C.SATIN, 0.02, 2)
	k.box(pole + Vector3(0, 1.95, 0.041), Vector3(0.15, 0.15, 0.004), Palette.MARIGOLD, C.EMIT)
	k.box(pole + Vector3(0, 1.95, -0.041), Vector3(0.15, 0.15, 0.004), Palette.MARIGOLD, C.EMIT)

	var res := _result(k)
	res["labels"].append({"pos": pole + Vector3(0, 1.95, 0.045), "size": 0.12, "kind": "lane"})
	res["labels"].append({"pos": pole + Vector3(0, 1.95, -0.045), "size": 0.12, "kind": "lane", "flip": true})
	res["cashier_spot"] = Vector3(-0.5, 0, reg_z)
	res["pay_spot"] = Vector3(0.98, 0, reg_z)
	return res


# --- Stockroom racking ------------------------------------------------------

static func _rack(def: FixtureDef) -> Dictionary:
	var k := MeshKit.new()
	var w := def.footprint.x * StoreGrid.CELL - 0.08
	var d := def.footprint.y * StoreGrid.CELL - 0.16
	var z0 := -def.footprint.y * StoreGrid.CELL * 0.5 + 0.04
	var cz := z0 + d * 0.5
	var h := def.height
	var upright := Color("3e5f8a")
	var beam := Palette.TOMATO
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(sx * (w * 0.5 - 0.03), h * 0.5, cz + sz * (d * 0.5 - 0.03))
			k.box(p, Vector3(0.06, h, 0.06), upright, C.SATIN, 0.008)
			k.box(Vector3(p.x, 0.01, p.z), Vector3(0.12, 0.02, 0.12), Palette.STEEL_DARK, C.METAL, 0.004)
		# Cross bracing on each frame.
		var zf := cz + d * 0.5 - 0.03
		var zb := cz - d * 0.5 + 0.03
		var x: float = sx * (w * 0.5 - 0.03)
		for i in 3:
			var y0 := 0.2 + i * 0.62
			k.rod(Vector3(x, y0, zf), Vector3(x, y0 + 0.62, zb), 0.012, upright, C.METAL, 6)
	var slots: Array = []
	for y in [0.14, 0.82, 1.5]:
		for sz in [-1.0, 1.0]:
			k.box(Vector3(0, y - 0.04, cz + sz * (d * 0.5 - 0.03)), Vector3(w - 0.06, 0.08, 0.05), beam, C.SATIN, 0.008)
		# Wood deck planks.
		for i in 6:
			var px := -w * 0.5 + 0.08 + i * ((w - 0.16) / 5.0)
			k.box(Vector3(px, y + 0.01, cz), Vector3(0.18, 0.02, d - 0.04), Palette.shade(Palette.WOOD, -0.04 * (i % 2)), C.WOOD, 0.004)
		slots.append({"origin": Vector3(0, y + 0.02, cz + d * 0.5), "facing": 1.0, "deck_center": Vector3(0, y + 0.02, cz)})
	var res := _result(k)
	res["slots"] = slots
	res["deck_size"] = Vector2(w - 0.1, d - 0.06)
	return res


# --- Decor --------------------------------------------------------------------

static func _plant(_def: FixtureDef) -> Dictionary:
	var k := MeshKit.new()
	var terracotta := Color("c4683f")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	k.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.13, 0), Vector2(0.15, 0.02), Vector2(0.17, 0.3),
			Vector2(0.19, 0.31), Vector2(0.19, 0.35), Vector2(0.165, 0.355), Vector2(0.16, 0.33), Vector2(0, 0.33)]),
			[terracotta, terracotta, terracotta, Palette.shade(terracotta, 0.08), Palette.shade(terracotta, 0.08),
			Palette.shade(terracotta, 0.08), Palette.SOIL, Palette.SOIL], C.PAINT, 20)
	# Leaves: broad, slightly cupped blades on arching stems.
	var n := 9
	for i in n:
		var ang := TAU * float(i) / n + rng.randf_range(-0.25, 0.25)
		var lift := rng.randf_range(0.45, 1.0)
		var reach := rng.randf_range(0.25, 0.42)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var base := Vector3(0, 0.33, 0) + dir * 0.03
		var tip := base + dir * reach + Vector3(0, 0.35 + lift * 0.4, 0)
		k.rod(base, tip, 0.008, Palette.shade(Palette.LEAF, -0.25), C.PAINT, 5)
		var leaf_len := rng.randf_range(0.28, 0.4)
		var leaf_w := leaf_len * 0.75
		var fwd := (dir * 0.9 + Vector3(0, -0.15 + lift * 0.1, 0)).normalized()
		var side := fwd.cross(Vector3.UP).normalized()
		var up := side.cross(fwd).normalized()
		var col := Palette.jitter(Palette.shade(Palette.LEAF, -0.1 + 0.1 * (i % 3) * 0.5), rng, 0.03)
		var pts := PackedVector3Array()
		var segs := 7
		for s in segs + 1:
			var t := float(s) / segs
			var width := sin(t * PI) * leaf_w * 0.5
			var droop := -t * t * 0.12
			pts.append(tip + fwd * (t * leaf_len) + side * width + up * (droop + width * 0.25))
		for s in range(segs, -1, -1):
			var t := float(s) / segs
			var width := sin(t * PI) * leaf_w * 0.5
			var droop := -t * t * 0.12
			pts.append(tip + fwd * (t * leaf_len) - side * width + up * (droop + width * 0.25))
		# Split into two halves around the midrib for a gentle fold.
		for s in segs:
			var a := pts[s]
			var b := pts[s + 1]
			var c := pts[pts.size() - 1 - (s + 1)]
			var dd := pts[pts.size() - 1 - s]
			var mid0 := (a + dd) * 0.5 + up * 0.015
			var mid1 := (b + c) * 0.5 + up * 0.015
			k.poly(PackedVector3Array([a, b, mid1, mid0]), up, col, C.SATIN, true)
			k.poly(PackedVector3Array([mid0, mid1, c, dd]), up, Palette.shade(col, -0.06), C.SATIN, true)
	return _result(k)


static func _lamp(_def: FixtureDef) -> Dictionary:
	var k := MeshKit.new()
	var brass := Color("c9a35a")
	k.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.15, 0), Vector2(0.16, 0.015), Vector2(0.12, 0.04), Vector2(0, 0.045)]),
			brass, C.METAL, 20)
	k.rod(Vector3(0, 0.04, 0), Vector3(0, 1.38, 0), 0.014, brass, C.METAL, 10)
	k.lathe(PackedVector2Array([Vector2(0.19, 1.3), Vector2(0.11, 1.62), Vector2(0.105, 1.625)]), Palette.SNOW, C.SATIN, 24)
	k.lathe(PackedVector2Array([Vector2(0.105, 1.618), Vector2(0.185, 1.305)]), Palette.LAMP_WARM, C.EMIT, 24)
	var res := _result(k)
	res["lights"].append({"pos": Vector3(0, 1.38, 0), "color": Palette.LAMP_WARM, "energy": 1.2, "range": 3.2,
			"shadow": false})
	return res


static func _baskets(_def: FixtureDef) -> Dictionary:
	var k := MeshKit.new()
	k.box(Vector3(0, 0.03, 0), Vector3(0.42, 0.06, 0.34), Palette.PINE, C.SATIN, 0.01)
	for i in 6:
		var y := 0.06 + i * 0.085
		var off := Vector3(0.006 * (i % 2), y, -0.004 * (i % 3))
		_basket_into(k, off, Palette.TOMATO)
	# Carry handles on the top basket, folded down.
	var top_y := 0.06 + 5 * 0.085 + 0.2
	k.rod(Vector3(-0.15, top_y, -0.13), Vector3(0.15, top_y, -0.13), 0.008, Palette.INK, C.SATIN, 6)
	k.rod(Vector3(-0.15, top_y, 0.13), Vector3(0.15, top_y, 0.13), 0.008, Palette.INK, C.SATIN, 6)
	return _result(k)


static func _basket_into(k: MeshKit, at: Vector3, col: Color) -> void:
	# Tapered basket shell with a darker rim.
	var w0 := 0.34
	var d0 := 0.26
	k.box(at + Vector3(0, 0.005, 0), Vector3(w0 - 0.04, 0.01, d0 - 0.04), Palette.shade(col, -0.15), C.SATIN)
	for sx in [-1.0, 1.0]:
		k.box(at + Vector3(sx * (w0 * 0.5 - 0.01), 0.1, 0), Vector3(0.012, 0.19, d0), col, C.SATIN, 0.004)
	for sz in [-1.0, 1.0]:
		k.box(at + Vector3(0, 0.1, sz * (d0 * 0.5 - 0.006)), Vector3(w0, 0.19, 0.012), col, C.SATIN, 0.004)
		k.box(at + Vector3(0, 0.2, sz * (d0 * 0.5 - 0.006)), Vector3(w0 + 0.01, 0.018, 0.02), Palette.shade(col, -0.2), C.SATIN, 0.004)


static func _chalkboard(_def: FixtureDef) -> Dictionary:
	# A-frame: two boards hinged at the top, feet splayed apart.
	var k := MeshKit.new()
	var tilt := deg_to_rad(13)
	var hinge := Vector3(0, 1.06, 0)
	var board := Color("26302e")
	var res_labels: Array = []
	for side in [1.0, -1.0]:
		var a: float = -tilt * side
		var basis := Basis(Vector3.RIGHT, a)
		var t := Transform3D(basis, hinge) * Transform3D(Basis.IDENTITY, -hinge)
		k.push(t)
		var zc: float = side * 0.016
		k.box(Vector3(-0.27, 0.53, zc), Vector3(0.04, 1.06, 0.03), Palette.WOOD, C.WOOD, 0.008)
		k.box(Vector3(0.27, 0.53, zc), Vector3(0.04, 1.06, 0.03), Palette.WOOD, C.WOOD, 0.008)
		k.box(Vector3(0, 1.035, zc), Vector3(0.58, 0.05, 0.03), Palette.WOOD, C.WOOD, 0.008)
		k.box(Vector3(0, 0.31, zc), Vector3(0.58, 0.04, 0.03), Palette.WOOD, C.WOOD, 0.008)
		k.box(Vector3(0, 0.67, zc), Vector3(0.5, 0.68, 0.022), board, C.PAINT)
		k.pop()
		var face := t * Vector3(0, 0.68, zc + side * 0.013)
		res_labels.append({"pos": face, "size": 0.07, "kind": "chalk", "tilt": a, "flip": side < 0.0})
	# Hinge pin across the top.
	k.rod(Vector3(-0.3, hinge.y + 0.005, 0), Vector3(0.3, hinge.y + 0.005, 0), 0.01, Palette.STEEL_DARK, C.METAL, 6)
	var res := _result(k)
	res["labels"] = res_labels
	return res


static func _fallback(def: FixtureDef) -> Dictionary:
	var k := MeshKit.new()
	var w := def.footprint.x * StoreGrid.CELL
	var d := def.footprint.y * StoreGrid.CELL
	k.box(Vector3(0, def.height * 0.5, 0), Vector3(w - 0.05, def.height, d - 0.05), Palette.STEEL, C.SATIN, 0.02)
	return _result(k)


# --- Utilities --------------------------------------------------------------

static func _merge(a: ArrayMesh, b: ArrayMesh) -> ArrayMesh:
	for i in b.get_surface_count():
		a.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b.surface_get_arrays(i))
		a.surface_set_material(a.get_surface_count() - 1, b.surface_get_material(i))
	return a
