class_name GenShape
## Stage 1: the island. One landmass with a sea rim on every edge: a rounded,
## slightly tilted body taller than it is wide (the journey runs south to
## north), pushed out into peninsulas, bitten into bays, cut by a few long
## winding sea lochs, and fringed with tidal islets and skerries. No enclosed
## seas. Worked at half resolution (the coastline is smooth at that scale)
## and spread to tiles.

## Share of the whole square that is land.
const LAND_SHARE := 0.47
## Detached land smaller than this survives as an islet; anything bigger is
## sunk, so every country lies on the one walkable island.
const ISLET_TILES := 900
## Superellipse exponent of the body: 2 is an oval, higher is squarer.
const BODY_POWER := 2.6
## How many holes between grown bodies take skerries, and how many each.
const SKERRY_HOLES := 14
## How far out at sea a grown body's loch starts, in tiles.
const LOCH_OFFSHORE := 6.0
## How far the frame's fade line wanders on a world of many, as a share of the
## square per unit of the continent noise (about +-0.5).
const FRAME_WARP := 0.05
const LOCH_OPEN_SEA := 24.0
## How far in toward its centre a grown body's loch runs, as a share of the
## coast-to-centre distance: a third or so, so the body stays whole and still
## has ground broad enough for a colossus's foot (gen_treads.gd).
const LOCH_REACH := Vector2(0.28, 0.38)
const SKERRY_COUNT := Vector2i(3, 6)
## A hole narrower across than this share of the square keeps its open water:
## the least strait `GenBodies.SEA_GAP`.
const SKERRY_FILL := 0.06
## A skerry's radius in tiles: under `ISLET_TILES` in area, so `_clean` keeps it.
const SKERRY_RADIUS := Vector2(5.0, 14.0)


