class_name GenCountries
## Stage 2 (coarse layout) and stage 4 (tiles, ecotones, regions): which
## landscape type is where.
##
## Every type comes from BiomeRegistry, and nothing about a landscape is written
## here: a type declares where it wants to lie (`anchors` for the island's
## journey, `temp_range`/`moist_range` and `adjacency` for a type placed by its
## climate), how much of the land it wants (`share`), and how its borders behave
## (`border_elevation`, `tongues`). Adding a landscape is adding a file.
##
## Sites are laid first (mirrored and jittered per seed, fitted to the island's
## extent), types are a warped power diagram of their sites, and additive
## weights are balanced on the coarse grid until every type holds its share.
##
## Tiles then take the best two types, fingered by noise so borders interleave.
## country2/blend record the second type and how far toward it a tile has
## turned (0.5 on the border, 0 at 12 to 24 tiles). Finally the connected runs
## of each type are recorded as REGIONS: one type can hold several regions in
## one world, and sentinels, works and subarcs key on their ids.

## Sampled passes that rebalance shares after the borders wander, and the
## sample's stride in tiles.
const BALANCE_PASSES := 3
const BALANCE_STRIDE := 4
## A piece of a type cut off inside another and smaller than this (512 world)
## joins the type round it: a blot of ash in the limestone is noise, not a place.
const ENCLAVE_TILES := 400
## A run of one type smaller than this (512 world) is not its own region.
const REGION_TILES := 220
## AND NO RUN IS A PLACE UNDER THIS, WHATEVER THE WORLD'S SIZE.
##
## A REGION IS A CHAPTER NOW (docs/VISION.md §10: explored, mined and defended
## before the next opens), and it was already the unit a keeper, a depot, a
## landmark round and an interference file key on. Measured, it could be a puddle:
## the floor is `REGION_TILES * body_k * body_k`, and `body_k` is a BODY's scale,
## so it came out at 220 tiles on a 512 island — 15 across, four seconds at
## walking pace — and 31 tiles on a 192 test world, which is five tiles across.
## Worse, it SHRANK as the world grew: 178 at 1024, because `body_k` falls when a
## world gains continents, so the bigger the world the smaller a place was allowed
## to be.
##
## That is `body_k` used for the one question it was never right for. It exists so
## distances scale with the body a thing stands on rather than with the square,
## which is correct for a noise wavelength and for how far apart two villages
## sit. It is wrong for "is this a place", because a place is the same size on a
## continent as on an island: it is measured in a body's own footsteps.
##
## It is stated against the WORLD (`GenContext.k`) and not against a body, so it
## GROWS as the world grows: 1,250 tiles at 512, 5,000 at 1024, 312 at a 256 test
## world. That direction is the whole point — a bigger world should hold bigger
## places, not more of the same small ones, which is exactly what it did while
## this was `body_k` (178 tiles at 1024, smaller than the 220 it allowed at 512).
##
## FLAT 1,250 WAS TRIED FIRST AND IS WRONG, and the suite said so in one run: the
## scrapwood and the slums are about 5% of the land each, so on a 256 world
## neither could raise a single region, and 16% of the land belonged to no place
## at all. A landscape with no region has no keeper, no depot and no chapter — it
## stops being somewhere the game happens. A floor has to be a share of the world
## it is floored in.
##
## The cost, stated because it is a real one: a body too small to hold a place of
## this size holds no region, no keeper and no chapter. For the orbital pebbles of
## docs/WORLD.md §2 that is a design question and not a bug — a rock you cross in
## four seconds was never going to be asked to be explored, mined and defended.
## **AND AT THE SIZE THE GAME SHIPS AT, THIS IS CURRENTLY WRONG. MEASURED
## 2026-09-19, seed 7 at `Tuning.WORLD_SIZE` (1300), which is what every player
## gets:**
##
##   floor 8,059 tiles       five continents, 104,140 to 140,313 tiles each
##   coverage 73.6%          a QUARTER of the land is in no region at all
##   server_fields           26 runs, biggest 6,616  -> NO REGION
##   glass_desert            14 runs, biggest 7,456  -> NO REGION
##
## Two landscapes with no keeper, no depot and no chapter, which the paragraph
## above calls the thing that must not happen -- and both miss by about 1,500
## tiles, so this is a floor just over the height of the world it floors.
##
## THE REASON IS THE ONE `gen_context.gd` ALREADY WROTE DOWN about `k` versus
## `body_k`: "right for one island filling the square; wrong for four continents
## in it". This floor is a share of the SQUARE (`c.k = size / 512`), and it grows
## with the square's AREA -- but a run lies on ONE CONTINENT, and the world did
## not get one bigger island when it grew, it got FIVE. A continent is about 7.7%
## of the 1300 square, so it holds roughly 130,000 tiles across 21 landscapes:
## about 6,600 each. The floor asks for 8,059. It outgrew the bodies it measures.
##
## `body_k` was swapped out for `c.k` because it SHRANK as the world grew (178 at
## 1024, under the 220 it allowed at 512). That was a real bug and the swap fixed
## it. It just swung past the answer: the square grows faster than any single
## body in it, so the floor now overshoots in the other direction.
##
## **NOT FIXED HERE, AND THE COST IS WHY.** `GenScatter` iterates `w.regions` and
## filters props with `region_at` (gen_scatter.gd:110, 140, 159), so ANY change to
## which runs become regions MOVES PROPS. That is a `tests/biome/test_parity.gd`
## re-acceptance, a `WorldStamp.GEN` bump by hand and a re-shoot of every frame
## that stands somewhere by name -- the owner's call to spend, not a builder's.
## The candidates, in the order they were judged:
##
##   PROMOTE        after the floor runs, give any landscape with no region its
##                  own biggest run. Smallest change, and it encodes exactly the
##                  rule this header already states. Does not lift coverage.
##   PER BODY       state the floor as a share of the BODY a run lies on rather
##                  than of the square. Principled, and it is what `body_k`
##                  exists for; the most work and the biggest parity move.
##   FLAT           back to a constant in tiles. Correct at 1300 and the reason
##                  it was rejected is a 256 TEST world, not a shipped one --
##                  `tests/biome/test_regions.gd` runs at 256 and so reports
##                  87-90% where the real number is 73.6%.
##
## Whichever is taken, note the test understates the bug by fifteen points
## because it measures a size nobody plays.
const PLACE_TILES := 1250.0
## The island's climate before any relief exists, for placing a type by its
## envelope: north is cold, the shore is wet, the middle is dry.
const CLIMATE_COLD := 0.78

