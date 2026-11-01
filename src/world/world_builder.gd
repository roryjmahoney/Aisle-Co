class_name WorldBuilder
extends RefCounted
## Assembles the static world: the diorama plinth, street, pavement, the
## building shell and the street furniture around it.
##
## Everything is composed with MeshKit and the shared material library, so the
## environment shares one visual language with the fixtures and products.

const C := MeshKit.Ch
const STUB_H := 0.35

var root: Node3D
var grid: StoreGrid
## Emissive bits that should only glow at night (street lamp heads).
var night_kit := MeshKit.new()
var _front_upper: Node3D
## Tall street furniture that would block the view into the shop; hidden
## together with the front wall when the camera looks in.
var lamp_kit := MeshKit.new()
var result := {
	"walls": [],          # Array[WallRun]
	"entrance": null,     # EntranceDoor
	"shutter": null,      # LoadingShutter
	"night_lights": [],   # lights that switch on at dusk
	"interior_lights": [],
	"street_occluders": null,
	"open_sign": null,
}


class _Kits:
	## Six builders for one wall group: {stub, upper} x {brick, plaster, vc}.
	var stub_brick := MeshKit.new()
	var stub_plaster := MeshKit.new()
	var stub_vc := MeshKit.new()
	var up_brick := MeshKit.new()
	var up_plaster := MeshKit.new()
	var up_vc := MeshKit.new()
	var split_y := 0.0

	func _init(y: float) -> void:
		split_y = y
		for k in [up_brick, up_plaster, up_vc]:
			k.push(Transform3D(Basis.IDENTITY, Vector3(0, -y, 0)))

	func box(kind: String, center: Vector3, size: Vector3, color: Color = Color.WHITE,
			ch: int = MeshKit.Ch.PAINT, bevel: float = 0.0) -> void:
		## Splits the box at the stub height so the lower part stays put when the
		## wall is cut away.
		var y0 := center.y - size.y * 0.5
		var y1 := center.y + size.y * 0.5
		var lo: MeshKit
		var hi: MeshKit
		match kind:
			"brick":
				lo = stub_brick
				hi = up_brick
			"plaster":
				lo = stub_plaster
				hi = up_plaster
			_:
				lo = stub_vc
				hi = up_vc
		if y1 <= split_y + 0.001:
			lo.box(center, size, color, ch, bevel)
		elif y0 >= split_y - 0.001:
			hi.box(center, size, color, ch, bevel)
		else:
			var a := Vector3(center.x, (y0 + split_y) * 0.5, center.z)
			lo.box(a, Vector3(size.x, split_y - y0, size.z), color, ch)
			var b := Vector3(center.x, (split_y + y1) * 0.5, center.z)
			hi.box(b, Vector3(size.x, y1 - split_y, size.z), color, ch, bevel)


static func build(parent: Node3D, g: StoreGrid) -> Dictionary:
	var wb := WorldBuilder.new()
	wb.root = Node3D.new()
	wb.root.name = "World"
	parent.add_child(wb.root)
	wb.grid = g
	wb._ground()
	wb._street()
	wb._building()
	wb._props()
	return wb.result


# --- Helpers ----------------------------------------------------------------

func _mi(mesh: Mesh, node_name: String, parent: Node3D = null, cast_shadow: bool = true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = node_name
	m.mesh = mesh
	if not cast_shadow:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else root).add_child(m)
	return m


func _plane(mat_name: String, rect_m: Rect2, y: float, node_name: String) -> void:
	var k := MeshKit.new()
	k.box(Vector3(rect_m.get_center().x, y - 0.01, rect_m.get_center().y),
			Vector3(rect_m.size.x, 0.02, rect_m.size.y), Color.WHITE, C.PAINT)
	_mi(k.build({C.PAINT: Materials.named(mat_name)}), node_name, null, false)


static func _r(cells: Rect2i) -> Rect2:
	return Rect2(cells.position.x * StoreGrid.CELL, cells.position.y * StoreGrid.CELL,
			cells.size.x * StoreGrid.CELL, cells.size.y * StoreGrid.CELL)


# --- Ground & plinth ---------------------------------------------------------

func _ground() -> void:
	var w := Lot.m(Lot.W)
	var d := Lot.m(Lot.D)
	var k := MeshKit.new()
	# The diorama plinth: a dark presentation base with a soil band at the cut.
	k.box(Vector3(w * 0.5, -0.67, d * 0.5), Vector3(w + 0.3, 1.0, d + 0.3), Palette.PLINTH, C.SATIN, 0.05, 2)
	# Soil band stops just short of the surface so it never fights the grass.
	k.box(Vector3(w * 0.5, -0.085, d * 0.5), Vector3(w + 0.02, 0.15, d + 0.02), Palette.SOIL, C.PAINT)
	k.box(Vector3(w * 0.5, -0.175, d * 0.5), Vector3(w + 0.06, 0.03, d + 0.06), Palette.shade(Palette.SOIL, -0.25), C.PAINT)
	_mi(k.build(), "Plinth")
	_plane("grass", Rect2(-0.01, -0.01, w + 0.02, d + 0.02), 0.0, "Grass")


