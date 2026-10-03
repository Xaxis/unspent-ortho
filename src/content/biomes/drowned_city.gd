## Drowned City: towers standing in the tide, streets running as canals, and the
## machines' ferries keeping to a timetable nobody set. VISION §3 row 10.
##
## WHAT IT ARGUES WITH: the water is not a wall here, it is the STREET. Every
## other landscape treats deep water as the edge of the walk (`Swim`), and this
## one is laid out so that the water is the way through and the buildings are the
## banks. A raft stops being a crossing and becomes transport, which is the first
## time in this game a craft is how you get about rather than how you get past.
##
## It is also the answer to the city reading as one note: the Slums is a city
## still running, and this is the same idea drowned — the same towers, the same
## streets, with the sea in them. Two cities that argue about what happened
## rather than two cities that look different.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"drowned_city"
	d.display_name = "the drowned city"
	d.spoken_in = "in the drowned city"
	d.order = 15
	d.style_note = "Green-black water between concrete, tide lines up every wall, nothing dry at ground level."
	d.share = Vector2(0.05, 0.09)
	# The first place across the water: the raft from home comes ashore in it,
	# and the story's second leg is cast here (docs/ROADMAP.md slice 3 step 6).
	d.spread = BiomeDef.LANDFALL
	d.anchors = [{"seq": 15, "u": 0.62, "v": 0.66}]
	d.temp_range = Vector2(0.35, 0.75)
	d.moist_range = Vector2(0.65, 1.0)
	d.adjacency = {&"coast": 0.45, &"slums": 0.3, &"moss": 0.2}
	# It IS the sea's: the drowned part of a coast, never inland.
	d.coastal = 1.0
	# Flat and LOW — the streets are at sea level because that is what drowned
	# them — with the towers doing all the standing up.
	d.relief = {
		&"base": 2.2, &"hills": 0.7, &"ridge": 1.2, &"near": 2.5, &"terrace": 0.3, &"valley": 1.8,
		&"rain": 1.2, &"temp": 0.1, &"moist": 0.9, &"cliff": 0.35,
		# Its streets' spacing: the ground is laid a level to a block
		# (GenRelief.flatten_streets), so a canal runs level from crossing to
		# crossing and the steps fall behind the frontages, back to back.
		&"streets": STREET_PITCH,
		# And it meets the sea as the port it was: flat at the lowest land's level
		# to the water's edge, a quay wall down to a raft, never a terraced hill.
		&"quays": 1.0,
	}
	d.border_elevation = -0.8
	d.reach_out_high = Vector4(3.5, 0.05, 0.07, 0.25)
	d.reach_in_low = Vector3(6.0, 0.1, 0.35)
	d.hatch = Ink.NONE
	d.grounds = {
		# Poured concrete the tide came up over, silted green-grey: darker and
		# greener than a dry floor (which read as snow at eye level), and apart
		# from every other landscape's turf (test_terrain holds them apart).
		Ground.FLOOR: P.SPRUCE[2].lerp(P.MOSS[2], 0.3).lerp(P.ASH[2], 0.35),
		Ground.ROAD: P.ASH[2].lerp(P.SLATE[2], 0.4),
		Ground.MUD: P.EARTH[2].lerp(P.SPRUCE[2], 0.45),
		# The quay's edge and its apron are wet stone, under the floor in value:
		# at the STONE's third step they read as snow from the raft.
		Ground.SHINGLE: P.STONE[2].lerp(P.SPRUCE[1], 0.35),
		Ground.GRAVEL: P.STONE[2].lerp(P.ASH[2], 0.4),
		Ground.MOSS: P.MOSS[2].lerp(P.SPRUCE[2], 0.5),
		Ground.BLACKWATER: P.SPRUCE[1],
	}
	# Every ground it does not name, named anyway: anything left unnamed falls
	# through to the shared table, which is the COAST's and is far brighter than
	# here, so it would arrive as the loudest object in the frame. A list of the
	# missing ones let grass through. The green ones take this landscape's weed,
	# the rest its gravel, because they only have to be in key. Not steel floor:
	# that is an interior's, no world lays it, and a wash for it is dead paint
	# (test_registry).
	for g: int in Ground.COUNT:
		if d.grounds.has(g) or Ground.is_water(g) or g == Ground.STEEL_FLOOR:
			continue
		var green := g in [Ground.GRASS, Ground.HEATH, Ground.NEEDLES, Ground.PEAT]
		d.grounds[g] = d.grounds[Ground.MOSS if green else Ground.GRAVEL]
	d.cliff_wash = P.ASH[2].lerp(P.SPRUCE[2], 0.35)
	# THE TIDE IS DRAWN ON EVERYTHING, and it is a LOOK choice only: the floor
	# stays FLOOR to worldgen and no seed moves. Its floor is silted under one
	# high-water line and stands in puddles (GroundColors.TIDEFLAT), and every
	# wall carries that same line at the same height -- weed under the working
	# tide, a white band of salt at the flood's, bleached pour lines above
	# (STRATA_TIDE). Before this the floor was a dry pale wash and the walls were
	# the scrapwood's made ground, and at eye level the city read as snow.
	d.ground_marks = {Ground.FLOOR: GroundColors.TIDEFLAT}
	d.strata = GroundColors.STRATA_TIDE
	d.plain_ground = Ground.FLOOR
	d.bank_ground = Ground.MUD
	d.pool_rim_ground = Ground.MUD
	d.village_ground = Ground.FLOOR
	# Its inland water is the street, so it is drawn as water and never as a hole.
	d.water_wash = P.SPRUCE[2].lerp(P.MOSS[2], 0.3)
	# On the floor, what the flood left of the people it went through, and the
	# city's own broken cast stone; nothing grows on it but the weed in the wet.
	d.decor = {
		Ground.MOSS: [0.55, Decor.TUFT, 20, Decor.SCRAP, 10],
		Ground.FLOOR: [0.22, Decor.DROWNED_LITTER, 10, Decor.REBAR, 6, Decor.SCRAP, 6, Decor.PEBBLES, 6],
	}
	d.grass_colors = [P.MOSS[2], P.SPRUCE[2]]
	d.rock_color = P.ASH[3]
	d.decor_tints = {&"fronds": [P.MOSS[2], P.SPRUCE[2], P.ASH[2]]}
	# Everything below the tide line is green and slick; everything above it is
	# salt-bleached concrete. That line is the whole palette.
	var dress := BiomeDressing.new()
	dress.stone = [P.ASH[3], P.STONE[3], P.SPRUCE[2]]
	dress.concrete = P.ASH[3]
	dress.walling = [P.ASH[2], P.STONE[3], P.SPRUCE[2], P.SLATE[2]]
	dress.sink = 0.16
	dress.lie = Vector2(-0.06, 0.1)
	# Timber that has stood in salt water for a lifetime goes grey, not brown:
	# the piles, the boards of a stilt house, a punt (docs/LANDSCAPES.md).
	dress.timber = [P.ASH[3].lerp(P.STONE[3], 0.35), P.ASH[2].lerp(P.SLATE[2], 0.3)]
	# What the tide leaves on anything it reaches: a line of weed hung on it and
	# rust where the salt gets in. The spec says "weed below the tide line";
	# that is `wrack` in BiomeDressing's words -- its `weed` is reeds up through
	# bog water, which is the moss's and not a tide's.
	dress.covers = &"wrack"
	# People here put up a hut on stilts over the water when they put up
	# anything (props/remains.gd `stilt`): the spec's stilt house, and the one
	# patched shelter already made of piles.
	dress.shelter = &"stilt"
	d.dressing = dress
	# Blocks, because it was a city before the water came in — the streets between
	# them are what the sea is standing in now, and a `row` would make it one
	# waterfront rather than a grid with canals through it.
	# ITS OWN STOCK, and not a trimmed RAISED (docs/LANDSCAPES.md): what people
	# live in here is what the water left them. The first floor of a flooded
	# block with the ground floor given to the sea, a timber house on piles over
	# the mud, and a barge moored for good with a shed on its deck. Low, as the
	# port always was, so the silhouette against the sea stays a long flat one
	# and the standing water reads as the thing out of place. The fourth is the
	# city's gutted SHELL, nobody's home, because a block of 14-22 cannot keep
	# `repeat_apart` with three shapes: two of one stood 8 tiles apart in Upper
	# Quay (test_houses). Four is what held it before.
	d.built = BiomeForms.new()
	d.built.stock = [&"upper_floor", &"stilt_house", &"hulk_home", &"shell"] as Array[StringName]
	# The stilt house is lived in over the water, and the hulk in the hold of a
	# barge moored for good; each room is its own (content/interiors/).
	d.interiors = {&"form:stilt_house": &"stilt_room", &"form:hulk_home": &"hulk_hold", &"house": &"home"}
	# Behind the other forms, stilt families, wet and raised: the water marked up
	# the wall, the buckets, the hammocks off the floor.
	d.home = {"hearth": &"raised_stove", "households": {
		&"stilter": {"wants": [&"tide_gauge", &"hammock", &"nets", &"buckets"], "by_hearth": []},
		&"bailer": {"wants": [&"buckets", &"buckets", &"oars", &"tide_gauge"],
			"by_hearth": [{"kind": &"fishline", "off": 1.2, "solid": 0.0}]},
	}}
	d.built.plan = &"block"
	d.built.apart = BiomeForms.ROW_APART
	d.built.buildings = Vector2i(14, 22)
	d.built.repeat_apart = 11.0
	d.grade = Vector4(-0.06, 0.02, 0.06, -0.03)
	# NOTHING DRY AT GROUND LEVEL (the style note), and it had never said so: wet
	# is what the sky's soak and every lamp's reflection read (SkyLight.neon_row),
	# so at 0 the city stood dry in the rain it is named for. A LOOK field: no
	# worldgen stage reads it.
	d.wet = 0.5
	# Weed and moss up every wall the tide wets: the green climbs out of the water.
	# (BiomeDef.overgrowth: lighter than the green towers' whole dose.)
	d.overgrowth = 0.6
	d.night_sky = 0.95
	d.props = [PropKind.RUIN, PropKind.DEBRIS, PropKind.WRECKAGE,
		PropKind.SEA_WALL, PropKind.TIDE_GAUGE, PropKind.HULL, PropKind.REEDS, PropKind.POLE,
		# Its own (docs/LANDSCAPES.md, src/models/props/drowned_city.gd),
		# declared here so the drowned city is the ONE landscape whose things
		# these are: that is what makes the tram's copper the city's gate
		# (Sources.lands_yielding). The bands that lay the stairs, trams and
		# piles, and the works row that stands the lock, are the placement
		# wave's; declaring a kind places nothing until a recipe returns it.
		PropKind.STAIR_TO_WATER, PropKind.DROWNED_TRAM, PropKind.MOORING_POST, PropKind.LOCK_GATE]
	d.ore = [[PropKind.IRON_ORE, 0.02], [PropKind.COPPER_ORE, 0.018]]
	# The flooded hall (SiteKinds), a rate per 1,000 tiles of each region.
	d.sites = {"tips": 2, "ruins": true, "flooded_hall": 0.05}
	d.beached_wrecks = true
	d.pools = {"order": 2, "cell": 22, "chance": 0.7, "r_min": 2.4, "r_max": 5.5, "ground": Ground.BLACKWATER}
	d.villages = 1
	d.village_order = 15
	d.village_names = ["Tidemark", "Upper Quay"]
	d.weather = [
		[Weather.GREY, 28, 0.0], [Weather.RAIN, 26, 0.6], [Weather.FOG, 20, 0.0],
		[Weather.CLEAR, 18, 0.0], [Weather.STORM, 8, 0.5],
	]
	d.mist = 0.3
	# In the water more often than out of it, and the streets are deep enough to
	# be over your head where they dip.
	d.hazards = {&"wet": 0.7, &"toxins": 0.35}
	d.roster = {
		&"dredger": {"weight": 1.0, "grounds": ["blackwater", "mud"]},
		&"harvester": {"weight": 0.8, "grounds": ["moss", "mud", "gravel"]},
		&"watcher": {"weight": 0.9},
		&"gulls": {"weight": 1.0, "hours": Vector2(5, 21), "grounds": ["shingle", "gravel"]},
		# Its own machine, found nowhere else: the plan's ferry keeping its
		# timetable on the canals (Roster, `ferry`). Its own row keeps it to the
		# water and to its hours.
		&"ferry": {"weight": 1.2},
	}
	# Its own blocks, standing in the water (`_works`): the city's frontages
	# along its canals, and its roofs out in the shallows.
	d.props.append_array([PropKind.DROWNED_SHELL, PropKind.DROWNED_ROOF])
	GenWorks.register(&"drowned_city", {
		"host": load("res://src/content/biomes/drowned_city.gd"),
		"works": &"_works",
	})
	# The clock tower first: each of its regions puts it down before anything else.
	d.landmarks = [&"clock_tower", &"sump_pump", &"poured_pillar", &"leaning_mast", &"clerks_office"]
	# Its keeper: the barge on stilts that keeps the locks (src/core/sentinel/
	# designs/lockkeeper.gd). The one door by which a landscape claims one.
	d.sentinel = &"lockkeeper"
	d.sound_bed = &"bed_shore"
	d.surface = _surface
	d.scatter = _scatter
	return d


