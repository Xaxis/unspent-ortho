extends RefCounted
## The two pens a prop is drawn with (docs/ART.md law 3): `made` for
## world.gdshader (hatched, by hand, uneven) and `found` for found.gdshader
## (ruled, clean, exact). Builders put each part in the kit it belongs to, and
## draw with the shapes below: nothing here makes a plain box or a smooth cone.
##
## MADE shapes jitter from a seed, so every copy differs; FOUND shapes never do.

var made := MeshKit.new()
var found := MeshKit.new()
## The third pen: LEAVES. Not a lobed solid but many small cards at many angles,
## drawn by src/render/foliage/leaf.gdshader, double-sided and cut to the shape
## of a sprig. See `canopy` for why.
var leaf := MeshKit.new()


func _init() -> void:
	found.style = Ink.NONE
	found.style2 = Ink.NONE


static func j(seed_value: int, i: int, amount: float) -> float:
	return (Rng.hash01(seed_value, i, 0x5eed) - 0.5) * 2.0 * amount


static func tone(col: Color, k: float) -> Color:
	return Color(minf(1.0, col.r * k), minf(1.0, col.g * k), minf(1.0, col.b * k), col.a)


## Set the hatch hand of the MADE pen (Ink.*) and its sway (0 rigid).
func hand(style: int, sway: float = 0.0, phase: float = 0.0) -> void:
	made.style = style
	made.style2 = style
	made.sway = sway
	made.sway_phase = phase


func still() -> void:
	made.sway = 0.0


# --- MADE shapes -------------------------------------------------------------

## A thin tapering spike from a to b, one segment, no cap: roots, twigs.
func spike(a: Vector3, b: Vector3, r: float, sides: int, col: Color) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 1e-5:
		return
	var up := axis / length
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	made.push(Transform3D(Basis(side, up, side.cross(up)), a))
	made.prism(0, 0, 0, r, length, 0.0, sides, col)
	made.pop()


## A tapered, slightly bent limb from a to b: trunks, branches, posts, logs.
func limb(a: Vector3, b: Vector3, r0: float, r1: float, sides: int, col: Color, bend: Vector3 = Vector3.ZERO) -> void:
	var mid := a.lerp(b, 0.5) + bend
	_frustum(a, mid, r0, lerpf(r0, r1, 0.5), sides, col)
	_frustum(mid, b, lerpf(r0, r1, 0.5), r1, sides, col)


func _frustum(a: Vector3, b: Vector3, r0: float, r1: float, sides: int, col: Color) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 1e-5:
		return
	var up := axis / length
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up)
	made.push(Transform3D(Basis(side, up, fwd), a))
	made.prism(0, 0, 0, r0, length, r1, sides, col, Color(0, 0, 0, 0), 0.3, false)
	made.pop()


## Ring profiles, ground to crown, as (radius share, height share). A stone
## bulges BELOW its middle, the way one sits into ground it has been settling
## into, and closes on a crown ring rather than a point: an apex fan drawn to a
## point is a crystal's termination and nothing else, which is exactly what every
## boulder in the game read as once the light became real (docs/LOOK.md law 1).
const STONE_RINGS: Array[Vector2] = [Vector2(0.92, 0.0), Vector2(1.0, 0.3), Vector2(0.95, 0.58), Vector2(0.75, 0.82), Vector2(0.42, 0.95)]
## What a cobble gets, and what a nugget gets. **Detail follows the size a thing
## is actually SEEN at**, which is this package's whole answer to spending more
## geometry: one screen pixel at the play camera is 14/360 of a tile, so a
## 0.08-radius chip of slack on a conveyor is four pixels across and a boulder's
## rings would be thrown away on it. That is not thrift, it is the same rule as
## the distance LOD, applied where the shape is authored.
const STONE_RINGS_SMALL: Array[Vector2] = [Vector2(0.94, 0.0), Vector2(1.0, 0.42), Vector2(0.74, 0.82), Vector2(0.4, 0.96)]
const STONE_RINGS_TINY: Array[Vector2] = [Vector2(0.95, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 0.94)]
## Radii, in tiles, where a stone drops a ring and stops earning extra corners.
const STONE_SMALL := 0.22
const STONE_TINY := 0.13