func _street() -> void:
	var road := _r(Lot.ROAD)
	_plane("asphalt", road, 0.012, "Road")
	var k := MeshKit.new()
	var paint := Palette.ROAD_PAINT
	var cz := road.get_center().y
	# Dashed centre line and solid edge lines.
	var x := 0.4
	while x < road.end.x - 0.5:
		k.box(Vector3(x + 0.6, 0.014, cz), Vector3(1.2, 0.006, 0.1), paint, C.PAINT)
		x += 2.4
	for z in [road.position.y + 0.35, road.end.y - 0.35]:
		k.box(Vector3(road.get_center().x, 0.014, z), Vector3(road.size.x, 0.006, 0.08), paint, C.PAINT)
	# Zebra crossing aligned with the shop entrance.
	var cross_x := Lot.m(Lot.ENTRANCE.x + 1.5)
	for i in 8:
		var zz := road.position.y + 0.65 + i * 0.5
		k.box(Vector3(cross_x, 0.015, zz + 0.18), Vector3(2.0, 0.006, 0.32), paint, C.PAINT)
	# Drain grate and manhole cover.
	k.cylinder(Vector3(Lot.m(44), 0.012, cz + 1.0), 0.32, 0.006, Palette.shade(Palette.ASPHALT, -0.3), C.METAL, 18)
	k.box(Vector3(Lot.m(18), 0.012, road.position.y + 0.25), Vector3(0.5, 0.008, 0.25), Palette.STEEL_DARK, C.METAL)
	_mi(k.build(), "RoadMarkings", null, false)

	# Pavements: raised slabs with a bevelled kerb that catches the light.
	var sw := _r(Lot.SIDEWALK)
	var apron_end := Lot.m(Lot.DRIVEWAY.end.x)
	_raised_paving(Rect2(apron_end, sw.position.y, sw.end.x - apron_end, sw.size.y), "Pavement")
	var far := _r(Lot.FAR_SIDEWALK)
	_raised_paving(far, "FarPavement")
	# Dropped kerb + driveway apron in poured concrete.
	var dw := _r(Lot.DRIVEWAY)
	var ap := MeshKit.new()
	ap.box(Vector3(dw.get_center().x, 0.02, (dw.position.y + sw.end.y) * 0.5),
			Vector3(dw.size.x, 0.04, sw.end.y - dw.position.y), Color.WHITE, C.PAINT)
	_mi(ap.build({C.PAINT: Materials.named("floor_backroom")}), "Driveway", null, false)
	var kerb := MeshKit.new()
	for zline in [sw.end.y, far.position.y]:
		var dz := -0.08 if zline == sw.end.y else 0.08
		kerb.box(Vector3(road.get_center().x + apron_end * 0.5, Lot.FLOOR_Y * 0.5 + 0.005, zline + dz),
				Vector3(road.size.x - apron_end, Lot.FLOOR_Y + 0.01, 0.16), Palette.shade(Palette.CONCRETE, 0.08), C.PAINT, 0.025, 2)
	kerb.box(Vector3(dw.get_center().x, 0.03, sw.end.y - 0.08), Vector3(dw.size.x, 0.05, 0.16),
			Palette.shade(Palette.CONCRETE, 0.08), C.PAINT, 0.02)
	_mi(kerb.build(), "Kerbs")


func _raised_paving(r: Rect2, node_name: String) -> void:
	var k := MeshKit.new()
	k.box(Vector3(r.get_center().x, Lot.FLOOR_Y * 0.5, r.get_center().y),
			Vector3(r.size.x, Lot.FLOOR_Y, r.size.y), Color.WHITE, C.PAINT)
	_mi(k.build({C.PAINT: Materials.named("paving")}), node_name, null, false)


# --- Building ---------------------------------------------------------------

func _building() -> void:
	var x0 := Lot.m(Lot.LEFT_X)
	var x1 := Lot.m(Lot.RIGHT_X)
	var z0 := Lot.m(Lot.BACK_Z)
	var z1 := Lot.m(Lot.FRONT_Z)
	var t := Lot.EXT_T
	var fy := Lot.FLOOR_Y

	# Foundation and floors.
	var fk := MeshKit.new()
	fk.box(Vector3((x0 + x1) * 0.5, fy * 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0 + t * 2 + 0.06, fy, z1 - z0 + t * 2 + 0.06),
			Palette.CONCRETE_DARK, C.PAINT, 0.02)
	_mi(fk.build(), "Foundation")
	_plane("floor_shop", _r(Lot.SHOP), fy + 0.004, "ShopFloor")
	_plane("floor_backroom", _r(Lot.BACKROOM), fy + 0.004, "StockroomFloor")
	# Skirting along the partition's shop side is part of the wall; add a
	# dark threshold strip under the staff doorway.
	var sk := MeshKit.new()
	sk.box(Vector3(Lot.m(Lot.STAFF_DOOR.x + 1), fy + 0.006, Lot.m(Lot.PARTITION_Z)), Vector3(1.0, 0.008, 0.16), Palette.STEEL_DARK, C.METAL)
	_mi(sk.build(), "Thresholds", null, false)

	var sides := {
		"back": Vector3(0, 0, -1), "left": Vector3(-1, 0, 0), "right": Vector3(1, 0, 0),
		"front": Vector3(0, 0, 1), "partition": Vector3(0, 0, 1),
	}
	var groups := {}
	for s in sides:
		var run := WallRun.new()
		run.setup(s, sides[s])
		root.add_child(run)
		groups[s] = {"run": run, "kits": _Kits.new(fy + STUB_H)}
		result["walls"].append(run)

	_front_upper = groups["front"]["run"].upper
	for w in grid.walls:
		_wall_segment(w, groups[w["side"]]["kits"], groups[w["side"]]["run"])

	_shopfront(groups["front"]["kits"], groups["front"]["run"])
	_interior_dressing(groups)

	for s in groups:
		var run: WallRun = groups[s]["run"]
		var kits: _Kits = groups[s]["kits"]
		run.upper.position.y = kits.split_y
		_emit_kits(run, kits)
		run.set_cut(false, true)


func _emit_kits(run: WallRun, kits: _Kits) -> void:
	var brick := Materials.named("brick")
	var plaster := Materials.named("plaster")
	var pairs := [
		[kits.stub_brick, run.stub, brick], [kits.stub_plaster, run.stub, plaster], [kits.stub_vc, run.stub, null],
		[kits.up_brick, run.upper, brick], [kits.up_plaster, run.upper, plaster], [kits.up_vc, run.upper, null],
	]
	for p in pairs:
		var k: MeshKit = p[0]
		if k.is_empty():
			continue
		var mesh: ArrayMesh = k.build({C.PAINT: p[2]}) if p[2] else k.build()
		_mi(mesh, "Mesh", p[1])


