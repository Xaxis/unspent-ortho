extends RefCounted
## What stands in the Mesas that nothing else has (docs/LANDSCAPES.md): what
## the wind carved out of banded rock, what people cut into it for water, and
## what the plan strung across the canyons. The land's is MADE and banded — a
## hoodoo with a harder cap stone balanced on it, a thin natural arch — laid in
## the dressing's own stone course by course, because strata are the point of
## the place and a stratum is a colour step in a rock that is otherwise one
## thing. The people's is MADE and CUTSTONE (row 91): a cistern cut at the foot
## of a wall. The plan's is FOUND: the ropeway's pylon, and one of its spans
## come down on the scree.
##
## THE ROCK IS UNTAGGED ON PURPOSE. A hoodoo and an arch are the land, not
## anything somebody cut, so they take the default made row the way a boulder
## does; tagging them CUTSTONE would give the wind's work a mason's relief, and
## a GROUND mark would pull the landscape's own ground treatment over a spire
## (CLAUDE.md, the tagging trap).
##
## Nothing here branches on a landscape by name: the stone is `BiomeDressing`'s,
## so a hoodoo dealt somewhere else stands in that land's rock. A model faces
## +X. The arch spans along X; the fallen span runs down +X from the pylon leg
## at its origin (the one circle a prop gets stops a body at the leg, and the
## cable lying on the ground six units off is walked over).
##
##   tools/shot.sh shots/mesas_gallery.png --scene=gallery --filter=mesas

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")

const KINDS: Array[int] = [PropKind.HOODOO, PropKind.ARCH_RIB, PropKind.FALLEN_SPAN, PropKind.CISTERN, PropKind.SPAN_PYLON]

## The arch's reach and rise (docs/LANDSCAPES.md: 4 x 3, walkable under).
const ARCH_HALF := 2.0
const ARCH_RISE := 2.6
## The pylon's head (docs/LANDSCAPES.md: 5 high).
const PYLON_HEAD := 4.7
## How far the fallen span's cable runs down the slope (docs/LANDSCAPES.md: 6).
const SPAN_RUN := 6.0


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.HOODOO: hoodoo(k, v, c)
		PropKind.ARCH_RIB: arch_rib(k, v, c)
		PropKind.FALLEN_SPAN: fallen_span(k, v, c)
		PropKind.CISTERN: cistern(k, v, c)
		PropKind.SPAN_PYLON: span_pylon(k, v, c)


## The strata: the dressing's stone and a paler face of it, in the order a bank of
## sandstone lays them down — dark, red, pale, red — so a column of it reads
## as layers and not as one colour. Indexed by COURSE, so two things standing
## side by side band at the same heights, the way strata do.
static func _strata(c: int) -> Array[Color]:
	var d := BiomeDressing.of(c)
	return [d.stone[1], d.stone[0], GroundColors.up(d.stone[0], 0.4), d.stone[0], d.stone[1].lerp(d.stone[2], 0.5)]


## What drifts against a thing left out here: the dressing's own drift, which
## is always filled in (unset, it is the land's plain ground).
static func _drift(c: int) -> Color:
	var d := BiomeDressing.of(c)
	return d.drift[0] if not d.drift.is_empty() else d.stone[0]


## The band a height falls in: strata keep their heights across a landscape.
static func _band(strata: Array[Color], y: float) -> Color:
	var i := floori(y / 0.42) % strata.size()
	return strata[i if i >= 0 else i + strata.size()]


## A quad that FACES `out`, whichever way its corners were listed: a quad's
## front is (c - b) x (a - b), and a MADE face wound backwards is not dark, it
## is absent (CLAUDE.md: the scrap tree's plate).
static func _facing(pen: MeshKit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, col: Color) -> void:
	if (c - b).cross(a - b).dot(out) >= 0.0:
		pen.quad(a, b, c, d, col)
	else:
		pen.quad(d, c, b, a, col)


# --- what the wind made --------------------------------------------------------

## A hoodoo: a column of soft banded rock the wind has necked in, with a harder
## cap stone balanced on its head that is why it is still standing. 0.8 wide,
## 3.5 high. Built as courses, each a little off the last and a little narrower
## at its top than the next is at its foot, so every stratum is a ledge the
## sun catches. Welded course by course: wind-worn rock is round.
##
## Variants: a tall one; a short fat one whose neck is nearly gone; a pair, a
## second younger spire beside the first with its cap still on.
static func hoodoo(k: Kit, v: int, c: int) -> void:
	var s := 9700 + v * 29 + c
	var strata := _strata(c)
	var d := BiomeDressing.of(c)
	match v:
		0:
			_spire(k, s, strata, d, Vector3.ZERO, 3.5, 0.42)
		1:
			_spire(k, s, strata, d, Vector3.ZERO, 2.5, 0.5)
		_:
			_spire(k, s, strata, d, Vector3(-0.1, 0.0, -0.18), 3.1, 0.4)
			_spire(k, s + 11, strata, d, Vector3(0.34, 0.0, 0.46), 1.9, 0.3)
	# What came off it, lying at its foot.
	k.stone(0.52, -0.04, -0.3, 0.16, 0.12, s + 31, d.stone[1], 5, 0.1)
	k.stone(-0.46, -0.04, 0.34, 0.11, 0.09, s + 32, strata[2], 5)