## The ring profile and corner count a stone or a clump of radius `r` has earned.
static func _detail(r: float, sides: int, big: Array[Vector2], small: Array[Vector2], tiny: Array[Vector2]) -> Array:
	if r < STONE_TINY:
		return [tiny, sides]
	if r < STONE_SMALL:
		return [small, sides + 1]
	return [big, sides + 3]


## A weathered stone: rings on one coherent radial profile, rounded into a single
## mass by the crease smoothing and closed with a crown. `lean` tips the top
## toward +x; `sides` is a floor, raised for anything big enough to show it.
##
## The corner wobble is dealt ONCE and used by every ring, so the rock has
## vertical ribs that read as form rather than as noise — per-ring noise smooths
## into a sphere, and a sphere is the other way to fail this.
func stone(cx: float, y0: float, cz: float, r: float, h: float, seed_value: int, col: Color, sides: int = 6, lean: float = 0.0, top_col: Color = Color(0, 0, 0, 0)) -> void:
	var tc := col if top_col.a == 0.0 else top_col
	var detail := _detail(r, sides, STONE_RINGS, STONE_RINGS_SMALL, STONE_RINGS_TINY)
	var prof: Array[Vector2] = detail[0]
	var n: int = detail[1]
	var rot := Rng.hash01(seed_value, 99) * TAU
	var tx := lean * h + j(seed_value, 97, r * 0.15)
	var tz := j(seed_value, 98, r * 0.15)
	var ang := PackedFloat32Array()
	var wob := PackedFloat32Array()
	for i in n:
		ang.append(rot + float(i) / n * TAU + j(seed_value, i, 0.3))
		wob.append(0.78 + Rng.hash01(seed_value, i, 1) * 0.42)
	var rings: Array[PackedVector3Array] = []
	for ri in prof.size():
		var ring := PackedVector3Array()
		for i in n:
			var a: float = ang[i]
			# A little of each ring's own life, far too little to lose the rib.
			var rr := r * prof[ri].x * wob[i] * (1.0 + j(seed_value, i * 11 + ri, 0.07))
			var t := prof[ri].y
			var y := y0 + h * (t + (j(seed_value, i * 7 + ri, 0.035) if ri > 0 else 0.0))
			ring.append(Vector3(cx + cos(a) * rr + tx * t, y, cz + sin(a) * rr + tz * t))
		rings.append(ring)
	var start := made.vertex_count()
	for ri in rings.size() - 1:
		var lo := rings[ri]
		var hi := rings[ri + 1]
		var band := tone(col, 0.94 + 0.03 * ri)
		for i in n:
			var m := (i + 1) % n
			made.quad(lo[m], lo[i], hi[i], hi[m], band)
	var crown := rings[rings.size() - 1]
	var top := Vector3(cx + tx, y0 + h, cz + tz)
	for i in n:
		made.tri(top, crown[(i + 1) % n], crown[i], tc)
	# The whole mass rounds; where the wobble turns hard it keeps its edge, which
	# is what a fracture plane in a boulder looks like.
	made.smooth_range(start, made.vertex_count())


const CLUMP_RINGS: Array[Vector2] = [Vector2(0.72, 0.1), Vector2(1.0, 0.4), Vector2(0.86, 0.68), Vector2(0.48, 0.88)]
const CLUMP_RINGS_SMALL: Array[Vector2] = [Vector2(0.76, 0.12), Vector2(1.0, 0.46), Vector2(0.56, 0.86)]
const CLUMP_RINGS_TINY: Array[Vector2] = [Vector2(0.8, 0.16), Vector2(1.0, 0.52), Vector2(0.52, 0.9)]


