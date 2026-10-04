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
## The furthest those passes may push one landscape's borders, in tiles.
const PUSH_MOST := 12.0
## The distance a type is put at from land its body was not dealt: past any
## weight the balance can reach, so it can never win a cell there.
const OUT_OF_REACH := 1.0e9
## Weight slots: one per body id a world can carry (`GenBodies` caps ids at 255).
const SLOTS := 256
## A piece of a type cut off inside another and smaller than this (512 world)
## joins the type round it: a blot of ash in the limestone is noise, not a place.
const ENCLAVE_TILES := 400
## AN ENCLAVE IS SMALL AND NEAR: under its tile count, and no wider or taller
## than this many tiles. Measured at 1840, the widest absorbed was 91 (seeds 1,
## 42, 90210). Bounding the reach is what lets a section decide it: a window
## with ENCLAVE_REACH + 1 tiles round its core absorbs the core's enclaves
## exactly as the whole world does (streamed worldgen S4e2,
## tests/stream/test_enclave_window.gd).
const ENCLAVE_REACH := 128
## A run of one type smaller than this (512 world) is not its own region.
const REGION_TILES := 220
## WHAT SHARE OF A TYPICAL LANDSCAPE'S HOLDING A RUN MUST BE TO BE A PLACE
## (a region: a chapter, a keeper, a depot, a landmark round, an interference
## file). Stated against the BODY a run lies on and divided by how many
## landscapes the REALM lays, `c.land_types.size()`: a share of the square alone
## outgrew the continents it measured (73.6% of the land in a region at 1300), a
## share of the body alone left fifteen landscapes with no region at 256, and
## dividing by the dealt count instead of the realm's lost the most coverage.
## 0.25 (owner's delegation, docs/ROADMAP.md DECIDED 5) keeps coverage at
## 0.93-0.95 on seeds 1, 42, 90210 and 7 with every region holding a landmark.
##
## `PLACE_LEAST` is the hard floor under it: a region under
## `Landmarks.REGION_TILES` can never have a landmark stood in it, so it would be
## a place that can only be crossed.
const BODY_SHARE := 0.25
const PLACE_LEAST := Landmarks.REGION_TILES
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