func _wall_segment(w: Dictionary, kits: _Kits, run: WallRun) -> void:
	var a: Vector2i = w["a"]
	var b: Vector2i = w["b"]
	var horizontal := a.y == b.y
	var side: String = w["side"]
	var kind: String = w["kind"]
	var fy := Lot.FLOOR_Y
	var top := fy + (Lot.PARTITION_H if side == "partition" else Lot.WALL_H)
	var t := Lot.EXT_T
	var from := Lot.m(mini(a.x, b.x) if horizontal else mini(a.y, b.y))
	var to := Lot.m(maxi(a.x, b.x) if horizontal else maxi(a.y, b.y))
	var line := Lot.m(a.y if horizontal else a.x)
	var n: Vector3 = run.outward

	# Side walls wrap the building corners.
	if not horizontal and kind != "door":
		if from <= Lot.m(Lot.BACK_Z) + 0.001:
			from -= t
		if to >= Lot.m(Lot.FRONT_Z) - 0.001:
			to += t

	var box_at := func(off0: float, off1: float, y0: float, y1: float) -> Array:
		var along_c := (from + to) * 0.5
		var along_len := to - from
		var nc: float = line + (off0 + off1) * 0.5 * (n.x + n.z)
		var nlen := absf(off1 - off0)
		if horizontal:
			return [Vector3(along_c, (y0 + y1) * 0.5, nc), Vector3(along_len, y1 - y0, nlen)]
		return [Vector3(nc, (y0 + y1) * 0.5, along_c), Vector3(nlen, y1 - y0, along_len)]

	match kind:
		"exterior":
			var br: Array = box_at.call(0.03, t, 0.0, top)
			kits.box("brick", br[0], br[1])
			var pl: Array = box_at.call(0.0, 0.03, fy, top)
			kits.box("plaster", pl[0], pl[1])
			var cap: Array = box_at.call(-0.02, t + 0.03, top, top + 0.07)
			kits.box("vc", cap[0], cap[1], Palette.TRIM, C.SATIN, 0.015)
			# Plinth course of darker brick at the base, outside.
			var pc: Array = box_at.call(t, t + 0.025, 0.0, 0.32)
			kits.box("vc", pc[0], pc[1], Palette.shade(Palette.BRICK_DARK, -0.15), C.PAINT, 0.008)
		"partition":
			var pl: Array = box_at.call(-0.07, 0.07, fy, top)
			kits.box("plaster", pl[0], pl[1])
			var cap: Array = box_at.call(-0.08, 0.08, top, top + 0.05)
			kits.box("vc", cap[0], cap[1], Palette.TRIM, C.SATIN, 0.012)
		"window":
			_window_run(kits, box_at, from, to, line, n, top)
		"door":
			match w.get("door", ""):
				"entrance":
					_entrance(kits, box_at, from, to, line, top)
				"loading":
					_loading_door(kits, box_at, from, to, line, top)
				"staff":
					_staff_door(kits, box_at, from, to, line, top)


func _window_run(kits: _Kits, box_at: Callable, from: float, to: float, line: float, n: Vector3, top: float) -> void:
	var fy := Lot.FLOOR_Y
	var t := Lot.EXT_T
	var sill_y := fy + 0.5
	var head_y := fy + 2.15
	var frame := Palette.PINE
	# Stall riser below the glass (brick out, plaster in).
	var r: Array = box_at.call(0.03, t, 0.0, sill_y)
	kits.box("brick", r[0], r[1])
	var ri: Array = box_at.call(0.0, 0.03, fy, sill_y)
	kits.box("plaster", ri[0], ri[1])
	var pc: Array = box_at.call(t, t + 0.025, 0.0, 0.32)
	kits.box("vc", pc[0], pc[1], Palette.shade(Palette.BRICK_DARK, -0.15), C.PAINT, 0.008)
	# Sill projecting both sides.
	var s: Array = box_at.call(-0.06, t + 0.07, sill_y, sill_y + 0.05)
	kits.box("vc", s[0], s[1], frame, C.SATIN, 0.012)
	# Wall above the transom.
	var hb: Array = box_at.call(0.03, t, head_y + 0.1, top)
	kits.box("brick", hb[0], hb[1])
	var hp: Array = box_at.call(0.0, 0.03, head_y + 0.1, top)
	kits.box("plaster", hp[0], hp[1])
	var cap: Array = box_at.call(-0.02, t + 0.03, top, top + 0.07)
	kits.box("vc", cap[0], cap[1], Palette.TRIM, C.SATIN, 0.015)
	# Frame: bottom rail, head rail, transom bar.
	for yy in [[sill_y + 0.05, sill_y + 0.1], [head_y, head_y + 0.1], [head_y - 0.42, head_y - 0.37]]:
		var fr: Array = box_at.call(0.06, 0.2, yy[0], yy[1])
		kits.box("vc", fr[0], fr[1], frame, C.SATIN, 0.01)
	# Mullions: evenly spaced, roughly every 1.2 m.
	var span := to - from
	var panes := maxi(1, roundi(span / 1.2))
	for i in panes + 1:
		var along := from + span * float(i) / panes
		var mw := 0.07 if (i == 0 or i == panes) else 0.05
		var c := Vector3(along, (sill_y + head_y) * 0.5 + 0.05, line + 0.13 * n.z) if n.z != 0.0 \
				else Vector3(line + 0.13 * n.x, (sill_y + head_y) * 0.5 + 0.05, along)
		var sz := Vector3(mw, head_y - sill_y, 0.14) if n.z != 0.0 else Vector3(0.14, head_y - sill_y, mw)
		kits.box("vc", c, sz, frame, C.SATIN, 0.008)
	# Glass.
	var gl: Array = box_at.call(0.125, 0.135, sill_y + 0.1, head_y)
	kits.box("vc", gl[0], gl[1], Color(0.74, 0.88, 0.92, 0.2), C.GLASS)