## A lumpy clump: crowns, bushes, heather, turf banks. Rings and a rounded crown,
## smoothed into one mass — the same correction as `stone`, for the same reason:
## at two rings and flat normals a bush was a cut green gem.
##
## `lobe` is what tells FOLIAGE from turf. Smoothing alone turns a bush into a
## smooth green dome, which is a boulder painted green and no better than the
## gem it replaced; leaves hang in masses with daylight between them. At `lobe`
## 1 the corners alternate far out and well in, so the crease pass rounds each
## lobe and keeps the valley between two of them hard — a broken outline out of
## the same triangles. Turf, snow and moss pass 0, because a bank of turf is
## smooth and that is the whole difference.
func clump(cx: float, y0: float, cz: float, r: float, h: float, seed_value: int, col: Color, sides: int = 7, lobe: float = 0.0) -> void:
	var rot := Rng.hash01(seed_value, 51) * TAU
	# A clump is widest low and falls away under itself, so the underside turns
	# from the sun without a skirt of separate geometry to do it.
	var detail := _detail(r, sides, CLUMP_RINGS, CLUMP_RINGS_SMALL, CLUMP_RINGS_TINY)
	var prof: Array[Vector2] = detail[0]
	var n: int = detail[1]
	var ang := PackedFloat32Array()
	var wob := PackedFloat32Array()
	for i in n:
		ang.append(rot + float(i) / n * TAU + j(seed_value, i, 0.26))
		var w := 0.74 + Rng.hash01(seed_value, i, 3) * 0.46
		wob.append(w * lerpf(1.0, 1.3 if i % 2 == 0 else 0.62, lobe))
	var rings: Array[PackedVector3Array] = []
	for ri in prof.size():
		var ring := PackedVector3Array()
		for i in n:
			var a: float = ang[i]
			var rr := r * prof[ri].x * wob[i] * (1.0 + j(seed_value, i * 13 + ri, 0.09))
			ring.append(Vector3(cx + cos(a) * rr, y0 + h * (prof[ri].y + j(seed_value, i * 5 + ri, 0.05)), cz + sin(a) * rr))
		rings.append(ring)
	var start := made.vertex_count()
	var bottom := Vector3(cx, y0, cz)
	var base := rings[0]
	for i in n:
		made.tri(bottom, base[i], base[(i + 1) % n], tone(col, 0.85))
	for ri in rings.size() - 1:
		var lo := rings[ri]
		var hi := rings[ri + 1]
		var band := tone(col, 0.96 + 0.04 * ri)
		for i in n:
			var m := (i + 1) % n
			made.quad(lo[m], lo[i], hi[i], hi[m], band)
	var crown := rings[rings.size() - 1]
	var top := Vector3(cx + j(seed_value, 40, r * 0.18), y0 + h, cz + j(seed_value, 41, r * 0.18))
	for i in n:
		made.tri(top, crown[(i + 1) % n], crown[i], tone(col, 1.05))
	made.smooth_range(start, made.vertex_count())


## One tier of a conifer: a jagged star of drooping branch tips round an
## off-centre apex. Never a smooth cone. The camera never sees under a tier, so
## only the lowest (`under` alpha > 0) gets a darker skirt, for its shadow rim.
func tier(cx: float, y_rim: float, cz: float, r: float, rise: float, points: int, droop: float, seed_value: int, col: Color, under: Color) -> void:
	var rot := Rng.hash01(seed_value, 61) * TAU
	var ring: Array[Vector3] = []
	for i in points * 2:
		var a := rot + float(i) / (points * 2) * TAU + j(seed_value, i, 0.12)
		if i % 2 == 0:
			var rr := r * (0.8 + Rng.hash01(seed_value, i, 5) * 0.4)
			ring.append(Vector3(cx + cos(a) * rr, y_rim - droop * (0.7 + Rng.hash01(seed_value, i, 6) * 0.6), cz + sin(a) * rr))
		else:
			var rn := r * (0.42 + Rng.hash01(seed_value, i, 7) * 0.12)
			ring.append(Vector3(cx + cos(a) * rn, y_rim + droop * 0.15, cz + sin(a) * rn))
	var apex := Vector3(cx + j(seed_value, 62, r * 0.12), y_rim + rise, cz + j(seed_value, 63, r * 0.12))
	var hub := Vector3(cx, y_rim - droop * 0.2, cz)
	var n := ring.size()
	for i in n:
		var m := (i + 1) % n
		made.tri(apex, ring[m], ring[i], col if i % 2 == 0 else tone(col, 0.93))
		if under.a > 0.0 and i % 2 == 0:
			made.tri(hub, ring[i], ring[(i + 2) % n], under)


## A small two-sided triangle: a fleck of flower, ember, shell, chip.
func fleck(p: Vector3, a: Vector3, b: Vector3, col: Color) -> void:
	made.tri(p, a, b, col)
	made.tri(p, b, a, col)