## Each type's share of the land it is ALLOWED to hold, stated as a share of all
## land so the balancer can aim at it. On a body, the types it was dealt split its
## land by their own `share`; a type's target is what it gets summed over its
## bodies. A share was a target over the whole square, and with the deal enforced
## that asks a type dealt one body of five to reach a world-wide share its own
## deal forbids -- the balancer then pulls its weight without bound until it has
## eaten that body. A mass nobody dealt (a skerry) is open to every type.
##
## A world of one body has nothing to split and returns `targets` itself, not a
## sum that equals it: the same number by a different order of float additions
## moves a balance pass, and every pinned world with it.
static func allowed_targets(c: GenContext, landc: PackedByteArray, cell_body: PackedByteArray) -> PackedFloat32Array:
	if c.allow.is_empty():
		return targets(c)
	var land_of := {}
	var total := 0.0
	for k in landc.size():
		if landc[k] == 0:
			continue
		var id := int(cell_body[k])
		land_of[id] = float(land_of.get(id, 0.0)) + 1.0
		total += 1.0
	var out := PackedFloat32Array()
	out.resize(c.types)
	for id: int in land_of:
		var sum := 0.0
		for cc: int in c.land_types:
			if c.may_stand(cc, id):
				sum += c.defs[cc].share_target()
		if sum <= 0.0:
			continue
		for cc: int in c.land_types:
			if c.may_stand(cc, id):
				out[cc] += float(land_of[id]) * c.defs[cc].share_target() / sum
	for cc: int in c.land_types:
		out[cc] /= maxf(1.0, total)
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
		own.append(GenFields.noise(c.s, 210 + cc, 1.0 / (90.0 * c.body_k * _place_scale(c)), 3))
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
	# A land cell on a dealt body is out of reach of every type it was not dealt.
	# Put into the DISTANCE, so the balance, the scores and the soft memberships
	# all see it without a second rule to keep in step.
	var cell_body := PackedByteArray()
	cell_body.resize(cn)
	for k in cn:
		if landc[k] == 0:
			continue
		var ix := clampi(roundi(GenFields.cell_centre(k % cw, step)), 0, size - 1)
		var iy := clampi(roundi(GenFields.cell_centre(k / cw, step)), 0, size - 1)
		cell_body[k] = c.w.continent_at(ix, iy)
	if not c.allow.is_empty():
		for k in cn:
			if landc[k] == 0:
				continue
			for cc in range(1, types):
				if not c.may_stand(cc, cell_body[k]):
					dist[cc * cn + k] = OUT_OF_REACH
	target = allowed_targets(c, landc, cell_body)
	c.share_target = target
	# ONE WEIGHT PER TYPE PER BODY (docs/DESIGN.md: "`share` normalises across
	# the types dealt to this body"). A single weight per type was set by every
	# body the type holds at once, so where its neighbours differed from body to
	# body it could not hold its share on all of them: measured, the coast's one
	# weight sat 250-500 under glass_desert's and drowned_city's and it lost its
	# OWN heart on the home continent of seeds 1 and 42. A world of one body has
	# one slot, 0, and the arithmetic below is the arithmetic it always had.
	# The continents the deal reached, by id; a body it did not is a skerry.
	var dealt := PackedByteArray()
	dealt.resize(256)
	for row: Dictionary in c.w.continents:
		if row.has("types"):
			dealt[int(row.get("id", 0))] = 1
	var wslot := _weight_slots(c, landc, cell_body, dealt)
	c.weight_slot = wslot
	# A SEA CELL IS ITS NEAREST BODY'S, AND SO IS A SKERRY: a landscape not dealt
	# that body is out of its reach too. Otherwise the sea between two continents,
	# and the islets off a shore that nobody dealt, blended the far shore's
	# landscapes into this one's climate and relief: a landscape moved across the
	# strait moved home's facing shore (seed 1: its skerries took the drowned
	# city's heart on the far side as their nearest).
	if not c.allow.is_empty():
		for k in cn:
			if landc[k] != 0 and dealt[cell_body[k]] != 0:
				continue
			for cc in range(1, types):
				if not c.may_stand(cc, wslot[k]):
					dist[cc * cn + k] = OUT_OF_REACH
	var slot_target := _slot_targets(c, target)
	var weight := PackedFloat32Array()
	weight.resize(SLOTS * types)
	# A BODY OSCILLATES WHERE THE WHOLE LAND DID NOT. One body is a fifth of the
	# land, so the same gain that settles a world-wide share throws a body's share
	# from nothing to far too much and back: measured on seed 90210, the home
	# body's coast swung between 0 and 0.28 for all forty passes. So on a world of
	# several bodies each (body, type) halves its own step whenever its error
	# changes sign -- the loop still aims where it did, it just stops overshooting.
	# One body keeps the undamped arithmetic it always had.
	var damp := PackedFloat32Array()
	damp.resize(SLOTS * types)
	damp.fill(1.0)
	var last_err := PackedFloat32Array()
	last_err.resize(SLOTS * types)
	var damped := not c.allow.is_empty()
	# EACH BODY SETTLES ON ITS OWN SCHEDULE. One loop for the world ran every body
	# until the slowest had settled, so how many steps home's weights took -- and
	# so home's climate and borders -- hung on what lay on the other continents.
	# A body's slot is sampled sparse until it is close, then in full until it
	# holds, then left alone. One body: the schedule it always had.
	var slots := slot_target.keys()
	var phase := {}
	var steps := {}
	var full := {}
	for sl: int in slots:
		phase[sl] = 0
		steps[sl] = 0
		full[sl] = 0
	var guard := 0
	while guard < 80:
		guard += 1
		var need_sparse := false
		var need_full := false
		for sl: int in slots:
			need_sparse = need_sparse or int(phase[sl]) == 0
			need_full = need_full or int(phase[sl]) == 1
		if not need_sparse and not need_full:
			break
		var counts_sparse := _assign_counts(dist, weight, wslot, landc, cw, types, true) if need_sparse else PackedInt32Array()
		var counts_full := _assign_counts(dist, weight, wslot, landc, cw, types, false) if need_full else PackedInt32Array()
		for sl: int in slots:
			var ph := int(phase[sl])
			if ph == 2:
				continue
			var sparse := ph == 0
			var counts := counts_sparse if sparse else counts_full
			var gain := size * (0.5 if sparse else 0.3)
			var want: PackedFloat32Array = slot_target[sl]
			var at := sl * types
			var total := 0.0
			for cc in types:
				total += counts[at + cc]
			total = maxf(1.0, total)
			var worst := 0.0
			for cc: int in c.land_types:
				var err := want[cc] - counts[at + cc] / total
				worst = maxf(worst, absf(err))
				if damped:
					if err * last_err[at + cc] < 0.0:
						damp[at + cc] = maxf(0.02, damp[at + cc] * 0.5)
					last_err[at + cc] = err
					weight[at + cc] += err * gain * damp[at + cc]
				else:
					weight[at + cc] += err * gain
			var it := int(steps[sl])
			# Close enough on the sample: go on to every cell. The tiles are
			# balanced again after their borders wander (fine()).
			if sparse and worst < 0.006 and it >= 8:
				it = 29
			if not sparse:
				full[sl] = int(full[sl]) + 1
				if worst < 0.004 and int(full[sl]) >= 3:
					phase[sl] = 2
			it += 1
			steps[sl] = it
			if int(phase[sl]) != 2:
				phase[sl] = 2 if it >= 40 else (0 if it < 30 else 1)
	c.layout_weight = weight
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
			var at := wslot[k] * types
			for cc in range(1, types):
				var v := weight[at + cc] - dist[cc * cn + k]
				flat[cc * cn + k] = v
				top = maxf(top, v)
			var sum := 0.0
			for cc in range(1, types):
				var e := exp((weight[at + cc] - dist[cc * cn + k] - top) / temp)
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
static func _assign_counts(dist: PackedFloat32Array, weight: PackedFloat32Array, wslot: PackedByteArray, landc: PackedByteArray, cw: int, types: int, sparse: bool) -> PackedInt32Array:
	var cn := cw * cw
	var band := 12
	var parts: Array[PackedInt32Array] = []
	parts.resize(ceili(float(cw) / band))
	GenFields.rows(cw, func(g0: int, g1: int) -> void:
		var counts := PackedInt32Array()
		counts.resize(SLOTS * types)
		for gy in range(g0, g1):
			if sparse and gy % 2 != 0:
				continue
			var gstep := 2 if sparse else 1
			for gx in range(0, cw, gstep):
				var k := gy * cw + gx
				if landc[k] == 0:
					continue
				var at := wslot[k] * types
				var best := 1
				var best_v := -1e12
				for cc in range(1, types):
					var v := weight[at + cc] - dist[cc * cn + k]
					if v > best_v:
						best_v = v
						best = cc
				counts[at + best] += 1
		parts[g0 / band] = counts
	, band)
	var total := PackedInt32Array()
	total.resize(SLOTS * types)
	for part in parts:
		for j in part.size():
			total[j] += part[j]
	return total


## Which weight slot each coarse cell balances in: its body's id, and for a sea
## cell or a skerry nobody dealt the nearest dealt body's, so a shore's upsampled
## scores mix one body's weights and never a body's with nothing's. All 0 on a
## world of one body.
static func _weight_slots(c: GenContext, landc: PackedByteArray, cell_body: PackedByteArray, dealt: PackedByteArray) -> PackedByteArray:
	var cw := c.cw
	var slot := PackedByteArray()
	slot.resize(cw * cw)
	if c.allow.is_empty():
		return slot
	var seen := PackedByteArray()
	seen.resize(cw * cw)
	var q := PackedInt32Array()
	for k in cw * cw:
		if landc[k] != 0 and dealt[cell_body[k]] != 0:
			slot[k] = cell_body[k]
			seen[k] = 1
			q.append(k)
	var head := 0
	while head < q.size():
		var k := q[head]
		head += 1
		var x := k % cw
		var y := k / cw
		for d: Vector2i in GenBodies.NEIGHBOURS:
			var nx := x + d.x
			var ny := y + d.y
			if nx < 0 or ny < 0 or nx >= cw or ny >= cw:
				continue
			var j := ny * cw + nx
			if seen[j] != 0:
				continue
			seen[j] = 1
			slot[j] = slot[k]
			q.append(j)
	return slot