func _entrance(kits: _Kits, box_at: Callable, from: float, to: float, line: float, top: float) -> void:
	var fy := Lot.FLOOR_Y
	var t := Lot.EXT_T
	var head_y := fy + 2.25
	var hb: Array = box_at.call(0.03, t, head_y + 0.12, top)
	kits.box("brick", hb[0], hb[1])
	var hp: Array = box_at.call(0.0, 0.03, head_y + 0.12, top)
	kits.box("plaster", hp[0], hp[1])
	var cap: Array = box_at.call(-0.02, t + 0.03, top, top + 0.07)
	kits.box("vc", cap[0], cap[1], Palette.TRIM, C.SATIN, 0.015)
	# Door head with the motion-sensor pod.
	var hd: Array = box_at.call(-0.08, t + 0.02, head_y, head_y + 0.12)
	kits.box("vc", hd[0], hd[1], Palette.PINE, C.SATIN, 0.012)
	kits.box("vc", Vector3((from + to) * 0.5, head_y - 0.03, line - 0.06), Vector3(0.16, 0.05, 0.06), Palette.INK, C.SATIN, 0.01)
	# Threshold plate and mats (inside: brand green border).
	kits.box("vc", Vector3((from + to) * 0.5, fy + 0.004, line + 0.12), Vector3(to - from, 0.008, 0.3), Palette.STEEL, C.METAL)
	kits.box("vc", Vector3((from + to) * 0.5, fy + 0.008, line - 0.62), Vector3(1.4, 0.012, 0.9), Palette.PINE, C.PAINT, 0.006)
	kits.box("vc", Vector3((from + to) * 0.5, fy + 0.011, line - 0.62), Vector3(1.24, 0.012, 0.74), Palette.shade(Palette.INK, 0.08), C.PAINT, 0.004)

	# Sliding panels as a live node.
	var door := EntranceDoor.new()
	door.name = "EntranceDoor"
	# Lives on the front wall's retracting half so it folds away with it.
	door.position = Vector3((from + to) * 0.5, fy - kits.split_y, line - 0.05)
	_front_upper.add_child(door)
	var pw := (to - from) * 0.5
	var pk := MeshKit.new()
	var fr := Palette.PINE
	var ph := head_y - fy - 0.02
	pk.box(Vector3(0, 0.05, 0), Vector3(pw, 0.1, 0.05), fr, C.SATIN, 0.008)
	pk.box(Vector3(0, ph - 0.03, 0), Vector3(pw, 0.06, 0.05), fr, C.SATIN, 0.008)
	pk.box(Vector3(-pw * 0.5 + 0.025, ph * 0.5, 0), Vector3(0.05, ph, 0.05), fr, C.SATIN, 0.008)
	pk.box(Vector3(pw * 0.5 - 0.025, ph * 0.5, 0), Vector3(0.05, ph, 0.05), fr, C.SATIN, 0.008)
	pk.box(Vector3(0, ph * 0.5, 0), Vector3(pw - 0.06, ph - 0.12, 0.01), Color(0.74, 0.88, 0.92, 0.18), C.GLASS)
	pk.box(Vector3(0, 1.0, 0.03), Vector3(pw - 0.16, 0.035, 0.02), Palette.STEEL, C.METAL, 0.008)
	var pmesh := pk.build()
	door.left_panel = Node3D.new()
	door.right_panel = Node3D.new()
	door.add_child(door.left_panel)
	door.add_child(door.right_panel)
	for pair in [[door.left_panel, -pw * 0.5], [door.right_panel, pw * 0.5]]:
		var m := MeshInstance3D.new()
		m.mesh = pmesh
		m.position.x = pair[1]
		pair[0].add_child(m)
	door.travel = pw - 0.06
	result["entrance"] = door


func _loading_door(kits: _Kits, box_at: Callable, from: float, to: float, line: float, top: float) -> void:
	var fy := Lot.FLOOR_Y
	var t := Lot.EXT_T
	var head_y := fy + 2.2
	var hb: Array = box_at.call(0.03, t, head_y + 0.15, top)
	kits.box("brick", hb[0], hb[1])
	var hp: Array = box_at.call(0.0, 0.03, head_y + 0.15, top)
	kits.box("plaster", hp[0], hp[1])
	var cap: Array = box_at.call(-0.02, t + 0.03, top, top + 0.07)
	kits.box("vc", cap[0], cap[1], Palette.TRIM, C.SATIN, 0.015)
	# Steel jambs and the roll box.
	for z in [from + 0.04, to - 0.04]:
		kits.box("vc", Vector3(line - t * 0.5, fy + 1.1, z), Vector3(t + 0.04, 2.2, 0.08), Palette.STEEL_DARK, C.METAL, 0.01)
	kits.box("vc", Vector3(line - t - 0.08, head_y + 0.08, (from + to) * 0.5), Vector3(0.22, 0.26, to - from + 0.1), Palette.STEEL_DARK, C.METAL, 0.02)
	# Hazard-striped dock edge on the slab.
	for i in 6:
		var z := from + 0.12 + i * (to - from - 0.24) / 5.0
		kits.box("vc", Vector3(line - t * 0.5, fy + 0.004, z), Vector3(t, 0.008, 0.12),
				Palette.MARIGOLD if i % 2 == 0 else Palette.INK, C.PAINT)

	var shutter := LoadingShutter.new()
	shutter.name = "LoadingShutter"
	shutter.position = Vector3(line - t - 0.04, head_y, (from + to) * 0.5)
	root.add_child(shutter)
	var ck := MeshKit.new()
	var slats := 22
	var h := head_y - fy
	for i in slats:
		var y := -h + (i + 0.5) * h / slats
		ck.box(Vector3(0, y, 0), Vector3(0.035, h / slats - 0.008, to - from - 0.14), Palette.shade(Palette.STEEL, -0.05 * (i % 2)), C.METAL, 0.006)
	ck.box(Vector3(0.0, -h + 0.03, 0), Vector3(0.06, 0.06, to - from - 0.12), Palette.MARIGOLD, C.SATIN, 0.01)
	shutter.curtain = _mi(ck.build(), "Curtain", shutter)
	shutter.height = h
	result["shutter"] = shutter


func _staff_door(kits: _Kits, box_at: Callable, from: float, to: float, line: float, top: float) -> void:
	var fy := Lot.FLOOR_Y
	var head_y := fy + 2.15
	var hb: Array = box_at.call(-0.07, 0.07, head_y, top)
	kits.box("plaster", hb[0], hb[1])
	var cap: Array = box_at.call(-0.08, 0.08, top, top + 0.05)
	kits.box("vc", cap[0], cap[1], Palette.TRIM, C.SATIN, 0.012)
	for x in [from + 0.03, to - 0.03]:
		kits.box("vc", Vector3(x, fy + (head_y - fy) * 0.5, line), Vector3(0.06, head_y - fy, 0.18), Palette.PINE, C.SATIN, 0.01)
	kits.box("vc", Vector3((from + to) * 0.5, head_y + 0.03, line), Vector3(to - from + 0.06, 0.06, 0.18), Palette.PINE, C.SATIN, 0.01)
	# PVC strip curtain: slightly overlapping translucent strips.
	var strips := 7
	for i in strips:
		var x := from + 0.08 + i * (to - from - 0.16) / (strips - 1)
		kits.box("vc", Vector3(x, fy + (head_y - fy) * 0.5 + 0.06, line + 0.01 * (i % 2)),
				Vector3(0.13, head_y - fy - 0.12, 0.006), Color(0.8, 0.9, 0.88, 0.32), C.GLASS)


