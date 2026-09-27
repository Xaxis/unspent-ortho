class_name GenSurface
## Stage 11: what every tile's surface is made of.
##
## Grounds are washes, not salad. Each landscape type's recipe (`BiomeDef.surface`,
## in its own file under src/content/biomes/) reads only fields that are smooth
## at the scale of a walk: `big` (1/48) for where a ground masses, float
## elevation and `rise` (how far the land stands above the land around it, from
## float elevation so it drapes across terrace edges), the woodland field, and
## distances (to the sea, to a cliff foot, to a river, to a pool). No per-tile
## noise and no integer level decides a field ground. Geometric grounds
## (beaches, scree aprons, pool rims, marsh) are bands at least two tiles deep.
##
## In an ecotone a tile follows its second type's recipe where the warped patch
## field falls under the blend, so the neighbour arrives in islands and tongues
## that thin away from the border. How far each type's ground travels is its own
## (`reach_out_thin`, `reach_out_high`, `reach_in_thin`, `reach_in_low`): snow
## creeps down only on high ground, ash drifts out thinner than anything else.
## Villages have their own recipe: a cleared ground with a ragged edge and a
## square in the middle.
##
## GenTidy then merges specks, mode-filters and takes the stair notches out,
## so ground edges are long curves the terrain mesher can draw.

## Polar grid of a caldera's lava flows: angle bins by radius bins.
const FLOW_ANGLES := 360
const FLOW_RADII := 96
## Tiles per radius bin: the flows are long tongues running out of the caldera.
const FLOW_BIN := 4.0
## Tiles past a village's core over which its grazing gives way to the wild.
const TENDED := 12.0


## How far round its own tiles a section lays the surface to lay them as the
## whole world does: the step fields reach 9, a cliff's foot 1, and the tidy
## GenTidy.MARGIN beyond the ground they settle (tests/stream/test_surface_sections.gd).
const MARGIN := 40


static func run(c: GenContext) -> void:
	var rules := prepare(c)
	window(c, rules, Rect2i(0, 0, c.size, c.size), 0)


## One section's surface: the tiles of `core`, laid from a window MARGIN wider
## all round, written into the world's ground, recipe, rise, forest and sea
## steps. `rules` is `prepare`'s, made once for every section.
static func section(c: GenContext, rules: Dictionary, core: Rect2i) -> void:
	window(c, rules, core, MARGIN)


## What every section's surface shares: the per-type rules flattened for the
## tile loop, the caldera's flows, and the world's surface arrays to write into.
static func prepare(c: GenContext) -> Dictionary:
	var n := c.n
	c.recipe = PackedByteArray()
	c.recipe.resize(n)
	c.rise = PackedFloat32Array()
	c.rise.resize(n)
	c.forest = PackedFloat32Array()
	c.forest.resize(n)
	c.sea_steps = PackedByteArray()
	c.sea_steps.resize(n)
	# Lava flows run out from the caldera: noise on a polar grid, stretched
	# along the radius, wrapping round the angle.
	var flow_noise := GenFields.noise(c.s, 507, 1.0 / 20.0, 1)
	var flow_img := flow_noise.get_seamless_image(FLOW_ANGLES, FLOW_RADII, false, false, 0.1, false)
	flow_img.convert(Image.FORMAT_RF)
	# Ecotone islands: warped, so a neighbour arrives in long tongues and
	# drifts rather than round blots.
	var patch_noise := GenFields.noise(c.s, 503, 1.0 / 22.0, 2)
	patch_noise.domain_warp_enabled = true
	patch_noise.domain_warp_amplitude = 18.0
	patch_noise.domain_warp_frequency = 1.0 / 40.0
	var types := c.types
	var r := {
		"flows": flow_img.get_data().to_float32_array(),
		"big_noise": GenFields.noise(c.s, 501, 1.0 / 48.0, 2),
		"patch_noise": patch_noise,
		"forest_noise": GenFields.noise(c.s, 504, 1.0 / 30.0, 2),
	}
	# The ecotone rules, flattened so the tile loop never touches a BiomeDef.
	var out_thin := PackedFloat32Array()
	var in_thin := PackedFloat32Array()
	var out_high := PackedVector4Array()
	var in_low := PackedVector3Array()
	# The caps on their own, so the tile loop can ask whether a type creeps at
	# all without copying a vector to find out.
	var out_high_cap := PackedFloat32Array()
	var in_low_cap := PackedFloat32Array()
	var plain := PackedInt32Array()
	var rim_g := PackedInt32Array()
	var frozen := PackedByteArray()
	out_thin.resize(types)
	in_thin.resize(types)
	out_high.resize(types)
	in_low.resize(types)
	out_high_cap.resize(types)
	in_low_cap.resize(types)
	plain.resize(types)
	rim_g.resize(types)
	frozen.resize(types)
	var surf: Array[Callable] = []
	for cc in types:
		var d := c.defs[cc]
		out_thin[cc] = d.reach_out_thin
		in_thin[cc] = d.reach_in_thin
		out_high[cc] = d.reach_out_high
		in_low[cc] = d.reach_in_low
		out_high_cap[cc] = d.reach_out_high.w
		in_low_cap[cc] = d.reach_in_low.z
		plain[cc] = d.plain_ground
		rim_g[cc] = d.pool_rim_ground
		frozen[cc] = 1 if d.rivers_freeze else 0
		surf.append(d.surface)
	r["out_thin"] = out_thin
	r["in_thin"] = in_thin
	r["out_high"] = out_high
	r["in_low"] = in_low
	r["out_high_cap"] = out_high_cap
	r["in_low_cap"] = in_low_cap
	r["plain"] = plain
	r["rim_g"] = rim_g
	r["frozen"] = frozen
	r["surf"] = surf
	return r


