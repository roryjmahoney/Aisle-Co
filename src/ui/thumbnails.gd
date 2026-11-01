class_name Thumbnails
extends Node
## Renders each buildable fixture's real 3D model into a small transparent
## texture once, for the build menu. No hand-drawn stand-ins.

const SIZE := Vector2i(208, 168)

var _tex: Dictionary = {}


func get_tex(def: FixtureDef) -> Texture2D:
	if _tex.has(def.id):
		return _tex[def.id]
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d7e6e8")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color("fff3e2")
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.35
	fill.light_color = Color("cfe6ff")
	vp.add_child(fill)
	var art := FixtureArt.build(def)
	var mi := MeshInstance3D.new()
	mi.mesh = art.mesh
	vp.add_child(mi)
	# Dress shelves with a little stock so they read as shelves at a glance.
	if def.slot_count > 0:
		var pids := [&"oats", &"soup", &"water", &"jam"] if def.slot_storage == "ambient" else [&"milk", &"cheddar", &"milk", &"cheddar"]
		for i in art.slots.size():
			var p: ProductDef = Game.catalog.product(pids[i % pids.size()])
			if p == null or not Merch.fits(p, def):
				continue
			var s: Dictionary = art.slots[i]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = ProductArt.unit_mesh(p)
			var layout := Merch.layout(p, def, i)
			mm.instance_count = layout.size()
			for j in layout.size():
				mm.set_instance_transform(j, layout[j])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.transform = Transform3D(Basis(Vector3.UP, 0.0 if s.facing > 0.0 else PI), s.origin)
			vp.add_child(mmi)
	for d in art.parts.get("doors", []):
		var dm := MeshInstance3D.new()
		dm.mesh = d.mesh
		dm.position = d.hinge
		if d.mirror:
			dm.scale.x = -1.0
		vp.add_child(dm)
	var aabb: AABB = art.mesh.get_aabb()
	var cam := Camera3D.new()
	cam.fov = 26.0
	var center := aabb.get_center()
	var radius := aabb.size.length() * 0.5
	var dir := Vector3(0.62, 0.48, 1.0).normalized()
	cam.position = center + dir * radius / sin(deg_to_rad(cam.fov * 0.5)) * 0.92
	vp.add_child(cam)
	cam.look_at(center, Vector3.UP)
	var t := vp.get_texture()
	_tex[def.id] = t
	return t
