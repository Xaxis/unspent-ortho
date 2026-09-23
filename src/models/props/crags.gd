extends RefCounted
## What stands in the Crags that nothing else has (docs/LANDSCAPES.md): what
## people cut out of the stone before the machines came, and the two pieces of
## survey furniture the plan left when its instruments returned nothing it could
## file. The stone is the hand's -- a trilithon, a face worn into a boulder, a
## sunken lane between dry-stone banks -- all MADE, and all CUTSTONE (row 91),
## because every one of them was cut by somebody and a cut stone is harder,
## glassier and more relieved under the sun than the turf beside it. The
## survey's is the ruler's: a sighting mast and a rack of cores, FOUND, the only
## exact things in the fog.
##
## Nothing here branches on a landscape by name: the stone is `BiomeDressing`'s,
## so the same lintel stands in another land in that land's rock. A model faces
## +X: a carved face looks along +X, a mast's telescope points along +X.
##
##   tools/shot.sh shots/crags_gallery.png --scene=gallery --filter=crags

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
const Works := preload("res://src/models/props/works.gd")
const Remains := preload("res://src/models/props/remains.gd")

const KINDS: Array[int] = [PropKind.LINTEL, PropKind.CARVED_FACE, PropKind.THEODOLITE_MAST, PropKind.CORE_RACK, PropKind.HOLLOW_WAY]

## The mast's lens, where it is in the model and in what colour: the light and
## the thing casting it come from one place (CLAUDE.md, Props). A small cold
## lens that never finds its target, steady, not on the machines' beat.
const LENS_AT := Vector3(0.362, 2.27, 0.0)


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.LINTEL: lintel(k, v, c)
		PropKind.CARVED_FACE: carved_face(k, v, c)
		PropKind.THEODOLITE_MAST: theodolite_mast(k, v, c)
		PropKind.CORE_RACK: core_rack(k, v, c)
		PropKind.HOLLOW_WAY: hollow_way(k, v, c)


## Stone somebody cut: the CUTSTONE row, tagged at the point it is built into
## `k.made` and never on the dressing's own colour (which may reach FOUND).
static func _cut(col: Color) -> Color:
	return GroundColors.made(col, GroundColors.CUTSTONE)


# --- what people cut ---------------------------------------------------------------

## A trilithon: two uprights and a cap stone across them, one upright leaning in
## under the cap's weight so the window under it is a wedge and not a doorway.
## 3.2 wide, 2.4 high. The window is the point: a roof answer (52_hazards ROOFS)
## with daylight through it, and the one built shape here that reads from a
## valley away, because nothing else on the crags has a straight top.
static func lintel(k: Kit, v: int, c: int) -> void:
	var d := BiomeDressing.of(c)
	var s := 9100 + v * 17 + c
	var body := _cut(d.stone[0])
	var shade := _cut(d.stone[1])
	var top := _cut(GroundColors.up(d.stone[0], 0.25))
	# The far upright stands square; the near one leans in.
	k.slab(0.0, -0.1, -1.25, 0.62, 2.1, 0.46, s, body, top, 0.05, 0.12, 0.0)
	k.made.push(Transform3D(Basis(Vector3.RIGHT, -0.16), Vector3(0.0, 0.0, 1.32)))
	k.slab(0.0, -0.1, 0.0, 0.58, 2.06, 0.44, s + 7, shade, top, 0.05, 0.1, 0.0)
	k.made.pop()
	# The cap, sitting on both: a hair off level, because the leaning one has
	# dropped its end.
	k.made.push(Transform3D(Basis(Vector3.RIGHT, 0.015), Vector3(0.0, 1.98, -0.12)))
	k.slab(0.0, 0.0, 0.0, 0.74, 0.42, 3.0, s + 13, body, top, 0.04, 0.0, 0.0)
	k.made.pop()
	# Lichen on the cap's top and down the weather side of the standing upright.
	# A quad's front is (c - b) x (a - b): these are wound so the top ones face
	# UP and the flank one faces +X, or they are absent rather than dark
	# (tests/render/test_found_drawn.gd).
	k.made.quad(Vector3(-0.2, 2.405, -0.9), Vector3(-0.28, 2.405, 0.0), Vector3(0.2, 2.405, 0.1), Vector3(0.24, 2.405, -0.7), P.MOSS[3])
	k.made.quad(Vector3(0.1, 2.405, 0.5), Vector3(0.0, 2.405, 1.1), Vector3(0.26, 2.405, 1.2), Vector3(0.3, 2.405, 0.6), P.MOSS[2])
	k.made.quad(Vector3(0.315, 0.6, -1.1), Vector3(0.315, 0.6, -1.4), Vector3(0.315, 1.2, -1.42), Vector3(0.315, 1.3, -1.14), P.MOSS[4])
	# A chip off the cap lying at the foot, and a spill of small stone.
	k.stone(0.5, -0.04, -0.85, 0.17, 0.14, s + 21, d.stone[1], 5, 0.1)
	k.stone(-0.42, -0.04, 1.0, 0.12, 0.1, s + 22, d.stone[1], 5)