## A flat blade standing from base to tip, seen from both sides: grass, reed,
## flame, frond.
func blade(base: Vector3, tip: Vector3, width: float, angle: float, col: Color) -> void:
	var side := Vector3(cos(angle), 0.0, sin(angle)) * width * 0.5
	made.tri(base - side, base + side, tip, col)
	made.tri(base + side, base - side, tip, tone(col, 0.92))


## A hand-built block: corners jittered by `rough`, the top `taper`ed and
## leaning `lean` toward +x. Walls, chimneys, slabs, planks.
func slab(cx: float, y0: float, cz: float, w: float, h: float, d: float, seed_value: int, col: Color, top_col: Color = Color(0, 0, 0, 0), rough: float = 0.03, taper: float = 0.0, lean: float = 0.0) -> void:
	var p: Array[Vector3] = []
	for i in 8:
		var sx := -0.5 if (i & 1) == 0 else 0.5
		var sy := 0.0 if (i & 2) == 0 else 1.0
		var sz := -0.5 if (i & 4) == 0 else 0.5
		var shrink := 1.0 - taper * sy
		p.append(Vector3(cx + sx * w * shrink + j(seed_value, i * 3, rough) + lean * sy * h, y0 + sy * h + (j(seed_value, i * 3 + 2, rough) if sy > 0.0 else 0.0), cz + sz * d * shrink + j(seed_value, i * 3 + 1, rough)))
	var tc := col if top_col.a == 0.0 else top_col
	made.quad(p[2], p[6], p[7], p[3], tc)
	made.quad(p[4], p[5], p[7], p[6], col)
	made.quad(p[1], p[0], p[2], p[3], tone(col, 0.97))
	made.quad(p[5], p[1], p[3], p[7], tone(col, 0.98))
	made.quad(p[0], p[4], p[6], p[2], col)


## A wall face as a quad on a plane, a hair proud of it: doors, windows, marks.
func face(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	made.quad(a, b, c, d, col)


## A sagging line from a to b as n pieces: rope, wire, fishing line (MADE).
func sag(a: Vector3, b: Vector3, dip: float, n: int, thick: float, col: Color) -> void:
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t) + Vector3.DOWN * dip * 4.0 * t * (1.0 - t)
		made.strut(prev, p, thick, 3, col)
		prev = p


# --- FOUND shapes ------------------------------------------------------------

## An exact post or tube between a and b, n-sided, no taper.
func rod(a: Vector3, b: Vector3, r: float, sides: int, col: Color) -> void:
	found.strut(a, b, r, sides, col)


## An exact block with chamfered corners, centred on (cx, cz), standing on y0.
## Eight sides, so it never reads as a box.
func chamfer(cx: float, y0: float, cz: float, w: float, h: float, d: float, cut: float, col: Color, top_col: Color = Color(0, 0, 0, 0)) -> void:
	var tc := col if top_col.a == 0.0 else top_col
	var hw := w * 0.5
	var hd := d * 0.5
	var pts: Array[Vector2] = [Vector2(hw - cut, -hd), Vector2(hw, -hd + cut), Vector2(hw, hd - cut), Vector2(hw - cut, hd),
		Vector2(-hw + cut, hd), Vector2(-hw, hd - cut), Vector2(-hw, -hd + cut), Vector2(-hw + cut, -hd)]
	var y1 := y0 + h
	var inset := minf(cut, h * 0.3)
	for i in 8:
		var a := pts[i]
		var b := pts[(i + 1) % 8]
		found.quad(Vector3(cx + b.x, y0, cz + b.y), Vector3(cx + a.x, y0, cz + a.y), Vector3(cx + a.x, y1 - inset, cz + a.y), Vector3(cx + b.x, y1 - inset, cz + b.y), col)
		# A bevel round the top edge.
		var ai := a * (1.0 - inset / maxf(hw, hd))
		var bi := b * (1.0 - inset / maxf(hw, hd))
		found.quad(Vector3(cx + b.x, y1 - inset, cz + b.y), Vector3(cx + a.x, y1 - inset, cz + a.y), Vector3(cx + ai.x, y1, cz + ai.y), Vector3(cx + bi.x, y1, cz + bi.y), tone(col, 1.08))
	var centre := Vector3(cx, y1, cz)
	for i in 8:
		var a := pts[i] * (1.0 - inset / maxf(hw, hd))
		var b := pts[(i + 1) % 8] * (1.0 - inset / maxf(hw, hd))
		found.tri(centre, Vector3(cx + b.x, y1, cz + b.y), Vector3(cx + a.x, y1, cz + a.y), tc)