const PARAMS := [&"base", &"hills", &"ridge", &"near", &"terrace", &"valley", &"rain", &"temp", &"moist", &"cliff"]


## Each land type's share of the land, normalised over the registry.
static func targets(c: GenContext) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(c.types)
	var total := 0.0
	for cc: int in c.land_types:
		total += c.defs[cc].share_target()
	for cc: int in c.land_types:
		out[cc] = c.defs[cc].share_target() / maxf(0.0001, total)
	return out


## A landscape that lies where the island lets it (no anchor) is only placed if
## the island has room for it to be a place: its share of the land must come to
## a region's worth of tiles at walking scale, not a share of a tiny island. A
## small test island is the six of the journey and nothing else.
static func fit_types(c: GenContext) -> void:
	var land := 0
	for v in c.land:
		land += v
	var room := float(REGION_TILES)
	var kept := PackedInt32Array()
	for cc: int in c.land_types:
		var d := c.defs[cc]
		if d.anchors.is_empty() and float(land) * d.share_target() < room:
			continue
		kept.append(cc)
	c.land_types = kept


static func coarse(c: GenContext) -> void:
	fit_types(c)
	# WHICH LANDSCAPES MAY LIE ON WHICH BODY, decided and recorded before a site is
	# placed. With one body it is every type, which is what a world has always had.
	GenBodies.deal(c)
	var rng := Rng.make(c.s, 201)
	var sites := _sites(c, rng)
	var cw := c.cw
	var cn := cw * cw
	var step := GenContext.STEP
	var size := c.size
	var types := c.types
	var target := targets(c)
	var warp := GenFields.noise(c.s, 202, 1.0 / (190.0 * c.body_k), 3)
	var wamp := 58.0 * c.body_k
	var own: Array[FastNoiseLite] = []
	for cc in types:
		own.append(GenFields.noise(c.s, 210 + cc, 1.0 / (90.0 * c.body_k), 3))
	var oamp := 38.0 * c.body_k
	# dist[cc * cn + k]: warped distance from cell k to type cc's nearest site.
	var dist := PackedFloat32Array()
	dist.resize(types * cn)
	dist.fill(1e9)
	var land := c.land
	var landc := PackedByteArray()
	landc.resize(cn)
	const N := GenFields.NOISE
	var specs := [[N, warp, cw, step], [N, warp, cw, step, 613.0, -287.0]]
	for cc in range(1, types):
		specs.append([N, own[cc], cw, step])
	var fl := GenFields.batch(size, specs)
	var wx := fl[0]
	var wy := fl[1]
	# Each type's own wander, end to end: cc * cn + k.
	var ownf := PackedFloat32Array()
	ownf.resize(cn)
	for cc in range(1, types):
		ownf.append_array(fl[cc + 1])
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
				for cc in range(1, types):
					dist[cc * cn + k] += ownf[cc * cn + k] * oamp
	)
	# Balance additive weights so shares hit the registry's targets: coarse
	# passes on every other cell, then fine passes on every land cell.
	var weight := PackedFloat32Array()
	weight.resize(types)
	var full_passes := 0
	var it := 0
	while it < 40:
		var sparse := it < 30
		var gain := size * (0.5 if sparse else 0.3)
		var counts := _assign_counts(dist, weight, landc, cw, types, sparse)
		var total := 0.0
		for cc in types:
			total += counts[cc]
		total = maxf(1.0, total)
		var worst := 0.0
		for cc: int in c.land_types:
			var err := target[cc] - counts[cc] / total
			worst = maxf(worst, absf(err))
			weight[cc] += err * gain
		# Close enough on the sample: go on to every cell. The tiles are
		# balanced again after their borders wander (fine()).
		if sparse and worst < 0.006 and it >= 8:
			it = 29
		if not sparse:
			full_passes += 1
			if worst < 0.004 and full_passes >= 3:
				break
		it += 1
	c.scores.clear()
	c.soft.clear()
	var flat := PackedFloat32Array()
	flat.resize(types * cn)
	# Soft membership for blending relief and climate: broad, so a mountain
	# range rises over many tiles rather than at a border line.
	var temp := 22.0
	var softm := PackedFloat32Array()
	softm.resize(types * cn)
	GenFields.rows(cw, func(g0: int, g1: int) -> void:
		for k in range(g0 * cw, g1 * cw):
			var top := -1e9
			for cc in range(1, types):
				var v := weight[cc] - dist[cc * cn + k]
				flat[cc * cn + k] = v
				top = maxf(top, v)
			var sum := 0.0
			for cc in range(1, types):
				var e := exp((weight[cc] - dist[cc * cn + k] - top) / temp)
				softm[cc * cn + k] = e
				sum += e
			for cc in range(1, types):
				softm[cc * cn + k] /= sum
	)
	for cc in types:
		c.scores.append(flat.slice(cc * cn, (cc + 1) * cn))
		c.soft.append(softm.slice(cc * cn, (cc + 1) * cn))
	c.soft_flat = softm
	c.hearts.clear()
	for cc in types:
		c.hearts.append(Vector2(-1, -1))
	for site: Vector3 in sites:
		if c.hearts[int(site.z)].x < 0.0:
			c.hearts[int(site.z)] = Vector2(site.x, site.y)


