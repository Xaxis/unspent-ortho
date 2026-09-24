## Coast: turf, heath, shingle and sea cliffs, where the player wakes.
## Its washes are the game's baseline, so it overrides almost nothing: what
## GroundColors calls a ground with nobody arguing is what the coast calls it.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"coast"
	d.display_name = "coast"
	d.order = 0
	d.style_note = "Calm long contours, fast cloud shadows, everything leaning off the sea."
	# NOT THE ONE THAT PAYS for the others' room, though it looks like it should
	# (L1, 2026-09-23: it held 185,000 tiles at 1840 while eight landscapes could not
	# make a 40-frame place). Cut to 0.14-0.20, and even to 0.24-0.30, the coast
	# stops holding the villages the spine needs on small worlds: `home` could not
	# be cast on seed 7 at 256, and a hold, a lit house and the cast went with it.
	# The coast is where he wakes, so the room came out of the four big inland
	# landscapes instead.
	d.share = Vector2(0.32, 0.38)
	# ON HOME, ALWAYS (docs/DESIGN.md: home "holds the coast, the spawn village
	# and a full starting economy"). The player wakes on a coast village, so a home
	# continent without a coast wakes him on another body -- measured on seeds 1
	# and 42 at 1300, where home grew no coast at all. `(1, 0)` is DEPENDENCY: the
	# dealer puts it on home first (`GenBodies.deal`). `StoryWorld.guaranteed`
	# once guaranteed it by the spawn instead; its header says why that ended.
	d.spread = Vector2i(1, 0)
	# The journey starts here: the south shore, with two arms round the bays.
	d.anchors = [
		{"seq": 0, "u": 0.5, "v": 0.87},
		{"seq": 1, "u": 0.17, "v": 0.82},
		{"seq": 2, "u": 0.83, "v": 0.82},
	]
	d.temp_range = Vector2(0.35, 0.8)
	d.moist_range = Vector2(0.35, 0.8)
	d.coastal = 1.0
	d.dunes = true
	d.relief = {
		&"base": 2.6, &"hills": 3.4, &"ridge": 1.0, &"near": 2.0, &"terrace": 0.0, &"valley": 0.42,
		&"rain": 1.0, &"temp": 0.58, &"moist": 0.55, &"cliff": 0.0,
	}
	d.hatch = Ink.WIND
	d.cliff_wash = P.EARTH[3].lerp(P.SAND[3], 0.4)
	d.strata = GroundColors.STRATA_COAST
	d.plain_ground = Ground.GRASS
	d.bank_ground = Ground.SAND
	d.village_ground = Ground.GRASS
	d.grass_colors = [P.MOSS[3], P.MOSS[4].lerp(P.SLATE[3], 0.2)]
	d.rock_color = P.SLATE[2]
	# Cliff meadow: knee-high sward the sea wind combs flat in the gusts, with
	# shorter turf between and thrift and thistle through it. Thick enough that a
	# body walking through it parts it (grass.gdshader).
	d.decor = {Ground.GRASS: [Vector2(1.9, 0.9), Decor.MEADOW, 62, Decor.TUFT_TALL, 8, Decor.TUFT, 8, Decor.FLOWER, 10,
		Decor.STONE, 2, Decor.THISTLE, 3, Decor.MOLEHILL, 1]}
	# Thrift in bloom on the cliff turf.
	d.decor_tints = {&"bloom": [P.BLOOM[2], P.BLOOM[3], P.BLOOM[4]]}
	# What a thing built or left here is made of. Slate under turf, sand banked
	# against everything, and a wind off the sea that crops what grows in it.
	var dress := BiomeDressing.new()
	dress.stone = [P.SLATE[3], P.SLATE[2], P.LINEN[3]]
	dress.drift = [P.SAND[4], P.SAND[3]]
	dress.turf = [P.MOSS[2], P.MOSS[3], P.MOSS[2].lerp(P.EARTH[2], 0.35), P.MOSS[3]]
	dress.walling = [P.STONE[2], P.SLATE[2], P.STONE[3], P.SLATE[3]]
	# A tide line of weed hung on whatever stands in it, and rust where the salt
	# gets in: the coast takes a thing apart differently from a dry place.
	dress.covers = &"wrack"
	dress.wind = 0.09
	dress.sink = 0.16
	dress.lie = Vector2(-0.1, 0.12)
	dress.berry = P.BLOOM[2]
	dress.spread = 1.1
	d.dressing = dress
	# Marram and sea club-rush in the brackish water behind the dunes.
	d.tree_tints = {
		&"reed": [P.SAND[4], P.MOSS[4].lerp(P.SAND[4], 0.5), P.SAND[3]],
		&"reed_head": [P.SAND[2]],
	}
	d.grade = Vector4(-0.55, 0.16, 0.05, 0.02)
	# 1.0 is the coast, and the coast is where the night was measured. Every other
	# landscape's night is stated against this one, so this line is a fixed point
	# and not a setting: moving it moves all nine.
	d.night_sky = 1.0
	d.wet = 0.15
	d.props = [PropKind.PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE, PropKind.BUSH, PropKind.REEDS,
		PropKind.BOULDER, PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.TIN_ORE, PropKind.GORSE,
		PropKind.DRIFTWOOD, PropKind.WRACK, PropKind.MUSSEL_ROCK]
	d.ore = [[PropKind.STONE_ORE, 0.035], [PropKind.TIN_ORE, 0.05], [PropKind.IRON_ORE, 0.055]]
	d.reed_chance = 0.14
	d.shore_bush = PropKind.GORSE
	d.sites = {"tips": 4, "ruins": true, "summit": 4, "kiln_ground": Ground.SAND}
	# The odd tarn behind the dunes: fresh water, not a piece of the sea.
	d.pools = {"order": 4, "cell": 44, "chance": 0.3, "r_min": 2.2, "r_max": 3.6, "ground": Ground.RIVER}
	d.villages = 3
	d.village_order = 8
	d.spawn_home = true
	d.village_names = ["Sandling", "Low Scar", "Pennock", "Tidesend", "Marrow Bay", "Oyster Row"]
	# Bleak grey days and rain in squalls off the sea; sea fret at dawn.
	d.weather = [
		[Weather.CLEAR, 24, 0.0], [Weather.GREY, 30, 0.0], [Weather.RAIN, 20, 0.75],
		[Weather.FOG, 8, 0.0], [Weather.HAIL, 6, 0.6], [Weather.STORM, 12, 0.45],
	]
	d.mist = 0.22
	d.hazards = {&"wet": 0.3}
	d.roster = {
		&"harvester": {"weight": 1.0},
		&"flock": {"weight": 1.0, "hours": Vector2(6, 19)},
		&"hauler": {"weight": 1.0},
		&"dredger": {"weight": 1.0},
		&"dog.yard": {"weight": 1.0}, &"dog.feral": {"weight": 1.0},
		&"bull.field": {"weight": 1.0},
		&"gulls": {"weight": 1.0, "hours": Vector2(6, 20)},
	}
	# Its keeper: the reaper on the gantry at the machines' intake
	# (src/core/sentinel/designs/tide_reaper.gd, docs/VISION.md).
	d.sentinel = &"tide_reaper"
	# The places worth the walk it holds (docs/VISION.md, src/core/landmarks):
	# what a player crosses this landscape FOR. Its own file is the authority;
	# `Landmarks.problems` fails if a kind here does not name this landscape back.
	d.landmarks = [&"lighthouse", &"firewatch", &"cast_stones", &"grown_hulk"]
	d.sound_bed = &"bed_wind"
	d.surface = _surface
	d.scatter = _scatter
	return d


