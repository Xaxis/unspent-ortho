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


static func run(c: GenContext) -> void:
	var size := c.size
	var s := c.s
	var hs := 2
	var hw := GenFields.coarse_width(size, hs)
	var hn := hw * hw
	var rng := Rng.make(s, 100)
	var ax := rng.randf_range(0.34, 0.38)
	var ay := rng.randf_range(0.38, 0.41)
	var tilt := rng.randf_range(-0.22, 0.22)
	var ct := cos(tilt)
	var st := sin(tilt)
	# Peninsulas: bumps straddling the rim, never on the south coast's middle
	# (the spawn bay stays a broad open shore).
	var lobes := PackedVector3Array()
	var lobe_amp := PackedFloat32Array()
	var lobe_count := rng.randi_range(3, 5)
	for k in lobe_count:
		var ang := _rim_angle(rng)
		var reach := rng.randf_range(0.9, 1.08)
		lobes.append(Vector3(0.5 + cos(ang) * ax * reach, 0.5 + sin(ang) * ay * reach, rng.randf_range(0.06, 0.11)))
		lobe_amp.append(rng.randf_range(0.35, 0.6))
	# Islets offshore: small, close enough that some sit on the shallow shelf.
	var islet_count := rng.randi_range(4, 8)
	for k in islet_count:
		var ang := rng.randf() * TAU
		var reach := rng.randf_range(1.12, 1.24)
		lobes.append(Vector3(0.5 + cos(ang) * ax * reach, 0.5 + sin(ang) * ay * reach, rng.randf_range(0.012, 0.022)))
		lobe_amp.append(rng.randf_range(0.9, 1.3))
	var warp := GenFields.noise(s, 103, 1.0 / (220.0 * c.k), 2)
	const N := GenFields.NOISE
	var fl := GenFields.batch(size, [
		[N, GenFields.noise(s, 101, 1.0 / (150.0 * c.k), 4), hw, hs],
		[N, GenFields.noise(s, 105, 1.0 / (58.0 * maxf(c.k, 0.5)), 3), hw, hs],
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
				var wu := u + warp_u[i] * 0.05 - 0.5
				var wv := v + warp_v[i] * 0.05 - 0.5
				var pu := absf((wu * ct - wv * st) / ax)
				var pv := absf((wu * st + wv * ct) / ay)
				var r := pow(pow(pu, BODY_POWER) + pow(pv, BODY_POWER), 1.0 / BODY_POWER)
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
				# Never let the land run into the frame.
				h -= (1.0 - smoothstep(0.035, 0.09, hard)) * 1.6
				lf[i] = h
				inner[i] = 1
	)
	c.mark(&"shape.noise")
	var inner_count := inner.count(1)
	var want := clampf(1.0 - (LAND_SHARE + 0.012) * hn / maxf(1.0, inner_count), 0.05, 0.95)
	var thr := GenFields.quantile(lf, inner, want, -2.5, 2.5)
	for i in hn:
		lf[i] -= thr
	_lochs(c, rng, lf, hw, hs, ax, ay)
	var land_h := PackedByteArray()
	land_h.resize(hn)
	for i in hn:
		land_h[i] = 1 if lf[i] > 0.0 else 0
	c.mark(&"shape.quantile")
	var islet_h := _clean(lf, land_h, hw)
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
		var travelled := 0.0
		var mouth := rng.randf_range(5.0, 8.0)
		var dir := (head - p).normalized()
		var salt := float(k) * 97.0
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


## Fill enclosed seas; sink detached land bigger than an islet. Returns 1
## on the islets that stay.
static func _clean(lf: PackedFloat32Array, land_h: PackedByteArray, hw: int) -> PackedByteArray:
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
	var main := 0
	for id in lsizes.size():
		if lsizes[id] > lsizes[main]:
			main = id
	var islet_cells := ISLET_TILES / 4
	for i in hn:
		var id := llabels[i]
		if id >= 0 and id != main and lsizes[id] > islet_cells:
			land_h[i] = 0
			lf[i] = -0.04
	var islets := PackedByteArray()
	islets.resize(hn)
	for i in hn:
		islets[i] = 1 if land_h[i] != 0 and llabels[i] != main else 0
	return islets
