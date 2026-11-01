class_name SaveManager
extends RefCounted
## Versioned JSON saves. Only plain data is written (ids, cells, counts) —
## never object references — so a save can always be rebuilt from the
## catalogue. Shoppers mid-visit aren't saved: their baskets and anything
## staff are carrying are counted back into the stockroom, which keeps the
## unit audit exact across a save/load.

const VERSION := 1
const DIR := "user://saves"


static func path(slot: String) -> String:
	return "%s/%s.json" % [DIR, slot]


static func exists(slot: String) -> bool:
	return FileAccess.file_exists(path(slot))


static func snapshot() -> Dictionary:
	var inv := Game.inventory.to_dict()
	# Fold transient units back into the stockroom figures.
	var sr: Dictionary = inv.stockroom
	if Game.customers:
		for c in Game.customers.customers:
			for pid in c.basket:
				sr[String(pid)] = int(sr.get(String(pid), 0)) + c.basket[pid]
	if Game.staff:
		for s in Game.staff.staff:
			if s.carry_n > 0:
				sr[String(s.carry_pid)] = int(sr.get(String(s.carry_pid), 0)) + s.carry_n
	var fixtures := []
	for f in Game.store.fixtures.values():
		fixtures.append(f.to_dict())
	var prices := {}
	for pid in Game.store.prices:
		prices[String(pid)] = Game.store.prices[pid]
	return {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"clock": Game.clock.to_dict(),
		"economy": Game.economy.to_dict(),
		"inventory": inv,
		"fixtures": fixtures,
		"prices": prices,
		"reputation": Game.reputation,
		"staff": Game.staff.to_array() if Game.staff else [],
	}


static func save(slot: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var data := snapshot()
	var tmp := path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "Couldn't write the save file"
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	# Write-then-rename so a crash mid-save never corrupts the old save.
	var err := DirAccess.rename_absolute(tmp, path(slot))
	if err != OK:
		return "Couldn't finalise the save file"
	return ""


static func read(slot: String) -> Dictionary:
	if not exists(slot):
		return {"error": "No save found"}
	var text := FileAccess.get_file_as_string(path(slot))
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return {"error": "That save file is damaged"}
	if int(data.get("version", 0)) > VERSION:
		return {"error": "That save is from a newer version of the game"}
	return data


static func apply(data: Dictionary) -> String:
	## Rebuilds the simulation from a save. Returns "" on success.
	if Game.customers:
		Game.customers.clear_all()
	if Game.staff:
		Game.staff.clear_all()
	# Clear the existing layout.
	for uid in Game.store.fixtures.keys():
		Game.store.remove(uid)
	Game.economy.from_dict(data.get("economy", {}))
	Game.clock.from_dict(data.get("clock", {}))
	Game.reputation = clampf(float(data.get("reputation", 0.5)), 0.0, 1.0)
	for k in data.get("prices", {}):
		if Game.catalog.product(StringName(k)):
			Game.store.prices[StringName(k)] = int(data.prices[k])
	var skipped := 0
	var restored_units := {}
	for fd in data.get("fixtures", []):
		var def := Game.catalog.fixture(StringName(fd.get("def", "")))
		if def == null:
			skipped += 1
			continue
		var anchor := Vector2i(int(fd.anchor[0]), int(fd.anchor[1]))
		var rot := int(fd.get("rot", 0))
		if Game.store.check_placement(def, anchor, rot) != "":
			skipped += 1
			continue
		var f := Game.store.add(def, anchor, rot, int(fd.get("uid", -1)))
		var slots: Array = fd.get("slots", [])
		for i in mini(slots.size(), f.slots.size()):
			var pid := StringName(slots[i].get("product", ""))
			if pid != &"" and Game.catalog.product(pid) and Merch.fits(Game.catalog.product(pid), def):
				f.slots[i].product = pid
				f.slots[i].cap = Merch.capacity(Game.catalog.product(pid), def)
				f.slots[i].qty = clampi(int(slots[i].get("qty", 0)), 0, f.slots[i].cap)
				restored_units[pid] = restored_units.get(pid, 0) + f.slots[i].qty
				f.changed.emit(i)
	Game.inventory.from_dict(data.get("inventory", {}))
	# Re-derive the audit baseline from what's physically present, so a save
	# edited by hand (or with skipped fixtures) still loads into a consistent
	# state instead of failing the conservation check.
	Game.inventory.total_received = Game.inventory.total_units_everywhere() + Game.inventory.total_sold + Game.inventory.total_written_off
	if Game.staff:
		Game.staff.from_array(data.get("staff", []))
	Game.store.prices_changed.emit()
	if skipped > 0:
		return "Loaded, but %d fixture%s couldn't be restored" % [skipped, "" if skipped == 1 else "s"]
	return ""