func _shopfront(kits: _Kits, run: WallRun) -> void:
	var fy := Lot.FLOOR_Y
	var x0 := Lot.m(Lot.LEFT_X)
	var x1 := Lot.m(Lot.RIGHT_X)
	var z := Lot.m(Lot.FRONT_Z) + Lot.EXT_T
	var top := fy + Lot.WALL_H
	# Fascia board for the store name.
	var fa_y0 := fy + 2.42
	var fa_y1 := top - 0.08
	kits.box("vc", Vector3((x0 + x1) * 0.5, (fa_y0 + fa_y1) * 0.5, z + 0.04), Vector3(x1 - x0 - 0.3, fa_y1 - fa_y0, 0.08), Palette.PINE, C.SATIN, 0.02)
	kits.box("vc", Vector3((x0 + x1) * 0.5, fa_y1 + 0.01, z + 0.05), Vector3(x1 - x0 - 0.2, 0.04, 0.12), Palette.MARIGOLD, C.SATIN, 0.01)
	kits.box("vc", Vector3((x0 + x1) * 0.5, fa_y0 - 0.01, z + 0.05), Vector3(x1 - x0 - 0.2, 0.04, 0.12), Palette.MARIGOLD, C.SATIN, 0.01)
	# Gooseneck sign lamps.
	for i in 4:
		var lx := x0 + 1.4 + i * (x1 - x0 - 2.8) / 3.0
		kits.box("vc", Vector3(lx, top + 0.02, z + 0.02), Vector3(0.06, 0.04, 0.06), Palette.INK, C.METAL)
		kits.box("vc", Vector3(lx, top + 0.04, z + 0.2), Vector3(0.025, 0.025, 0.36), Palette.INK, C.METAL)
		kits.box("vc", Vector3(lx, top - 0.02, z + 0.38), Vector3(0.12, 0.08, 0.1), Palette.INK, C.METAL, 0.02)

	# Store name, set in the display face.
	var label := Label3D.new()
	label.text = "AISLE & CO."
	label.font = Fonts.display(800, 75)
	label.font_size = 128
	label.pixel_size = 0.0042
	label.modulate = Palette.SNOW
	label.outline_size = 0
	label.position = Vector3((x0 + x1) * 0.5 - 0.6, (fa_y0 + fa_y1) * 0.5 + 0.0, z + 0.085)
	label.double_sided = false
	label.shaded = true
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	run.upper.add_child(label)
	label.position.y -= kits.split_y
	var sub := Label3D.new()
	sub.text = "FINE GROCERS"
	sub.font = Fonts.display(700, 90)
	sub.font_size = 48
	sub.pixel_size = 0.0042
	sub.modulate = Palette.MARIGOLD
	sub.position = Vector3(x1 - 2.1, (fa_y0 + fa_y1) * 0.5 - 0.02, z + 0.085)
	sub.shaded = true
	run.upper.add_child(sub)
	sub.position.y -= kits.split_y
	var est := Label3D.new()
	est.text = "EST. 2026"
	est.font = Fonts.body(700)
	est.font_size = 36
	est.pixel_size = 0.0042
	est.modulate = Palette.MINT
	est.position = Vector3(x0 + 1.5, (fa_y0 + fa_y1) * 0.5 - 0.02, z + 0.085)
	est.shaded = true
	run.upper.add_child(est)
	est.position.y -= kits.split_y

	_awning(kits, x0 + 0.25, x1 - 0.25, z, fy + 2.36)


func _awning(kits: _Kits, x0: float, x1: float, z: float, y_top: float) -> void:
	# A classic striped canvas awning with a scalloped valance.
	var depth := 1.15
	var drop := 0.42
	var stripe := 0.32
	var n := int(ceil((x1 - x0) / stripe))
	var sw := (x1 - x0) / n
	var k := kits.up_vc
	var y_front := y_top - drop
	var slope_n := Vector3(0, depth, drop).normalized()
	for i in n:
		var a := x0 + i * sw
		var b := a + sw
		var col := Palette.GROCER if i % 2 == 0 else Palette.SNOW
		k.poly(PackedVector3Array([Vector3(a, y_top, z), Vector3(b, y_top, z), Vector3(b, y_front, z + depth), Vector3(a, y_front, z + depth)]),
				slope_n, col, C.SATIN, true)
		# Valance with a scalloped lower edge.
		var vh := 0.17
		var pts := PackedVector3Array([Vector3(a, y_front, z + depth), Vector3(b, y_front, z + depth)])
		var scallop := 6
		for s in range(scallop, -1, -1):
			var tt := float(s) / scallop
			var x := lerpf(a, b, tt)
			var dip := sin(tt * PI) * 0.06
			pts.append(Vector3(x, y_front - vh - dip, z + depth))
		k.poly(pts, Vector3(0, 0, 1), col, C.SATIN, true)
	# Side cheeks.
	for x in [x0, x1]:
		k.poly(PackedVector3Array([Vector3(x, y_top, z), Vector3(x, y_front, z + depth), Vector3(x, y_front - 0.17, z + depth)]),
				Vector3(1, 0, 0), Palette.GROCER, C.SATIN, true)
	# Support arms.
	for x in [x0 + 0.2, (x0 + x1) * 0.5, x1 - 0.2]:
		k.rod(Vector3(x, y_top - 0.55, z), Vector3(x, y_front + 0.02, z + depth - 0.05), 0.012, Palette.INK, C.METAL, 6)
	k.rod(Vector3(x0, y_front, z + depth), Vector3(x1, y_front, z + depth), 0.015, Palette.INK, C.METAL, 8)


