class_name MeshKit
extends RefCounted
## Procedural mesh builder used for every hand-authored asset in the game.
##
## Assets are composed from a handful of well-behaved primitives (bevelled
## boxes, lathed profiles, rods, panels). Each primitive writes vertex colours
## into a "channel" — a material family such as matte paint, satin plastic or
## brushed metal. build() merges everything into one ArrayMesh with one
## surface per channel, so a full shelving unit costs only a few draw calls.
##
## Bevels matter: a 1–2 cm chamfer on every edge catches the key light and is
## the single biggest difference between "miniature diorama" and "grey-box".

enum Ch { PAINT, SATIN, METAL, GLASS, EMIT, WOOD, GLOSS }


class _Buf:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()


var xf := Transform3D.IDENTITY
## When >= 0, every vertex emitted is rigidly bound to this skeleton bone.
var bone := -1
var _skinned := false
var _stack: Array[Transform3D] = []
var _bufs: Dictionary = {}


# --- Transform stack --------------------------------------------------------

func push(t: Transform3D) -> void:
	_stack.push_back(xf)
	xf = xf * t


func push_at(pos: Vector3, yaw_deg: float = 0.0) -> void:
	push(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos))


func pop() -> void:
	xf = _stack.pop_back()


# --- Low level ----------------------------------------------------------------

func _buf(ch: int) -> _Buf:
	if not _bufs.has(ch):
		_bufs[ch] = _Buf.new()
	return _bufs[ch]


func _v(b: _Buf, p: Vector3, n: Vector3, c: Color) -> int:
	b.verts.push_back(xf * p)
	b.norms.push_back((xf.basis * n).normalized())
	b.cols.push_back(c)
	if bone >= 0:
		_skinned = true
	b.bones.append_array([maxi(bone, 0), 0, 0, 0])
	b.weights.append_array([1.0, 0.0, 0.0, 0.0])
	return b.verts.size() - 1


func _tri(b: _Buf, i0: int, i1: int, i2: int) -> void:
	# Godot treats clockwise triangles as front-facing. Rather than reasoning
	# about winding for every primitive, orient each triangle against its
	# intended normal. This also keeps mirrored transforms correct.
	var p0 := b.verts[i0]
	var g := (b.verts[i1] - p0).cross(b.verts[i2] - p0)
	if g.length_squared() < 1e-14:
		return
	var n := b.norms[i0] + b.norms[i1] + b.norms[i2]
	if g.dot(n) > 0.0:
		b.idx.append_array([i0, i2, i1])
	else:
		b.idx.append_array([i0, i1, i2])


func _quad(b: _Buf, i0: int, i1: int, i2: int, i3: int) -> void:
	_tri(b, i0, i1, i2)
	_tri(b, i0, i2, i3)


# --- Primitives -------------------------------------------------------------

func box(center: Vector3, size: Vector3, color: Color, ch: int = Ch.PAINT,
		bevel: float = 0.0, seg: int = 1) -> void:
	var h := size * 0.5
	var b := _buf(ch)
	if bevel <= 0.0005:
		for axis in 3:
			for s in [-1.0, 1.0]:
				var n := Vector3.ZERO
				n[axis] = s
				var u := (axis + 1) % 3
				var v := (axis + 2) % 3
				var ids: Array[int] = []
				for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					var p := Vector3.ZERO
					p[axis] = s * h[axis]
					p[u] = corner.x * h[u]
					p[v] = corner.y * h[v]
					ids.append(_v(b, center + p, n, color))
				_quad(b, ids[0], ids[1], ids[2], ids[3])
		return

	var r := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.98)
	var inner := h - Vector3(r, r, r)
	var lists: Array[PackedFloat32Array] = []
	for axis in 3:
		var l := PackedFloat32Array()
		l.append(-h[axis])
		for k in range(1, seg + 1):
			l.append(-h[axis] + r * float(k) / seg)
		for k in range(seg, 0, -1):
			l.append(h[axis] - r * float(k) / seg)
		l.append(h[axis])
		lists.append(l)

	for axis in 3:
		for s in [-1.0, 1.0]:
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			var lu := lists[u]
			var lv := lists[v]
			var start := b.verts.size()
			for j in lv.size():
				for i in lu.size():
					var p := Vector3.ZERO
					p[axis] = s * h[axis]
					p[u] = lu[i]
					p[v] = lv[j]
					var q := p.clamp(-inner, inner)
					var d := p - q
					var n := Vector3.ZERO
					n[axis] = s
					var pos := p
					if d.length_squared() > 1e-12:
						n = d.normalized()
						pos = q + n * r
					_v(b, center + pos, n, color)
			var w := lu.size()
			for j in lv.size() - 1:
				for i in w - 1:
					var a := start + j * w + i
					_quad(b, a, a + 1, a + w + 1, a + w)