## One spire of `h` rising from `at`, `r` across at its foot, with its cap.
static func _spire(k: Kit, s: int, strata: Array[Color], d: BiomeDressing, at: Vector3, h: float, r: float) -> void:
	const N := 9
	# The column's profile as a share of `r` up its height: a wide foot, a
	# bulge where a harder band stands out, the neck the wind cut, and the
	# shoulder the cap sits on.
	var prof: Array[Vector2] = [Vector2(1.0, 0.0), Vector2(0.86, 0.14), Vector2(0.9, 0.3), Vector2(0.7, 0.46),
		Vector2(0.78, 0.6), Vector2(0.52, 0.76), Vector2(0.44, 0.88), Vector2(0.6, 0.93)]
	var col_h := h * 0.93
	for i in prof.size() - 1:
		var y0 := col_h * prof[i].y - (0.06 if i == 0 else 0.0)
		var y1 := col_h * prof[i + 1].y
		var dx := at.x + Kit.j(s, i, 0.04)
		var dz := at.z + Kit.j(s, i + 20, 0.04)
		var col := _band(strata, (y0 + y1) * 0.5)
		var start := k.made.vertex_count()
		# A course's top is a shade narrower than the next course's foot: that
		# step is the ledge a stratum makes.
		k.made.prism(dx, y0, dz, r * prof[i].x, y1, r * prof[i + 1].x * 0.94, N, col, GroundColors.up(col, 0.1), float(i) * 0.37)
		k.made.smooth_range(start, k.made.vertex_count(), 60.0)
	# The cap stone: wider than the neck under it, harder, darker, and set a
	# hair off true, which is what makes a hoodoo look like it is about to go.
	var cap_y := col_h * 0.93
	var cap := GroundColors.down(d.stone[1], 0.35)
	# A flat worn lump and not a block: the first frame of it was a slab, and a
	# slab on a spire reads as a crate somebody set there.
	k.made.push(Transform3D(Basis(Vector3.BACK, Kit.j(s, 90, 0.1)), Vector3(at.x, cap_y - 0.04, at.z)))
	k.stone(0.0, 0.0, 0.0, r * 0.95, h * 0.06 + 0.16, s + 91, cap, 7, 0.0, GroundColors.up(cap, 0.18))
	k.made.pop()


## A thin natural arch, its span along X, 4 across and about 3 to its crown,
## high enough to walk under. The rib thickens and deepens toward its feet the
## way a real one does, where it carries the weight; its courses are the same
## strata as everything round it, so the bands run straight through the arch as
## if it were cut out of a wall — which is what it was.
##
## Variants: a round arch; a flatter one with its crown worn thin, the kind that
## comes down next winter.
static func arch_rib(k: Kit, v: int, c: int) -> void:
	var s := 9800 + v * 37 + c
	var strata := _strata(c)
	var d := BiomeDressing.of(c)
	var rise := ARCH_RISE if v == 0 else ARCH_RISE * 0.82
	const SEGS := 14
	var inner: Array[Vector3] = []
	var outer: Array[Vector3] = []
	var depth: Array[float] = []
	for i in SEGS + 1:
		var t := float(i) / SEGS
		var th := PI * (1.0 - t)
		var foot := 1.0 - sin(th)
		var centre := Vector3(ARCH_HALF * cos(th), rise * sin(th), 0.0)
		var n := Vector3(cos(th) / ARCH_HALF, sin(th) / rise, 0.0).normalized()
		var thick := (0.32 if v == 0 else 0.24) + 0.62 * foot * foot
		var wob := Vector3(Kit.j(s, i, 0.04), Kit.j(s, i + 30, 0.04), 0.0)
		inner.append(centre - n * thick * 0.5 + wob - Vector3(0.0, 0.08 * foot, 0.0))
		outer.append(centre + n * thick * 0.5 + wob)
		depth.append(0.5 + 0.5 * foot + Kit.j(s, i + 60, 0.05))
	for i in SEGS:
		var mid_y := (inner[i].y + outer[i + 1].y) * 0.5
		var col := _band(strata, mid_y)
		var za := depth[i] * 0.5
		var zb := depth[i + 1] * 0.5
		var mid := (inner[i] + outer[i] + inner[i + 1] + outer[i + 1]) * 0.25
		var up := ((outer[i] + outer[i + 1]) - (inner[i] + inner[i + 1])).normalized()
		# The back of the rib, its underside, and its two faces.
		_facing(k.made, outer[i] + Vector3(0, 0, -za), outer[i] + Vector3(0, 0, za), outer[i + 1] + Vector3(0, 0, zb), outer[i + 1] + Vector3(0, 0, -zb), up, GroundColors.up(col, 0.08))
		_facing(k.made, inner[i] + Vector3(0, 0, -za), inner[i] + Vector3(0, 0, za), inner[i + 1] + Vector3(0, 0, zb), inner[i + 1] + Vector3(0, 0, -zb), -up, GroundColors.down(col, 0.3))
		for sz: float in [-1.0, 1.0]:
			_facing(k.made, inner[i] + Vector3(0, 0, sz * za), outer[i] + Vector3(0, 0, sz * za), outer[i + 1] + Vector3(0, 0, sz * zb), inner[i + 1] + Vector3(0, 0, sz * zb), Vector3(0, 0, sz), Kit.tone(col, 0.94 if sz > 0.0 else 0.9))
		# A lip where a harder band stands proud of the rest.
		if i % 4 == 2:
			k.slab(mid.x, mid.y - 0.06, 0.0, 0.3, 0.1, depth[i] + 0.1, s + 70 + i, GroundColors.down(col, 0.2), col, 0.02)
	# Its feet in their own spill, and the stone that fell out of the crown.
	for sx: float in [-1.0, 1.0]:
		k.stone(sx * (ARCH_HALF + 0.35), -0.05, 0.4, 0.26, 0.2, s + 80 + int(sx), d.stone[1], 6, 0.1)
		k.stone(sx * (ARCH_HALF - 0.1), -0.05, -0.55, 0.18, 0.14, s + 84 + int(sx), strata[2], 5)
	k.stone(0.3, -0.04, 0.2, 0.14, 0.1, s + 88, d.stone[0], 5)