## What each balanced slot aims at: slot -> each type's share of THAT slot's land.
## One body: slot 0 and `target` itself. Several: every DEALT body splits its land
## among the types it was dealt by their `share`; a mass nobody dealt is not
## balanced at all and keeps a weight of 0, which leaves a skerry to distance.
static func _slot_targets(c: GenContext, target: PackedFloat32Array) -> Dictionary:
	var out := {}
	if c.allow.is_empty():
		out[0] = target
		return out
	for row: Dictionary in c.w.continents:
		if not row.has("types"):
			continue
		var id := int(row.get("id", 0))
		var want := PackedFloat32Array()
		want.resize(c.types)
		var sum := 0.0
		for cc: int in c.land_types:
			if c.may_stand(cc, id):
				sum += c.defs[cc].share_target()
		for cc: int in c.land_types:
			if c.may_stand(cc, id) and sum > 0.0:
				want[cc] = c.defs[cc].share_target() / sum
		out[id] = want
	return out


## How much bigger a place is on a world of continents (four or five landscapes
## to a body) than on the one island the wander and the enclave floor were tuned
## for. Held at the island's size, the wander broke a landscape into lobes inside
## its neighbour. 1 on a one-body world.
const PLACE_SCALE := 2.0


static func _place_scale(c: GenContext) -> float:
	return PLACE_SCALE if c.bodies.size() > 1 else 1.0


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
	_landfall_site(c, out)
	_envelope_sites(c, rng, out)
	_site_every_dealt_body(c, mirror, out)
	return _one_heart_per_body(c, out)


## How far inland of where the water comes ashore the landfall's heart stands:
## far enough that its territory takes the shore, near enough that a raft from
## home lands in it.
const LANDFALL_INLAND := 60.0


## THE LANDFALL'S HEART (`BiomeDef.LANDFALL`) stands on the body GenBodies marked,
## LANDFALL_INLAND tiles in from where the shortest water from home comes ashore
## (the row's `from`), toward the body's centre. It goes first and replaces any
## site the type was given on that body. No random draws, so nothing after it
## shifts.
static func _landfall_site(c: GenContext, out: Array[Vector3]) -> void:
	if c.bodies.size() <= 1:
		return
	var row: Dictionary = {}
	for r: Dictionary in c.w.continents:
		if bool(r.get("landfall", false)):
			row = r
	if row.is_empty():
		return
	var id := int(row.get("id", 0))
	var shore: Vector2 = row.get("from", row.centre)
	var centre: Vector2 = row.centre
	var heart := shore + (centre - shore).normalized() * minf(LANDFALL_INLAND, shore.distance_to(centre))
	if c.w.continent_at(floori(heart.x), floori(heart.y)) != id:
		heart = shore
	for cc: int in c.land_types:
		if c.defs[cc].spread != BiomeDef.LANDFALL:
			continue
		for i in range(out.size() - 1, -1, -1):
			if int(out[i].z) == cc and c.w.continent_at(floori(out[i].x), floori(out[i].y)) == id:
				out.remove_at(i)
		out.insert(0, Vector3(heart.x, heart.y, cc))


## One heart per landscape per continent: territory is distance to a type's
## nearest site, so a second site on one body is a second, separate run of it.
## The first is kept (anchors come first, in journey order). A one-body test
## island keeps every site: its second anchors give its journey a shape.
static func _one_heart_per_body(c: GenContext, sites: Array[Vector3]) -> Array[Vector3]:
	if c.bodies.size() <= 1:
		return sites
	var out: Array[Vector3] = []
	var seen := {}
	for s: Vector3 in sites:
		var key := int(s.z) * 256 + c.w.continent_at(floori(s.x), floori(s.y))
		if seen.has(key):
			continue
		seen[key] = true
		out.append(s)
	return out


## A SITE ON EVERY BODY A TYPE WAS DEALT. Territory is distance to a type's
## nearest site, and with the deal enforced a type can hold nothing on a body
## where it has none -- the balancer then raises its weight on that body without
## end and the land goes to whoever does have a site there. A type with one
## anchor dealt three bodies had a site on one of them (`_rect_for` takes them in
## turn) and a type placed by climate took its sites wherever it fitted best,
## which need not be every body it was dealt. Measured before this: shares missed
## their per-body target by up to 148% on seed 42.
##
## An anchored type repeats its anchors onto the bodies still without one, in
## the same mirror; a climate type takes the land on that body its envelope fits
## best. No random draws, so nothing after it shifts. One body: nothing to do.
static func _site_every_dealt_body(c: GenContext, mirror: bool, out: Array[Vector3]) -> void:
	if c.allow.is_empty():
		return
	for row: Dictionary in c.w.continents:
		if not row.has("types"):
			continue
		var id := int(row.get("id", 0))
		var bounds: Rect2 = row.bounds
		for cc: int in (row.get("types") as PackedInt32Array):
			var has := false
			for s: Vector3 in out:
				if int(s.z) == cc and c.w.continent_at(floori(s.x), floori(s.y)) == id:
					has = true
					break
			if has:
				continue
			var d := c.defs[cc]
			if not d.anchors.is_empty():
				var a: Dictionary = d.anchors[0]
				var u := float(a.u)
				if mirror:
					u = 1.0 - u
				out.append(Vector3(bounds.position.x + u * bounds.size.x, bounds.position.y + float(a.v) * bounds.size.y, cc))
				continue
			var best := Vector2(-1, -1)
			var best_fit := -1.0
			var y := bounds.position.y + 4.0
			while y < bounds.end.y:
				var x := bounds.position.x + 4.0
				while x < bounds.end.x:
					if c.w.continent_at(floori(x), floori(y)) == id:
						var f := _fit(c, d, Vector2(x, y), bounds)
						if f > best_fit:
							best_fit = f
							best = Vector2(x, y)
					x += 8.0
				y += 8.0
			if best.x >= 0.0:
				out.append(Vector3(best.x, best.y, cc))


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
	# A mass nobody dealt is a skerry, not a continent: whatever washed up on it
	# is welcome. Only a DEALT body turns a type away -- the same answer the
	# territory gets, from the same table.
	return c.may_stand(cc, id)