## The tide line decides everything: under it is silt, at it is the slick, and
## above it is the floor somebody poured. One field, two borders.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.SHINGLE
	if f & BiomeSurface.APRON != 0:
		return Ground.GRAVEL
	if f & BiomeSurface.BANK != 0:
		return Ground.MUD
	if _flooded(t, i) and _street(t, i):
		return Ground.BLACKWATER
	if e <= 2.6:
		return Ground.MUD
	return Ground.MOSS if gb > 0.25 else Ground.FLOOR


## THE STREETS ARE WHERE THE SEA STANDS. The water was round pools dropped on a
## cell grid, and the city between them read as a dry plaza with ponds in it.
## A city has streets, and the sea came in along them: a grid of them, as wide
## as a street and as far apart as the blocks it held (`built.buildings` is 14 to
## 22), ruled on the survey bearing as the metropolis's are, because it is the
## same city drowned, is shallow standing water wherever the land lies low, and
## the blocks between keep their frontages (`_works`). Each street's middle line
## stands on a multiple of the pitch, so a crossing is where GenRelief.
## flatten_streets centres a block's floor.
##
## STANDING WATER IS LEVEL. Flooded by elevation, a street ran up the terraces
## and its water stood in steps, a stair of dark tiles (seed 1, 518,414). So it
## floods only on the two lowest levels, where most of the city is (seed 1:
## 8,342 and 22,101 of its 46,238 tiles), and never on a tile with a lower one
## beside it: water stands against a higher wall as a bank, never hangs over a
## drop, so where a street crosses a terrace the upper side is a dry kerb.
const STREET_PITCH := 18.0
const STREET_WIDTH := 3.0
## The highest level a street holds water on; above it the upper town is dry.
const STREET_FLOOD := 2


