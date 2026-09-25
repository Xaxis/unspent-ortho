## Salt Flats (docs/VISION.md, surface 7): a drained inland sea, floored in
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

## Everything this landscape is drawn in is taken down by this one number, and
## `grade` puts it back (see the note beside d.grade). Keeping the two in step is
## what stops the crust clipping the moment another landscape is in the frame:
## TONE * (1 - grade.x) is what the eye gets, and TONE alone is what a
## neighbour's lift is multiplied against. Mirrored by SALT_TOP in
## world.gdshader and the CRUST constants in src/models/props/salt.gd.
const TONE := 0.655


static func _w(c: Color) -> Color:
	return Color(c.r * TONE, c.g * TONE, c.b * TONE, c.a)


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"salt_flats"
	d.display_name = "salt flats"
	d.order = 6
	d.style_note = "Hard white glare on a cracked mosaic; the pans ruled straight across it."
	d.share = Vector2(0.065, 0.10)
	# No anchor: it goes where the island is hot, dry and far from the sea.
	d.temp_range = Vector2(0.45, 0.85)
	d.moist_range = Vector2(0.0, 0.35)
	d.site_count = Vector2i(1, 2)
	d.coastal = -0.8
	# It likes the dry country and keeps away from the fen and the wood.
	d.adjacency = {&"bonelands": 0.5, &"burning": 0.2, &"moss": -0.6, &"pinewood": -0.5}
	# A basin: low, flat, barely any relief, and rivers die in it.
	d.relief = {
		&"base": 1.6, &"hills": 0.5, &"ridge": 0.0, &"near": 0.3, &"terrace": 0.0, &"valley": 0.35,
		&"rain": 0.2, &"temp": 0.72, &"moist": 0.1, &"cliff": -0.3,
	}
	# The crust drifts out thin on the wind and stops, and little of what grows
	# outside gets in: a flat that wears the next country's ground is not a flat.
	d.reach_out_thin = 0.35
	d.reach_in_thin = 0.4
	d.hatch = Ink.CRACK
	# Everything the flat can show, named here. A ground left out of this table
	# falls through to the shared one, which is not scaled by TONE and so comes
	# in 1.5x brighter than everything around it — and PAN, which is 8% of the
	# landscape and the thing the machines built the whole place for, was falling
	# through. Its own bank, pool rim and village ground drew in another
	# landscape's colour.
	d.grounds = {
		Ground.SALT: _w(P.LINEN[5].lerp(P.SAND[5], 0.2)),
		# A pan the brine drew back from: mineral silt, damp and stained, a clear
		# step under the crust so the bunded rectangles read AS rectangles from
		# above — but still pale, because it is a dry floor and not mud, and
		# because it is 8% of this landscape and the flat has to stay the
		# brightest ground in the game.
		Ground.PAN: _w(P.LINEN[4].lerp(P.STONE[4], 0.3).lerp(P.RUST[2], 0.1)),
		Ground.ROAD: _w(P.LINEN[3].lerp(P.SAND[3], 0.4)),
		Ground.SAND: _w(P.LINEN[4].lerp(P.SAND[4], 0.5)),
		Ground.SHINGLE: _w(P.LINEN[3].lerp(P.STONE[3], 0.4)),
		Ground.GRAVEL: _w(P.LINEN[3].lerp(P.STONE[3], 0.35)),
		# What little grass survives on the rim is bleached to straw.
		Ground.GRASS: _w(P.SAND[4].lerp(P.LINEN[4], 0.45)),
		Ground.HEATH: _w(P.SAND[3].lerp(P.EARTH[3], 0.4)),
		Ground.ROCK: _w(P.LINEN[3].lerp(P.STONE[2], 0.3)),
		Ground.SCREE: _w(P.LINEN[2].lerp(P.STONE[3], 0.4)),
		# Bleed over a border: nothing green keeps its colour out here.
		Ground.MOSS: _w(P.MOSS[2].lerp(P.LINEN[3], 0.45)),
		Ground.NEEDLES: _w(P.EARTH[2].lerp(P.LINEN[3], 0.4)),
		Ground.MUD: _w(P.EARTH[2].lerp(P.LINEN[2], 0.35)),
		Ground.PEAT: _w(P.EARTH[1].lerp(P.LINEN[2], 0.3)),
		Ground.SWARF: _w(P.LINEN[2].lerp(P.SLATE[2], 0.3).lerp(P.RUST[1], 0.18)),
		Ground.BONE: _w(P.LINEN[4].lerp(P.STONE[4], 0.2)),
		Ground.LIMESTONE: _w(P.LINEN[4].lerp(P.STONE[4], 0.2)),
		# Frost on the crust before dawn. The shared snow is the page itself and
		# on the one landscape with no headroom left it would be the brightest
		# thing in the frame by seventy-five steps.
		Ground.SNOW: _w(P.RIME[4].lerp(P.LINEN[4], 0.5)),
		Ground.ICE: _w(P.RIME[3].lerp(P.SLATE[3], 0.3)),
	}
	d.cliff_wash = _w(P.LINEN[4].lerp(P.SAND[4], 0.3))
	d.strata = GroundColors.STRATA_SALT
	d.plain_ground = Ground.SALT
	d.bank_ground = Ground.PAN
	d.pool_rim_ground = Ground.PAN
	d.village_ground = Ground.PAN
	d.village_square_ground = Ground.GRAVEL
	d.beached_wrecks = false
	d.decor = {
		Ground.SALT: [0.4, Decor.SALT_PLATE, 54, Decor.PEBBLES, 8, Decor.BOLT, 3, Decor.SCRAP, 3, Decor.GRASS_A, 22],
		Ground.PAN: [0.35, Decor.SALT_PLATE, 18, Decor.PEBBLES, 20, Decor.STONE, 10, Decor.CAN, 4, Decor.WIRE, 4, Decor.GRASS_A, 26],
		Ground.GRASS: [0.6, Decor.GRASS_A, 30, Decor.THISTLE, 12, Decor.STONE, 12, Decor.BONE, 4],
	}
	# Straw: a few stiff dead stems at a time, bleached to the pan, broken short
	# and ticking in the wind rather than swaying.
	d.grasses = [
		GrassSpecies.make(&"straw", {"blades": 18, "height": Vector2(0.14, 0.38), "width": 0.02, "spread": 0.22,
			"reach": Vector2(0.1, 0.45), "curl": 0.05, "lay": 0.55, "root": _w(P.EARTH[3].lerp(P.SAND[3], 0.5)), "tip": _w(P.LINEN[3]),
			"stiff": 0.9, "flutter": 6, "casts": true}),
	]
	d.grass_colors = [_w(P.SAND[4]), _w(P.LINEN[4])]
	d.rock_color = _w(P.LINEN[3])
	d.hard_rock = true
	# A speck of small life is a lit face with nothing shading it, so it stays a
	# step under the ground it stands on (src/models/props/salt.gd, CRUST_UP).
	d.decor_tints = {&"bloom": [_w(P.LINEN[3]), _w(P.SAND[4]), _w(P.LINEN[4])], &"spoil": [_w(P.LINEN[3])]}
	# Whatever holds on at the rim is bleached and half dead.
	d.tree_tints = {
		&"leaf": [_w(P.MOSS[4].lerp(P.LINEN[4], 0.5)), _w(P.MOSS[4].lerp(P.SAND[4], 0.4)), _w(P.LINEN[4]), _w(P.SAND[4])],
		&"trunk": [_w(P.LINEN[2])],
		&"scrub": [_w(P.MOSS[4].lerp(P.SAND[4], 0.5)), _w(P.SAND[4]), _w(P.LINEN[3])],
	}
	# Brine takes everything: paint goes chalky, rubber perishes, and what the
	# wind banks against a thing is crust rather than sand. The stone, the drift
	# and the sods are its own washes because it declares them; this says only
	# what the flat DOES to a thing left standing on it.
	var dress := BiomeDressing.new()
	dress.pale = [_w(P.LINEN[5]), _w(P.LINEN[4]), _w(P.LINEN[3])]
	dress.bleach = _w(P.LINEN[4])
	dress.facets = 5
	# Nothing grows to build with, so a shelter here is sawn crust under tin.
	dress.shelter = &"lean_to"
	dress.sink = 0.1
	d.dressing = dress
	# Where the flat's brightness lives, and the whole of art review 1. The grade
	# is ONE value for a frame: SkyLight averages every landscape in view and
	# sky.gdshaderinc scales the graded colour by (1 - grade.x), a GAIN. So a
	# landscape that keeps its brightness in its WASHES has that brightness
	# multiplied by whatever a dark neighbour lifts by — the coast lifts 1.55x
	# against the flat's old 1.12x — and the crust came back across the border
	# thirty luminance steps brighter than on the flat, clipped to paper: no
	# wash, no second wash, no shade band, no plate, no hatch, no ink (18.6% of
	# shots/tour/biomes/15-coast-salt-flats.png was pure white).
	#
	# So the brightness moved into the LIFT, which is the safe place for it: this
	# is now the largest lift in the registry, and an average with any neighbour
	# can only bring it DOWN. The washes are the same drawing as before, taken
	# down by TONE to pay for it.
	#
	# The review asked whether this could go up another step, because the flat had
	# stopped being the brightest ground in the game and that is the one thing its
	# own file claims. It cannot, and the tests say so before a shot does: -0.66
	# fails BOTH `tests/biome/test_registry.gd` (the sky's own clamp stops at
	# -0.6) and `tests/biome/test_salt_headroom.gd` (SALT_TOP under the worst
	# pairing reaches 1.015, and a rim at the page is a white line with nothing in
	# it). The lift is already at its ceiling. The only lever left is TONE and its
	# mirror SALT_TOP, which lives in another package's shader — and the crust
	# already measures 194.7 against the snowfield's 191.6, so it may not be
	# needed at all. Left for whoever owns that seam.
	d.grade = Vector4(-0.58, 0.08, -0.06, 0.2)
	# A white pan under nothing at all. It throws the night sky back harder than
	# the snow does, and there is not a thing on it to cast a shadow.
	d.night_sky = 1.40
	# A warm cast taken out of the blue rather than added to the red: a light
	# tint over 1 is one more gain on a landscape with no headroom left.
	d.light_tint = Color(1.0, 0.985, 0.95)
	# Brine, not water: what is left after the sun took the rest is dense, green
	# and heavy, and it does not break white. A chart-blue pool with a paper-white
	# swash on a landscape with no headroom is two clipped things at once.
	d.water_wash = Color(0.112, 0.250, 0.264, 0.92)
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
	# Its keeper: the rake that made the pans and still goes round them
	# (src/core/sentinel/designs/pan_rake.gd, docs/VISION.md).
	d.sentinel = &"pan_rake"
	# The places worth the walk it holds (docs/VISION.md, src/core/landmarks):
	# what a player crosses this landscape FOR. Its own file is the authority;
	# `Landmarks.problems` fails if a kind here does not name this landscape back.
	d.landmarks = [&"cast_stones", &"evaporator", &"clerks_office"]
	d.sound_bed = &"bed_bones"
	d.music_motif = &"bonelands"
	d.surface = _surface
	d.scatter = _scatter
	# What this landscape holds of what happened to it (docs/VISION.md).
	GenWorks.register(&"salt_flats", {
		"host": load("res://src/content/biomes/salt_flats.gd"),
		"works": &"_works",
		# Shade is the whole answer to glare on the flat (Hazards._answer_shift
		# takes 0.85 of it under a roof), and there was one weight of shelter in
		# twenty-four across a whole region: nothing to cross to (playtest 3).
		"vignettes": [[5, &"shelter"], [4, &"survey_posts"], [4, &"debris_field"], [3, &"tipped_signs"],
			[3, &"wreck"], [2, &"grave_cluster"], [2, &"wreck_parts"], [1, &"barricade"]],
		# Nothing to drill in a dry pan: where the survey crosses the flat it
		# leaves its posts and a sign, and goes on.
		"survey": [[0.45, &"sign_beside"]],
	})
	# The web's day contrast here (BiomeDef.web_contrast): inferred from the snowfield: a bright floor.
	d.web_contrast = 1.05
	return d


## Crust almost everywhere; the pans are where the ground lies low and damp, and
## the rim of the basin comes up through it as gravel and bleached grass.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.SHINGLE if gb > 0.1 else Ground.SAND
	if f & BiomeSurface.APRON != 0:
		return Ground.SCREE
	if f & BiomeSurface.BANK != 0:
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


static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.SALT:
		var k := maxf(0.0, t.clump[i])
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