## A climate type's sites, where its envelope fits best.
##
## ON A WORLD OF BODIES, A SITE ANSWERS TO ITS OWN BODY. It weighed every site in
## the world for its neighbours and its room, and drew its jitter from one stream
## through every type and every candidate cell, so a landscape moved between two
## bodies moved a third's: on seed 42 the landfall traded the salt flats off one
## body, the stream after them shifted, and the scrapwood's heart on another
## body moved 200 tiles. So a site reads only the sites on its own body, and its
## jitter is a hash of its type and its cell. One body: as it always was.
static func _envelope_sites(c: GenContext, rng: RandomNumberGenerator, out: Array[Vector3]) -> void:
	var several := c.bodies.size() > 1
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
				var body := c.w.continent_at(floori(p.x), floori(p.y)) if several else 0
				for s: Vector3 in out:
					if several and c.w.continent_at(floori(s.x), floori(s.y)) != body:
						continue
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
				score += (Rng.hash01(c.s, floori(p.x), floori(p.y), 0x5E70 + cc) if several else rng.randf()) * 0.25
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
	var specs := []
	specs.append_array([
		[F, GenFields.noise(c.s, 221, 1.0 / 15.0, 3), 2],
		# Bends at the scale of a walk, so no border runs ruler-straight.
		[F, GenFields.noise(c.s, 224, 1.0 / 70.0, 2), 4],
		[F, GenFields.noise(c.s, 222, 1.0 / 34.0, 2, FastNoiseLite.TYPE_PERLIN), 4],
		[F, GenFields.noise(c.s, 223, 1.0 / 70.0, 2), 8],
		[GenFields.SMOOTH, elev, 3],
	])
	var fl := GenFields.batch(size, specs)
	# THE SCORES ARE NEVER WHOLE. Every type's score upsampled to every tile was
	# (types - 1) world-sized fields at once -- 270 MB at 1840, the high-water of
	# the whole generation (GenContext.memory: 675 MB at `tiles.coarse`), and in a
	# browser the heap keeps its high-water for good. Each band of the tile loop
	# upsamples the rows it reads (`_band_scores`, the world's own cells and
	# weights, so the same values tile for tile) and lets them go.
	var finger := fl[0]
	var bend := fl[1]
	var tongue := fl[2]
	var widen := fl[3]
	var elev_smooth := fl[4]
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
				ct[k] = clampf(ct[k] - maxf(0.0, minf(elev[ty * size + tx], GenRelief.TUNED_TOP) - 5.0) * 0.035, 0.0, 1.0)
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
	# Per slot and type, the same slots the coarse weights balanced in: a land tile
	# pushes in its own body's slot, and on one body every tile is slot 0.
	var push := PackedFloat32Array()
	push.resize(SLOTS * types)
	# stride 1 writes every tile; a larger stride only counts a sample, by type,
	# into parts (one count per band).
	var restricted := not c.allow.is_empty()
	var body := w.continent
	# A BODY DEALT ONE TYPE IS THAT TYPE, every tile of it. `_best_two` answers it
	# with the type twice, and a border between a type and itself has a margin of
	# nothing, so every one of its tiles took the long way round (gradient,
	# tongues, climb) to the answer it started with: 19 of the underground's 41 s
	# at 1840, a realm of one landscape. Per body: that type, or 0 for a body with
	# a choice.
	var only := PackedInt32Array()
	only.resize(256)
	if restricted:
		for id in mini(only.size(), c.allow.size() / types):
			var one := 0
			for cc in range(1, types):
				if c.may_stand(cc, id):
					one = cc if one == 0 else -1
			only[id] = maxi(one, 0)
	# Every type's scores as the image its bands crop, made once.
	var score_images: Array[Image] = [null]
	for cc in range(1, types):
		score_images.append(GenFields.grid_image(c.scores[cc], cw))
	var assign := func(stride: int, parts: Array[PackedInt32Array]) -> void:
		GenFields.rows(size, func(y0: int, y1: int) -> void:
			var counts := PackedInt32Array()
			counts.resize(SLOTS * types)
			# The band's scores, two rows more each way for the margin's gradient:
			# `flat[(cc - 1) * bn + li]`, li the tile's index in the band.
			var ra := maxi(y0 - 2, 0)
			var flat := _band_scores(c, score_images, ra, mini(y1 + 2, size))
			var bn := (mini(y1 + 2, size) - ra) * size
			for y in range(y0, y1):
				if y % stride != 0:
					continue
				var row := y * size
				var lrow := (y - ra) * size
				for x in range(0, size, stride):
					var i := row + x
					var li := lrow + x
					if land[i] == 0:
						if stride == 1:
							country[i] = Country.SEA
							country2[i] = top1[(y / step) * cw + x / step]
						continue
					if restricted and only[body[i]] > 0:
						var one := only[body[i]]
						if stride == 1:
							country[i] = one
							country2[i] = one
						else:
							counts[body[i] * types + one] += 1
						continue
					var a := 1
					var b := 2
					var sa := flat[li]
					var sb := flat[bn + li]
					if sb > sa:
						a = 2
						b = 1
						sa = flat[bn + li]
						sb = flat[li]
					for cc in range(3, types):
						var v := flat[(cc - 1) * bn + li]
						if v > sa:
							b = a
							sb = sa
							a = cc
							sa = v
						elif v > sb:
							b = cc
							sb = v
					if restricted and not (c.may_stand(a, body[i]) and c.may_stand(b, body[i])):
						# The coarse cells round a thin neck of land can be sea, which
						# no deal restricts, so the upsampled scores may still offer a
						# type this body was not dealt. Pick again among those it was.
						var got := _best_two(flat, bn, li, types, c, body[i])
						a = got.x
						b = got.y
						sa = flat[(a - 1) * bn + li]
						sb = flat[(b - 1) * bn + li]
					var lo := mini(a, b)
					var hi := maxi(a, b)
					var bl := (lo - 1) * bn
					var bh := (hi - 1) * bn
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
						var lia := lrow + xa
						var lib := lrow + xb
						var lja := (ya - ra) * size + x
						var ljb := (yb - ra) * size + x
						var gx := (flat[bl + lib] - flat[bh + lib]) - (flat[bl + lia] - flat[bh + lia])
						var gy := (flat[bl + ljb] - flat[bh + ljb]) - (flat[bl + lja] - flat[bh + lja])
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
							m -= sgn * (minf(elev[i], GenRelief.TUNED_TOP) - 6.5)
							gx -= sgn * (elev_smooth[ib] - elev_smooth[ia])
							gy -= sgn * (elev_smooth[jb] - elev_smooth[ja])
						var grad := maxf(0.25, sqrt(gx * gx + gy * gy) / float(maxi(1, xb - xa + yb - ya) / 2))
						var pat := (body[i] * types) if restricted else 0
						var d := m / grad + finger[i] * amp + bend[i] * 22.0 + push[pat + lo] - push[pat + hi]
						win = hi if d < 0.0 else lo
					if stride == 1:
						country[i] = win
						country2[i] = hi if win == lo else lo
					else:
						counts[((body[i] * types) if restricted else 0) + win] += 1
			if stride > 1:
				parts[y0 / 12] = counts
		)
	# The layout was balanced on the coarse grid; the fingers, bends, tongues
	# and the climbing borders then move every border. Measure the shares that
	# result on a sample, push each border out or in by the error, and measure
	# again, so every seed keeps its landscapes near their targets.
	var target := c.share_target if not c.share_target.is_empty() else targets(c)
	var slot_target := _slot_targets(c, target)
	var parts: Array[PackedInt32Array] = []
	parts.resize(ceili(float(size) / 12))
	var gain := 60.0 * size / 512.0
	# On a continent the climb (`border_elevation`) moves a border through a
	# margin whose gradient is shallow between hearts far apart, so it carries
	# the border much further than on one island: more reach and passes, damped
	# (a step halves when its error changes sign) because a tile of push there
	# moves a great deal of land.
	var reach := PUSH_MOST * _place_scale(c) * _place_scale(c)
	var passes := BALANCE_PASSES if _place_scale(c) <= 1.0 else BALANCE_PASSES * 3
	var damped := _place_scale(c) > 1.0
	var damp := PackedFloat32Array()
	damp.resize(SLOTS * types)
	damp.fill(1.0)
	var last_err := PackedFloat32Array()
	last_err.resize(SLOTS * types)
	for it in passes:
		assign.call(BALANCE_STRIDE, parts)
		for sl: int in slot_target:
			var want: PackedFloat32Array = slot_target[sl]
			var at := sl * types
			var counts := PackedFloat32Array()
			counts.resize(types)
			var total := 0.0
			for part in parts:
				for cc in types:
					counts[cc] += part[at + cc]
					total += part[at + cc]
			for cc: int in c.land_types:
				var err := want[cc] - counts[cc] / maxf(1.0, total)
				if damped:
					if err * last_err[at + cc] < 0.0:
						damp[at + cc] = maxf(0.05, damp[at + cc] * 0.5)
					last_err[at + cc] = err
				push[at + cc] = clampf(push[at + cc] + err * gain * damp[at + cc], -reach, reach)
	c.mark(&"tiles.balance")
	assign.call(1, parts)
	c.mark(&"tiles.assign")
	_dry_shores(c)
	c.coarse_country = sample(country, size, cw, step)
	_absorb_enclaves(c, roundi(ENCLAVE_TILES * c.body_k * c.body_k * _place_scale(c) * _place_scale(c)))
	c.mark(&"tiles.enclaves")
	if with_blend:
		_blend(c, widen)
	c.mark(&"tiles.blend")
	regions(c)
	c.mark(&"tiles.regions")


