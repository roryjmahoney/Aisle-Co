class_name StarterStore
extends RefCounted
## The humble corner shop the player inherits on day one: a few shelves, one
## chiller, one till and a single rack in the back. Deliberately sparse.


static func populate() -> void:
	var store := Game.store
	var cat := Game.catalog
	var inv := Game.inventory
	var plan := [
		[&"shelf_wall", Vector2i(8, 11), 1, [&"oats", &"oats", &"soup", &"soup"]],
		[&"shelf_wall", Vector2i(13, 9), 0, [&"jam", &"jam", &"water", &"water"]],
		[&"shelf_wall", Vector2i(16, 9), 0, [&"soup", &"oats", &"water", &"jam"]],
		[&"fridge", Vector2i(30, 11), 3, [&"milk", &"milk", &"cheddar", &"cheddar"]],
		[&"checkout", Vector2i(19, 15), 0, []],
		[&"storage_rack", Vector2i(20, 4), 0, []],
		[&"plant", Vector2i(9, 20), 0, []],
		[&"basket_stand", Vector2i(23, 19), 0, []],
	]
	for row in plan:
		var def: FixtureDef = cat.fixture(row[0])
		var err := store.check_placement(def, row[1], row[2])
		if err != "":
			push_error("StarterStore: %s at %s: %s" % [row[0], row[1], err])
			continue
		var f := store.add(def, row[1], row[2])
		for i in row[3].size():
			inv.assign_slot(f, i, row[3][i])
			# Opening stock: shelves start roughly two-thirds full.
			var want := int(f.slots[i].cap * (0.55 + 0.1 * (i % 3)))
			inv.seed_shelf(f, i, want)
	# A few cases already in the back.
	for pid in [&"soup", &"water", &"milk"]:
		inv.seed_stockroom(pid, cat.product(pid).case_size * 2)
