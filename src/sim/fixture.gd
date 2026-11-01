class_name Fixture
extends RefCounted
## Runtime state of one placed fixture. Pure data + invariants; views listen
## to `changed` to update what's drawn.

signal changed(slot: int)

var uid: int
var def: FixtureDef
var anchor: Vector2i
var rot: int
## One entry per shelf tier: {product: StringName, qty: int, cap: int}
var slots: Array[Dictionary] = []
## Shopping-related ephemeral state (who is standing where) lives in the
## agent systems, not here.


func _init(p_uid: int, p_def: FixtureDef, p_anchor: Vector2i, p_rot: int) -> void:
	uid = p_uid
	def = p_def
	anchor = p_anchor
	rot = posmod(p_rot, 4)
	for i in def.slot_count:
		slots.append({"product": &"", "qty": 0, "cap": 0})


func cells() -> Array[Vector2i]:
	return def.cells_for(anchor, rot)


func access_cells() -> Array[Vector2i]:
	return def.access_for(anchor, rot)


func world_center() -> Vector3:
	return def.center_world(anchor, rot)


func to_world(local: Vector3) -> Vector3:
	return def.local_to_world(anchor, rot, local)


func yaw() -> float:
	return def.yaw(rot)


func slot_side(i: int) -> float:
	## +1 if the tier faces local +Z, -1 for the back of a gondola.
	if def.double_sided and i >= def.slot_count / 2:
		return -1.0
	return 1.0


func access_for_slot(i: int) -> Array[Vector2i]:
	## Cells a shopper can stand on to reach slot i.
	var out: Array[Vector2i] = []
	var side := slot_side(i)
	for lc in def.access_cells:
		if (side > 0.0 and lc.y >= def.footprint.y) or (side < 0.0 and lc.y < 0):
			out.append(def.local_to_cell(anchor, rot, lc))
	return out


func total_units() -> int:
	var n := 0
	for s in slots:
		n += s.qty
	return n


func has_product(pid: StringName) -> bool:
	for s in slots:
		if s.product == pid and s.qty > 0:
			return true
	return false


func to_dict() -> Dictionary:
	var sl := []
	for s in slots:
		sl.append({"product": String(s.product), "qty": s.qty})
	return {"uid": uid, "def": String(def.id), "anchor": [anchor.x, anchor.y], "rot": rot, "slots": sl}
