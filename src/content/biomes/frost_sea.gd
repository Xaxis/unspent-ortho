## Frost Sea: the sea itself, frozen and walked on. Pressure ridges thrown up
## where two floes met, leads of black water that open and close, and the
## machines' sounding rigs standing out on it listening to something underneath.
## VISION §3 row 14.
##
## WHAT IT ARGUES WITH, and it is the strongest argument any of the new seven
## makes: this is a landscape you WALK ON WATER to cross. Every other place in
## this game treats deep water as the wall it always was (`Swim`); here the wall
## has a lid on it, and the lid is the ground. That makes the ice the content —
## where it is thick, where it is ridged, where it is a lead that will take you.
##
## It is also the one place where a coast is not an edge. The sea does not stop
## the walk, so a continent's shore is a door rather than a boundary, which is
## worth having now that there are five of them and straits between.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"frost_sea"
	d.display_name = "the frost sea"
	d.order = 13
	d.style_note = "White going blue in the hollows, black leads, ridges thrown up like slate."
	d.share = Vector2(0.06, 0.1)
	d.anchors = [{"seq": 14, "u": 0.18, "v": 0.08}]
	d.temp_range = Vector2(0.0, 0.14)
	d.moist_range = Vector2(0.45, 1.0)
	d.adjacency = {&"snowfield": 0.25, &"coast": 0.35}
	# ONE CONTINENT'S OWN, and this is what stopped it being a climate twin.
	#
	# Measured first, wrongly: every snow field taken out of this file left the
	# leak identical to eleven decimal places, because the snow was never this
	# landscape's — it was the SNOWFIELD's, blowing over a border the two shared
	# because they declare the same coldest band and so always landed together.
	# Chasing it through adjacency and ground rules could not work; the two were
	# twins before either of them had a border.
	#
	# `spread` decides which BODY carries a landscape before climate decides where
	# on that body it sits, so one continent makes this a frozen sea you reach by
	# crossing water rather than a shelf beside a snowfield — which is the thing
	# it was always meant to be, and is why it could not sit on one island at all.
	d.spread = Vector2i(1, 1)
	# It IS the sea: it wants the edge of the land, not the middle of it.
	d.coastal = 1.0
	# Flat as water, because it is water. What relief there is was pushed up by
	# one floe meeting another, so the ridges are thin and high and everything
	# between them is level.
	d.relief = {
		# MEASURED. At 1.6 the whole floe sat so near the waterline that a lead had
		# no room to be one: `test_pools_are_round_rimmed` found a blackwater pool
		# ONE tile across. Flat is the point, but flat has to be flat ABOVE
		# something or the pools are clipped away to nothing.
		&"base": 3.6, &"hills": 0.5, &"ridge": 3.2, &"near": 5.0, &"terrace": 0.15, &"valley": 0.3,
		&"rain": 1.3, &"temp": 0.02, &"moist": 0.8, &"cliff": 0.15,
	}
	d.border_elevation = -0.5
	d.reach_out_high = Vector4(3.0, 0.04, 0.06, 0.2)
	d.reach_in_low = Vector3(7.0, 0.12, 0.4)
	d.hatch = Ink.SPARSE
	d.grounds = {
		# ICE IS NOT SNOW, and this was `P.RIME[5]` -- byte for byte what the
		# snowfield gives its snow, so a landscape that chose a different ground
		# still drew the same turf and the two were 0.0000 apart. Frozen SEA is
		# harder and bluer than fallen snow: it is the water you are walking on.
		Ground.ICE: P.RIME[5].lerp(P.SLATE[4], 0.20),
		Ground.SNOW: P.RIME[4].lerp(P.LINEN[5], 0.4),
		Ground.ROCK: P.SLATE[3].lerp(P.RIME[3], 0.5),
		Ground.SHINGLE: P.SLATE[2].lerp(P.RIME[2], 0.4),
		Ground.GRAVEL: P.SLATE[3].lerp(P.RIME[4], 0.35),
		Ground.BLACKWATER: P.SLATE[1],
	}
	d.cliff_wash = P.SLATE[2].lerp(P.RIME[2], 0.45)
	d.strata = GroundColors.STRATA_ICE
	d.plain_ground = Ground.ICE
	d.bank_ground = Ground.ICE
	d.pool_rim_ground = Ground.ICE
	d.rivers_freeze = true
	d.village_ground = Ground.ICE
	d.decor = {Ground.ICE: [0.3, Decor.SNOW_TUFT, 12]}
	d.grass_colors = [P.RIME[3], P.LINEN[3]]
	d.rock_color = P.SLATE[3]
	d.decor_tints = {&"fronds": [P.RIME[2], P.SLATE[2], P.LINEN[2]]}
	var dress := BiomeDressing.new()
	dress.snow = [P.RIME[5], P.RIME[4], P.RIME[3], P.LINEN[4]]
	dress.stone = [P.SLATE[3].lerp(P.RIME[3], 0.4), P.SLATE[2], P.RIME[5]]
	dress.drift = [P.RIME[5], P.LINEN[5]]
	dress.walling = [P.SLATE[2], P.SLATE[3], P.RIME[2], P.LINEN[3]]
	dress.sink = 0.2
	dress.lie = Vector2(-0.08, 0.14)
	# A boarded fishing shack, banked in the sea's own drift: the ice-fisher's
	# hut (docs/LANDSCAPES.md). Said here because the cold would otherwise
	# dress this sea's people in the snowfield's emergency pod, and a fisher on
	# the ice is not a survivor under it; `Remains._fish_shack` banks `drift`
	# against the walls, and this landscape's drift is rime.
	dress.shelter = &"shack"
	d.dressing = dress
	d.grade = Vector4(-0.06, 0.04, 0.12, -0.04)
	# White under a clear sky throws back nearly everything: the brightest night
	# in the game, and the emptiest.
	d.night_sky = 1.4
	# NO LIP SNOW, and this was the last of it. Between the bank, the village
	# ground, the decor and a snowy terrace lip, this landscape was quietly laying
	# SNOW — which belongs to the snowfield — over 4.7% of itself. Every one of
	# those was me reaching for the white I wanted without asking who owned it.
	d.lip_snow = false
	d.props = [PropKind.BOULDER, PropKind.DRIFTWOOD, PropKind.WRACK, PropKind.STONE_ORE,
		PropKind.SURVEY, PropKind.RELAY, PropKind.DEBRIS,
		# Its own (docs/LANDSCAPES.md, src/models/props/frost_sea.gd): ice
		# thrown up on end, a trawler frozen in, the plan's sounding tripod, a
		# seal's hole. Declared here so the economy can walk lens ice back to
		# this sea; where each stands per frame is `_scatter`'s, and the bands
		# land with the works row and the ridge relief (phase B).
		PropKind.PRESSURE_BLOCK, PropKind.FROZEN_HULL, PropKind.SOUNDING_RIG, PropKind.SEAL_HOLE]
	d.ore = [[PropKind.STONE_ORE, 0.012]]
	d.sites = {"tips": 1}
	d.beached_wrecks = true
	d.pools = {"order": 2, "cell": 26, "chance": 0.55, "r_min": 2.2, "r_max": 5.0, "ground": Ground.BLACKWATER}
	# NOBODY LIVES ON MOVING ICE, and that is a decision, not a gap (docs/
	# LANDSCAPES.md §2). People are here as a dead expedition's camp and one
	# living ice-fisher at a seal hole (the floe camp site, phase B), never as a
	# village, so `villages` stays 0 and the built forms are declared EMPTY on
	# purpose: no stock, no plan. `BiomeForms.resolve` would hand the plain eight
	# to anyone who asked, and nobody asks, because nothing here raises a
	# settlement. What a person does put up on the ice is the shelter below.
	d.villages = 0
	d.built = BiomeForms.new()
	d.village_order = 13
	d.village_names = []
	d.weather = [
		[Weather.CLEAR, 22, 0.0], [Weather.GREY, 20, 0.0], [Weather.SNOW, 24, 0.6],
		[Weather.BLIZZARD, 18, 0.4], [Weather.WHITEOUT, 16, 0.0],
	]
	d.mist = 0.2
	# Cold that does not let up, and ice that does not hold everywhere. `collapse`
	# is the lead nobody saw: the one pressure here that is about the GROUND.
	#
	# The 0.4 is the sea's floor, and docs/LANDSCAPES.md asks for collapse to
	# be CAUSED on top of it: rising within two tiles of BLACKWATER and of an
	# icesaw's fresh cut. Half of that is here already -- a seal hole thins the
	# ice round it through `PropHazards.TABLE`, the per-prop half of shared
	# system 3, which landed on main this morning. The other half is a GROUND's
	# neighbourhood, and `Hazards.felt` reads the land, the hour, the weather,
	# shelter, fire and props, never the tiles round the body; a lead's edge and
	# a cut's edge want "within R of ground G adds H", declared once for
	# BLACKWATER, and a cut wants the time-varying ground edit of shared system 5
	# to exist before there is a cut to stand near. Both are left to those
	# systems: nothing here fakes them with a higher floor.
	d.hazards = {&"cold": 0.85, &"collapse": 0.4}
	d.roster = {
		&"longlegs": {"weight": 1.0},
		&"lineman": {"weight": 0.8, "grounds": ["ice", "snow", "rock", "gravel"]},
		&"watcher": {"weight": 0.7},
		# Its own: the saw sled that works the ice for the soundings line
		# (roster.gd `icesaw`). Only on the ice, because a sled has nowhere else
		# to go.
		&"icesaw": {"weight": 0.9, "grounds": ["ice"]},
	}
	d.landmarks = [&"leaning_mast", &"blinking_stack", &"sump_pump", &"cast_stones"]
	# Its keeper listens through the ice (src/core/sentinel/designs/listener.gd).
	d.sentinel = &"listener"
	d.sound_bed = &"bed_snowfield"
	d.surface = _surface
	d.scatter = _scatter
	# The web's day contrast here (BiomeDef.web_contrast): inferred from the snowfield: bright and cold.
	d.web_contrast = 1.05
	return d