# --- what people cut ----------------------------------------------------------------

## A cistern cut at the foot of a wall: a tank of cut stone, its back the rock
## face itself, green water standing in it out of the sun, and a tin cup on a
## chain on the rim, which is how anyone here knows it is somebody's. 1.6
## across. The water is the land's own spring (docs/LANDSCAPES.md), and the
## one standing water on a mesa a person will stop at.
##
## Variants: open; half covered with planks against the sun, which is what a
## cistern somebody still keeps looks like.
static func cistern(k: Kit, v: int, c: int) -> void:
	var s := 9900 + v * 41 + c
	var d := BiomeDressing.of(c)
	var cut := GroundColors.made(d.walling[0], GroundColors.CUTSTONE)
	var cut2 := GroundColors.made(d.walling[1], GroundColors.CUTSTONE)
	var cut_top := GroundColors.made(GroundColors.up(d.walling[2], 0.2), GroundColors.CUTSTONE)
	# The rock the tank was cut into, behind it: the wall's foot.
	# Rounded, and banded like every other piece of this rock: a slab here read
	# as a crate the tank was built against.
	var strata := _strata(c)
	k.stone(-1.25, -0.1, 0.1, 0.75, 0.8, s, strata[0], 7, 0.0, strata[1])
	k.stone(-1.2, 0.62, -0.1, 0.62, 0.7, s + 6, strata[2], 7, -0.06, strata[3])
	k.stone(-0.9, -0.05, 0.95, 0.3, 0.5, s + 1, d.stone[1], 6, 0.05)
	# The tank: four walls of cut stone, the back one the rock's own face.
	const HX := 0.62
	const HZ := 0.62
	const TH := 0.16
	const WH := 0.5
	k.slab(HX, -0.06, 0.0, TH, WH, HZ * 2.0 + TH, s + 2, cut, cut_top, 0.01)
	k.slab(-0.02, -0.06, HZ, HX * 2.0 - 0.1, WH, TH, s + 3, cut2, cut_top, 0.01)
	k.slab(-0.02, -0.06, -HZ, HX * 2.0 - 0.1, WH, TH, s + 4, cut, cut_top, 0.01)
	# The water, standing green in the dark of the tank a hand under the rim.
	var water := P.MOSS[1].lerp(P.SPRUCE[2], 0.5)
	_facing(k.made, Vector3(-0.66, WH - 0.2, -HZ + 0.08), Vector3(-0.66, WH - 0.2, HZ - 0.08), Vector3(HX - 0.08, WH - 0.2, HZ - 0.08), Vector3(HX - 0.08, WH - 0.2, -HZ + 0.08), Vector3.UP, water)
	# A skin of green scum along the back where it never moves.
	_facing(k.made, Vector3(-0.66, WH - 0.195, -HZ + 0.08), Vector3(-0.66, WH - 0.195, HZ - 0.08), Vector3(-0.4, WH - 0.195, HZ - 0.08), Vector3(-0.4, WH - 0.195, -HZ + 0.08), Vector3.UP, P.MOSS[3])
	# The spout: a cut lip on the front wall where it is drawn from.
	k.slab(HX + 0.1, WH - 0.12, 0.0, 0.2, 0.08, 0.2, s + 5, cut2, cut_top, 0.005)
	# The tin cup on the rim and the chain that keeps it there, to a peg
	# driven into the rock.
	var peg := Vector3(-0.72, 0.9, 0.5)
	k.rod(peg, peg + Vector3(0.12, 0.0, 0.0), 0.018, 4, P.PLATE[2])
	var cup := Vector3(HX - 0.04, WH - 0.06, 0.4)
	k.cable(peg + Vector3(0.12, 0.0, 0.0), cup + Vector3(0.0, 0.1, 0.0), 0.25, 5, 0.008, P.PLATE[1])
	k.found.prism(cup.x, cup.y, cup.z, 0.055, cup.y + 0.1, 0.06, 8, P.PLATE[4], P.PLATE[3])
	k.rod(cup + Vector3(0.0, 0.06, 0.06), cup + Vector3(0.0, 0.06, 0.1), 0.01, 4, P.PLATE[3])
	if v == 1:
		# Planks laid over half of it against the sun, a stone on them.
		var timber := GroundColors.made(d.timber[0], GroundColors.TIMBER)
		var dark := GroundColors.made(d.timber[1], GroundColors.TIMBER)
		for i in 3:
			k.slab(-0.3 + i * 0.22, WH - 0.04, 0.02, 0.2, 0.05, HZ * 2.0 + 0.12, s + 10 + i, dark if i == 1 else timber, timber, 0.01)
		k.stone(-0.1, WH + 0.01, -0.2, 0.12, 0.1, s + 14, d.stone[1], 5)


# --- what the plan strung --------------------------------------------------------