## Land cells each type would win with these weights (every other cell in each
## direction when sparse).
static func _assign_counts(dist: PackedFloat32Array, weight: PackedFloat32Array, landc: PackedByteArray, cw: int, types: int, sparse: bool) -> PackedInt32Array:
	var cn := cw * cw
	var band := 12
	var parts: Array[PackedInt32Array] = []
	parts.resize(ceili(float(cw) / band))
	GenFields.rows(cw, func(g0: int, g1: int) -> void:
		var counts := PackedInt32Array()
		counts.resize(types)
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
				for cc in range(1, types):
					var v := weight[cc] - dist[cc * cn + k]
					if v > best_v:
						best_v = v
						best = cc
				counts[best] += 1
		parts[g0 / band] = counts
	, band)
	var total := PackedInt32Array()
	total.resize(types)
	for part in parts:
		for cc in types:
			total[cc] += part[cc]
	return total


## Where every type's sites go: x, y in tiles, z the type index.
##
## Types that declare `anchors` lay the island's journey: each anchor names a
## place in the island's extent and the order it was surveyed in, so the coast
## holds the south shore where the player wakes and the cold and the fire lie
## north. Anchors in one band trade places with the seed. Every other type is
## placed by its climate envelope and what it likes to lie beside.
static func _sites(c: GenContext, rng: RandomNumberGenerator) -> Array[Vector3]:
	var raw: Array = []
	var bands := {}
	for cc: int in c.land_types:
		for a: Dictionary in c.defs[cc].anchors:
			var e := a.duplicate()
			e["type"] = cc
			raw.append(e)
			var band: StringName = e.get("band", &"")
			if band != &"":
				var members: Array = bands.get(band, [])
				members.append(e)
				bands[band] = members
	raw.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("seq", 0)) < int(b.get("seq", 0)))
	# Two landscapes of a band trade places with the seed, so the belt across
	# the island's waist is not the same three in the same order every time.
	# The PLACES stay put and the landscapes move between them.
	var band_names := bands.keys()
	band_names.sort()
	for band: StringName in band_names:
		var members: Array = bands[band]
		members.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("slot", 0)) < int(b.get("slot", 0)))
		var swap := 0.0
		for m: Dictionary in members:
			swap = maxf(swap, float(m.get("swap", 0.0)))
		if members.size() >= 2 and swap > 0.0 and rng.randf() < swap:
			var t: int = members[0]["type"]
			members[0]["type"] = members[1]["type"]
			members[1]["type"] = t
	var kept: Array = []
	for e: Dictionary in raw:
		# Optional sites give each seed its own silhouette.
		if float(e.get("chance", 1.0)) < 1.0 and rng.randf() >= float(e.get("chance", 1.0)):
			continue
		kept.append(e)
	var mirror := rng.randf() < 0.5
	var out: Array[Vector3] = []
	# An anchor is a place on a BODY, not a place in the square. With one body the
	# two are the same rect and nothing moves; with several, mapping u,v across the
	# whole archipelago would put a landscape's heart in open ocean.
	var seen_of := {}
	for e: Dictionary in kept:
		var u := float(e.u) + rng.randf_range(-0.05, 0.05)
		var v := float(e.v) + rng.randf_range(-0.035, 0.035)
		if mirror:
			u = 1.0 - u
		var cc: int = e["type"]
		var nth: int = int(seen_of.get(cc, 0))
		seen_of[cc] = nth + 1
		var r := _rect_for(c, cc, nth)
		out.append(Vector3(r.position.x + u * r.size.x, r.position.y + v * r.size.y, cc))
	_envelope_sites(c, rng, out)
	return out


## Types with no anchor find their own ground: the island's latitude and its
## distance from the sea give a climate before any relief exists, and a type
## goes where that climate fits it, near what it likes and away from its own
## other sites.
## The rect the `nth` site of type `cc` is placed in: the whole land when there is
## one body, and otherwise the bounds of one of the bodies that type was dealt,
## taken in turn so a type on two continents puts a heart on each.
static func _rect_for(c: GenContext, cc: int, nth: int) -> Rect2:
	# THE PLAN SAYS HOW MANY CONTINENTS THERE ARE, not `w.continents`, which counts
	# every scrap of land — a 512 world has one island and half a dozen skerries,
	# and reading its length as a body count moved every seed's island the first
	# time this was written.
	if c.bodies.size() <= 1:
		return c.land_rect
	var bodies := c.w.continents
	var mine: Array[int] = []
	for i in bodies.size():
		var types: PackedInt32Array = bodies[i].get("types", PackedInt32Array())
		if types.has(cc):
			mine.append(i)
	if mine.is_empty():
		return c.land_rect
	return bodies[mine[nth % mine.size()]].bounds as Rect2


