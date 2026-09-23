## Scrapwood (docs/VISION.md, surface 9): a wood that grew back through the
## machines that died in it. Something was fought here, or dumped here, and the
## trees took it: trunks closed over frames, plate still hanging in the forks,
## the floor a mulch of leaves over rust grit and cut swarf.
##
## The mood is green-brown gloom with a metal taste. The field still in the
## dead iron draws the filings into combed arcs and stands shards on end, so the
## ground is patterned by something nobody switched off. Neon has no business
## here; the only machine light is the odd strip on something half swallowed.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"scrapwood"
	d.display_name = "scrapwood"
	d.order = 7
	d.style_note = "Upright strokes over rust: the hand's crowns closed over the ruler's frames."
	d.share = Vector2(0.055, 0.085)
	# No anchor: it takes the temperate middle, beside whatever is already wooded.
	d.temp_range = Vector2(0.3, 0.7)
	d.moist_range = Vector2(0.4, 0.9)
	d.site_count = Vector2i(1, 2)
	d.adjacency = {&"pinewood": 0.5, &"moss": 0.3, &"coast": 0.2, &"burning": -0.5, &"snowfield": -0.4}
	d.relief = {
		&"base": 3.4, &"hills": 2.6, &"ridge": 0.8, &"near": 4.0, &"terrace": 0.0, &"valley": 0.5,
		&"rain": 1.15, &"temp": 0.5, &"moist": 0.72, &"cliff": 0.0,
	}
	d.hatch = Ink.UPRIGHT
	# A landscape only gets its own colour for the grounds it NAMES here;
	# everything else falls through to the shared table, which is written for a
	# coast and knows nothing about this place. Sixty per cent of the scrapwood
	# is SWARF — its own plain_ground, the floor the file is named after — and it
	# was falling through, coming out a warm brown-mauve and then multiplied by
	# this landscape's 1.52x lift. That, not the trees, is why the wood read as
	# an ordinary wood on bare earth (playtest 6). So every ground the wood can
	# show is named, down to the ones that only bleed in over a border.
	d.grounds = {
		# Leaf mulch over rust grit: dark olive, with the earth in it and none of
		# the rust, because the rust belongs to the FILINGS and the flecks lying
		# on it and a wash carrying it too went grey. Green-dominant by eleven
		# steps and darker than the floor it replaced, which is the gloom.
		Ground.SWARF: P.MOSS[2].lerp(P.MOSS[1], 0.4).lerp(P.EARTH[1], 0.26),
		Ground.GRASS: P.MOSS[3].lerp(P.RUST[2], 0.2),
		Ground.HEATH: P.EARTH[2].lerp(P.RUST[1], 0.35),
		Ground.NEEDLES: P.EARTH[2].lerp(P.RUST[2], 0.3),
		Ground.MOSS: P.MOSS[2].lerp(P.SPRUCE[2], 0.5),
		Ground.MUD: P.EARTH[1].lerp(P.RUST[1], 0.3),
		Ground.ROCK: P.SLATE[2].lerp(P.RUST[1], 0.25),
		Ground.SCREE: P.SLATE[2].lerp(P.STONE[2], 0.4),
		Ground.GRAVEL: P.STONE[2].lerp(P.RUST[2], 0.3),
		# Peat under the bottoms: what the yard leached, gone to black.
		Ground.PEAT: P.MOSS[1].lerp(P.EARTH[1], 0.4).lerp(P.RUST[0], 0.2),
		# Stone the wood has had time to stain. The shared shingle is a bright
		# sea-sorted grey (lum 119) and it shouted off the floor of a dark wood.
		Ground.SHINGLE: P.SLATE[2].lerp(P.STONE[2], 0.45).lerp(P.RUST[1], 0.18),
		Ground.SAND: P.EARTH[2].lerp(P.SLATE[2], 0.3).lerp(P.RUST[2], 0.2),
		# The lanes the machines cut: grit pressed flat, already going green
		# at the edges. The shared road is a warm tan and read as desert.
		Ground.ROAD: P.SLATE[1].lerp(P.EARTH[2], 0.45).lerp(P.RUST[1], 0.2),
		# Bleed from the dry country over a border: a crust that has lain under
		# this canopy is not the crust out on the flat.
		Ground.SALT: P.LINEN[2].lerp(P.SLATE[2], 0.4).lerp(P.MOSS[2], 0.2),
		Ground.PAN: P.LINEN[1].lerp(P.SLATE[2], 0.35).lerp(P.RUST[1], 0.15),
		Ground.BONE: P.LINEN[2].lerp(P.SLATE[2], 0.35),
		Ground.LIMESTONE: P.LINEN[2].lerp(P.SLATE[2], 0.35),
		# Snow does not lie clean under a wood full of rust.
		Ground.SNOW: P.RIME[3].lerp(P.SLATE[2], 0.35).lerp(P.RUST[1], 0.12),
		Ground.ICE: P.RIME[2].lerp(P.SLATE[2], 0.3),
	}
	d.cliff_wash = P.EARTH[1].lerp(P.RUST[1], 0.35)
	d.strata = GroundColors.STRATA_SCRAP
	d.plain_ground = Ground.SWARF
	d.bank_ground = Ground.MUD
	d.pool_rim_ground = Ground.MUD
	d.village_ground = Ground.GRASS
	d.decor = {
		Ground.SWARF: [0.85, Decor.FILINGS, 40, Decor.TWIG, 18, Decor.FERN, 14, Decor.MUSHROOM, 8, Decor.BOLT, 6, Decor.SCRAP, 6, Decor.WIRE, 4],
		Ground.GRASS: [1.0, Decor.FERN, 28, Decor.BRACKEN, 22, Decor.TUFT_TALL, 16, Decor.FILINGS, 12, Decor.SCRAP, 4],
		Ground.NEEDLES: [0.9, Decor.CONE, 22, Decor.BRACKEN, 20, Decor.FILINGS, 16, Decor.MUSHROOM, 10, Decor.SCRAP, 5],
	}
	d.grass_colors = [P.SPRUCE[2], P.MOSS[3]]
	d.rock_color = P.SLATE[2].lerp(P.RUST[1], 0.3)
	d.decor_tints = {&"bloom": [P.RUST[3], P.BLOOM[2], P.RUST[4]], &"twig": [P.EARTH[1]], &"spoil": [P.RUST[2]]}
	# Leaves that grew in a metal taste: darker and greyer than any other wood,
	# over bark stained by what runs off the frames they took.
	d.tree_tints = {
		&"leaf": [P.SPRUCE[2].lerp(P.MOSS[2], 0.4), P.MOSS[2], P.SPRUCE[3].lerp(P.MOSS[3], 0.5), P.MOSS[2].lerp(P.SPRUCE[2], 0.6)],
		&"trunk": [P.EARTH[2].lerp(P.RUST[1], 0.3)],
		&"scrub": [P.SPRUCE[2], P.MOSS[2].lerp(P.RUST[1], 0.25), P.SPRUCE[2].lerp(P.MOSS[3], 0.4)],
		&"needle": [P.SPRUCE[2].lerp(P.RUST[1], 0.2), P.SPRUCE[3], P.SPRUCE[3].lerp(P.MOSS[3], 0.4)],
		&"dead": [P.EARTH[2].lerp(P.RUST[1], 0.4), P.RUST[1]],
	}
	# A wood grown up through a scrapyard: leaf litter with filings in it, timber
	# stained by what runs off the frames, and a mat of it over anything left.
	var dress := BiomeDressing.new()
	dress.stone = [P.SLATE[2].lerp(P.RUST[1], 0.3), P.SLATE[1], P.MOSS[3].lerp(P.RUST[1], 0.25)]
	dress.timber = [P.EARTH[2].lerp(P.RUST[1], 0.25), P.EARTH[1]]
	dress.covers = &"needles"
	# A platform up among the frames, out of the water that runs off them.
	dress.shelter = &"blind"
	dress.sink = 0.1
	d.dressing = dress
	# Under a closed canopy over dark ground: dimmer than the pines, and the
	# darkness term goes as negative as the moss's so noon still reads as noon.
	d.grade = Vector4(-0.52, 0.12, 0.0, 0.08)
	# A canopy, but a broken one: more sky gets through here than through the
	# pines and less than over open ground.
	d.night_sky = 0.90
	d.wet = 0.25
	# The water here is dead. Everything the yard leached is in it, and it lies
	# under a closed canopy: an oily green-black that gives nothing back. It was
	# the shared chart blue, a slate pond.
	#
	# The number first written here, 3.7x the moss's water, was wrong, and the
	# review that caught it was right: it compared the wood's water against the
	# moss's water by way of a pale mass in the wood's heart frame that is not
	# water at all but the SNOWFIELD across the border (380 of the 2829 tiles a
	# zoom-12 frame holds at `place scrapwood`, seed 7). Measured at one named
	# coordinate the water itself went from a slate blue to a dead olive-black;
	# the numbers are in the commit. The snowfield is another landscape, drawn
	# correctly in its own colours, and nothing here reaches it.
	#
	# It is a WASH, though, not a hole: taken all the way to the wash at full
	# strength the chart's whole value range collapsed into 15..63 and a river
	# read as a black ribbon cut out of the land, which breaks Law 2 the other
	# way round. Kept a step up and a shade short of the whole, the soundings,
	# the marbling and the broken white of a fall all still draw, over 20..138.
	d.water_wash = Color(0.125, 0.140, 0.110, 0.86)
	d.props = [PropKind.SCRAP_TREE, PropKind.MAGNET_HEAP, PropKind.BROADLEAF, PropKind.PINE,
		PropKind.DEAD_TREE, PropKind.BUSH, PropKind.BOULDER, PropKind.REEDS,
		PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.COPPER_ORE, PropKind.COAL_ORE, PropKind.DRIFTWOOD]
	# The seams here are what the machines left, not what the rock holds: iron
	# and copper come up easily, stone hardly at all.
	d.ore = [[PropKind.IRON_ORE, 0.05], [PropKind.COPPER_ORE, 0.08], [PropKind.STONE_ORE, 0.09],
		[PropKind.COAL_ORE, 0.1]]
	d.reed_chance = 0.12
	d.sites = {"tips": 4, "ruins": true, "summit": 0}
	d.pools = {"order": 5, "cell": 34, "chance": 0.45, "r_min": 2.4, "r_max": 4.0, "ground": Ground.BLACKWATER}
	d.villages = 1
	d.village_names = ["Rivetgate", "Coil End", "Ironroot"]
	d.village_order = 2
	# Rain that drips off metal for hours, mist caught under the canopy, and the
	# haze that hangs where the rust is thickest.
	d.weather = [
		[Weather.CLEAR, 18, 0.0], [Weather.GREY, 26, 0.0], [Weather.RAIN, 22, 0.2],
		[Weather.DRIZZLE, 14, 0.0], [Weather.FOG, 12, 0.0], [Weather.STORM, 8, 0.35],
	]
	d.mist = 0.6
	d.hazards = {&"magnetism": 0.6, &"collapse": 0.4, &"toxins": 0.2, &"dark": 0.3}
	# Recyclers take the dead and the broken; magnet swarms come off the heaps.
	# Until the content milestone draws them, the sweepers and the dredgers that
	# already clear ground answer here.
	var floor_g := ["swarf", "grass", "needles", "heath", "gravel", "mud", "road", "moss"]
	d.roster = {
		&"sweeper": {"weight": 1.2, "grounds": floor_g},
		&"warden": {"weight": 0.8, "hours": Vector2(20, 5), "grounds": floor_g},
		&"watcher": {"weight": 0.8, "grounds": floor_g},
		&"flock": {"weight": 0.8, "hours": Vector2(7, 18), "grounds": floor_g},
		&"dog.feral": {"weight": 1.0, "grounds": floor_g},
	}
	d.sentinel = &""
	# The places worth the walk it holds (docs/VISION.md, src/core/landmarks):
	# what a player crosses this landscape FOR. Its own file is the authority;
	# `Landmarks.problems` fails if a kind here does not name this landscape back.
	d.landmarks = [&"firewatch", &"grown_hulk", &"clerks_office", &"blinking_stack"]
	d.sound_bed = &"bed_pines"
	d.music_motif = &"pinewood"
	d.surface = _surface
	d.scatter = _scatter
	# What this landscape holds of what happened to it (docs/VISION.md).
	GenWorks.register(&"scrapwood", {
		"host": load("res://src/content/biomes/scrapwood.gd"),
		"works": &"_works",
		"vignettes": [[5, &"wreck_parts"], [4, &"debris_field"], [4, &"stump_rows"], [3, &"wreck"],
			[3, &"grave_cluster"], [2, &"fence_corner"], [2, &"tipped_signs"], [1, &"shelter"]],
		"survey": [[0.8, &"lane"]],
	})
	return d


