class_name FixtureDef
extends Resource
## Immutable description of anything the player can build.
##
## Local space convention: the object's *front* faces local +Z; footprint cell
## (0,0) is the back-left corner. `access_cells` are local cells (usually just
## in front of the footprint) that must stay walkable for it to be usable.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export_enum("fixtures", "storage", "decor") var category: String = "fixtures"
@export var price_cents: int = 10000
@export var upkeep_cents_per_day: int = 0
@export var footprint: Vector2i = Vector2i(1, 1)
@export var allow_shop: bool = true
@export var allow_backroom: bool = false
@export var access_cells: Array[Vector2i] = []
## Rugs, mats: occupy cells for placement but don't block walking.
@export var walk_through: bool = false
@export var icon: StringName = &"shelf"
## How much this object lifts the store's atmosphere (decor, lighting).
@export var appeal: int = 0

@export_group("Merchandising")
@export var slot_count: int = 0
@export_enum("none", "ambient", "chilled") var slot_storage: String = "none"
## Usable volume of each shelf tier (width, clear height, depth) in metres.
@export var slot_size: Vector3 = Vector3.ZERO
## Height of each tier's deck, bottom to top.
@export var slot_heights: PackedFloat32Array = PackedFloat32Array()
## Gondolas: the second half of the slots face local -Z.
@export var double_sided: bool = false

@export_group("Logistics")
## Cases this fixture can hold in the stockroom.
@export var storage_cases: int = 0
@export var is_checkout: bool = false

@export_group("Art")
@export var art: StringName = &"shelf_wall"
@export var height: float = 2.0


func cells_for(anchor: Vector2i, rot: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in footprint.y:
		for x in footprint.x:
			out.append(local_to_cell(anchor, rot, Vector2i(x, z)))
	return out


func access_for(anchor: Vector2i, rot: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in access_cells:
		out.append(local_to_cell(anchor, rot, c))
	return out


func rotated_size(rot: int) -> Vector2i:
	return footprint if rot % 2 == 0 else Vector2i(footprint.y, footprint.x)


func center_world(anchor: Vector2i, rot: int) -> Vector3:
	var s := rotated_size(rot)
	return Vector3((anchor.x + s.x * 0.5) * StoreGrid.CELL, 0.0, (anchor.y + s.y * 0.5) * StoreGrid.CELL)


func yaw(rot: int) -> float:
	return rot * PI * 0.5


func local_to_world(anchor: Vector2i, rot: int, local: Vector3) -> Vector3:
	return center_world(anchor, rot) + Basis(Vector3.UP, yaw(rot)) * local


func local_to_cell(anchor: Vector2i, rot: int, lc: Vector2i) -> Vector2i:
	var cell := StoreGrid.CELL
	var local := Vector3((lc.x + 0.5) * cell - footprint.x * cell * 0.5, 0.0,
			(lc.y + 0.5) * cell - footprint.y * cell * 0.5)
	return StoreGrid.world_to_cell(local_to_world(anchor, rot, local))