## The surface over the square `core` grown by `margin`, its core written into
## the world. With no margin over the whole world it works on the world's own
## arrays; a section works on its window's copy of them, where a tile outside
## the world is open sea as the world's own edge is.
static func window(c: GenContext, rules: Dictionary, core: Rect2i, margin: int) -> void:
	var w := c.w
	var size := c.size
	var whole := margin == 0 and core == Rect2i(0, 0, size, size)
	var ox := core.position.x - margin
	var oy := core.position.y - margin
	var side := core.size.x + margin * 2
	var n := side * side
	var s := c.s
	var level: PackedInt32Array = w.level if whole else _cut_i(w.level, size, ox, oy, side, -1)
	var country: PackedByteArray = w.country if whole else _cut_b(w.country, size, ox, oy, side)
	var country2: PackedByteArray = w.country2 if whole else _cut_b(w.country2, size, ox, oy, side)
	var blend: PackedFloat32Array = w.blend if whole else _cut_f(w.blend, size, ox, oy, side)
	var water: PackedByteArray = c.water if whole else _cut_b(c.water, size, ox, oy, side)
	var road: PackedByteArray = c.road if whole else _cut_b(c.road, size, ox, oy, side)
	var site_ground: PackedByteArray = c.site_ground
	if not whole:
		site_ground = PackedByteArray()
		site_ground.resize(n)
		GenScatter.patch_square(c.site_patches, site_ground, country, _cut_b(c.land, size, ox, oy, side), water, road,
			_cut_b(c.village, size, ox, oy, side), side, Vector2i(ox, oy), size)
	var pool_ground: PackedByteArray = c.pool_ground if whole else _cut_b(c.pool_ground, size, ox, oy, side)
	var convex: PackedFloat32Array = c.convex if whole else _cut_f(c.convex, size, ox, oy, side)
	var inland: PackedFloat32Array = c.inland if whole else _cut_f(c.inland, size, ox, oy, side)
	var rim_warp: PackedFloat32Array = c.rim_warp if whole else _cut_f(c.rim_warp, size, ox, oy, side)
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
	GenFields.rows(side, func(y0: int, y1: int) -> void:
		for y in range(y0, y1):
			var wy := oy + y
			for x in side:
				var i := y * side + x
				var wx := ox + x
				var l := level[i]
				sea[i] = 1 if l <= 0 else 0
				var wat := water[i]
				river[i] = 1 if wat == 1 else 0
				still[i] = 1 if wat == 2 else 0
				# Low river water near the sea: salt marsh grows out from it.
				estuary[i] = 1 if wat == 1 and l <= 2 and inland[i] < 16.0 else 0
				if l > 0 and wx > 0 and wy > 0 and wx < size - 1 and wy < size - 1 and x > 0 and y > 0 and x < side - 1 and y < side - 1:
					# The foot of a tall face (three levels or more): scree lies here.
					var up := maxi(maxi(level[i - 1], level[i + 1]), maxi(level[i - side], level[i + side])) - l
					foot[i] = 1 if up >= 3 and wat == 0 else 0
	)
	if whole:
		c.mark(&"surface.masks")
	var steps: Array[PackedByteArray] = [PackedByteArray(), PackedByteArray(), PackedByteArray(), PackedByteArray(), PackedByteArray()]
	GenFields.together([
		func() -> void: steps[0] = GenFields.near_steps(sea, side, 8),
		func() -> void: steps[1] = GenFields.near_steps(estuary, side, 9),
		func() -> void: steps[2] = GenFields.near_steps(foot, side, 3),
		func() -> void: steps[3] = GenFields.near_steps(river, side, 2),
		func() -> void: steps[4] = GenFields.near_steps(still, side, 2),
	])
	var sea_steps := steps[0]
	var marsh := steps[1]
	var foot_steps := steps[2]
	var river_steps := steps[3]
	var pool_steps := steps[4]
	if whole:
		c.sea_steps = sea_steps
		c.mark(&"surface.steps")
	var elev_s: PackedFloat32Array
	var broad: PackedFloat32Array
	var big: PackedFloat32Array
	var patch: PackedFloat32Array
	var forest: PackedFloat32Array
	if whole:
		var fl := GenFields.batch(size, [
			[GenFields.SMOOTH, elev, 2],
			[GenFields.SMOOTH, elev, 4],
			[GenFields.FIELD, rules.big_noise, 8],
			[GenFields.FIELD, rules.patch_noise, 2],
			[GenFields.FIELD, rules.forest_noise, 4],
		])
		elev_s = fl[0]
		broad = fl[1]
		big = fl[2]
		patch = fl[3]
		forest = fl[4]
	else:
		elev_s = GenFields.smooth_rect(elev, size, 2, ox, oy, side, side)
		broad = GenFields.smooth_rect(elev, size, 4, ox, oy, side, side)
		big = GenFields.field_rect(rules.big_noise, size, 8, ox, oy, side, side)
		patch = GenFields.field_rect(rules.patch_noise, size, 2, ox, oy, side, side)
		forest = GenFields.field_rect(rules.forest_noise, size, 4, ox, oy, side, side)
	var rise := c.rise if whole else PackedFloat32Array()
	if not whole:
		rise.resize(n)
	GenFields.rows(side, func(y0: int, y1: int) -> void:
		for i in range(y0 * side, y1 * side):
			rise[i] = elev_s[i] - broad[i]
	)
	if whole:
		c.forest = forest
		c.mark(&"surface.rise")
		c.mark(&"surface.noise")
	var flows: PackedFloat32Array = rules.flows
	var caldera_type := c.caldera_type
	var heart := c.hearts[caldera_type] if caldera_type >= 0 else Vector2(-1, -1)
	var crater := GenRelief.crater_radius(c)
	var spawn := w.spawn
	var tended := PackedFloat32Array()
	tended.resize(n)
	var clearing := _clearings(c, patch, tended, ox, oy, side)
	var recipe := c.recipe if whole else PackedByteArray()
	var ground := w.ground if whole else PackedByteArray()
	if not whole:
		recipe.resize(n)
		ground.resize(n)
	# 1 where the ground is fixed by geometry (sea, water, roads, sites, pool
	# rims): GenTidy never changes these.
	var fixed := PackedByteArray()
	fixed.resize(n)
	if whole:
		c.mark(&"surface.fields")
	var defs := c.defs
	var out_thin: PackedFloat32Array = rules.out_thin
	var in_thin: PackedFloat32Array = rules.in_thin
	var out_high: PackedVector4Array = rules.out_high
	var in_low: PackedVector3Array = rules.in_low
	var out_high_cap: PackedFloat32Array = rules.out_high_cap
	var in_low_cap: PackedFloat32Array = rules.in_low_cap
	var plain: PackedInt32Array = rules.plain
	var rim_g: PackedInt32Array = rules.rim_g
	var frozen: PackedByteArray = rules.frozen
	var surf: Array[Callable] = rules.surf
	GenFields.rows(side, func(y0: int, y1: int) -> void:
		var t := BiomeSurface.new()
		# The two types in play and the recipe change only where the land does,
		# so they are handed over when they change and not once a tile: an
		# assignment costs more than comparing two bytes.
		var last_own := -1
		var last_other := -1
		var last_recipe := -1
		var recipe_fn := surf[0]
		t.crater = crater
		t.size = side
		t.x0 = ox
		t.y0 = oy
		t.seed_value = s
		t.elev = elev_s
		t.rise = rise
		t.big = big
		t.convex = convex
		t.forest = forest
		t.sea_steps = sea_steps
		t.marsh = marsh
		t.levels = level
		t.blends = blend
		for y in range(y0, y1):
			var wy := oy + y
			for x in side:
				var i := y * side + x
				var wx := ox + x
				var l := level[i]
				var own := country[i]
				recipe[i] = own
				# The world's edge is sea; a window's own edge is the margin's, and
				# never laid for keeps.
				if l <= 0 or wx <= 0 or wy <= 0 or wx >= size - 1 or wy >= size - 1 or x == 0 or y == 0 or x == side - 1 or y == side - 1:
					ground[i] = Ground.DEEP_WATER if l < 0 else Ground.WATER
					fixed[i] = 1
					continue
				if road[i] != 0:
					# Roads run into the square and become it.
					ground[i] = Ground.GRAVEL if clearing[i] - float((int(clearing[i]) >> 4) << 4) >= 1.0 else Ground.ROAD
					fixed[i] = 1
					continue
				var wat := water[i]
				if wat == 1:
					ground[i] = Ground.ICE if frozen[own] != 0 and l >= 6 else Ground.RIVER
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
					if out_thin[c2] > 0.0:
						# Ash drifts out thin, and thinner with every tile from the rim.
						pb = bl * near * out_thin[c2]
					elif in_thin[own] > 0.0:
						# Little that is not burnt survives inside the rim: the
						# neighbour's ground reaches in only near the border.
						pb = bl * near * in_thin[own]
					elif out_high_cap[c2] > 0.0:
						# Snow creeps down only the high ground, and only as far as
						# the ecotone reaches: tongues down the ridges.
						var hi_out: Vector4 = out_high[c2]
						pb = near * clampf((e - hi_out.x) * hi_out.y + rs * hi_out.z, 0.0, hi_out.w)
					elif in_low_cap[own] > 0.0:
						# The neighbour climbs the Snowfield's low valleys.
						var lo_in: Vector3 = in_low[own]
						pb = bl * 0.7 + near * clampf((lo_in.x - e) * lo_in.y, 0.0, lo_in.z)
					# The patch field's tails pass 0: never let them cross where
					# the neighbour has no pull.
					if maxf(0.03, 0.5 + patch[i] * 1.2) < pb:
						cc = c2
				recipe[i] = cc
				var ss := sea_steps[i]
				var cv := clearing[i]
				if cv > 0.0:
					# A village clears its ground; the square is trodden bare.
					var vc := int(cv) >> 4
					var part := cv - (vc << 4)
					ground[i] = defs[vc].village_square_ground if part >= 1.0 else defs[vc].village_ground
					recipe[i] = vc
					# The square keeps its drawn edge: roads can leave it in pieces
					# the tidy pass would otherwise sweep away. The cleared ground
					# is kept too: a road can cut a sliver of it off, and the tidy
					# pass would hand the sliver to the wild ground outside.
					fixed[i] = 1
					continue
				var lx := level[i - 1]
				var rx := level[i + 1]
				var uy := level[i - side]
				var dy := level[i + side]
				var down := l - mini(mini(lx, rx), mini(uy, dy))
				var tame := absf(wx + 0.5 - spawn.x) < 4.5 and absf(wy + 0.5 - spawn.y) < 4.5
				var apron := foot_steps[i] <= (1 if gb < 0.15 else 2) and down < 2 and not tame
				var bank := river_steps[i] <= 1
				var rim := pool_steps[i] <= 2
				var shore := ss <= (2 if gb > -0.2 else 1) and l <= 2
				var g := Ground.GRASS
				if rim:
					# Pools lie in a rim of their own shore, whatever the recipe.
					g = rim_g[cc]
				else:
					# Nothing per-tile is written to the sample: see its header.
					if own != last_own:
						last_own = own
						t.own_def = defs[own]
					if c2 != last_other:
						last_other = c2
						t.other_def = defs[c2]
					if cc == caldera_type:
						var fdx := wx + 0.5 - heart.x
						var fdy := wy + 0.5 - heart.y
						t.heart_dist = sqrt(fdx * fdx + fdy * fdy)
						t.rim_dist = t.heart_dist + rim_warp[i] * crater * 0.3
						t.flow = _flow_at(flows, fdx, fdy, t.heart_dist)
					if cc != last_recipe:
						last_recipe = cc
						recipe_fn = surf[cc]
					g = recipe_fn.call(t, i, e, rs, gb, (BiomeSurface.SHORE if shore else 0) | (BiomeSurface.APRON if apron else 0) | (BiomeSurface.BANK if bank else 0))
				if cc != own and bl < 0.32 and not shore and not rim:
					# Out in the far half of an ecotone the neighbour arrives as its
					# plain wash first; its dark and broken grounds (peat hags, mud,
					# heath, scree) only come in toward the border, so the land turns
					# by degrees instead of wearing blotches of the next landscape.
					if g == Ground.PEAT or g == Ground.MUD or g == Ground.HEATH or g == Ground.SCREE or g == Ground.ROCK or g == Ground.GRAVEL or g == Ground.PAN or g == Ground.SWARF:
						g = plain[cc]
				var td := tended[i]
				if td > 0.0 and not shore and td > 0.45 + patch[i] * 0.6:
					# Round a village the wild grounds give way to grazing, raggedly.
					if g == Ground.HEATH or g == Ground.SCREE or g == Ground.ROCK or g == Ground.CLINKER or g == Ground.PEAT or g == Ground.MUD or g == Ground.GRAVEL:
						g = defs[cc].village_ground
				if rim:
					fixed[i] = 1
				ground[i] = g
				# Water a recipe laid is laid on purpose, like a pool's: the tidy
				# passes smooth washes of ground, and let loose on water they
				# spread it onto the tiles round it, over terrace lips it cannot
				# stand on (the drowned city's streets, GEN 33).
				if Ground.is_water(g):
					fixed[i] = 1
	)
	if whole:
		c.mark(&"surface.tiles")
	GenTidy.tidy(ground, recipe, fixed, side, c if whole else null)
	if whole:
		c.mark(&"surface.tidy")
		return
	# The section's own tiles, into the world.
	for y in core.size.y:
		var k := (margin + y) * side + margin
		var j := (core.position.y + y) * size + core.position.x
		for x in core.size.x:
			w.ground[j + x] = ground[k + x]
			c.recipe[j + x] = recipe[k + x]
			c.rise[j + x] = rise[k + x]
			c.forest[j + x] = forest[k + x]
			c.sea_steps[j + x] = sea_steps[k + x]


