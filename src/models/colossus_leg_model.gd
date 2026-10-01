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
##   gallery() -> Array                 the thigh pitch, stood up to be looked at

const Model := preload("res://src/models/colossus_model.gd")
const Def := preload("res://src/core/colossus/colossus_def.gd")

const HALF_W := 20.0
const MARGIN := 8.0
## The bare skin under the plates is laid out on a grid this many metres a cell.
const CELL := 2.0
## A plate is this wide round the leg and this tall up it; the gap between two
## shows the dark skin as a seam.
const PANEL := Vector2(4.0, 6.0)
const GAP := 0.3
const PROUD := 0.25
## A hold's rung, and a ledge's shelf: half-width across, depth off the plate.
const RUNG := Vector2(0.35, 0.3)
const SHELF := Vector2(1.3, 1.0)
const CABLE_OFF := 1.2
const SALT := 0x1e95


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
	var up := -MARGIN
	while up < hi:
		var u0 := maxf(lo, up) + GAP * 0.5
		var u1 := minf(hi, up + PANEL.y) - GAP * 0.5
		# Each row of plates is laid half a plate over from the one below, as
		# plating is, so the seams never line up into a ladder of their own.
		var s := -HALF_W - (PANEL.x * 0.5 if row % 2 == 1 else 0.0)
		var col := 0
		while s < half_w:
			var s0 := maxf(-half_w, s) + GAP * 0.5
			var s1 := minf(half_w, s + PANEL.x) - GAP * 0.5
			if s1 > s0 and u1 > u0:
				var pick := Rng.hash01(climb.seed_value, SALT, p, row, col)
				# Plate is BODY or PLATE; RIM is kept for what a hand holds, so the
				# hardware reads apart from the skin it is bolted to.
				var tint: Color = Model.BODY if pick < 0.6 else Model.PLATE
				var a := _at(def, climb, p, u0, s0, PROUD)
				var b := _at(def, climb, p, u0, s1, PROUD)
				var c := _at(def, climb, p, u1, s1, PROUD)
				var d := _at(def, climb, p, u1, s0, PROUD)
				var out := _out(a)
				_face(k, a, b, c, d, tint, out)
				# Its edges, down to the skin: a plate's lip is what catches the
				# light, and the seams read by it rather than by colour alone.
				var a0 := _at(def, climb, p, u0, s0, 0.0)
				var b0 := _at(def, climb, p, u0, s1, 0.0)
				var c0 := _at(def, climb, p, u1, s1, 0.0)
				var d0 := _at(def, climb, p, u1, s0, 0.0)
				var mid := (a + b + c + d) * 0.25
				var lip := tint.darkened(0.2)
				_face(k, a0, b0, b, a, lip, (a + b) * 0.5 - mid)
				_face(k, b0, c0, c, b, lip, (b + c) * 0.5 - mid)
				_face(k, c0, d0, d, c, lip, (c + d) * 0.5 - mid)
				_face(k, d0, a0, a, d, lip, (d + a) * 0.5 - mid)
			s += PANEL.x
			col += 1
		up += PANEL.y
		row += 1


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
	mi.material_override = PropModels.found_material()
	mi.transform = frame.affine_inverse()
	var holder := Node3D.new()
	holder.add_child(mi)
	return {"name": name, "node": holder}