func _interior_dressing(groups: Dictionary) -> void:
	var fy := Lot.FLOOR_Y
	var back: _Kits = groups["back"]["kits"]
	var part: _Kits = groups["partition"]["kits"]
	var x0 := Lot.m(Lot.LEFT_X)
	var x1 := Lot.m(Lot.RIGHT_X)
	# Stockroom: caged bulkhead lamps on the back wall.
	for x in [x0 + 3.0, x0 + 7.0, x0 + 10.5]:
		var p := Vector3(x, fy + 2.35, Lot.m(Lot.BACK_Z) + 0.06)
		back.box("vc", p, Vector3(0.22, 0.14, 0.08), Palette.INK, C.SATIN, 0.03)
		back.box("vc", p + Vector3(0, 0, 0.03), Vector3(0.16, 0.08, 0.04), Palette.LAMP_WARM, C.EMIT, 0.02)
		_light(p + Vector3(0, -0.1, 0.5), Palette.LAMP_WARM, 0.9, 4.5, groups["back"]["run"])
	# Shop side of the partition: a long brand stripe and a wall clock.
	var pz := Lot.m(Lot.PARTITION_Z) + 0.072
	part.box("vc", Vector3((x0 + x1) * 0.5 + 1.0, fy + 2.3, pz), Vector3(x1 - x0 - 2.2, 0.1, 0.012), Palette.MARIGOLD, C.SATIN)
	var clock := Vector3(x0 + 7.5, fy + 2.0, pz + 0.02)
	var ck := part.up_vc
	ck.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), clock))
	ck.cylinder(Vector3.ZERO, 0.17, 0.04, Palette.INK, C.SATIN, 24, 0.01)
	ck.cylinder(Vector3(0, 0.041, 0), 0.145, 0.004, Palette.SNOW, C.SATIN, 24)
	ck.pop()
	part.box("vc", clock + Vector3(0, 0.04, 0.05), Vector3(0.012, 0.09, 0.004), Palette.INK, C.PAINT)
	part.box("vc", clock + Vector3(0.035, 0, 0.05), Vector3(0.08, 0.01, 0.004), Palette.INK, C.PAINT)
	# Hand-painted wall lettering.
	var paint := Label3D.new()
	paint.text = "FRESH  ·  LOCAL  ·  NEIGHBOURLY"
	paint.font = Fonts.display(800, 70)
	paint.font_size = 150
	paint.pixel_size = 0.001
	paint.modulate = Palette.PINE
	paint.shaded = true
	paint.position = Vector3(x0 + 9.4, fy + 2.05 - part.split_y, pz + 0.004)
	groups["partition"]["run"].upper.add_child(paint)

	# Hanging OPEN / CLOSED sign in the shop window, facing the street.
	var front_up: Node3D = groups["front"]["run"].upper
	var sx := Lot.m(Lot.ENTRANCE.x) - 1.1
	var sz := Lot.m(Lot.FRONT_Z) + 0.06
	var sy := fy + 1.75
	var sk := MeshKit.new()
	sk.rod(Vector3(sx - 0.18, sy + 0.12, sz), Vector3(sx, sy + 0.32, sz), 0.004, Palette.STEEL_DARK, C.METAL, 4)
	sk.rod(Vector3(sx + 0.18, sy + 0.12, sz), Vector3(sx, sy + 0.32, sz), 0.004, Palette.STEEL_DARK, C.METAL, 4)
	sk.box(Vector3(sx, sy, sz), Vector3(0.5, 0.24, 0.02), Palette.INK, C.SATIN, 0.02, 2)
	sk.box(Vector3(sx, sy, sz), Vector3(0.46, 0.2, 0.024), Palette.shade(Palette.INK, 0.06), C.SATIN, 0.01)
	var sm := MeshInstance3D.new()
	sm.mesh = sk.build()
	sm.position.y = -kits_split(groups)
	front_up.add_child(sm)
	var sign_labels: Array[Label3D] = []
	for side in [1.0, -1.0]:
		var l := Label3D.new()
		l.font = Fonts.display(800, 80)
		l.font_size = 120
		l.pixel_size = 0.001
		l.shaded = false
		l.position = Vector3(sx, sy - kits_split(groups), sz + side * 0.0135)
		if side < 0.0:
			l.rotation.y = PI
		front_up.add_child(l)
		sign_labels.append(l)
	result["open_sign"] = sign_labels

	# Implied ceiling lights over the shop floor (no visible ceiling in
	# cutaway, as in a dolls' house).
	for x in [x0 + 2.5, x0 + 6.0, x0 + 9.5]:
		for zz in [Lot.m(Lot.PARTITION_Z) + 1.8, Lot.m(Lot.FRONT_Z) - 1.6]:
			_light(Vector3(x, fy + 3.0, zz), Palette.LAMP_WARM, 0.55, 5.5, root, false, true)


func kits_split(groups: Dictionary) -> float:
	return (groups["front"]["kits"] as _Kits).split_y


