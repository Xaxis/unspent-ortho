## Moss: fen, black water, peat hags and reeds, under a green-grey gloom.
## Dead trees with insulators still standing in it; the machines drained half of
## it and the pumps are still running.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"moss"
	d.display_name = "moss"
	d.order = 1
	d.style_note = "Soft broken edges, stippled dots, mist lying in the hollows."
	d.share = Vector2(0.09, 0.13)
	# ON HOME, ALWAYS: the first step north of the coast, so the journey can be
	# READ from where he wakes (docs/DESIGN.md: `least` is so a beat never
	# strands "a player who never crosses the ocean") and the coast-moss border is
	# a promise rather than a leak. Home is "not dealt the harshest or rarest
	# types" (§8.4), and harshest is read as the top of the landscapes' own table
	# of declared hazards, about 0.7 and up (snowfield, glass desert, the drowned
	# city, the Burning, the salt, the frost sea, the caves). The moss's wet at 0.6
	# bites, but it is thirteenth of twenty-three, a mid-pack bog and not a
	# destination; "anything that bites" would bar thirteen landscapes, a rule
	# nobody wrote.
	d.spread = Vector2i(1, 0)
	# One of the three that cross the island's waist. Two of the belt trade
	# places with the seed, so no world lays it in the same order.
	d.anchors = [{"seq": 3, "u": 0.17, "v": 0.53, "band": &"middle", "slot": 0, "swap": 0.4}]
	d.temp_range = Vector2(0.3, 0.65)
	d.moist_range = Vector2(0.7, 1.0)
	d.adjacency = {&"pinewood": 0.4, &"coast": 0.2}
	d.relief = {
		&"base": 1.3, &"hills": 0.7, &"ridge": 0.0, &"near": 1.5, &"terrace": 0.0, &"valley": 0.3,
		&"rain": 1.35, &"temp": 0.46, &"moist": 0.92, &"cliff": -0.6,
	}
	# Long tongues of pinewood reach into the fen along drier ground, and the
	# fen runs back up the wet hollows.
	d.tongues = {&"pinewood": Vector2(30.0, 13.0)}
	d.hatch = Ink.STIPPLE
	d.grounds = {
		Ground.SAND: P.SAND[3],
		Ground.GRASS: P.MOSS[2],
		Ground.HEATH: P.EARTH[1].lerp(P.MOSS[1], 0.5),
		Ground.MUD: P.EARTH[1].lerp(P.EARTH[2], 0.35),
		Ground.ROCK: P.SLATE[2].lerp(P.SPRUCE[2], 0.35),
	}
	# The mud here is peat that has not dried: it takes the fen's ink, not silt's.
	d.ground_marks = {Ground.MUD: GroundColors.PEAT}
	d.cliff_wash = P.EARTH[1]
	d.strata = GroundColors.STRATA_MOSS
	d.plain_ground = Ground.MOSS
	d.bank_ground = Ground.PEAT
	d.pool_rim_ground = Ground.PEAT
	d.village_ground = Ground.GRASS
	# Sedge, heavy and dark, arching over and slow to move; and bog cotton, thin
	# stems standing out of it with white heads that bob in the least air.
	d.grasses = [
		GrassSpecies.make(&"sedge", {"blades": 22, "height": Vector2(0.25, 0.45), "width": 0.028, "spread": 0.22,
			"reach": Vector2(0.45, 0.8), "curl": 0.35, "lay": 0.15, "root": P.SPRUCE[2], "tip": P.MOSS[3],
			"stiff": 0.7, "flutter": 1}),
		GrassSpecies.make(&"bog_cotton", {"blades": 9, "height": Vector2(0.25, 0.42), "width": 0.012, "spread": 0.16,
			"reach": Vector2(0.05, 0.15), "curl": 0.05, "lay": 0.3, "root": P.MOSS[2], "tip": P.MOSS[3],
			"heads": 9, "head_color": P.LINEN[5], "head_size": 0.04, "stiff": 0.35, "flutter": 5}),
	]
	d.decor = {
		Ground.GRASS: [1.2, Decor.GRASS_A, 30, Decor.TUFT_TALL, 20, Decor.GRASS_B, 14, Decor.SPHAGNUM, 8],
		Ground.MOSS: [Vector2(1.3, 0.6), Decor.GRASS_A, 34, Decor.GRASS_B, 20, Decor.SPHAGNUM, 16, Decor.TUFT, 6, Decor.FLOWER, 4],
	}
	d.grass_colors = [P.SPRUCE[3], P.MOSS[3]]
	d.rock_color = P.SLATE[2].lerp(P.SPRUCE[2], 0.3)
	d.decor_tints = {&"bloom": [P.RUST[4], P.SAND[5], P.RUST[5]]}
	# Wet slate, timber gone black in the bog, and peat banked against anything
	# left standing. What people build here stands on stilts over the water.
	var dress := BiomeDressing.new()
	dress.stone = [P.SLATE[2], P.SLATE[1], P.MOSS[2]]
	dress.timber = [P.EARTH[1], P.INK[3]]
	dress.drift = [P.EARTH[1].lerp(P.MOSS[1], 0.4), P.EARTH[1]]
	dress.sign = [P.RIME[4].lerp(P.MOSS[3], 0.25), P.INK[1]]
	dress.spread = 0.85
	dress.sink = 0.34
	dress.lie = Vector2(-0.26, -0.12)
	d.dressing = dress
	d.tree_tints = {
		&"needle": [P.SPRUCE[2].lerp(P.MOSS[2], 0.35), P.SPRUCE[3].lerp(P.MOSS[3], 0.3), P.SPRUCE[3].lerp(P.MOSS[4], 0.3)],
		&"leaf": [P.MOSS[2].lerp(P.ASH[2], 0.4), P.MOSS[2], P.ASH[3].lerp(P.MOSS[3], 0.5), P.MOSS[3]],
		&"trunk": [P.LINEN[2]],
		&"scrub": [P.SPRUCE[2], P.EARTH[2].lerp(P.MOSS[2], 0.5), P.SPRUCE[2].lerp(P.MOSS[3], 0.4)],
		&"dead": [P.LINEN[2].lerp(P.SPRUCE[2], 0.25), P.ASH[1]],
		&"reed": [P.MOSS[2], P.EARTH[3], P.MOSS[3]],
		&"reed_head": [P.EARTH[1]],
	}
	d.grade = Vector4(-0.5, 0.16, 0.02, 0.06)
	# A fen has NO LID ON IT. The moss is dark because its ground is dark — peat
	# and sphagnum are the lowest-albedo surfaces in the game — and not because
	# anything stands between it and the sky, so its night is the brightest of the
	# surface landscapes and it still comes out the darkest picture. Under the one
	# global night it was 95.3% below luma 24 at 23:00 against the coast's 81.4%,
	# which is a bog nobody can cross rather than a bog that is dark.
	d.night_sky = 1.45
	d.wet = 0.35
	d.props = [PropKind.PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE, PropKind.BUSH, PropKind.REEDS,
		PropKind.BOULDER, PropKind.STONE_ORE, PropKind.COAL_ORE, PropKind.PEAT_BANK,
		PropKind.DRIFTWOOD, PropKind.WRACK, PropKind.MUSSEL_ROCK]
	d.ore = [[PropKind.STONE_ORE, 0.02], [PropKind.COAL_ORE, 0.03]]
	d.reed_chance = 0.3
	d.sites = {"tips": 2, "ruins": true}
	d.pools = {"order": 1, "cell": 18, "chance": 0.85, "r_min": 2.6, "r_max": 4.8, "ground": Ground.BLACKWATER}
	d.villages = 2
	d.village_order = 1
	d.village_names = ["Fennick", "Sedgeley", "Peatholm"]
	# Drowned green gloom: drizzle and fog lying in the hollows, still air.
	d.weather = [
		[Weather.CLEAR, 16, 0.0], [Weather.GREY, 20, 0.0], [Weather.DRIZZLE, 28, 0.0],
		[Weather.FOG, 24, 0.0], [Weather.RAIN, 6, 0.3], [Weather.STORM, 6, 0.3],
	]
	d.mist = 1.0
	d.hazards = {&"wet": 0.6, &"toxins": 0.1}
	d.roster = {
		&"dredger": {"weight": 1.0},
		&"dog.yard": {"weight": 1.0}, &"dog.feral": {"weight": 1.0},
		&"gulls": {"weight": 1.0, "hours": Vector2(6, 20)},
	}
	# The places worth the walk it holds (docs/VISION.md, src/core/landmarks):
	# what a player crosses this landscape FOR. Its own file is the authority;
	# `Landmarks.problems` fails if a kind here does not name this landscape back.
	d.landmarks = [&"leaning_mast", &"cast_stones", &"grown_hulk", &"clerks_office"]
	d.sound_bed = &"bed_moss"
	d.surface = _surface
	d.scatter = _scatter
	# The web's day contrast here (BiomeDef.web_contrast): measured: the sunny moss wanted 0.85 of 0.95 and the grey moss 0.95 of 1.05, both 0.9.
	d.web_contrast = 0.9
	return d