## May this type stand here? True everywhere on a one-body world.
static func _dealt_here(c: GenContext, cc: int, p: Vector2) -> bool:
	if c.bodies.size() <= 1:
		return true
	var id := c.w.continent_at(floori(p.x), floori(p.y))
	if id == GenBodies.VOID:
		return false
	for b: Dictionary in c.w.continents:
		if int(b.id) != id:
			continue
		# A mass nobody dealt is a skerry, not a continent: whatever washed up on
		# it is welcome. Only a DEALT body turns a type away.
		if not b.has("types"):
			return true
		return (b.get("types") as PackedInt32Array).has(cc)
	return false


static func _envelope_sites(c: GenContext, rng: RandomNumberGenerator, out: Array[Vector3]) -> void:
	var wanted: Array[int] = []
	for cc: int in c.land_types:
		if c.defs[cc].anchors.is_empty():
			wanted.append(cc)
	if wanted.is_empty():
		return
	var r := c.land_rect
	var size := c.size
	# Candidate cells across the island, coarse: sites only need to be roughly right.
	var cells: Array[Vector3] = []
	var stepx := maxf(8.0, r.size.x / 18.0)
	var stepy := maxf(8.0, r.size.y / 18.0)
	var y := r.position.y + stepy * 0.5
	while y < r.end.y:
		var x := r.position.x + stepx * 0.5
		while x < r.end.x:
			var ix := clampi(int(x), 0, size - 1)
			var iy := clampi(int(y), 0, size - 1)
			if c.land[iy * size + ix] != 0:
				cells.append(Vector3(x, y, 0.0))
			x += stepx
		y += stepy
	for cc: int in wanted:
		var d := c.defs[cc]
		var want := maxi(d.site_count.x, mini(d.site_count.y, roundi(d.site_count.x + (d.site_count.y - d.site_count.x) * c.body_k)))
		for i in want:
			var best := -1
			var best_score := -1e9
			for j in cells.size():
				var p := Vector2(cells[j].x, cells[j].y)
				if cells[j].z > 0.0:
					continue
				if not _dealt_here(c, cc, p):
					continue
				var score := _fit(c, d, p, r)
				if score <= 0.0:
					continue
				for s: Vector3 in out:
					var dist := p.distance_to(Vector2(s.x, s.y))
					var other := c.defs[int(s.z)]
					# Never on top of another site; drawn toward the neighbours
					# it likes and pushed off the ones it does not.
					if dist < 40.0 * maxf(0.5, c.body_k):
						score -= 3.0
					var like := float(d.adjacency.get(other.id, 0.0))
					score += like * clampf(1.0 - dist / (140.0 * maxf(0.5, c.body_k)), 0.0, 1.0)
					if int(s.z) == cc:
						score -= clampf(1.0 - dist / (200.0 * maxf(0.5, c.body_k)), 0.0, 1.0) * 2.0
				score += rng.randf() * 0.25
				if score > best_score:
					best_score = score
					best = j
			if best < 0:
				break
			cells[best] = Vector3(cells[best].x, cells[best].y, 1.0)
			out.append(Vector3(cells[best].x, cells[best].y, cc))


## How well a type's climate envelope fits a place, 0 (never) to 1.
static func _fit(c: GenContext, d: BiomeDef, p: Vector2, r: Rect2) -> float:
	# North is cold: the island's own latitude, before any relief.
	var v := clampf((p.y - r.position.y) / maxf(1.0, r.size.y), 0.0, 1.0)
	var temp := clampf(0.06 + v * CLIMATE_COLD, 0.0, 1.0)
	var i := clampi(int(p.y), 0, c.size - 1) * c.size + clampi(int(p.x), 0, c.size - 1)
	var inland := c.inland[i]
	# The shore is wet, the middle of the island is dry.
	var moist := clampf(1.0 - smoothstep(4.0, 150.0 * maxf(0.5, c.body_k), inland) * 0.85, 0.0, 1.0)
	if temp < d.temp_range.x or temp > d.temp_range.y:
		return 0.0
	if moist < d.moist_range.x or moist > d.moist_range.y:
		return 0.0
	var mid_t := (d.temp_range.x + d.temp_range.y) * 0.5
	var mid_m := (d.moist_range.x + d.moist_range.y) * 0.5
	var fit := 1.0 - absf(temp - mid_t) - absf(moist - mid_m)
	if d.coastal != 0.0:
		var shore := clampf(1.0 - inland / (60.0 * maxf(0.5, c.body_k)), 0.0, 1.0)
		fit += d.coastal * (shore - 0.5)
	return maxf(0.05, fit)


## Upsample the named per-type parameters to tile resolution.
static func params(c: GenContext, names: Array) -> Dictionary:
	var cw := c.cw
	var cn := cw * cw
	var out := {}
	var soft := c.soft_flat
	for name: StringName in names:
		# Only the types that set this parameter, so the sum stays short.
		var bases := PackedInt32Array()
		var values := PackedFloat32Array()
		for cc: int in c.land_types:
			var t := c.defs[cc].param(name)
			if t != 0.0:
				bases.append(cc * cn)
				values.append(t)
		var terms := bases.size()
		var g := PackedFloat32Array()
		g.resize(cn)
		GenFields.rows(cw, func(g0: int, g1: int) -> void:
			for k in range(g0 * cw, g1 * cw):
				var v := 0.0
				for j in terms:
					v += soft[bases[j] + k] * values[j]
				g[k] = v
		)
		out[name] = g
	return out


