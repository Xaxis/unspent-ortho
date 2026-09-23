extends RefCounted
## What stands on the Glass Desert (docs/LANDSCAPES.md). Everything here is
## either older than the glassing or was caught in it, and three of the four
## are the same material: the sand, fused. A fulgurite is a strike's own cast in
## the drift; a blister is where a gas pocket rose through the sheet as it
## cooled and burst; a car is a car that was standing there. The fourth is the
## plan's, and the only one that was MADE: a strike rod, ruled copper and steel
## on a guyed foot, one of a field the plan draws the dry storms down into.
##
## Nothing here is a cube, and the glass is GLASS: every fused surface carries
## `GroundColors.GLASS` (matter row 86) in its alpha, on the MADE pen, so it is
## lit as a pane is — low roughness, a real specular return — and nothing has
## to be painted shiny. The two lit shaders read alpha for different things,
## and only `made` reads it as a material: `Kit.rod`, `chamfer`, `plate`,
## `cable` and `hoop` build into FOUND, where the same alpha is a lamp, so a
## glass colour is never handed to one of those five (props/kit.gd's header).
##
## The one lamp on the landscape is the rod's tip, and it is on the FOUND pen
## on purpose: `TIP` is the machines' cold strip on the beacon's alpha, so it
## blinks on the machine beat in the plan's own cold. `PropModels.glow_points`
## reads the same constant, so the light and the thing casting it cannot
## disagree.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
const Works := preload("res://src/models/props/works.gd")
const Remains := preload("res://src/models/props/remains.gd")

## The rod's tip: `Works.STRIP`'s colour at `Works.BEACON`'s alpha, the FOUND
## light code that blinks (found.gdshader, under 0.5). A literal, because a
## const cannot be composed from two others' fields; the numbers are the two
## works.gd writes, and tests/models/test_glass_desert.gd holds them to it.
const TIP := Color(0.7451, 0.7294, 0.8745, 0.36)
## Where the tip is, in the rod's own frame, for the glow point.
const TIP_AT := Vector3(0.0, 4.7, 0.0)


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.FULGURITE: fulgurite(k, v, c)
		PropKind.GLASS_BLISTER: blister(k, v, c)
		PropKind.FUSED_CAR: fused_car(k, v, c)
		PropKind.STRIKE_ROD: strike_rod(k, v, c)


# --- the glass, as colours -------------------------------------------------------

## A colour as glass: the GLASS row in its alpha. Tagged at the point of use and
## never on a shared colour, because a `lerp` moves alpha and a tagged colour
## on the FOUND pen is a lamp.
static func _glass(col: Color) -> Color:
	return GroundColors.made(col, GroundColors.GLASS)


## The sheet itself, green-black: the landscape's own rock wash, deeper.
static func _dark() -> Color:
	return P.SPRUCE[1].lerp(P.SLATE[1], 0.4)


## Where the glass thins, light gets into it: the translucent edge.
static func _edge() -> Color:
	return P.SPRUCE[3].lerp(P.RIME[4], 0.45)


## Fused sand, `pale` 0..1: a tube is the drift it was struck in, gone to glass.
static func _fused(pale: float) -> Color:
	return P.SAND[2].lerp(P.LINEN[4], pale)


## A quad wound so its front faces `out`. Both lit shaders cull the back face,
## and a face wound the wrong way is invisible from every bearing without an
## error anywhere (tests/render/test_found_drawn.gd), so nothing here relies
## on remembering which corner comes first.
static func _q(pen: MeshKit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, out: Vector3) -> void:
	if (b - a).cross(c - a).dot(out) < 0.0:
		pen.quad(d, c, b, a, col)
	else:
		pen.quad(a, b, c, d, col)


static func _t(pen: MeshKit, a: Vector3, b: Vector3, c: Vector3, col: Color, out: Vector3) -> void:
	if (b - a).cross(c - a).dot(out) < 0.0:
		pen.tri(a, c, b, col)
	else:
		pen.tri(a, b, c, col)


# --- fulgurite -----------------------------------------------------------------

