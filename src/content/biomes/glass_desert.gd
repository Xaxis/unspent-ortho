## Glass Desert: sand fused to a sheet by something that came down here, cratered
## and cracked into plates that ring underfoot. VISION §3 row 8.
##
## WHAT IT ARGUES WITH: it is the one landscape whose GROUND is a made thing. Every
## other floor in this game is what the land does — turf, ash, crust, snow. This
## one is a surface that was manufactured in a second and has been breaking ever
## since, so it is drawn as plates with dark cracks between them rather than as a
## wash with things on it, and what it gives a player is what it is made of.
##
## The glass is the reason it is worth crossing and the reason it is dangerous: it
## cuts, it throws the sun back at you, and there is nothing to drink on it.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"glass_desert"
	d.display_name = "the glass"
	d.order = 12
	d.style_note = "Plates of green-black glass, hard white glare, cracks like a dry riverbed."
	d.share = Vector2(0.05, 0.09)
	d.anchors = [{"seq": 12, "u": 0.55, "v": 0.78}]
	d.temp_range = Vector2(0.6, 1.0)
	d.moist_range = Vector2(0.0, 0.2)
	d.adjacency = {&"salt_flats": 0.4, &"burning": 0.2}
	d.coastal = -0.6
	# Flat, because it was flattened. The only relief is the crater rim and what
	# the wind has banked against it.
	d.relief = {
		&"base": 4.5, &"hills": 1.1, &"ridge": 1.4, &"near": 4.0, &"terrace": 0.25, &"valley": 0.5,
		&"rain": 0.2, &"temp": 0.25, &"moist": 0.05, &"cliff": 0.2,
	}
	d.border_elevation = 0.6
	d.reach_out_high = Vector4(4.0, 0.06, 0.08, 0.3)
	d.reach_in_low = Vector3(4.0, 0.06, 0.25)
	d.hatch = Ink.NONE
	d.grounds = {
		Ground.ROAD: P.SLATE[3].lerp(P.SAND[3], 0.3),
		Ground.SAND: P.SAND[4].lerp(P.LINEN[4], 0.3),
		Ground.ROCK: P.SLATE[2].lerp(P.SPRUCE[2], 0.35),
		Ground.SCREE: P.SLATE[3].lerp(P.SAND[3], 0.4),
		Ground.GRAVEL: P.SAND[3].lerp(P.SLATE[3], 0.3),
		Ground.SALT: P.LINEN[5],
	}
	d.cliff_wash = P.SLATE[2].lerp(P.SPRUCE[2], 0.3)
	d.strata = GroundColors.STRATA_SALT
	d.plain_ground = Ground.ROCK
	d.bank_ground = Ground.SAND
	d.pool_rim_ground = Ground.SALT
	d.village_ground = Ground.GRAVEL
	d.decor = {Ground.SAND: [0.35, Decor.SEA_GLASS, 26, Decor.TUFT, 4]}
	d.grass_colors = [P.SAND[3], P.LINEN[3]]
	d.rock_color = P.SLATE[2]
	d.decor_tints = {&"fronds": [P.SAND[2], P.LINEN[2], P.SPRUCE[2]]}
	# Everything here is either fused or sand-blasted: no rot, no rust worth the
	# name, and a shine on anything that has not been scoured.
	var dress := BiomeDressing.new()
	dress.stone = [P.SLATE[2].lerp(P.SPRUCE[2], 0.3), P.SLATE[3], P.LINEN[4]]
	dress.walling = [P.SLATE[2], P.SAND[3], P.LINEN[3], P.SPRUCE[2]]
	dress.bleach = P.LINEN[5]
	dress.sink = 0.02
	dress.lie = Vector2(0.0, 0.03)
	d.dressing = dress
	d.grade = Vector4(-0.02, 0.0, 0.05, 0.05)
	# Nothing grows to shade it and the glass throws the moon back: bright, and
	# with no cover anywhere on it.
	d.night_sky = 1.3
	d.props = [PropKind.BOULDER, PropKind.STONE_ORE, PropKind.DEBRIS, PropKind.WRECKAGE,
		PropKind.SURVEY, PropKind.STANDING_STONE]
	d.ore = [[PropKind.STONE_ORE, 0.022]]
	d.sites = {"tips": 1, "stone_circles": 1}
	d.beached_wrecks = false
	d.pools = {"order": 4, "cell": 52, "chance": 0.16, "r_min": 1.4, "r_max": 2.6, "ground": Ground.SALT}
	d.villages = 0
	d.village_order = 12
	d.village_names = []
	# Clear was 52 of 100 -- over half of all weather was no weather, on the
	# landscape that is meant to be crossed with gear or not crossed. The heat and
	# the dust carry it instead.
	d.weather = [
		[Weather.CLEAR, 30, 0.0], [Weather.HEAT, 28, 0.0], [Weather.DUST, 26, 0.6],
		[Weather.GREY, 8, 0.0], [Weather.DRY_STORM, 8, 0.5],
	]
	d.mist = 0.02
	# Three at once and no shade to answer any of them: this is the landscape that
	# is crossed with gear or not crossed.
	d.hazards = {&"heat": 0.6, &"glare": 0.7, &"thirst": 0.6}
	d.roster = {
		&"watcher": {"weight": 1.0},
		&"harvester": {"weight": 0.7, "grounds": ["sand", "salt", "gravel"]},
		&"runner": {"weight": 0.6, "hours": Vector2(9, 18), "grounds": ["road", "sand", "rock"]},
	}
	d.landmarks = [&"cast_stones", &"evaporator", &"blinking_stack", &"poured_pillar"]
	# Its keeper: the anvil, the mast the strike fields are called through
	# (src/core/sentinel/designs/anvil.gd, docs/LANDSCAPES.md §3).
	d.sentinel = &"anvil"
	d.sound_bed = &"bed_wind"
	d.surface = _surface
	d.scatter = _scatter
	# The web's day contrast here (BiomeDef.web_contrast): inferred from the bonelands: a bright floor.
	d.web_contrast = 1.1
	return d


## Glass where it was fused, sand where the wind has buried it, salt in the
## hollows where the little water there is goes to die. Two borders, wide bands.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.SAND
	if f & BiomeSurface.APRON != 0:
		return Ground.SCREE
	if f & BiomeSurface.BANK != 0:
		return Ground.SALT
	if e <= 3.0:
		return Ground.SALT
	return Ground.SAND if gb > 0.5 else Ground.ROCK


## WHAT SURVIVES A PLACE THAT WAS FUSED. Nothing grows, so everything standing
## is either older than the glassing (the stones, which is why they are the only
## thing here anybody put up on purpose) or was caught in it. The wreckage lies
## where the sand took it and the boulders stand where the rock still shows.
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.SAND:
		if r < 0.016:
			return PropKind.DEBRIS
		if r < 0.024:
			return PropKind.WRECKAGE
		return PropKind.STANDING_STONE if r > 0.70 and r < 0.705 else BiomeScatter.NONE
	if g == Ground.ROCK or g == Ground.SCREE:
		if r < 0.038:
			return PropKind.BOULDER
		if r < 0.050:
			return PropKind.STONE_ORE
		return BiomeScatter.NONE
	if g == Ground.GRAVEL:
		if r < 0.020:
			return PropKind.BOULDER
		return PropKind.SURVEY if r > 0.40 and r < 0.406 else BiomeScatter.NONE
	if g == Ground.SALT:
		return PropKind.DEBRIS if r < 0.010 else BiomeScatter.NONE
	return BiomeScatter.NONE