## Every type's score upsampled to the world's rows ya..yb, end to end: type cc
## at (cc - 1) * rows * size. `GenFields.upsample_rows`, so each value is the one
## the whole-world upsample gives that tile.
static func _band_scores(c: GenContext, images: Array[Image], ya: int, yb: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for cc in range(1, c.types):
		out.append_array(GenFields.upsample_rows_of(images[cc], c.cw, GenContext.STEP, c.size, ya, yb - ya))
	return out


## The two best-scoring types body `id` was dealt, at tile `i`, best first. Only
## asked where the plain best two include a type the body may not hold, so its
## cost is paid on a strip of coast and not on the world.
static func _best_two(flat: PackedFloat32Array, n: int, i: int, types: int, c: GenContext, id: int) -> Vector2i:
	var a := -1
	var b := -1
	var sa := -INF
	var sb := -INF
	for cc in range(1, types):
		if not c.may_stand(cc, id):
			continue
		var v := flat[(cc - 1) * n + i]
		if v > sa:
			b = a
			sb = sa
			a = cc
			sa = v
		elif v > sb:
			b = cc
			sb = v
	# A body dealt one type has no second: the border rules need a pair, and a
	# pair of the same type draws no border.
	return Vector2i(maxi(a, 1), b if b >= 1 else maxi(a, 1))


## Pieces of a type smaller than min_tiles take the land type most common along
## their edge (islets, with no land neighbours, stay). Runs before the ecotones
## are measured, so the blend follows the borders that remain.
## A LANDSCAPE BOUND TO THE SEA (BiomeDef.sea_bound: the coast, the frost sea)
## HOLDS NO PLACE THE SEA DOES NOT REACH. Its keeper and works stand at the open
## water (the coast's intake on the shore), and a run of it walled off from the
## sea by another landscape was a coast with no coast: 90210's coast r23 (9,485 tiles, its nearest sea 16 off) and seed 1's
## frost sea r22 (13,822 tiles, 54 off), with no keeper or works in either.
## Asked of the PLAN (the sampled landscape every region is cut from,
## `regions`): a run of a shore type none of whose cells touches the open sea
## or the square's edge takes the landscape round it, by the votes of its
## border, tile for tile, its own type kept as the second for the blend. A run
## with no other land round it is left as it is.
static func _dry_shores(c: GenContext) -> void:
	var w := c.w
	var cw := c.cw
	var step := GenContext.STEP
	var size := c.size
	var types := c.types
	var shore := PackedByteArray()
	shore.resize(types)
	var any := false
	for cc: int in c.land_types:
		if c.defs[cc].sea_bound:
			shore[cc] = 1
			any = true
	if not any:
		return
	var plan := sample(w.country, size, cw, step)
	var n := cw * cw
	var sea := PackedByteArray()
	sea.resize(n)
	# THE OPEN SEA: water the square's edge reaches. Water the land closes round
	# all the way is SEA to the plan too, and is no shore for a coast.
	var open_sea := PackedByteArray()
	open_sea.resize(n)
	var reach := PackedInt32Array()
	for k in n:
		sea[k] = 1 if plan[k] == Country.SEA else 0
		var gx := k % cw
		var gy := k / cw
		if sea[k] != 0 and (gx == 0 or gy == 0 or gx == cw - 1 or gy == cw - 1):
			open_sea[k] = 1
			reach.append(k)
	var at := 0
	while at < reach.size():
		var k := reach[at]
		at += 1
		for m: int in [k - 1, k + 1, k - cw, k + cw]:
			if m >= 0 and m < n and absi(m % cw - k % cw) <= 1 and sea[m] != 0 and open_sea[m] == 0:
				open_sea[m] = 1
				reach.append(m)
	var sizes := PackedInt32Array()
	var label := GenFields.patches(plan, sea, cw, sizes)
	var wet := PackedByteArray()
	wet.resize(sizes.size())
	var votes := {}
	for k in n:
		var la := label[k]
		if la < 0 or shore[plan[k]] == 0:
			continue
		var gx := k % cw
		var gy := k / cw
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var x := gx + dx
				var y := gy + dy
				if x < 0 or y < 0 or x >= cw or y >= cw or open_sea[y * cw + x] != 0:
					wet[la] = 1
					continue
				if sea[y * cw + x] != 0:
					continue
				var m := y * cw + x
				if (dx == 0 or dy == 0) and label[m] != la and shore[plan[m]] == 0:
					var v: PackedInt32Array = votes.get(la, PackedInt32Array())
					if v.is_empty():
						v.resize(types)
					v[plan[m]] += 1
					votes[la] = v
	var winner := {}
	for la: int in votes:
		if wet[la] != 0:
			continue
		var v: PackedInt32Array = votes[la]
		var best := 0
		for cc in range(1, types):
			if v[cc] > v[best]:
				best = cc
		if best > 0:
			winner[la] = best
	if winner.is_empty():
		return
	var country := w.country
	var country2 := w.country2
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for y in range(y0, y1):
			var gy := mini(y / step, cw - 1)
			for x in size:
				var k := gy * cw + mini(x / step, cw - 1)
				var la := label[k]
				if la < 0 or not winner.has(la):
					continue
				var i := y * size + x
				if country[i] == plan[k]:
					country2[i] = country[i]
					country[i] = winner[la]
	)


