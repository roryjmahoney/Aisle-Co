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
	if sim_seconds > 0.0:
		Game.set_speed(4)
		var t := 0.0
		while t < sim_seconds:
			await get_tree().process_frame
			t += get_process_delta_time() * 4.0
		Game.set_speed(0)
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