## Tiles take their type and the runner-up.
##
## The smooth margin between a tile's best two types (scores, plus the pull a
## type declares toward high ground, plus the tongues a pair of types reach into
## each other) is divided by its own gradient at that tile, so it reads as tiles
## to the border however the warps have stretched the field. Finger and bend
## noise then shift the border itself by a known number of tiles, so every
## border wanders. _blend then measures the ecotones from the borders that
## resulted, and _regions records the runs that remain.
static func fine(c: GenContext, with_blend: bool = true) -> void:
	var w := c.w
	var size := c.size
	var n := c.n
	var cw := c.cw
	var types := c.types
	var step := GenContext.STEP
	var elev := c.elev
	const F := GenFields.FIELD
	const U := GenFields.UP
	var specs := []
	for cc in range(1, types):
		specs.append([U, c.scores[cc], cw, step])
	specs.append_array([
		[F, GenFields.noise(c.s, 221, 1.0 / 15.0, 3), 2],
		# Bends at the scale of a walk, so no border runs ruler-straight.
		[F, GenFields.noise(c.s, 224, 1.0 / 70.0, 2), 4],
		[F, GenFields.noise(c.s, 222, 1.0 / 34.0, 2, FastNoiseLite.TYPE_PERLIN), 4],
		[F, GenFields.noise(c.s, 223, 1.0 / 70.0, 2), 8],
		[GenFields.SMOOTH, elev, 3],
	])
	var fl := GenFields.batch(size, specs)
	# Scores for types 1..types-1, upsampled, end to end: (cc - 1) * n + i.
	var flat := PackedFloat32Array()
	for cc in range(1, types):
		flat.append_array(fl[cc - 1])
	var last := types - 1
	var finger := fl[last]
	var bend := fl[last + 1]
	var tongue := fl[last + 2]
	var widen := fl[last + 3]
	var elev_smooth := fl[last + 4]
	var land := c.land
	var country := w.country
	var country2 := w.country2
	# Coarse pass: climate with a lapse rate, and the leading type for sea tiles.
	var coarse_p := params(c, [&"temp", &"moist"])
	var ct: PackedFloat32Array = coarse_p[&"temp"]
	var top1 := PackedByteArray()
	top1.resize(cw * cw)
	var sc := c.scores
	GenFields.rows(cw, func(g0: int, g1: int) -> void:
		for gy in range(g0, g1):
			var ty := clampi(roundi(gy * step + step * 0.5 - 0.5), 0, size - 1)
			for gx in cw:
				var k := gy * cw + gx
				var tx := clampi(roundi(gx * step + step * 0.5 - 0.5), 0, size - 1)
				ct[k] = clampf(ct[k] - maxf(0.0, elev[ty * size + tx] - 5.0) * 0.035, 0.0, 1.0)
				var best := 1
				var bv := -1e12
				for cc in range(1, types):
					var v: float = sc[cc][k]
					if v > bv:
						bv = v
						best = cc
				top1[k] = best
	)
	w.temperature = GenFields.upsample(ct, cw, step, size)
	w.moisture = GenFields.upsample(coarse_p[&"moist"], cw, step, size)
	c.mark(&"tiles.coarse")
	# Border rules, flattened so the tile loop never touches a BiomeDef:
	# how far a type's border climbs, and the tongues each pair reaches.
	var climb := PackedFloat32Array()
	climb.resize(types)
	var tongue_amp := PackedFloat32Array()
	tongue_amp.resize(types * types)
	var finger_amp := PackedFloat32Array()
	finger_amp.resize(types * types)
	finger_amp.fill(9.0)
	for cc: int in c.land_types:
		var d := c.defs[cc]
		climb[cc] = d.border_elevation
		for other: StringName in d.tongues:
			var oi := BiomeRegistry.index_of(other)
			if oi < 0:
				continue
			var amp: Vector2 = d.tongues[other]
			var lo := mini(cc, oi)
			var hi := maxi(cc, oi)
			# The tongue runs toward the higher-indexed of the pair.
			tongue_amp[lo * types + hi] = amp.x if cc == lo else -amp.x
			finger_amp[lo * types + hi] = amp.y
	# Tiles each type's borders are pushed out by (negative: pulled in), found
	# by balancing on a sparse sample below.
	var push := PackedFloat32Array()
	push.resize(types)
	# stride 1 writes every tile; a larger stride only counts a sample, by type,
	# into parts (one count per band).
	var assign := func(stride: int, parts: Array[PackedInt32Array]) -> void:
		GenFields.rows(size, func(y0: int, y1: int) -> void:
			var counts := PackedInt32Array()
			counts.resize(types)
			for y in range(y0, y1):
				if y % stride != 0:
					continue
				var row := y * size
				for x in range(0, size, stride):
					var i := row + x
					if land[i] == 0:
						if stride == 1:
							country[i] = Country.SEA
							country2[i] = top1[(y / step) * cw + x / step]
						continue
					var a := 1
					var b := 2
					var sa := flat[i]
					var sb := flat[n + i]
					if sb > sa:
						a = 2
						b = 1
						sa = flat[n + i]
						sb = flat[i]
					for cc in range(3, types):
						var v := flat[(cc - 1) * n + i]
						if v > sa:
							b = a
							sb = sa
							a = cc
							sa = v
						elif v > sb:
							b = cc
							sb = v
					var lo := mini(a, b)
					var hi := maxi(a, b)
					var bl := (lo - 1) * n
					var bh := (hi - 1) * n
					var m := sa - sb if a == lo else sb - sa
					var win := lo
					if m > 200.0 or m < -200.0:
						# Far past anything the noise can move a border (the margin
						# rarely changes by 5 a tile; the shifts reach ~50 tiles).
						win = lo if m > 0.0 else hi
					else:
						# The margin's gradient, over four tiles each way.
						var xa := maxi(x - 2, 0)
						var xb := mini(x + 2, size - 1)
						var ya := maxi(y - 2, 0)
						var yb := mini(y + 2, size - 1)
						var ia := row + xa
						var ib := row + xb
						var ja := ya * size + x
						var jb := yb * size + x
						var gx := (flat[bl + ib] - flat[bh + ib]) - (flat[bl + ia] - flat[bh + ia])
						var gy := (flat[bl + jb] - flat[bh + jb]) - (flat[bl + ja] - flat[bh + ja])
						var pair := lo * types + hi
						var amp := finger_amp[pair]
						var tg := tongue_amp[pair]
						if tg != 0.0:
							# One of the pair reaches long tongues into the other
							# along the ground that suits it.
							m -= tongue[i] * tg
							gx -= (tongue[ib] - tongue[ia]) * tg
							gy -= (tongue[jb] - tongue[ja]) * tg
						var sgn := climb[hi] - climb[lo]
						if sgn != 0.0:
							# A type that takes the high ground: the local lie of the
							# land moves the border, the broad slope sets how far.
							m -= sgn * (elev[i] - 6.5)
							gx -= sgn * (elev_smooth[ib] - elev_smooth[ia])
							gy -= sgn * (elev_smooth[jb] - elev_smooth[ja])
						var grad := maxf(0.25, sqrt(gx * gx + gy * gy) / float(maxi(1, xb - xa + yb - ya) / 2))
						var d := m / grad + finger[i] * amp + bend[i] * 22.0 + push[lo] - push[hi]
						win = hi if d < 0.0 else lo
					if stride == 1:
						country[i] = win
						country2[i] = hi if win == lo else lo
					else:
						counts[win] += 1
			if stride > 1:
				parts[y0 / 12] = counts
		)
	# The layout was balanced on the coarse grid; the fingers, bends, tongues
	# and the climbing borders then move every border. Measure the shares that
	# result on a sample, push each border out or in by the error, and measure
	# again, so every seed keeps its landscapes near their targets.
	var target := targets(c)
	var parts: Array[PackedInt32Array] = []
	parts.resize(ceili(float(size) / 12))
	var gain := 60.0 * size / 512.0
	for it in BALANCE_PASSES:
		assign.call(BALANCE_STRIDE, parts)
		var counts := PackedFloat32Array()
		counts.resize(types)
		var total := 0.0
		for part in parts:
			for cc in types:
				counts[cc] += part[cc]
				total += part[cc]
		for cc: int in c.land_types:
			push[cc] = clampf(push[cc] + (target[cc] - counts[cc] / maxf(1.0, total)) * gain, -12.0, 12.0)
	c.mark(&"tiles.balance")
	assign.call(1, parts)
	c.mark(&"tiles.assign")
	_absorb_enclaves(c, roundi(ENCLAVE_TILES * c.body_k * c.body_k))
	c.mark(&"tiles.enclaves")
	if with_blend:
		_blend(c, widen)
	c.mark(&"tiles.blend")
	regions(c)
	c.mark(&"tiles.regions")