## Ice almost everywhere; a ridge where two floes met is rock-hard and stands
## proud; and the low ground is where a lead has opened and the water shows.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.SHINGLE
	if f & BiomeSurface.APRON != 0:
		return Ground.GRAVEL
	if f & BiomeSurface.BANK != 0:
		return Ground.SNOW
	# A pressure ridge: the only steep thing out here, and the only thing to take
	# cover behind.
	if rs > 1.2:
		return Ground.ROCK
	# ICE, not snow, and `test_snow_and_ash_keep_to_their_countries` is what made
	# the point: SNOW belongs to the snowfield, and reaching for it here because
	# it is the white ground I wanted put 4.7% of it outside its own country. A
	# frozen sea is ice. What snow there is drifts against the ridges and the
	# bank, which is where the bank rule already puts it.
	return Ground.ICE


## THE SEA PUT ALL OF IT HERE. Driftwood and wrack are only ever on the shingle,
## because that is the line the water reaches; the boulders out on the ice are
## erratics the floe carried and dropped, which is why they stand alone rather
## than in fields. The plan's own things are the rarest thing in the landscape.
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.SHINGLE:
		if r < 0.042:
			return PropKind.DRIFTWOOD
		if r < 0.062:
			return PropKind.WRACK
		if r < 0.070:
			return PropKind.BOULDER
		return BiomeScatter.NONE
	if g == Ground.ICE:
		if r > 0.80 and r < 0.812:
			return PropKind.BOULDER
		return PropKind.DEBRIS if r > 0.20 and r < 0.206 else BiomeScatter.NONE
	if g == Ground.SNOW:
		if r > 0.60 and r < 0.609:
			return PropKind.BOULDER
		return PropKind.SURVEY if r > 0.10 and r < 0.1035 else BiomeScatter.NONE
	if g == Ground.ROCK:
		if r < 0.030:
			return PropKind.BOULDER
		if r < 0.040:
			return PropKind.STONE_ORE
		return PropKind.RELAY if r > 0.50 and r < 0.505 else BiomeScatter.NONE
	if g == Ground.GRAVEL:
		return PropKind.DRIFTWOOD if r < 0.012 else BiomeScatter.NONE
	return BiomeScatter.NONE
