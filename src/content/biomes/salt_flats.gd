## Salt Flats (docs/VISION.md §3, surface 7): a drained inland sea, floored in
## white crust that cracks into polygons and lifts at every join. The machines
## took the water: their evaporation pans are ruled rectangles bunded across the
## flat, their sluice gates still stand, and the rakes still go round on pans
## that yield nothing. Where the brine drew back it left rings of mineral stain.
##
## The mood is glare, not dark. At noon the flat is the brightest ground in the
## game and the hardest to look at; at dusk the pans hold the sky in sheets; at
## night it reads as pale paper under a cold moon with the gates' strips on it.
## Nothing grows. The horizon shimmers and nothing ever arrives at it.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"salt_flats"
	d.display_name = "salt flats"
	d.order = 6
	d.style_note = "Hard white glare on a cracked mosaic; the pans ruled straight across it."
	d.share = Vector2(0.055, 0.085)
	# No anchor: it goes where the island is hot, dry and far from the sea.
	d.temp_range = Vector2(0.45, 0.85)
	d.moist_range = Vector2(0.0, 0.35)
	d.site_count = Vector2i(1, 2)
	d.coastal = -0.8
	# It likes the dry country and keeps away from the fen and the wood.
	d.adjacency = {&"bonelands": 0.5, &"burning": 0.2, &"moss": -0.6, &"pinewood": -0.5}
	# A basin: low, flat, barely any relief, and rivers die in it.
	d.relief = {
		&"base": 1.6, &"hills": 0.5, &"ridge": 0.0, &"terrace": 0.0, &"valley": 0.35,
		&"rain": 0.2, &"temp": 0.72, &"moist": 0.1, &"cliff": -0.3,
	}
	# The crust drifts out thin on the wind and stops, and little of what grows
	# outside gets in: a flat that wears the next country's ground is not a flat.
	d.reach_out_thin = 0.35
	d.reach_in_thin = 0.4
	d.hatch = Ink.CROSS
	d.grounds = {
		Ground.ROAD: P.LINEN[3].lerp(P.SAND[3], 0.4),
		Ground.SAND: P.LINEN[4].lerp(P.SAND[4], 0.5),
		Ground.SHINGLE: P.LINEN[3].lerp(P.STONE[3], 0.4),
		Ground.GRAVEL: P.LINEN[3].lerp(P.STONE[3], 0.35),
		# What little grass survives on the rim is bleached to straw.
		Ground.GRASS: P.SAND[4].lerp(P.LINEN[4], 0.45),
		Ground.HEATH: P.SAND[3].lerp(P.EARTH[3], 0.4),
		Ground.ROCK: P.LINEN[3].lerp(P.STONE[2], 0.3),
		Ground.SCREE: P.LINEN[2].lerp(P.STONE[3], 0.4),
	}
	d.cliff_wash = P.LINEN[4].lerp(P.SAND[4], 0.3)
	d.strata = GroundColors.STRATA_SALT
	d.plain_ground = Ground.SALT
	d.bank_ground = Ground.PAN
	d.pool_rim_ground = Ground.PAN
	d.village_ground = Ground.PAN
	d.village_square_ground = Ground.GRAVEL
	d.beached_wrecks = false
	d.decor = {
		Ground.SALT: [0.4, Decor.SALT_PLATE, 54, Decor.PEBBLES, 8, Decor.BOLT, 3, Decor.SCRAP, 3],
		Ground.PAN: [0.35, Decor.SALT_PLATE, 18, Decor.PEBBLES, 20, Decor.STONE, 10, Decor.CAN, 4, Decor.WIRE, 4],
		Ground.GRASS: [0.6, Decor.TUFT, 30, Decor.THISTLE, 12, Decor.STONE, 12, Decor.BONE, 4],
	}
	d.grass_colors = [P.SAND[4], P.LINEN[4]]
	d.rock_color = P.LINEN[3]
	d.hard_rock = true
	d.decor_tints = {&"bloom": [P.LINEN[4], P.SAND[5], P.LINEN[5]], &"spoil": [P.LINEN[4]]}
	# Whatever holds on at the rim is bleached and half dead.
	d.tree_tints = {
		&"leaf": [P.MOSS[4].lerp(P.LINEN[4], 0.5), P.MOSS[4].lerp(P.SAND[4], 0.4), P.LINEN[4], P.SAND[4]],
		&"trunk": [P.LINEN[2]],
		&"scrub": [P.MOSS[4].lerp(P.SAND[4], 0.5), P.SAND[4], P.LINEN[3]],
	}
	# The one landscape whose noon is BRIGHTER than the page: the grade lifts
	# instead of dimming, and the contrast is pushed so the glare has an edge.
	d.grade = Vector4(0.12, 0.2, -0.06, 0.2)
	d.light_tint = Color(1.03, 1.01, 0.97)
	d.props = [PropKind.SALT_RIDGE, PropKind.SALT_HEAP, PropKind.PAN_GATE, PropKind.BOULDER,
		PropKind.BONES, PropKind.DEAD_TREE, PropKind.STONE_ORE, PropKind.TIN_ORE, PropKind.COPPER_ORE,
		PropKind.DRIFTWOOD, PropKind.GORSE, PropKind.BUSH]
	# Evaporites: what the brine left is worth taking, and the stone under it.
	d.ore = [[PropKind.STONE_ORE, 0.03], [PropKind.TIN_ORE, 0.045], [PropKind.COPPER_ORE, 0.055]]
	d.sites = {"tips": 2, "ruins": true, "summit": 0}
	d.villages = 1
	d.village_names = ["Panfoot", "Bitter Cross", "Rakeshead"]
	d.village_order = 6
	# Glare almost every day, dust off the crust, and the dry storms that come
	# over the flat with no rain in them at all.
	d.weather = [
		[Weather.CLEAR, 18, 0.0], [Weather.GLARE, 34, 0.0], [Weather.HEAT, 12, 0.0],
		[Weather.DUST, 22, 0.55], [Weather.DRY_STORM, 10, 0.4], [Weather.GREY, 4, 0.0],
	]
	d.hazards = {&"heat": 0.6, &"glare": 0.8, &"thirst": 0.7}
	# Pan rakers work the bunds all day; a mirage decoy stands out on the flat
	# where there is nothing to stand on. Until the content milestone draws
	# them, the machines that already rake and haul answer to the same orders.
	var crust := ["salt", "pan", "gravel", "sand", "shingle", "road", "grass"]
	d.roster = {
		&"cutter": {"weight": 0.8, "hours": Vector2(6, 20), "grounds": crust},
		&"hauler": {"weight": 1.0, "grounds": crust},
		&"watcher": {"weight": 1.2, "grounds": crust},
		&"runner": {"weight": 0.6, "hours": Vector2(10, 17), "grounds": crust},
		&"gulls": {"weight": 0.4, "hours": Vector2(6, 20), "grounds": ["salt", "pan", "sand", "shingle", "gravel"]},
	}
	d.sentinel = &""
	d.sound_bed = &"bed_bones"
	d.music_motif = &"bonelands"
	d.surface = _surface
	d.scatter = _scatter
	# What this landscape holds of what happened to it (docs/VISION.md §8).
	GenWorks.register(&"salt_flats", {
		"host": load("res://src/content/biomes/salt_flats.gd"),
		"works": &"_works",
		"vignettes": [[5, &"survey_posts"], [4, &"debris_field"], [4, &"tipped_signs"], [3, &"grave_cluster"],
			[3, &"wreck"], [2, &"wreck_parts"], [2, &"barricade"], [1, &"shelter"]],
		# Nothing to drill in a dry pan: where the survey crosses the flat it
		# leaves its posts and a sign, and goes on.
		"survey": [[0.45, &"sign_beside"]],
	})
	return d