## The ropeway's pylon: a lattice mast on four splayed legs, a crossarm at its
## head carrying two sheaves, and the cable leaving both ways over them toward
## the next station across the canyon. 5 high. The span itself is a prop of
## two points (docs/LANDSCAPES.md, shared system 7), so here the cable only
## leaves: what it runs to is not drawn until a prop can reach two places.
static func span_pylon(k: Kit, v: int, c: int) -> void:
	var s := 9950 + v * 43 + c
	const FOOT := 0.72
	const TOP := 0.2
	var legs: Array[Vector3] = []
	var heads: Array[Vector3] = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			legs.append(Vector3(sx * FOOT, -0.05, sz * FOOT))
			heads.append(Vector3(sx * TOP, PYLON_HEAD, sz * TOP))
	for i in 4:
		k.rod(legs[i], heads[i], 0.05, 5, P.PLATE[3])
		# Its foot plate, bolted to the rock.
		k.chamfer(legs[i].x, -0.04, legs[i].z, 0.3, 0.08, 0.3, 0.05, P.PLATE[2], P.PLATE[3])
	# The lattice: rings of rod at four heights and an X-brace in every face.
	var ring_y: Array[float] = [0.9, 2.0, 3.0, 3.9]
	var order: Array[int] = [0, 1, 3, 2]
	var prev: Array[Vector3] = [legs[0], legs[1], legs[3], legs[2]]
	for yi in ring_y.size():
		var y: float = ring_y[yi]
		var t := (y + 0.05) / (PYLON_HEAD + 0.05)
		var ring: Array[Vector3] = []
		for i in order:
			ring.append(legs[i].lerp(heads[i], t))
		for i in 4:
			k.rod(ring[i], ring[(i + 1) % 4], 0.022, 4, P.PLATE[2])
		for i in 4:
			k.rod(prev[i], ring[(i + 1) % 4], 0.016, 4, P.PLATE[2])
			k.rod(prev[(i + 1) % 4], ring[i], 0.016, 4, P.PLATE[2])
		prev = ring
	# The head: a housing on the top, a crossarm along X and a sheave at each
	# end with the cable over it.
	k.chamfer(0.0, PYLON_HEAD - 0.1, 0.0, 0.62, 0.34, 0.5, 0.06, P.PLATE[3], P.PLATE[4])
	var arm_y := PYLON_HEAD + 0.12
	k.rod(Vector3(-0.95, arm_y, 0.0), Vector3(0.95, arm_y, 0.0), 0.06, 6, P.PLATE[3])
	for sx: float in [-1.0, 1.0]:
		var hub := Vector3(sx * 0.85, arm_y + 0.28, 0.0)
		k.hoop(hub, 0.24, 12, 0.03, P.PLATE[4], Vector3.BACK)
		k.found.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), hub))
		k.found.prism(0.0, -0.04, 0.0, 0.2, 0.04, 0.2, 12, P.PLATE[1], P.PLATE[2])
		k.found.pop()
		k.rod(hub, Vector3(sx * 0.85, arm_y, 0.0), 0.03, 4, P.PLATE[2])
		# The cable over the sheave and away, falling toward the canyon.
		var over := hub + Vector3(0.0, 0.25, 0.0)
		k.cable(over, over + Vector3(sx * 2.4, -1.1, 0.0), 0.12, 4, 0.028, P.INK[2])
	# The station's plate and a ladder up one leg for whoever services it.
	# On the housing's +Z face, clear of the crossarm that runs along X through
	# the other two (the first cut of it faced into the housing and was drawn
	# from no bearing at all: tests/render/test_found_drawn.gd).
	k.plate(Vector3(-0.18, PYLON_HEAD - 0.06, 0.251), Vector3(0.18, PYLON_HEAD - 0.06, 0.251), Vector3(0.18, PYLON_HEAD + 0.14, 0.251), Vector3(-0.18, PYLON_HEAD + 0.14, 0.251), P.PLATE[2], P.PLATE[1], P.PLATE[4])
	var la := legs[1]
	var lb := heads[1]
	for i in 12:
		var p := la.lerp(lb, (i + 1) / 13.0)
		k.rod(p + Vector3(-0.08, 0.0, 0.06), p + Vector3(0.08, 0.0, 0.06), 0.01, 4, P.PLATE[4])
	# Red dust drifted against the feet.
	for i in 4:
		k.clump(legs[i].x * 1.1, -0.06, legs[i].z * 1.1, 0.22, 0.08, s + i, _drift(c), 6)