## Swarf under the canopy, mulch in the hollows, and the clearings the machines
## cut and never came back to.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.SHINGLE if gb > 0.0 else Ground.SAND
	if f & BiomeSurface.APRON != 0:
		return Ground.SCREE
	if f & BiomeSurface.BANK != 0:
		return Ground.MUD
	if rs < -0.8 and gb < -0.2:
		# The bottoms never drain: a black mat of bog moss over what leached out
		# of the yard. The standing water itself is `pools` (BLACKWATER), and
		# what colour it takes is `water_wash`.
		return Ground.MOSS
	# The canopy is closed almost everywhere: swarf is the floor of this wood,
	# and a clearing has to be a real one before the grass gets in.
	if t.forest[i] > -0.5 - rs * 0.05:
		return Ground.SWARF
	if e >= 8.5 or rs > 1.4:
		# Open tops where the wood never took: bare grit over the old heaps.
		return Ground.HEATH
	return Ground.GRASS


static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.SWARF:
		var k := maxf(0.0, t.forest[i] + 0.15)
		if r < 0.11 + k * 0.26:
			return PropKind.SCRAP_TREE
		if r < 0.15 + k * 0.28:
			return PropKind.BROADLEAF
		if r < 0.17 + k * 0.28:
			return PropKind.DEAD_TREE
		if r > 0.4 and r < 0.418:
			# Where the field is strongest the filings stand up on their own.
			return PropKind.MAGNET_HEAP
		return PropKind.BUSH if r < 0.2 + k * 0.28 else BiomeScatter.NONE
	if g == Ground.GRASS:
		var k := maxf(0.0, t.forest[i])
		if r < 0.02 + k * 0.08:
			return PropKind.SCRAP_TREE
		if r < 0.05:
			return PropKind.BUSH
		return PropKind.MAGNET_HEAP if r > 0.3 and r < 0.306 else BiomeScatter.NONE
	if g == Ground.HEATH:
		if r < 0.025:
			return PropKind.BUSH
		return PropKind.MAGNET_HEAP if r > 0.2 and r < 0.209 else BiomeScatter.NONE
	return BiomeScatter.PASS