static func _flooded(t: BiomeSurface, i: int) -> bool:
	# The city's own ground: this recipe also lays the far half of an ecotone,
	# and a street flooded there is the city's water standing in the salt flats
	# (seed 1, 539,314), a stretch of street with no city round it.
	if t.own_def == null or t.own_def.id != &"drowned_city":
		return false
	var l := t.levels[i]
	if l > STREET_FLOOD:
		return false
	return t.levels[i - 1] >= l and t.levels[i + 1] >= l and t.levels[i - t.size] >= l and t.levels[i + t.size] >= l


static func _street(t: BiomeSurface, i: int) -> bool:
	var d := Vector2.from_angle(GenWorks.bearing(t.seed_value))
	var p := Vector2(t.x0 + i % t.size + 0.5, t.y0 + i / t.size + 0.5)
	return _off_street(p.dot(d)) < STREET_WIDTH * 0.5 or _off_street(p.dot(Vector2(-d.y, d.x))) < STREET_WIDTH * 0.5


## How far a coordinate across the grid lies from its nearest street's middle.
static func _off_street(u: float) -> float:
	return absf(u - roundf(u / STREET_PITCH) * STREET_PITCH)


## THE WATER IS STILL IN IT, and that is the whole landscape: a city at the
## waterline rather than a city with a lake in it. So the MUD -- where the tide
## still reaches -- carries the reeds and the poles and the trams sunk where
## their lines ran, and the FLOOR slabs that are still dry carry what came down
## when it came in. The sea walls and the tide gauges are the port's, laid with
## it (`_works`). Nothing here deals PIPE or CONVEYOR: the plan lays its runs at
## scale.
## The silt's tram band: r from 0.70 to this.
const TRAM_BAND := 0.703
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.FLOOR:
		if r < 0.034:
			return PropKind.DEBRIS
		return PropKind.RUIN if r < 0.048 else BiomeScatter.NONE
	if g == Ground.MUD:
		if r < 0.055:
			return PropKind.REEDS
		if r < 0.070:
			return PropKind.POLE
		# A tram half sunk in the silt where its line ran, the city's copper in
		# its cables (Takes: sea_copper, MUD only).
		return PropKind.DROWNED_TRAM if r > 0.70 and r < TRAM_BAND else BiomeScatter.NONE
	if g == Ground.SHINGLE:
		if r < 0.030:
			return PropKind.DEBRIS
		return PropKind.HULL if r > 0.40 and r < 0.4075 else BiomeScatter.NONE
	if g == Ground.MOSS:
		return PropKind.REEDS if r < 0.024 else BiomeScatter.NONE
	if g == Ground.GRAVEL:
		return PropKind.WRECKAGE if r < 0.018 else BiomeScatter.NONE
	if g == Ground.ROAD:
		return PropKind.DEBRIS if r < 0.020 else BiomeScatter.NONE
	return BiomeScatter.NONE


