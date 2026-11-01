class_name Capture
extends Node
## Scripted screenshots for visual review and regression checks.
##
## Usage (after `--` on the Godot command line):
##   --capture=<out_dir> --shots=<name>:<yaw>:<pitch>:<dist>:<fx>:<fz>:<minute>[;...]
## Optional: --settle=<frames> --sim=<seconds of simulation before shooting>

var _main: Node


static func parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
	if not out.has("capture"):
		return {}
	return out


func run(main: Node, args: Dictionary) -> void:
	_main = main
	var out_dir: String = args["capture"]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var settle := int(args.get("settle", "45"))
	var sim_seconds := float(args.get("sim", "0"))
	var shots: Array = []
	for s in String(args.get("shots", "overview:-24:44:21:10.2:7.4:600")).split(";", false):
		shots.append(s.split(":"))
	await get_tree().process_frame
	if args.has("open"):
		Game.clock.open_now()
	if sim_seconds > 0.0:
		Game.set_speed(4)
		var start := Game.sim_time
		var next_trace := 0.0
		while Game.sim_time - start < sim_seconds:
			await get_tree().process_frame
			if args.has("trace") and Game.sim_time >= next_trace:
				next_trace = Game.sim_time + 2.0
				for st in Game.staff.staff:
					print("t=%.1f %s state=%d pos=(%.2f,%.2f) path=%d goal=%s" % [Game.sim_time, st.display_name, st.state, st.pos.x, st.pos.z, st._path.size(), st._goal_cell])
		Game.set_speed(0)
	if args.has("dump"):
		_dump()
	if args.has("report") and not Game.economy.history.is_empty():
		var r: Dictionary = Game.economy.history[-1]
		print("DAY REPORT ", JSON.stringify(r))
	if args.has("actions"):
		await _actions(main, String(args["actions"]).split(",", false))
	if args.has("headless"):
		get_tree().quit()
		return
	for parts in shots:
		var rig: CameraRig = main.rig
		rig.snap_to(Vector3(float(parts[4]), Lot.FLOOR_Y, float(parts[5])), float(parts[1]), float(parts[2]), float(parts[3]))
		if parts.size() > 6:
			main.atmosphere.override_minute = float(parts[6])
		for i in settle:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [out_dir, parts[0]]
		img.save_png(path)
		print("CAPTURED ", path)
	get_tree().quit()


func _dump() -> void:
	print("--- STATE DUMP  t=%.1f  %s  cash=%d" % [Game.sim_time, Game.clock.time_string(), Game.economy.cash])
	for s in Game.staff.staff:
		print("staff %s role=%d state=%d pos=%s carry=%s:%d task=%s" % [s.display_name, s.role, s.state, s.pos, s.carry_pid, s.carry_n, s.task])
	for c in Game.customers.customers:
		print("cust %s state=%d pos=%s basket=%s list=%s" % [c.display_name, c.state, c.pos, c.basket, c.list.map(func(i): return "%s:%s" % [i.pid, i.status])])
	for l in Game.customers.lanes.values():
		print("lane %d queue=%d cashier=%s present=%s" % [l.fixture.uid, l.queue.size(), l.cashier.display_name if l.cashier else "-", l.cashier_present])
	print("report ", Game.economy.report)
	print("audit: '", Game.inventory.audit(), "'")


func _actions(main: Node, acts: PackedStringArray) -> void:
	## Scripted UI states for review shots.
	for a in acts:
		var p := a.split(":")
		match p[0]:
			"window":
				main.ui._set_active(p[1])
			"build":
				main.ui._set_active("build")
				main.build.begin_place(Game.catalog.fixture(StringName(p[1])))
				var at := Vector3(float(p[2]), Lot.FLOOR_Y, float(p[3]))
				if p.size() > 4:
					for i in int(p[4]):
						main.build.rotate_ghost(1)
				main.rig.snap_to(main.rig.focus, rad_to_deg(main.rig.yaw), rad_to_deg(main.rig.pitch), main.rig.distance)
				await get_tree().process_frame
				main.build._mouse = main.rig.camera.unproject_position(at)
				main.build._refresh(true)
			"select_fixture":
				main.selection.select(Game.store.fixtures[int(p[1])])
			"select_customer":
				if not Game.customers.customers.is_empty():
					main.selection.select(Game.customers.customers[mini(int(p[1]), Game.customers.customers.size() - 1)])
			"report":
				var r: Dictionary = Game.economy.report.duplicate(true)
				r["opening_cash"] = Game.economy.opening_cash
				r["closing_cash"] = Game.economy.cash
				r["gross_margin"] = r.revenue - r.cogs
				r["rent"] = Economy.RENT_PER_DAY
				r["upkeep"] = Economy.BASE_UTILITIES + Game.store.upkeep()
				r["operating_profit"] = r.gross_margin - r.rent - r.upkeep
				Game.day_report_ready.emit(r)
			"pause":
				main.ui._open_pause()
		await get_tree().process_frame
