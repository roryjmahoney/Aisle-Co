class_name Lot
extends RefCounted
## The starting property: a narrow corner store on a street, with the
## neighbouring plot left open for future expansion. All values are in grid
## cells (0.5 m) unless noted. World X runs along the street; +Z points
## towards the road.

const W := 56
const D := 40

const SHOP := Rect2i(8, 9, 24, 13)          # 12 m x 6.5 m shop floor
const BACKROOM := Rect2i(8, 4, 24, 5)       # 12 m x 2.5 m stockroom
const SIDEWALK := Rect2i(0, 22, 56, 6)      # 3 m pavement
const ROAD := Rect2i(0, 28, 56, 10)         # two-lane street
const FAR_SIDEWALK := Rect2i(0, 38, 56, 2)
const DRIVEWAY := Rect2i(0, 2, 7, 20)       # side lane to the loading door
const EXPANSION := Rect2i(33, 0, 23, 22)    # the empty lot next door

const FRONT_Z := 22
const BACK_Z := 4
const LEFT_X := 8
const RIGHT_X := 32
const PARTITION_Z := 9
const ENTRANCE := Vector2i(24, 27)          # x range of the entrance opening
const STAFF_DOOR := Vector2i(10, 12)        # x range in the partition
const LOADING_DOOR := Vector2i(5, 8)        # z range in the left wall

const FLOOR_Y := 0.12                        # metres; interior + pavement level
const WALL_H := 3.2
const PARTITION_H := 2.6
const EXT_T := 0.25                          # exterior wall thickness (m)

const ENTRANCE_INSIDE := Vector2i(25, 21)
const ENTRANCE_OUTSIDE := Vector2i(25, 23)
const SPAWN_LEFT := Vector2i(1, 25)
const SPAWN_RIGHT := Vector2i(55, 25)
const LOADING_BAY := Vector2i(4, 6)          # van stops here (outside left wall)
const LOADING_INSIDE := Vector2i(8, 6)
## Occupant id for immovable scenery (wall thickness, street furniture).
const STATIC_UID := -2


static func apply(grid: StoreGrid) -> void:
	grid.set_zone_rect(Rect2i(0, 0, W, D), StoreGrid.Zone.OUTSIDE)
	grid.set_zone_rect(ROAD, StoreGrid.Zone.ROAD)
	grid.set_zone_rect(DRIVEWAY, StoreGrid.Zone.LOADING)
	grid.set_zone_rect(SHOP, StoreGrid.Zone.SHOP)
	grid.set_zone_rect(BACKROOM, StoreGrid.Zone.BACKROOM)

	var front := FRONT_Z
	# Back and side walls.
	grid.add_wall(Vector2i(LEFT_X, BACK_Z), Vector2i(RIGHT_X, BACK_Z), "exterior", {"side": "back"})
	grid.add_wall(Vector2i(LEFT_X, BACK_Z), Vector2i(LEFT_X, LOADING_DOOR.x), "exterior", {"side": "left"})
	grid.add_wall(Vector2i(LEFT_X, LOADING_DOOR.x), Vector2i(LEFT_X, LOADING_DOOR.y), "door", {"side": "left", "door": "loading"})
	grid.add_wall(Vector2i(LEFT_X, LOADING_DOOR.y), Vector2i(LEFT_X, front), "exterior", {"side": "left"})
	grid.add_wall(Vector2i(RIGHT_X, BACK_Z), Vector2i(RIGHT_X, front), "exterior", {"side": "right"})
	# Shopfront: windows either side of the entrance.
	grid.add_wall(Vector2i(LEFT_X, front), Vector2i(ENTRANCE.x - 1, front), "window", {"side": "front"})
	grid.add_wall(Vector2i(ENTRANCE.x - 1, front), Vector2i(ENTRANCE.x, front), "exterior", {"side": "front"})
	grid.add_wall(Vector2i(ENTRANCE.x, front), Vector2i(ENTRANCE.y, front), "door", {"side": "front", "door": "entrance"})
	grid.add_wall(Vector2i(ENTRANCE.y, front), Vector2i(ENTRANCE.y + 1, front), "exterior", {"side": "front"})
	grid.add_wall(Vector2i(ENTRANCE.y + 1, front), Vector2i(RIGHT_X, front), "window", {"side": "front"})
	# Stockroom partition with a doorway.
	grid.add_wall(Vector2i(LEFT_X, PARTITION_Z), Vector2i(STAFF_DOOR.x, PARTITION_Z), "partition", {"side": "partition"})
	grid.add_wall(Vector2i(STAFF_DOOR.x, PARTITION_Z), Vector2i(STAFF_DOOR.y, PARTITION_Z), "door", {"side": "partition", "door": "staff"})
	grid.add_wall(Vector2i(STAFF_DOOR.y, PARTITION_Z), Vector2i(RIGHT_X, PARTITION_Z), "partition", {"side": "partition"})

	# Exterior walls are built *outside* the interior boundary, so the outdoor
	# cells they sit on are not walkable (except at the door openings).
	var shell: Array[Vector2i] = []
	for x in range(LEFT_X - 1, RIGHT_X + 1):
		shell.append(Vector2i(x, BACK_Z - 1))
		if x < ENTRANCE.x or x >= ENTRANCE.y:
			shell.append(Vector2i(x, FRONT_Z))
	for z in range(BACK_Z, FRONT_Z + 1):
		if z < LOADING_DOOR.x or z >= LOADING_DOOR.y:
			shell.append(Vector2i(LEFT_X - 1, z))
		shell.append(Vector2i(RIGHT_X, z))
	for c in shell:
		if grid.in_bounds(c):
			grid.occupant[grid.idx(c)] = STATIC_UID


static func ground_height(c: Vector2i) -> float:
	## Walking surface height in metres for a cell.
	if c.y >= FRONT_Z and c.y < SIDEWALK.end.y and c.x >= DRIVEWAY.end.x:
		return FLOOR_Y
	if c.x >= LEFT_X and c.x < RIGHT_X and c.y >= BACK_Z and c.y < FRONT_Z:
		return FLOOR_Y
	if c.y >= FAR_SIDEWALK.position.y:
		return FLOOR_Y
	if c.y >= ROAD.position.y and c.y < ROAD.end.y:
		return 0.01
	return 0.03


static func m(cells: float) -> float:
	return cells * StoreGrid.CELL