## A square of the world `side` wide at (ox, oy), `outside` where it leaves the world.
static func _cut_i(a: PackedInt32Array, size: int, ox: int, oy: int, side: int, outside: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(side * side)
	out.fill(outside)
	for y in side:
		var wy := oy + y
		if wy < 0 or wy >= size:
			continue
		for x in side:
			var wx := ox + x
			if wx >= 0 and wx < size:
				out[y * side + x] = a[wy * size + wx]
	return out


static func _cut_b(a: PackedByteArray, size: int, ox: int, oy: int, side: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(side * side)
	for y in side:
		var wy := oy + y
		if wy < 0 or wy >= size:
			continue
		for x in side:
			var wx := ox + x
			if wx >= 0 and wx < size:
				out[y * side + x] = a[wy * size + wx]
	return out


static func _cut_f(a: PackedFloat32Array, size: int, ox: int, oy: int, side: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(side * side)
	for y in side:
		var wy := oy + y
		if wy < 0 or wy >= size:
			continue
		for x in side:
			var wx := ox + x
			if wx >= 0 and wx < size:
				out[y * side + x] = a[wy * size + wx]
	return out


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


## Village clearings: 0 outside; otherwise type * 16 plus 0.5 on the cleared
## ground (its edge ragged with the patch field) or 1 on the square. Written per
## village over a box, so it costs nothing where there are none.
static func _clearings(c: GenContext, patch: PackedFloat32Array, tended: PackedFloat32Array, ox: int, oy: int, side: int) -> PackedFloat32Array:
	var w := c.w
	var size := c.size
	var out := PackedFloat32Array()
	out.resize(side * side)
	var reach := ceili(GenSettle.CORE + TENDED)
	for v in w.villages:
		var vp: Vector2 = v.pos
		var vc: int = v.country
		var cx := floori(vp.x)
		var cy := floori(vp.y)
		if cx + reach < ox or cy + reach < oy or cx - reach >= ox + side or cy - reach >= oy + side:
			continue
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var x := cx + dx
				var y := cy + dy
				if x < 1 or y < 1 or x >= size - 1 or y >= size - 1:
					continue
				if x < ox or y < oy or x >= ox + side or y >= oy + side:
					continue
				var wi := y * size + x
				if c.land[wi] == 0 or c.water[wi] != 0:
					continue
				var i := (y - oy) * side + (x - ox)
				var p := Vector2(x + 0.5, y + 0.5) - vp
				var d := p.length()
				tended[i] = maxf(tended[i], 1.0 - smoothstep(GenSettle.CORE * 0.8, GenSettle.CORE + TENDED, d))
				var sq := GenSettle.square_radius(c, v, p.angle())
				if d < sq:
					out[i] = vc * 16 + 1.0
					continue
				# The cleared ground's edge wanders with the patch field.
				var edge := maxf(8.6, GenSettle.CORE * (1.0 + patch[i] * 0.5))
				if d < edge and out[i] == 0.0:
					out[i] = vc * 16 + 0.5
	return out