## Pieces of a type smaller than min_tiles take the land type most common along
## their edge (islets, with no land neighbours, stay). Runs before the ecotones
## are measured, so the blend follows the borders that remain.
static func _absorb_enclaves(c: GenContext, min_tiles: int) -> void:
	var size := c.size
	var types := c.types
	var country := c.w.country
	var country2 := c.w.country2
	var sea := PackedByteArray()
	sea.resize(c.n)
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for i in range(y0 * size, y1 * size):
			sea[i] = 1 if country[i] == Country.SEA else 0
	)
	var sizes := PackedInt32Array()
	var label := GenFields.patches(country, sea, size, sizes)
	var band := 12
	var parts: Array[PackedInt32Array] = []
	parts.resize(ceili(float(size) / band))
	GenFields.rows(size - 1, func(y0: int, y1: int) -> void:
		var found := PackedInt32Array()
		for y in range(maxi(y0, 1), y1):
			for x in range(1, size - 1):
				var i := y * size + x
				var la := label[i]
				if la >= 0 and sizes[la] < min_tiles:
					found.append(i)
		parts[y0 / band] = found
	, band)
	var votes := {}
	for part in parts:
		for i in part:
			var la := label[i]
			var v: PackedInt32Array = votes.get(la, PackedInt32Array())
			if v.is_empty():
				v.resize(types)
			for j: int in [i - 1, i + 1, i - size, i + size]:
				if label[j] >= 0 and label[j] != la:
					v[country[j]] += 1
			votes[la] = v
	var winner := {}
	for la: int in votes:
		var v: PackedInt32Array = votes[la]
		var best := 0
		for cc in range(1, types):
			if v[cc] > v[best]:
				best = cc
		if best > 0:
			winner[la] = best
	for part in parts:
		for i in part:
			var la := label[i]
			if winner.has(la):
				country2[i] = country[i]
				country[i] = winner[la]