## A boulder with a worn human face cut into its +X side, half-lidded with
## lichen. 1.2 across. The mass is built on one profile with ONE facet held
## square to +X, so the face has a plane to be cut into: `Kit.stone` wobbles
## every corner, and a face put on that either floats off the rock or sinks
## into it. The features stand proud of the facet by a few hundredths, which at
## 72 px a unit is a real edge for the sun to catch.
static func carved_face(k: Kit, v: int, c: int) -> void:
	var d := BiomeDressing.of(c)
	var s := 9200 + v * 23 + c
	var body := _cut(d.stone[0])
	var light := _cut(GroundColors.up(d.stone[0], 0.2))
	var dark := _cut(GroundColors.down(d.stone[1], 0.5))
	const N := 7
	var phase := -PI / N
	var prof: Array[Vector2] = [Vector2(0.56, -0.06), Vector2(0.64, 0.3), Vector2(0.6, 0.72), Vector2(0.44, 1.02), Vector2(0.2, 1.2)]
	var rings: Array[PackedVector3Array] = []
	for ri in prof.size():
		var ring := PackedVector3Array()
		# Each band sits a little off the last, in z only: the facet the face is
		# cut on stays a plane, the mass stops being a lathe.
		var dz := Kit.j(s, ri, 0.05)
		for i in N:
			var a := phase + float(i) / N * TAU
			ring.append(Vector3(cos(a) * prof[ri].x, prof[ri].y, sin(a) * prof[ri].x + dz))
		rings.append(ring)
	var start := k.made.vertex_count()
	for ri in rings.size() - 1:
		var band := Kit.tone(body, 0.94 + 0.03 * ri)
		for i in N:
			var m := (i + 1) % N
			k.made.quad(rings[ri][m], rings[ri][i], rings[ri + 1][i], rings[ri + 1][m], band)
	var crown := rings[rings.size() - 1]
	var apex := Vector3(0.0, 1.24, Kit.j(s, 9, 0.04))
	for i in N:
		k.made.tri(apex, crown[(i + 1) % N], crown[i], light)
	# The mass rounds; the face's own facet keeps its edges where the wobble
	# would have turned hard, which is what a boulder does.
	k.made.smooth_range(start, k.made.vertex_count())
	# The face. `ap` is the front facet's plane at a height.
	var brow := _apothem(prof, 0.84, N) + 0.03
	k.slab(brow, 0.8, 0.0, 0.08, 0.07, 0.46, s + 1, light, light, 0.01, 0.0, 0.0)
	var eye := _apothem(prof, 0.68, N)
	for sz: float in [-1.0, 1.0]:
		var z0 := sz * 0.06
		var z1 := sz * 0.22
		var lo := minf(z0, z1)
		var hi := maxf(z0, z1)
		k.face(Vector3(eye + 0.008, 0.6, hi), Vector3(eye + 0.008, 0.6, lo), Vector3(eye + 0.008, 0.74, lo), Vector3(eye + 0.008, 0.74, hi), dark)
		# Half-lidded: lichen grown over the top of each socket.
		k.face(Vector3(eye + 0.016, 0.68, hi + 0.01), Vector3(eye + 0.016, 0.68, lo - 0.01), Vector3(eye + 0.016, 0.76, lo - 0.01), Vector3(eye + 0.016, 0.76, hi + 0.01), P.MOSS[3])
	var nose := _apothem(prof, 0.55, N) + 0.05
	k.slab(nose, 0.4, 0.0, 0.1, 0.36, 0.11, s + 2, light, light, 0.008, 0.45, 0.0)
	var mouth := _apothem(prof, 0.32, N)
	k.face(Vector3(mouth + 0.008, 0.29, 0.14), Vector3(mouth + 0.008, 0.29, -0.14), Vector3(mouth + 0.008, 0.33, -0.12), Vector3(mouth + 0.008, 0.33, 0.12), dark)
	# Lichen on the crown, and a chip that came off the cheek lying at the foot.
	k.made.quad(Vector3(-0.14, 1.245, -0.06), Vector3(-0.1, 1.245, 0.1), Vector3(0.12, 1.245, 0.08), Vector3(0.08, 1.245, -0.12), P.MOSS[2])
	k.stone(0.62, -0.04, 0.34, 0.1, 0.08, s + 3, d.stone[1], 5)


