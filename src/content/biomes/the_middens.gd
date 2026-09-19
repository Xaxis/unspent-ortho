## The Middens: miles of cyber refuse cut into slot canyons, so narrow in places
## that the sky is a line. Owner's own, 2026-09-18: "slot canyoned labrinth of
## technological wasteland, think a dump with miles of cyber refuse".
##
## WHAT IT ARGUES WITH: it is the only landscape where the TERRAIN is made of
## rubbish. The scrapwood has machines grown through it and the tips are heaps on
## open ground, but here the refuse IS the relief — the walls you walk between
## are seventy years of it, and the canyon floors are where it has not settled
## yet. Nothing in this game has said "the ground is not ground" before.
##
## AND IT IS THE ONE PLACE THAT IS A MAZE. Everywhere else the walk is open and
## the danger is what is in it; here the danger is not knowing the way out, and a
## body that can see three tiles in each direction cannot navigate by looking.
## That is what the biggest ridge amplitude in the registry buys, against a base
## low enough that the walls stand over you rather than under the sky.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"the_middens"
	d.display_name = "the middens"
	d.order = 19
	d.style_note = "Walls of sorted refuse, a strip of sky, everything the colour of what it used to be."
	d.share = Vector2(0.06, 0.1)
	d.anchors = [{"seq": 19, "u": 0.68, "v": 0.3}]
	d.temp_range = Vector2(0.3, 0.75)
	d.moist_range = Vector2(0.2, 0.6)
	d.adjacency = {&"scrapwood": 0.4, &"machine_city": 0.25, &"slums": 0.2}
	d.coastal = -0.4
	# THE MAZE IS IN THIS ROW. The highest ridge amplitude anywhere against a low
	# base and a hard cliff factor, so the land comes out as walls with slots
	# between them rather than as hills — which is the difference between a place
	# you cross and a place you get lost in.
	d.relief = {
		&"base": 5.5, &"hills": 2.0, &"ridge": 13.5, &"terrace": 0.5, &"valley": 3.0,
		&"rain": 0.6, &"temp": 0.1, &"moist": 0.25, &"cliff": 1.0,
	}
	d.border_elevation = 1.2
	d.reach_out_high = Vector4(5.0, 0.1, 0.12, 0.35)
	d.reach_in_low = Vector3(4.5, 0.08, 0.3)
	d.hatch = Ink.NONE
	d.grounds = {
		Ground.SWARF: P.RUST[2].lerp(P.SLATE[2], 0.4),
		Ground.GRAVEL: P.STONE[3].lerp(P.RUST[3], 0.35),
		Ground.SCREE: P.SLATE[2].lerp(P.RUST[2], 0.45),
		Ground.ROCK: P.SLATE[3].lerp(P.RUST[3], 0.3),
		Ground.MUD: P.EARTH[2].lerp(P.RUST[2], 0.35),
		Ground.ROAD: P.ASH[2].lerp(P.SLATE[2], 0.3),
	}
	d.cliff_wash = P.RUST[2].lerp(P.SLATE[2], 0.4)
	d.strata = GroundColors.STRATA_SCRAP
	d.plain_ground = Ground.SWARF
	d.bank_ground = Ground.MUD
	d.pool_rim_ground = Ground.SWARF
	d.village_ground = Ground.GRAVEL
	d.decor = {Ground.SWARF: [0.8, Decor.SCRAP, 34, Decor.SEA_GLASS, 8]}
	d.grass_colors = [P.RUST[3], P.SLATE[3]]
	d.rock_color = P.SLATE[3]
	d.decor_tints = {&"fronds": [P.RUST[2], P.SLATE[2], P.ASH[2]]}
	# Everything here WAS something, and what colour it is now is what seventy
	# years did to what it was.
	var dress := BiomeDressing.new()
	dress.stone = [P.SLATE[3].lerp(P.RUST[3], 0.3), P.RUST[2], P.SLATE[2]]
	dress.walling = [P.RUST[2], P.SLATE[2], P.ASH[2], P.STONE[3]]
	dress.sink = 0.22
	dress.lie = Vector2(-0.1, 0.16)
	d.dressing = dress
	d.grade = Vector4(0.03, -0.02, -0.02, -0.02)
	# Down in a slot you see almost no sky at all, which is most of why a lamp
	# matters here in a way it does not on open ground.
	d.night_sky = 0.6
	d.props = [PropKind.DEBRIS, PropKind.WRECKAGE, PropKind.SCRAP_TREE, PropKind.MAGNET_HEAP,
		PropKind.VEHICLE, PropKind.HULL, PropKind.BARRICADE, PropKind.SLAG_HEAP,
		PropKind.IRON_ORE, PropKind.COPPER_ORE]
	d.ore = [[PropKind.IRON_ORE, 0.05], [PropKind.COPPER_ORE, 0.042], [PropKind.TIN_ORE, 0.03]]
	# The richest ground in the game for taking, and the hardest to get out of.
	d.sites = {"tips": 4}
	d.beached_wrecks = false
	d.pools = {"order": 3, "cell": 34, "chance": 0.35, "r_min": 1.6, "r_max": 3.2, "ground": Ground.BLACKWATER}
	d.villages = 0
	d.village_order = 19
	d.village_names = []
	d.weather = [
		[Weather.GREY, 30, 0.0], [Weather.CLEAR, 22, 0.0], [Weather.DUST, 22, 0.6],
		[Weather.RAIN, 16, 0.5], [Weather.FOG, 10, 0.0],
	]
	d.mist = 0.18
	# What a dump of machine parts does to a body: the heaps pull on anything
	# ferrous, and the walls come down.
	d.hazards = {&"magnetism": 0.6, &"collapse": 0.45}
	d.roster = {
		&"sweeper": {"weight": 1.0},
		&"cutter": {"weight": 0.9},
		&"hauler": {"weight": 0.9},
		&"dog.feral": {"weight": 0.7},
	}
	d.landmarks = [&"grown_hulk", &"blinking_stack", &"clerks_office", &"poured_pillar"]
	d.sound_bed = &"bed_the_middens"
	d.surface = _surface
	d.scatter = _scatter
	return d


## Swarf on the floors where it is still being tipped, scree where a wall has
## shed, and rock where it has been standing long enough to pack down hard. The
## steep test does the work, because in a slot canyon almost everything is steep.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.GRAVEL
	if f & BiomeSurface.APRON != 0:
		return Ground.SCREE
	if f & BiomeSurface.BANK != 0:
		return Ground.MUD
	if rs > 1.7:
		return Ground.ROCK
	return Ground.SCREE if rs > 0.8 else Ground.SWARF


## What grows out of a dump is a scrap tree, and only in the slots where water
## collects long enough for anything to take.
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.SWARF:
		return PropKind.SCRAP_TREE if r < 0.018 else BiomeScatter.NONE
	return BiomeScatter.NONE
