## Grey Orchards: automated farms that never stopped and never had anybody to
## stop for. Rows of grafted trees going over, sprayers running their circuits,
## and a spore mist the machines keep making because the schedule says to.
## VISION §3 row 12.
##
## WHAT IT ARGUES WITH: it is the only landscape where the machines are FEEDING
## somebody, and there is nobody left to feed. Everything else of theirs is
## extraction — quarried, surveyed, hauled away — and this is the plan still
## going through the motions of care, which is a worse thing to walk through than
## a quarry.
##
## And it is the only one whose danger is in the AIR rather than under your feet
## or coming at you: the mist is the sprayers doing their job on a schedule, so
## the pressure rises and falls with the hour rather than with the weather, and
## the place is safe at the wrong times.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"grey_orchards"
	d.display_name = "the grey orchards"
	d.spoken_in = "in the grey orchards"
	d.order = 16
	d.style_note = "Ruled rows of grey-green trees, white bloom that is not bloom, everything one step past ripe."
	d.share = Vector2(0.075, 0.12)
	d.anchors = [{"seq": 10, "u": 0.36, "v": 0.52}]
	d.temp_range = Vector2(0.4, 0.75)
	d.moist_range = Vector2(0.45, 0.85)
	d.adjacency = {&"moss": 0.3, &"pinewood": 0.25, &"coast": 0.2}
	d.coastal = -0.2
	# Graded into long shallow terraces for the machinery to run along, which is
	# why it reads as ruled from the air even where nothing is standing.
	d.relief = {
		&"base": 6.5, &"hills": 1.8, &"ridge": 2.0, &"near": 1.2, &"terrace": 0.9, &"valley": 1.6,
		&"rain": 1.0, &"temp": 0.12, &"moist": 0.6, &"cliff": 0.3,
	}
	d.border_elevation = 0.5
	d.reach_out_high = Vector4(5.0, 0.08, 0.1, 0.32)
	d.reach_in_low = Vector3(5.0, 0.08, 0.3)
	d.hatch = Ink.SPARSE
	d.grounds = {
		Ground.GRASS: P.MOSS[3].lerp(P.LINEN[3], 0.4),
		Ground.HEATH: P.MOSS[2].lerp(P.ASH[2], 0.35),
		Ground.MUD: P.EARTH[3].lerp(P.ASH[3], 0.3),
		Ground.ROAD: P.ASH[3].lerp(P.EARTH[3], 0.4),
		Ground.GRAVEL: P.STONE[3].lerp(P.LINEN[3], 0.35),
		Ground.MOSS: P.MOSS[2].lerp(P.SPRUCE[2], 0.4),
		Ground.ROCK: P.STONE[3],
	}
	# Grounds this place never lays, named anyway: anything left unnamed falls
	# through to the shared table, which is the COAST's and is far brighter than
	# here, so it would arrive as the loudest object in the frame. Each takes this
	# landscape's own gravel, because they only have to be in key.
	for g: int in [Ground.BONE, Ground.ICE, Ground.LIMESTONE, Ground.PAN, Ground.SALT, Ground.SAND, Ground.SHINGLE, Ground.SNOW]:
		d.grounds[g] = d.grounds[Ground.GRAVEL]
	d.cliff_wash = P.STONE[2].lerp(P.MOSS[2], 0.3)
	d.strata = GroundColors.STRATA_MOSS
	d.plain_ground = Ground.GRASS
	d.bank_ground = Ground.MUD
	d.pool_rim_ground = Ground.MUD
	d.village_ground = Ground.GRAVEL
	d.decor = {Ground.GRASS: [0.7, Decor.TUFT, 26, Decor.CROTTLE, 10]}
	d.grass_colors = [P.MOSS[3].lerp(P.LINEN[3], 0.35), P.MOSS[2]]
	d.rock_color = P.STONE[3]
	# What grows is grafted and going over: grey-green rather than green, and the
	# white on it is not blossom.
	d.tree_tints = {&"leaf": [P.MOSS[2].lerp(P.LINEN[3], 0.45), P.MOSS[3], P.LINEN[3], P.LINEN[2]]}
	d.decor_tints = {&"fronds": [P.MOSS[2], P.LINEN[2], P.ASH[2]]}
	var dress := BiomeDressing.new()
	dress.stone = [P.STONE[3], P.ASH[3], P.LINEN[3]]
	dress.timber = [P.EARTH[2], P.ASH[2]]
	dress.walling = [P.STONE[3], P.ASH[2], P.EARTH[2], P.LINEN[3]]
	dress.crown = &"full"
	dress.sink = 0.08
	dress.lie = Vector2(-0.03, 0.06)
	d.dressing = dress
	d.grade = Vector4(-0.03, 0.03, 0.0, 0.02)
	d.night_sky = 1.0
	d.props = [PropKind.BROADLEAF, PropKind.BUSH, PropKind.GROWTH_TANK,
		PropKind.WATER_TANK, PropKind.FENCE, PropKind.STUMP, PropKind.DEBRIS, PropKind.RELAY]
	d.ore = [[PropKind.IRON_ORE, 0.014], [PropKind.COPPER_ORE, 0.012]]
	d.sites = {"tips": 2}
	d.beached_wrecks = false
	d.pools = {"order": 3, "cell": 30, "chance": 0.45, "r_min": 2.0, "r_max": 4.2, "ground": Ground.WATER}
	d.villages = 1
	d.village_order = 16
	d.village_names = ["Graft Row", "Nine Acre"]
	d.weather = [
		[Weather.GREY, 30, 0.0], [Weather.CLEAR, 22, 0.0], [Weather.RAIN, 22, 0.5],
		[Weather.FOG, 20, 0.0], [Weather.STORM, 6, 0.4],
	]
	d.mist = 0.34
	# The spores are the sprayers' own doing and the wet is what they are carried
	# in: declared under BITE so the mist decides, exactly as the Burning's fumes
	# are declared under it so the ash decides.
	d.hazards = {&"toxins": 0.5, &"wet": 0.35}
	d.roster = {
		&"harvester": {"weight": 1.0, "grounds": ["grass", "heath", "mud"]},
		&"sweeper": {"weight": 0.9, "grounds": ["road", "gravel", "grass", "mud"]},
		&"warden": {"weight": 0.7},
		&"dog.feral": {"weight": 0.8},
	}
	d.landmarks = [&"clerks_office", &"poured_pillar", &"sump_pump", &"blinking_stack"]
	d.sound_bed = &"bed_pines"
	d.surface = _surface
	d.scatter = _scatter
	return d