## One of the ropeway's spans come down: the cable snapped at the head and
## strewn down the scree for six units, its bucket line still on it, and the
## pylon leg it tore out bent over at the origin. FOUND, all of it, and a plan
## work nobody came back for. The cable is what a steel edge cuts rope out of.
##
## Variants: the buckets on it, and a second where two of them are off and
## lying open on the scree.
static func fallen_span(k: Kit, v: int, c: int) -> void:
	var s := 9980 + v * 47 + c
	# The leg: two members of lattice bent over where it snapped, lying toward
	# -X away from the fall, with its foot plate still bolted.
	k.chamfer(0.0, -0.04, 0.0, 0.32, 0.08, 0.32, 0.05, P.PLATE[2], P.PLATE[3])
	var knee := Vector3(-0.1, 1.3, 0.05)
	var tip := Vector3(-1.4, 0.35, 0.3)
	k.rod(Vector3(0.0, 0.0, 0.0), knee, 0.05, 5, P.PLATE[3])
	k.rod(knee, tip, 0.045, 5, P.PLATE[3])
	k.rod(Vector3(0.12, 0.0, 0.12), knee + Vector3(0.12, -0.05, 0.1), 0.035, 4, P.PLATE[2])
	k.rod(knee + Vector3(0.12, -0.05, 0.1), tip + Vector3(0.1, -0.05, 0.14), 0.035, 4, P.PLATE[2])
	for i in 4:
		var a := Vector3.ZERO.lerp(knee, (i + 0.5) / 4.0)
		k.rod(a, a + Vector3(0.12, -0.03, 0.12), 0.014, 4, P.PLATE[2])
	# A sheave torn off with it, lying on its side.
	k.hoop(Vector3(-0.5, 0.06, -0.45), 0.24, 12, 0.03, P.PLATE[4], Vector3.UP)
	k.found.prism(-0.5, 0.0, -0.45, 0.2, 0.06, 0.2, 12, P.PLATE[1], P.PLATE[2])
	# The cable, down the slope in three lying runs, kinked where it hit.
	var pts: Array[Vector3] = [knee + Vector3(0.05, 0.0, 0.0), Vector3(1.4, 0.06, 0.25), Vector3(3.2, 0.04, -0.2),
		Vector3(4.8, 0.05, 0.35), Vector3(SPAN_RUN, 0.04, 0.1)]
	for i in pts.size() - 1:
		k.cable(pts[i], pts[i + 1], 0.02 if i > 0 else -0.25, 4, 0.03, P.INK[2])
	# The snapped end: the strands splayed.
	var end := pts[pts.size() - 1]
	for j in 5:
		var a := float(j) / 5.0 * PI - PI * 0.5
		k.rod(end, end + Vector3(cos(a) * 0.22, 0.02 + 0.03 * j, sin(a) * 0.22), 0.006, 3, P.PLATE[3])
	# The buckets: open steel boxes on hangers, on their sides where they fell.
	var on: Array[float] = [0.45]
	if v == 0:
		on = [0.3, 0.55, 0.8]
	for t: float in on:
		var at := _along(pts, t)
		_bucket(k, at + Vector3(0.0, 0.0, 0.32), 0.5 + t, s + int(t * 100.0))
	if v == 1:
		_bucket(k, Vector3(2.4, 0.0, -0.9), 1.9, s + 7)
		_bucket(k, Vector3(4.1, 0.0, 1.0), -0.6, s + 8)
	# Red dust already over the low end of it.
	k.clump(SPAN_RUN - 0.4, -0.06, 0.1, 0.3, 0.07, s + 20, _drift(c), 6)
	k.clump(3.3, -0.06, -0.2, 0.24, 0.06, s + 21, _drift(c), 6)


## A point `t` of the way along a polyline, by segment count (it only has to
## land on the cable, not measure it).
static func _along(pts: Array[Vector3], t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * (pts.size() - 1)
	var i := mini(floori(f), pts.size() - 2)
	return pts[i].lerp(pts[i + 1], f - i)


## One bucket lying on its side, turned `yaw` about the vertical: an open steel
## box on a hanger bar.
static func _bucket(k: Kit, at: Vector3, yaw: float, s: int) -> void:
	k.found.push(Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5 + Kit.j(s, 1, 0.2)), at + Vector3(0.0, 0.2, 0.0)))
	k.chamfer(0.0, -0.18, 0.0, 0.42, 0.34, 0.36, 0.04, P.RUST[2].lerp(P.PLATE[2], 0.5), P.INK[1])
	k.rod(Vector3(-0.22, 0.2, 0.0), Vector3(0.22, 0.2, 0.0), 0.015, 4, P.PLATE[3])
	k.found.pop()


# --- what the mesas' people live in (BiomeForms: cut_room, adobe, watch_hut) ---

## Mud brick, lit as clay (row 84): the red of the ground it was dug from,
## tagged at the source so every face `Houses.walls` darkens keeps the mark.
static func _clay(c: int, lift: float = 0.0) -> Color:
	var d := BiomeDressing.of(c)
	return GroundColors.made(GroundColors.up(d.walling[0].lerp(d.stone[0], 0.6), lift), GroundColors.CLAY)


## Timber that went silver in the sun and never rotted, as TIMBER (row 80).
static func _timber(c: int, i: int = 0) -> Color:
	return GroundColors.made(BiomeDressing.of(c).timber[i], GroundColors.TIMBER)


## A cloth hung over a doorway, from its rod down `h`, facing `out`: the one
## soft colour in a village of red rock, and what a door is here.
static func _curtain(k: Kit, at: Vector3, out: Vector3, w: float, h: float, col: Color, s: int) -> void:
	var o := out.normalized()
	var side := o.cross(Vector3.UP).normalized()
	for i in 3:
		var u0 := -w * 0.5 + i * w / 3.0
		var u1 := u0 + w / 3.0 - 0.01
		var hang := h - 0.06 * float(i % 2) + Kit.j(s, i, 0.04)
		_facing(k.made, at + side * u0 + o * 0.01, at + side * u1 + o * 0.01, at + side * u1 + Vector3(0, -hang, 0) + o * (0.02 + 0.02 * i),
			at + side * u0 + Vector3(0, -hang, 0) + o * (0.02 + 0.02 * i), o, Kit.tone(col, 0.92 + 0.06 * i))
	k.limb(at + side * (-w * 0.6), at + side * (w * 0.6), 0.02, 0.02, 4, _timber_plain(), Vector3.ZERO, Kit.SAWN)


static func _timber_plain() -> Color:
	return P.LINEN[3].lerp(P.ASH[3], 0.5)


