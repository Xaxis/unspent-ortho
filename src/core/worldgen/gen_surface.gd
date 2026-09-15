class_name GenSurface
## Stage 11: what every tile's surface is made of.
##
## Grounds are washes, not salad. Each country's recipe reads only fields that
## are smooth at the scale of a walk: `big` (1/48) for where a ground masses,
## float elevation and `rise` (how far the land stands above the land around
## it, from float elevation so it drapes across terrace edges), the woodland
## field, and distances (to the sea, to a cliff foot, to a river, to a pool).
## No per-tile noise and no integer level decides a field ground. Geometric
## grounds (beaches, scree aprons, pool rims, marsh) are bands at least two
## tiles deep.
##
## In an ecotone a tile follows its second country's recipe where the warped
## patch field falls under the blend, so the neighbour arrives in islands and
## tongues that thin away from the border. Snow creeps down only on high
## ground and only inside the ecotone; ash drifts out of the Burning thinner
## than anything else. Villages have their own recipe: a cleared ground with a
## ragged edge and a square in the middle.
##
## GenTidy then merges specks, mode-filters and takes the stair notches out,
## so ground edges are long curves the terrain mesher can draw.

## Polar grid of the Burning's lava flows: angle bins by radius bins.
const FLOW_ANGLES := 360
const FLOW_RADII := 96
## Tiles per radius bin: the flows are long tongues running out of the caldera.
const FLOW_BIN := 4.0