static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	var cx := t.convex[i]
	var lvl := t.levels[i]
	if f & BiomeSurface.SHORE != 0:
		if cx > 0.64:
			return Ground.MUD
		if cx < 0.47 or gb > 0.45:
			return Ground.SHINGLE
		return Ground.SAND
	if f & BiomeSurface.APRON != 0:
		return Ground.SHINGLE if lvl <= 2 else Ground.SCREE
	if t.marsh[i] <= 3 + int(maxf(0.0, gb + 0.3) * 6.0) and lvl <= 2:
		return Ground.MUD
	if lvl <= 3 and cx > 0.5 and t.sea_steps[i] <= mini(7, 3 + int(maxf(0.0, gb) * 10.0)):
		# Dunes back the sandy bays.
		return Ground.SAND
	if e + gb * 3.0 + rs * 0.8 >= 4.4:
		return Ground.HEATH
	if rs < -0.55 and gb < -0.2 and e < 3.5:
		return Ground.MUD
	return Ground.GRASS


static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.GRASS:
		# Copses in the sheltered folds, not on the tops.
		var f := maxf(0.0, t.forest[i]) * clampf(1.0 - t.rise[i] * 0.6, 0.0, 1.3)
		if r < f * f * 1.1:
			return PropKind.BROADLEAF
		if r < 0.02:
			return PropKind.BUSH
		return PropKind.BOULDER if r < 0.026 else BiomeScatter.NONE
	if g == Ground.HEATH:
		var c := maxf(0.0, t.clump[i])
		if r < 0.02 + c * 0.26:
			return PropKind.GORSE
		return PropKind.BOULDER if r > 0.37 and r < 0.385 else BiomeScatter.NONE
	return BiomeScatter.PASS