## A flat exact panel on the plane of quad (a, b, c, d), with a darker rim and
## rivets at its corners: plate taken off a machine.
func plate(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, rim: Color, rivet: Color) -> void:
	var n := (c - b).cross(a - b).normalized() * 0.006
	found.quad(a + n, b + n, c + n, d + n, rim)
	var centre := (a + b + c + d) * 0.25
	var k := 0.86
	var ai := centre.lerp(a, k) + n * 2.0
	var bi := centre.lerp(b, k) + n * 2.0
	var ci := centre.lerp(c, k) + n * 2.0
	var di := centre.lerp(d, k) + n * 2.0
	found.quad(ai, bi, ci, di, col)
	var u := (b - a).normalized() * 0.014
	var v := (d - a).normalized() * 0.014
	for p: Vector3 in [ai, bi, ci, di]:
		var q := centre.lerp(p, 0.88) + n * 3.0
		found.quad(q - u - v, q + u - v, q + u + v, q - u + v, rivet)


## A cable from a to b hanging `dip` at its middle (FOUND: the grid's).
func cable(a: Vector3, b: Vector3, dip: float, n: int, thick: float, col: Color) -> void:
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t) + Vector3.DOWN * dip * 4.0 * t * (1.0 - t)
		found.strut(prev, p, thick, 3, col)
		prev = p


