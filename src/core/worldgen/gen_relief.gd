class_name GenRelief
## Stages 3 and 6: float elevation, in levels. Each landscape type has its own
## relief (low fen, rolling coast, pine hills, a limestone plateau of stepped
## scarps, a ridged range, a caldera), declared in `BiomeDef.relief` and blended
## by soft membership so land rises and falls over many tiles. The shore is a
## beach in bays and a cliff on headlands, with a shingle ledge at the foot.

## The highest land, in levels (15 units). Twice what it was, so a region's
## form (`GenForm`) can stand a spine a player sees from the shore.
const MAX_LEVEL := 30
## The top of the range the climate and border rules were tuned on: they read
## height no higher than this, so land standing taller than it used to (a
## spine, a range no longer clamped) does not move a border or cool a tile.
const TUNED_TOP := 15.99


static func run(c: GenContext) -> void:
	var size := c.size
	var s := c.s
	var n := c.n
	var p := GenCountries.params(c, [&"base", &"hills", &"ridge", &"near", &"terrace", &"cliff", &"shelf", &"shelf_var", &"slots"])
	c.mark(&"relief.params")
	const F := GenFields.FIELD
	const U := GenFields.UP
	const N := GenFields.NOISE
	var cw := c.cw
	var step := GenContext.STEP
	var fl := GenFields.batch(size, [
		[U, p[&"base"], cw, step], [U, p[&"hills"], cw, step], [U, p[&"ridge"], cw, step],
		[U, p[&"near"], cw, step],
		[U, p[&"terrace"], cw, step], [U, p[&"cliff"], cw, step],
		[U, _caldera_soft(c), cw, step], [U, _dunes_soft(c), cw, step],
		# At walking scale on a body of one island; a continent's swell is
		# broader by `body_k`, so a region is not one 60-tile swell repeated.
		# Never narrower than it always was (`body_k` is under 1 below 512).
		[F, GenFields.noise(s, 301, 1.0 / (58.0 * maxf(1.0, c.body_k)), 4), 2],
		[F, GenFields.noise(s, 302, 1.0 / (92.0 * maxf(1.0, c.body_k)), 3), 2],
		[N, GenFields.noise(s, 303, 1.0 / 13.0, 2), size, 1],
		[F, GenFields.noise(s, 304, 1.0 / 44.0, 2), 4],
		[F, GenFields.noise(s, 306, 1.0 / 60.0, 2), 8],
		[F, GenFields.noise(s, 305, 1.0 / 30.0, 2), 4],
		[N, GenFields.noise(s, 308, 1.0 / 8.0, 2), size, 1],
		# The rim is a broken ring, never a drawn circle.
		[F, GenFields.noise(s, 307, 1.0 / 26.0, 2), 2],
		# How tall a shelf's cliff stands, wandering across a range of crags.
		[F, GenFields.noise(s, 309, 1.0 / 70.0, 2), 8],
		[U, p[&"shelf"], cw, step], [U, p[&"shelf_var"], cw, step],
		[U, p[&"slots"], cw, step], [U, _slotted_soft(c), cw, step],
	])
	c.mark(&"relief.batch")
	var base := fl[0]
	var hills_amp := fl[1]
	var ridge_amp := fl[2]
	var near_amp := fl[3]
	var terrace := fl[4]
	var cliff_bias := fl[5]
	var burning := fl[6]
	var coastal := fl[7]
	var hills := fl[8]
	var ridge := fl[9]
	var detail := fl[10]
	var cliffn := fl[11]
	var shoren := fl[12]
	var shelf := fl[13]
	var dunes := fl[14]
	var heart := c.hearts[c.caldera_type] if c.caldera_type >= 0 else Vector2(-1, -1)
	var crater := crater_radius(c)
	var rim_warp := fl[15]
	var shelfn := fl[16]
	var shelf_amp := fl[17]
	var shelf_var := fl[18]
	# SLOT CANYONS (`slots`, GenSlots): the plateau stands `slots` levels over a
	# labyrinth of floors, only where a landscape asks for it.
	var slots := fl[19]
	var slot_share := fl[20]
	var slotted := false
	for v: float in p[&"slots"]:
		slotted = slotted or v > 0.01
	var slot_up := GenSlots.plan(s, size).field(s, size, slots) if slotted else PackedFloat32Array()
	c.rim_warp = rim_warp
	var land := c.land
	var inland := c.inland
	var offshore := c.offshore
	var convex := c.convex
	var islet := c.islet
	var elev := PackedFloat32Array()
	elev.resize(n)
	var form := GenFields.upsample(c.form_e, cw, step, size) if not c.form_e.is_empty() else PackedFloat32Array()
	var formed := not form.is_empty()
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
				if formed:
					e += form[i]
				var r := 1.0 - absf(ridge[i])
				var ha := hills_amp[i]
				e += r * r * r * ridge_amp[i]
				if ha > 1.0:
					e += detail[i] * (0.3 + ha * 0.12)
				# What this landscape asked for at walking scale, on top of
				# whatever its hills happen to carry (`BiomeDef.relief.near`).
				e += detail[i] * near_amp[i]
				var t := terrace[i]
				# SLOTS: how firmly a slot labyrinth holds this tile. A
				# neighbour's terraces are kept off it: their two-level risers
				# would stair its floors into pieces no body can walk between.
				var hold := 0.0
				if slotted and slot_share[i] > 0.01:
					hold = smoothstep(0.04, 0.16, slot_share[i])
					t *= 1.0 - hold
				if t > 0.01:
					# Plateaus in steps of two levels with short steep risers: scarps.
					# A fixed step climbs tall land as a stair of equal treads, so
					# `shelf` raises the step and `shelf_var` varies it: cliffs
					# between broad shelves. The riser keeps the two-level scarp's
					# height of raw land, so a tall step stands as one face rather
					# than a ramp; the default step keeps its exact bounds.
					var h := 2.0 + shelf_amp[i] * (1.0 + shelf_var[i] * shelfn[i])
					var lo := 0.62 if h == 2.0 else 0.88 - 0.52 / h
					var q := e / h
					var f := q - floorf(q)
					e = lerpf(e, (floorf(q) + smoothstep(lo, 0.88, f)) * h, t)
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
				elif hold > 0.0:
					# The plateau over the slots, at the declared height wherever
					# the landscape holds the ground (not its blend-weighted share
					# of it, so its core walls stand full height), faded across
					# its border in a few tiles; laid after the shore so the shore
					# cannot flatten it, and let down in the last tiles to the sea.
					e += slots[i] / slot_share[i] * hold * slot_up[i] * smoothstep(1.5, 6.0, d_in)
				elev[i] = clampf(e, 1.0, MAX_LEVEL + 0.99)
	)
	c.elev = elev


## Radius in tiles of the caldera rim of the type that has one.
static func crater_radius(c: GenContext) -> float:
	if c.caldera_type < 0:
		return 1.0
	return c.defs[c.caldera_type].caldera * maxf(0.6, c.body_k)


## The soft membership of the type that sinks a caldera, if any.
static func _caldera_soft(c: GenContext) -> PackedFloat32Array:
	if c.caldera_type >= 0:
		return c.soft[c.caldera_type]
	var empty := PackedFloat32Array()
	empty.resize(c.cw * c.cw)
	return empty


## Where a slot labyrinth may stand: every type that asks for one.
static func _slotted_soft(c: GenContext) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(c.cw * c.cw)
	for cc: int in c.land_types:
		if c.defs[cc].param(&"slots") <= 0.0:
			continue
		var s := c.soft[cc]
		for k in out.size():
			out[k] += s[k]
	return out


## Where dunes may ridge up behind the bays: every type that makes them.
static func _dunes_soft(c: GenContext) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(c.cw * c.cw)
	for cc: int in c.land_types:
		if not c.defs[cc].dunes:
			continue
		var s := c.soft[cc]
		for k in out.size():
			out[k] += s[k]
	return out


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