## A cluster of branching fused-sand tubes standing up out of the drift like
## dead coral: five to seven tubes off one fused root, each leaning its own way,
## with a branch or two going out and up. 0.8 high, half a tile wide. Broken
## for the tubes (Takes), it is worked down by `Broken` and then gone, leaving
## rubble (RemnantModels), because a fulgurite is carried off whole.
static func fulgurite(k: Kit, v: int, c: int) -> void:
	var s := 41000 + v * 23 + c * 3
	var root := _glass(_fused(0.15))
	var tube := _glass(_fused(0.45))
	var tip := _glass(_fused(0.75))
	# The root: the drift fused round the strike's foot, half sunk.
	k.stone(0.0, -0.06, 0.0, 0.22 + v * 0.03, 0.1, s, root, 7)
	var count := 5 + v
	for i in count:
		var a := Rng.hash01(s, i, 1) * TAU
		var r0 := 0.15 * Rng.hash01(s, i, 2)
		var foot := Vector3(cos(a) * r0, 0.0, sin(a) * r0)
		var h := 0.34 + Rng.hash01(s, i, 3) * 0.44
		var lean := Vector3(cos(a), 0.0, sin(a)) * (0.06 + Rng.hash01(s, i, 4) * 0.14)
		var top := foot + Vector3(0, h, 0) + lean
		var bend := Vector3(-lean.z, 0.0, lean.x) * (Rng.hash01(s, i, 5) - 0.5) * 0.3
		var rad := 0.032 + Rng.hash01(s, i, 6) * 0.03
		k.limb(foot, top, rad, rad * 0.4, 6, tube, bend)
		# A branch or two off each tube, going out and up: the coral in it.
		var branches := 1 + int(Rng.hash01(s, i, 7) * 2.0)
		for j in branches:
			var t := 0.4 + Rng.hash01(s, i, 8 + j) * 0.4
			var at := foot.lerp(top, t) + bend * 4.0 * t * (1.0 - t)
			var ba := a + (Rng.hash01(s, i, 11 + j) - 0.5) * 2.6
			var bl := 0.1 + Rng.hash01(s, i, 14 + j) * 0.18
			var end := at + Vector3(cos(ba) * bl, bl * 0.9, sin(ba) * bl)
			k.limb(at, end, rad * 0.55, 0.012, 5, tip)


# --- glass blister -------------------------------------------------------------