## A ring of exact struts: hoops, coils, flanges.
func hoop(c: Vector3, r: float, n: int, thick: float, col: Color, axis: Vector3 = Vector3.UP) -> void:
	var ax := axis.normalized()
	var u := ax.cross(Vector3.FORWARD if absf(ax.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var v := ax.cross(u)
	for i in n:
		var a0 := float(i) / n * TAU
		var a1 := float(i + 1) / n * TAU
		found.strut(c + (u * cos(a0) + v * sin(a0)) * r, c + (u * cos(a1) + v * sin(a1)) * r, thick, 4, col)


## Set the sway of every MADE vertex from index `start` by height: 0 at or
## below y0, `w` at y1 and above. Keeps bases planted while tips move.
## `pen` is the kit the range is in: `leaf` for a canopy's cards.
func sway_by_height(start: int, y0: float, y1: float, w: float, pen: MeshKit = null) -> void:
	var k := made if pen == null else pen
	for i in range(start, k.vertex_count()):
		var y := k.verts[i].y
		var t := clampf((y - y0) / maxf(y1 - y0, 1e-4), 0.0, 1.0)
		# Never exactly 0: a zero weight would read as rigid, patchy geometry.
		k.uv2s[i] = Vector2(maxf(w * t, 0.0001), k.uv2s[i].y)


# --- LEAVES -------------------------------------------------------------------
#
# WHY CARDS. Foliage is many small surfaces at many angles, and that is the whole
# of how it reads under a real sun: each leaf turns its own way, so the light
# breaks into dapple -- lit leaves, leaves in their neighbours' shade, a dark
# gap, sky through the rim -- where a solid of the same outline shades like ONE
# surface. The lobed clump was that solid, and the crease pass could only choose
# which way it failed: faceted it was a cut green gem, smoothed it was a green
# dome, which is a boulder painted green, and lobed it was a compromise found by
# eye between a starfish and a crystal (the geometry package said so, and said
# "foliage really wants leaf cards"). So a crown is now a cloud of small cards
# on a shell, each a sprig cut out by its shader.
#
# THE ONE TRICK THAT MAKES CARDS READ AS A MASS. A card's own face normal alone
# gives noise: sixty random facets, sixty random values. So every card carries
# TWO normals and the shader blends them: the vertex NORMAL written here is the
# CROWN's -- the outward normal of the ellipsoid the card sits on, so the sunny
# side of the tree is sunny and the far side is in shade -- and the card's own
# face is found in the fragment. The blend is volume plus dapple.
#
# What a card also carries, and where:
#   COLOR.rgb  the leaf's wash, toned darker the deeper into the crown it sits,
#              because the inside of a canopy is in its own shade (baked AO)
#   COLOR.a    which sprig the shader cuts (LEAF_*) / 255
#   UV         card coordinates, 0..1, the stem at v = 0 and the tip at v = 1
#   UV2        (sway weight, phase) exactly as MADE carries them; the phase is
#              also the card's seed, so no two sprigs are cut alike

## The sprigs leaf.gdshader cuts. Kept in step with its LEAF_* consts, which
## tests/render/test_foliage.gd reads out of the shader.
const LEAF_BROAD := 1
const LEAF_SMALL := 2
const LEAF_NEEDLE := 3
const LEAF_SPINE := 4

## The golden angle, so cards spread over a shell without a pole or a seam.
const _GOLDEN := 2.39996323


## A cloud of leaf cards on the upper part of an ellipsoid shell standing on
## (cx, y0, cz): `r` wide, `h` tall, as `clump` takes them, so a builder swaps
## one call for the other. `cols` is the landscape's own leaf palette and is
## dealt per card. `size` is a card's edge in tiles; `count` how many cards.
##
## Deterministic from `seed_value` and nothing else. Cards are emitted OUTER AND
## UPPER FIRST: inside one draw a GPU with no depth prepass (Compatibility, the
## web) shades triangles in order, so a card that a nearer one will cover must
## come later, where the depth test throws it away unshaded.
func canopy(cx: float, y0: float, cz: float, r: float, h: float, seed_value: int, cols: Array[Color],
		shape: int = LEAF_BROAD, size: float = 0.26, count: int = 28) -> void:
	var centre := Vector3(cx, y0 + h * 0.46, cz)
	var radii := Vector3(r, h * 0.54, r)
	var inv2 := Vector3(1.0 / (radii.x * radii.x), 1.0 / (radii.y * radii.y), 1.0 / (radii.z * radii.z))
	var spin := Rng.hash01(seed_value, 71) * TAU
	var cards: Array[Array] = []
	for i in count:
		# Fibonacci over the shell from the crown down to a little under the
		# middle: the camera never sees under a canopy, and a card there would be
		# paid for in the shadow pass and the prepass for nothing.
		var fy := 1.0 - (float(i) + 0.5) / float(count) * 1.32 + j(seed_value, i * 3 + 1, 0.05)
		fy = clampf(fy, -0.4, 0.98)
		var ring := sqrt(maxf(0.0, 1.0 - fy * fy))
		var a := spin + float(i) * _GOLDEN + j(seed_value, i * 3 + 2, 0.35)
		var dir := Vector3(cos(a) * ring, fy, sin(a) * ring)
		# Most cards on the skin, some sunk into the crown: the sunk ones are
		# what the gaps between the outer ones show, in the crown's own shade.
		var sink := Rng.hash01(seed_value, i, 72)
		var depth := 1.0 - 0.5 * sink * sink
		var p := centre + dir * radii * depth
		var out := ((p - centre) * inv2).normalized()
		# The card turns well off the shell's own facing: that difference is the
		# dapple. Never so far that a card is seen edge-on from above as a line.
		var tilt := Vector3(Rng.hash01(seed_value, i, 73) - 0.5, Rng.hash01(seed_value, i, 74) - 0.5, Rng.hash01(seed_value, i, 75) - 0.5)
		var face := (out + tilt * 1.7 + Vector3(0, 0.35, 0)).normalized()
		var ref := Vector3.UP if absf(face.y) < 0.92 else Vector3.RIGHT
		var t1 := face.cross(ref).normalized()
		var t2 := face.cross(t1)
		var turn := Rng.hash01(seed_value, i, 76) * TAU
		var up := (t1 * cos(turn) + t2 * sin(turn)).normalized()
		var side := up.cross(face).normalized()
		var s := size * (0.78 + Rng.hash01(seed_value, i, 77) * 0.44)
		# The deeper a card sits and the lower on the crown, the less light
		# reaches it: the inside of a canopy is its own shade.
		var shade := lerpf(0.58, 1.0, smoothstep(0.5, 1.0, depth)) * (0.9 + 0.13 * clampf(dir.y, -1.0, 1.0))
		var col := cols[int(Rng.hash01(seed_value, i, 78) * cols.size()) % cols.size()]
		col = tone(col, shade * (0.92 + Rng.hash01(seed_value, i, 79) * 0.16))
		cards.append([depth + dir.y * 0.35, p, up, side, s, col, Rng.hash01(seed_value, i, 80)])
	cards.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	for cd: Array in cards:
		_card(cd[1], cd[2], cd[3], cd[4], cd[5], shape, cd[6], centre, inv2)


## Needle sprays round one conifer tier (see `tier`, which takes the same
## numbers): one and a half to a point, each a card leaving the trunk inside the
## tier and reaching past its rim as it droops, and half a point more, shorter
## and higher, laid on the tier's upper face. Two to a point was measured at 221
## thousand triangles of leaves across every pass in the canon's pinewood frame,
## against 131 thousand for the solid tiers, and looked no better than this. The spray is what reaches the light;
## the tier under it is the bough's own shade.
func sprays(cx: float, y_rim: float, cz: float, r: float, rise: float, droop: float, points: int,
		seed_value: int, cols: Array[Color], shape: int = LEAF_NEEDLE) -> void:
	# The crown normal of a tier is a cone's: out from the trunk and up.
	var centre := Vector3(cx, y_rim - droop - rise * 0.2, cz)
	var inv2 := Vector3(1.0 / (r * r), 1.0 / maxf(rise * rise, 0.04), 1.0 / (r * r))
	var rot := Rng.hash01(seed_value, 81) * TAU
	var outer := points + points / 2
	var inner := maxi(3, points / 2)
	for i in outer + inner:
		var high := i >= outer
		var n := inner if high else outer
		var a := rot + float(i) / float(n) * TAU + j(seed_value, i, 0.22) + (0.5 if high else 0.0)
		var out := Vector3(cos(a), 0.0, sin(a))
		var reach := r * ((0.62 if high else 1.02) + Rng.hash01(seed_value, i, 82) * 0.22)
		var lift := rise * (0.38 if high else 0.06)
		var from := Vector3(cx, y_rim + lift + droop * 0.2, cz) + out * r * (0.12 if high else 0.3)
		var to := Vector3(cx, y_rim + lift * 0.5 - droop * (0.7 + Rng.hash01(seed_value, i, 83) * 0.5), cz) + out * reach
		var along := to - from
		var length := along.length()
		var dir := along / length
		# Laid flat across the bough, turned a little on its own axis, so from
		# above a spray is seen as a spray and never edge-on as a line.
		var side := out.cross(Vector3.UP).normalized()
		var twist := j(seed_value, i + 40, 0.45)
		side = (side * cos(twist) + dir.cross(side) * sin(twist)).normalized()
		var col := tone(cols[int(Rng.hash01(seed_value, i, 84) * cols.size()) % cols.size()], 0.9 + Rng.hash01(seed_value, i, 85) * 0.2)
		if high:
			col = tone(col, 1.06)
		_card(from + dir * length * 0.5, dir, side, length, col, shape, Rng.hash01(seed_value, i, 86), centre, inv2)


## One card: centred on `p`, stem to tip along `up`, `s` on an edge. Its vertex
## normals are the crown's (see the block above), taken at each corner so the
## light turns smoothly across the whole mass.
func _card(p: Vector3, up: Vector3, side: Vector3, s: float, col: Color, shape: int, phase: float,
		centre: Vector3, inv2: Vector3) -> void:
	var half := s * 0.5
	var corners: Array[Vector3] = [p - up * half - side * half, p - up * half + side * half,
		p + up * half + side * half, p + up * half - side * half]
	var uv: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var c := Color(col.r, col.g, col.b, shape / 255.0)
	for idx: int in [0, 1, 2, 0, 2, 3]:
		var v := corners[idx]
		# A little lift toward the sky in the crown normal: a canopy is lit from
		# above far more than an ellipsoid of its size would be, because its
		# leaves turn to the light.
		var n := ((v - centre) * inv2).normalized()
		leaf.verts.append(v)
		leaf.normals.append((n + Vector3(0, 0.3, 0)).normalized())
		leaf.colors.append(c)
		leaf.uvs.append(uv[idx])
		leaf.uv2s.append(Vector2(0.0001, phase))
		leaf.custom0.append_array([0.0, 0.0, 0.0, 0.0])
