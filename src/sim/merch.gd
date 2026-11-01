class_name Merch
extends RefCounted
## Merchandising maths shared by the simulation and the renderer, so the
## number of units a shelf holds is *exactly* the number you can see on it.

const GAP_ACROSS := 0.012
const GAP_DEEP := 0.008


static func fits(p: ProductDef, def: FixtureDef) -> bool:
	if p == null or def == null or def.slot_count == 0:
		return false
	return def.slot_storage == p.storage and p.unit_size.y <= def.slot_size.y


static func grid_for(p: ProductDef, def: FixtureDef) -> Vector2i:
	if not fits(p, def):
		return Vector2i.ZERO
	var s := def.slot_size
	var across := int(floor((s.x + GAP_ACROSS) / (p.unit_size.x + GAP_ACROSS)))
	var deep := int(floor((s.z + GAP_DEEP) / (p.unit_size.z + GAP_DEEP)))
	return Vector2i(maxi(across, 0), maxi(deep, 0))


static func capacity(p: ProductDef, def: FixtureDef) -> int:
	var g := grid_for(p, def)
	return g.x * g.y


static func layout(p: ProductDef, def: FixtureDef, seed_value: int) -> Array[Transform3D]:
	## Unit transforms in slot space: origin at the deck's front-centre, +Z
	## towards the shopper. Ordered column by column (left to right), each
	## column back to front — so as stock sells, the front of the last column
	## empties first, then whole columns, exactly like a real shelf.
	var out: Array[Transform3D] = []
	var g := grid_for(p, def)
	if g.x == 0 or g.y == 0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var u := p.unit_size
	var block_w := g.x * u.x + (g.x - 1) * GAP_ACROSS
	for cx in g.x:
		var x := -block_w * 0.5 + u.x * 0.5 + cx * (u.x + GAP_ACROSS)
		for dz in range(g.y - 1, -1, -1):
			var z := -(0.01 + u.z * 0.5 + dz * (u.z + GAP_DEEP))
			var jitter := Vector3(rng.randf_range(-0.003, 0.003), 0, rng.randf_range(-0.003, 0.003))
			var b := Basis(Vector3.UP, rng.randf_range(-0.05, 0.05))
			out.append(Transform3D(b, Vector3(x, 0.0, z) + jitter))
	return out