static func _absorb_enclaves(c: GenContext, min_tiles: int) -> void:
	absorb(c.w.country, c.w.country2, c.size, c.types, min_tiles)


## `_absorb_enclaves` over one square of `size` tiles: the whole world, or a
## section with ENCLAVE_REACH + 1 tiles of the world round its own. A run that
## reaches the square's edge is never an enclave: in the world the edge is sea,
## and in a section it is a run the square cannot see the end of.
static func absorb(country: PackedByteArray, country2: PackedByteArray, size: int, types: int, min_tiles: int) -> void:
	var n := country.size()
	var sea := PackedByteArray()
	sea.resize(n)
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
	# Each small run's box (x0, y0, x1, y1), from its own tiles only.
	var box := {}
	for part in parts:
		for i in part:
			var la := label[i]
			var x := i % size
			var y := i / size
			var r: Vector4i = box.get(la, Vector4i(x, y, x, y))
			box[la] = Vector4i(mini(r.x, x), mini(r.y, y), maxi(r.z, x), maxi(r.w, y))
	var far := {}
	for la: int in box:
		var r: Vector4i = box[la]
		# A run touching the square's first or last usable row or column may go
		# on past it (the passes above never read the outermost ring).
		if r.z - r.x + 1 > ENCLAVE_REACH or r.w - r.y + 1 > ENCLAVE_REACH or r.x <= 1 or r.y <= 1 or r.z >= size - 2 or r.w >= size - 2:
			far[la] = true
	var votes := {}
	for part in parts:
		for i in part:
			var la := label[i]
			if far.has(la):
				continue
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