## A burst dome of glass where a gas pocket rose as the sheet cooled: a tile
## and three quarters across, its edge shattered into standing shards, black
## inside. One side is broken open, and that is where a body steps in out of
## the sun (52_hazards ROOFS): the opening faces +X on 0 and the far side on
## 1, so two in one frame do not face the same way.
static func blister(k: Kit, v: int, c: int) -> void:
	var s := 41100 + v * 29 + c
	var R := 0.9
	var segs := 14
	var heights: Array[float] = [0.0, 0.3, 0.54, 0.68]
	var shares: Array[float] = [1.0, 0.88, 0.62, 0.3]
	var open_at := 0.0 if v == 0 else PI * 0.5 + 0.4
	var open_half := 1.0
	var dark := _dark()
	var edge := _edge()
	var inside := _glass(P.INK[1])
	# Each ring jittered by segment: a burst thing is not a compass drawing.
	var pt := func(i: int, b: int) -> Vector3:
		var a := float(i) / segs * TAU
		var rj := 1.0 + (Rng.hash01(s, i % segs, 40 + b) - 0.5) * 0.12
		var r := R * shares[b] * rj
		var y := heights[b] + (Rng.hash01(s, i % segs, 50 + b) - 0.5) * 0.04 * b
		return Vector3(cos(a) * r, y, sin(a) * r)
	var bands: Array[Color] = [_glass(dark), _glass(dark.lerp(edge, 0.45)), _glass(edge)]
	for b in 3:
		for i in segs:
			var mid := (float(i) + 0.5) / segs * TAU
			# The burst narrows as it rises: wide at the rim, nearly closed by the cap.
			if absf(wrapf(mid - open_at, -PI, PI)) < open_half * (1.0 - 0.28 * b):
				continue
			var p0: Vector3 = pt.call(i, b)
			var p1: Vector3 = pt.call(i + 1, b)
			var p2: Vector3 = pt.call(i + 1, b + 1)
			var p3: Vector3 = pt.call(i, b + 1)
			var out := Vector3(cos(mid), 0.6, sin(mid))
			_q(k.made, p0, p1, p2, p3, bands[b], out)
			_q(k.made, p0, p1, p2, p3, inside, -out)
	# The cap: a fan to an apex off centre, thin enough that light gets in.
	var apex := Vector3(0.03, 0.72, -0.04)
	for i in segs:
		var mid := (float(i) + 0.5) / segs * TAU
		if absf(wrapf(mid - open_at, -PI, PI)) < open_half * 0.16:
			continue
		_t(k.made, pt.call(i, 3), pt.call(i + 1, 3), apex, bands[2], Vector3.UP)
		_t(k.made, pt.call(i, 3), pt.call(i + 1, 3), apex, inside, Vector3.DOWN)
	# The floor inside, seen through the burst: black glass.
	k.made.prism(0.0, -0.02, 0.0, R * 0.92, 0.02, R * 0.92, segs, inside)
	# Shards standing up round the rim, thickest and tallest at the lip of the burst.
	for i in segs:
		var a := float(i) / segs * TAU
		var at_lip := absf(wrapf(a - open_at, -PI, PI)) < open_half + 0.3
		var n := 2 if at_lip else 1
		for j in n:
			var aa := a + (Rng.hash01(s, i, 60 + j) - 0.5) * (TAU / segs)
			var r := R * (1.0 + (Rng.hash01(s, i, 70 + j) - 0.5) * 0.1)
			var base := Vector3(cos(aa) * r, 0.0, sin(aa) * r)
			var h := 0.1 + Rng.hash01(s, i, 80 + j) * (0.28 if at_lip else 0.14)
			var top := base + Vector3(cos(aa) * 0.08, h, sin(aa) * 0.08)
			k.blade(base, top, 0.1 + Rng.hash01(s, i, 90 + j) * 0.08, aa + PI * 0.5, _glass(edge))
	# And lying in the sand round it, where the burst threw them.
	for i in 9:
		var a := Rng.hash01(s, i, 100) * TAU
		var r := R + 0.15 + Rng.hash01(s, i, 101) * 0.5
		var p := Vector3(cos(a) * r, 0.01, sin(a) * r)
		var d := Vector3(cos(a + 1.0), 0.0, sin(a + 1.0)) * (0.08 + Rng.hash01(s, i, 102) * 0.08)
		var e := Vector3(cos(a + 2.4), 0.0, sin(a + 2.4)) * 0.06
		k.fleck(p, p + d, p + e, _glass(dark) if i % 2 == 0 else _glass(edge))


# --- fused car -------------------------------------------------------------------