## THE CITY STILL STANDS IN ITS WATER (GenWorks.register). Its streets are the
## surface's (`_street`): a grid STREET_PITCH apart on the survey bearing,
## STREET_WIDTH wide, and water on the low town. Every block between them keeps
## its frontage, a drowned block to each plot along each side with its face to
## the street, so from above the city is its plan and from a raft its streets are
## canals between walls. Past its shore the grid goes on into the sea, as roofs.
static func _works(L: Object) -> void:
	var d: Vector2 = L.d
	var nrm: Vector2 = L.nrm
	# The port first, sited where the region's canals are: its lock, the stairs
	# down off its quays, and the sea walls along them that keep off the stairs.
	# A lock its keeper cannot den by is taken back (`_lock`) and the next reach
	# is tried, never dropped.
	var sites := _lock_sites(L, LOCK_TRIES)
	var next := 0
	for n in GenWorks._n_station(L, 1.0):
		while next < sites.size():
			var at: Vector3 = sites[next]
			next += 1
			if GenWorks._work(L, &"_lock", Vector2(at.x, at.y), [int(at.z)]):
				break
	# THE PORT, when the landfall is this region's: a stair down into the sea on
	# the quay nearest where the raft comes ashore, recorded as `port`. The raft
	# is landed there (StoryCrossing) and the clock stands over it (Landmarks,
	# `wants` the landfall). Darted with the slips, the nearest stood 66 tiles off
	# seed 1's landing.
	for p: Vector2i in _landing(L):
		if GenWorks._work(L, &"_port", Vector2(p) + Vector2(0.5, 0.5)):
			break
	for n in GenWorks._n(L, 6.0):
		var p := GenWorks._shore(L, QUAY_GROUNDS, 18.0)
		if p.x >= 0:
			GenWorks._work(L, &"_slip", Vector2(p) + Vector2(0.5, 0.5))
	for n in GenWorks._n(L, 3.0):
		var p := GenWorks._shore(L, QUAY_GROUNDS, 30.0)
		if p.x >= 0:
			GenWorks._work(L, &"_sea_wall", Vector2(p) + Vector2(0.5, 0.5))
	# The walls of each flooded hall the region's places claimed (SiteKinds lays
	# the black water of its floor; the hall's walls are the city's own fronts).
	var w: WorldData = L.w
	for j in range(L.m_start):
		var m: Dictionary = w.landmarks[j]
		if m.kind == &"flooded_hall" and int(m.get("region", -1)) == int(L.region):
			GenWorks._work(L, &"_hall", m.pos as Vector2)
	for rect: Rect2 in L.rects:
		# The blocks over the region's bounds, and a pitch past them for the
		# roofs off its shore.
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q: Vector2 in [rect.position, rect.position + Vector2(rect.size.x, 0.0), rect.end, rect.position + Vector2(0.0, rect.size.y)]:
			var uv := Vector2(q.dot(d), q.dot(nrm))
			lo = lo.min(uv)
			hi = hi.max(uv)
		for m in range(floori(lo.x / STREET_PITCH) - 1, ceili(hi.x / STREET_PITCH) + 1):
			for n in range(floori(lo.y / STREET_PITCH) - 1, ceili(hi.y / STREET_PITCH) + 1):
				_block(L, d, nrm, m, n)