## The distance from the axis to the +X facet of an N-sided mass with the
## profile `prof` at height `y`.
static func _apothem(prof: Array[Vector2], y: float, n: int) -> float:
	var r := prof[0].x
	for i in prof.size() - 1:
		if y >= prof[i].y and y <= prof[i + 1].y:
			r = lerpf(prof[i].x, prof[i + 1].x, (y - prof[i].y) / maxf(1e-5, prof[i + 1].y - prof[i].y))
	return r * cos(PI / n)


## A sunken lane between two dry-stone banks, walled with moss. 4 long along X,
## the banks a little over half a unit high with turf on top: cover between them
## (Cover.PROPS) and nothing to take. The stone is the dressing's walling, cut
## and laid by hand in courses that step in as they rise.
static func hollow_way(k: Kit, v: int, c: int) -> void:
	var d := BiomeDressing.of(c)
	var s := 9500 + v * 31 + c
	var wall: Array[Color] = [_cut(d.walling[0]), _cut(d.walling[1]), _cut(d.walling[2]), _cut(d.walling[3])]
	for sz: float in [-1.0, 1.0]:
		var z0 := sz * 0.95
		var y := -0.08
		for course in 3:
			var n := 6 - course
			var run := 4.0 / n
			var h := 0.2 - course * 0.02
			for i in n:
				# One stone gone from the near bank's middle course: a gap somebody
				# climbed through and nobody put back.
				if sz > 0.0 and course == 1 and i == 2:
					continue
				var x := -2.0 + (i + 0.5) * run + Kit.j(s, course * 10 + i, 0.05)
				var col := wall[(i + course) % 4]
				k.made.push(Transform3D(Basis(Vector3.UP, Kit.j(s, course * 20 + i, 0.07)), Vector3(x, y, z0 + sz * course * 0.05)))
				k.slab(0.0, 0.0, 0.0, run * 0.96, h, 0.42 - course * 0.06, s + course * 30 + i, GroundColors.down(col, 0.15), col, 0.02, 0.05, 0.0)
				k.made.pop()
			y += h * 0.96
		# Sods on top: the land's own turf, untagged on purpose (a GROUND mark on
		# made geometry pulls the land's treatment over it; the dressing's turf is
		# not a ground mark, it is a colour).
		k.slab(0.0, y - 0.02, z0 + sz * 0.1, 3.9, 0.12, 0.36, s + 90 + int(sz), d.turf[0], d.turf[1], 0.05, 0.0, 0.0)
		# Moss on the inner face, where the lane keeps the wet.
		var zi := z0 - sz * 0.215
		for j in 3:
			var x0 := -1.7 + j * 1.3 + Kit.j(s, 50 + j, 0.2)
			var x1 := x0 + 0.7 + Kit.j(s, 60 + j, 0.15)
			var y0 := 0.05 + Kit.j(s, 70 + j, 0.04)
			var y1 := y0 + 0.28
			if sz > 0.0:
				k.face(Vector3(x1, y0, zi), Vector3(x0, y0, zi), Vector3(x0, y1, zi), Vector3(x1, y1, zi), P.MOSS[3] if j != 1 else P.MOSS[2])
			else:
				k.face(Vector3(x0, y0, zi), Vector3(x1, y0, zi), Vector3(x1, y1, zi), Vector3(x0, y1, zi), P.MOSS[3] if j != 1 else P.MOSS[2])
	# A fallen stone in the lane, off the gap.
	k.stone(0.3, -0.04, 0.42, 0.14, 0.1, s + 99, d.walling[1], 5, 0.1)


# --- what the survey left ------------------------------------------------------------