## A vehicle caught in the glassing, sunk to its sills in a pool of glass, one
## side melted smooth. The body is FOUND plate — this is the one prop here that
## was steel — but what the heat did to it is drawn by the hand: the whole of
## the flank that faced the strike slumps off the roof edge into the pool as
## one glazed drape, and the pool it stands in is the sheet itself. 0 is a
## saloon melted on its left; 1 a van melted on its right, so a crater's three
## do not read as one car stamped three times. The intact flank keeps a door
## panel, its rust and its wheel arch, so the two sides say which way the
## strike came from.
static func fused_car(k: Kit, v: int, c: int) -> void:
	var s := 41200 + v * 31 + c * 7
	var melt := -1.0 if v == 0 else 1.0
	var van := v == 1
	var L := 1.9
	var W := 0.88
	var belt := 0.34
	var cab_y := 0.42
	var roof := 0.84 if van else 0.72
	var cab_x0 := -1.45 if van else -0.95
	var cab_x1 := 0.85 if van else 0.8
	var paint := P.SLATE[2].lerp(P.RUST[2], 0.3)
	var lower := GroundColors.down(paint, 0.2)
	var top := GroundColors.up(paint, 0.12)
	var hole := P.INK[1]
	var f := k.found
	# 1. The sill band: found walls from the pool to the belt, all round but the
	# flank that melted, which the drape below replaces.
	var plan := _rounded(L, W, 0.3)
	var n := plan.size()
	for i in n:
		var a := plan[i]
		var b := plan[(i + 1) % n]
		var mx := (a.x + b.x) * 0.5
		var mz := (a.y + b.y) * 0.5
		if mz * melt > 0.35 and absf(mx) < L - 0.4:
			continue
		var out := Vector3(mx / L, 0.0, mz / W)
		_q(f, Vector3(a.x, 0.0, a.y), Vector3(b.x, 0.0, b.y), Vector3(b.x, belt, b.y), Vector3(a.x, belt, a.y), paint, out)
	# 2. The deck: the boot sloping up to the cabin, the bonnet from the cabin to
	# the engine bay, and the bay itself OPEN — the bonnet torn up at the nose
	# and standing off it. The bay's floor lies under the sill rim with nothing
	# over it, because a hole drawn under a deck is a hole nobody has seen
	# (tests/render/test_found_drawn.gd caught the first cut of this).
	var hw := W - 0.05
	var bay := L - 0.78
	_q(f, Vector3(bay, belt, -hw), Vector3(bay, belt, hw), Vector3(cab_x1, cab_y, hw), Vector3(cab_x1, cab_y, -hw), top, Vector3(0.2, 1.0, 0.0))
	_q(f, Vector3(cab_x0, cab_y, -hw), Vector3(cab_x0, cab_y, hw), Vector3(-L + 0.12, belt, hw), Vector3(-L + 0.12, belt, -hw), top, Vector3(-0.2, 1.0, 0.0))
	_q(f, Vector3(bay, belt - 0.05, -hw + 0.04), Vector3(bay, belt - 0.05, hw - 0.04), Vector3(L - 0.15, belt - 0.05, hw - 0.04), Vector3(L - 0.15, belt - 0.05, -hw + 0.04), hole, Vector3.UP)
	_q(f, Vector3(bay + 0.02, belt + 0.03, -0.36), Vector3(bay + 0.02, belt + 0.03, 0.26), Vector3(L - 0.22, belt + 0.3, 0.3), Vector3(L - 0.22, belt + 0.3, -0.32), lower, Vector3(-0.5, 1.0, 0.0))
	# 3. The cabin: pillars, the glass gone to black holes, and a roof caved
	# along its middle.
	var cw := W - 0.12
	for sx: float in [cab_x0, cab_x1]:
		for sz: float in [-cw, cw]:
			k.rod(Vector3(sx, cab_y, sz), Vector3(sx, roof, sz), 0.03, 4, lower)
	var iz := -melt * cw
	k.rod(Vector3((cab_x0 + cab_x1) * 0.5, cab_y, iz), Vector3((cab_x0 + cab_x1) * 0.5, roof, iz), 0.03, 4, lower)
	var wy0 := cab_y + 0.02
	var wy1 := roof - 0.05
	_q(f, Vector3(cab_x1, wy0, -cw), Vector3(cab_x1, wy0, cw), Vector3(cab_x1 - 0.08, wy1, cw), Vector3(cab_x1 - 0.08, wy1, -cw), hole, Vector3.RIGHT)
	_q(f, Vector3(cab_x0, wy0, -cw), Vector3(cab_x0, wy0, cw), Vector3(cab_x0 + 0.05, wy1, cw), Vector3(cab_x0 + 0.05, wy1, -cw), hole, Vector3.LEFT)
	_q(f, Vector3(cab_x0, wy0, iz), Vector3(cab_x1, wy0, iz), Vector3(cab_x1, wy1, iz), Vector3(cab_x0, wy1, iz), hole, Vector3(0.0, 0.0, -melt))
	var mid_x := (cab_x0 + cab_x1) * 0.5
	var dent := roof - 0.1
	_q(f, Vector3(cab_x0, roof, -cw), Vector3(mid_x, dent, -cw), Vector3(mid_x, dent, cw), Vector3(cab_x0, roof, cw), top, Vector3(0.3, 1.0, 0.0))
	_q(f, Vector3(mid_x, dent, -cw), Vector3(cab_x1, roof, -cw), Vector3(cab_x1, roof, cw), Vector3(mid_x, dent, cw), top, Vector3(-0.3, 1.0, 0.0))
	# 4. The intact flank: a door panel of plate, its arch, and rust down from
	# the window sill. Wound by hand for the side it is on.
	var pz := -melt * (W + 0.006)
	var pa := Vector3(-0.6, 0.06, pz)
	var pb := Vector3(0.5, 0.06, pz)
	var pc := Vector3(0.5, belt - 0.04, pz)
	var pd := Vector3(-0.6, belt - 0.04, pz)
	if melt < 0.0:
		k.plate(pa, pb, pc, pd, paint, lower, P.PLATE[5])
	else:
		k.plate(pb, pa, pd, pc, paint, lower, P.PLATE[5])
	for ax: float in [L - 0.75, -L + 0.75]:
		_q(f, Vector3(ax - 0.3, 0.0, pz), Vector3(ax + 0.3, 0.0, pz), Vector3(ax + 0.2, 0.2, pz), Vector3(ax - 0.2, 0.2, pz), hole, Vector3(0.0, 0.0, -melt))
	Works.run(k, Vector3(-0.15, belt - 0.02, pz), 0.3, 0.26, Vector3(0.0, 0.0, -melt))
	# 5. The melted flank: paint and glass slumped off the roof edge in one
	# drape into the pool, by the hand, glazed. Each column its own sag.
	var cols := 7
	var drape_top := _glass(paint.lerp(P.SPRUCE[1], 0.35))
	var drape_mid := _glass(paint.lerp(_dark(), 0.7))
	var drape_low := _glass(_dark())
	var prev: Array[Vector3] = []
	for j in cols + 1:
		var t := float(j) / cols
		var x := lerpf(-L + 0.35, L - 0.35, t)
		var top_y := roof - 0.02 if (x > cab_x0 and x < cab_x1) else belt
		var jit := (Rng.hash01(s, j, 3) - 0.5) * 0.2
		var col_pts: Array[Vector3] = [
			Vector3(x, top_y, melt * (W - 0.12)),
			Vector3(x, belt * 0.8, melt * (W + 0.12 + jit * 0.3)),
			Vector3(x, 0.14, melt * (W + 0.45 + jit)),
			Vector3(x, 0.02, melt * (W + 0.85 + jit * 1.5)),
		]
		if j > 0:
			var shades: Array[Color] = [drape_top, drape_mid, drape_low]
			for r in 3:
				_q(k.made, prev[r], prev[r + 1], col_pts[r + 1], col_pts[r], shades[r], Vector3(0.0, 0.5, melt))
		prev = col_pts
	for j in 3:
		var x := lerpf(-1.0, 1.2, float(j) / 2.0) + (Rng.hash01(s, j, 9) - 0.5) * 0.3
		k.limb(Vector3(x, belt * 0.75, melt * (W + 0.2)), Vector3(x + 0.05, 0.03, melt * (W + 0.6)), 0.04, 0.015, 5, drape_low, Vector3(0.0, -0.06, melt * 0.05))
	# 6. The pool it stands in: the sheet, spread toward the side that melted.
	# SCOURED, NOT GLAZED: this was tagged GLASS like the drape, and in the
	# gallery frame the pool came back as a five-unit white hole with the car
	# sitting in it — a flat welded plate at the GLASS row's specular returns
	# the noon sun straight into the lens, which is what that row's own comment
	# warns a pane will do. The domes and the tubes are curved, so their
	# highlights stay small; a pool is not. And a pool the wind has sand-blasted
	# for seventy years IS matte: the landscape's file says a shine survives
	# only on what has not been scoured. So the sheet takes the plain made row.
	k.stone(melt * 0.3, -0.05, melt * 0.35, 2.4, 0.07, s, _dark(), 9)
	# 7. Sand banked against the intact side and the nose.
	Remains.banks(k, [[L * 0.75, -melt * (W + 0.35), 0.5, 0.14], [-L * 0.6, -melt * (W + 0.3), 0.42, 0.1]], Remains.drift_of(c)[0], s)