## How deep a drowned block stands from its street, and how much of the street's
## length it takes (models/props/drowned_city.gd BLOCK_DEEP, BLOCK_ALONG).
const BLOCK_DEEP := 2.4
const BLOCK_ALONG := 3.0


## Block (m, n) of the grid: the land between the streets m and m + 1 along `d`
## and n and n + 1 along `nrm`. Its two sides facing along `d` take the corners.
static func _block(L: Object, d: Vector2, nrm: Vector2, m: int, n: int) -> void:
	var kerb := STREET_WIDTH * 0.5
	var u0 := float(m) * STREET_PITCH + kerb
	var u1 := float(m + 1) * STREET_PITCH - kerb
	var v0 := float(n) * STREET_PITCH + kerb
	var v1 := float(n + 1) * STREET_PITCH - kerb
	for side in 2:
		var u := u0 + BLOCK_DEEP * 0.5 if side == 0 else u1 - BLOCK_DEEP * 0.5
		var t := v0 + BLOCK_ALONG * 0.5
		while t <= v1 - BLOCK_ALONG * 0.5 + 0.01:
			_plot(L, d * u + nrm * t, -d if side == 0 else d)
			t += BLOCK_ALONG
	for side in 2:
		var v := v0 + BLOCK_DEEP * 0.5 if side == 0 else v1 - BLOCK_DEEP * 0.5
		var t := u0 + BLOCK_DEEP + BLOCK_ALONG * 0.5
		while t <= u1 - BLOCK_DEEP - BLOCK_ALONG * 0.5 + 0.01:
			_plot(L, d * t + nrm * v, -nrm if side == 0 else nrm)
			t += BLOCK_ALONG


