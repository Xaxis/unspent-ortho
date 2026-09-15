class_name GenCountries
## Stage 2 (coarse layout) and stage 5 (tiles, ecotones): where each country is.
##
## The island is laid out as a JOURNEY. The Coast holds the south shore where
## the player wakes; a middle belt (Moss, Pinewood, Bonelands) crosses the
## island's waist; the far north is Snowfield and the Burning. Sites follow a
## template (mirrored and jittered per seed, fitted to the island's extent),
## countries are a warped power diagram of their sites, and additive weights
## are balanced on the coarse grid until every country holds its share.
##
## Tiles then take the best two countries, fingered by noise so borders
## interleave, with snow pulled down onto high ground and ash blown further out
## of the Burning than anything else travels. country2/blend record the second
## country and how far toward it a tile has turned (0.5 on the border).

const TARGET: PackedFloat32Array = [0.0, 0.35, 0.13, 0.13, 0.13, 0.13, 0.13]

## Relief and climate by country id (sea, coast, moss, pinewood, snowfield,
## bonelands, burning). Levels are WorldData levels.
const BASE: PackedFloat32Array = [0.0, 2.6, 1.3, 4.4, 7.8, 5.8, 4.6]
const HILLS: PackedFloat32Array = [0.0, 3.4, 0.7, 4.2, 3.0, 2.4, 2.0]
const RIDGE: PackedFloat32Array = [0.0, 1.0, 0.0, 2.2, 6.5, 0.6, 1.8]
const TERRACE: PackedFloat32Array = [0.0, 0.0, 0.0, 0.0, 0.2, 1.0, 0.25]
## Cost in levels per tile of a river valley's side: low is a broad vale, high a gorge.
const VALLEY: PackedFloat32Array = [0.5, 0.42, 0.3, 0.55, 0.85, 1.25, 0.7]
const RAIN: PackedFloat32Array = [0.0, 1.0, 1.35, 1.2, 1.1, 0.45, 0.12]
const TEMP: PackedFloat32Array = [0.5, 0.58, 0.46, 0.36, 0.08, 0.5, 0.95]
const MOIST: PackedFloat32Array = [1.0, 0.55, 0.92, 0.66, 0.5, 0.22, 0.08]
## Headland cliff tendency.
const CLIFF: PackedFloat32Array = [0.0, 0.0, -0.6, 0.1, 0.3, 0.45, 0.2]

const PARAMS := [&"base", &"hills", &"ridge", &"terrace", &"valley", &"rain", &"temp", &"moist", &"cliff"]


