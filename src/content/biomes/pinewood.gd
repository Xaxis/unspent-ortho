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
	d.anchors = [
		{"seq": 4, "u": 0.5, "v": 0.52, "band": &"middle", "slot": 1},
		{"seq": 8, "u": 0.5, "v": 0.33, "chance": 0.5},
	]
	d.temp_range = Vector2(0.25, 0.55)
	d.moist_range = Vector2(0.5, 0.85)
	d.adjacency = {&"moss": 0.4, &"snowfield": 0.2}
	d.relief = {
		&"base": 4.4, &"hills": 4.2, &"ridge": 2.2, &"terrace": 0.0, &"valley": 0.55,
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
	d.decor = {Ground.GRASS: [1.2, Decor.FERN, 30, Decor.BRACKEN, 26, Decor.TUFT_TALL, 14, Decor.MUSHROOM, 4, Decor.CONE, 6]}
	d.grass_colors = [P.SPRUCE[2], P.MOSS[2]]
	d.rock_color = P.SLATE[2].lerp(P.SPRUCE[2], 0.3)
	d.grade = Vector4(-0.45, 0.15, 0.05, 0.06)
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
	# The places worth the walk it holds (docs/VISION.md §3, src/core/landmarks):
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
