class_name ProductArt
extends RefCounted
## Builds the packaging models for products and their shipping cases.
## Units are authored with the origin at the bottom centre, front facing +Z.

const C := MeshKit.Ch

static var _units: Dictionary = {}
static var _cases: Dictionary = {}


static func unit_mesh(p: ProductDef) -> ArrayMesh:
	if _units.has(p.id):
		return _units[p.id]
	var k := MeshKit.new()
	var s := p.unit_size
	match p.shape:
		"cereal_box":
			_cereal(k, p, s)
		"can":
			_can(k, p, s)
		"jar":
			_jar(k, p, s)
		"bottle":
			_bottle(k, p, s)
		"carton":
			_carton(k, p, s)
		"cheese":
			_cheese(k, p, s)
		_:
			k.box(Vector3(0, s.y * 0.5, 0), s, p.color_main, C.SATIN, 0.004)
	var m := k.build()
	_units[p.id] = m
	return m


static func case_mesh(p: ProductDef) -> ArrayMesh:
	## A cardboard shipping case with a printed brand panel and packing tape.
	if _cases.has(p.id):
		return _cases[p.id]
	var k := MeshKit.new()
	var s := case_size()
	k.box(Vector3(0, s.y * 0.5, 0), s, Palette.CARDBOARD, C.PAINT, 0.012)
	k.box(Vector3(0, s.y + 0.0005, 0), Vector3(0.06, 0.002, s.z + 0.004), Palette.shade(Palette.CARDBOARD, 0.25), C.SATIN)
	k.box(Vector3(0, s.y * 0.5, s.z * 0.5 + 0.001), Vector3(0.06, s.y + 0.004, 0.002), Palette.shade(Palette.CARDBOARD, 0.25), C.SATIN)
	# Printed panel on the front: product colours so stock is readable at a glance.
	k.box(Vector3(-0.08, s.y * 0.55, s.z * 0.5 + 0.002), Vector3(0.18, 0.12, 0.002), p.color_main, C.PAINT)
	k.box(Vector3(-0.08, s.y * 0.55 - 0.045, s.z * 0.5 + 0.003), Vector3(0.18, 0.03, 0.002), p.color_second, C.PAINT)
	k.box(Vector3(0.12, s.y * 0.72, s.z * 0.5 + 0.002), Vector3(0.1, 0.02, 0.002), Palette.INK, C.PAINT)
	k.box(Vector3(0.12, s.y * 0.66, s.z * 0.5 + 0.002), Vector3(0.1, 0.012, 0.002), Palette.shade(Palette.CARDBOARD, -0.3), C.PAINT)
	var m := k.build()
	_cases[p.id] = m
	return m


static func case_size() -> Vector3:
	return Vector3(0.40, 0.26, 0.355)


# --- Shapes --------------------------------------------------------------------

static func _cereal(k: MeshKit, p: ProductDef, s: Vector3) -> void:
	k.box(Vector3(0, s.y * 0.5, 0), s, p.color_main, C.SATIN, 0.004)
	var fz := s.z * 0.5 + 0.0012
	# Big rising-sun motif and a white name band.
	k.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.02, s.y * 0.62, fz - 0.001)))
	k.cylinder(Vector3.ZERO, s.x * 0.34, 0.002, p.color_second, C.SATIN, 18)
	k.pop()
	k.box(Vector3(0, s.y * 0.3, fz), Vector3(s.x * 0.86, s.y * 0.13, 0.002), p.color_accent, C.SATIN)
	k.box(Vector3(-s.x * 0.12, s.y * 0.3, fz + 0.001), Vector3(s.x * 0.5, s.y * 0.04, 0.002), Palette.INK, C.PAINT)
	k.box(Vector3(0, s.y * 0.08, fz), Vector3(s.x, s.y * 0.06, 0.002), p.color_second, C.SATIN)
	# Spine stripe on the sides so end-of-aisle views still read.
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * (s.x * 0.5 + 0.0012), s.y * 0.5, 0), Vector3(0.002, s.y * 0.9, s.z * 0.5), p.color_second, C.SATIN)


static func _can(k: MeshKit, p: ProductDef, s: Vector3) -> void:
	var r := s.x * 0.5
	var h := s.y
	k.lathe(PackedVector2Array([Vector2(0, 0), Vector2(r * 0.92, 0), Vector2(r, 0.006), Vector2(r, 0.012)]),
			Palette.STEEL, C.METAL, 14)
	k.lathe(PackedVector2Array([Vector2(r, 0.012), Vector2(r, h * 0.36)]), p.color_main, C.SATIN, 14)
	k.lathe(PackedVector2Array([Vector2(r, h * 0.36), Vector2(r, h * 0.62)]), p.color_second, C.SATIN, 14)
	k.lathe(PackedVector2Array([Vector2(r, h * 0.62), Vector2(r, h - 0.012)]), p.color_main, C.SATIN, 14)
	k.lathe(PackedVector2Array([Vector2(r, h - 0.012), Vector2(r, h - 0.004), Vector2(r * 0.9, h),
			Vector2(r * 0.85, h - 0.004), Vector2(0, h - 0.004)]), Palette.STEEL, C.METAL, 14)
	k.box(Vector3(0, h * 0.49, r + 0.0005), Vector3(r * 0.9, h * 0.08, 0.002), p.color_accent, C.SATIN)


