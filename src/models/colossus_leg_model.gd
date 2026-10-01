extends RefCounted
## THE LEG UP CLOSE, WHERE HE CLIMBS (ROADMAP slice 3 step 7b): a patch of a
## walker's leg around the climbing line of one pitch, in real space and honest
## size, in the far body's FOUND plate (colossus_model.gd's ramp). The far body is
## drawn in compressed space and cannot be touched; this is the surface a hand is
## on.
##
## Every point comes from WalkerClimb.surface_at, the one place a pitch's
## geometry is decided, so a bracket is drawn exactly where the climb says the
## body hangs: a rung per hold, a shelf per ledge with a cold strip along its lip
## (lit, not drawn: a ledge is found by its light), and a cable up the line.
##
## THE FRAME is the pitch's bone's own (pose.bones[climb.bone_index(p)]): whoever
## draws it sets the node on that bone and the gait carries it. The climbing line
## is theta 0; the patch runs HALF_W metres of surface either side of it and
## MARGIN metres past each end of the pitch.
##
##   build(def, climb, p) -> MeshKit    the patch for pitch `p` of `climb`'s leg
##   material() -> ShaderMaterial       FOUND as the patch wears it
##   lift(mat, on)                      the near rule on any walker material
##   daylight(mat, dome)                a FOUND walker material's daylight
##   gallery() -> Array                 the thigh pitch, stood up to be looked at

const Model := preload("res://src/models/colossus_model.gd")
const Def := preload("res://src/core/colossus/colossus_def.gd")

const HALF_W := 20.0
const MARGIN := 8.0
## The bare skin under the plates is laid out on a grid this many metres a cell.
const CELL := 2.0
## A plate is this wide round the leg and this tall up it; the seam between two
## side by side shows the dark skin.
const PANEL := Vector2(4.0, 6.0)
const GAP := 0.12
const PROUD := 0.25
## PLATE IS LAPPED, as armour is: each row's lower edge comes LAP down over the
## top of the row below and stands PROUD, and its own top edge is tucked in at
## TUCK under the row above. A flat slab set in a grid of dark gaps is a floor
## of tiles; a lapped course is a hide, and its shadow line says which way is
## down.
const LAP := 0.45
const TUCK := 0.07
## The lower edge and the sides are cut back at 45 degrees this far, so the edge
## that faces the light is a bright line and not a black step.
const CHAMFER := 0.06
## A plate is gone, now and then, off the line he climbs (never within LINE_KEEP
## of it, where the holds are bolted): the skin shows with the ribs it hung on.
const MISSING := 0.05
const LINE_KEEP := 4.0
const RIB := 0.09
## A hold's rung, and a ledge's shelf: half-width across, depth off the plate.
const RUNG := Vector2(0.35, 0.3)
const SHELF := Vector2(1.3, 1.0)
const CABLE_OFF := 1.2
const SALT := 0x1e95
## UP CLOSE THE PLATE IS LIT AS FORM (walker_plate.gdshaderinc, on the patch and
## on the far body by the same rule while a climb is live): its albedo is raised
## x times over nearer the eye than y metres, and not at all past z, and w of
## the way to its own grey as it is; and the open air in front of it lights it
## NEAR_FILL strong from the eye's side. FOUND_MASS keeps a machine a dark mass
## by day, which is right for one seen across a field and, under a hand, left a
## pitch of flat purple slabs at noon with nothing on them to read, and a face
## in the leg's own shade black. Raised and still violet it read as painted
## lilac, not as metal. Past z the walker is the silhouette the ground sees.
const NEAR_LIFT := Vector4(0.65, 14.0, 45.0, 0.35)
const NEAR_FILL := 3.5
## No lift (walker_plate.gdshaderinc).
const NEAR_OFF := Vector4(0.0, 1.0, 2.0, 0.0)


static func build(def: RefCounted, climb: WalkerClimb, p: int) -> MeshKit:
	var top := float(WalkerClimb.PITCHES[p].levels) * WalkerClimb.LEVEL
	return build_span(def, climb, p, -MARGIN, top + MARGIN, HALF_W)


## Only the part of the pitch from `lo` to `hi` metres up it, `half_w` metres of
## surface either side of the line: a closer look, or a cheaper one.
static func build_span(def: RefCounted, climb: WalkerClimb, p: int, lo: float, hi: float, half_w: float) -> MeshKit:
	var k := MeshKit.new()
	k.style = Ink.NONE
	k.style2 = Ink.NONE
	_skin(k, def, climb, p, lo, hi, half_w)
	_plates(k, def, climb, p, lo, hi, half_w)
	_holds(k, def, climb, p, lo, hi)
	return k


