## Machine City: built by machines, for machines. Nothing here is a compromise
## with a body — no doors at a person's height, no stairs, no light where light
## is not needed, no room that is not exactly the size of what it holds. Owner's
## own, 2026-09-18: "a completely artificially made machine mega city perfectly
## organized efficient and clean meant entirely for machines".
##
## WHAT IT ARGUES WITH, and it is the third city on purpose. The Slums is a city
## PEOPLE still live in; the Ruined Metropolis is a city that died with people in
## it; this one was never for people at all, and that is the whole difference.
## Three cities that argue about who a city is FOR rather than three cities in
## different colours.
##
## SO ITS HORROR IS THAT NOTHING IS WRONG WITH IT. Everywhere else in this game
## the machines are patching, scavenging and half-broken; here they got what they
## wanted. The ground is level because they levelled it, the rows are exact
## because nothing needed them otherwise, and a player walking it is the only
## thing out of place — which is the one landscape where being trespasser is the
## feeling rather than a rule.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"machine_city"
	d.display_name = "the machine city"
	d.order = 18
	d.style_note = "Exact, level, clean. No warmth anywhere and not one thing out of line."
	d.share = Vector2(0.05, 0.09)
	d.anchors = [{"seq": 18, "u": 0.3, "v": 0.24}]
	d.temp_range = Vector2(0.25, 0.7)
	d.moist_range = Vector2(0.15, 0.55)
	d.adjacency = {&"server_fields": 0.4, &"salt_flats": 0.2, &"bonelands": 0.2}
	d.coastal = -0.4
	# LEVELLED, and that is the point: the lowest relief of any landscape here,
	# because they graded it flat and nothing has been allowed to move since.
	d.relief = {
		&"base": 6.0, &"hills": 0.4, &"ridge": 0.5, &"near": 0.5, &"terrace": 0.2, &"valley": 0.6,
		&"rain": 0.5, &"temp": 0.08, &"moist": 0.2, &"cliff": 0.15,
	}
	d.border_elevation = 0.3
	d.reach_out_high = Vector4(3.0, 0.04, 0.05, 0.2)
	d.reach_in_low = Vector3(3.5, 0.05, 0.22)
	d.hatch = Ink.NONE
	d.grounds = {
		Ground.FLOOR: P.SLATE[1].lerp(P.ASH[1], 0.3),
		Ground.ROAD: P.SLATE[1].lerp(P.INK[3], 0.35),
		Ground.GRAVEL: P.ASH[2].lerp(P.SLATE[2], 0.45),
		Ground.ROCK: P.SLATE[3],
		Ground.SWARF: P.SLATE[2].lerp(P.RUST[2], 0.2),
	}
	# Grounds this place never lays, named anyway: anything left unnamed falls
	# through to the shared table, which is the COAST's and is far brighter than
	# here, so it would arrive as the loudest object in the frame. Each takes this
	# landscape's own gravel, because they only have to be in key.
	for g: int in [Ground.BONE, Ground.ICE, Ground.LIMESTONE, Ground.PAN, Ground.SALT, Ground.SAND, Ground.SHINGLE, Ground.SNOW]:
		d.grounds[g] = d.grounds[Ground.GRAVEL]
	d.cliff_wash = P.SLATE[2]
	d.strata = GroundColors.STRATA_SCRAP
	d.plain_ground = Ground.FLOOR
	d.bank_ground = Ground.GRAVEL
	d.pool_rim_ground = Ground.GRAVEL
	d.village_ground = Ground.FLOOR
	# NOTHING GROWS AND NOTHING IS LEFT LYING. The decor table is deliberately
	# empty: every other landscape has tufts and crottle and drift, and the whole
	# character of this one is that it has been swept.
	d.decor = {}
	d.grass_colors = [P.SLATE[3], P.ASH[3]]
	d.rock_color = P.SLATE[3]
	d.decor_tints = {&"fronds": [P.SLATE[2], P.ASH[2], P.STONE[2]]}
	var dress := BiomeDressing.new()
	dress.stone = [P.SLATE[3], P.ASH[3], P.SLATE[2]]
	dress.concrete = P.ASH[3].lerp(P.SLATE[3], 0.4)
	dress.walling = [P.SLATE[2], P.ASH[2], P.SLATE[3], P.STONE[3]]
	# Nothing weathers here, because nothing is left long enough to.
	dress.sink = 0.0
	dress.lie = Vector2(0.0, 0.0)
	d.dressing = dress
	# It stands up, and it stands up in RANKS. `block` for the same reason the
	# other two cities take it, and `apart` tighter than either: there is no
	# street here, only clearance.
	# THREE SHAPES, MANY TIMES OVER, AND THAT IS THE WHOLE LOOK. "Perfectly
	# organized, efficient and clean" is not more variety than a human city, it is
	# far less: nothing here is an arcade, because a covered walk is for somebody
	# on foot; nothing is a shell, because nothing has been allowed to fall; and
	# nothing is a spire, because a spire is a gesture and the plan makes none.
	# What is left repeats on a short pitch, which is what reads as engineered.
	d.built = BiomeForms.new()
	d.built.stock = [&"tower", &"stack", &"block"] as Array[StringName]
	d.built.plan = &"block"
	d.built.apart = BiomeForms.ROW_APART
	d.built.buildings = Vector2i(26, 38)
	d.built.repeat_apart = 6.0
	d.grade = Vector4(-0.01, -0.04, 0.06, -0.05)
	# Lit exactly as much as the work needs and no more, all night, every night —
	# so it is neither dark nor warm, which is worse than either.
	d.night_sky = 0.7
	d.props = [PropKind.RELAY, PropKind.PYLON, PropKind.CONSOLE, PropKind.STACK,
		PropKind.CHECKPOINT, PropKind.FENCE, PropKind.PLATFORM, PropKind.WATER_TANK]
	d.ore = [[PropKind.COPPER_ORE, 0.024], [PropKind.IRON_ORE, 0.02]]
	d.sites = {"tips": 1}
	# The runs the plant was laid out around, put down ruled on the survey bearing
	# rather than dealt loose by the scatter (`GenWorks.RUNS`): conveyor first,
	# because that is what a works city moves things on.
	GenWorks.register(&"machine_city", {
		"vignettes": [[5, &"conveyor_run"], [4, &"pipe_run"], [3, &"debris_field"], [3, &"wreck_parts"],
			[2, &"survey_posts"], [2, &"tipped_signs"], [1, &"barricade"]],
		"survey": [[0.5, &"pipe_line"]],
	})
	d.beached_wrecks = false
	d.pools = {"order": 4, "cell": 48, "chance": 0.2, "r_min": 1.6, "r_max": 2.8, "ground": Ground.WATER}
	# NOBODY LIVES HERE. Not a village, not a shack, not one fire — the only
	# landscape in the game that declares none, and the reason is the whole idea.
	d.villages = 1
	d.village_order = 18
	d.village_names = ["Transfer", "Node Nine"]
	d.weather = [
		[Weather.CLEAR, 36, 0.0], [Weather.GREY, 34, 0.0], [Weather.RAIN, 18, 0.4],
		[Weather.FOG, 12, 0.0],
	]
	d.mist = 0.1
	# What a place built for machines does to a body: the field off everything
	# running, and no shade, no water, no shelter anybody thought to leave.
	d.hazards = {&"em": 0.65, &"thirst": 0.4}
	d.roster = {
		&"warden": {"weight": 1.0},
		&"watcher": {"weight": 1.0},
		&"clerk": {"weight": 1.0, "grounds": ["floor", "road", "gravel", "rock"]},
		&"sweeper": {"weight": 0.9, "grounds": ["floor", "road", "gravel"]},
		&"longlegs": {"weight": 0.6},
	}
	d.landmarks = [&"clerks_office", &"blinking_stack", &"poured_pillar", &"cast_stones"]
	d.sound_bed = &"bed_hum"
	d.surface = _surface
	d.scatter = _scatter
	return d