static func run(c: GenContext) -> void:
	var size := c.size
	var s := c.s
	var hs := 2
	var hw := GenFields.coarse_width(size, hs)
	var hn := hw * hw
	var rng := Rng.make(s, 100)
	# ONE SUPERELLIPSE PER BODY (docs/DESIGN.md). The draws are made in the same
	# order they always were, so a world of ONE body — which is every world this
	# project generates today — takes the identical stream and comes out identical.
	# A body's radii scale by the square root of its share of the land, because a
	# share is an area.
	var plan: Array[Dictionary] = c.bodies
	if plan.is_empty():
		plan = [{"at": Vector2(0.5, 0.5), "share": 1.0}]
	var shapes: Array[Dictionary] = []
	var lobes := PackedVector3Array()
	var lobe_amp := PackedFloat32Array()
	var lobe_body := PackedInt32Array()
	for bi in plan.size():
		var body: Dictionary = plan[bi]
		var at: Vector2 = body.get("at", Vector2(0.5, 0.5))
		var scale := sqrt(clampf(float(body.get("share", 1.0)), 0.02, 1.0))
		# A grown body's own aspect (`GenBodies._grow`) stretches one axis and
		# shrinks the other, so its area is what its share says.
		var aspect := float(body.get("aspect", 1.0))
		var ax := rng.randf_range(0.34, 0.38) * scale * aspect
		var ay := rng.randf_range(0.38, 0.41) * scale / aspect
		var tilt := rng.randf_range(-0.22, 0.22)
		shapes.append({"at": at, "ax": ax, "ay": ay, "ct": cos(tilt), "st": sin(tilt),
			"power": float(body.get("power", BODY_POWER)), "tilt": tilt})
		# A CONTINENT'S HEADLANDS REACH INTO ITS OWN OCEAN. With one island every
		# direction is its own ocean and this does nothing. With several, a
		# peninsula thrown inward lands in the strait — and they are big enough to
		# bridge it: the first multi-body world came out as ONE mass with four
		# visible arms, not because the bodies overlapped (they are 60 tiles clear
		# at 1024) but because each one's inward lobes met in the middle. The draws
		# are unchanged and only the ANGLE is turned, so a single body still takes
		# the identical stream.
		#
		# SO A HEADLAND IS TURNED ONLY WHERE IT WOULD MEET A NEIGHBOUR: toward
		# open sea, even the middle of the square, it stands where it was drawn.
		# The draws are unchanged, so a single body takes the identical stream.
		var many := plan.size() > 1
		var lobe_count := rng.randi_range(3, 5)
		for k in lobe_count:
			var ang := _rim_angle(rng)
			var reach := rng.randf_range(0.9, 1.08)
			var rad := rng.randf_range(0.06, 0.11)
			var keep := 1.0
			if many:
				var got := _clear_angle(plan, bi, ang, Vector2(ax, ay) * reach, rad, lobes, lobe_body)
				ang = got.x
				keep = got.y
			lobes.append(Vector3(at.x + cos(ang) * ax * reach, at.y + sin(ang) * ay * reach, rad))
			lobe_amp.append(rng.randf_range(0.35, 0.6) * keep)
			lobe_body.append(bi)
		# Islets offshore: small, close enough that some sit on the shallow shelf.
		var islet_count := rng.randi_range(4, 8)
		for k in islet_count:
			var ang := rng.randf() * TAU
			var reach := rng.randf_range(1.12, 1.24)
			var rad := rng.randf_range(0.012, 0.022)
			var keep := 1.0
			if many:
				var got := _clear_angle(plan, bi, ang, Vector2(ax, ay) * reach, rad, lobes, lobe_body)
				ang = got.x
				keep = got.y
			lobes.append(Vector3(at.x + cos(ang) * ax * reach, at.y + sin(ang) * ay * reach, rad))
			lobe_amp.append(rng.randf_range(0.9, 1.3) * keep)
			lobe_body.append(bi)
	var ax: float = shapes[0].ax
	var ay: float = shapes[0].ay
	var warp := GenFields.noise(s, 103, 1.0 / (220.0 * c.body_k), 2)
	const N := GenFields.NOISE
	var fl := GenFields.batch(size, [
		[N, GenFields.noise(s, 101, 1.0 / (150.0 * c.body_k), 4), hw, hs],
		[N, GenFields.noise(s, 105, 1.0 / (58.0 * maxf(c.body_k, 0.5)), 3), hw, hs],
		[N, GenFields.noise(s, 102, 1.0 / 20.0, 3), hw, hs],
		[N, warp, hw, hs],
		[N, warp, hw, hs, 731.0, -419.0],
		# Fine noise right at the waterline (used below).
		[N, GenFields.noise(s, 104, 1.0 / 7.0, 2), size, 1],
	])
	var continent := fl[0]
	var bays := fl[1]
	var coastline := fl[2]
	var warp_u := fl[3]
	var warp_v := fl[4]
	var lf := PackedFloat32Array()
	lf.resize(hn)
	var inner := PackedByteArray()
	inner.resize(hn)
	# THE BODIES, OUT OF THE INNERMOST LOOP. These were five Dictionary lookups
	# and five Variant casts per body per cell, on a grid of hw squared -- about
	# ten million of them. CLAUDE.md's own note: a GDScript method call is ten
	# times an array index, and reading packed arrays directly is what took a
	# coarse-world block from 480 ms to 34.
	#
	# Float64 and not Float32 on purpose: `float(sh.ct)` is a float64, and
	# narrowing it here would move every coastline in the game by a rounding
	# error while looking like a tidy-up.
	var shape_n := shapes.size()
	var sh_ax_ := PackedFloat64Array()
	var sh_ay_ := PackedFloat64Array()
	var sh_ct := PackedFloat64Array()
	var sh_st := PackedFloat64Array()
	var sh_rx := PackedFloat64Array()
	var sh_ry := PackedFloat64Array()
	var sh_p := PackedFloat64Array()
	for sh: Dictionary in shapes:
		var at: Vector2 = sh.at
		sh_ax_.append(at.x)
		sh_ay_.append(at.y)
		sh_ct.append(float(sh.ct))
		sh_st.append(float(sh.st))
		sh_rx.append(float(sh.ax))
		sh_ry.append(float(sh.ay))
		sh_p.append(float(sh.power))
	var many_bodies := plan.size() > 1
	GenFields.rows(hw, func(g0: int, g1: int) -> void:
		for gy in range(g0, g1):
			var ty := GenFields.cell_centre(gy, hs)
			var v := ty / size
			for gx in hw:
				var tx := GenFields.cell_centre(gx, hs)
				var u := tx / size
				var i := gy * hw + gx
				var hard := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
				if hard < 0.035:
					lf[i] = -1.0
					continue
				# The nearest body wins the cell: the void between them is simply
				# where no body reaches, which is what makes an ocean an ocean and
				# not a hole cut in one.
				#
				# The root per body, since a grown body has its own power. One
				# body takes the min of one value, which is the old arithmetic.
				var r := INF
				for si in shape_n:
					var wu := u + warp_u[i] * 0.05 - sh_ax_[si]
					var wv := v + warp_v[i] * 0.05 - sh_ay_[si]
					var pu := absf((wu * sh_ct[si] - wv * sh_st[si]) / sh_rx[si])
					var pv := absf((wu * sh_st[si] + wv * sh_ct[si]) / sh_ry[si])
					var p := sh_p[si]
					r = minf(r, pow(pow(pu, p) + pow(pv, p), 1.0 / p))
				r = minf(1e9, r)
				var h := (1.0 - r) * 1.1
				# Bays bite hardest near the rim, where the coast is.
				var rim := exp(-(r - 1.0) * (r - 1.0) * 14.0)
				h += continent[i] * 0.26 + bays[i] * (0.08 + 0.36 * rim) + coastline[i] * (0.03 + 0.07 * rim)
				for k in lobes.size():
					var lb := lobes[k]
					var du := u - lb.x
					var dv := v - lb.y
					var q := (du * du + dv * dv) / (lb.z * lb.z)
					if q < 4.0:
						h += lobe_amp[k] * exp(-q * 1.6)
				# Never let the land run into the frame. On a world of many the
				# fade line is itself warped by the continent noise, so a body
				# packed near the frame ends in a coast, not a ruler line.
				var fade := hard + continent[i] * FRAME_WARP if many_bodies else hard
				h -= (1.0 - smoothstep(0.035, 0.09, fade)) * 1.6
				lf[i] = h
				inner[i] = 1
	)
	c.mark(&"shape.noise")
	var inner_count := inner.count(1)
	# THE LAND A WORLD HAS FOLLOWS ITS BODIES. `LAND_SHARE` is what ONE island
	# takes; a world of continents takes the sum of what its bodies take, which is
	# less, because the ocean between them is the difference. Without this the
	# quantile below hands back the same total land whatever shapes it was given
	# and simply fills the water in — which is exactly what four continents did on
	# the first run, coming out as one mass of half a million tiles.
	var share := 0.0
	for body: Dictionary in plan:
		share += float(body.get("share", 1.0))
	var want := clampf(1.0 - (LAND_SHARE * share + 0.012) * hn / maxf(1.0, inner_count), 0.05, 0.95)
	var thr := GenFields.quantile(lf, inner, want, -2.5, 2.5)
	for i in hn:
		lf[i] -= thr
	if plan.size() > 1:
		for bi in shapes.size():
			_body_lochs(c, rng, lf, hw, hs, shapes[bi], bi)
		_skerries(c, Rng.make(s, 107), lf, hw, hs, coastline, plan)
	else:
		_lochs(c, rng, lf, hw, hs, ax, ay)
	var land_h := PackedByteArray()
	land_h.resize(hn)
	for i in hn:
		land_h[i] = 1 if lf[i] > 0.0 else 0
	c.mark(&"shape.quantile")
	var islet_h := _clean(lf, land_h, hw, plan.size())
	c.mark(&"shape.clean")
	# Tiles: bilinear, then a whisper of fine noise right at the waterline so
	# rock shores crinkle and throw the odd skerry.
	var full := GenFields.upsample(lf, hw, hs, size)
	var fine := fl[5]
	var land := PackedByteArray()
	land.resize(c.n)
	var islet := PackedByteArray()
	islet.resize(c.n)
	# The crinkle only where the coast really is: inland the field can lie
	# close to zero for miles, and noise there would pock the land with pits.
	var shore_h := PackedByteArray()
	shore_h.resize(hn)
	for gy in range(1, hw - 1):
		for gx in range(1, hw - 1):
			var k := gy * hw + gx
			var a := land_h[k]
			if land_h[k - 1] != a or land_h[k + 1] != a or land_h[k - hw] != a or land_h[k + hw] != a:
				shore_h[k] = 1
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for y in range(maxi(y0, 3), mini(y1, size - 3)):
			var row := y * size
			var hrow := (y >> 1) * hw
			for x in range(3, size - 3):
				var k := hrow + (x >> 1)
				if shore_h[k] == 0:
					land[row + x] = land_h[k]
				elif full[row + x] + fine[row + x] * 0.022 > 0.0:
					land[row + x] = 1
				if land[row + x] != 0:
					islet[row + x] = islet_h[k]
	)
	c.islet = islet
	c.land = land
	# The journey template is laid over the main body's extent, not the islets'.
	var min_x := size
	var min_y := size
	var max_x := 0
	var max_y := 0
	for gy in hw:
		for gx in hw:
			if land_h[gy * hw + gx] != 0 and lf[gy * hw + gx] > 0.08:
				min_x = mini(min_x, gx * hs)
				min_y = mini(min_y, gy * hs)
				max_x = maxi(max_x, gx * hs + hs)
				max_y = maxi(max_y, gy * hs + hs)
	c.land_rect = Rect2(min_x, min_y, maxi(1, max_x - min_x), maxi(1, max_y - min_y))
	c.mark(&"shape.tiles")
	# Distances at half resolution are plenty for ramps and profiles.
	var sea_h := PackedByteArray()
	sea_h.resize(hn)
	for i in hn:
		sea_h[i] = 1 - land_h[i]
	# Exact to 48 tiles, which is farther than anything reads it (the spawn
	# village looks up to 40 tiles inland).
	var inland_h := GenFields.distance8_banded(sea_h, hw, 999.0, 24)
	var offshore_h := GenFields.distance8_banded(land_h, hw, 999.0, 24)
	for i in hn:
		inland_h[i] = inland_h[i] * hs - 1.0
		offshore_h[i] = offshore_h[i] * hs - 1.0
	c.inland = GenFields.upsample(inland_h, hw, hs, size)
	c.offshore = GenFields.upsample(offshore_h, hw, hs, size)
	c.mark(&"shape.distance")
	c.convex = GenFields.neighbourhood_share(land, size, 4)
	c.mark(&"shape.convex")


