## Pinewood: tiered pines, deadfall, needle floor, and the exact squares the
## machines cut out of it. Dark under the canopy, and a curfew after dusk.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"pinewood"
	d.display_name = "pinewood"
	d.order = 2
	d.style_note = "Tall tight contours, upright strokes, shafts of light in the clearings."
	d.share = Vector2(0.11, 0.15)
	# ON HOME, ALWAYS (docs/DESIGN.md: home "holds the coast, the spawn village
	# and a full starting economy"): its timber and coal are the first days'
	# makings. `(1, 0)` is DEPENDENCY, as the coast's and the moss's are.
	d.spread = Vector2i(1, 0)
	d.anchors = [
		{"seq": 4, "u": 0.5, "v": 0.52, "band": &"middle", "slot": 1},
		{"seq": 8, "u": 0.5, "v": 0.33, "chance": 0.5},
	]
	d.temp_range = Vector2(0.25, 0.55)
	d.moist_range = Vector2(0.5, 0.85)
	d.adjacency = {&"moss": 0.4, &"snowfield": 0.2}
	d.relief = {
		&"base": 4.4, &"hills": 4.2, &"ridge": 2.2, &"near": 3.0, &"terrace": 0.0, &"valley": 0.55,
		&"rain": 1.2, &"temp": 0.36, &"moist": 0.66, &"cliff": 0.1,
	}
	d.hatch = Ink.UPRIGHT
	d.grounds = {
		# A clearing: the light gets in.
		Ground.GRASS: P.MOSS[3].lerp(P.SPRUCE[3], 0.45),
		Ground.ROCK: P.SLATE[2].lerp(P.SPRUCE[2], 0.25),
	}
	d.cliff_wash = P.SLATE[2].lerp(P.SPRUCE[2], 0.4)
	d.strata = GroundColors.STRATA_PINE
	d.plain_ground = Ground.NEEDLES
	d.bank_ground = Ground.NEEDLES
	d.village_ground = Ground.GRASS
	# Under the pines: fern, fronds arching out of one crown with their leaflets
	# hung down each side, rocking slowly; and bracken, taller and gone to rust,
	# held out flat and stiff.
	d.grasses = [
		GrassSpecies.make(&"fern", {"blades": 7, "height": Vector2(0.26, 0.42), "width": 0.012, "spread": 0.08,
			"reach": Vector2(0.9, 1.25), "curl": 0.7, "lay": 0.0, "leaflets": 10, "leaflet": 0.34,
			"root": P.SPRUCE[3], "tip": P.MOSS[4], "tip_pale": P.MOSS[5].lerp(P.SAND[4], 0.3), "stiff": 0.6, "flutter": 2}),
		GrassSpecies.make(&"bracken", {"blades": 4, "height": Vector2(0.38, 0.58), "width": 0.014, "spread": 0.07,
			"reach": Vector2(0.8, 1.1), "curl": 0.35, "lay": 0.1, "leaflets": 10, "leaflet": 0.34,
			"root": P.EARTH[3].lerp(P.MOSS[3], 0.3), "tip": P.RUST[3].lerp(P.SAND[3], 0.25), "tip_pale": P.SAND[4],
			"other": P.MOSS[3], "other_share": 0.3, "stiff": 0.75, "flutter": 1}),
	]
	d.decor = {
		Ground.GRASS: [1.2, Decor.GRASS_A, 30, Decor.GRASS_B, 26, Decor.TUFT_TALL, 14, Decor.MUSHROOM, 4, Decor.CONE, 6],
		Ground.NEEDLES: [0.8, Decor.CONE, 30, Decor.GRASS_B, 20, Decor.TWIG, 18, Decor.MUSHROOM, 6, Decor.GRASS_A, 8],
	}
	d.grass_colors = [P.SPRUCE[2], P.MOSS[2]]
	d.rock_color = P.SLATE[2].lerp(P.SPRUCE[2], 0.3)
	# Green-shadowed slate, resinous timber, and a needle mat over everything
	# left lying. People watch the cut from a platform up among the trunks.
	var dress := BiomeDressing.new()
	dress.stone = [P.SLATE[2].lerp(P.SPRUCE[2], 0.3), P.SLATE[1], P.MOSS[2].lerp(P.SPRUCE[3], 0.4)]
	dress.timber = [P.EARTH[2], P.EARTH[1]]
	dress.drift = [P.EARTH[2].lerp(P.EARTH[3], 0.4), P.EARTH[2]]
	dress.covers = &"needles"
	dress.shelter = &"blind"
	dress.sink = 0.08
	dress.lie = Vector2(0.05, 0.09)
	dress.berry = P.BLOOM[1]
	d.dressing = dress
	d.tree_tints = {
		&"leaf": [P.MOSS[1].lerp(P.SPRUCE[2], 0.5), P.MOSS[2], P.SPRUCE[3], P.MOSS[3]],
		&"scrub": [P.SPRUCE[1], P.SPRUCE[2], P.SPRUCE[2].lerp(P.SPRUCE[3], 0.5)],
	}
	d.grade = Vector4(-0.45, 0.15, 0.05, 0.06)
	# A closed canopy: less of the sky reaches this floor than reaches anywhere
	# else on the surface, which is the whole reason a wood is frightening at
	# night. It is the one landscape whose night is darker than the coast's, and
	# it earns it by having something overhead rather than by being told to.
	d.night_sky = 0.80
	d.wet = 0.2
	d.props = [PropKind.PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE, PropKind.BUSH, PropKind.REEDS,
		PropKind.BOULDER, PropKind.STONE_ORE, PropKind.COAL_ORE, PropKind.IRON_ORE, PropKind.SNOW_PINE,
		PropKind.GORSE, PropKind.DRIFTWOOD, PropKind.WRACK, PropKind.MUSSEL_ROCK]
	d.ore = [[PropKind.STONE_ORE, 0.035], [PropKind.COAL_ORE, 0.06], [PropKind.IRON_ORE, 0.07]]
	d.reed_chance = 0.14
	d.sites = {"tips": 2, "ruins": true, "summit": 3}
	d.pools = {"order": 3, "cell": 40, "chance": 0.35, "r_min": 2.4, "r_max": 4.2, "ground": Ground.RIVER}
	d.villages = 2
	d.village_order = 3
	d.village_names = ["Resin Hill", "Tallowmere", "Coombe Wood"]
	# Steady rain that drips through the canopy long after it stops.
	d.weather = [
		[Weather.CLEAR, 22, 0.0], [Weather.GREY, 26, 0.0], [Weather.RAIN, 28, 0.15],
		[Weather.FOG, 14, 0.0], [Weather.STORM, 10, 0.3],
	]
	d.mist = 0.5
	d.hazards = {&"dark": 0.4}
	d.roster = {
		&"warden": {"weight": 1.0, "hours": Vector2(20, 5)},
		&"sweeper": {"weight": 1.0, "hours": Vector2(5, 11)},
		&"dog.yard": {"weight": 1.0}, &"dog.feral": {"weight": 1.0},
		&"bull.field": {"weight": 1.0},
		&"gulls": {"weight": 1.0, "hours": Vector2(6, 20)},
	}
	# The places worth the walk it holds (docs/VISION.md, src/core/landmarks):
	# what a player crosses this landscape FOR. Its own file is the authority;
	# `Landmarks.problems` fails if a kind here does not name this landscape back.
	d.landmarks = [&"leaning_mast", &"firewatch", &"grown_hulk", &"cast_stones"]
	d.sound_bed = &"bed_pines"
	d.surface = _surface
	d.scatter = _scatter
	return d


