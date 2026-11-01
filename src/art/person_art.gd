class_name PersonArt
extends RefCounted
## Stylised miniature people: a rigidly-skinned single mesh per look (one draw
## call per person) on an 8-bone skeleton that PersonView animates
## procedurally.

const C := MeshKit.Ch
enum B { ROOT, HIPS, CHEST, HEAD, ARM_L, ARM_R, LEG_L, LEG_R }

# Joint positions in model space (rest pose).
const J_HIPS := Vector3(0, 0.78, 0)
const J_CHEST := Vector3(0, 0.98, 0)
const J_HEAD := Vector3(0, 1.36, 0)
const J_ARM_L := Vector3(0.19, 1.27, 0)
const J_ARM_R := Vector3(-0.19, 1.27, 0)
const J_LEG_L := Vector3(0.085, 0.78, 0)
const J_LEG_R := Vector3(-0.085, 0.78, 0)

static var _cache: Dictionary = {}


static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	var shirt: Color = Palette.CLOTHING[rng.randi() % Palette.CLOTHING.size()]
	var trousers: Color = [Color("2a3e52"), Color("3d3a36"), Color("5b6b78"), Color("7a5a44"), Color("1f2a2a"), Color("8a8f86")][rng.randi() % 6]
	return {
		"skin": Palette.SKIN_TONES[rng.randi() % Palette.SKIN_TONES.size()],
		"hair": Palette.HAIR_TONES[rng.randi() % Palette.HAIR_TONES.size()],
		"shirt": shirt,
		"trousers": trousers,
		"shoes": [Color("2a2f33"), Color("f4f7f2"), Color("6d5040")][rng.randi() % 3],
		"hair_style": ["short", "bun", "long", "crop", "bald"][rng.randi() % 5],
		"height": rng.randf_range(0.92, 1.06),
		"build": rng.randf_range(0.92, 1.12),
		"staff": false,
	}


static func staff_look(rng: RandomNumberGenerator) -> Dictionary:
	var l := random_look(rng)
	l.shirt = Palette.SNOW
	l.trousers = Color("2a3e52")
	l.staff = true
	return l


static func skeleton() -> Skeleton3D:
	var s := Skeleton3D.new()
	var defs := [
		["root", -1, Vector3.ZERO],
		["hips", B.ROOT, J_HIPS],
		["chest", B.HIPS, J_CHEST - J_HIPS],
		["head", B.CHEST, J_HEAD - J_CHEST],
		["arm_l", B.CHEST, J_ARM_L - J_CHEST],
		["arm_r", B.CHEST, J_ARM_R - J_CHEST],
		["leg_l", B.HIPS, J_LEG_L - J_HIPS],
		["leg_r", B.HIPS, J_LEG_R - J_HIPS],
	]
	for d in defs:
		var i := s.add_bone(d[0])
		if d[1] >= 0:
			s.set_bone_parent(i, d[1])
		s.set_bone_rest(i, Transform3D(Basis.IDENTITY, d[2]))
	s.reset_bone_poses()
	return s