## The plan's sighting mast: a thin tripod with a ruled head and a small cold
## lens at the end of its telescope, pointed along +X at a target it has never
## found. 2.6 high. It hums as an installation (SoundMix: "mast").
static func theodolite_mast(k: Kit, v: int, c: int) -> void:
	var s := 9300 + v * 13 + c
	var hub := Vector3(0.0, 2.0, 0.0)
	var mid: Array[Vector3] = []
	for i in 3:
		var a := float(i) / 3.0 * TAU + PI / 6.0
		var foot := Vector3(cos(a) * 0.48, -0.04, sin(a) * 0.48)
		var head := hub + Vector3(cos(a) * 0.06, -0.06, sin(a) * 0.06)
		k.rod(foot, head, 0.022, 5, P.PLATE[3])
		k.found.prism(foot.x, -0.05, foot.z, 0.05, 0.02, 0.03, 5, P.PLATE[2])
		mid.append(foot.lerp(head, 0.5))
	# The spreader: three braces between the legs at their middles.
	for i in 3:
		k.rod(mid[i], mid[(i + 1) % 3], 0.012, 4, P.PLATE[2])
	# The head plate, the spindle and the housing.
	k.found.prism(0.0, 1.95, 0.0, 0.17, 2.02, 0.17, 8, P.PLATE[3], P.PLATE[4], PI / 8.0)
	k.rod(Vector3(0.0, 2.02, 0.0), Vector3(0.0, 2.15, 0.0), 0.03, 6, P.PLATE[4])
	k.chamfer(0.0, 2.15, 0.0, 0.26, 0.22, 0.18, 0.02, P.PLATE[3], P.PLATE[4])
	# The telescope through it, pointing along +X, and its objective.
	k.rod(Vector3(-0.12, 2.27, 0.0), Vector3(0.36, 2.27, 0.0), 0.04, 8, P.PLATE[2])
	k.found.prism(0.31, 2.27, 0.0, 0.0, 0.0, 0.0, 3, P.PLATE[2])
	k.found.push(Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(0.3, 2.27, 0.0)))
	k.found.prism(0.0, 0.0, 0.0, 0.048, 0.06, 0.048, 8, P.PLATE[4], P.PLATE[4])
	k.found.pop()
	# The lens: a small cold light at the objective's face, steady. The one
	# machine light on the whole landscape, and it lights nothing.
	var l := LENS_AT
	k.found.quad(Vector3(l.x, l.y - 0.034, l.z + 0.034), Vector3(l.x, l.y - 0.034, l.z - 0.034), Vector3(l.x, l.y + 0.034, l.z - 0.034), Vector3(l.x, l.y + 0.034, l.z + 0.034), Works.lit(P.COLD[3], 0.88))
	# The scale plate on the housing's side, and the sight vane on top.
	k.plate(Vector3(-0.1, 2.17, 0.091), Vector3(0.1, 2.17, 0.091), Vector3(0.1, 2.33, 0.091), Vector3(-0.1, 2.33, 0.091), P.PLATE[2], P.PLATE[1], P.PLATE[4])
	k.rod(Vector3(0.0, 2.37, 0.0), Vector3(0.0, 2.6, 0.0), 0.012, 4, P.PLATE[4])
	k.found.quad(Vector3(0.006, 2.5, -0.03), Vector3(0.006, 2.5, 0.03), Vector3(0.006, 2.58, 0.03), Vector3(0.006, 2.58, -0.03), P.PLATE[1])
	var d := BiomeDressing.of(c)
	if d.cold():
		Remains.banks(k, [[0.1, 0.05, 0.2, 0.1]], d.snow[0], s)


## A rack of stone cores pulled from the bores, each labelled, stacked in ruled
## rows. 1.6 by 0.6. The rack is the ruler's; the cores are the land's, drawn
## by hand in the dressing's stone and CUTSTONE, because a core is a cut. A
## few are missing: they were taken to be filed, and the file said nothing.
static func core_rack(k: Kit, v: int, c: int) -> void:
	var d := BiomeDressing.of(c)
	var s := 9400 + v * 19 + c
	const L := 0.8
	const W := 0.3
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.chamfer(sx * L, -0.02, sz * W, 0.06, 1.06, 0.06, 0.012, P.PLATE[3], P.PLATE[4])
	var shelves: Array[float] = [0.3, 0.62, 0.94]
	for y: float in shelves:
		k.chamfer(0.0, y, 0.0, 1.62, 0.03, 0.62, 0.008, P.PLATE[2], P.PLATE[3])
	# The cores: six to a shelf, lying across it, a label on each end.
	var core := _cut(d.stone[0])
	var pale := _cut(GroundColors.up(d.stone[0], 0.3))
	var n := 0
	for si in shelves.size():
		for i in 6:
			var x := -L + 0.16 + i * 0.26
			# Gaps where cores were taken.
			if Rng.hash01(s, si, i) < 0.18:
				continue
			var col := core if (i + si) % 3 != 0 else pale
			k.made.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, shelves[si] + 0.075, -0.26)))
			var start := k.made.vertex_count()
			k.made.prism(0.0, 0.0, 0.0, 0.046, 0.52, 0.046, 6, Kit.tone(col, 0.96 + 0.02 * (i % 3)), col)
			k.made.smooth_range(start, k.made.vertex_count(), 70.0)
			k.made.pop()
			k.found.quad(Vector3(x + 0.03, shelves[si] + 0.05, 0.262), Vector3(x - 0.03, shelves[si] + 0.05, 0.262), Vector3(x - 0.03, shelves[si] + 0.1, 0.262), Vector3(x + 0.03, shelves[si] + 0.1, 0.262), P.LINEN[4])
			n += 1
	# The rack's own number plate on one end frame.
	k.plate(Vector3(L + 0.031, 0.72, 0.12), Vector3(L + 0.031, 0.72, -0.12), Vector3(L + 0.031, 0.86, -0.12), Vector3(L + 0.031, 0.86, 0.12), P.PLATE[2], P.PLATE[1], P.PLATE[4])
	if d.cold():
		Remains.banks(k, [[0.0, 0.0, 0.4, 0.14]], d.snow[0], s)