## Worked ground everywhere, mud in the irrigation cuts, and moss where a row was
## abandoned early enough for something else to take it.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.GRAVEL
	if f & BiomeSurface.APRON != 0:
		return Ground.GRAVEL
	if f & BiomeSurface.BANK != 0:
		return Ground.MUD
	if e <= 4.0:
		return Ground.MUD
	return Ground.MOSS if gb > 0.35 else Ground.GRASS


## THE ROWS ARE THE POINT: planted on a grid the machines still keep, so the
## trees come in lines rather than in drifts, and that is what says at a glance
## this was a FARM and not a wood. Everything else here is the plant that tends
## them -- the tanks and the standpipes on the service GRAVEL, the fences and the
## relays along the ROAD -- and the stumps are where a row was taken out and
## never replanted, which is the only thing in the landscape that is failing.
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.GRASS:
		if r < 0.085:
			return PropKind.BROADLEAF
		if r < 0.100:
			return PropKind.BUSH
		return PropKind.STUMP if r > 0.50 and r < 0.508 else BiomeScatter.NONE
	if g == Ground.GRAVEL:
		if r < 0.032:
			return PropKind.GROWTH_TANK
		return PropKind.WATER_TANK if r < 0.046 else BiomeScatter.NONE
	if g == Ground.ROAD:
		if r < 0.028:
			return PropKind.FENCE
		return PropKind.RELAY if r > 0.60 and r < 0.6055 else BiomeScatter.NONE
	if g == Ground.MUD:
		if r < 0.026:
			return PropKind.STUMP
		return PropKind.DEBRIS if r < 0.036 else BiomeScatter.NONE
	if g == Ground.HEATH or g == Ground.MOSS:
		if r < 0.030:
			return PropKind.BUSH
		return PropKind.STUMP if r < 0.040 else BiomeScatter.NONE
	if g == Ground.ROCK:
		return PropKind.DEBRIS if r < 0.020 else BiomeScatter.NONE
	return BiomeScatter.NONE
