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
	d.share = Vector2(0.11, 0.15)
	# One of the three that cross the island's waist. Two of the belt trade
	# places with the seed, so no world lays it in the same order.
	d.anchors = [{"seq": 3, "u": 0.17, "v": 0.53, "band": &"middle", "slot": 0, "swap": 0.4}]
	d.temp_range = Vector2(0.3, 0.65)
	d.moist_range = Vector2(0.7, 1.0)
	d.adjacency = {&"pinewood": 0.4, &"coast": 0.2}
	d.relief = {
		&"base": 1.3, &"hills": 0.7, &"ridge": 0.0, &"terrace": 0.0, &"valley": 0.3,
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
	d.decor = {Ground.GRASS: [1.2, Decor.SEDGE, 30, Decor.TUFT_TALL, 20, Decor.BOG_COTTON, 14, Decor.SPHAGNUM, 8]}
	d.grass_colors = [P.SPRUCE[3], P.MOSS[3]]
	d.rock_color = P.SLATE[2].lerp(P.SPRUCE[2], 0.3)
	d.decor_tints = {&"bloom": [P.RUST[4], P.SAND[5], P.RUST[5]]}
	d.grade = Vector4(-0.5, 0.16, 0.02, 0.06)
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
	d.sound_bed = &"bed_moss"
	d.surface = _surface
	d.scatter = _scatter
	return d


static func _surface(t: BiomeSurface, e: float, rs: float, gb: float) -> int:
	if t.shore:
		return Ground.MUD if gb > -0.25 else Ground.SAND
	if t.apron:
		return Ground.PEAT
	if e >= 5.0 and rs > 0.3 and gb > -0.1:
		return Ground.HEATH
	if rs > 0.35 + gb * 0.6 or gb > 0.45:
		# Peat hags stand proud of the fen; peat moor where it masses.
		return Ground.PEAT
	if rs < -0.6 and gb < -0.1:
		return Ground.MUD
	return Ground.MOSS


static func _scatter(t: BiomeScatter, g: int, r: float) -> int:
	if g == Ground.MUD:
		if r < 0.1 + maxf(0.0, t.clump[t.i]) * 0.35:
			return PropKind.REEDS
		# Drowned trunks stand where the fen took the ground back.
		return PropKind.DEAD_TREE if r > 0.49 else BiomeScatter.NONE
	return BiomeScatter.PASS