# --- what the crags' people live in (BiomeForms: roundhouse, lean_to_broch, byre) ---

## The dressing's walling, cut: what every wall here is laid in.
static func _walling(d: BiomeDressing) -> Array[Color]:
	return [_cut(d.walling[0]), _cut(d.walling[1]), _cut(d.walling[2]), _cut(d.walling[3])]


## Sods: the dressing's own turf, UNTAGGED on purpose. A ground mark on made
## geometry pulls the land's treatment over it (CLAUDE.md, tagging); turf as a
## colour is not a mark, and a roof of it takes the default made row.
static func _turf(d: BiomeDressing) -> Array[Color]:
	return [d.turf[0], d.turf[1], d.turf[2], d.turf[3], GroundColors.down(d.turf[0], 0.3), P.EARTH[2]]


## A dry-stone round: courses of hand-laid stones on a circle of radius `r`, `h`
## high, a doorway `door` wide facing +X with a lintel over it and the courses
## carried across above. Joints alternate course to course and the ring steps
## in a hair as it rises, the way a wall that has to carry a roof is battered.
## Returns the top of the wall.
static func _drystone_round(k: Kit, wall: Array[Color], s: int, r: float, h: float, door: float) -> float:
	const CH := 0.24
	var courses := ceili(h / CH)
	var y := -0.06
	var half := door * 0.5 / r
	var lintel_y := h - CH * 1.4
	for course in courses:
		var rr := r - course * 0.015
		var n := maxi(8, roundi(TAU * rr / 0.56))
		var step := TAU / n
		var off := step * 0.5 if course % 2 == 1 else 0.0
		var ch := CH + Kit.j(s, course, 0.02)
		for i in n:
			var a := off + i * step
			if absf(wrapf(a, -PI, PI)) < half + step * 0.5 and y < lintel_y:
				continue
			var col := wall[(i + course) % 4]
			k.made.push(Transform3D(Basis(Vector3.UP, -a - PI * 0.5),
				Vector3(cos(a) * rr + Kit.j(s, course * 40 + i, 0.02), y, sin(a) * rr + Kit.j(s, course * 40 + i + 1, 0.02))))
			k.slab(0.0, 0.0, 0.0, step * rr * 0.95, ch, 0.42, s + course * 50 + i, GroundColors.down(col, 0.15), col, 0.02, 0.05, 0.0)
			k.made.pop()
		y += ch * 0.96
	# The lintel: one long stone across the doorway's head.
	k.slab(r - 0.02, lintel_y - 0.04, 0.0, 0.44, 0.16, door + 0.5, s + 77, wall[1], GroundColors.up(wall[1], 0.2), 0.02, 0.0, 0.0)
	# A floor, dark, so the doorway opens onto a room and not onto the ground
	# behind the house.
	k.made.prism(0.0, -0.02, 0.0, r - 0.12, 0.01, r - 0.12, 12, P.INK[2], GroundColors.down(P.EARTH[1], 0.3))
	return y


## A conical roof over a round: `n` segments in four courses, each course laid
## proud of the one below (the overlap is the whole drawing of a roof, as
## `Houses.patch_slope` says) and its exposed edge dark. Drawn here rather than
## through `patch_slope`, which sizes its courses to the slope's length and
## would spend nine courses of forty cells on a cone this tall. The lowest
## course is sods laid over the thatch's foot; the rest is thatch.
static func _cone_roof(k: Kit, d: BiomeDressing, s: int, apex: Vector3, eave_r: float, eave_y: float, n: int, thatch: Array[Color]) -> void:
	var turf := _turf(d)
	var stations: Array[float] = [0.0, 0.3, 0.56, 0.8, 1.0]
	var rings: Array[PackedVector3Array] = []
	for ri in stations.size():
		var v: float = stations[ri]
		var ring := PackedVector3Array()
		for i in n + 1:
			var a := float(i % n) / n * TAU
			var rr := lerpf(eave_r, 0.07, v) + (Kit.j(s, 200 + (i % n), 0.08) if ri == 0 else Kit.j(s, 210 + ri * 20 + (i % n), 0.03))
			var yy := lerpf(eave_y, apex.y, v) + (Kit.j(s, 230 + (i % n), 0.05) if ri == 0 else 0.0)
			ring.append(Vector3(apex.x * v + cos(a) * rr, yy, apex.z * v + sin(a) * rr))
		rings.append(ring)
	const LAP := 0.035
	for ri in rings.size() - 1:
		var mats := turf if ri == 0 else thatch
		var pick := int(Rng.hash01(s, ri, 71) * mats.size()) % mats.size()
		for i in n:
			var a := rings[ri][i]
			var b := rings[ri][i + 1]
			var c := rings[ri + 1][i + 1]
			var dd := rings[ri + 1][i]
			var p := pick if Rng.hash01(s, ri * 47 + i, 62) > 0.2 else int(Rng.hash01(s, ri * 47 + i, 72) * mats.size()) % mats.size()
			var col := Kit.tone(mats[p], 0.93 + 0.14 * Rng.hash01(s, ri * 29 + i, 73))
			var face_n := (b - a).cross(dd - a)
			var lay := face_n.normalized() * LAP if face_n.length_squared() > 1e-12 else Vector3(0, LAP, 0)
			k.made.quad(b + lay, a + lay, dd + lay, c + lay, col)
			k.made.quad(a, b, b + lay, a + lay, Kit.tone(col, 0.8))
	# The smoke hole at the apex, and the peg through it.
	k.made.prism(apex.x, apex.y - 0.03, apex.z, 0.14, apex.y + 0.02, 0.11, 6, P.INK[1], P.INK[1])
	k.limb(apex + Vector3(0.0, -0.1, 0.0), apex + Vector3(0.03, 0.22, 0.02), 0.03, 0.02, 4, GroundColors.made(d.timber[1], GroundColors.TIMBER), Vector3.ZERO, Kit.SAWN)