static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.SHINGLE if gb > 0.0 else Ground.SAND
	if f & BiomeSurface.APRON != 0:
		return Ground.SCREE
	if f & BiomeSurface.BANK != 0 and gb > 0.25:
		return Ground.GRAVEL
	if rs < -0.75 and gb < -0.15:
		# Bog in the bottom of the wood.
		return Ground.MOSS
	if t.forest[i] > -0.15 - rs * 0.05:
		return Ground.NEEDLES
	if e >= 9.0 or rs > 1.3 or (t.other_def.id == &"snowfield" and t.blends[i] > 0.12):
		# Open tops, and the heath the wood thins into below the snow.
		return Ground.HEATH
	return Ground.GRASS


static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.GRASS:
		# A clearing seeds itself back: young pines, then scrub.
		var k := maxf(0.0, t.forest[i])
		if r < (0.03 + k * 0.1) * BiomeScatter.green_reach(t, i):
			return PropKind.PINE
		return PropKind.BUSH if r < 0.07 else BiomeScatter.NONE
	if g == Ground.HEATH:
		if t.own_def.id == &"snowfield" or t.other_def.id == &"snowfield":
			return PropKind.SNOW_PINE if r < 0.05 else (PropKind.BOULDER if r < 0.06 else BiomeScatter.NONE)
		return PropKind.PINE if r < 0.03 else (PropKind.BUSH if r < 0.06 else BiomeScatter.NONE)
	return BiomeScatter.PASS