static func coarse(c: GenContext) -> void:
	var rng := Rng.make(c.s, 201)
	var sites := _sites(c, rng)
	var cw := c.cw
	var cn := cw * cw
	var step := GenContext.STEP
	var size := c.size
	var warp := GenFields.noise(c.s, 202, 1.0 / (190.0 * c.k), 3)
	var wamp := 58.0 * c.k
	var own: Array[FastNoiseLite] = []
	for cc in Country.COUNT:
		own.append(GenFields.noise(c.s, 210 + cc, 1.0 / (90.0 * c.k), 3))
	var oamp := 38.0 * c.k
	# dist[cc * cn + k]: warped distance from cell k to country cc's nearest site.
	var dist := PackedFloat32Array()
	dist.resize(Country.COUNT * cn)
	dist.fill(1e9)
	var land := c.land
	var landc := PackedByteArray()
	landc.resize(cn)
	var wx := GenFields.sample(warp, cw, step)
	var wy := GenFields.sample(warp, cw, step, 613.0, -287.0)
	var own_fields: Array[PackedFloat32Array] = []
	for cc in Country.COUNT:
		own_fields.append(GenFields.sample(own[cc], cw, step) if cc != Country.SEA else PackedFloat32Array())
	var site_xyz := PackedVector3Array(sites)
	GenFields.rows(cw, func(g0: int, g1: int) -> void:
		for gy in range(g0, g1):
			var ty := GenFields.cell_centre(gy, step)
			for gx in cw:
				var tx := GenFields.cell_centre(gx, step)
				var k := gy * cw + gx
				var ix := clampi(roundi(tx), 0, size - 1)
				var iy := clampi(roundi(ty), 0, size - 1)
				landc[k] = land[iy * size + ix]
				var px := tx + wx[k] * wamp
				var py := ty + wy[k] * wamp
				for site in site_xyz:
					var dx := px - site.x
					var dy := py - site.y
					var d := sqrt(dx * dx + dy * dy)
					var j := int(site.z) * cn + k
					if d < dist[j]:
						dist[j] = d
				for cc in range(1, Country.COUNT):
					dist[cc * cn + k] += own_fields[cc][k] * oamp
	)
	# Balance additive weights so shares hit TARGET: coarse passes on every
	# other cell, then fine passes on every land cell.
	var weight := PackedFloat32Array()
	weight.resize(Country.COUNT)
	for it in 40:
		var sparse := it < 30
		var gain := size * (0.5 if sparse else 0.3)
		var counts := _assign_counts(dist, weight, landc, cw, sparse)
		var total := 0.0
		for cc in Country.COUNT:
			total += counts[cc]
		total = maxf(1.0, total)
		for cc: int in Country.LAND:
			weight[cc] += (TARGET[cc] - counts[cc] / total) * gain
	c.scores.clear()
	c.soft.clear()
	var flat := PackedFloat32Array()
	flat.resize(Country.COUNT * cn)
	# Soft membership for blending relief and climate: broad, so a mountain
	# range rises over many tiles rather than at a border line.
	var temp := 22.0
	var softm := PackedFloat32Array()
	softm.resize(Country.COUNT * cn)
	GenFields.rows(cw, func(g0: int, g1: int) -> void:
		for k in range(g0 * cw, g1 * cw):
			var top := -1e9
			for cc in range(1, Country.COUNT):
				var v := weight[cc] - dist[cc * cn + k]
				flat[cc * cn + k] = v
				top = maxf(top, v)
			var sum := 0.0
			for cc in range(1, Country.COUNT):
				var e := exp((weight[cc] - dist[cc * cn + k] - top) / temp)
				softm[cc * cn + k] = e
				sum += e
			for cc in range(1, Country.COUNT):
				softm[cc * cn + k] /= sum
	)
	for cc in Country.COUNT:
		c.scores.append(flat.slice(cc * cn, (cc + 1) * cn))
		c.soft.append(softm.slice(cc * cn, (cc + 1) * cn))
	c.hearts.clear()
	for cc in Country.COUNT:
		c.hearts.append(Vector2(-1, -1))
	for site: Vector3 in sites:
		if c.hearts[int(site.z)].x < 0.0:
			c.hearts[int(site.z)] = Vector2(site.x, site.y)


## Land cells each country would win with these weights (every other cell
## in each direction when sparse).
static func _assign_counts(dist: PackedFloat32Array, weight: PackedFloat32Array, landc: PackedByteArray, cw: int, sparse: bool) -> PackedInt32Array:
	var cn := cw * cw
	var band := 12
	var parts: Array[PackedInt32Array] = []
	parts.resize(ceili(float(cw) / band))
	GenFields.rows(cw, func(g0: int, g1: int) -> void:
		var counts := PackedInt32Array()
		counts.resize(Country.COUNT)
		for gy in range(g0, g1):
			if sparse and gy % 2 != 0:
				continue
			var gstep := 2 if sparse else 1
			for gx in range(0, cw, gstep):
				var k := gy * cw + gx
				if landc[k] == 0:
					continue
				var best := 1
				var best_v := -1e12
				for cc in range(1, Country.COUNT):
					var v := weight[cc] - dist[cc * cn + k]
					if v > best_v:
						best_v = v
						best = cc
				counts[best] += 1
		parts[g0 / band] = counts
	, band)
	var total := PackedInt32Array()
	total.resize(Country.COUNT)
	for part in parts:
		for cc in Country.COUNT:
			total[cc] += part[cc]
	return total