## An angle around the rim (0 = east, PI/2 = south), keeping clear of the
## middle of the south coast.
static func _rim_angle(rng: RandomNumberGenerator) -> float:
	for attempt in 8:
		var a := rng.randf() * TAU
		if absf(wrapf(a - PI * 0.5, -PI, PI)) > 0.6:
			return a
	return PI * 1.5


## Sea lochs: long winding inlets cut from the open sea toward the heart of the
## island, widest at the mouth. They make the walk go round, and put sheltered
## water deep inland. Never more than a third of the way in, so the island
## stays whole.
static func _lochs(c: GenContext, rng: RandomNumberGenerator, lf: PackedFloat32Array, hw: int, hs: int, ax: float, ay: float) -> void:
	var size := float(c.size)
	var count := rng.randi_range(2, 3)
	var wobble := GenFields.noise(c.s, 106, 1.0 / 30.0, 2)
	for k in count:
		var ang := _rim_angle(rng)
		# Start out at sea and head for the centre, bending as it goes.
		var p := Vector2(0.5 + cos(ang) * ax * 1.15, 0.5 + sin(ang) * ay * 1.15) * size
		var head := Vector2(size * 0.5, size * 0.5)
		var total := (p.distance_to(head)) * rng.randf_range(0.42, 0.55)
		var mouth := rng.randf_range(5.0, 8.0)
		_cut_loch(lf, hw, hs, wobble, p, (head - p).normalized(), total, mouth, float(k) * 97.0)