func _light(pos: Vector3, color: Color, energy: float, rng: float, parent: Node3D, night_only: bool = false,
		interior: bool = true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	if parent is WallRun:
		parent = (parent as WallRun).stub
	parent.add_child(l)
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	l.light_specular = 0.4
	if night_only:
		result["night_lights"].append(l)
	elif interior:
		result["interior_lights"].append(l)
	return l


# --- Street furniture ------------------------------------------------------

func _props() -> void:
	var k := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var fy := Lot.FLOOR_Y
	var curb_z := Lot.m(Lot.SIDEWALK.end.y) - 0.45

	# Street lamps.
	for x in [Lot.m(14), Lot.m(46)]:
		_street_lamp(lamp_kit, Vector3(x, fy, curb_z))
	# Bench facing the road, bike rack by the entrance, a hydrant.
	_bench(k, Vector3(Lot.m(39), fy, curb_z - 0.2))
	_bike_rack(k, Vector3(Lot.m(31), fy, curb_z - 0.15))
	_hydrant(k, Vector3(Lot.m(21), fy, curb_z))
	# Planter boxes under the windows.
	for x in [Lot.m(10.5), Lot.m(15.5), Lot.m(20.0)]:
		_planter(k, Vector3(x, fy, Lot.m(Lot.FRONT_Z) + Lot.EXT_T + 0.2), rng)
	# Back lot: dumpster by the loading door, a pallet.
	_dumpster(k, Vector3(Lot.m(2.5), 0.03, Lot.m(1.4)))
	_pallet(k, Vector3(Lot.m(5.6), 0.03, Lot.m(1.6)))
	# Trees on the empty lot and behind the store.
	for p in [Vector3(Lot.m(50), 0.02, Lot.m(5)), Vector3(Lot.m(42), 0.02, Lot.m(2.5)),
			Vector3(Lot.m(53), 0.02, Lot.m(16)), Vector3(Lot.m(36), 0.02, Lot.m(14))]:
		_tree(k, p, rng)
	# A low picket fence around the empty lot.
	_fence(k, Vector3(Lot.m(Lot.EXPANSION.position.x) + 0.1, 0.02, Lot.m(Lot.EXPANSION.end.y) - 0.15),
			Vector3(Lot.m(Lot.W) - 0.1, 0.02, Lot.m(Lot.EXPANSION.end.y) - 0.15))
	_fence(k, Vector3(Lot.m(Lot.EXPANSION.position.x) + 0.1, 0.02, 0.15),
			Vector3(Lot.m(Lot.EXPANSION.position.x) + 0.1, 0.02, Lot.m(Lot.EXPANSION.end.y) - 0.15))
	_sale_sign(k, Vector3(Lot.m(44), 0.02, Lot.m(19.5)))
	_mi(k.build(), "StreetFurniture")
	var occ := Node3D.new()
	occ.name = "StreetOccluders"
	root.add_child(occ)
	_mi(lamp_kit.build(), "StreetLamps", occ)
	_mi(night_kit.build({C.EMIT: Materials.named("emit_night")}), "StreetLampGlow", occ, false)
	result["street_occluders"] = occ

	# Grid: mark street furniture so nobody walks through it.
	var row := Lot.SIDEWALK.end.y - 1
	var blocked: Array[Vector2i] = [Vector2i(14, row), Vector2i(46, row), Vector2i(21, row)]
	for x in range(36, 42):
		blocked.append(Vector2i(x, row))
	for x in range(29, 33):
		blocked.append(Vector2i(x, row))
	for x in range(8, 22):
		blocked.append(Vector2i(x, Lot.FRONT_Z + 1))
	# Through occupy() so the navigation graph is relinked around them.
	var valid: Array[Vector2i] = []
	for c in blocked:
		if grid.in_bounds(c) and grid.is_free(c):
			valid.append(c)
	grid.occupy(valid, Lot.STATIC_UID)


func _street_lamp(k: MeshKit, base: Vector3) -> void:
	var pole := Palette.PINE
	k.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.12, 0), Vector2(0.12, 0.12), Vector2(0.08, 0.2),
			Vector2(0.05, 0.24), Vector2(0, 0.24)]), pole, C.SATIN, 14, base)
	k.rod(base + Vector3(0, 0.2, 0), base + Vector3(0, 3.6, 0), 0.04, pole, C.SATIN, 10)
	k.rod(base + Vector3(0, 3.4, 0), base + Vector3(0, 3.55, 0.45), 0.02, pole, C.SATIN, 8)
	var head := base + Vector3(0, 3.5, 0.5)
	k.lathe(PackedVector2Array([Vector2(0.0, 0.18), Vector2(0.2, 0.06), Vector2(0.22, 0.0), Vector2(0.0, 0.0)]),
			pole, C.SATIN, 16, head)
	night_kit.cylinder(head + Vector3(0, -0.06, 0), 0.13, 0.06, Palette.LAMP_WARM, C.EMIT, 14)
	_light(head + Vector3(0, -0.3, 0), Palette.LAMP_WARM, 2.2, 7.0, root, true)


func _bench(k: MeshKit, at: Vector3) -> void:
	for sx in [-0.7, 0.7]:
		k.box(at + Vector3(sx, 0.22, 0), Vector3(0.06, 0.44, 0.42), Palette.INK, C.METAL, 0.01)
	for i in 3:
		k.box(at + Vector3(0, 0.45, -0.14 + i * 0.14), Vector3(1.7, 0.035, 0.11), Palette.WOOD, C.WOOD, 0.01)
	for i in 2:
		k.box(at + Vector3(0, 0.62 + i * 0.13, -0.23), Vector3(1.7, 0.1, 0.03), Palette.WOOD, C.WOOD, 0.01)


func _bike_rack(k: MeshKit, at: Vector3) -> void:
	for i in 3:
		var x := at.x - 0.5 + i * 0.5
		var pts: Array[Vector3] = []
		for s in 9:
			var a := PI * float(s) / 8.0
			pts.append(Vector3(x + cos(a) * 0.18, at.y + 0.45 + sin(a) * 0.25 * (1.0 if s > 0 and s < 8 else 0.0), at.z))
		k.rod(Vector3(x - 0.18, at.y, at.z), Vector3(x - 0.18, at.y + 0.45, at.z), 0.02, Palette.STEEL_DARK, C.METAL, 8)
		k.rod(Vector3(x + 0.18, at.y, at.z), Vector3(x + 0.18, at.y + 0.45, at.z), 0.02, Palette.STEEL_DARK, C.METAL, 8)
		for s in 8:
			k.rod(pts[s], pts[s + 1], 0.02, Palette.STEEL_DARK, C.METAL, 8)


func _hydrant(k: MeshKit, at: Vector3) -> void:
	var red := Palette.TOMATO
	k.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.14, 0), Vector2(0.14, 0.05), Vector2(0.1, 0.07),
			Vector2(0.1, 0.5), Vector2(0.13, 0.52), Vector2(0.13, 0.56), Vector2(0.09, 0.6),
			Vector2(0.05, 0.68), Vector2(0.03, 0.72), Vector2(0, 0.72)]), red, C.GLOSS, 16, at)
	for sx in [-1.0, 1.0]:
		k.rod(at + Vector3(0, 0.38, 0), at + Vector3(sx * 0.17, 0.38, 0), 0.045, red, C.GLOSS, 10)
	k.rod(at + Vector3(0, 0.36, 0), at + Vector3(0, 0.36, 0.16), 0.055, Palette.shade(red, -0.15), C.GLOSS, 10)


