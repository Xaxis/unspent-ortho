class_name GenRelief
## Stage 3: float elevation, in levels. Each country has its own relief (low
## fen, rolling coast, pine hills, a limestone plateau of stepped scarps, a
## ridged range, a caldera), blended by soft membership so land rises and
## falls over many tiles. The shore is a beach in bays and a cliff on
## headlands, with a shingle ledge at the cliff foot.

const MAX_LEVEL := 15


static func run(c: GenContext) -> void:
	var size := c.size
	var s := c.s
	var n := c.n
	var p := GenCountries.upsample_params(c, [&"base", &"hills", &"ridge", &"terrace", &"cliff"])
	var base: PackedFloat32Array = p[&"base"]
	var hills_amp: PackedFloat32Array = p[&"hills"]
	var ridge_amp: PackedFloat32Array = p[&"ridge"]
	var terrace: PackedFloat32Array = p[&"terrace"]
	var cliff_bias: PackedFloat32Array = p[&"cliff"]
	var burning := GenFields.upsample(c.soft[Country.BURNING], c.cw, GenContext.STEP, size)
	var hills := GenFields.field(GenFields.noise(s, 301, 1.0 / 58.0, 4), size, 2)
	var ridge := GenFields.field(GenFields.noise(s, 302, 1.0 / 92.0, 3), size, 2)
	var detail := GenFields.noise(s, 303, 1.0 / 13.0, 2)
	var cliffn := GenFields.field(GenFields.noise(s, 304, 1.0 / 44.0, 2), size, 4)
	var shoren := GenFields.field(GenFields.noise(s, 306, 1.0 / 60.0, 2), size, 8)
	var shelf := GenFields.field(GenFields.noise(s, 305, 1.0 / 30.0, 2), size, 4)
	var heart := c.hearts[Country.BURNING]
	var crater := 30.0 * maxf(0.6, c.k)
	var land := c.land
	var inland := c.inland
	var offshore := c.offshore
	var convex := c.convex
	var elev := PackedFloat32Array()
	elev.resize(n)
	c.mark(&"relief.fields")
	for y in size:
		var row := y * size
		for x in size:
			var i := row + x
			if land[i] == 0:
				elev[i] = 0.0 if offshore[i] < 2.2 + shelf[i] * 3.0 else -1.0
				continue
			var e := base[i] + hills[i] * hills_amp[i]
			var r := 1.0 - absf(ridge[i])
			var ha := hills_amp[i]
			e += r * r * r * ridge_amp[i]
			if ha > 1.0:
				e += detail.get_noise_2d(x, y) * (0.3 + ha * 0.12)
			var t := terrace[i]
			if t > 0.01:
				# Plateaus in steps of two levels with short steep risers: scarps.
				var q := e * 0.5
				var f := q - floorf(q)
				e = lerpf(e, (floorf(q) + smoothstep(0.62, 0.88, f)) * 2.0, t)
			var bw := burning[i]
			if bw > 0.05:
				var dx := x - heart.x
				var dy := y - heart.y
				var d := sqrt(dx * dx + dy * dy) / crater
				var rim := exp(-(d - 1.0) * (d - 1.0) * 5.0) * 4.5
				var basin := -2.2 * (1.0 - smoothstep(0.2, 0.95, d))
				e += bw * (rim + basin)
			var d_in := inland[i]
			if d_in < 24.0:
				var cl := clampf((0.52 - convex[i]) * 5.0 + cliffn[i] * 1.5 + cliff_bias[i], 0.0, 1.0)
				# Beaches vary from wide flats to steep shores.
				var sh := shoren[i]
				var flat := 1.0 + maxf(0.0, sh) * 7.0
				var slope := 0.3 + maxf(0.0, -sh) * 1.6
				var beach := minf(e, 0.95 + maxf(0.0, d_in - flat) * slope)
				var top := maxf(e, 3.2 + cl * 3.0 + e * 0.1)
				var headland := lerpf(top, e, smoothstep(5.0, 18.0, d_in))
				if d_in < 1.3:
					headland = 1.0
				e = lerpf(beach, headland, smoothstep(0.4, 0.62, cl))
			elev[i] = clampf(e, 1.0, MAX_LEVEL + 0.99)
	c.elev = elev


## Float elevation to integer levels; lonely one-tile spikes and pits removed.
static func terrace(c: GenContext) -> void:
	var size := c.size
	var land := c.land
	var water := c.water
	var elev := c.elev
	var level := c.w.level
	for i in c.n:
		if land[i] == 0:
			level[i] = int(elev[i])
		else:
			level[i] = clampi(floori(elev[i]), 1, MAX_LEVEL)
	for y in range(1, size - 1):
		for x in range(1, size - 1):
			var i := y * size + x
			if land[i] == 0 or water[i] != 0:
				continue
			var l := level[i]
			var a := level[i - 1]
			var b := level[i + 1]
			var d := level[i - size]
			var u := level[i + size]
			if a > l and b > l and d > l and u > l:
				level[i] = mini(mini(a, b), mini(d, u))
			elif a < l and b < l and d < l and u < l:
				level[i] = maxi(maxi(a, b), maxi(maxi(d, u), 1))
