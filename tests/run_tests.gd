extends Node
## Headless test suite.
##   godot --headless --path . res://tests/test_runner.tscn
## Exits with code 0 when everything passes, 1 otherwise.
## Every test must end with `return true`: a test that crashes part-way
## returns null and is counted as a failure, never as a silent pass.

var _failures := 0
var _passes := 0
var _current := ""
var game: Node
var root: Window


func _ready() -> void:
	game = Game
	root = get_tree().root
	_run.call_deferred()


func _run() -> void:
	var tests := [
		"test_money_format", "test_ledger_integrity", "test_merch_capacity_matches_layout",
		"test_placement_rules", "test_inventory_conservation", "test_slot_reassignment",
		"test_order_delivery", "test_clock_phases", "test_sfx_levels",
		"test_full_day", "test_save_roundtrip",
	]
	for t in tests:
		_current = t
		game.new_world()
		var before := _failures
		var finished: Variant = await call(t)
		if finished != true:
			check(false, "test did not run to completion (script error?)")
		if _failures == before:
			_passes += 1
			print("  PASS  ", t)
		else:
			print("  FAIL  ", t)
	print("\n%d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("    ✗ [%s] %s" % [_current, msg])


# --- Unit tests ------------------------------------------------------------------

func test_money_format() -> bool:
	check(Fmt.money(0) == "$0.00", "zero")
	check(Fmt.money(123456) == "$1,234.56", "grouping: " + Fmt.money(123456))
	check(Fmt.money(-505).ends_with("$5.05"), "negative")
	check(Fmt.money(100000000, false) == "$1,000,000", "millions")
	return true


func test_ledger_integrity() -> bool:
	var e: Economy = game.economy
	var start := e.cash
	check(e.ledger_balance() == e.cash, "ledger matches opening cash")
	check(e.charge(Economy.Kind.BUILD, 1234, "x"), "affordable charge succeeds")
	check(not e.charge(Economy.Kind.BUILD, e.cash + 1, "too much"), "unaffordable charge refused")
	e.credit(Economy.Kind.REFUND, 1000, "refund")
	check(e.cash == start - 234, "cash arithmetic")
	e.charge(Economy.Kind.RENT, e.cash + 500, "debt", true)
	check(e.cash == -500, "mandatory costs may go into debt")
	check(e.ledger_balance() == e.cash, "ledger still matches after many posts")
	var r := e.close_day(0, 0)
	check(r.operating_profit == r.revenue - r.cogs - r.rent - r.upkeep - r.wages, "P&L identity")
	return true


func test_merch_capacity_matches_layout() -> bool:
	for pid in game.catalog.products:
		var p: ProductDef = game.catalog.products[pid]
		for fid in game.catalog.fixtures:
			var d: FixtureDef = game.catalog.fixtures[fid]
			var cap := Merch.capacity(p, d)
			var lay := Merch.layout(p, d, 1)
			check(cap == lay.size(), "%s on %s: capacity %d vs %d visible" % [pid, fid, cap, lay.size()])
			if Merch.fits(p, d):
				check(cap > 0, "%s fits %s but holds nothing" % [pid, fid])
				for t in lay:
					check(absf(t.origin.x) <= d.slot_size.x * 0.5 + 0.01, "%s unit outside tier width" % pid)
					check(-t.origin.z <= d.slot_size.z + 0.02, "%s unit beyond tier depth" % pid)
	return true


func test_placement_rules() -> bool:
	var s: Store = game.store
	var shelf: FixtureDef = game.catalog.fixture(&"shelf_wall")
	var rack: FixtureDef = game.catalog.fixture(&"storage_rack")
	var island: FixtureDef = game.catalog.fixture(&"shelf_island")
	check(s.check_placement(shelf, Vector2i(14, 13), 0) == "", "open floor is valid: " + s.check_placement(shelf, Vector2i(14, 13), 0))
	check(s.check_placement(shelf, Vector2i(2, 2), 0) != "", "outside the store is invalid")
	check(s.check_placement(rack, Vector2i(14, 13), 0) == "Stockroom only", "rack refused on shop floor")
	check(s.check_placement(rack, Vector2i(14, 4), 0) == "", "rack allowed in stockroom")
	check(s.check_placement(shelf, Vector2i(24, 20), 0) != "", "doorway must stay clear")
	# Straddling the stockroom partition.
	check(s.check_placement(island, Vector2i(14, 8), 0) != "", "can't straddle a wall")
	s.add(shelf, Vector2i(14, 13), 0)
	check(s.check_placement(shelf, Vector2i(14, 13), 0) == "Overlaps something", "overlap rejected")
	# Directly in front of it would block its aisle.
	var err := s.check_placement(shelf, Vector2i(14, 14), 0)
	check(err.begins_with("Blocks access") or err == "Needs a clear aisle in front", "blocking an aisle is rejected: " + err)
	# Walling off the staff door must be refused.
	var err2 := s.check_placement(island, Vector2i(9, 9), 0)
	check(err2 != "", "can't block the stockroom route")
	return true


func test_inventory_conservation() -> bool:
	var s: Store = game.store
	var inv: Inventory = game.inventory
	var f := s.add(game.catalog.fixture(&"shelf_wall"), Vector2i(14, 13), 0)
	s.add(game.catalog.fixture(&"storage_rack"), Vector2i(14, 4), 0)
	inv.seed_stockroom(&"soup", 96)
	inv.assign_slot(f, 0, &"soup")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var baskets := {}
	for i in 400:
		match rng.randi() % 5:
			0: inv.restock_slot(f, 0, rng.randi_range(1, 30))
			1:
				var got := inv.pick(f, 0, rng.randi_range(1, 4))
				baskets[&"soup"] = baskets.get(&"soup", 0) + got
			2:
				if baskets.get(&"soup", 0) > 0:
					var n: int = rng.randi_range(1, baskets[&"soup"])
					inv.sell_from_basket(n)
					baskets[&"soup"] -= n
			3:
				if baskets.get(&"soup", 0) > 0:
					inv.return_basket({&"soup": baskets[&"soup"]})
					baskets[&"soup"] = 0
			4:
				var t := inv.take_for_restock(&"soup", rng.randi_range(1, 12))
				var put := inv.put_on_shelf(f, 0, &"soup", t)
				inv.return_transit(&"soup", t - put)
		var a := inv.audit()
		if a != "":
			check(false, "step %d: %s" % [i, a])
			return false
	check(inv.units(&"soup") >= 0 and f.slots[0].qty >= 0, "never negative")
	return true


func test_slot_reassignment() -> bool:
	var s: Store = game.store
	var inv: Inventory = game.inventory
	var f := s.add(game.catalog.fixture(&"shelf_wall"), Vector2i(14, 13), 0)
	s.add(game.catalog.fixture(&"storage_rack"), Vector2i(14, 4), 0)
	inv.assign_slot(f, 0, &"jam")
	inv.seed_shelf(f, 0, 10)
	check(inv.assign_slot(f, 0, &"milk") != "", "chilled product refused on ambient shelf")
	check(inv.assign_slot(f, 0, &"soup") == "", "reassign allowed")
	check(inv.units(&"jam") == 10 and f.slots[0].qty == 0, "old stock returned to stockroom")
	check(inv.audit() == "", "audit after reassignment")
	return true


func test_order_delivery() -> bool:
	var s: Store = game.store
	var inv: Inventory = game.inventory
	var e: Economy = game.economy
	s.add(game.catalog.fixture(&"storage_rack"), Vector2i(14, 4), 0)
	var cash := e.cash
	var o := inv.place_order({&"soup": 2, &"milk": 1})
	check(not o.has("error"), "order accepted")
	var cost: int = 2 * 24 * 85 + 1 * 12 * 95
	check(e.cash == cash - cost, "charged exactly once: %d" % (cash - e.cash))
	check(inv.free_cases() == 18 - 3, "incoming cases reserve space")
	check(inv.place_order({&"soup": 99}).has("error"), "over-capacity order refused")
	game.clock.open_now()
	var steps := 0
	while not inv.orders.is_empty() and steps < 20000:
		game._step(game.STEP)
		steps += 1
	check(inv.orders.is_empty(), "delivery completed")
	check(inv.units(&"soup") == 48 and inv.units(&"milk") == 12, "units received")
	check(e.cash == cash - cost, "no extra charges on delivery")
	check(inv.audit() == "", "audit after delivery: " + inv.audit())
	return true


func test_clock_phases() -> bool:
	var c := SimClock.new()
	var seen := []
	c.phase_changed.connect(func(p): seen.append(p))
	for i in 3000:
		c.step(0.25)
	check(seen.has(SimClock.Phase.OPEN) and seen.has(SimClock.Phase.CLOSING), "opens then closes")
	c.finish_closing()
	check(c.phase == SimClock.Phase.CLOSED, "closed after last shopper")
	c.start_next_day()
	check(c.day == 2 and c.phase == SimClock.Phase.PREOPEN, "next morning")
	return true


func test_sfx_levels() -> bool:
	for name in ["tick", "ui_click", "ui_open", "ui_close", "place", "remove", "rotate", "deny", "undo", "scan",
			"register", "door_chime", "delivery", "shutter", "coins", "day_end", "pick"]:
		var w := Sfx.stream(name)
		var peak := 0
		for i in range(0, w.data.size(), 2):
			peak = maxi(peak, absi(w.data.decode_s16(i)))
		check(peak < 32000, "%s clips (peak %d)" % [name, peak])
		check(peak > 300, "%s is near-silent (peak %d)" % [name, peak])
	return true


# --- Integration tests (full scene) ---------------------------------------------

func _load_main() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await get_tree().process_frame
	return main


func _unload(main: Node) -> void:
	main.queue_free()
	await get_tree().process_frame
	game.customers = null
	game.staff = null
	game.world = null


func test_full_day() -> bool:
	var main := await _load_main()
	var reports := []
	game.day_report_ready.connect(func(r): reports.append(r), CONNECT_ONE_SHOT)
	game.clock.open_now()
	var steps := 0
	while reports.is_empty() and steps < 40000:
		game._step(game.STEP)
		steps += 1
		if steps % 3000 == 0:
			var a: String = game.inventory.audit()
			if a != "":
				check(false, "mid-day audit at step %d: %s" % [steps, a])
				break
	check(not reports.is_empty(), "day closed (steps=%d, phase=%d, shoppers=%d)" % [steps, game.clock.phase, game.customers.customers.size()])
	if not reports.is_empty():
		var r: Dictionary = reports[0]
		check(r.customers > 20, "reasonable footfall: %d" % r.customers)
		check(r.served > 0 and r.revenue > 0, "made sales")
		check(r.served + r.lost <= r.customers, "outcome counts consistent")
		print("      day: %d shoppers, %d served, sales %s, profit %s" % [r.customers, r.served, Fmt.money(r.revenue), Fmt.money(r.operating_profit)])
	check(game.customers.customers.is_empty(), "everyone went home")
	check(game.inventory.audit() == "", "end-of-day audit: " + game.inventory.audit())
	check(game.economy.ledger_balance() == game.economy.cash, "cash equals ledger")
	await _unload(main)
	return true


func test_save_roundtrip() -> bool:
	var main := await _load_main()
	game.clock.open_now()
	for i in 1500:
		game._step(game.STEP)
	var before := SaveManager.snapshot()
	var json := JSON.stringify(before)
	var parsed: Dictionary = JSON.parse_string(json)
	var msg := SaveManager.apply(parsed)
	check(msg == "", "applied cleanly: " + msg)
	var after := SaveManager.snapshot()
	check(after.economy.cash == before.economy.cash, "cash restored")
	check(after.fixtures.size() == before.fixtures.size(), "fixtures restored")
	check(JSON.stringify(after.inventory.stockroom) == JSON.stringify(before.inventory.stockroom), "stockroom restored")
	var shelf_units_before := 0
	for f in before.fixtures:
		for s in f.slots:
			shelf_units_before += int(s.qty)
	var shelf_units_after := 0
	for f in game.store.fixtures.values():
		shelf_units_after += f.total_units()
	check(shelf_units_before == shelf_units_after, "shelf stock restored (%d vs %d)" % [shelf_units_before, shelf_units_after])
	check(game.inventory.audit() == "", "audit after load: " + game.inventory.audit())
	# The game keeps running after a load.
	for i in 600:
		game._step(game.STEP)
	check(game.inventory.audit() == "", "audit after playing on")
	await _unload(main)
	return true