## Crust almost everywhere; the pans are where the ground lies low and damp, and
## the rim of the basin comes up through it as gravel and bleached grass.
static func _surface(t: BiomeSurface, e: float, rs: float, gb: float) -> int:
	if t.shore:
		return Ground.SHINGLE if gb > 0.1 else Ground.SAND
	if t.apron:
		return Ground.SCREE
	if t.bank:
		# A stream that reaches the flat sinks into it and stains the pan.
		return Ground.PAN
	if rs > 0.9 + gb * 0.5 or e >= 5.5:
		# The rim of the basin: what the flat never drowned, in one wash or the
		# other over a whole slope rather than tile by tile.
		return Ground.GRASS if gb > 0.15 else Ground.GRAVEL
	if rs < -0.55 - gb * 0.5:
		# The lowest ground is the last to dry: pan, stained and damp, and it
		# masses in the hollows instead of freckling the flat.
		return Ground.PAN
	return Ground.SALT


static func _scatter(t: BiomeScatter, g: int, r: float) -> int:
	if g == Ground.SALT:
		var k := maxf(0.0, t.clump[t.i])
		if r < 0.012 + k * 0.05:
			# Pressure ridges run in lines where two plates met.
			return PropKind.SALT_RIDGE
		if r > 0.2 and r < 0.203:
			return PropKind.SALT_HEAP
		return PropKind.BONES if r > 0.249 and r < 0.2497 else BiomeScatter.NONE
	if g == Ground.PAN:
		if r < 0.01:
			return PropKind.SALT_RIDGE
		# A gate stands in a bund, and a bund is a work: the scatter leaves it
		# to whoever built the pans.
		return PropKind.DEAD_TREE if r > 0.22 and r < 0.2215 else BiomeScatter.NONE
	if g == Ground.GRASS:
		if r < 0.012:
			return PropKind.GORSE
		return PropKind.BONES if r < 0.018 else BiomeScatter.NONE
	if g == Ground.HEATH:
		return PropKind.GORSE if r < 0.03 else BiomeScatter.NONE
	return BiomeScatter.PASS


