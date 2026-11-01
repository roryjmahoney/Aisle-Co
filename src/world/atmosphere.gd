class_name Atmosphere
extends Node3D
## Lighting and mood, driven by the business clock. The sun travels east to
## west, warms at the ends of the day, and when it sets the street lamps and
## shop lights take over.

var env: Environment
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var camera_attrs: CameraAttributesPractical
var night_lights: Array = []
var interior_lights: Array = []
var _night_mat: ShaderMaterial
var override_minute := -1.0

# minute, sun colour, sun energy, elevation, background, ambient, ambient energy
const KEYS := [
	[300.0, Color("4a5f8f"), 0.05, -8.0, Color("2a3a5a"), Color("5a6f9e"), 0.35],
	[390.0, Color("ffb894"), 0.55, 6.0, Color("c9b6d0"), Color("b6b0cc"), 0.55],
	[480.0, Color("ffe2bf"), 1.15, 24.0, Color("b4d6dc"), Color("c3d8e2"), 0.7],
	[720.0, Color("fff6ea"), 1.35, 52.0, Color("a9d4de"), Color("cfe2e9"), 0.78],
	[1020.0, Color("ffe4b8"), 1.2, 30.0, Color("aed0d8"), Color("cfd9e0"), 0.72],
	[1140.0, Color("ffb27a"), 0.9, 12.0, Color("c7a9c4"), Color("c4bcd6"), 0.62],
	[1230.0, Color("d08a96"), 0.22, -2.0, Color("6f6a9c"), Color("7d80b2"), 0.45],
	[1320.0, Color("7b8fc7"), 0.12, -10.0, Color("27344f"), Color("4f6390"), 0.36],
	[1440.0, Color("6a7fb5"), 0.1, -12.0, Color("1f2b44"), Color("4a5d88"), 0.33],
]


func setup(parent: Node3D) -> void:
	name = "Atmosphere"
	parent.add_child(self)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a9d4de")
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("6fa8c9")
	sm.sky_horizon_color = Color("d9e8e6")
	sm.ground_horizon_color = Color("c9d6cf")
	sm.ground_bottom_color = Color("5d7a6a")
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cfe2e9")
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.8
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_strength = 0.9
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.6)
	env.set_glow_level(3, 0.3)
	env.fog_enabled = true
	env.fog_light_color = Color("a9d4de")
	env.fog_density = 0.0018
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.06
	world_env = WorldEnvironment.new()
	world_env.environment = env
	camera_attrs = CameraAttributesPractical.new()
	world_env.camera_attributes = camera_attrs
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.shadow_bias = 0.025
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 1.2
	add_child(sun)
	_night_mat = Materials.named("emit_night") as ShaderMaterial


func apply_settings(s: Settings) -> void:
	env.ssao_enabled = s.get_value("ssao")
	var sh: int = s.get_value("shadows")
	sun.shadow_enabled = sh > 0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if sh >= 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS


func _process(_delta: float) -> void:
	var minute := Game.clock.minute if override_minute < 0.0 else override_minute
	apply_time(minute)


func apply_time(minute: float) -> void:
	minute = fposmod(minute, 1440.0)
	var a: Array = KEYS[0]
	var b: Array = KEYS[KEYS.size() - 1]
	for i in KEYS.size() - 1:
		if minute >= KEYS[i][0] and minute <= KEYS[i + 1][0]:
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	if minute < KEYS[0][0]:
		a = KEYS[KEYS.size() - 1]
		b = KEYS[0]
	var span: float = fposmod(b[0] - a[0], 1440.0)
	var t: float = fposmod(minute - a[0], 1440.0) / maxf(span, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var sun_col: Color = (a[1] as Color).lerp(b[1], t)
	var sun_e: float = lerpf(a[2], b[2], t)
	var elev: float = lerpf(a[3], b[3], t)
	var bg: Color = (a[4] as Color).lerp(b[4], t)
	var amb: Color = (a[5] as Color).lerp(b[5], t)
	var amb_e: float = lerpf(a[6], b[6], t)

	# Sun arc: rises roughly behind-left of the shop, sets front-right, so
	# shadows rake across the façade through the afternoon.
	var day_t := clampf((minute - 360.0) / (1260.0 - 360.0), 0.0, 1.0)
	var azimuth := lerpf(-125.0, 70.0, day_t)
	var e := maxf(elev, 14.0) if sun_e > 0.15 else 40.0
	sun.rotation_degrees = Vector3(-e, azimuth, 0)
	sun.light_color = sun_col
	sun.light_energy = sun_e
	sun.shadow_opacity = clampf(sun_e * 1.1, 0.3, 0.92)
	env.background_color = bg
	env.fog_light_color = bg
	env.ambient_light_color = amb
	env.ambient_light_energy = amb_e

	# Night factor drives lamps.
	var night := 1.0 - clampf((sun_e - 0.15) / 0.5, 0.0, 1.0)
	for l in night_lights:
		if is_instance_valid(l):
			l.light_energy = 2.4 * night
			l.visible = night > 0.02
	for l in interior_lights:
		if is_instance_valid(l):
			if not l.has_meta("base"):
				l.set_meta("base", l.light_energy)
			l.light_energy = l.get_meta("base") * (1.0 + night * 0.9)
	if _night_mat:
		_night_mat.set_shader_parameter("energy", 0.15 + night * 3.0)