## The machines' works here (GenWorks.register, called from make()): the yard
## they dumped in, and the relay line the wood is closing over. Both are ruled;
## both are being taken back by something that is not in a hurry.
static func _works(L: Object) -> void:
	var c: GenContext = L.c
	var rng: RandomNumberGenerator = L.rng
	var d: Vector2 = L.d
	var nrm: Vector2 = L.nrm
	var floor_g: Array = [Ground.SWARF, Ground.GRASS, Ground.NEEDLES, Ground.GRAVEL, Ground.HEATH]
	# Breaking yards: a fenced square of wreckage with a conveyor running into
	# the trees, the ground under it cut and never grown back the same.
	for n in GenWorks._n(c, 2.0):
		var p := GenWorks._site(L, 7, 1, floor_g, 32.0, 700, 0.4)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		var half := Vector2(rng.randf_range(6.5, 8.5), rng.randf_range(5.0, 6.5))
		GenWorks._record(c, &"breaking_yard", at, d, half, GenWorks.CUT)
		for sy: float in [-1.0, 1.0]:
			GenWorks._run(L, PropKind.FENCE, at + nrm * half.y * sy - d * half.x, d, 6, 2.6, -99, 0.25)
		# The gate they weighed loads at: a barricade across the way in, with
		# the yard's sign still bolted to it.
		GenWorks._put(L, PropKind.BARRICADE, at - d * (half.x + 0.5), nrm.angle(), -99, 0.6)
		for gy in range(-1, 2):
			for gx in range(-2, 3):
				if rng.randf() < 0.4:
					continue
				var q := at + d * gx * 3.2 + nrm * gy * 3.4
				GenWorks._put(L, PropKind.WRECKAGE, q, rng.randf() * TAU, -99, 0.4)
		# The belt was lifted for the metal the week after it stopped: what runs
		# out of the yard is the line of it lying in the leaves.
		GenWorks._run(L, PropKind.WRECKAGE, at + d * (half.x + 0.5), d, rng.randi_range(4, 6), 2.5, -99, 0.3)
		GenWorks._about(L, PropKind.DEBRIS, at, 3, 1.0, half.x)
		GenWorks._about(L, PropKind.MAGNET_HEAP, at, 2, half.y, half.x + 3.0)
		GenWorks._put(L, PropKind.SIGN, at - d * (half.x + 2.0), (-d).angle(), -99, 0.2)
	# A relay corridor the wood has nearly closed: masts on the bearing, exact,
	# with the crowns leaning in over them and a heap under every second one.
	for n in GenWorks._n(c, 1.0):
		var p := GenWorks._site(L, 4, 2, [], 36.0, 500, 0.5)
		if p.x < 0:
			continue
		var at := Vector2(p) + Vector2(0.5, 0.5)
		# Two masts still stand on the line; the rest came down years ago and
		# the wood grew through where they fell.
		var masts := GenWorks._run(L, PropKind.RELAY, at, d, 2, 9.0, -99, 0.0)
		if masts.is_empty():
			continue
		GenWorks._record(c, &"closing_corridor", at, d, Vector2(18.0, 3.0), GenWorks.CUT)
		for i in masts.size():
			# Clear of the mast's own feet. At 1.6-3.0 tiles the heap stood inside
			# the pylon's legs, so the one prop that says what this wood IS could
			# never be the subject of a frame and was never the thing in reach.
			GenWorks._about(L, PropKind.MAGNET_HEAP, c.w.props[masts[i]].pos, 2, 4.0, 7.0)
		# Where the fallen ones lie, on the same line.
		GenWorks._run(L, PropKind.WRECKAGE, at + d * 4.5, d, 4, 9.0, -99, 0.15)
		GenWorks._about(L, PropKind.SCRAP_TREE, at, 3, 3.0, 7.0)
