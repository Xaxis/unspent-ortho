class_name GenRelief
## Stages 3 and 6: float elevation, in levels. Each country has its own relief (low
## fen, rolling coast, pine hills, a limestone plateau of stepped scarps, a
## ridged range, a caldera), blended by soft membership so land rises and
## falls over many tiles. The shore is a beach in bays and a cliff on
## headlands, with a shingle ledge at the cliff foot.

const MAX_LEVEL := 15


static func run(c: GenContext) -> void:
	var size := c.size
	var s := c.s
	var n := c.n
	var p := GenCountries.params(c, [&"base", &"hills", &"ridge", &"terrace", &"cliff"])
	c.mark(&"relief.params")
	const F := GenFields.FIELD
	const U := GenFields.UP
	const N := GenFields.NOISE
	var cw := c.cw
	var step := GenContext.STEP
	var fl := GenFields.batch(size, [
		[U, p[&"base"], cw, step], [U, p[&"hills"], cw, step], [U, p[&"ridge"], cw, step],
		[U, p[&"terrace"], cw, step], [U, p[&"cliff"], cw, step],
		[U, c.soft[Country.BURNING], cw, step], [U, c.soft[Country.COAST], cw, step],
		[F, GenFields.noise(s, 301, 1.0 / 58.0, 4), 2],
		[F, GenFields.noise(s, 302, 1.0 / 92.0, 3), 2],
		[N, GenFields.noise(s, 303, 1.0 / 13.0, 2), size, 1],
		[F, GenFields.noise(s, 304, 1.0 / 44.0, 2), 4],
		[F, GenFields.noise(s, 306, 1.0 / 60.0, 2), 8],
		[F, GenFields.noise(s, 305, 1.0 / 30.0, 2), 4],
		[N, GenFields.noise(s, 308, 1.0 / 8.0, 2), size, 1],
		# The rim is a broken ring, never a drawn circle.
		[F, GenFields.noise(s, 307, 1.0 / 26.0, 2), 2],
	])
	c.mark(&"relief.batch")
	var base := fl[0]
	var hills_amp := fl[1]
	var ridge_amp := fl[2]
	var terrace := fl[3]
	var cliff_bias := fl[4]
	var burning := fl[5]
	var coastal := fl[6]
	var hills := fl[7]
	var ridge := fl[8]
	var detail := fl[9]
	var cliffn := fl[10]
	var shoren := fl[11]
	var shelf := fl[12]
	var dunes := fl[13]
	var heart := c.hearts[Country.BURNING]
	var crater := crater_radius(c)
	var rim_warp := fl[14]
	c.rim_warp = rim_warp
	var land := c.land
	var inland := c.inland
	var offshore := c.offshore
	var convex := c.convex
	var islet := c.islet
	var elev := PackedFloat32Array()
	elev.resize(n)
	c.mark(&"relief.fields")
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for y in range(y0, y1):
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
					e += detail[i] * (0.3 + ha * 0.12)
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
					var d := (sqrt(dx * dx + dy * dy) + rim_warp[i] * crater * 0.3) / crater
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
					if d_in > 1.5 and d_in < 12.0 and coastal[i] > 0.3:
						# Dunes: ridged hummocks behind the sandy bays.
						var ridge_v := 1.0 - absf(dunes[i])
						beach += smoothstep(0.45, 0.95, ridge_v) * 1.15 * smoothstep(1.5, 4.0, d_in) * (1.0 - smoothstep(8.0, 12.0, d_in)) * minf(1.0, (coastal[i] - 0.3) * 2.5)
					var top := maxf(e, 3.2 + cl * 3.0 + e * 0.1)
					var headland := lerpf(top, e, smoothstep(5.0, 18.0, d_in))
					if d_in < 1.3:
						headland = 1.0
					e = lerpf(beach, headland, smoothstep(0.4, 0.62, cl))
				if islet[i] != 0 and cliffn[i] < 0.25:
					# Most islets are low skerries; the rest stand as stacks.
					e = 1.0 + minf(1.6, d_in * 0.35)
				elev[i] = clampf(e, 1.0, MAX_LEVEL + 0.99)
	)
	c.elev = elev


## Radius in tiles of the Burning's caldera rim.
static func crater_radius(c: GenContext) -> float:
	return 30.0 * maxf(0.6, c.k)


## Float elevation to integer levels; lonely one-tile spikes and pits removed.
static func terrace(c: GenContext) -> void:
	var size := c.size
	var land := c.land
	var water := c.water
	var elev := c.elev
	var level := c.w.level
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for i in range(y0 * size, y1 * size):
			if land[i] == 0:
				level[i] = int(elev[i])
			else:
				level[i] = clampi(floori(elev[i]), 1, MAX_LEVEL)
	)
	# Spikes and pits are judged against the undisturbed levels, so bands can
	# work in parallel.
	var before: PackedInt32Array = GenFields.snapshot(level)
	GenFields.rows(size - 1, func(y0: int, y1: int) -> void:
		for y in range(maxi(y0, 1), y1):
			for x in range(1, size - 1):
				var i := y * size + x
				if land[i] == 0 or water[i] != 0:
					continue
				var l := before[i]
				var a := before[i - 1]
				var b := before[i + 1]
				var d := before[i - size]
				var u := before[i + size]
				if a > l and b > l and d > l and u > l:
					level[i] = mini(mini(a, b), mini(d, u))
				elif a < l and b < l and d < l and u < l:
					level[i] = maxi(maxi(a, b), maxi(maxi(d, u), 1))
	)
