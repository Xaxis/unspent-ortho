class_name GenSurface
## Stage 9: what every tile's surface is made of.
##
## Each country has a recipe read from smooth world-position fields (never
## per-tile noise): its broad field (heath uplands, dune fields, peat hags),
## its middle field, a forest field shared with the prop scatter so needles lie
## under pines, and terrain facts (cliff feet take scree, cliff lips rock or
## pavement, banks gravel, shores sand or shingle by bay or headland).
##
## In an ecotone a tile follows its second country's recipe where a patch
## field falls under the blend, so the neighbour arrives in organic islands
## that thicken toward the border. Snow takes high ground first; ash drifts
## further out of the Burning than anything else does.


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
	for i in n:
		sea[i] = 1 if level[i] <= 0 else 0
	c.sea_steps = GenFields.near_steps(sea, size, 8)
	var sea_steps := c.sea_steps
	var big := GenFields.field(GenFields.noise(s, 501, 1.0 / 48.0, 3), size, 8)
	var mid := GenFields.field(GenFields.noise(s, 502, 1.0 / 16.0, 2), size, 4)
	var patch := GenFields.field(GenFields.noise(s, 503, 1.0 / 13.0, 3), size, 2)
	c.forest = GenFields.field(GenFields.noise(s, 504, 1.0 / 30.0, 3), size, 4)
	var forest := c.forest
	var veins := GenFields.noise(s, 505, 1.0 / 24.0, 3)
	var pave := GenFields.field(GenFields.noise(s, 506, 1.0 / 20.0, 2), size, 4)
	var flow := GenFields.noise(s, 507, 1.0 / 9.0, 3)
	var heart := c.hearts[Country.BURNING]
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
	for y in range(1, size - 1):
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
				ground[i] = Ground.ICE if own == Country.SNOWFIELD and l >= 6 else Ground.RIVER
				continue
			if wat == 2:
				if own == Country.MOSS:
					ground[i] = Ground.BLACKWATER
				elif own == Country.SNOWFIELD:
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
				if c2 == Country.SNOWFIELD:
					pb += maxf(0.0, l - 6.0) * 0.08
				elif own == Country.SNOWFIELD:
					pb += maxf(0.0, 5.0 - l) * 0.06
				elif c2 == Country.BURNING:
					pb *= 1.35
				if 0.5 + patch[i] * 1.2 < pb:
					cc = c2
			var ss := sea_steps[i]
			var gb := big[i]
			var gm := mid[i]
			var g := Ground.GRASS
			var tame := village[i] != 0
			if tame:
				up = 0
				down = 0
			match cc:
				Country.COAST:
					var cx := convex[i]
					if ss <= 1 and l <= 2:
						g = Ground.SHINGLE if cx < 0.47 or gm > 0.3 or up >= 2 else Ground.SAND
					elif ss <= 3 and l <= 2 and cx > 0.46:
						g = Ground.SAND
					elif ss <= 7 and l <= 2 and cx > 0.55 and gb > 0.05:
						g = Ground.SAND
					elif up >= 2:
						g = Ground.SCREE
					elif down >= 2 and l >= 5:
						g = Ground.ROCK
					elif bank:
						g = Ground.GRAVEL if gm > -0.1 else Ground.MUD
					elif (l - 3.0) * 0.22 + gb * 1.1 > 0.2:
						g = Ground.HEATH
					elif gb < -0.4 and gm < -0.05 and l <= 2:
						g = Ground.MUD
					else:
						g = Ground.GRASS
				Country.MOSS:
					if ss <= 1:
						g = Ground.MUD if gm > -0.25 else Ground.SAND
					elif up >= 2:
						g = Ground.PEAT
					elif pool:
						g = Ground.PEAT if gm > 0.0 else Ground.MUD
					elif bank:
						g = Ground.MUD
					elif l >= 4 and gb > 0.0:
						g = Ground.HEATH
					elif gm > 0.28:
						g = Ground.PEAT
					elif gb < -0.3:
						g = Ground.MUD
					else:
						g = Ground.MOSS
				Country.PINEWOOD:
					if ss <= 1:
						g = Ground.SHINGLE if gm > 0.0 else Ground.SAND
					elif up >= 2:
						g = Ground.SCREE
					elif down >= 2 and gm > 0.1:
						g = Ground.ROCK
					elif bank:
						g = Ground.GRAVEL
					elif forest[i] > -0.15:
						g = Ground.NEEDLES
					elif l >= 8 or gb > 0.35:
						g = Ground.HEATH
					else:
						g = Ground.GRASS
				Country.SNOWFIELD:
					if ss <= 1:
						g = Ground.ICE if gm > 0.15 else Ground.SHINGLE
					elif up >= 2:
						g = Ground.SCREE
					elif down >= 2 or (l >= 11 and gm > 0.22):
						g = Ground.ROCK
					elif bank:
						g = Ground.GRAVEL
					elif l <= 4 and gb < -0.35:
						g = Ground.GRAVEL
					else:
						g = Ground.SNOW
				Country.BONELANDS:
					if ss <= 1:
						g = Ground.SHINGLE
					elif up >= 2:
						g = Ground.SCREE
					elif down >= 2:
						g = Ground.LIMESTONE
					elif flat and pave[i] > -0.15 and gb > -0.3:
						g = Ground.GRAVEL if absf(veins.get_noise_2d(x, y)) < 0.045 else Ground.LIMESTONE
					elif gb < -0.25:
						g = Ground.GRASS
					elif gm > 0.33:
						g = Ground.HEATH
					elif gb > 0.28:
						g = Ground.BONE
					else:
						g = Ground.GRASS
				Country.BURNING:
					var dx := x - heart.x
					var dy := y - heart.y
					var ang := atan2(dy, dx)
					var radial := 1.0 - absf(flow.get_noise_3d(cos(ang) * 26.0, sin(ang) * 26.0, sqrt(dx * dx + dy * dy) * 0.08))
					if ss <= 1:
						g = Ground.CLINKER if gm > 0.0 else Ground.SHINGLE
					elif up >= 2:
						g = Ground.SCREE
					elif radial > 0.9 or (1.0 - absf(veins.get_noise_2d(x, y))) > 0.95:
						g = Ground.CLINKER
					elif down >= 2 and gm > 0.0:
						g = Ground.ROCK
					elif l >= 8 and gm > 0.35:
						g = Ground.ROCK
					else:
						g = Ground.ASH
					if own != Country.BURNING and g != Ground.SCREE:
						# Only the ash travels.
						g = Ground.ASH
			if tame and (g == Ground.SCREE or g == Ground.ROCK or g == Ground.CLINKER or g == Ground.SHINGLE):
				g = Ground.SNOW if cc == Country.SNOWFIELD else Ground.GRASS
			ground[i] = g