## One loch: from `from` (tiles) along `dir`, bending by `wobble`, for `total`
## tiles, `mouth` tiles in radius at the mouth narrowing to three.
static func _cut_loch(lf: PackedFloat32Array, hw: int, hs: int, wobble: FastNoiseLite, from: Vector2, dir: Vector2, total: float, mouth: float, salt: float) -> void:
	var p := from
	var travelled := 0.0
	while travelled < total:
		var t := travelled / total
		# Never narrower than about three tiles: a thinner channel breaks
		# into a dotted line of pits.
		var radius := lerpf(mouth, 3.0, t) / hs
		var bend := wobble.get_noise_2d(travelled, salt) * 1.3
		var step_dir := dir.rotated(bend)
		p += step_dir
		travelled += 1.0
		var cx := p.x / hs
		var cy := p.y / hs
		var ri := ceili(radius + 1.0)
		for dy in range(-ri, ri + 1):
			for dx in range(-ri, ri + 1):
				var gx := floori(cx) + dx
				var gy := floori(cy) + dy
				if gx < 1 or gy < 1 or gx >= hw - 1 or gy >= hw - 1:
					continue
				var d := Vector2(gx + 0.5 - cx, gy + 0.5 - cy).length()
				if d < radius:
					var i := gy * hw + gx
					lf[i] = minf(lf[i], -0.06 - 0.25 * (1.0 - d / radius))