## Journey template: x = u across the island's extent, y = v down it, z = country.
static func _sites(c: GenContext, rng: RandomNumberGenerator) -> Array[Vector3]:
	var middle: Array[int] = [Country.MOSS, Country.PINEWOOD, Country.BONELANDS]
	if rng.randf() < 0.4:
		middle = [Country.PINEWOOD, Country.MOSS, Country.BONELANDS]
	var raw: Array[Vector3] = [
		# The first site of a country is its heart.
		Vector3(0.5, 0.87, Country.COAST),
		Vector3(0.17, 0.82, Country.COAST),
		Vector3(0.83, 0.82, Country.COAST),
		Vector3(0.17, 0.53, middle[0]),
		Vector3(0.5, 0.52, middle[1]),
		Vector3(0.83, 0.53, middle[2]),
		Vector3(0.3, 0.19, Country.SNOWFIELD),
		Vector3(0.73, 0.2, Country.BURNING),
	]
	# Optional second sites give each seed its own silhouette.
	if rng.randf() < 0.5:
		raw.append(Vector3(0.5, 0.33, Country.PINEWOOD))
	if rng.randf() < 0.5:
		raw.append(Vector3(0.1, 0.34, Country.SNOWFIELD))
	if rng.randf() < 0.5:
		raw.append(Vector3(0.9, 0.36, Country.BURNING))
	var mirror := rng.randf() < 0.5
	var r := c.land_rect
	var out: Array[Vector3] = []
	for p in raw:
		var u := p.x + rng.randf_range(-0.05, 0.05)
		var v := p.y + rng.randf_range(-0.035, 0.035)
		if mirror:
			u = 1.0 - u
		out.append(Vector3(r.position.x + u * r.size.x, r.position.y + v * r.size.y, p.z))
	return out


## Upsample the named per-country parameters to tile resolution.
static func params(c: GenContext, names: Array) -> Dictionary:
	var tables := {
		&"base": BASE, &"hills": HILLS, &"ridge": RIDGE, &"terrace": TERRACE, &"valley": VALLEY,
		&"rain": RAIN, &"temp": TEMP, &"moist": MOIST, &"cliff": CLIFF,
	}
	var cw := c.cw
	var cn := cw * cw
	var out := {}
	var soft := c.soft
	for name: StringName in names:
		var table: PackedFloat32Array = tables[name]
		var g := PackedFloat32Array()
		g.resize(cn)
		GenFields.rows(cw, func(g0: int, g1: int) -> void:
			for k in range(g0 * cw, g1 * cw):
				var v := 0.0
				for cc in range(1, Country.COUNT):
					v += soft[cc][k] * table[cc]
				g[k] = v
		)
		out[name] = g
	return out


static func upsample_params(c: GenContext, names: Array) -> Dictionary:
	var coarse_params := params(c, names)
	var out := {}
	for name: StringName in names:
		out[name] = GenFields.upsample(coarse_params[name], c.cw, GenContext.STEP, c.size)
	return out



