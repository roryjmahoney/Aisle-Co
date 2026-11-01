class_name FixtureView
extends Node3D
## Renders one Fixture and keeps it in sync with the simulation:
## * one MultiMesh per shelf tier — the visible units *are* the stock
## * header signs naming what the fixture sells
## * shelf-edge price tags (only drawn when the camera is close)
## * fridge doors that swing open when someone reaches in

const CATEGORY_NAMES := {"pantry": "PANTRY", "drinks": "DRINKS", "dairy": "DAIRY", "produce": "PRODUCE", "household": "HOUSEHOLD"}

var fixture: Fixture
var art: Dictionary
var body: MeshInstance3D
var _tiers: Array[MultiMeshInstance3D] = []
var _tier_layout: Array = []
var _tags: Array[Label3D] = []
var _headers: Array[Label3D] = []
var _doors: Array[Node3D] = []
var _door_open: Array[float] = []
var _door_hold: Array[float] = []
var _cases: MultiMeshInstance3D
var _case_by_product: Dictionary = {}
var _highlight := false
var _pop := 0.0


func setup(f: Fixture) -> void:
	fixture = f
	name = "Fixture_%d" % f.uid
	art = FixtureArt.build(f.def)
	body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = art.mesh
	add_child(body)
	_sync_transform()
	_build_parts()
	_build_labels()
	_build_tiers()
	f.changed.connect(_on_changed)
	for i in f.slots.size():
		_refresh_slot(i)
	if f.def.storage_cases > 0:
		refresh_cases({})


func _sync_transform() -> void:
	position = fixture.world_center() + Vector3(0, Lot.FLOOR_Y, 0)
	rotation = Vector3(0, fixture.yaw(), 0)


func relocate() -> void:
	_sync_transform()
	play_pop()


func play_pop() -> void:
	## A small settle when placed: drops 6 cm and squashes very slightly.
	_pop = 1.0


func _process(delta: float) -> void:
	if _pop > 0.0:
		_pop = maxf(_pop - delta * 3.2, 0.0)
		var e := _pop * _pop
		body.position.y = e * 0.06
		var sq := 1.0 - sin((1.0 - _pop) * PI) * 0.03
		body.scale = Vector3(2.0 - sq, sq, 2.0 - sq)
	for i in _doors.size():
		_door_hold[i] = maxf(_door_hold[i] - delta, 0.0)
		var target := 1.0 if _door_hold[i] > 0.0 else 0.0
		if not is_equal_approx(_door_open[i], target):
			_door_open[i] = move_toward(_door_open[i], target, delta * (2.4 if target > 0.5 else 1.5))
			var e2 := _door_open[i] * _door_open[i] * (3.0 - 2.0 * _door_open[i])
			var sign_ := 1.0 if _doors[i].get_meta("mirror") else -1.0
			_doors[i].rotation.y = sign_ * e2 * deg_to_rad(80)


func open_door_near(local_x: float) -> void:
	if _doors.is_empty():
		return
	var i := 0 if local_x < 0.0 else 1
	i = mini(i, _doors.size() - 1)
	_door_hold[i] = 1.4


func set_highlight(on: bool) -> void:
	if _highlight == on:
		return
	_highlight = on
	body.material_overlay = Materials.highlight() if on else null


# --- Construction -----------------------------------------------------------

func _build_parts() -> void:
	for d in art.parts.get("doors", []):
		var hinge := Node3D.new()
		hinge.position = d.hinge
		hinge.set_meta("mirror", d.mirror)
		add_child(hinge)
		var m := MeshInstance3D.new()
		m.mesh = d.mesh
		if d.mirror:
			m.scale.x = -1.0
		hinge.add_child(m)
		_doors.append(hinge)
		_door_open.append(0.0)
		_door_hold.append(0.0)
	for l in art.lights:
		var o := OmniLight3D.new()
		o.position = l.pos
		o.light_color = l.color
		o.light_energy = l.energy
		o.omni_range = l.range
		o.shadow_enabled = l.get("shadow", false)
		o.light_specular = 0.3
		add_child(o)


func _build_labels() -> void:
	for spec in art.labels:
		var l := Label3D.new()
		l.position = spec.pos
		l.pixel_size = 0.001
		l.font_size = int(spec.size * 1000.0 * 0.8)
		l.shaded = true
		l.double_sided = false
		if spec.get("flip", false):
			l.rotation.y = PI
		if spec.has("tilt"):
			l.rotation.x = spec.tilt
		match spec.kind:
			"header":
				l.font = Fonts.display(800, 80)
				l.modulate = spec.get("color", Palette.MARIGOLD)
				l.text = spec.get("text", "")
				if not spec.has("text"):
					_headers.append(l)
			"lane":
				l.font = Fonts.display(800, 90)
				l.modulate = Palette.INK
				l.text = str(fixture.uid % 10 if fixture.uid % 10 != 0 else 1)
				l.position += Vector3(0, 0, 0.002 * (-1.0 if spec.get("flip", false) else 1.0))
				l.shaded = false
			"chalk":
				l.font = Fonts.display(700, 85)
				l.modulate = Color(0.95, 0.96, 0.93, 0.92)
				l.text = "TODAY\nfresh\nfrom the\nfarm"
				l.line_spacing = -8
				l.font_size = 64
				l.pixel_size = 0.0011
		add_child(l)


