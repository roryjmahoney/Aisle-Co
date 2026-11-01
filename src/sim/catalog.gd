class_name Catalog
extends RefCounted
## Loads every ProductDef and FixtureDef from data/. Definitions are immutable
## at runtime; look them up by id.

var products: Dictionary = {}   # StringName -> ProductDef
var fixtures: Dictionary = {}   # StringName -> FixtureDef
var product_order: Array[StringName] = []
var fixture_order: Array[StringName] = []


func load_all() -> void:
	for p in _load_dir("res://data/products"):
		if p is ProductDef:
			products[p.id] = p
			product_order.append(p.id)
	for f in _load_dir("res://data/fixtures"):
		if f is FixtureDef:
			fixtures[f.id] = f
			fixture_order.append(f.id)
	# Stable, intentional ordering for menus.
	var fixture_rank := [&"shelf_wall", &"shelf_island", &"fridge", &"checkout", &"storage_rack",
			&"plant", &"floor_lamp", &"basket_stand", &"chalkboard"]
	fixture_order.sort_custom(func(a, b): return fixture_rank.find(a) < fixture_rank.find(b))
	var product_rank := [&"oats", &"soup", &"jam", &"water", &"milk", &"cheddar"]
	product_order.sort_custom(func(a, b): return product_rank.find(a) < product_rank.find(b))


func product(id: StringName) -> ProductDef:
	return products.get(id)


func fixture(id: StringName) -> FixtureDef:
	return fixtures.get(id)


func _load_dir(path: String) -> Array:
	var out := []
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Catalog: cannot open %s" % path)
		return out
	var files := dir.get_files()
	files.sort()
	for f in files:
		# Exported builds list remapped resources as *.tres.remap.
		var name := f.trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			var r := load(path + "/" + name)
			if r == null:
				push_error("Catalog: failed to load %s" % name)
			else:
				out.append(r)
	return out