## The machines' works here (GenWorks.register, called from make()): the pans
## themselves. Bunded rectangles ruled across the flat on the survey bearing,
## a gate in every wall, the rake's rows still in the floor, and the conveyor
## that carried the salt off to somewhere that stopped wanting it.
static func _works(L: Object) -> void:
	var c: GenContext = L.c
	var rng: RandomNumberGenerator = L.rng
	var d: Vector2 = L.d
	var nrm: Vector2 = L.nrm
	var floors: Array = [Ground.SALT, Ground.PAN, Ground.GRAVEL, Ground.SAND]
	# Pan batteries: two or three pans side by side, each a ruled rectangle.
	for n in GenWorks._n(c, 2.0):
		var p := GenWorks._site(L, 8, 1, floors, 34.0, 700, 0.4)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var half := Vector2(rng.randf_range(8.0, 11.0), rng.randf_range(5.0, 7.0))
		GenWorks._record(c, &"pans", at, d, half, GenWorks.CUT)
		# The bund: a gate at the middle of each long wall, survey posts at the
		# corners, and a line of pipe carrying brine that never comes.
		for sx: float in [-1.0, 1.0]:
			GenWorks._put(L, PropKind.PAN_GATE, at + nrm * half.y * sx, nrm.angle(), -99, 0.4, true)
			for sy: float in [-1.0, 1.0]:
				GenWorks._put(L, PropKind.SURVEY, at + d * half.x * sy + nrm * half.y * sx, d.angle(), -99, 0.0, true)
		GenWorks._run(L, PropKind.PIPE, at + d * (half.x + 1.0), d, rng.randi_range(3, 5), 2.0, -99, 0.25)
		# What the rakes left standing in the pan, in rows along the bearing.
		for gx in range(-2, 3):
			if rng.randf() < 0.3:
				continue
			GenWorks._put(L, PropKind.SALT_HEAP, at + d * gx * 3.4 + nrm * rng.randf_range(-1.5, 1.5), 0.0, -99, 0.3)
		GenWorks._put(L, PropKind.SIGN, at - d * (half.x + 1.6), (-d).angle(), -99, 0.2)
		GenWorks._about(L, PropKind.DEBRIS, at, 2, half.y, half.x)
	# The intake that drained the sea into all this, standing on the rim with
	# its pipe run heading out over the crust.
	for n in GenWorks._n(c, 1.0):
		var p := GenWorks._site(L, 5, 2, [], 40.0, 500, 0.5)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		if GenWorks._put(L, PropKind.PUMP_HOUSE, at, d.angle(), -99, 1.0) == null:
			continue
		GenWorks._record(c, &"brine_house", at, d, Vector2(4.0, 3.0))
		GenWorks._run(L, PropKind.PIPE, at + d * 2.5, d, rng.randi_range(4, 6), 2.0, -99, 0.2)
		GenWorks._about(L, PropKind.WATER_TANK, at, 1, 3.0, 5.0)
		GenWorks._about(L, PropKind.GRAVE, at, 2, 5.0, 8.0)