func _planter(k: MeshKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	k.box(at + Vector3(0, 0.2, 0), Vector3(1.6, 0.4, 0.34), Palette.WOOD_DARK, C.WOOD, 0.015)
	k.box(at + Vector3(0, 0.41, 0), Vector3(1.66, 0.03, 0.38), Palette.PINE, C.SATIN, 0.01)
	k.box(at + Vector3(0, 0.39, 0), Vector3(1.5, 0.02, 0.26), Palette.SOIL, C.PAINT)
	for i in 14:
		var p := at + Vector3(rng.randf_range(-0.7, 0.7), 0.42, rng.randf_range(-0.09, 0.09))
		var h := rng.randf_range(0.12, 0.26)
		k.rod(p, p + Vector3(rng.randf_range(-0.04, 0.04), h, 0), 0.006, Palette.LEAF, C.PAINT, 4)
		k.sphere(p + Vector3(0, h * 0.55, 0), rng.randf_range(0.06, 0.09), Palette.jitter(Palette.LEAF, rng, 0.06), C.PAINT, 4, 7, 0.8)
		var bloom: Color = [Palette.TOMATO, Palette.MARIGOLD, Palette.SNOW, Color("d98aa0")][i % 4]
		k.sphere(p + Vector3(0, h, 0), 0.035, bloom, C.SATIN, 4, 7)


func _dumpster(k: MeshKit, at: Vector3) -> void:
	var g := Palette.GROCER
	k.box(at + Vector3(0, 0.6, 0), Vector3(1.6, 1.0, 0.9), Palette.shade(g, -0.25), C.SATIN, 0.03, 2)
	k.box(at + Vector3(0, 1.13, -0.02), Vector3(1.66, 0.06, 0.98), Palette.INK, C.SATIN, 0.02)
	for sx in [-0.65, 0.65]:
		for sz in [-0.35, 0.35]:
			k.cylinder(at + Vector3(sx, 0.0, sz), 0.07, 0.1, Palette.RUBBER, C.PAINT, 10)


func _pallet(k: MeshKit, at: Vector3) -> void:
	for i in 5:
		k.box(at + Vector3(-0.5 + i * 0.25, 0.13, 0), Vector3(0.14, 0.025, 1.0), Palette.WOOD, C.WOOD, 0.004)
	for sx in [-0.5, 0.0, 0.5]:
		k.box(at + Vector3(sx, 0.06, 0), Vector3(0.1, 0.1, 1.0), Palette.WOOD_DARK, C.WOOD, 0.004)
	k.box(at + Vector3(0.05, 0.31, 0.1), Vector3(0.45, 0.34, 0.4), Palette.CARDBOARD, C.PAINT, 0.01)
	k.box(at + Vector3(-0.3, 0.27, -0.2), Vector3(0.38, 0.26, 0.36), Palette.CARDBOARD_DARK, C.PAINT, 0.01)


func _tree(k: MeshKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(2.6, 3.4)
	var bark := Color("6d5040")
	k.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.16, 0), Vector2(0.11, 0.3), Vector2(0.09, h * 0.7), Vector2(0, h * 0.7)]),
			bark, C.PAINT, 9, at)
	var greens := [Palette.LEAF, Palette.GRASS_DARK, Palette.shade(Palette.LEAF, -0.12), Palette.GRASS]
	for i in 6:
		var off := Vector3(rng.randf_range(-0.5, 0.5), h * 0.68 + rng.randf_range(0.0, 0.9), rng.randf_range(-0.5, 0.5))
		var r := rng.randf_range(0.55, 0.85)
		k.sphere(at + off, r, Palette.jitter(greens[i % greens.size()], rng, 0.03), C.PAINT, 5, 8, 0.85)
	# Small soil ring around the trunk.
	k.cylinder(at + Vector3(0, -0.01, 0), 0.5, 0.025, Palette.shade(Palette.SOIL, 0.1), C.PAINT, 14)


func _fence(k: MeshKit, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := d.length()
	var dir := d / length
	var n := int(length / 0.22)
	for i in n + 1:
		var p := a + dir * (i * length / n)
		k.box(p + Vector3(0, 0.3, 0), Vector3(0.07, 0.6, 0.07) if absf(dir.x) > 0.5 else Vector3(0.07, 0.6, 0.07),
				Palette.SNOW, C.PAINT, 0.012)
		k.box(p + Vector3(0, 0.62, 0), Vector3(0.05, 0.05, 0.05), Palette.SNOW, C.PAINT, 0.02)
	for y in [0.18, 0.45]:
		var c := (a + b) * 0.5 + Vector3(0, y, 0)
		var s := Vector3(length, 0.05, 0.03) if absf(dir.x) > 0.5 else Vector3(0.03, 0.05, length)
		c += Vector3(0, 0, -0.045) if absf(dir.x) > 0.5 else Vector3(-0.045, 0, 0)
		k.box(c, s, Palette.shade(Palette.SNOW, -0.06), C.PAINT, 0.008)


func _sale_sign(k: MeshKit, at: Vector3) -> void:
	for sx in [-0.55, 0.55]:
		k.box(at + Vector3(sx, 0.55, 0), Vector3(0.07, 1.1, 0.07), Palette.WOOD_DARK, C.WOOD, 0.01)
	k.box(at + Vector3(0, 0.95, 0.04), Vector3(1.4, 0.6, 0.04), Palette.SNOW, C.SATIN, 0.015)
	k.box(at + Vector3(0, 1.17, 0.062), Vector3(1.4, 0.14, 0.005), Palette.TOMATO, C.SATIN)
	var l := Label3D.new()
	l.text = "LOT AVAILABLE"
	l.font = Fonts.display(800, 80)
	l.font_size = 64
	l.pixel_size = 0.003
	l.modulate = Palette.SNOW
	l.position = at + Vector3(0, 1.17, 0.067)
	l.shaded = true
	root.add_child(l)
	var l2 := Label3D.new()
	l2.text = "Room to grow"
	l2.font = Fonts.body(600)
	l2.font_size = 52
	l2.pixel_size = 0.003
	l2.modulate = Palette.PINE
	l2.position = at + Vector3(0, 0.92, 0.064)
	l2.shaded = true
	root.add_child(l2)