## "cut_room": a room dug into the scarp, where only the front wall and the
## door are built. The rock stands over it and behind it in its own strata; the
## wall is mud brick set into the cut, a curtained door, one small window, a
## water jar by the door and a line of stones where the step was cut. 2.4 high.
static func cut_room(k: Kit, c: int) -> void:
	var s := 10100 + c
	var strata := _strata(c)
	var d := BiomeDressing.of(c)
	# The scarp: banded rock behind and over the room, rounded, a lip of the
	# harder band standing out over the front wall as its only roof.
	k.stone(-0.9, -0.1, 0.0, 1.35, 1.1, s, strata[0], 7, 0.0, strata[1])
	k.stone(-0.95, 0.9, 0.1, 1.25, 0.9, s + 1, strata[2], 7, 0.04, strata[3])
	k.stone(-0.85, 1.7, -0.05, 1.05, 0.7, s + 2, strata[1], 7, -0.04, strata[4])
	# The lip: a lump of the harder band standing out over the wall. A slab here
	# read as a table top laid on the rock.
	k.made.push(Transform3D(Basis(Vector3.RIGHT, 0.04), Vector3(0.1, 2.02, 0.0)))
	k.made.push(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.9)), Vector3.ZERO))
	k.stone(0.0, 0.0, 0.0, 0.7, 0.3, s + 3, GroundColors.down(d.stone[1], 0.2), 7, 0.0, strata[1])
	k.made.pop()
	k.made.pop()
	# The front wall: two piers of brick either side of the door and a lintel
	# over it, set into the cut.
	var clay := _clay(c)
	var clay_dark := GroundColors.down(clay, 0.25)
	for sz: float in [-1.0, 1.0]:
		k.slab(0.46, -0.04, sz * 0.72, 0.28, 2.16, 0.9, s + 10 + int(sz), clay, GroundColors.up(clay, 0.12), 0.02, 0.02, 0.0)
	k.slab(0.46, 1.5, 0.0, 0.3, 0.66, 0.62, s + 12, clay_dark, clay, 0.015)
	# The dark of the room behind the door.
	_facing(k.made, Vector3(0.4, 0.0, -0.27), Vector3(0.4, 0.0, 0.27), Vector3(0.4, 1.5, 0.27), Vector3(0.4, 1.5, -0.27), Vector3.RIGHT, P.INK[1])
	_curtain(k, Vector3(0.63, 1.48, 0.0), Vector3.RIGHT, 0.56, 1.1, P.RUST[3].lerp(P.LINEN[3], 0.3), s + 20)
	# A small window in the right pier, and the brick courses ruled on both.
	_facing(k.made, Vector3(0.611, 1.0, 0.62), Vector3(0.611, 1.0, 0.82), Vector3(0.611, 1.24, 0.82), Vector3(0.611, 1.24, 0.62), Vector3.RIGHT, P.INK[2])
	for sz: float in [-1.0, 1.0]:
		for ci in 6:
			var y := 0.3 + ci * 0.3
			_facing(k.made, Vector3(0.612, y, sz * 0.3), Vector3(0.612, y, sz * 1.15), Vector3(0.612, y + 0.02, sz * 1.15), Vector3(0.612, y + 0.02, sz * 0.3), Vector3.RIGHT, clay_dark)
	# Vigas: roof poles let into the rock, their ends out over the wall.
	for i in 4:
		var z := -0.9 + i * 0.6
		k.limb(Vector3(-0.3, 1.98, z), Vector3(0.84, 1.98 + Kit.j(s, 30 + i, 0.03), z + Kit.j(s, 40 + i, 0.05)), 0.055, 0.045, 5, _timber(c, i % 2), Vector3.ZERO, Kit.SAWN)
	# The step cut into the ground, a jar by the door.
	k.slab(0.95, -0.06, 0.0, 0.5, 0.1, 0.8, s + 50, d.stone[1], strata[2], 0.02)
	k.made.prism(0.8, 0.0, 0.55, 0.12, 0.34, 0.08, 8, _clay(c, 0.3), GroundColors.down(_clay(c), 0.4))