## The radius of the pitch's surface at `up` metres, for turning metres of
## surface into an angle round it.
static func _radius(def: RefCounted, climb: WalkerClimb, p: int, up: float) -> float:
	var s := climb.surface_at(def, p, up, 0.0, 0.0)
	return maxf(1.0, Vector2(s.x, s.z).length())


static func _at(def: RefCounted, climb: WalkerClimb, p: int, up: float, across: float, lift: float) -> Vector3:
	return climb.surface_at(def, p, up, across / _radius(def, climb, p, up), lift)


## A quad wound to face `toward`, whichever way its corners came: "up the
## pitch" is +Y on the drum and -Y on a thigh or shin, so the same corner order
## winds the two opposite ways (MeshKit's front is (c - b) x (a - b)).
static func _face(k: MeshKit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, toward: Vector3) -> void:
	if (c - b).cross(a - b).dot(toward) < 0.0:
		k.quad(a, d, c, b, col)
	else:
		k.quad(a, b, c, d, col)


## Out of the leg at `v`, in the bone's frame (its axis is local Y).
static func _out(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()


static func _skin(k: MeshKit, def: RefCounted, climb: WalkerClimb, p: int, lo: float, hi: float, half_w: float) -> void:
	var up := lo
	while up < hi:
		var u1 := minf(hi, up + CELL)
		var s := -half_w
		while s < half_w:
			var s1 := minf(half_w, s + CELL)
			var a := _at(def, climb, p, up, s, 0.0)
			_face(k, a, _at(def, climb, p, up, s1, 0.0), _at(def, climb, p, u1, s1, 0.0), _at(def, climb, p, u1, s, 0.0), Model.DARK, _out(a))
			s = s1
		up = u1


static func _plates(k: MeshKit, def: RefCounted, climb: WalkerClimb, p: int, lo: float, hi: float, half_w: float) -> void:
	# Rows are counted from the full patch's foot, so a closer look lays the
	# same plates where the whole pitch does.
	var row := 0
	var line := -MARGIN
	while line < hi:
		# Each row of plates is laid half a plate over from the one below, as
		# plating is, so the seams never line up into a ladder of their own.
		var s := -HALF_W - (PANEL.x * 0.5 if row % 2 == 1 else 0.0)
		var col := 0
		while s < half_w:
			var pick := Rng.hash01(climb.seed_value, SALT, p, row, col)
			var s0 := maxf(-half_w, s) + GAP * 0.5
			var s1 := minf(half_w, s + PANEL.x) - GAP * 0.5
			var u0 := maxf(lo, line - LAP)
			var u1 := minf(hi, line + PANEL.y)
			if s1 > s0 and u1 > u0:
				if pick < MISSING and minf(absf(s0), absf(s1)) > LINE_KEEP and s0 * s1 > 0.0:
					_ribs(k, def, climb, p, s0, s1, u0, u1)
				else:
					_plate(k, def, climb, p, Rect2(s0, u0, s1 - s0, u1 - u0), line - LAP, pick)
			s += PANEL.x
			col += 1
		line += PANEL.y
		row += 1
	k.wash2 = Color.BLACK
	k.wash_blend = 0.0


## How proud of the skin a plate stands `v` metres up from its lower edge:
## PROUD along that lapping edge, down to TUCK along its top, under the next row.
static func _lift(v: float) -> float:
	return lerpf(PROUD, TUCK, clampf(v / (PANEL.y + LAP), 0.0, 1.0))


## One lapped plate over `r` (x across, y up the pitch, metres of surface), whose
## own lower edge is at `foot` (a plate cut by the patch's end keeps its layout).
## Its face, the chamfer round its lower edge and sides, and its lips down to the
## skin, each carrying the plate's own frame for found.gdshader (`plate_detail`):
## UV2 the metres across and up the plate from its lower corner, CUSTOM0 as
## `_meta` says.
static func _plate(k: MeshKit, def: RefCounted, climb: WalkerClimb, p: int, r: Rect2, foot: float, pick: float) -> void:
	# Plate is BODY or PLATE; RIM is kept for what a hand holds, so the hardware
	# reads apart from the skin it is bolted to.
	var tint: Color = Model.BODY if pick < 0.6 else Model.PLATE
	var corner := Vector2(r.position.x, foot)
	var outer: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	# The face, inset by the chamfer on its lower edge and its sides.
	var inner: Array[Vector2] = [outer[0] + Vector2(CHAMFER, CHAMFER), outer[1] + Vector2(-CHAMFER, CHAMFER),
		outer[2] - Vector2(CHAMFER, 0.0), outer[3] + Vector2(CHAMFER, 0.0)]
	var out := _out(_on(def, climb, p, r.get_center(), 0.0))
	var mid := _on(def, climb, p, r.get_center(), PROUD)
	_meta(k, r.size.x, pick, FACE)
	_plate_quad(k, def, climb, p, inner, [0.0, 0.0, 0.0, 0.0], corner, foot, tint, out)
	# The chamfer, from the face's edge down and out to the plate's outline, on
	# every edge but the top, which is under the row above.
	_meta(k, r.size.x, pick, BEVEL)
	for e: int in [0, 1, 3]:
		var n := (e + 1) % 4
		var q: Array[Vector2] = [outer[e], outer[n], inner[n], inner[e]]
		var edge := (_on(def, climb, p, outer[e], PROUD) + _on(def, climb, p, outer[n], PROUD)) * 0.5
		_plate_quad(k, def, climb, p, q, [-CHAMFER, -CHAMFER, 0.0, 0.0], corner, foot, tint, edge - mid + out * 0.5)
	# Its lips, from the chamfer's foot down to the skin: the lower edge's shadow
	# is the line the courses are read by.
	_meta(k, r.size.x, pick, LIP)
	for e in 4:
		var n := (e + 1) % 4
		var down := 0.0 if e == 2 else -CHAMFER
		var q: Array[Vector2] = [outer[e], outer[n], outer[n], outer[e]]
		var edge := (_on(def, climb, p, outer[e], PROUD) + _on(def, climb, p, outer[n], PROUD)) * 0.5
		_plate_quad(k, def, climb, p, q, [-INF, -INF, down, down], corner, foot, tint.darkened(0.2), edge - mid)


## A point `v` (x across, y up) on pitch `p`, `lift` proud of its skin.
static func _on(def: RefCounted, climb: WalkerClimb, p: int, v: Vector2, lift: float) -> Vector3:
	return _at(def, climb, p, v.y, v.x, lift)


## A quad of a lapped plate whose corners `q` stand `_lift` proud where they are
## on it, plus `drop` (-INF: down on the skin), each carrying where it is on the
## plate (from `corner`) as its UV2.
static func _plate_quad(k: MeshKit, def: RefCounted, climb: WalkerClimb, p: int, q: Array[Vector2], drop: Array,
		corner: Vector2, foot: float, col: Color, toward: Vector3) -> void:
	var v: Array[Vector3] = []
	var uv: Array[Vector2] = []
	for i in 4:
		var d := float(drop[i])
		var lift := 0.0 if is_inf(d) else _lift(q[i].y - foot) + d
		v.append(_on(def, climb, p, q[i], lift))
		uv.append(q[i] - corner)
	var from := k.uv2s.size()
	_face(k, v[0], v[1], v[2], v[3], col, toward)
	# MeshKit lays one UV2 on a whole triangle: each vertex it emitted is given
	# its own corner's.
	for i in range(from, k.uv2s.size()):
		for c in 4:
			if k.verts[i] == v[c]:
				k.uv2s[i] = uv[c]
				break


## Where a plate is gone: the ribs it was fixed to, across the hole, over skin.
static func _ribs(k: MeshKit, def: RefCounted, climb: WalkerClimb, p: int, x0: float, x1: float, y0: float, y1: float) -> void:
	k.wash2 = Color.BLACK
	k.wash_blend = 0.0
	for t: float in [0.3, 0.7]:
		var y := lerpf(y0, y1, t)
		k.strut(_at(def, climb, p, y, x0, RIB), _at(def, climb, p, y, x1, RIB), RIB, 4, Model.DARK)
	var x := (x0 + x1) * 0.5
	k.strut(_at(def, climb, p, y0, x, RIB), _at(def, climb, p, y1, x, RIB), RIB * 0.7, 4, Model.DARK)


## Which part of a plate a face is, for found.gdshader's `plate_detail` (0 is
## none of one: the skin, the hardware).
const FACE := 1.0
const BEVEL := 2.0
const LIP := 3.0


## The plate frame the next faces carry (found.gdshader `plate_detail`): its
## width, how much of its height shows below the row lapped over it (PANEL.y,
## from its own lower corner), its pick, and which part of it they are.
static func _meta(k: MeshKit, w: float, pick: float, part: float) -> void:
	k.wash2 = Color(w, PANEL.y, pick)
	k.wash_blend = part


## The frame at a hold: +X across the leg, +Y up the pitch, +Z out of the plate.
static func hold_frame(def: RefCounted, climb: WalkerClimb, p: int, i: int) -> Transform3D:
	var h := climb.hold_at(p, i)
	var up := h.x * WalkerClimb.LEVEL
	var at := climb.surface_at(def, p, up, h.y, PROUD)
	var ahead := (climb.surface_at(def, p, up + 0.5, h.y, PROUD) - at).normalized()
	var out := climb.surface_at(def, p, up, h.y, PROUD + 1.0) - at
	out = (out - ahead * out.dot(ahead)).normalized()
	var across := ahead.cross(out).normalized()
	return Transform3D(Basis(across, ahead, out), at)


static func _holds(k: MeshKit, def: RefCounted, climb: WalkerClimb, p: int, lo: float, hi: float) -> void:
	var last := Vector3.INF
	for i in climb.holds_in(p):
		var up := climb.hold_at(p, i).x * WalkerClimb.LEVEL
		if up < lo or up > hi:
			continue
		var f := hold_frame(def, climb, p, i)
		k.push(f)
		if climb.is_stance(i):
			k.box(Vector3(-SHELF.x, -0.12, 0.0), Vector3(SHELF.x, 0.0, SHELF.y), Model.RIM)
			# The strip along its lip: the ledge is found by its light.
			k.box(Vector3(-SHELF.x, 0.0, SHELF.y - 0.06), Vector3(SHELF.x, 0.05, SHELF.y), Model.STRIP)
		else:
			k.box(Vector3(-RUNG.x, -0.06, 0.0), Vector3(RUNG.x, 0.06, RUNG.y), Model.RIM)
		k.pop()
		# The cable up the line: hung straight beside it, whatever the holds do.
		var c := _at(def, climb, p, up, CABLE_OFF * 2.0, PROUD + 0.15)
		if last.is_finite():
			k.strut(last, c, 0.04, 4, Model.DARK)
		last = c


## FOUND as the patch wears it, a copy of its own: the patch lays its plates in
## geometry, seams and lips and all, so the world's ruled panels would only cut
## across them, and its wear is each plate's own (found.gdshader
## `plate_detail`), so it walks with the leg.
static func material() -> ShaderMaterial:
	var m := PropModels.found_material().duplicate() as ShaderMaterial
	m.set_shader_parameter("ruled", 0.0)
	m.set_shader_parameter("plate_detail", 1.0)
	lift(m, true)
	return m


## The near rule on walker material `mat` (the patch, the far body, the near
## foot), or off.
static func lift(mat: ShaderMaterial, on: bool) -> void:
	mat.set_shader_parameter("near_lift", NEAR_LIFT if on else NEAR_OFF)
	mat.set_shader_parameter("near_fill", NEAR_FILL if on else 0.0)


## The dome's numbers a FOUND walker material's daylight is read from
## (SkyLight.seen_air's `dome`), and what found.gdshader calls them.
const DAY_FROM := {&"dome_sun_dir": &"near_sun_dir", &"dome_sun_color": &"near_sun_color", &"dome_top_color": &"near_top_color"}


## The far body's daylight on FOUND walker material `mat`, from the sky's `dome`.
static func daylight(mat: ShaderMaterial, dome: Dictionary) -> void:
	for k: StringName in DAY_FROM:
		if dome.has(k):
			mat.set_shader_parameter(DAY_FROM[k], dome[k])


static func gallery() -> Array:
	var def: RefCounted = Def.tripod(&"C")
	var climb := WalkerClimb.begin(0, 1)
	var p := 2
	# The middle ledge of the thigh pitch, and the whole pitch around it.
	var ledge := climb.holds_in(p) / 2
	while not climb.is_stance(ledge):
		ledge += 1
	var at := climb.hold_at(p, ledge).x * WalkerClimb.LEVEL
	return [
		_shown("colossus leg, a ledge on the thigh pitch", build_span(def, climb, p, at - 4.0, at + 4.0, 4.0), hold_frame(def, climb, p, ledge)),
		_shown("colossus leg, the thigh pitch", build(def, climb, p), hold_frame(def, climb, p, ledge)),
	]


## Stood up to be looked at: `frame` made the origin, up the pitch as up and the
## plate facing +Z.
static func _shown(name: String, kit: MeshKit, frame: Transform3D) -> Dictionary:
	var mi := MeshInstance3D.new()
	mi.mesh = kit.build()
	mi.material_override = material()
	mi.transform = frame.affine_inverse()
	var holder := Node3D.new()
	holder.add_child(mi)
	return {"name": name, "node": holder}
