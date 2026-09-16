## Coast: turf, heath, shingle and sea cliffs, where the player wakes.
## Its washes are the game's baseline, so it overrides almost nothing: what
## GroundColors calls a ground with nobody arguing is what the coast calls it.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"coast"
	d.display_name = "the coast"
	d.order = 0
	d.style_note = "Calm long contours, fast cloud shadows, everything leaning off the sea."
	d.share = Vector2(0.32, 0.38)
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
		&"base": 2.6, &"hills": 3.4, &"ridge": 1.0, &"terrace": 0.0, &"valley": 0.42,
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
	# Thrift in bloom on the cliff turf.
	d.decor_tints = {&"bloom": [P.BLOOM[2], P.BLOOM[3], P.BLOOM[4]]}
	d.grade = Vector4(-0.55, 0.16, 0.05, 0.02)
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
	d.sound_bed = &"bed_wind"
	d.surface = _surface
	d.scatter = _scatter
	return d


static func _surface(t: BiomeSurface) -> int:
	var i := t.i
	var cx := t.convex[i]
	var gb := t.big[i]
	if t.shore:
		if cx > 0.64:
			return Ground.MUD
		if cx < 0.47 or gb > 0.45:
			return Ground.SHINGLE
		return Ground.SAND
	if t.apron:
		return Ground.SHINGLE if t.level <= 2 else Ground.SCREE
	if t.marsh[i] <= 3 + int(maxf(0.0, gb + 0.3) * 6.0) and t.level <= 2:
		return Ground.MUD
	if t.level <= 3 and cx > 0.5 and t.sea_steps[i] <= mini(7, 3 + int(maxf(0.0, gb) * 10.0)):
		# Dunes back the sandy bays.
		return Ground.SAND
	var e := t.elev[i]
	var rs := t.rise[i]
	if e + gb * 3.0 + rs * 0.8 >= 4.4:
		return Ground.HEATH
	if rs < -0.55 and gb < -0.2 and e < 3.5:
		return Ground.MUD
	return Ground.GRASS


static func _scatter(t: BiomeScatter) -> int:
	if t.ground == Ground.GRASS:
		# Copses in the sheltered folds, not on the tops.
		var f := maxf(0.0, t.forest[t.i]) * clampf(1.0 - t.rise[t.i] * 0.6, 0.0, 1.3)
		if t.roll < f * f * 1.1:
			return PropKind.BROADLEAF
		if t.roll < 0.02:
			return PropKind.BUSH
		return PropKind.BOULDER if t.roll < 0.026 else BiomeScatter.NONE
	if t.ground == Ground.HEATH:
		var c := maxf(0.0, t.clump[t.i])
		if t.roll < 0.02 + c * 0.26:
			return PropKind.GORSE
		return PropKind.BOULDER if t.roll > 0.37 and t.roll < 0.385 else BiomeScatter.NONE
	return BiomeScatter.PASS