static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.MUD if gb > -0.25 else Ground.SAND
	if f & BiomeSurface.APRON != 0:
		return Ground.PEAT
	if e >= 5.0 and rs > 0.3 and gb > -0.1:
		return Ground.HEATH
	if rs > 0.35 + gb * 0.6 or gb > 0.45:
		# Peat hags stand proud of the fen; peat moor where it masses.
		return Ground.PEAT
	if rs < -0.6 and gb < -0.1:
		return Ground.MUD
	return Ground.MOSS


## A BOG THAT REACHES THE SEA, which is the thing about this place that one prop
## kind could never say. The MOSS is the open bog and what grows on it is
## stunted and sparse -- a pine out here is a survivor, not a wood. The PEAT
## banks are cut faces with a lip, so they carry the peat and the dead standing
## trees; the MUD is where the reeds are; and the SAND is a real SHORE, with
## driftwood and wrack and mussel rock on it, because the Moss ends at the water
## and a bog with no coast is half a landscape.
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.MOSS:
		if r < 0.036:
			return PropKind.BUSH
		if r < 0.048:
			return PropKind.DEAD_TREE
		return PropKind.PINE if r > 0.55 and r < 0.5625 else BiomeScatter.NONE
	if g == Ground.PEAT:
		if r < 0.055:
			return PropKind.PEAT_BANK
		return PropKind.DEAD_TREE if r < 0.070 else BiomeScatter.NONE
	if g == Ground.MUD:
		if r < 0.060:
			return PropKind.REEDS
		return PropKind.PEAT_BANK if r < 0.074 else BiomeScatter.NONE
	if g == Ground.HEATH:
		if r < 0.040:
			return PropKind.BUSH
		return PropKind.PINE if r < 0.055 else BiomeScatter.NONE
	if g == Ground.GRASS:
		if r < 0.050:
			return PropKind.BROADLEAF
		return PropKind.BUSH if r < 0.068 else BiomeScatter.NONE
	if g == Ground.ROCK:
		if r < 0.034:
			return PropKind.BOULDER
		if r < 0.046:
			return PropKind.STONE_ORE
		return PropKind.COAL_ORE if r < 0.056 else BiomeScatter.NONE
	if g == Ground.SAND:
		if r < 0.038:
			return PropKind.DRIFTWOOD
		if r < 0.052:
			return PropKind.WRACK
		return PropKind.MUSSEL_ROCK if r < 0.062 else BiomeScatter.NONE
	return BiomeScatter.NONE