func lathe(profile: PackedVector2Array, colors, ch: int = Ch.PAINT,
		sides: int = 16, center: Vector3 = Vector3.ZERO, smooth_deg: float = 38.0) -> void:
	## Revolves a (radius, height) profile around the local Y axis.
	## `colors` is a single Color or an Array with one Color per segment.
	var b := _buf(ch)
	var nseg := profile.size() - 1
	if nseg < 1:
		return
	var seg_n: Array[Vector2] = []
	for i in nseg:
		var t := profile[i + 1] - profile[i]
		seg_n.append(Vector2(t.y, -t.x).normalized())
	var cos_lim := cos(deg_to_rad(smooth_deg))
	for i in nseg:
		var c: Color = colors[i] if colors is Array else colors
		var n0 := seg_n[i]
		var n1 := seg_n[i]
		if i > 0 and seg_n[i - 1].dot(seg_n[i]) > cos_lim:
			n0 = (seg_n[i - 1] + seg_n[i]).normalized()
		if i < nseg - 1 and seg_n[i + 1].dot(seg_n[i]) > cos_lim:
			n1 = (seg_n[i + 1] + seg_n[i]).normalized()
		var a := profile[i]
		var z := profile[i + 1]
		var start := b.verts.size()
		for k in sides + 1:
			var th := TAU * float(k) / sides
			var cs := cos(th)
			var sn := sin(th)
			_v(b, center + Vector3(a.x * cs, a.y, a.x * sn), Vector3(n0.x * cs, n0.y, n0.x * sn), c)
			_v(b, center + Vector3(z.x * cs, z.y, z.x * sn), Vector3(n1.x * cs, n1.y, n1.x * sn), c)
		for k in sides:
			var i0 := start + k * 2
			_quad(b, i0, i0 + 2, i0 + 3, i0 + 1)


func cylinder(base: Vector3, radius: float, height: float, color: Color,
		ch: int = Ch.PAINT, sides: int = 16, bevel: float = 0.0) -> void:
	var p := PackedVector2Array()
	p.append(Vector2(0, 0))
	if bevel > 0.0:
		p.append(Vector2(radius - bevel, 0))
		p.append(Vector2(radius, bevel))
		p.append(Vector2(radius, height - bevel))
		p.append(Vector2(radius - bevel, height))
	else:
		p.append(Vector2(radius, 0))
		p.append(Vector2(radius, height))
	p.append(Vector2(0, height))
	lathe(p, color, ch, sides, base)


func sphere(center: Vector3, radius: float, color: Color, ch: int = Ch.PAINT,
		rings: int = 8, sides: int = 14, squash: float = 1.0) -> void:
	var p := PackedVector2Array()
	for i in rings + 1:
		var a := PI * float(i) / rings - PI * 0.5
		p.append(Vector2(cos(a) * radius, sin(a) * radius * squash))
	p[0].x = 0.0
	p[rings].x = 0.0
	lathe(p, color, ch, sides, center, 89.0)


func rod(a: Vector3, z: Vector3, radius: float, color: Color, ch: int = Ch.METAL,
		sides: int = 8) -> void:
	## A cylinder between two points (handles, legs, rails, frames).
	var d := z - a
	var length := d.length()
	if length < 1e-5:
		return
	var y := d / length
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var zz := x.cross(y).normalized()
	push(Transform3D(Basis(x, y, zz), a))
	cylinder(Vector3.ZERO, radius, length, color, ch, sides)
	pop()


func capsule(a: Vector3, z: Vector3, radius: float, color: Color, ch: int = Ch.PAINT,
		sides: int = 10) -> void:
	var d := z - a
	var length := d.length()
	var y := d / maxf(length, 1e-5)
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var zz := x.cross(y).normalized()
	var p := PackedVector2Array()
	var rings := 4
	for i in rings + 1:
		var t := -PI * 0.5 + (PI * 0.5) * float(i) / rings
		p.append(Vector2(cos(t) * radius, sin(t) * radius))
	for i in rings + 1:
		var t := (PI * 0.5) * float(i) / rings
		p.append(Vector2(cos(t) * radius, length + sin(t) * radius))
	p[0].x = 0.0
	p[p.size() - 1].x = 0.0
	push(Transform3D(Basis(x, y, zz), a))
	lathe(p, color, ch, sides, Vector3.ZERO, 89.0)
	pop()


func panel(center: Vector3, size: Vector2, normal_axis: Vector3, color: Color,
		ch: int = Ch.PAINT, double_sided: bool = false) -> void:
	## A flat rectangle facing `normal_axis` (one of the six unit axes).
	var b := _buf(ch)
	var n := normal_axis.normalized()
	var u := Vector3.UP if absf(n.y) < 0.9 else Vector3.FORWARD
	var t := u.cross(n).normalized()
	u = n.cross(t).normalized()
	var hx := t * size.x * 0.5
	var hy := u * size.y * 0.5
	var sides_list := [n, -n] if double_sided else [n]
	for nn in sides_list:
		var i0 := _v(b, center - hx - hy, nn, color)
		var i1 := _v(b, center + hx - hy, nn, color)
		var i2 := _v(b, center + hx + hy, nn, color)
		var i3 := _v(b, center - hx + hy, nn, color)
		_quad(b, i0, i1, i2, i3)


func poly(points: PackedVector3Array, normal: Vector3, color: Color, ch: int = Ch.PAINT,
		double_sided: bool = false) -> void:
	## Convex polygon fan (leaves, pennants, sign shapes).
	var b := _buf(ch)
	var sides_list := [normal, -normal] if double_sided else [normal]
	for nn in sides_list:
		var ids: Array[int] = []
		for p in points:
			ids.append(_v(b, p, nn, color))
		for i in range(1, ids.size() - 1):
			_tri(b, ids[0], ids[i], ids[i + 1])


# --- Output ---------------------------------------------------------------

func is_empty() -> bool:
	return _bufs.is_empty()


func build(material_override: Dictionary = {}) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var keys := _bufs.keys()
	keys.sort()
	for ch in keys:
		var b: _Buf = _bufs[ch]
		if b.idx.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = b.verts
		arrays[Mesh.ARRAY_NORMAL] = b.norms
		arrays[Mesh.ARRAY_COLOR] = b.cols
		arrays[Mesh.ARRAY_INDEX] = b.idx
		if _skinned:
			arrays[Mesh.ARRAY_BONES] = b.bones
			arrays[Mesh.ARRAY_WEIGHTS] = b.weights
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat: Material = material_override.get(ch, Materials.for_channel(ch))
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	return mesh