## Where a headland or islet of body `bi` may stand, drawn at `ang`, `reach`
## out along its axes with radius `rad` (square units): x the angle, y 1 to lay
## it or 0 to drop it. The drawn angle where it clears every other body's
## ellipse and every headland already laid on another body by
## GenBodies.SEA_GAP; else folded toward the side facing away from what it
## would meet; else straight away from it; else dropped. Two headlands facing
## across a strait each clear the other's ELLIPSE and still meet, which is how
## grown bodies fused.
static func _clear_angle(plan: Array[Dictionary], bi: int, ang: float, reach: Vector2, rad: float, lobes: PackedVector3Array, lobe_body: PackedInt32Array) -> Vector2:
	var at: Vector2 = plan[bi].at
	var got := _gap(plan, bi, at + Vector2(cos(ang) * reach.x, sin(ang) * reach.y), rad, lobes, lobe_body)
	if got.x >= GenBodies.SEA_GAP:
		return Vector2(ang, 1.0)
	var away := (at - Vector2(got.y, got.z)).angle()
	for turn: float in [away + wrapf(ang - away, -PI, PI) * 0.42, away]:
		if _gap(plan, bi, at + Vector2(cos(turn) * reach.x, sin(turn) * reach.y), rad, lobes, lobe_body).x >= GenBodies.SEA_GAP:
			return Vector2(turn, 1.0)
	return Vector2(ang, 0.0)


## The least clearance from a disc at `p` of radius `rad` to anything not of
## body `bi` (x), and where that nearest thing stands (y, z).
static func _gap(plan: Array[Dictionary], bi: int, p: Vector2, rad: float, lobes: PackedVector3Array, lobe_body: PackedInt32Array) -> Vector3:
	var worst := INF
	var from := p
	for oi in plan.size():
		if oi == bi:
			continue
		var o: Vector2 = plan[oi].at
		var r := GenBodies.ONE_RADIUS * sqrt(clampf(float(plan[oi].get("share", 1.0)), 0.02, 1.0)) * GenBodies.PACK_REACH
		var a := float(plan[oi].get("aspect", 1.0))
		var d := p - o
		var dir := d.normalized() if d.length() > 1e-6 else Vector2.RIGHT
		var gap := d.length() - GenBodies._reach(r * a, r / a, dir) - rad
		if gap < worst:
			worst = gap
			from = o
	for k in lobes.size():
		if lobe_body[k] == bi:
			continue
		var lb := lobes[k]
		var gap := p.distance_to(Vector2(lb.x, lb.y)) - rad - lb.z
		if gap < worst:
			worst = gap
			from = Vector2(lb.x, lb.y)
	return Vector3(worst, from.x, from.y)