## One plot of a frontage at `p`, its face to `face`: a drowned block where the
## city's own ground holds it, a roof where the shallows off this region's shore
## do and the city leads that sea (`WorldData.dress_country`, what a prop there
## is dressed as),
## and now and then nothing, a block the water had down altogether. Each
## plot's roll is its own, keyed on the plot.
static func _plot(L: Object, p: Vector2, face: Vector2) -> void:
	var c: GenContext = L.c
	var tx := floori(p.x)
	var ty := floori(p.y)
	if not c.w.in_bounds(tx, ty):
		return
	var key := Vector2i(roundi(p.x * 4.0), roundi(p.y * 4.0))
	if Rng.hash01(c.s, key.x, key.y, 0xD121) < 0.14:
		return
	if L.here(tx, ty):
		GenWorks._put(L, PropKind.DROWNED_SHELL, p, face.angle(), -99, 0.0, true)
	elif c.land[ty * c.size + tx] == 0 and c.w.dress_country(tx, ty) == int(L.own) and Rng.hash01(c.s, key.x, key.y, 0xD122) < 0.55 and _off_here(L, p):
		GenWorks._put_awash(L, PropKind.DROWNED_ROOF, p, face.angle(), 0.0)


## How far out a roof stands from the region's shore.
const ROOFS_OUT := 9


## The nearest land to `p`, along the four ways, lies within ROOFS_OUT and is
## the region being laid: the sea there is this part of the city's.
static func _off_here(L: Object, p: Vector2) -> bool:
	var c: GenContext = L.c
	var best := ROOFS_OUT + 1
	var mine := false
	for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		for r in range(1, ROOFS_OUT + 1):
			var x := floori(p.x) + o.x * r
			var y := floori(p.y) + o.y * r
			if not c.w.in_bounds(x, y):
				break
			if c.land[y * c.size + x] != 0:
				if r < best:
					best = r
					mine = L.here(x, y)
				break
	return mine


# --- the port ------------------------------------------------------------------

## The grounds a quay's edge is laid in (`_surface`: SHORE and APRON), and the
## floor and silt behind them.
const QUAY_GROUNDS: Array = [Ground.SHINGLE, Ground.GRAVEL, Ground.FLOOR, Ground.MUD]

## THE LOCK (docs/LANDSCAPES.md: the port still runs). Across a canal, on the
## street's own line: a flight of two chambers, so four gate leaves in recesses
## of cut stone, the pump house that dries the basin on the bank, and the tide
## gauges logging a sea that keeps rising, which stand here now and not loose in
## the silt. The lockkeeper dens at it and feeds on its leaves and its pump house
## (sentinel/designs/lockkeeper.gd), so a lock that cannot stand LOCK_LEAVES
## leaves is taken back whole: a keeper on a larder of fewer is a starve way won
## by one theft (SentinelWay.FEEDS_LEAST).
const LOCK_LEAVES := 4
## Where along the canal each leaf stands, off the lock's middle (each takes the
## tiles round its own, so two stand at least two apart), and how far that
## middle stands from its crossing: the flight keeps inside one block's
## floor (GenRelief.flatten_streets centres a floor on a crossing and steps it
## halfway to the next), so its canal holds water the whole way along.
const LOCK_GATES: Array[float] = [-3.2, -1.1, 1.1, 3.2]
const LOCK_OFF := 4.8