static func _jar(k: MeshKit, p: ProductDef, s: Vector3) -> void:
	var r := s.x * 0.5
	var h := s.y
	k.lathe(PackedVector2Array([Vector2(0, 0), Vector2(r * 0.85, 0), Vector2(r, h * 0.08), Vector2(r, h * 0.7),
			Vector2(r * 0.86, h * 0.8), Vector2(r * 0.82, h * 0.8), Vector2(0, h * 0.8)]), p.color_main, C.GLOSS, 14)
	k.lathe(PackedVector2Array([Vector2(r + 0.001, h * 0.22), Vector2(r + 0.001, h * 0.6)]), p.color_second, C.PAINT, 14)
	# Gingham-red lid with a white crown.
	k.lathe(PackedVector2Array([Vector2(0, h * 0.8), Vector2(r * 0.9, h * 0.8), Vector2(r * 0.92, h * 0.96),
			Vector2(r * 0.85, h), Vector2(0, h)]), p.color_accent, C.SATIN, 14)
	k.cylinder(Vector3(0, h * 0.995, 0), r * 0.55, 0.003, Palette.SNOW, C.SATIN, 12)


static func _bottle(k: MeshKit, p: ProductDef, s: Vector3) -> void:
	var r := s.x * 0.5
	var h := s.y
	k.lathe(PackedVector2Array([Vector2(0, 0), Vector2(r * 0.88, 0), Vector2(r, h * 0.04), Vector2(r, h * 0.62),
			Vector2(r * 0.85, h * 0.74), Vector2(r * 0.42, h * 0.86), Vector2(r * 0.36, h * 0.9)]), p.color_main, C.GLOSS, 14)
	k.lathe(PackedVector2Array([Vector2(r + 0.001, h * 0.22), Vector2(r + 0.001, h * 0.48)]), p.color_second, C.SATIN, 14)
	k.lathe(PackedVector2Array([Vector2(r + 0.0015, h * 0.3), Vector2(r + 0.0015, h * 0.4)]), p.color_accent, C.SATIN, 14)
	k.cylinder(Vector3(0, h * 0.9, 0), r * 0.42, h * 0.1, p.color_accent, C.SATIN, 12, 0.002)


static func _carton(k: MeshKit, p: ProductDef, s: Vector3) -> void:
	var body_h := s.y * 0.8
	var w := s.x
	var d := s.z
	k.box(Vector3(0, body_h * 0.5, 0), Vector3(w, body_h, d), p.color_main, C.SATIN, 0.003)
	# Gable roof.
	var y0 := body_h
	var y1 := s.y * 0.95
	for sz in [-1.0, 1.0]:
		k.poly(PackedVector3Array([Vector3(-w * 0.5, y0, sz * d * 0.5), Vector3(w * 0.5, y0, sz * d * 0.5),
				Vector3(w * 0.5, y1, 0), Vector3(-w * 0.5, y1, 0)]), Vector3(0, 0.5, sz).normalized(), p.color_second, C.SATIN)
	for sx in [-1.0, 1.0]:
		k.poly(PackedVector3Array([Vector3(sx * w * 0.5, y0, -d * 0.5), Vector3(sx * w * 0.5, y0, d * 0.5),
				Vector3(sx * w * 0.5, y1, 0)]), Vector3(sx, 0, 0), p.color_main, C.SATIN)
	k.box(Vector3(0, s.y * 0.975, 0), Vector3(w, s.y * 0.05, 0.006), p.color_main, C.SATIN)
	# Band and a little meadow stripe.
	var fz := d * 0.5 + 0.0012
	k.box(Vector3(0, body_h * 0.62, fz), Vector3(w, body_h * 0.24, 0.002), p.color_second, C.SATIN)
	k.box(Vector3(0, body_h * 0.12, fz), Vector3(w, body_h * 0.1, 0.002), p.color_accent, C.SATIN)


static func _cheese(k: MeshKit, p: ProductDef, s: Vector3) -> void:
	k.box(Vector3(0, s.y * 0.5, 0), s, p.color_main, C.SATIN, 0.006, 2)
	k.box(Vector3(0, s.y * 0.5, 0), Vector3(s.x * 0.34, s.y + 0.002, s.z + 0.002), p.color_second, C.SATIN)
	k.box(Vector3(0, s.y * 0.55, s.z * 0.5 + 0.002), Vector3(s.x * 0.24, s.y * 0.36, 0.002), p.color_accent, C.PAINT)