static func run(c: GenContext) -> void:
	var w := c.w
	var size := c.size
	var s := c.s
	var n := c.n
	var level := w.level
	var ground := w.ground
	var country := w.country
	var country2 := w.country2
	var blend := w.blend
	var water := c.water
	var road := c.road
	var village := c.village
	var site_ground := c.site_ground
	var pool_ground := c.pool_ground
	var convex := c.convex
	var inland := c.inland
	var elev := c.elev
	var sea := PackedByteArray()
	sea.resize(n)
	var estuary := PackedByteArray()
	estuary.resize(n)
	var foot := PackedByteArray()
	foot.resize(n)
	var river := PackedByteArray()
	river.resize(n)
	var still := PackedByteArray()
	still.resize(n)
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for y in range(y0, y1):
			for x in size:
				var i := y * size + x
				var l := level[i]
				sea[i] = 1 if l <= 0 else 0
				var wat := water[i]
				river[i] = 1 if wat == 1 else 0
				still[i] = 1 if wat == 2 else 0
				# Low river water near the sea: salt marsh grows out from it.
				estuary[i] = 1 if wat == 1 and l <= 2 and inland[i] < 16.0 else 0
				if l > 0 and x > 0 and y > 0 and x < size - 1 and y < size - 1:
					# The foot of a tall face (three levels or more): scree lies here.
					var up := maxi(maxi(level[i - 1], level[i + 1]), maxi(level[i - size], level[i + size])) - l
					foot[i] = 1 if up >= 3 and wat == 0 else 0
	)
	c.mark(&"surface.masks")
	var steps: Array[PackedByteArray] = [PackedByteArray(), PackedByteArray(), PackedByteArray(), PackedByteArray(), PackedByteArray()]
	GenFields.together([
		func() -> void: steps[0] = GenFields.near_steps(sea, size, 8),
		func() -> void: steps[1] = GenFields.near_steps(estuary, size, 9),
		func() -> void: steps[2] = GenFields.near_steps(foot, size, 3),
		func() -> void: steps[3] = GenFields.near_steps(river, size, 2),
		func() -> void: steps[4] = GenFields.near_steps(still, size, 2),
	])
	c.sea_steps = steps[0]
	var sea_steps := steps[0]
	var marsh := steps[1]
	var foot_steps := steps[2]
	var river_steps := steps[3]
	var pool_steps := steps[4]
	c.mark(&"surface.steps")
	var elev_s := GenFields.smooth(elev, size, 2)
	var broad := GenFields.smooth(elev, size, 4)
	c.rise = PackedFloat32Array()
	c.rise.resize(n)
	var rise := c.rise
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for i in range(y0 * size, y1 * size):
			rise[i] = elev_s[i] - broad[i]
	)
	c.mark(&"surface.rise")
	var big := GenFields.field(GenFields.noise(s, 501, 1.0 / 48.0, 2), size, 8)
	# Ecotone islands: warped, so a neighbour arrives in long tongues and
	# drifts rather than round blots.
	var patch_noise := GenFields.noise(s, 503, 1.0 / 22.0, 2)
	patch_noise.domain_warp_enabled = true
	patch_noise.domain_warp_amplitude = 18.0
	patch_noise.domain_warp_frequency = 1.0 / 40.0
	var patch := GenFields.field(patch_noise, size, 2)
	c.forest = GenFields.field(GenFields.noise(s, 504, 1.0 / 30.0, 2), size, 4)
	var forest := c.forest
	c.mark(&"surface.noise")
	# Lava flows run out from the caldera: noise on a polar grid, stretched
	# along the radius, wrapping round the angle.
	var flow_noise := GenFields.noise(s, 507, 1.0 / 20.0, 1)
	var flow_img := flow_noise.get_seamless_image(FLOW_ANGLES, FLOW_RADII, false, false, 0.1, false)
	flow_img.convert(Image.FORMAT_RF)
	var flows := flow_img.get_data().to_float32_array()
	var heart := c.hearts[Country.BURNING]
	var crater := GenRelief.crater_radius(c)
	var spawn := w.spawn
	var rim_warp := c.rim_warp
	var clearing := _clearings(c, patch)
	c.recipe = PackedByteArray()
	c.recipe.resize(n)
	var recipe := c.recipe
	# 1 where the ground is fixed by geometry (sea, water, roads, sites, pool
	# rims): GenTidy never changes these.
	var fixed := PackedByteArray()
	fixed.resize(n)
	c.mark(&"surface.fields")
	const COAST := Country.COAST
	const MOSS := Country.MOSS
	const PINEWOOD := Country.PINEWOOD
	const SNOWFIELD := Country.SNOWFIELD
	const BONELANDS := Country.BONELANDS
	const BURNING := Country.BURNING
	const G_GRASS := Ground.GRASS
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for y in range(y0, y1):
			for x in size:
				var i := y * size + x
				var l := level[i]
				var own := country[i]
				recipe[i] = own
				if l <= 0 or x == 0 or y == 0 or x == size - 1 or y == size - 1:
					ground[i] = Ground.DEEP_WATER if l < 0 else Ground.WATER
					fixed[i] = 1
					continue
				if road[i] != 0:
					ground[i] = Ground.ROAD
					fixed[i] = 1
					continue
				var wat := water[i]
				if wat == 1:
					ground[i] = Ground.ICE if own == SNOWFIELD and l >= 6 else Ground.RIVER
					fixed[i] = 1
					continue
				if wat == 2:
					ground[i] = pool_ground[i]
					fixed[i] = 1
					continue
				if site_ground[i] != 0:
					ground[i] = site_ground[i] - 1
					fixed[i] = 1
					continue
				var cc := own
				var bl := blend[i]
				var c2 := country2[i]
				var e := elev_s[i]
				var rs := rise[i]
				var gb := big[i]
				if bl > 0.0:
					var pb := bl
					var near := bl * 2.0
					if c2 == BURNING:
						# Ash drifts out thin, and thinner with every tile from the rim.
						pb = bl * near * 0.28
					elif c2 == SNOWFIELD:
						# Snow creeps down only the high ground, and only as far as
						# the ecotone reaches: tongues down the ridges.
						pb = near * clampf((e - 6.5) * 0.1 + rs * 0.12, 0.0, 0.45)
					elif own == SNOWFIELD:
						# The neighbour climbs the Snowfield's low valleys.
						pb = bl * 0.7 + near * clampf((6.0 - e) * 0.08, 0.0, 0.3)
					# The patch field's tails pass 0: never let them cross where
					# the neighbour has no pull.
					if maxf(0.03, 0.5 + patch[i] * 1.2) < pb:
						cc = c2
				recipe[i] = cc
				var ss := sea_steps[i]
				var cv := clearing[i]
				if cv > 0.0:
					# A village clears its ground; the square is trodden bare.
					ground[i] = _village_ground(own, cv)
					recipe[i] = own
					continue
				var lx := level[i - 1]
				var rx := level[i + 1]
				var uy := level[i - size]
				var dy := level[i + size]
				var down := l - mini(mini(lx, rx), mini(uy, dy))
				var tame := absf(x + 0.5 - spawn.x) < 4.5 and absf(y + 0.5 - spawn.y) < 4.5
				var apron := foot_steps[i] <= (1 if gb < 0.15 else 2) and down < 2 and not tame
				var bank := river_steps[i] <= 1
				var rim := pool_steps[i] <= 2
				var shore := ss <= (2 if gb > -0.2 else 1) and l <= 2
				var g := G_GRASS
				if rim:
					# Pools lie in a rim of their own shore, whatever the recipe.
					g = Ground.PEAT if cc == MOSS else (Ground.GRAVEL if cc == SNOWFIELD else Ground.MUD)
				elif cc == COAST:
					var cx := convex[i]
					if shore:
						if cx > 0.64:
							g = Ground.MUD
						elif cx < 0.47 or gb > 0.45:
							g = Ground.SHINGLE
						else:
							g = Ground.SAND
					elif apron:
						g = Ground.SHINGLE if l <= 2 else Ground.SCREE
					elif marsh[i] <= 3 + int(maxf(0.0, gb + 0.3) * 6.0) and l <= 2:
						g = Ground.MUD
					elif l <= 3 and cx > 0.5 and ss <= mini(7, 3 + int(maxf(0.0, gb) * 10.0)):
						# Dunes back the sandy bays.
						g = Ground.SAND
					elif e + gb * 3.0 + rs * 0.8 >= 4.4:
						g = Ground.HEATH
					elif rs < -0.55 and gb < -0.2 and e < 3.5:
						g = Ground.MUD
				elif cc == PINEWOOD:
					if shore:
						g = Ground.SHINGLE if gb > 0.0 else Ground.SAND
					elif apron:
						g = Ground.SCREE
					elif bank and gb > 0.25:
						g = Ground.GRAVEL
					elif rs < -0.75 and gb < -0.15:
						# Bog in the bottom of the wood.
						g = Ground.MOSS
					elif forest[i] > -0.15 - rs * 0.05:
						g = Ground.NEEDLES
					elif e >= 9.0 or rs > 1.3 or (c2 == SNOWFIELD and bl > 0.12):
						# Open tops, and the heath the wood thins into below the snow.
						g = Ground.HEATH
				elif cc == MOSS:
					if shore:
						g = Ground.MUD if gb > -0.25 else Ground.SAND
					elif apron:
						g = Ground.PEAT
					elif e >= 5.0 and rs > 0.3 and gb > -0.1:
						g = Ground.HEATH
					elif rs > 0.35 + gb * 0.6 or gb > 0.45:
						# Peat hags stand proud of the fen; peat moor where it masses.
						g = Ground.PEAT
					elif rs < -0.6 and gb < -0.1:
						g = Ground.MUD
					else:
						g = Ground.MOSS
				elif cc == SNOWFIELD:
					if shore:
						g = Ground.ICE if gb > 0.15 else Ground.SHINGLE
					elif apron:
						g = Ground.SCREE
					elif bank:
						g = Ground.GRAVEL
					elif (e >= 11.5 and gb > 0.35) or rs > 1.8 + gb * 0.8:
						# Wind strips the crests to rock.
						g = Ground.ROCK
					elif rs < -0.85 and e < 5.5 and gb < 0.1:
						g = Ground.GRAVEL
					else:
						g = Ground.SNOW
				elif cc == BONELANDS:
					if shore:
						g = Ground.SHINGLE
					elif apron:
						g = Ground.SCREE
					elif bank and gb > 0.0:
						g = Ground.GRAVEL
					elif rs < -0.4 - gb * 0.3:
						# Green dales between the pavements, heath where they widen.
						g = Ground.HEATH if gb > 0.35 else G_GRASS
					elif gb < -0.5:
						g = Ground.GRAVEL
					elif gb > 0.5:
						g = Ground.BONE
					else:
						g = Ground.LIMESTONE
				elif cc == BURNING:
					var fdx := x + 0.5 - heart.x
					var fdy := y + 0.5 - heart.y
					var dist := sqrt(fdx * fdx + fdy * fdy)
					var rim_d := dist + rim_warp[i] * crater * 0.3
					var fv := _flow_at(flows, fdx, fdy, dist)
					if shore:
						g = Ground.CLINKER if gb > 0.0 else Ground.SHINGLE
					elif apron:
						g = Ground.SCREE
					elif fv > 0.65 - (0.1 if rim_d < crater * 0.8 else 0.0) + maxf(0.0, dist - crater * 3.0) * 0.004:
						g = Ground.CLINKER
					elif absf(rim_d - crater) < 2.5 + gb * 3.0:
						g = Ground.ROCK
					elif e >= 9.0 and gb > 0.3:
						g = Ground.ROCK
					else:
						g = Ground.ASH
					if own != BURNING and g != Ground.SCREE:
						# Only the ash travels.
						g = Ground.ASH
				if rim:
					fixed[i] = 1
				ground[i] = g
	)
	c.mark(&"surface.tiles")
	GenTidy.run(c, fixed)
	c.mark(&"surface.tidy")