## How many reaches a region's lock is tried at.
const LOCK_TRIES := 4


## The middles of canal reaches to lock in the region being laid: a flooded
## street LOCK_OFF along from a crossing, water under every leaf and dry banks
## of this region on both sides, off the villages and the spawn; up to `count`
## of them, the nearest the region's heart first (ties in scan order).
## Each (x, y, axis), axis 0 a street running along `nrm` and 1 along `d`.
static func _lock_sites(L: Object, count: int) -> Array[Vector3]:
	var d: Vector2 = L.d
	var nrm: Vector2 = L.nrm
	var heart := Vector2(GenWorks._heart(L))
	# By distance first: the reach's own test reads its leaves and banks.
	var all: Array = []
	for rect: Rect2 in L.rects:
		if heart.x < 0.0:
			heart = rect.get_center()
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q: Vector2 in [rect.position, rect.position + Vector2(rect.size.x, 0.0), rect.end, rect.position + Vector2(0.0, rect.size.y)]:
			lo = lo.min(Vector2(q.dot(d), q.dot(nrm)))
			hi = hi.max(Vector2(q.dot(d), q.dot(nrm)))
		for m in range(ceili(lo.x / STREET_PITCH), floori(hi.x / STREET_PITCH) + 1):
			for n in range(floori(lo.y / STREET_PITCH), ceili(hi.y / STREET_PITCH) + 1):
				for axis in 2:
					# A street along `nrm` lies on u = m * pitch; along `d`, on v.
					var along := nrm if axis == 0 else d
					var across := d if axis == 0 else nrm
					var crossing := d * float(m) * STREET_PITCH + nrm * float(n) * STREET_PITCH if axis == 0 else d * float(n) * STREET_PITCH + nrm * float(m) * STREET_PITCH
					for off: float in [LOCK_OFF, -LOCK_OFF]:
						var p := crossing + along * off
						all.append([p.distance_to(heart), Vector3(p.x, p.y, axis), along, across, all.size()])
	all.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[4] < b[4]))
	var out: Array[Vector3] = []
	for e: Array in all:
		var v: Vector3 = e[1]
		if _canal_reach(L, Vector2(v.x, v.y), e[2], e[3]):
			out.append(v)
			if out.size() >= count:
				break
	return out


## A canal at `p` running `along`: water under every leaf, and dry ground of
## the region being laid on both banks, clear of villages and the spawn.
static func _canal_reach(L: Object, p: Vector2, along: Vector2, across: Vector2) -> bool:
	var c: GenContext = L.c
	var w := c.w
	for k: float in LOCK_GATES:
		var q := p + along * k
		if w.ground_at(floori(q.x), floori(q.y)) != Ground.BLACKWATER:
			return false
	for side: float in [-1.0, 1.0]:
		var b := p + across * side * (STREET_WIDTH * 0.5 + 1.5)
		var x := floori(b.x)
		var y := floori(b.y)
		if not w.in_bounds(x, y) or not L.here(x, y) or Ground.is_water(w.ground_at(x, y)) or c.road[y * c.size + x] != 0:
			return false
	if p.distance_to(w.spawn) < Sentinels.CLEAR_OF_HOME + 2.0 or GenScatter._near_village(w, p, 18.0):
		return false
	return true