## Land as one value, so `GenFields.patches` answers with one patch per CONTINENT
## rather than one per landscape. The sea is masked out by the same `fixed` array
## the run pass uses, so the two labellings line up tile for tile.
static func _land_mask(country: PackedByteArray, n: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(n)
	for i in n:
		out[i] = 0 if country[i] == Country.SEA else 1
	return out


## The tile a coarse cell reads the fine world at (the same centre every coarse
## pass samples).
static func sample_tile(g: int, step: int, size: int) -> int:
	return clampi(roundi(g * step + step * 0.5 - 0.5), 0, size - 1)


## The fine landscape at every coarse cell's sample tile.
static func sample(country: PackedByteArray, size: int, cw: int, step: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(cw * cw)
	for gy in cw:
		var row := sample_tile(gy, step, size) * size
		for gx in cw:
			out[gy * cw + gx] = country[row + sample_tile(gx, step, size)]
	return out


## Every connected run of one landscape type is a REGION of that type: one type
## can hold several in a world, and a sentinel, a works network, a subarc and a
## save all key on a region's id (docs/VISION.md, §7.2). Runs too small to
## be a place are left out; their tiles keep their type and belong to no region.
##
## THE PLAN DECIDES THEM (streamed worldgen S4e4). A run can be as long as the
## island, so which runs are regions, how big, and which is biggest are asked
## of the plan's landscapes (`coarse_country`), one sample every STEP tiles;
## each tile then takes its region from the cells round it (`tile_regions`),
## which a section can do with its own tiles and the plan's cells.
static func regions(c: GenContext) -> void:
	var w := c.w
	var plan := plan_regions(c.coarse_country, c.cw, GenContext.STEP, c.size, c.land_types.size())
	w.regions.clear()
	for r: Dictionary in plan.regions:
		w.regions.append(r)
	w.plan_country = c.coarse_country
	w.plan_cells = plan.cells
	w.region.resize(c.n)
	w.region.fill(0)
	tile_regions(w.country, c.size, Vector2i.ZERO, plan.cells, c.coarse_country, c.cw, GenContext.STEP, c.size, w.region)


## REGION `id`'S OWN KEY, for whatever is thrown in it: its landscape and the
## plan cell its centre lies in, which only its own land decides. Never its id:
## ids rank every region of the world biggest-first, so a landscape moved on
## another continent renumbered home's regions and laid home's tips and works
## again (seed 1: the camp 190 tiles, the yard 32). Keyed on itself, a body's
## places depend on that body alone (tests/biome/test_body_independence.gd).
## No region (-1) keys as itself.
static func region_key(w: WorldData, id: int) -> int:
	if id < 0 or id >= w.regions.size():
		return id
	var r: Dictionary = w.regions[id]
	var at: Vector2 = r.get("centre", Vector2.ZERO)
	return Rng.hash_ints(int(r.get("index", 0)), floori(at.x / GenContext.STEP), floori(at.y / GenContext.STEP))


## The plan's regions: {"regions": the records, ids biggest first, "cells": per
## coarse cell its region id + 1, 0 where the cell holds none}. Tiles, centre
## and bounds are the cells' (a cell stands for STEP x STEP tiles); the bounds
## reach two cells past them, as far as `tile_regions` looks.
static func plan_regions(coarse: PackedByteArray, cw: int, step: int, size: int, land_types: int) -> Dictionary:
	var n := cw * cw
	var sea := PackedByteArray()
	sea.resize(n)
	for k in n:
		sea[k] = 1 if coarse[k] == Country.SEA else 0
	var sizes := PackedInt32Array()
	var label := GenFields.patches(coarse, sea, cw, sizes)
	# **THE FLOOR IS A SHARE OF THE BODY THE RUN LIES ON** (owner, 2026-09-19).
	# A run of one landscape is connected land, so it lies wholly within one
	# continent, and `body_of` says which. See `BODY_SHARE`.
	var body_sizes := PackedInt32Array()
	var body := GenFields.patches(_land_mask(coarse, n), sea, cw, body_sizes)
	var cell := step * step
	var floor_of := PackedInt32Array()
	floor_of.resize(sizes.size())
	for k in n:
		if sea[k] != 0:
			continue
		var la := label[k]
		if floor_of[la] == 0:
			floor_of[la] = maxi(PLACE_LEAST, roundi(BODY_SHARE * float(body_sizes[body[k]] * cell) / float(maxi(1, land_types))))
	# Biggest first, so region 0 is the largest place in the world and ids stay
	# stable as long as the shape of the land does.
	var order: Array[int] = []
	for la in sizes.size():
		if floor_of[la] > 0 and sizes[la] * cell >= floor_of[la]:
			order.append(la)
	order.sort_custom(func(a: int, b: int) -> bool:
		if sizes[a] != sizes[b]:
			return sizes[a] > sizes[b]
		return a < b)
	var rid_of := PackedInt32Array()
	rid_of.resize(n)
	for r in order.size():
		rid_of[order[r]] = r + 1
	var cells := PackedInt32Array()
	cells.resize(n)
	var sum := PackedFloat64Array()
	sum.resize(order.size() * 2)
	var lo := PackedInt32Array()
	var hi := PackedInt32Array()
	lo.resize(order.size() * 2)
	hi.resize(order.size() * 2)
	lo.fill(1 << 30)
	hi.fill(-(1 << 30))
	for k in n:
		var la := label[k]
		if la < 0 or rid_of[la] == 0:
			continue
		var rid := rid_of[la] - 1
		cells[k] = rid + 1
		var gx := k % cw
		var gy := k / cw
		sum[rid * 2] += sample_tile(gx, step, size) + 0.5
		sum[rid * 2 + 1] += sample_tile(gy, step, size) + 0.5
		lo[rid * 2] = mini(lo[rid * 2], gx)
		lo[rid * 2 + 1] = mini(lo[rid * 2 + 1], gy)
		hi[rid * 2] = maxi(hi[rid * 2], gx)
		hi[rid * 2 + 1] = maxi(hi[rid * 2 + 1], gy)
	var out: Array[Dictionary] = []
	for r in order.size():
		var la := order[r]
		var cc := coarse[la]
		var x0 := clampi((lo[r * 2] - 2) * step, 0, size)
		var y0 := clampi((lo[r * 2 + 1] - 2) * step, 0, size)
		var x1 := clampi((hi[r * 2] + 3) * step, 0, size)
		var y1 := clampi((hi[r * 2 + 1] + 3) * step, 0, size)
		out.append({
			"id": r, "type": BiomeRegistry.by_index(cc).id, "index": cc, "tiles": sizes[la] * cell,
			"centre": Vector2(sum[r * 2] / sizes[la], sum[r * 2 + 1] / sizes[la]),
			"bounds": Rect2(x0, y0, x1 - x0, y1 - y0),
		})
	return {"regions": out, "cells": cells}


## Each tile's region, over a square of `size` tiles at `origin` in a world
## `world_size` wide: the region of the cell it lies in when that cell holds its
## landscape, else of the nearest cell within two that does, else none. Writes
## `region` (id + 1, 0 for none) for the square's tiles.
static func tile_regions(country: PackedByteArray, size: int, origin: Vector2i, cells: PackedInt32Array,
		coarse: PackedByteArray, cw: int, step: int, world_size: int, region: PackedInt32Array) -> void:
	# Ring order out to two cells, nearest first, a fixed order within a ring.
	var rings: Array[Vector2i] = []
	for r in range(1, 3):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r:
					rings.append(Vector2i(dx, dy))
	rings.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := a.length_squared()
		var db := b.length_squared()
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for y in range(y0, y1):
			var wy := origin.y + y
			for x in size:
				var i := y * size + x
				var t := country[i]
				if t == Country.SEA:
					region[i] = 0
					continue
				var wx := origin.x + x
				var g := Vector2i(_cell_of(wx, step, cw, world_size), _cell_of(wy, step, cw, world_size))
				var k := g.y * cw + g.x
				if coarse[k] == t:
					region[i] = cells[k]
					continue
				var got := 0
				for d in rings:
					var q := g + d
					if q.x < 0 or q.y < 0 or q.x >= cw or q.y >= cw:
						continue
					var kq := q.y * cw + q.x
					if coarse[kq] == t:
						got = cells[kq]
						break
				region[i] = got
	)


## The coarse cell a tile lies in (STEP tiles to a cell, the last cell taking any rest).
static func _cell_of(t: int, step: int, cw: int, size: int) -> int:
	return clampi(floori(float(t) / step), 0, cw - 1)


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
	# A BODY'S ECOTONES ARE ITS OWN. The nearest border was spread over the sea
	# too, so a shore took its blend from a border on the far side of a strait,
	# and a landscape moved there re-blended home's facing shore (seed 1: 3,877
	# tiles). Each cell is its body's, a sea cell its nearest body's (the coarse
	# weight slot), and a border spreads only over its own body's cells. One body:
	# every cell is one owner's, as it always was.
	var owner := PackedInt32Array()
	owner.resize(hn)
	if not c.allow.is_empty():
		var cw := c.cw
		GenFields.rows(hw, func(g0: int, g1: int) -> void:
			for gy in range(g0, g1):
				var ty := mini(gy * 2, size - 1)
				for gx in hw:
					var tx := mini(gx * 2, size - 1)
					var id := w.continent_at(tx, ty)
					owner[gy * hw + gx] = id if id != GenBodies.VOID else c.weight_slot[clampi(ty / GenContext.STEP, 0, cw - 1) * cw + clampi(tx / GenContext.STEP, 0, cw - 1)]
		)
	# How wide an ecotone runs on each body, and exact past the widest of them.
	var reach := GenBodies.by_tile(w, _ecotone_reach(c))
	var spread := GenFields.banded([dist, pair, owner], hw, ceili(ECOTONE_MOST * 0.5) + 2, func(arrays: Array, width: int) -> Array:
		var dd: PackedFloat32Array = arrays[0]
		var pp: PackedInt32Array = arrays[1]
		var oo: PackedInt32Array = arrays[2]
		_spread_labelled(dd, pp, oo, width, 2.0)
		return [dd, pp, oo]
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
				# One to two of the body's `_ecotone_reach`, wandering along the
				# border. Every ecotone keeps inside it, the Burning's ash included.
				var least := reach[i]
				var width := least + least * clampf(0.5 + widen[i] * 1.4, 0.0, 1.0)
				var fade := maxf(clampf((seam_d[i] * 510.0 - 1.0) / 8.0, 0.0, 1.0), 1.0 - d / 2.0)
				blend[i] = (0.5 - 0.5 * d / width) * fade if d < width else 0.0
	)


## The narrowest an ecotone runs, per body id, in tiles: a share of how far a
## walk crosses one of the body's landscapes, never under the one island's 12.
## The widest is twice it. A fixed 12-24 was a line across a place 300 tiles wide.
const ECOTONE_SHARE := 0.12
const ECOTONE_LEAST := 12.0
## The widest any ecotone runs: what the distance spread is exact to.
const ECOTONE_MOST := 64.0


static func _ecotone_reach(c: GenContext) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(256)
	out.fill(ECOTONE_LEAST)
	for row: Dictionary in c.w.continents:
		var types := (row.get("types", PackedInt32Array()) as PackedInt32Array).size()
		if types <= 0:
			continue
		var across := sqrt(float(row.get("tiles", 0)) / float(types))
		out[int(row.get("id", 0))] = clampf(across * ECOTONE_SHARE, ECOTONE_LEAST, ECOTONE_MOST * 0.5)
	return out


## Two-sweep 8-neighbour chamfer distance (cell = `unit` tiles) that also
## carries each source's label to the cells it is nearest, never from a cell of
## one `owner` to another's.
static func _spread_labelled(d: PackedFloat32Array, label: PackedInt32Array, owner: PackedInt32Array, width: int, unit: float) -> void:
	var height := d.size() / width
	var dc := unit * 1.4142
	for y in height:
		var row := y * width
		for x in width:
			var i := row + x
			var m := d[i]
			var lb := label[i]
			var o := owner[i]
			if x > 0 and owner[i - 1] == o and d[i - 1] + unit < m:
				m = d[i - 1] + unit
				lb = label[i - 1]
			if y > 0:
				var j := i - width
				if owner[j] == o and d[j] + unit < m:
					m = d[j] + unit
					lb = label[j]
				if x > 0 and owner[j - 1] == o and d[j - 1] + dc < m:
					m = d[j - 1] + dc
					lb = label[j - 1]
				if x < width - 1 and owner[j + 1] == o and d[j + 1] + dc < m:
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
			var o := owner[i]
			if x < width - 1 and owner[i + 1] == o and d[i + 1] + unit < m:
				m = d[i + 1] + unit
				lb = label[i + 1]
			if y < height - 1:
				var j := i + width
				if owner[j] == o and d[j] + unit < m:
					m = d[j] + unit
					lb = label[j]
				if x < width - 1 and owner[j + 1] == o and d[j + 1] + dc < m:
					m = d[j + 1] + dc
					lb = label[j + 1]
				if x > 0 and owner[j - 1] == o and d[j - 1] + dc < m:
					m = d[j - 1] + dc
					lb = label[j - 1]
			d[i] = m
			label[i] = lb
