## Server Fields: cooling arrays to the horizon, drinking a river dry, humming at
## a pitch you feel in your teeth. The plan thinking, laid out on the ground.
## VISION §3 row 11.
##
## WHAT IT ARGUES WITH: this is the only landscape that is entirely THEIRS. The
## coast has villages, the slums has people, the bonelands has nobody but was
## nobody's to begin with — this was built, is maintained, and is still running.
## So it is the one place where the machines are not scavengers in a ruin but a
## working industry, and a player walking it is trespassing rather than exploring.
##
## It is also where the story's own argument lives: Elias's mind became the
## machines, and this is the nearest a player can walk to the thing that is doing
## the thinking. The ground is a floor. That is the whole look.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"server_fields"
	d.display_name = "the server fields"
	d.order = 14
	d.style_note = "Ruled rows to the horizon, cast floor, one violet strip repeated a thousand times."
	d.share = Vector2(0.05, 0.09)
	d.anchors = [{"seq": 13, "u": 0.46, "v": 0.3}]
	d.temp_range = Vector2(0.35, 0.7)
	d.moist_range = Vector2(0.3, 0.7)
	d.adjacency = {&"salt_flats": 0.2, &"scrapwood": 0.25, &"moss": 0.2}
	d.coastal = -0.3
	# Graded flat by machines that wanted it flat, with a fall on it so the
	# coolant runs the way they want it to run.
	d.relief = {
		&"base": 5.0, &"hills": 0.8, &"ridge": 1.0, &"terrace": 0.4, &"valley": 1.4,
		&"rain": 0.9, &"temp": 0.1, &"moist": 0.4, &"cliff": 0.25,
	}
	d.border_elevation = 0.4
	d.reach_out_high = Vector4(4.0, 0.05, 0.08, 0.28)
	d.reach_in_low = Vector3(4.5, 0.07, 0.3)
	d.hatch = Ink.NONE
	d.grounds = {
		Ground.FLOOR: P.ASH[3].lerp(P.SLATE[3], 0.4),
		Ground.ROAD: P.ASH[3].lerp(P.SLATE[2], 0.3),
		Ground.GRAVEL: P.STONE[3].lerp(P.ASH[3], 0.4),
		Ground.ROCK: P.SLATE[3],
		Ground.GRASS: P.MOSS[2].lerp(P.ASH[2], 0.45),
		Ground.MUD: P.EARTH[2].lerp(P.SLATE[2], 0.3),
		Ground.WATER: P.SLATE[2].lerp(P.SPRUCE[2], 0.3),
	}
	d.cliff_wash = P.SLATE[2].lerp(P.ASH[2], 0.35)
	d.strata = GroundColors.STRATA_SCRAP
	d.plain_ground = Ground.FLOOR
	d.bank_ground = Ground.GRAVEL
	d.pool_rim_ground = Ground.GRAVEL
	d.village_ground = Ground.GRAVEL
	d.decor = {Ground.GRASS: [0.3, Decor.TUFT, 14, Decor.SCRAP, 8]}
	d.grass_colors = [P.MOSS[2], P.ASH[3]]
	d.rock_color = P.SLATE[3]
	d.decor_tints = {&"fronds": [P.MOSS[2], P.ASH[2], P.SLATE[2]]}
	# Cast concrete, cable trays, and paint that is still the colour it was
	# specified as: the one place nothing has been allowed to weather.
	var dress := BiomeDressing.new()
	dress.stone = [P.SLATE[3], P.ASH[3], P.STONE[3]]
	dress.concrete = P.ASH[3]
	dress.walling = [P.ASH[2], P.SLATE[2], P.STONE[3], P.SLATE[3]]
	dress.sink = 0.03
	dress.lie = Vector2(0.0, 0.02)
	d.dressing = dress
	d.grade = Vector4(-0.05, -0.02, 0.06, -0.02)
	# Lit all night by things that never stop: the least dark place in the game,
	# and none of the light is anybody's to warm their hands at.
	d.night_sky = 0.8
	d.props = [PropKind.RELAY, PropKind.PIPE, PropKind.WATER_TANK, PropKind.INTAKE,
		PropKind.PYLON, PropKind.CONSOLE, PropKind.DEBRIS, PropKind.STACK, PropKind.FENCE]
	d.ore = [[PropKind.COPPER_ORE, 0.02], [PropKind.IRON_ORE, 0.016]]
	d.sites = {"tips": 3}
	d.beached_wrecks = false
	d.pools = {"order": 3, "cell": 34, "chance": 0.4, "r_min": 2.0, "r_max": 4.0, "ground": Ground.WATER}
	d.villages = 0
	d.village_order = 14
	d.village_names = []
	d.weather = [
		[Weather.CLEAR, 30, 0.0], [Weather.GREY, 28, 0.0], [Weather.RAIN, 22, 0.5],
		[Weather.FOG, 12, 0.0], [Weather.HEAT, 8, 0.0],
	]
	d.mist = 0.16
	# The heat is the arrays' own exhaust and the noise is electrical: the one
	# place a body is pressed by something that is simply RUNNING, not weather.
	d.hazards = {&"heat": 0.45, &"em": 0.6}
	d.roster = {
		&"clerk": {"weight": 1.0},
		&"watcher": {"weight": 1.0},
		&"warden": {"weight": 0.9},
		&"sweeper": {"weight": 0.7},
	}
	d.landmarks = [&"clerks_office", &"blinking_stack", &"poured_pillar", &"sump_pump"]
	d.sound_bed = &"bed_server_fields"
	d.surface = _surface
	d.scatter = _scatter
	return d


## A floor, a service road where the ground falls, and the strip of green nobody
## has got round to killing at the edges. One field decides it.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.GRAVEL
	if f & BiomeSurface.APRON != 0:
		return Ground.GRAVEL
	if f & BiomeSurface.BANK != 0:
		return Ground.MUD
	if e <= 3.2:
		return Ground.MUD
	return Ground.GRASS if gb > 0.72 else Ground.FLOOR


## Nothing is planted. What grows came up through a joint in the slab.
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.GRASS:
		return PropKind.BUSH if r < 0.01 else BiomeScatter.NONE
	return BiomeScatter.NONE