## Bilinear sample of the polar flow grid at an offset from the caldera's heart.
static func _flow_at(flows: PackedFloat32Array, dx: float, dy: float, dist: float) -> float:
	var fa := (atan2(dy, dx) + PI) / TAU * FLOW_ANGLES
	var fr := minf(dist / FLOW_BIN, FLOW_RADII - 1.001)
	var a0 := floori(fa)
	var r0 := floori(fr)
	var ta := fa - a0
	var tr := fr - r0
	var a1 := posmod(a0 + 1, FLOW_ANGLES)
	a0 = posmod(a0, FLOW_ANGLES)
	var r1 := mini(r0 + 1, FLOW_RADII - 1)
	var top := lerpf(flows[r0 * FLOW_ANGLES + a0], flows[r0 * FLOW_ANGLES + a1], ta)
	var bot := lerpf(flows[r1 * FLOW_ANGLES + a0], flows[r1 * FLOW_ANGLES + a1], ta)
	return lerpf(top, bot, tr)


## Village clearings: 0 outside; in (0, 1) on the cleared ground, fading out
## with a ragged edge; >= 1 on the square. Written per village over a box, so
## it costs nothing where there are no villages.
static func _clearings(c: GenContext, patch: PackedFloat32Array) -> PackedFloat32Array:
	var w := c.w
	var size := c.size
	var out := PackedFloat32Array()
	out.resize(c.n)
	var reach := ceili(GenSettle.CORE + 4.0)
	for v in w.villages:
		var vp: Vector2 = v.pos
		var cx := floori(vp.x)
		var cy := floori(vp.y)
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var x := cx + dx
				var y := cy + dy
				if x < 1 or y < 1 or x >= size - 1 or y >= size - 1:
					continue
				var i := y * size + x
				if c.land[i] == 0 or c.water[i] != 0:
					continue
				var p := Vector2(x + 0.5, y + 0.5) - vp
				var d := p.length()
				var sq := GenSettle.square_radius(c, v, p.angle())
				if d < sq:
					out[i] = 1.0
					continue
				# The cleared ground's edge wanders with the patch field.
				var edge := maxf(8.6, GenSettle.CORE * (1.0 + patch[i] * 0.5))
				if d < edge:
					out[i] = maxf(out[i], 0.5)
	return out


## Ground of a village clearing (cv in (0, 1)) or square (cv >= 1).
static func _village_ground(cc: int, cv: float) -> int:
	if cv >= 1.0:
		# Trodden green in the wet countries, raked gravel in the hard ones.
		return Ground.GRASS if cc == Country.MOSS or cc == Country.PINEWOOD else Ground.GRAVEL
	match cc:
		Country.SNOWFIELD:
			return Ground.SNOW
		Country.BONELANDS:
			return Ground.GRASS
		Country.BURNING:
			return Ground.ASH
		Country.MOSS:
			return Ground.GRASS
		Country.PINEWOOD:
			return Ground.GRASS
	return Ground.GRASS