## SKERRIES WHERE A GROWN WORLD WOULD LEAVE A HOLE. Bodies packed apart leave
## open water between three or four of them far wider than any strait, and a
## hole in the middle is the ring's empty sea again. On the thresholded field
## (land where `lf` > 0), the widest disc of open water that stays inside the
## hull of the bodies' centres takes a cluster of skerries, and again, until no
## such disc is wider across than SKERRY_FILL or SKERRY_HOLES have been filled.
## Each skerry is under `ISLET_TILES`, so `_clean` keeps it, and its rim is
## crinkled by the coastline noise. Drawn from its own stream, and only on a
## world of many bodies.
static func _skerries(c: GenContext, rng: RandomNumberGenerator, lf: PackedFloat32Array, hw: int, hs: int, coastline: PackedFloat32Array, plan: Array[Dictionary]) -> void:
	const ST := 4
	var cw := hw / ST
	var tiles := float(ST * hs)
	var land := PackedByteArray()
	land.resize(cw * cw)
	for cy in cw:
		for cx in cw:
			if lf[(cy * ST + ST / 2) * hw + cx * ST + ST / 2] > 0.0:
				land[cy * cw + cx] = 1
	var centres := PackedVector2Array()
	for b: Dictionary in plan:
		centres.append((b.at as Vector2) * float(cw))
	var hull := Geometry2D.convex_hull(centres)
	for _h in SKERRY_HOLES:
		var d := GenFields.distance8(land, cw)
		var best := Vector3(0, 0, 0)
		for cy in cw:
			for cx in cw:
				var open := d[cy * cw + cx]
				if open <= best.z:
					continue
				var p := Vector2(cx, cy)
				if not Geometry2D.is_point_in_polygon(p, hull):
					continue
				var r := open
				for k in hull.size() - 1:
					r = minf(r, p.distance_to(Geometry2D.get_closest_point_to_segment(p, hull[k], hull[k + 1])))
				if r > best.z:
					best = Vector3(cx, cy, r)
		if 2.0 * best.z * tiles < SKERRY_FILL * c.size:
			return
		var count := rng.randi_range(SKERRY_COUNT.x, SKERRY_COUNT.y)
		for k in count:
			var at := Vector2(best.x, best.y) + Vector2.from_angle(rng.randf() * TAU) * best.z * 0.6 * sqrt(rng.randf())
			var rt := rng.randf_range(SKERRY_RADIUS.x, SKERRY_RADIUS.y)
			# In half-resolution cells.
			var hc := (at * ST + Vector2(ST, ST) * 0.5)
			var rr := rt / hs
			var ri := ceili(rr + 1.0)
			for dy in range(-ri, ri + 1):
				for dx in range(-ri, ri + 1):
					var gx := floori(hc.x) + dx
					var gy := floori(hc.y) + dy
					if gx < 1 or gy < 1 or gx >= hw - 1 or gy >= hw - 1:
						continue
					var i := gy * hw + gx
					var dd := Vector2(gx + 0.5 - hc.x, gy + 0.5 - hc.y).length() / rr
					lf[i] = maxf(lf[i], 0.08 * (1.0 - dd) + coastline[i] * 0.05)
			var ci := clampi(floori(at.y), 0, cw - 1) * cw + clampi(floori(at.x), 0, cw - 1)
			land[ci] = 1


