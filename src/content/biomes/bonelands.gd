## Bonelands: limestone pavement cut by grikes, standing stones some of which
## were cast in concrete with rebar in them, cairns, and the machines' drill
## grids ruled straight across the clints.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"bonelands"
	d.display_name = "bonelands"
	d.order = 4
	d.style_note = "Cracked broken lines, hard white light, grikes as ink cuts."
	d.share = Vector2(0.11, 0.15)
	d.anchors = [{"seq": 5, "u": 0.83, "v": 0.53, "band": &"middle", "slot": 2}]
	d.temp_range = Vector2(0.4, 0.7)
	d.moist_range = Vector2(0.0, 0.4)
	d.adjacency = {&"burning": 0.2, &"snowfield": 0.1}
	d.relief = {
		&"base": 5.8, &"hills": 2.4, &"ridge": 0.6, &"near": 5.5, &"terrace": 1.0, &"valley": 1.25,
		&"rain": 0.45, &"temp": 0.5, &"moist": 0.22, &"cliff": 0.45,
	}
	d.hatch = Ink.CROSS
	d.grounds = {
		Ground.ROAD: P.LINEN[3].lerp(P.EARTH[3], 0.4),
		Ground.GRAVEL: P.STONE[3].lerp(P.LINEN[3], 0.5),
		# Bleached sheep-bitten grass on the limestone.
		Ground.GRASS: P.MOSS[4].lerp(P.SAND[4], 0.5),
		Ground.HEATH: P.EARTH[3].lerp(P.SAND[3], 0.5),
		Ground.SCREE: P.SLATE[3].lerp(P.LINEN[3], 0.35),
		Ground.ROCK: P.LINEN[3].lerp(P.SLATE[3], 0.4),
	}
	d.cliff_wash = P.LINEN[3]
	d.strata = GroundColors.STRATA_BONE
	d.plain_ground = Ground.LIMESTONE
	d.bank_ground = Ground.GRAVEL
	d.pool_rim_ground = Ground.MUD
	d.rock_ground = Ground.SCREE
	d.village_ground = Ground.GRASS
	# Twice the litter of anywhere else, and most of it is what the drilling
	# left: cores pulled and dropped where they came out, cast stone with its
	# rebar showing, bolts, bone. An empty land that says who emptied it.
	d.decor = {Ground.GRASS: [1.2, Decor.TUFT, 32, Decor.FLOWER, 12, Decor.STONE, 10,
		Decor.THISTLE, 6, Decor.BONE, 8, Decor.REBAR, 6, Decor.DRILL_CORE, 4, Decor.BOLT, 4]}
	d.grass_colors = [P.MOSS[4].lerp(P.SAND[4], 0.4), P.SAND[4]]
	d.rock_color = P.LINEN[3]
	d.hard_rock = true
	d.decor_tints = {&"bloom": [P.BRINE[3], P.BRINE[4], P.LINEN[4]], &"spoil": [P.LINEN[4]]}
	# Limestone, which breaks slabby rather than round, and a sun that takes the
	# colour out of everything left in it — so paint goes chalky and a tyre
	# perishes. What grows is a hawthorn bent right over by the wind.
	var dress := BiomeDressing.new()
	dress.stone = [P.LINEN[3], P.LINEN[2], P.LINEN[4]]
	dress.facets = 5
	dress.timber = [P.LINEN[3], P.LINEN[2]]
	dress.drift = [P.LINEN[4].lerp(P.SAND[4], 0.4), P.LINEN[3]]
	dress.turf = [P.MOSS[3].lerp(P.SAND[4], 0.4), P.MOSS[3], P.SAND[3].lerp(P.MOSS[3], 0.4), P.SAND[3]]
	dress.walling = [P.LINEN[3], P.LINEN[2], P.LINEN[4], P.SAND[3]]
	dress.sign = [P.LINEN[5].lerp(P.PLATE[4], 0.2), P.INK[1]]
	dress.bleach = P.LINEN[3]
	dress.wind = 0.13
	dress.sink = 0.14
	dress.lie = Vector2(0.08, -0.07)
	dress.berry = P.RUST[3]
	dress.shelter = &"lean_to"
	dress.crown = &"low"
	dress.spread = 1.3
	d.dressing = dress
	d.tree_tints = {
		&"leaf": [P.MOSS[3].lerp(P.SAND[4], 0.35), P.MOSS[3], P.MOSS[4].lerp(P.LINEN[4], 0.35), P.MOSS[3].lerp(P.SAND[3], 0.3)],
		&"scrub": [P.MOSS[3].lerp(P.SAND[4], 0.35), P.MOSS[3], P.MOSS[4].lerp(P.LINEN[3], 0.35)],
	}
	d.grade = Vector4(-0.03, 0.14, -0.02, 0.12)
	# Nothing stands here and the ground is bone: an open sky over a pale floor,
	# so the night is wide and cold rather than dark. What makes it frightening is
	# that you can be seen in it.
	d.night_sky = 1.20
	d.props = [PropKind.PINE, PropKind.DEAD_TREE, PropKind.BUSH, PropKind.REEDS, PropKind.BOULDER,
		PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.COPPER_ORE, PropKind.TIN_ORE, PropKind.COAL_ORE,
		PropKind.BONES, PropKind.GORSE, PropKind.CLINTS, PropKind.STANDING_STONE,
		PropKind.DRIFTWOOD, PropKind.WRACK, PropKind.MUSSEL_ROCK]
	# The richest seams in the world, and they show in the pavement's joints.
	d.ore = [[PropKind.STONE_ORE, 0.05], [PropKind.IRON_ORE, 0.075], [PropKind.COPPER_ORE, 0.1],
		[PropKind.TIN_ORE, 0.12], [PropKind.COAL_ORE, 0.135]]
	d.gravel_ore = true
	d.reed_chance = 0.14
	d.sites = {"tips": 3, "stone_circles": 3, "summit": 2, "kiln_ground": Ground.LIMESTONE}
	d.villages = 2
	d.village_order = 4
	d.village_names = ["Chalkstone", "Grike End", "Pale Knoll"]
	# Hard white glare, dust on the wind, dry lightning with no rain in it.
	d.weather = [
		[Weather.CLEAR, 20, 0.0], [Weather.GLARE, 24, 0.0], [Weather.GREY, 10, 0.0],
		[Weather.DUST, 18, 0.6], [Weather.FOG, 6, 0.0], [Weather.DRY_STORM, 16, 0.4], [Weather.STORM, 6, 0.4],
	]
	d.hazards = {&"heat": 0.3}
	d.roster = {
		&"cutter": {"weight": 1.0}, &"hauler": {"weight": 1.0},
		&"dog.yard": {"weight": 1.0}, &"dog.feral": {"weight": 1.0},
		&"bull.field": {"weight": 1.0},
		&"gulls": {"weight": 1.0, "hours": Vector2(6, 20)},
	}
	# The places worth the walk it holds (docs/VISION.md §3, src/core/landmarks):
	# what a player crosses this landscape FOR. Its own file is the authority;
	# `Landmarks.problems` fails if a kind here does not name this landscape back.
	d.landmarks = [&"blinking_stack", &"cast_stones", &"clerks_office"]
	d.sound_bed = &"bed_bones"
	d.surface = _surface
	d.scatter = _scatter
	return d


static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.SHINGLE
	if f & BiomeSurface.APRON != 0:
		return Ground.SCREE
	if f & BiomeSurface.BANK != 0 and gb > 0.0:
		return Ground.GRAVEL
	if rs < -0.4 - gb * 0.3:
		# Green dales between the pavements, heath where they widen.
		return Ground.HEATH if gb > 0.35 else Ground.GRASS
	if gb < -0.5:
		return Ground.GRAVEL
	if gb > 0.5:
		return Ground.BONE
	return Ground.LIMESTONE


static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.GRASS:
		if r < 0.01:
			return PropKind.BONES
		if r < 0.022:
			return PropKind.BOULDER
		return PropKind.GORSE if r < 0.03 else BiomeScatter.NONE
	if g == Ground.HEATH:
		var k := maxf(0.0, t.clump[i])
		if r < 0.02 + k * 0.26:
			return PropKind.GORSE
		return PropKind.BOULDER if r > 0.37 and r < 0.385 else BiomeScatter.NONE
	return BiomeScatter.PASS