func _build_tiers() -> void:
	for i in art.slots.size():
		var s: Dictionary = art.slots[i]
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Tier%d" % i
		var side: float = s.facing
		mmi.transform = Transform3D(Basis(Vector3.UP, 0.0 if side > 0.0 else PI), s.origin)
		add_child(mmi)
		_tiers.append(mmi)
		_tier_layout.append([])
		if fixture.def.slot_count > 0:
			var tag := Label3D.new()
			tag.font = Fonts.numeric(800)
			tag.font_size = 40
			tag.pixel_size = 0.001
			tag.modulate = Palette.INK
			tag.shaded = true
			tag.outline_size = 0
			tag.visibility_range_end = 9.0
			tag.visibility_range_end_margin = 1.5
			tag.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			tag.position = Vector3(-0.5, -0.006, 0.014)
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mmi.add_child(tag)
			# Marigold tag card behind the price.
			var card := MeshInstance3D.new()
			var k := MeshKit.new()
			k.box(Vector3(-0.5, -0.006, 0.011), Vector3(0.11, 0.036, 0.004), Palette.MARIGOLD, MeshKit.Ch.SATIN, 0.002)
			card.mesh = k.build()
			card.visibility_range_end = 14.0
			mmi.add_child(card)
			card.visible = false
			tag.visible = false
			tag.set_meta("card", card)
			_tags.append(tag)


func _on_changed(slot: int) -> void:
	_refresh_slot(slot)


func _refresh_slot(i: int) -> void:
	if i >= _tiers.size() or i >= fixture.slots.size():
		return
	var s := fixture.slots[i]
	var mmi := _tiers[i]
	var p: ProductDef = Game.catalog.product(s.product) if s.product != &"" else null
	if p == null:
		mmi.multimesh = null
		_set_tag(i, null)
		_update_headers()
		return
	var mm := mmi.multimesh
	if mm == null or mm.mesh != ProductArt.unit_mesh(p) or mm.instance_count != s.cap:
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = ProductArt.unit_mesh(p)
		var layout := Merch.layout(p, fixture.def, fixture.uid * 31 + i * 7)
		mm.instance_count = layout.size()
		for j in layout.size():
			mm.set_instance_transform(j, layout[j])
		mmi.multimesh = mm
		_tier_layout[i] = layout
	mm.visible_instance_count = clampi(s.qty, 0, mm.instance_count)
	_set_tag(i, p)
	_update_headers()


func _set_tag(i: int, p: ProductDef) -> void:
	if i >= _tags.size():
		return
	var tag := _tags[i]
	var card: MeshInstance3D = tag.get_meta("card")
	tag.visible = p != null
	card.visible = p != null
	if p:
		tag.text = Fmt.money(Game.store.price_of(p.id))


func refresh_prices() -> void:
	for i in fixture.slots.size():
		var pid: StringName = fixture.slots[i].product
		_set_tag(i, Game.catalog.product(pid) if pid != &"" else null)


func _update_headers() -> void:
	if _headers.is_empty():
		return
	var counts := {}
	for s in fixture.slots:
		if s.product != &"":
			var cat: String = Game.catalog.product(s.product).category
			counts[cat] = counts.get(cat, 0) + 1
	var best := ""
	for c in counts:
		if best == "" or counts[c] > counts[best]:
			best = c
	for h in _headers:
		h.text = CATEGORY_NAMES.get(best, "")


# --- Stockroom cases --------------------------------------------------------

func refresh_cases(alloc: Dictionary) -> void:
	## alloc: pid -> number of cases this rack should show.
	if _cases == null:
		_cases = MultiMeshInstance3D.new()
		_cases.name = "Cases"
		add_child(_cases)
	for c in _case_by_product.values():
		c.queue_free()
	_case_by_product.clear()
	var spots := case_spots()
	var k := 0
	for pid in alloc:
		var n: int = alloc[pid]
		if n <= 0:
			continue
		var p := Game.catalog.product(pid)
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = ProductArt.case_mesh(p)
		mm.instance_count = n
		for j in n:
			if k < spots.size():
				mm.set_instance_transform(j, spots[k])
			k += 1
		mmi.multimesh = mm
		add_child(mmi)
		_case_by_product[pid] = mmi


func case_spots() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var cs := ProductArt.case_size()
	var deck: Vector2 = art.get("deck_size", Vector2(1.3, 0.8))
	var across := int(deck.x / (cs.x + 0.03) + 0.001)
	var deep := int(deck.y / (cs.z + 0.03) + 0.001)
	var rng := RandomNumberGenerator.new()
	rng.seed = fixture.uid
	for s in art.slots:
		var c: Vector3 = s.deck_center
		for dz in deep:
			for ax in across:
				var x := (ax - (across - 1) * 0.5) * (cs.x + 0.03)
				var z := (dz - (deep - 1) * 0.5) * (cs.z + 0.03)
				var b := Basis(Vector3.UP, rng.randf_range(-0.04, 0.04))
				out.append(Transform3D(b, c + Vector3(x + rng.randf_range(-0.01, 0.01), 0.0, -z)))
	return out