## A rounded rectangle in plan (x along, y across), `n` corner steps a side,
## run counterclockwise seen from above.
static func _rounded(hl: float, hw: float, r: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var corners: Array[Vector2] = [Vector2(hl - r, hw - r), Vector2(-hl + r, hw - r), Vector2(-hl + r, -hw + r), Vector2(hl - r, -hw + r)]
	for ci in 4:
		var c := corners[ci]
		for j in 3:
			var a := ci * PI * 0.5 + float(j) / 2.0 * PI * 0.5
			out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


# --- strike rod --------------------------------------------------------------------

## A ruled copper-and-steel mast on a guyed foot, five units to the point: one
## of a field the plan calls the dry storms down into. Steel to the collar the
## guys tie to, copper above it, and the tip lit cold and blinking on the
## machine beat. At its foot, the crop: one fused tube where a strike already
## came down, and the drift banked against the block.
static func strike_rod(k: Kit, v: int, c: int) -> void:
	var s := 41300 + v + c
	var f := k.found
	k.chamfer(0.0, -0.06, 0.0, 0.52, 0.16, 0.52, 0.09, P.PLATE[2], P.PLATE[3])
	# The field's number, on a plate on the block.
	k.plate(Vector3(0.261, 0.02, 0.14), Vector3(0.261, 0.02, -0.14), Vector3(0.261, 0.09, -0.14), Vector3(0.261, 0.09, 0.14), P.PLATE[3], P.PLATE[1], P.PLATE[5])
	k.rod(Vector3(0.0, 0.08, 0.0), Vector3(0.0, 3.9, 0.0), 0.05, 6, P.PLATE[3])
	f.prism(0.0, 1.95, 0.0, 0.085, 2.12, 0.085, 6, P.PLATE[4], P.PLATE[3])
	f.prism(0.0, 3.86, 0.0, 0.07, 3.98, 0.06, 6, P.PLATE[4])
	k.rod(Vector3(0.0, 3.98, 0.0), Vector3(0.0, 4.62, 0.0), 0.04, 6, P.COPPER[2])
	f.prism(0.0, 4.62, 0.0, 0.055, 4.78, 0.05, 6, TIP)
	f.prism(0.0, 4.78, 0.0, 0.038, 5.0, 0.0, 6, P.COPPER[3])
	# Graduations up the mast: the field was ruled, and its rods say so.
	for i in 6:
		var y := 0.5 + float(i) * 0.55
		f.quad(Vector3(0.052, y, 0.02), Vector3(0.052, y, -0.02), Vector3(0.052, y + 0.012, -0.02), Vector3(0.052, y + 0.012, 0.02), P.PLATE[5])
	# Three guys from the collar to anchor blocks a tile out.
	for i in 3:
		var a := float(i) / 3.0 * TAU + PI / 6.0
		var anchor := Vector3(cos(a) * 1.05, 0.0, sin(a) * 1.05)
		k.chamfer(anchor.x, -0.05, anchor.z, 0.18, 0.12, 0.18, 0.03, P.PLATE[2], P.PLATE[3])
		k.cable(Vector3(cos(a) * 0.09, 2.08, sin(a) * 0.09), anchor + Vector3(0.0, 0.07, 0.0), 0.03, 4, 0.012, P.PLATE[2])
	Works.run(k, Vector3(0.052, 1.9, 0.0), 0.08, 0.5, Vector3.RIGHT)
	Works.run(k, Vector3(0.262, 0.1, 0.06), 0.12, 0.12, Vector3.RIGHT)
	# A strike that already came down: the field's crop, at the foot.
	k.limb(Vector3(0.3, 0.0, 0.32), Vector3(0.36, 0.28, 0.38), 0.03, 0.012, 5, _glass(_fused(0.4)))
	k.limb(Vector3(0.3, 0.0, 0.32), Vector3(0.22, 0.2, 0.42), 0.022, 0.01, 5, _glass(_fused(0.7)))
	Remains.banks(k, [[-0.3, 0.3, 0.32, 0.1]], Remains.drift_of(c)[0], s)


## The landscape's own review surface (src/gallery.gd finds any script under
## src/models with a `gallery()`): its four things dressed as the glass desert
## dresses them, and its two machines, all named for the landscape so one
## filter frames the lot.
##
##   tools/shot.sh shots/x.png --scene=gallery --filter=glass
static func gallery() -> Array:
	const MG := preload("res://src/models/machines/machine_gallery.gd")
	var out: Array = []
	var land := BiomeRegistry.index_of(&"glass_desert")
	for kind: int in [PropKind.FULGURITE, PropKind.GLASS_BLISTER, PropKind.FUSED_CAR, PropKind.STRIKE_ROD]:
		for v in PropModels.variants(kind, land):
			out.append({"name": "glass desert %s %d" % [PropKind.NAMES[kind], v], "node": PropModels.node(kind, v, land)})
	for kid: StringName in [&"skater", &"sentinel_anvil"]:
		var m: FigureModel = MG.make(kid, &"alert")
		var holder := Node3D.new()
		holder.add_child(m)
		out.append({"name": "glass desert %s" % kid, "node": holder})
	return out