## One lock at `at` (`GenWorks._work`): a[0] the street's axis, as `_lock_sites`.
static func _lock(L: Object, at: Vector2, a: Array) -> bool:
	var along: Vector2 = L.nrm if int(a[0]) == 0 else L.d
	var across := Vector2(-along.y, along.x)
	var leaves := 0
	for k: float in LOCK_GATES:
		if GenWorks._put_awash(L, PropKind.LOCK_GATE, at + along * k, along.angle(), 0.0, Ground.BLACKWATER) != null:
			leaves += 1
	if leaves < LOCK_LEAVES:
		return false
	# The pump house on whichever bank has room, its door to the canal.
	var pump: WorldProp = null
	for side: float in [1.0, -1.0]:
		if pump == null:
			pump = GenWorks._put_footed(L, PropKind.PUMP_HOUSE, at + across * side * (STREET_WIDTH * 0.5 + 2.6), (-across * side).angle(), 0.6)
	if pump == null or not GenWorks.station_holds(L, at):
		return false
	# A gauge on each bank by the lower gate, reading the sea off the canal.
	for side: float in [1.0, -1.0]:
		GenWorks._put(L, PropKind.TIDE_GAUGE, at + along * 3.4 + across * side * (STREET_WIDTH * 0.5 + 0.8), (-across * side).angle(), -99, 0.2)
	GenWorks._record(L.c, &"lock", at, along, Vector2(7.0, 2.5), GenWorks.CUT)
	return true


## How far from where the raft comes ashore the port's quay may be (its stair
## steps out under a tile further), and how far off the region's other marks.
const LANDING_REACH := 10
const LANDING_ROOM := 6.0


## The quay tiles round where the raft comes ashore (GenBodies.ashore) that are
## the region being laid's, nearest first;
## none when the landfall is another region's or no quay is in reach of it.
static func _landing(L: Object) -> Array[Vector2i]:
	var from := GenBodies.ashore(L.w)
	return GenWorks._shores_near(L, QUAY_GROUNDS, from, LANDING_REACH, LANDING_ROOM) if from.is_finite() else []


## A STAIR down off a quay into the sea (`GenWorks._work`): where a raft is
## landed and a body steps off it, and a sea wall keeps off it (its mark, and
## `GenWorks._shore`'s room round the marks). Its +X is the water.
static func _slip(L: Object, at: Vector2, _a: Array) -> bool:
	return _stair(L, at, &"slip")


## THE PORT's stair (`GenWorks._work`), a slip recorded as `port`: the one row
## that says where the raft from home is landed.
static func _port(L: Object, at: Vector2, _a: Array) -> bool:
	return _stair(L, at, &"port")


## A stair off the quay at `at` down into the sea (the sea's own level, never a
## canal: `GenWorks._sea_dir`), recorded as `kind`.
static func _stair(L: Object, at: Vector2, kind: StringName) -> bool:
	var c: GenContext = L.c
	var sea := GenWorks._sea_dir(c, Vector2i(at.floor()))
	if sea.length() < 0.5:
		return false
	var step := at + sea * 0.6
	if GenWorks._put(L, PropKind.STAIR_TO_WATER, step, sea.angle(), -99, 0.0) == null:
		return false
	GenWorks._record(c, kind, step, sea, Vector2(1.0, 0.6))
	return true


## A FLOODED HALL's walls (`GenWorks._work`): fronts of the city's drowned blocks
## (`DROWNED_SHELL`'s front-only profile) standing round the black water of its
## floor, their faces in to it, two to a side and the corners gone: a hall whose
## roof came down and whose floor the sea took. Standing in the water where the
## floor is water, on its edge where it is not.
const HALL_WALL := 4.2


static func _hall(L: Object, at: Vector2, _a: Array) -> bool:
	var d: Vector2 = L.d
	var nrm: Vector2 = L.nrm
	var stood := 0
	for out: Vector2 in [d, -d, nrm, -nrm]:
		var side := Vector2(-out.y, out.x)
		for k: float in [-1.6, 1.6]:
			# The front stands BLOCK_DEEP / 2 - 0.17 in front of its prop's origin.
			var p := at + out * (HALL_WALL + BLOCK_DEEP * 0.5 - 0.17) + side * k
			var wall: WorldProp = GenWorks._put_awash(L, PropKind.DROWNED_SHELL, p, (-out).angle(), 0.0, Ground.BLACKWATER)
			if wall == null:
				wall = GenWorks._put(L, PropKind.DROWNED_SHELL, p, (-out).angle(), -99, 0.0, true)
			if wall != null:
				wall.variant = HALL_FRONT
				stood += 1
	return stood >= 4


## DROWNED_SHELL's front-only profile (models/props/drowned_city.gd SHELLS).
const HALL_FRONT := 3


## A run of sea wall along a quay (`GenWorks._work`): the coast's own, the city's
## quays being a coast the plan walled.
static func _sea_wall(L: Object, at: Vector2, a: Array) -> bool:
	return GenWorks._sea_wall(L, at, a)
