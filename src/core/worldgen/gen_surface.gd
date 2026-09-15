class_name GenSurface
## Stage 9: what every tile's surface is made of.
##
## Each country has a recipe read from smooth world-position fields, never
## per-tile noise, and from the lie of the land: `rise` is how far a tile
## stands above the ground around it (tops and ridges positive, dales and
## hollows negative), so heath takes the tops, marsh the hollows, pavement the
## plateaus and grass the dales. Terrain facts come first: cliff feet take
## scree, cliff lips rock or pavement, shores sand in bays and shingle on
## headlands, river mouths salt marsh, banks gravel or mud.
##
## In an ecotone a tile follows its second country's recipe where a patch
## field falls under the blend, so the neighbour arrives in organic islands
## that thicken toward the border. Snow takes high ground first; ash drifts
## further out of the Burning than anything else does.

## Polar grid of the Burning's lava flows: angle bins by radius bins (2 tiles).
const FLOW_ANGLES := 360
const FLOW_RADII := 160


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
	var land := c.land
	var water := c.water
	var road := c.road
	var ramp := c.ramp
	var village := c.village
	var site_ground := c.site_ground
	var convex := c.convex
	var sea := PackedByteArray()
	sea.resize(n)
	var levelf := PackedFloat32Array()
	levelf.resize(n)
	var estuary := PackedByteArray()
	estuary.resize(n)
	var inland := c.inland
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for i in range(y0 * size, y1 * size):
			var l := level[i]
			sea[i] = 1 if l <= 0 else 0
			# float(l), not maxf(0.0, l): an int into a float utility takes a
			# slow path that serialises every worker thread.
			levelf[i] = float(l) if l > 0 else 0.0
			# Low river water near the sea: salt marsh grows out from it.
			estuary[i] = 1 if water[i] == 1 and l <= 2 and inland[i] < 16.0 else 0
	)
	c.mark(&"surface.masks")
	c.sea_steps = GenFields.near_steps(sea, size, 8)
	var sea_steps := c.sea_steps
	var marsh := GenFields.near_steps(estuary, size, 9)
	c.mark(&"surface.steps")
	c.rise = GenFields.smooth(levelf, size, 4)
	var rise := c.rise
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for i in range(y0 * size, y1 * size):
			rise[i] = levelf[i] - rise[i]
	)
	c.mark(&"surface.rise")
	var big := GenFields.field(GenFields.noise(s, 501, 1.0 / 48.0, 3), size, 8)
	var mid := GenFields.field(GenFields.noise(s, 502, 1.0 / 16.0, 2), size, 4)
	# Ecotone islands: warped, so a neighbour arrives in long tongues and
	# drifts rather than round blots.
	var patch_noise := GenFields.noise(s, 503, 1.0 / 20.0, 3)
	patch_noise.domain_warp_enabled = true
	patch_noise.domain_warp_amplitude = 18.0
	patch_noise.domain_warp_frequency = 1.0 / 40.0
	var patch := GenFields.field(patch_noise, size, 2)
	c.forest = GenFields.field(GenFields.noise(s, 504, 1.0 / 30.0, 3), size, 4)
	var forest := c.forest
	var veins := GenFields.sample(GenFields.noise(s, 505, 1.0 / 24.0, 3), size, 1)
	var pave := GenFields.field(GenFields.noise(s, 506, 1.0 / 20.0, 2), size, 4)
	c.mark(&"surface.noise")
	# Lava flows run out from the caldera: noise on a polar grid, stretched
	# along the radius, wrapping round the angle.
	var flow_noise := GenFields.noise(s, 507, 1.0 / 7.0, 3)
	var flow_img := flow_noise.get_seamless_image(FLOW_ANGLES, FLOW_RADII, false, false, 0.1, false)
	flow_img.convert(Image.FORMAT_RF)
	var flows := flow_img.get_data().to_float32_array()
	var heart := c.hearts[Country.BURNING]
	var crater := GenRelief.crater_radius(c)
	var plazas := PackedByteArray()
	plazas.resize(n)
	for v in w.villages:
		var vp: Vector2 = v.pos
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var x := floori(vp.x) + dx
				var y := floori(vp.y) + dy
				if w.in_bounds(x, y) and Vector2(x + 0.5, y + 0.5).distance_squared_to(vp) < 7.5:
					plazas[y * size + x] = 1
	c.mark(&"surface.fields")
	const COAST := Country.COAST
	const MOSS := Country.MOSS
	const PINEWOOD := Country.PINEWOOD
	const SNOWFIELD := Country.SNOWFIELD
	const BONELANDS := Country.BONELANDS
	const BURNING := Country.BURNING
	GenFields.rows(size - 1, func(y0: int, y1: int) -> void:
		for y in range(maxi(y0, 1), y1):
			for x in range(1, size - 1):
				var i := y * size + x
				var l := level[i]
				if l <= 0:
					ground[i] = Ground.DEEP_WATER if l < 0 else Ground.WATER
					continue
				if road[i] != 0 or plazas[i] != 0:
					ground[i] = Ground.ROAD
					continue
				if ramp[i] != 0:
					ground[i] = Ground.SCREE
					continue
				var own := country[i]
				var wat := water[i]
				if wat == 1:
					ground[i] = Ground.ICE if own == SNOWFIELD and l >= 6 else Ground.RIVER
					continue
				if wat == 2:
					if own == MOSS:
						ground[i] = Ground.BLACKWATER
					elif own == SNOWFIELD:
						ground[i] = Ground.ICE
					else:
						ground[i] = Ground.RIVER
					continue
				if site_ground[i] != 0:
					ground[i] = site_ground[i] - 1
					continue
				var cc := own
				var bl := blend[i]
				var c2 := country2[i]
				var la := level[i - 1] - l
				var lb := level[i + 1] - l
				var lc := level[i - size] - l
				var ld := level[i + size] - l
				var up := maxi(maxi(la, lb), maxi(lc, ld))
				var down := -mini(mini(la, lb), mini(lc, ld))
				var flat := la == 0 and lb == 0 and lc == 0 and ld == 0
				var wa := water[i - 1]
				var wb := water[i + 1]
				var wc := water[i - size]
				var wd := water[i + size]
				var bank := wa == 1 or wb == 1 or wc == 1 or wd == 1
				var pool := wa == 2 or wb == 2 or wc == 2 or wd == 2
				if bl > 0.0:
					var pb := bl
					if c2 == SNOWFIELD:
						pb += maxf(0.0, l - 6.0) * 0.08
					elif own == SNOWFIELD:
						pb += maxf(0.0, 5.0 - l) * 0.06
					elif c2 == BURNING:
						pb *= 1.0
					if 0.5 + patch[i] * 1.2 < pb:
						cc = c2
				var ss := sea_steps[i]
				var gb := big[i]
				var gm := mid[i]
				var rs := rise[i]
				var tame := village[i] != 0
				if tame:
					up = 0
					down = 0
				var g := Ground.GRASS
				if cc == COAST:
					var cx := convex[i]
					if ss <= 1 and l <= 2:
						if cx > 0.64:
							g = Ground.MUD
						elif cx < 0.47 or up >= 2 or gb > 0.42:
							g = Ground.SHINGLE
						else:
							g = Ground.SAND
					elif up >= 2:
						g = Ground.SCREE
					elif down >= 3 or (down >= 2 and gm > 0.2):
						g = Ground.ROCK
					elif marsh[i] <= 5 + int(gm * 4.0) and l <= 2:
						g = Ground.MUD
					elif bank:
						g = Ground.MUD if l <= 2 else (Ground.GRAVEL if gm > 0.25 else Ground.GRASS)
					elif l <= 3 and cx > 0.5 and ss <= mini(7, 3 + int(maxf(0.0, gb) * 10.0)):
						# Dunes back the sandy bays.
						g = Ground.SAND
					elif l + gb * 2.5 + rs * 0.7 >= 4.2:
						g = Ground.HEATH
					elif rs < -0.6 and gm < 0.0 and l <= 3:
						g = Ground.MUD
				elif cc == PINEWOOD:
					if ss <= 1:
						g = Ground.SHINGLE if gm > 0.0 else Ground.SAND
					elif up >= 2:
						g = Ground.SCREE
					elif down >= 2 and gm > 0.1:
						g = Ground.ROCK
					elif bank:
						g = Ground.GRAVEL if gm > -0.2 else Ground.NEEDLES
					elif rs < -0.8 and gb < -0.15:
						# Bog in the bottom of the wood.
						g = Ground.MOSS
					elif forest[i] > -0.15 - rs * 0.05:
						g = Ground.NEEDLES
					elif l >= 9 or rs > 1.4:
						g = Ground.HEATH
				elif cc == MOSS:
					if ss <= 1:
						g = Ground.MUD if gm > -0.25 else Ground.SAND
					elif up >= 2:
						g = Ground.PEAT
					elif pool:
						g = Ground.PEAT if gm > 0.0 else Ground.MUD
					elif bank:
						g = Ground.MUD
					elif l >= 5 and rs > 0.3 and gb > -0.1:
						g = Ground.HEATH
					elif rs > 0.25 + gm * 0.4:
						# Peat hags stand proud of the fen.
						g = Ground.PEAT
					elif rs < -0.5 and gb < 0.0:
						g = Ground.MUD
					else:
						g = Ground.MOSS
				elif cc == SNOWFIELD:
					if ss <= 1:
						g = Ground.ICE if gm > 0.15 else Ground.SHINGLE
					elif up >= 2:
						g = Ground.SCREE
					elif down >= 2 or (l >= 11 and gm > 0.25) or rs > 1.6 + gm:
						# Wind strips the crests and lips to rock.
						g = Ground.ROCK
					elif bank:
						g = Ground.GRAVEL
					elif rs < -0.9 and l <= 5 and gb < 0.1:
						g = Ground.GRAVEL
					else:
						g = Ground.SNOW
				elif cc == BONELANDS:
					if ss <= 1:
						g = Ground.SHINGLE
					elif up >= 2:
						g = Ground.SCREE
					elif down >= 2:
						g = Ground.LIMESTONE
					elif bank or rs < -0.45 - pave[i] * 0.3:
						# Green dales between the pavements, heath up their sides.
						g = Ground.HEATH if rs > -0.6 and gm > 0.25 else Ground.GRASS
					elif flat and l >= 3:
						g = Ground.GRAVEL if absf(veins[i]) < 0.05 else Ground.LIMESTONE
					elif gb > 0.5:
						g = Ground.BONE
					else:
						g = Ground.LIMESTONE if rs > -0.1 else Ground.GRASS
				elif cc == BURNING:
					var dx := x + 0.5 - heart.x
					var dy := y + 0.5 - heart.y
					var dist := sqrt(dx * dx + dy * dy)
					var ai := posmod(floori((atan2(dy, dx) + PI) / TAU * FLOW_ANGLES), FLOW_ANGLES)
					var ri := mini(FLOW_RADII - 1, floori(dist * 0.5))
					var fv := flows[ri * FLOW_ANGLES + ai]
					var in_crater := dist < crater * 0.8
					if ss <= 1:
						g = Ground.CLINKER if gm > 0.0 else Ground.SHINGLE
					elif up >= 2:
						g = Ground.SCREE
					elif fv > 0.64 - (0.12 if in_crater else 0.0) or (1.0 - absf(veins[i])) > 0.96:
						g = Ground.CLINKER
					elif down >= 2 and gm > -0.1:
						g = Ground.ROCK
					elif absf(dist - crater) < 3.0 + gm * 3.0:
						g = Ground.ROCK
					elif l >= 9 and gm > 0.3:
						g = Ground.ROCK
					else:
						g = Ground.ASH
					if own != BURNING and g != Ground.SCREE:
						# Only the ash travels.
						g = Ground.ASH
				if tame and (g == Ground.SCREE or g == Ground.ROCK or g == Ground.CLINKER or g == Ground.SHINGLE or g == Ground.MUD):
					g = Ground.SNOW if cc == SNOWFIELD else Ground.GRASS
				ground[i] = g
	)