## "adobe": red mud brick in soft-cornered walls, a flat roof on vigas whose
## ends stand out of the wall tops, a parapet, a ladder to the roof where the
## living is done in the evening, and pots along the foot. 2.6 high.
static func adobe(k: Kit, c: int) -> void:
	var s := 10200 + c
	var clay := _clay(c)
	var t := PropModels.Houses.walls(k, 2.4, 2.2, 2.0, s, clay, GroundColors.down(clay, 0.3), Vector3(0.0, 0.0, 0.0))
	var fb := [t[2], t[1], t[5], t[6]]
	PropModels.Houses.door(k, fb[0], fb[1], fb[2], fb[3], 0.62, 0.12, 0.92)
	PropModels.Houses.wall_rect(k.made, fb[0], fb[1], fb[2], fb[3], 0.2, 0.55, 0.34, 0.72, 0.012, P.INK[2])
	var sb := [t[3], t[2], t[6], t[7]]
	PropModels.Houses.wall_rect(k.made, sb[0], sb[1], sb[2], sb[3], 0.45, 0.55, 0.58, 0.72, 0.012, P.INK[2])
	# Mud plaster worn off in the rain it hardly ever gets: the brick shows.
	for fi in 2:
		var wf: Array = PropModels.Houses.faces(t)[fi]
		for i in 3:
			var u0 := fmod(0.15 + i * 0.31 + fi * 0.2, 0.75)
			var v0 := fmod(0.1 + i * 0.27, 0.7)
			PropModels.Houses.wall_rect(k.made, wf[0], wf[1], wf[2], wf[3], u0, v0, u0 + 0.12, v0 + 0.08, 0.008, GroundColors.down(clay, 0.4))
	# The roof: a flat slab a hand inside the wall tops, a parapet round it.
	var top := minf(minf(t[4].y, t[5].y), minf(t[6].y, t[7].y))
	k.slab(0.0, top - 0.12, 0.0, 2.3, 0.12, 2.1, s + 1, GroundColors.down(clay, 0.2), GroundColors.up(clay, 0.08), 0.02)
	# The parapet, square to the walls' own footprint: front and back across Z,
	# the two sides across X.
	for sx: float in [-1.0, 1.0]:
		k.slab(sx * 1.14, top - 0.04, 0.0, 0.16, 0.26, 2.2, s + 5 + int(sx), clay, GroundColors.up(clay, 0.15), 0.02)
	for sz: float in [-1.0, 1.0]:
		k.slab(0.0, top - 0.04, sz * 1.04, 2.1, 0.26, 0.16, s + 8 + int(sz), clay, GroundColors.up(clay, 0.15), 0.02)
	# Vigas out through the wall under the parapet, front and back.
	for i in 5:
		var z := -0.8 + i * 0.4
		k.limb(Vector3(-1.45, top - 0.2, z), Vector3(1.45, top - 0.2 + Kit.j(s, 60 + i, 0.02), z), 0.05, 0.045, 5, _timber(c, i % 2), Vector3.ZERO, Kit.SAWN)
	# A ladder up the +Z side to the roof.
	var lz := 1.22
	for sx: float in [-1.0, 1.0]:
		k.limb(Vector3(-0.35 + sx * 0.2, 0.0, lz + 0.18), Vector3(-0.35 + sx * 0.2, top + 0.5, lz - 0.02), 0.03, 0.025, 4, _timber(c, 0), Vector3.ZERO, Kit.SAWN)
	for i in 6:
		var y := 0.3 + i * (top / 6.0)
		var zz := lz + 0.18 - 0.2 * (y / (top + 0.5))
		k.limb(Vector3(-0.58, y, zz), Vector3(-0.12, y, zz), 0.02, 0.02, 4, _timber(c, 1), Vector3.ZERO, Kit.SAWN)
	# Pots along the front foot and a bench of brick.
	for i in 3:
		k.made.prism(1.3, 0.0, -0.8 + i * 0.28, 0.1 + 0.02 * i, 0.26 + 0.05 * i, 0.07, 8, _clay(c, 0.25), GroundColors.down(_clay(c), 0.35), float(i))
	k.slab(1.35, -0.04, 0.7, 0.3, 0.36, 0.7, s + 70, GroundColors.down(clay, 0.15), clay, 0.02)


## Where the watch hut's stolen lamp hangs, in its own frame: a bucket off the
## ropeway strung from the hut's eave on the side that faces the square, with a
## tube wired inside it. The light and the tube are one place.
const WATCH_LAMP := Vector3(0.95, 2.35, 0.0)


## "watch_hut": a plank hut on four poles at the rim edge, reached by a ladder,
## a lean-to roof of plate and silvered boards, and a ropeway bucket hung off its
## eave with a stolen tube in it: the one light in a mesas village, and it is
## the plan's own bucket. 3.4 high. Lit.
static func watch_hut(k: Kit, c: int) -> void:
	var s := 10300 + c
	const DECK := 1.6
	# The stilts, braced, and the deck on them.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.limb(Vector3(sx * 0.62, -0.05, sz * 0.62), Vector3(sx * 0.55, DECK, sz * 0.55), 0.06, 0.05, 5, _timber(c, 1), Vector3.ZERO, Kit.SAWN)
	for sz: float in [-1.0, 1.0]:
		k.limb(Vector3(-0.62, 0.2, sz * 0.62), Vector3(0.55, DECK - 0.2, sz * 0.55), 0.03, 0.03, 4, _timber(c, 0), Vector3.ZERO, Kit.SAWN)
	for i in 5:
		k.slab(-0.72 + i * 0.36, DECK, 0.0, 0.34, 0.06, 1.5, s + i, _timber(c, i % 2), _timber(c, 0), 0.01)
	# The hut: plank walls, a door on +X, a slit to look out of over the drop,
	# all built up on the deck (the made pen is lifted there while they are).
	var boards := _timber(c, 0)
	k.made.push(Transform3D(Basis(), Vector3(0.0, DECK + 0.06, 0.0)))
	var t := PropModels.Houses.walls(k, 1.2, 1.2, 1.05, s + 20, boards, GroundColors.down(boards, 0.3), Vector3(0.0, 0.0, 0.0))
	var fb := [t[2], t[1], t[5], t[6]]
	PropModels.Houses.door(k, fb[0], fb[1], fb[2], fb[3], 0.3, 0.11, 0.85)
	var bk := [t[0], t[3], t[7], t[4]]
	PropModels.Houses.wall_rect(k.made, bk[0], bk[1], bk[2], bk[3], 0.2, 0.62, 0.8, 0.72, 0.012, P.INK[1])
	k.made.pop()
	# The roof: a lean-to of plate and board, pitched to the back.
	var eave_hi := DECK + 1.28
	k.plate(Vector3(0.78, eave_hi, 0.78), Vector3(0.78, eave_hi, -0.78), Vector3(-0.78, eave_hi - 0.32, -0.78), Vector3(-0.78, eave_hi - 0.32, 0.78),
		P.PLATE[2], P.PLATE[1], P.PLATE[4])
	# The ladder up from the ground on the +Z side.
	for sx: float in [-1.0, 1.0]:
		k.limb(Vector3(0.25 + sx * 0.18, 0.0, 1.15), Vector3(0.25 + sx * 0.18, DECK + 0.4, 0.66), 0.028, 0.024, 4, _timber(c, 1), Vector3.ZERO, Kit.SAWN)
	for i in 5:
		var f := (i + 1) / 6.0
		k.limb(Vector3(0.05, f * (DECK + 0.4), lerpf(1.15, 0.66, f)), Vector3(0.45, f * (DECK + 0.4), lerpf(1.15, 0.66, f)), 0.018, 0.018, 4, _timber(c, 0), Vector3.ZERO, Kit.SAWN)
	# The stolen lamp: a ropeway bucket hung off the eave on its bar, open to
	# the square, the tube wired inside it. The bucket is the plan's, and FOUND.
	var lamp := WATCH_LAMP
	k.rod(Vector3(0.78, eave_hi - 0.02, 0.0), lamp + Vector3(0.0, 0.2, 0.0), 0.012, 4, P.PLATE[3])
	k.chamfer(lamp.x, lamp.y - 0.16, lamp.z, 0.3, 0.26, 0.26, 0.03, P.RUST[2].lerp(P.PLATE[2], 0.5), P.INK[1])
	_tube(k, lamp + Vector3(0.16, 0.0, 0.1), lamp + Vector3(0.16, 0.0, -0.1), Vector3.RIGHT, PropModels.Houses.NEON_TUBES[0])


