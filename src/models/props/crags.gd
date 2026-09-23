extends RefCounted
## What stands in the Crags that nothing else has (docs/LANDSCAPES.md §1): what
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