static func mesh(look: Dictionary) -> ArrayMesh:
	var key := str(look)
	if _cache.has(key):
		return _cache[key]
	var k := MeshKit.new()
	var skin: Color = look.skin
	var shirt: Color = look.shirt
	var trousers: Color = look.trousers
	var hair: Color = look.hair
	var bw: float = look.build

	# Legs + shoes
	for side in [1.0, -1.0]:
		k.bone = B.LEG_L if side > 0.0 else B.LEG_R
		var x: float = 0.085 * side * bw
		k.capsule(Vector3(x, 0.12, 0), Vector3(x, 0.76, 0), 0.066 * bw, trousers, C.PAINT, 10)
		k.box(Vector3(x, 0.045, 0.03), Vector3(0.11, 0.09, 0.2), look.shoes, C.SATIN, 0.03, 2)

	# Hips (trousers) and torso (shirt)
	k.bone = B.HIPS
	k.lathe(PackedVector2Array([Vector2(0, 0.7), Vector2(0.15 * bw, 0.72), Vector2(0.16 * bw, 0.86), Vector2(0.158 * bw, 0.92)]),
			[trousers, trousers, shirt], C.PAINT, 14)
	k.bone = B.CHEST
	k.lathe(PackedVector2Array([Vector2(0.158 * bw, 0.92), Vector2(0.168 * bw, 1.08), Vector2(0.178 * bw, 1.2),
			Vector2(0.15 * bw, 1.29), Vector2(0.07, 1.33), Vector2(0.05, 1.36), Vector2(0, 1.36)]), shirt, C.PAINT, 14)
	if look.staff:
		# Pine apron with a marigold name badge.
		k.box(Vector3(0, 1.02, 0.155 * bw), Vector3(0.26 * bw, 0.4, 0.02), Palette.STAFF_APRON, C.PAINT, 0.01)
		k.box(Vector3(0.06, 1.16, 0.168 * bw), Vector3(0.06, 0.03, 0.01), Palette.MARIGOLD, C.SATIN)
		k.rod(Vector3(-0.1, 1.22, 0.15 * bw), Vector3(-0.06, 1.33, 0.06), 0.008, Palette.STAFF_APRON, C.PAINT, 4)
		k.rod(Vector3(0.1, 1.22, 0.15 * bw), Vector3(0.06, 1.33, 0.06), 0.008, Palette.STAFF_APRON, C.PAINT, 4)

	# Arms with hands
	for side in [1.0, -1.0]:
		k.bone = B.ARM_L if side > 0.0 else B.ARM_R
		var sx: float = 0.19 * side * bw
		k.capsule(Vector3(sx, 1.25, 0), Vector3(sx + 0.03 * side, 0.92, 0), 0.05 * bw, shirt, C.PAINT, 8)
		k.sphere(Vector3(sx + 0.035 * side, 0.86, 0.0), 0.048, skin, C.SATIN, 6, 10)

	# Head, face, hair
	k.bone = B.HEAD
	var hc := Vector3(0, 1.5, 0)
	k.sphere(hc, 0.13, skin, C.SATIN, 10, 16)
	k.sphere(hc + Vector3(0, -0.01, 0.124), 0.02, Palette.shade(skin, -0.08), C.SATIN, 4, 8)
	for ex in [-0.046, 0.046]:
		k.sphere(hc + Vector3(ex, 0.02, 0.115), 0.015, Palette.INK, C.GLOSS, 4, 8)
	# Rosy cheeks — subtle.
	for ex in [-0.075, 0.075]:
		k.sphere(hc + Vector3(ex, -0.025, 0.098), 0.024, skin.lerp(Color("e58a7a"), 0.35), C.SATIN, 4, 8, 0.6)
	match look.hair_style:
		"short":
			k.sphere(hc + Vector3(0, 0.03, -0.018), 0.138, hair, C.SATIN, 8, 14, 0.9)
		"crop":
			k.sphere(hc + Vector3(0, 0.045, -0.02), 0.132, hair, C.SATIN, 8, 14, 0.78)
		"bun":
			k.sphere(hc + Vector3(0, 0.03, -0.018), 0.138, hair, C.SATIN, 8, 14, 0.9)
			k.sphere(hc + Vector3(0, 0.13, -0.08), 0.065, hair, C.SATIN, 6, 10)
		"long":
			k.sphere(hc + Vector3(0, 0.03, -0.018), 0.14, hair, C.SATIN, 8, 14, 0.92)
			k.box(hc + Vector3(0, -0.12, -0.06), Vector3(0.25, 0.26, 0.12), hair, C.SATIN, 0.05, 2)
		"bald":
			pass
	if look.staff:
		# Pine cap with a short brim.
		k.sphere(hc + Vector3(0, 0.05, -0.01), 0.137, Palette.STAFF_APRON, C.SATIN, 8, 14, 0.7)
		k.box(hc + Vector3(0, 0.07, 0.13), Vector3(0.17, 0.018, 0.1), Palette.STAFF_APRON, C.SATIN, 0.008)
	k.bone = -1
	var m := k.build()
	_cache[key] = m
	return m


static func basket_mesh() -> ArrayMesh:
	if _cache.has("basket"):
		return _cache["basket"]
	var k := MeshKit.new()
	var col := Palette.TOMATO
	var w := 0.3
	var d := 0.2
	var h := 0.15
	k.box(Vector3(0, 0.005, 0), Vector3(w - 0.03, 0.01, d - 0.03), Palette.shade(col, -0.15), C.SATIN)
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * (w * 0.5 - 0.006), h * 0.5, 0), Vector3(0.012, h, d), col, C.SATIN, 0.004)
	for sz in [-1.0, 1.0]:
		k.box(Vector3(0, h * 0.5, sz * (d * 0.5 - 0.006)), Vector3(w, h, 0.012), col, C.SATIN, 0.004)
	k.rod(Vector3(-0.1, h, 0), Vector3(-0.06, h + 0.1, 0), 0.008, Palette.INK, C.SATIN, 5)
	k.rod(Vector3(0.1, h, 0), Vector3(0.06, h + 0.1, 0), 0.008, Palette.INK, C.SATIN, 5)
	k.rod(Vector3(-0.06, h + 0.1, 0), Vector3(0.06, h + 0.1, 0), 0.008, Palette.INK, C.SATIN, 5)
	var m := k.build()
	_cache["basket"] = m
	return m