## A door of planks hung in a doorway `w` wide in a wall whose face is at `x`,
## standing a little ajar. TIMBER: what the crags' timber weathers to.
static func _plank_door(k: Kit, d: BiomeDressing, x: float, w: float, h: float, s: int) -> void:
	var timber := GroundColors.made(d.timber[0], GroundColors.TIMBER)
	var dark := GroundColors.made(d.timber[1], GroundColors.TIMBER)
	k.made.push(Transform3D(Basis(Vector3.UP, 0.3), Vector3(x, 0.0, -w * 0.5)))
	for i in 3:
		var pw := w / 3.0
		k.slab(0.0, 0.02, pw * (i + 0.5), 0.05, h - 0.04 * (i % 2), pw - 0.02, s + 300 + i, dark if i == 1 else timber, timber, 0.008, 0.0, 0.0)
	k.made.pop()


## Sods banked round the foot of a round wall.
static func _sods_round(k: Kit, d: BiomeDressing, s: int, r: float, n: int) -> void:
	for i in n:
		var a := float(i) / n * TAU + 0.4
		if absf(wrapf(a, -PI, PI)) < 0.45:
			continue
		k.clump(cos(a) * r, -0.05, sin(a) * r, 0.26 + Kit.j(s, 400 + i, 0.06), 0.13, s + 410 + i, d.turf[i % 2 * 2], 6)


## A dry-stone round under a conical turf-and-thatch roof. 3.0 high. The
## oldest shape people build and the one they went back to.
static func roundhouse(k: Kit, c: int) -> void:
	var d := BiomeDressing.of(c)
	var s := 9600 + c
	var wall := _walling(d)
	const R := 1.45
	var top := _drystone_round(k, wall, s, R, 1.3, 0.72)
	_cone_roof(k, d, s, Vector3(0.04, 3.0, -0.03), R + 0.4, top - 0.1, 16, PropModels.Houses.THATCH_ROOF)
	_plank_door(k, d, R - 0.16, 0.72, 0.95, s)
	_sods_round(k, d, s, R + 0.15, 8)
	# A peat stack against the wall and the stone the door is propped with.
	for i in 3:
		k.slab(-R * 0.55 + i * 0.04, i * 0.15, R * 0.78, 0.5, 0.16, 0.34, s + 100 + i, P.EARTH[1], P.EARTH[2], 0.02, 0.0, 0.0)
	k.stone(R + 0.32, -0.04, -0.62, 0.15, 0.12, s + 91, d.stone[1], 5)
	if d.cold():
		for i in 4:
			var a := i * TAU / 4.0 + 0.5
			k.clump(cos(a) * 1.1, 1.9 - i * 0.05, sin(a) * 1.1, 0.42, 0.12, s + 500 + i, d.snow[i % 2], 7)