## A floor, a road where they drive, and swarf where something is cut. Three
## grounds and no accidents: the simplest surface rule in the registry, because
## the simplicity IS the landscape.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.GRAVEL
	if f & BiomeSurface.APRON != 0:
		return Ground.GRAVEL
	if f & BiomeSurface.BANK != 0:
		return Ground.GRAVEL
	return Ground.SWARF if gb > 0.45 else Ground.FLOOR


## EVERY PIECE OF IT IS THE PLANT, and the plant is the landscape. Nothing here
## grew: the floor carries the run of conveyors and pipe the place was laid out
## around, the road carries what controls who is on it, and the swarf is the one
## ground with anything untidy on it, because it is where the work is actually
## being done rather than where it is being routed.
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.FLOOR:
		# THE RUNS ARE NOT SCATTERED. The conveyor and pipe this floor was laid out
		# around are the plan's own, put down ruled on the survey bearing by the
		# works stage (`pipe_run`/`conveyor_run`, this file's GenWorks row). Dealing
		# them here turned each piece a random way: see `GenWorks.RUNS`.
		if r < 0.060:
			return PropKind.PLATFORM
		if r < 0.068:
			return PropKind.CONSOLE
		return PropKind.PYLON if r > 0.50 and r < 0.508 else BiomeScatter.NONE
	if g == Ground.ROAD:
		if r < 0.022:
			return PropKind.FENCE
		return PropKind.CHECKPOINT if r > 0.60 and r < 0.609 else BiomeScatter.NONE
	if g == Ground.SWARF:
		if r < 0.040:
			return PropKind.STACK
		if r < 0.055:
			return PropKind.WATER_TANK
		return PropKind.RELAY if r > 0.30 and r < 0.312 else BiomeScatter.NONE
	if g == Ground.GRAVEL:
		return BiomeScatter.NONE
	return BiomeScatter.NONE