## Tiles take their country, second country and blend.
##
## The smooth margin between a tile's best two countries (scores, plus snow
## pulled onto high ground, plus pinewood tongues into the moss) is divided by
## its gradient, so it reads as distance to the border in tiles however the
## warps have stretched the field. Finger noise then shifts the border itself,
## and blend falls from 0.5 there to 0 over 12-24 tiles (wider where ash blows
## out of the Burning).
static func fine(c: GenContext) -> void:
	var w := c.w
	var size := c.size
	var cw := c.cw
	var step := GenContext.STEP
	var sc: Array[PackedFloat32Array] = [PackedFloat32Array()]
	for cc in range(1, Country.COUNT):
		sc.append(GenFields.upsample(c.scores[cc], cw, step, size))
	var s1 := sc[1]
	var s2 := sc[2]
	var s3 := sc[3]
	var s4 := sc[4]
	var s5 := sc[5]
	var s6 := sc[6]
	var finger := GenFields.field(GenFields.noise(c.s, 221, 1.0 / 15.0, 3), size, 2)
	var tongue := GenFields.field(GenFields.noise(c.s, 222, 1.0 / 34.0, 2, FastNoiseLite.TYPE_PERLIN), size, 4)
	var widen := GenFields.field(GenFields.noise(c.s, 223, 1.0 / 70.0, 2), size, 8)
	var elev := c.elev
	var land := c.land
	var country := w.country
	var country2 := w.country2
	var blend := w.blend
	# Coarse pass: climate (with a lapse rate), the leading country for sea
	# tiles, and the margin's gradient in score units per tile.
	var coarse_p := params(c, [&"temp", &"moist"])
	var ct: PackedFloat32Array = coarse_p[&"temp"]
	var top1 := PackedByteArray()
	top1.resize(cw * cw)
	var cpair := PackedByteArray()
	cpair.resize(cw * cw)
	var cn := cw * cw
	var ms := PackedFloat32Array()
	for cc in Country.COUNT:
		ms.append_array(c.scores[cc])
	var ce := PackedFloat32Array()
	ce.resize(cn)
	var ctg := PackedFloat32Array()
	ctg.resize(cn)
	for gy in cw:
		var ty := clampi(roundi(GenFields.cell_centre(gy, step)), 0, size - 1)
		for gx in cw:
			var k := gy * cw + gx
			var tx := clampi(roundi(GenFields.cell_centre(gx, step)), 0, size - 1)
			var e := elev[ty * size + tx]
			ce[k] = e
			ctg[k] = maxf(0.0, tongue[ty * size + tx]) * 30.0
			ct[k] = clampf(ct[k] - maxf(0.0, e - 5.0) * 0.035, 0.0, 1.0)
			var a := 1
			var b := 2
			var sa := ms[cn + k]
			var sb := ms[2 * cn + k]
			if sb > sa:
				a = 2
				b = 1
				var t := sa
				sa = sb
				sb = t
			for cc in range(3, Country.COUNT):
				var v := ms[cc * cn + k]
				if v > sa:
					b = a
					sb = sa
					a = cc
					sa = v
				elif v > sb:
					b = cc
					sb = v
			top1[k] = a
			cpair[k] = mini(a, b) * 8 + maxi(a, b)
	var grad := PackedFloat32Array()
	grad.resize(cn)
	grad.fill(2.0)
	for gy in range(1, cw - 1):
		for gx in range(1, cw - 1):
			var k := gy * cw + gx
			var pk := cpair[k]
			var lo := pk >> 3
			var hi := pk & 7
			var bl := lo * cn
			var bh := hi * cn
			var gxv := (ms[bl + k + 1] - ms[bh + k + 1]) - (ms[bl + k - 1] - ms[bh + k - 1])
			var gyv := (ms[bl + k + cw] - ms[bh + k + cw]) - (ms[bl + k - cw] - ms[bh + k - cw])
			if lo == Country.MOSS and hi == Country.PINEWOOD:
				gxv -= ctg[k + 1] - ctg[k - 1]
				gyv -= ctg[k + cw] - ctg[k - cw]
			elif hi == Country.SNOWFIELD:
				gxv -= (ce[k + 1] - ce[k - 1]) * 2.4
				gyv -= (ce[k + cw] - ce[k - cw]) * 2.4
			elif lo == Country.SNOWFIELD:
				gxv += (ce[k + 1] - ce[k - 1]) * 2.4
				gyv += (ce[k + cw] - ce[k - cw]) * 2.4
			grad[k] = maxf(0.35, sqrt(gxv * gxv + gyv * gyv) * 0.5 / step)
	var grad_t := GenFields.upsample(grad, cw, step, size)
	w.temperature = GenFields.upsample(ct, cw, step, size)
	w.moisture = GenFields.upsample(coarse_p[&"moist"], cw, step, size)
	c.mark(&"tiles.coarse")
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for y in range(y0, y1):
			var row := y * size
			for x in size:
				var i := row + x
				if land[i] == 0:
					country[i] = Country.SEA
					country2[i] = top1[(y / step) * cw + x / step]
					continue
				var v1 := s1[i]
				var v2 := s2[i]
				var a := 1
				var b := 2
				var sa := v1
				var sb := v2
				if v2 > v1:
					a = 2
					b = 1
					sa = v2
					sb = v1
				var v := s3[i]
				if v > sa:
					b = a
					sb = sa
					a = 3
					sa = v
				elif v > sb:
					b = 3
					sb = v
				v = s4[i]
				if v > sa:
					b = a
					sb = sa
					a = 4
					sa = v
				elif v > sb:
					b = 4
					sb = v
				v = s5[i]
				if v > sa:
					b = a
					sb = sa
					a = 5
					sa = v
				elif v > sb:
					b = 5
					sb = v
				v = s6[i]
				if v > sa:
					b = a
					sb = sa
					a = 6
					sa = v
				elif v > sb:
					b = 6
					sb = v
				var lo := mini(a, b)
				var hi := maxi(a, b)
				var m := sa - sb if a == lo else sb - sa
				var amp := 9.0
				if lo == Country.MOSS and hi == Country.PINEWOOD:
					# Tongues of pinewood reach far into the moss along drier ground.
					m -= maxf(0.0, tongue[i]) * 30.0
					amp = 13.0
				elif hi == Country.SNOWFIELD:
					m -= (elev[i] - 6.5) * 2.4
				elif lo == Country.SNOWFIELD:
					m += (elev[i] - 6.5) * 2.4
				# Distance to the border in tiles, the border shifted by the fingers.
				var d := m / grad_t[i] + finger[i] * amp
				if d < 0.0:
					country[i] = hi
					country2[i] = lo
				else:
					country[i] = lo
					country2[i] = hi
	)
	c.mark(&"tiles.assign")
	_blend(c, widen)
	c.mark(&"tiles.blend")