## A timber lean-to built into a broken tower's wall. 2.8 high. The tower is
## an arc of thick dry stone, tallest at the back and broken down toward the
## gap at the front; the lean-to sits against its +Z flank under sods.
static func lean_to_broch(k: Kit, c: int) -> void:
	var d := BiomeDressing.of(c)
	var s := 9700 + c
	var wall := _walling(d)
	const CX := -0.5
	const R := 1.3
	const CH := 0.26
	const A0 := 0.55
	const N := 10
	var step := (TAU - 2.0 * A0) / N
	for course in 12:
		var y := -0.06 + course * CH * 0.96
		var off := step * (0.5 if course % 2 == 1 else 0.0)
		var rr := R - course * 0.012
		for i in N:
			var a := A0 + off + (i + 0.5) * step
			if a > TAU - A0:
				continue
			# Tallest at the back, falling to the gap, and jagged.
			var back := 1.0 - absf(wrapf(a - PI, -PI, PI)) / PI
			var top := 0.9 + back * 1.8 + Kit.j(s, 300 + i, 0.25)
			if y + CH > top:
				continue
			var col := wall[(i + course) % 4]
			k.made.push(Transform3D(Basis(Vector3.UP, -a - PI * 0.5), Vector3(CX + cos(a) * rr, y, sin(a) * rr)))
			k.slab(0.0, 0.0, 0.0, step * rr * 0.95, CH + Kit.j(s, course * 40 + i, 0.03), 0.5, s + course * 40 + i, GroundColors.down(col, 0.15), col, 0.025, 0.05, 0.0)
			k.made.pop()
	# What fell: rubble at the gap and inside the ring.
	PropModels.Houses._spill(k, Vector2(CX + 1.15, 0.1), Vector2(0.8, 0.5), 7, s + 2, wall)
	PropModels.Houses._spill(k, Vector2(CX - 0.3, -0.3), Vector2(0.6, 0.4), 4, s + 3, wall)
	# The lean-to: two posts and a beam, planks from the wall down to it, sods
	# over the planks, a hide hung across the open end.
	var timber := GroundColors.made(d.timber[0], GroundColors.TIMBER)
	var tdark := GroundColors.made(d.timber[1], GroundColors.TIMBER)
	k.limb(Vector3(0.3, -0.05, 2.5), Vector3(0.28, 1.05, 2.48), 0.07, 0.06, 5, tdark, Vector3.ZERO, Kit.SAWN)
	k.limb(Vector3(-1.3, -0.05, 2.5), Vector3(-1.32, 1.02, 2.5), 0.07, 0.06, 5, tdark, Vector3.ZERO, Kit.SAWN)
	k.limb(Vector3(0.36, 1.05, 2.5), Vector3(-1.38, 1.02, 2.5), 0.06, 0.06, 5, timber, Vector3.ZERO, Kit.SAWN)
	var slope := -atan2(1.72 - 1.08, 2.62 - 1.45)
	for i in 6:
		var x := 0.2 - i * 0.31
		k.made.push(Transform3D(Basis(Vector3.RIGHT, slope), Vector3(x, 1.4 + Kit.j(s, 600 + i, 0.03), 2.03)))
		k.slab(0.0, 0.0, 0.0, 0.29, 0.05, 1.34, s + 610 + i, tdark if i % 3 == 1 else timber, timber, 0.01, 0.0, 0.0)
		if i % 2 == 0:
			k.slab(0.02, 0.05, 0.1 - (i % 4) * 0.15, 0.32, 0.1, 0.5, s + 620 + i, d.turf[i % 4], d.turf[(i + 1) % 4], 0.03, 0.0, 0.0)
		k.made.pop()
	# A hide across the open end, facing +X: HIDE (89), what a door is made of
	# where nobody has planks to spare.
	var hide := GroundColors.made(P.EARTH[3].lerp(P.SAND[3], 0.35), GroundColors.HIDE)
	k.face(Vector3(0.34, 0.0, 2.42), Vector3(0.34, 0.0, 1.55), Vector3(0.33, 1.0, 1.5), Vector3(0.35, 1.06, 2.44), hide)
	_sods_round(k, d, s, R + 0.35, 6)


## A byre: long, low, sunk into the slope. 2.2 high. Dry-stone walls under a
## hipped roof of sods, the earth banked to the eaves along the back and both
## ends, a wide door on the front for what it was built to keep.
static func byre(k: Kit, c: int) -> void:
	var d := BiomeDressing.of(c)
	var s := 9800 + c
	var wall := _walling(d)
	var H := PropModels.Houses
	var t: Array[Vector3] = H.walls(k, 3.6, 2.0, 0.78, s, wall[0], wall[1], Vector3(0.02, 0.0, 0.02))
	for fi in H.faces(t).size():
		var wf: Array = H.faces(t)[fi]
		H.weathered(k, wf[0], wf[1], wf[2], wf[3], s + fi * 13, wall[2], d.growth)
	var fb: Array = H.faces(t)[0]
	H.door(k, fb[0], fb[1], fb[2], fb[3], 0.5, 0.17, 0.72)
	var turf := _turf(d)
	var r: Array[Vector3] = H.hipped(k, t, 0.32, 1.0, 0.64, 0.14, s + 60, turf, 0.0, turf[0], 2, 0.1)
	# Sunk into the slope: earth to the eaves along the back and round both ends.
	for i in 4:
		k.clump(-2.05 + Kit.j(s, 400 + i, 0.15), -0.05, -1.2 + i * 0.8, 0.9, 0.82 + Kit.j(s, 410 + i, 0.1), s + 420 + i, d.turf[(i % 2) * 2], 7)
	k.clump(-0.7, -0.05, -1.85, 0.85, 0.6, s + 430, d.turf[1], 7)
	k.clump(-0.7, -0.05, 1.85, 0.85, 0.6, s + 431, d.turf[3], 7)
	H.turf_bank(k, t, s + 20, c)
	if d.cold():
		H._snow_on(k, r, d.snow)