## Every connected run of one landscape type is a REGION of that type: one type
## can hold several in a world, and a sentinel, a works network, a subarc and a
## save all key on a region's id (docs/VISION.md §3, §7.2). Runs too small to
## be a place are left out; their tiles keep their type and belong to no region.
static func regions(c: GenContext) -> void:
	var w := c.w
	var size := c.size
	var country := w.country
	var sea := PackedByteArray()
	sea.resize(c.n)
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for i in range(y0 * size, y1 * size):
			sea[i] = 1 if country[i] == Country.SEA else 0
	)
	var sizes := PackedInt32Array()
	var label := GenFields.patches(country, sea, size, sizes)
	var min_tiles := maxi(roundi(PLACE_TILES * c.k * c.k), roundi(REGION_TILES * c.body_k * c.body_k))
	# Biggest first, so region 0 is the largest place in the world and ids stay
	# stable as long as the shape of the land does.
	var order := PackedInt32Array()
	for la in sizes.size():
		if sizes[la] >= min_tiles:
			order.append(la)
	var by_size := Array(order)
	by_size.sort_custom(func(a: int, b: int) -> bool:
		if sizes[a] != sizes[b]:
			return sizes[a] > sizes[b]
		return a < b)
	var id_of := {}
	w.regions.clear()
	w.region.resize(c.n)
	w.region.fill(0)
	for la: int in by_size:
		id_of[la] = w.regions.size()
		w.regions.append({
			"id": w.regions.size(), "type": &"", "index": 0, "tiles": sizes[la],
			"centre": Vector2.ZERO, "bounds": Rect2(),
		})
	var count := w.regions.size()
	# Label -> id + 1, as an array: the tile pass asks this once a tile, and a
	# Dictionary lookup a tile costs more than the whole rest of the pass.
	var rid_of := PackedInt32Array()
	rid_of.resize(c.n)
	for la: int in id_of:
		rid_of[la] = int(id_of[la]) + 1
	var region := w.region
	var band := 16
	var bands := ceili(float(size) / band)
	# Each band totals its own rows; the bands are merged in row order, so the
	# centres come out the same however the pool scheduled them.
	var b_sum: Array[PackedFloat64Array] = []
	var b_box: Array[PackedInt32Array] = []
	b_sum.resize(bands)
	b_box.resize(bands)
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		var s2 := PackedFloat64Array()
		s2.resize(count * 2)
		var box := PackedInt32Array()
		box.resize(count * 5)
		for r in count:
			box[r * 5] = 1 << 30
			box[r * 5 + 1] = 1 << 30
			box[r * 5 + 2] = -(1 << 30)
			box[r * 5 + 3] = -(1 << 30)
			box[r * 5 + 4] = -1
		for y in range(y0, y1):
			var row := y * size
			for x in size:
				var i := row + x
				var la := label[i]
				if la < 0:
					continue
				var rid := rid_of[la] - 1
				if rid < 0:
					continue
				region[i] = rid + 1
				var b := rid * 5
				s2[rid * 2] += x + 0.5
				s2[rid * 2 + 1] += y + 0.5
				if x < box[b]:
					box[b] = x
				if y < box[b + 1]:
					box[b + 1] = y
				if x > box[b + 2]:
					box[b + 2] = x
				if y > box[b + 3]:
					box[b + 3] = y
				if box[b + 4] < 0:
					box[b + 4] = i
		b_sum[y0 / band] = s2
		b_box[y0 / band] = box
	, band)
	var sum := PackedFloat64Array()
	sum.resize(count * 2)
	# One tile each region was seen to own, so its type never has to be hunted for.
	var sample := PackedInt32Array()
	sample.resize(count)
	sample.fill(0)
	var lo := PackedInt32Array()
	var hi := PackedInt32Array()
	lo.resize(count * 2)
	hi.resize(count * 2)
	lo.fill(1 << 30)
	hi.fill(-(1 << 30))
	for b in bands:
		var s2 := b_sum[b]
		var box := b_box[b]
		for rid in count:
			sum[rid * 2] += s2[rid * 2]
			sum[rid * 2 + 1] += s2[rid * 2 + 1]
			lo[rid * 2] = mini(lo[rid * 2], box[rid * 5])
			lo[rid * 2 + 1] = mini(lo[rid * 2 + 1], box[rid * 5 + 1])
			hi[rid * 2] = maxi(hi[rid * 2], box[rid * 5 + 2])
			hi[rid * 2 + 1] = maxi(hi[rid * 2 + 1], box[rid * 5 + 3])
			if sample[rid] == 0 and box[rid * 5 + 4] >= 0:
				sample[rid] = box[rid * 5 + 4]
	for r: Dictionary in w.regions:
		var rid: int = r.id
		var tiles := maxi(1, int(r.tiles))
		r.centre = Vector2(sum[rid * 2] / tiles, sum[rid * 2 + 1] / tiles)
		r.bounds = Rect2(lo[rid * 2], lo[rid * 2 + 1], hi[rid * 2] - lo[rid * 2] + 1, hi[rid * 2 + 1] - lo[rid * 2 + 1] + 1)
		# The centre of a bent region can fall outside it, so the type is read
		# off a tile the region was seen to own.
		var cc := country[sample[rid]]
		r.index = cc
		r.type = BiomeRegistry.by_index(cc).id