## blend from the true distance to the nearest border, so 0.5 on the border
## always falls to 0 over the stated width however the score fields were
## warped. Borders are found per tile; distance is spread at half resolution
## carrying the pair of countries that meet there, so country2 is the country
## actually across the nearest border (the score runner-up only at a junction).
static func _blend(c: GenContext, widen: PackedFloat32Array) -> void:
	var w := c.w
	var size := c.size
	var country := w.country
	var country2 := w.country2
	var blend := w.blend
	var hw := GenFields.coarse_width(size, 2)
	var hn := hw * hw
	var dist := PackedFloat32Array()
	dist.resize(hn)
	dist.fill(1e4)
	var pair := PackedByteArray()
	pair.resize(hn)
	var edge := PackedByteArray()
	edge.resize(c.n)
	const SEA := Country.SEA
	# Bands are an even number of rows, so each half-resolution cell is written
	# by exactly one band.
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for y in range(y0, y1):
			var row := y * size
			var hrow := (y >> 1) * hw
			for x in size:
				var i := row + x
				var a := country[i]
				if a == SEA:
					continue
				var b := SEA
				if x < size - 1 and country[i + 1] != a:
					b = country[i + 1]
				if b == SEA and y < size - 1 and country[i + size] != a:
					b = country[i + size]
				if b == SEA and x > 0 and country[i - 1] != a:
					b = country[i - 1]
				if b == SEA and y > 0 and country[i - size] != a:
					b = country[i - size]
				if b == SEA:
					continue
				var pk := mini(a, b) * 8 + maxi(a, b)
				edge[i] = pk
				dist[hrow + (x >> 1)] = 0.0
				pair[hrow + (x >> 1)] = pk
	, 12)
	_spread_labelled(dist, pair, hw, 2.0)
	var up := GenFields.upsample(dist, hw, 2, size)
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for y in range(y0, y1):
			var row := y * size
			var hrow := (y >> 1) * hw
			for x in size:
				var i := row + x
				var own := country[i]
				if own == SEA:
					continue
				var pk := edge[i]
				var d := 0.0
				if pk == 0:
					pk = pair[hrow + (x >> 1)]
					d = maxf(0.0, up[i])
				var lo := pk >> 3
				var hi := pk & 7
				var other := country2[i]
				if lo == own:
					other = hi
				elif hi == own:
					other = lo
				country2[i] = other
				var width := 12.0 + 12.0 * clampf(0.5 + widen[i] * 1.4, 0.0, 1.0)
				if other == Country.BURNING:
					# Ash blows further out of the Burning than anything else travels.
					width *= 1.6
				blend[i] = 0.5 - 0.5 * d / width if d < width else 0.0
	)


## Two-sweep 8-neighbour chamfer distance (cell = `unit` tiles) that also
## carries each source's label to the cells it is nearest.
static func _spread_labelled(d: PackedFloat32Array, label: PackedByteArray, width: int, unit: float) -> void:
	var height := d.size() / width
	var dc := unit * 1.4142
	for y in height:
		var row := y * width
		for x in width:
			var i := row + x
			var m := d[i]
			var lb := label[i]
			if x > 0 and d[i - 1] + unit < m:
				m = d[i - 1] + unit
				lb = label[i - 1]
			if y > 0:
				var j := i - width
				if d[j] + unit < m:
					m = d[j] + unit
					lb = label[j]
				if x > 0 and d[j - 1] + dc < m:
					m = d[j - 1] + dc
					lb = label[j - 1]
				if x < width - 1 and d[j + 1] + dc < m:
					m = d[j + 1] + dc
					lb = label[j + 1]
			d[i] = m
			label[i] = lb
	for y in range(height - 1, -1, -1):
		var row := y * width
		for x in range(width - 1, -1, -1):
			var i := row + x
			var m := d[i]
			var lb := label[i]
			if x < width - 1 and d[i + 1] + unit < m:
				m = d[i + 1] + unit
				lb = label[i + 1]
			if y < height - 1:
				var j := i + width
				if d[j] + unit < m:
					m = d[j] + unit
					lb = label[j]
				if x < width - 1 and d[j + 1] + dc < m:
					m = d[j + 1] + dc
					lb = label[j + 1]
				if x > 0 and d[j - 1] + dc < m:
					m = d[j - 1] + dc
					lb = label[j - 1]
			d[i] = m
			label[i] = lb