## Where the shelter's hearth burns, in its own frame: just inside the doorway,
## which faces +X. The light (`glow_points`) and the embers are one place.
const HEARTH_AT := Vector3(0.5, 0.06, 0.0)

## The crags' patched shelter (`BiomeDressing.shelter`): a small dry-stone
## round under sods, a sheet of machine plate weighted onto the roof where the
## turf failed, a plank door, peat stacked by it. Nothing WIRED in -- the one
## landscape with no stolen light keeps that in its shelters too -- but the
## lit one (`lit`, variant 1 as every shelter counts it) has a HEARTH going
## inside the door: a ring of stones and embers, and the warm light of it is
## what a night village here is seen by.
static func roundhouse_shelter(k: Kit, s: int, lit: bool, d: BiomeDressing) -> void:
	var wall := _walling(d)
	const R := 1.0
	var top := _drystone_round(k, wall, s, R, 0.85, 0.6)
	if lit:
		var h := HEARTH_AT
		for i in 5:
			var a := float(i) / 5.0 * TAU + 0.3
			k.stone(h.x + cos(a) * 0.2, 0.0, h.z + sin(a) * 0.2, 0.07, 0.06, s + 800 + i, d.stone[1], 5)
		k.made.prism(h.x, 0.01, h.z, 0.13, 0.06, 0.09, 6, GroundColors.glow(P.EMBER[3], 0.9), GroundColors.glow(P.EMBER[4], 1.1))
	_cone_roof(k, d, s, Vector3(0.03, 1.9, -0.02), R + 0.35, top - 0.08, 12, _turf(d))
	# The plate: laid on the slope over the back, its corners held with stones.
	# A flat sheet on a cone is a CHORD, inside the roof by r(1 - cos(half its
	# span)): at 52 degrees that was a tenth of the radius and the play camera
	# never saw it (tests/render/test_found_drawn.gd). 26 degrees and a lift of
	# 0.09 clear the roof's own jitter on the outer edge and the chord in the middle.
	var a0 := 2.15
	var a1 := 2.6
	var rl := 0.5
	var rh := 1.2
	var yl := lerpf(top - 0.08, 1.9, (R + 0.35 - rl) / (R + 0.35 - 0.07)) + 0.09
	var yh := lerpf(top - 0.08, 1.9, (R + 0.35 - rh) / (R + 0.35 - 0.07)) + 0.09
	# Wound so its front is (c - b) x (a - b) = outward-up. `rl` is the ring
	# nearer the APEX, so c - b runs inward and up: worked out with numbers,
	# because the first two guesses at this order were both wrong.
	k.plate(Vector3(cos(a1) * rh, yh, sin(a1) * rh), Vector3(cos(a0) * rh, yh, sin(a0) * rh),
		Vector3(cos(a0) * rl, yl, sin(a0) * rl), Vector3(cos(a1) * rl, yl, sin(a1) * rl), P.PLATE[2], P.PLATE[1], P.PLATE[4])
	k.stone(cos(a0) * rh * 0.95, yh + 0.02, sin(a0) * rh * 0.95, 0.1, 0.08, s + 700, d.stone[1], 5)
	k.stone(cos(a1) * rh * 0.95, yh + 0.02, sin(a1) * rh * 0.95, 0.09, 0.08, s + 701, d.stone[1], 5)
	_plank_door(k, d, R - 0.15, 0.6, 0.78, s)
	_sods_round(k, d, s, R + 0.12, 6)
	for i in 3:
		k.slab(0.55, i * 0.14, 0.85 + i * 0.02, 0.4, 0.14, 0.3, s + 500 + i, P.EARTH[1], P.EARTH[2], 0.02, 0.0, 0.0)


static func glow_points(kind: int, _v: int) -> Array:
	if kind == PropKind.THEODOLITE_MAST:
		return [{"at": LENS_AT, "size": Vector2.ZERO, "color": Color(P.COLD[3], 1.0), "blink": false}]
	return []


## Every crags kind in the crags' own dressing, named so `--filter=crags` finds
## them all at once (src/gallery.gd folds case and underscores).
static func gallery() -> Array:
	var out: Array = []
	var crags := BiomeRegistry.index_of(&"the_crags")
	for kind: int in KINDS:
		for v in PropModels.variants(kind, crags):
			out.append({"name": "crags %s %d" % [PropKind.NAMES[kind], v], "node": PropModels.node(kind, v, crags)})
	return out