## blend from the true distance to the nearest border, so 0.5 on the border
## always falls to 0 over the stated width however the score fields were
## warped. Borders are found per tile; distance is spread at half resolution
## carrying the pair of types that meet there, so country2 is the type actually
## across the nearest border (the score runner-up only at a junction).
static func _blend(c: GenContext, widen: PackedFloat32Array) -> void:
	var w := c.w
	var size := c.size
	var slots := BiomeRegistry.SLOTS
	var country := w.country
	var country2 := w.country2
	var blend := w.blend
	var hw := GenFields.coarse_width(size, 2)
	var hn := hw * hw
	var dist := PackedFloat32Array()
	dist.resize(hn)
	dist.fill(1e4)
	var pair := PackedInt32Array()
	pair.resize(hn)
	var edge := PackedInt32Array()
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
				var pk := mini(a, b) * slots + maxi(a, b)
				edge[i] = pk
				dist[hrow + (x >> 1)] = 0.0
				pair[hrow + (x >> 1)] = pk
	, 12)
	# Exact to 28 tiles, past the widest ecotone.
	var spread := GenFields.banded([dist, pair], hw, 14, func(arrays: Array, width: int) -> Array:
		var dd: PackedFloat32Array = arrays[0]
		var pp: PackedInt32Array = arrays[1]
		_spread_labelled(dd, pp, width, 2.0)
		return [dd, pp]
	)
	dist = spread[0]
	pair = spread[1]
	var up := GenFields.upsample(dist, hw, 2, size)
	# Where the nearest border changes from one neighbour to another, country2
	# flips along a straight line. Fade the blend to nothing along those seams
	# (except hard by a border), so a renderer mixing in country2's wash never
	# shows the flip.
	var seam := PackedByteArray()
	seam.resize(hn)
	var other_h := PackedByteArray()
	other_h.resize(hn)
	var own_h := PackedByteArray()
	own_h.resize(hn)
	GenFields.rows(hw, func(g0: int, g1: int) -> void:
		for gy in range(g0, g1):
			var trow := mini(gy * 2, size - 1) * size
			for gx in hw:
				var k := gy * hw + gx
				var own := country[trow + mini(gx * 2, size - 1)]
				own_h[k] = own
				var pk := pair[k]
				if own == pk / slots:
					other_h[k] = pk % slots
				elif own == pk % slots:
					other_h[k] = pk / slots
	)
	GenFields.rows(hw - 1, func(g0: int, g1: int) -> void:
		for gy in range(maxi(g0, 1), g1):
			for gx in range(1, hw - 1):
				var k := gy * hw + gx
				var o := other_h[k]
				var own := own_h[k]
				# A CELL WHOSE NEAREST PAIR DOES NOT NAME IT IS THE SEAM ITSELF.
				# `other_h` is 0 where the pair the chamfer carried here holds two
				# countries and neither is this cell's own — which happens exactly
				# where a cell is equidistant between two DIFFERENT neighbours, near
				# a place three landscapes meet. That is the definition of the seam
				# this loop is looking for, and it was the one case it skipped.
				#
				# It skipped it twice over, because the loop below cannot work out
				# `other` for such a cell either and leaves `country2` holding
				# whatever it had before — so the stale value is what flips, along
				# the very line that was never faded. Measured on seed 42 with
				# eleven landscapes: a straight run of eight tiles of moss, in a
				# corridor with the coast on one side and the city on the other,
				# where country2 changed allegiance under a blend of 0.09 to 0.30.
				#
				# Marking them costs almost nothing, which is how you can tell it is
				# the right place: over the three test seeds the blend band loses
				# 0.08% of its tiles and 0.2% of its mass. Widening the FADE until
				# the same seams went quiet was tried first and cost 40% of the
				# world's blend mass and 56% of everything over 0.25 — passing the
				# test by flattening the ecotones the test exists to protect.
				if o == 0:
					if own != SEA:
						seam[k] = 1
					continue
				var r := other_h[k + 1]
				var dn := other_h[k + hw]
				var l := other_h[k - 1]
				var u := other_h[k - hw]
				if (own_h[k + 1] == own and r != 0 and r != o) or (own_h[k + hw] == own and dn != 0 and dn != o) or (own_h[k - 1] == own and l != 0 and l != o) or (own_h[k - hw] == own and u != 0 and u != o):
					seam[k] = 1
	)
	# Only the first few cells from a seam matter to the fade.
	var seam_img := Image.create_from_data(hw, hw, false, Image.FORMAT_L8, GenFields.near_steps(seam, hw, 5))
	seam_img.convert(Image.FORMAT_RF)
	seam_img.resize(hw * 2, hw * 2, Image.INTERPOLATE_BILINEAR)
	if hw * 2 != size:
		seam_img.crop(size, size)
	var seam_d := seam_img.get_data().to_float32_array()
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
				var lo := pk / slots
				var hi := pk % slots
				var other := country2[i]
				if lo == own:
					other = hi
				elif hi == own:
					other = lo
				country2[i] = other
				# 12 to 24 tiles, wandering along the border. Every ecotone keeps
				# inside it, the Burning's ash included.
				var width := 12.0 + 12.0 * clampf(0.5 + widen[i] * 1.4, 0.0, 1.0)
				var fade := maxf(clampf((seam_d[i] * 510.0 - 1.0) / 8.0, 0.0, 1.0), 1.0 - d / 2.0)
				blend[i] = (0.5 - 0.5 * d / width) * fade if d < width else 0.0
	)


## Two-sweep 8-neighbour chamfer distance (cell = `unit` tiles) that also
## carries each source's label to the cells it is nearest.
static func _spread_labelled(d: PackedFloat32Array, label: PackedInt32Array, width: int, unit: float) -> void:
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