## Sea lochs for one grown body: as `_lochs`, but from its own rim toward its
## own centre, with its own axes and tilt, 2-4 of them. A body of a world of
## many is several islands' worth of land, and the square's centre `_lochs`
## heads for is open sea or another body.
static func _body_lochs(c: GenContext, rng: RandomNumberGenerator, lf: PackedFloat32Array, hw: int, hs: int, sh: Dictionary, bi: int) -> void:
	var size := float(c.size)
	var at: Vector2 = sh.at
	var ax: float = sh.ax
	var ay: float = sh.ay
	var tilt: float = sh.tilt
	var count := rng.randi_range(2, 4)
	var wobble := GenFields.noise(c.s, 106, 1.0 / 30.0, 2)
	for k in count:
		var ang := _rim_angle(rng)
		var rim := Vector2(cos(ang) * ax * 1.15, sin(ang) * ay * 1.15).rotated(tilt)
		var head := at * size
		var p := _coast_along(lf, hw, hs, head, (at + rim) * size)
		var total := p.distance_to(head) * rng.randf_range(LOCH_REACH.x, LOCH_REACH.y) + LOCH_OFFSHORE
		var mouth := rng.randf_range(5.0, 8.0)
		var dir := (head - p).normalized()
		_cut_loch(lf, hw, hs, wobble, p - dir * LOCH_OFFSHORE, dir, total, mouth, float(bi * 5 + k) * 97.0)


## The last land from `head` out along the line through `rim` (tiles), before
## LOCH_OPEN_SEA of open water and no farther than twice `rim`: where a loch's
## mouth must open, and never on a neighbour across the strait. A loch started at the drawn rim
## began inland wherever a headland stood there, and `_clean` filled it as an
## enclosed sea. `rim` itself when the line meets no land.
static func _coast_along(lf: PackedFloat32Array, hw: int, hs: int, head: Vector2, rim: Vector2) -> Vector2:
	var dir := (rim - head).normalized()
	var reach := head.distance_to(rim) * 2.0
	var last := rim
	var t := 0.0
	while t < reach:
		var q := head + dir * t
		var gx := floori(q.x / hs)
		var gy := floori(q.y / hs)
		if gx < 0 or gy < 0 or gx >= hw or gy >= hw:
			break
		if lf[gy * hw + gx] > 0.0:
			last = q
		elif q.distance_to(last) > LOCH_OPEN_SEA and last != rim:
			break
		t += 2.0
	return last


## Fill enclosed seas; sink detached land bigger than an islet. Returns 1
## on the islets that stay.
static func _clean(lf: PackedFloat32Array, land_h: PackedByteArray, hw: int, keep: int) -> PackedByteArray:
	var hn := hw * hw
	var sea := PackedByteArray()
	sea.resize(hn)
	for i in hn:
		sea[i] = 1 - land_h[i]
	var sizes := PackedInt32Array()
	var labels := GenFields.components(sea, hw, sizes)
	var ocean := labels[0]
	for i in hn:
		if labels[i] >= 0 and labels[i] != ocean:
			land_h[i] = 1
			lf[i] = maxf(lf[i], 0.12)
	var lsizes := PackedInt32Array()
	var llabels := GenFields.components(land_h, hw, lsizes)
	# KEEP AS MANY MASSES AS THE WORLD WAS PLANNED TO HAVE. This kept exactly one
	# and drowned every other run of land above islet size, which is what made
	# "every country lies on the one walkable island" true — and it is the line
	# that silently deleted three continents out of four the first time the body
	# stage laid them. With `keep` at 1 it does exactly what it always did.
	var order: Array[int] = []
	for id in lsizes.size():
		if lsizes[id] > 0:
			order.append(id)
	order.sort_custom(func(a: int, b: int) -> bool: return lsizes[a] > lsizes[b])
	var kept := {}
	for r in mini(maxi(keep, 1), order.size()):
		kept[order[r]] = true
	var islet_cells := ISLET_TILES / 4
	for i in hn:
		var id := llabels[i]
		if id >= 0 and not kept.has(id) and lsizes[id] > islet_cells:
			land_h[i] = 0
			lf[i] = -0.04
	var islets := PackedByteArray()
	islets.resize(hn)
	for i in hn:
		islets[i] = 1 if land_h[i] != 0 and not kept.has(llabels[i]) else 0
	return islets