## A tube of stolen neon from a to b standing out along `out`: its dark mount
## and the tube, NEON-marked so `PropModels.neon_point` finds it and the light
## it throws stands where the tube is (the metropolis's `_tube`, the same rule).
static func _tube(k: Kit, a: Vector3, b: Vector3, out: Vector3, col: Color) -> void:
	var o := out.normalized()
	PropModels.Remains._facing_quad(k.made, a + o * 0.01 + Vector3(0, -0.04, 0), b + o * 0.01 + Vector3(0, -0.04, 0), Vector3(0, 0.08, 0), o, P.INK[1])
	PropModels.Remains._facing_quad(k.made, a + o * 0.02 + Vector3(0, -0.024, 0), b + o * 0.02 + Vector3(0, -0.024, 0), Vector3(0, 0.048, 0), o, GroundColors.neon(col))


## Where the shelter's hearth burns, in its own frame: just inside the mouth of
## the cut, which faces +X. The light (`glow_points`) and the embers are one place.
const HEARTH_AT := Vector3(0.35, 0.06, 0.3)


## The mesas' patched shelter (`BiomeDressing.shelter`): a small cut room, a
## hollow under a lip of banded rock with a hide hung across its mouth and a
## sheet of plate propped against the weather side. Nothing wired in; the lit
## one (variant 1, as every shelter counts it) has a hearth going in the mouth
## of the cut, and a fire's light is what a night bench is seen by.
static func cut_room_shelter(k: Kit, s: int, lit: bool, d: BiomeDressing, c: int) -> void:
	var strata := _strata(c)
	k.stone(-0.55, -0.1, 0.0, 0.95, 0.8, s, strata[0], 7, 0.0, strata[1])
	k.stone(-0.5, 0.62, 0.05, 0.85, 0.6, s + 1, strata[2], 7, 0.05, strata[3])
	k.made.push(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.7)), Vector3(0.1, 0.98, 0.0)))
	k.stone(0.0, 0.0, 0.0, 0.5, 0.24, s + 2, GroundColors.down(d.stone[1], 0.2), 7, 0.0, strata[1])
	k.made.pop()
	_facing(k.made, Vector3(0.05, 0.0, -0.4), Vector3(0.05, 0.0, 0.4), Vector3(0.05, 1.0, 0.4), Vector3(0.05, 1.0, -0.4), Vector3.RIGHT, P.INK[1])
	_curtain(k, Vector3(0.5, 1.02, -0.18), Vector3.RIGHT, 0.46, 0.8, P.EARTH[3].lerp(P.SAND[3], 0.4), s + 10)
	k.plate(Vector3(0.62, 0.0, 0.62), Vector3(0.28, 0.0, 0.92), Vector3(0.18, 0.86, 0.8), Vector3(0.52, 0.86, 0.5), P.PLATE[2], P.PLATE[1], P.PLATE[4])
	if lit:
		var h := HEARTH_AT
		for i in 5:
			var a := float(i) / 5.0 * TAU + 0.3
			k.stone(h.x + cos(a) * 0.18, 0.0, h.z + sin(a) * 0.18, 0.06, 0.05, s + 800 + i, d.stone[1], 5)
		k.made.prism(h.x, 0.01, h.z, 0.11, 0.06, 0.08, 6, GroundColors.glow(P.EMBER[3], 0.9), GroundColors.glow(P.EMBER[4], 1.1))


## Every mesas kind in the mesas' own dressing, named so `--filter=mesas` finds
## them all at once (src/gallery.gd folds case and underscores).
static func gallery() -> Array:
	var out: Array = []
	var mesas := BiomeRegistry.index_of(&"mesas")
	for kind: int in KINDS:
		for v in PropModels.variants(kind, mesas):
			out.append({"name": "mesas %s %d" % [PropKind.NAMES[kind], v], "node": PropModels.node(kind, v, mesas)})
	# What its people build and the shelter they patch, in the same dressing:
	# `--filter=mesas_house` and `--filter=mesas_shack`.
	for v in PropModels.variants(PropKind.HOUSE, mesas):
		out.append({"name": "mesas house %d" % v, "node": PropModels.node(PropKind.HOUSE, v, mesas)})
	for v in 2:
		out.append({"name": "mesas shack %d" % v, "node": PropModels.node(PropKind.SHACK, v, mesas)})
	return out
