## Sulphur Jungle: vents and geysers under a canopy that loves them. Wet heat,
## yellow crust round every hole, and everything growing twice as fast as it
## should because the ground is warm. Owner's own, 2026-09-18: "a region of
## volcanic sulphur vents and geysers humid and varied jungle throughout".
##
## WHAT IT ARGUES WITH: it is the only landscape where the danger FEEDS the place.
## The Burning is ash and nothing lives in it; here the same heat and the same
## fumes are why the canopy is the thickest in the game, so the ground that hurts
## you is the ground that grew everything worth taking. Nowhere else in this world
## is a hazard also a reason.
##
## AND IT IS THE FIRST WET HOT PLACE. Every landscape until now is cold-wet
## (moss, crags, frost) or hot-dry (salt, glass, mesas, burning); this one is both
## at once, which is a corner of the climate map nothing has stood in.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"sulphur_jungle"
	d.display_name = "the sulphur jungle"
	d.order = 21
	d.style_note = "Green over yellow crust, steam standing in the trees, nothing dry and nothing cool."
	d.share = Vector2(0.06, 0.1)
	d.anchors = [{"seq": 21, "u": 0.82, "v": 0.72}]
	d.temp_range = Vector2(0.7, 1.0)
	d.moist_range = Vector2(0.7, 1.0)
	d.adjacency = {&"burning": 0.3, &"moss": 0.2, &"coast": 0.2}
	d.coastal = 0.1
	# Broken volcanic ground — cones, collapsed chambers, a lot of small steep
	# stuff rather than one big shape.
	d.relief = {
		&"base": 7.5, &"hills": 4.5, &"ridge": 5.0, &"terrace": 0.5, &"valley": 2.2,
		&"rain": 1.4, &"temp": 0.3, &"moist": 0.85, &"cliff": 0.6,
	}
	d.border_elevation = 1.2
	d.reach_out_high = Vector4(5.5, 0.1, 0.12, 0.35)
	d.reach_in_low = Vector3(5.0, 0.09, 0.3)
	d.hatch = Ink.SPARSE
	d.grounds = {
		Ground.GRASS: P.MOSS[3].lerp(P.SPRUCE[3], 0.3),
		Ground.MOSS: P.SPRUCE[2].lerp(P.MOSS[2], 0.4),
		Ground.MUD: P.EARTH[3].lerp(P.SAND[3], 0.3),
		Ground.ASH: P.SAND[4].lerp(P.EARTH[3], 0.25),
		Ground.ROCK: P.SLATE[3].lerp(P.EARTH[3], 0.3),
		Ground.CLINKER: P.SLATE[2].lerp(P.RUST[2], 0.3),
		Ground.NEEDLES: P.SPRUCE[2].lerp(P.EARTH[2], 0.4),
	}
	# Grounds this place never lays, named anyway: anything left unnamed falls
	# through to the shared table, which is the COAST's and is far brighter than
	# here, so it would arrive as the loudest object in the frame. Each takes this
	# landscape's own ash, because they only have to be in key.
	for g: int in [Ground.BONE, Ground.GRAVEL, Ground.ICE, Ground.LIMESTONE, Ground.PAN, Ground.SALT, Ground.SAND, Ground.SHINGLE, Ground.SNOW]:
		d.grounds[g] = d.grounds[Ground.ASH]
	d.cliff_wash = P.SLATE[2].lerp(P.EARTH[2], 0.35)
	d.strata = GroundColors.STRATA_BASALT
	d.plain_ground = Ground.GRASS
	d.bank_ground = Ground.MUD
	d.pool_rim_ground = Ground.ASH
	d.village_ground = Ground.MUD
	d.decor = {Ground.GRASS: [0.95, Decor.TUFT, 36, Decor.CROTTLE, 14]}
	d.grass_colors = [P.MOSS[3], P.SPRUCE[3]]
	d.rock_color = P.SLATE[3]
	# What grows here is fat, dark and fast, and the yellow is the ground under it.
	d.tree_tints = {&"leaf": [P.SPRUCE[3], P.MOSS[3], P.SPRUCE[2], P.MOSS[2]]}
	d.decor_tints = {&"fronds": [P.MOSS[3], P.SPRUCE[3], P.SAND[3]]}
	# Sulphur crust on everything near a vent, and timber that never dries out.
	var dress := BiomeDressing.new()
	dress.stone = [P.SLATE[3], P.EARTH[3], P.SAND[4]]
	dress.walling = [P.SLATE[2], P.EARTH[2], P.SAND[3], P.SPRUCE[2]]
	dress.timber = [P.EARTH[2], P.SPRUCE[2]]
	dress.crown = &"full"
	dress.sink = 0.2
	dress.lie = Vector2(-0.08, 0.14)
	d.dressing = dress
	d.grade = Vector4(0.0, 0.04, -0.02, 0.03)
	# Thick canopy and standing steam: dark under the trees even on a clear night.
	d.night_sky = 0.75
	d.props = [PropKind.BROADLEAF, PropKind.BUSH, PropKind.VENT, PropKind.VENT_CAP,
		PropKind.REEDS, PropKind.BOULDER, PropKind.STUMP, PropKind.STONE_ORE,
		PropKind.COPPER_ORE, PropKind.SLAG_HEAP]
	d.ore = [[PropKind.COPPER_ORE, 0.034], [PropKind.STONE_ORE, 0.026], [PropKind.TIN_ORE, 0.02]]
	d.sites = {"fumaroles": 4, "tips": 1}
	d.beached_wrecks = false
	d.pools = {"order": 2, "cell": 26, "chance": 0.6, "r_min": 2.2, "r_max": 4.6, "ground": Ground.WATER}
	d.villages = 1
	d.village_order = 21
	d.village_names = ["Steam Row", "Yellowfoot"]
	d.weather = [
		[Weather.RAIN, 30, 0.6], [Weather.FOG, 22, 0.0], [Weather.GREY, 18, 0.0],
		[Weather.HEAT, 18, 0.0], [Weather.STORM, 12, 0.5],
	]
	d.mist = 0.45
	# Declared under BITE on purpose, like the Burning's, so the WEATHER decides:
	# the fumes are always noticed and only unbreathable when the air is still and
	# wet, which here is most of the time.
	d.hazards = {&"heat": 0.5, &"fumes": 0.5, &"wet": 0.45}
	d.roster = {
		&"dredger": {"weight": 0.9, "grounds": ["mud", "water"]},
		&"cutter": {"weight": 0.9, "grounds": ["rock", "clinker", "ash"]},
		&"harvester": {"weight": 0.8, "grounds": ["grass", "moss", "mud"]},
		&"watcher": {"weight": 0.8},
		&"dog.feral": {"weight": 0.7},
	}
	d.landmarks = [&"evaporator", &"blinking_stack", &"firewatch", &"clerks_office"]
	d.sound_bed = &"bed_moss"
	d.surface = _surface
	d.scatter = _scatter
	return d


## Green over most of it, ash and crust round the vents where nothing will take,
## and mud in every bottom because the rain has nowhere to go.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.SAND
	if f & BiomeSurface.APRON != 0:
		return Ground.CLINKER
	if f & BiomeSurface.BANK != 0:
		return Ground.MUD
	if rs > 1.5:
		return Ground.ROCK
	if e <= 5.0:
		return Ground.MUD
	return Ground.ASH if gb > 0.84 else Ground.GRASS


## THE THICKEST CANOPY IN THE GAME, because the ground is warm and wet and has
## been left alone for seventy years. Twice the coast's broadleaf rate.
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.GRASS:
		if r < 0.11:
			return PropKind.BROADLEAF
		return PropKind.BUSH if r < 0.17 else BiomeScatter.NONE
	if g == Ground.MUD:
		return PropKind.REEDS if r < 0.05 else BiomeScatter.NONE
	return BiomeScatter.NONE
