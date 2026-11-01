class_name Materials
extends RefCounted
## Shared material library. Every material is created once and reused, which
## keeps the look consistent and lets the renderer batch aggressively.

static var _cache: Dictionary = {}


static func for_channel(ch: int) -> Material:
	var key := "ch_%d" % ch
	if _cache.has(key):
		return _cache[key]
	var m: Material
	match ch:
		MeshKit.Ch.PAINT:
			m = _vc(0.78, 0.0, 0.35)
		MeshKit.Ch.SATIN:
			m = _vc(0.48, 0.0, 0.5)
		MeshKit.Ch.GLOSS:
			m = _vc(0.22, 0.0, 0.6)
		MeshKit.Ch.METAL:
			m = _vc(0.32, 0.75, 0.5)
		MeshKit.Ch.GLASS:
			var g := _vc(0.04, 0.0, 0.8)
			g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = g
		MeshKit.Ch.EMIT:
			m = _shader("res://shaders/vc_emit.gdshader")
		MeshKit.Ch.WOOD:
			m = _shader("res://shaders/vc_wood.gdshader")
		_:
			m = _vc(0.8, 0.0, 0.3)
	_cache[key] = m
	return m


static func named(name: String) -> Material:
	if _cache.has(name):
		return _cache[name]
	var m: Material
	match name:
		"floor_shop":
			m = _shader("res://shaders/floor_tiles.gdshader")
		"floor_backroom":
			var s := _shader("res://shaders/terrain.gdshader")
			s.set_shader_parameter("mode", 3)
			s.set_shader_parameter("col_a", Color("a9aea8"))
			s.set_shader_parameter("col_b", Color("8e948e"))
			m = s
		"brick":
			m = _shader("res://shaders/brick.gdshader")
		"plaster":
			m = _shader("res://shaders/plaster.gdshader")
		"plaster_plain":
			var s := _shader("res://shaders/plaster.gdshader")
			s.set_shader_parameter("split_height", -1.0)
			m = s
		"grass":
			var s := _shader("res://shaders/terrain.gdshader")
			s.set_shader_parameter("mode", 0)
			s.set_shader_parameter("col_a", Palette.GRASS)
			s.set_shader_parameter("col_b", Palette.GRASS_DARK)
			m = s
		"paving":
			var s := _shader("res://shaders/terrain.gdshader")
			s.set_shader_parameter("mode", 1)
			s.set_shader_parameter("col_a", Palette.CONCRETE)
			s.set_shader_parameter("col_b", Palette.CONCRETE_DARK)
			s.set_shader_parameter("slab", 1.0)
			m = s
		"asphalt":
			var s := _shader("res://shaders/terrain.gdshader")
			s.set_shader_parameter("mode", 2)
			s.set_shader_parameter("col_a", Palette.ASPHALT)
			s.set_shader_parameter("col_b", Palette.shade(Palette.ASPHALT, -0.25))
			m = s
		"emit_night":
			var s := _shader("res://shaders/vc_emit.gdshader")
			s.set_shader_parameter("energy", 0.2)
			m = s
		"plinth":
			var p := StandardMaterial3D.new()
			p.albedo_color = Palette.PLINTH
			p.roughness = 0.7
			m = p
		_:
			push_warning("Materials: unknown material '%s'" % name)
			m = _vc(0.8, 0.0, 0.3)
	_cache[name] = m
	return m


static func ghost(valid: bool) -> Material:
	## Placement preview: a calm translucent tint, not a garish neon.
	var key := "ghost_%s" % valid
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.56, 0.88, 0.72, 0.42) if valid else Color(0.95, 0.4, 0.32, 0.45)
	m.cull_mode = BaseMaterial3D.CULL_BACK
	_cache[key] = m
	return m


static func highlight() -> Material:
	## Used as material_overlay to outline the hovered / selected object.
	if _cache.has("highlight"):
		return _cache["highlight"]
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.95, 0.70, 0.24, 1.0);
uniform float width = 0.018;
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = tint.a;
}
"""
	m.shader = sh
	_cache["highlight"] = m
	return m


static func _vc(roughness: float, metallic: float, specular: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = roughness
	m.metallic = metallic
	m.metallic_specular = specular
	return m


static func _shader(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	return m
