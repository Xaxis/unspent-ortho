## Drowned City: towers standing in the tide, streets running as canals, and the
## machines' ferries keeping to a timetable nobody set. VISION §3 row 10.
##
## WHAT IT ARGUES WITH: the water is not a wall here, it is the STREET. Every
## other landscape treats deep water as the edge of the walk (`Swim`), and this
## one is laid out so that the water is the way through and the buildings are the
## banks. A raft stops being a crossing and becomes transport, which is the first
## time in this game a craft is how you get about rather than how you get past.
##
## It is also the answer to the city reading as one note: the Slums is a city
## still running, and this is the same idea drowned — the same towers, the same
## streets, with the sea in them. Two cities that argue about what happened
## rather than two cities that look different.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"drowned_city"
	d.display_name = "the drowned city"
	d.order = 15
	d.style_note = "Green-black water between concrete, tide lines up every wall, nothing dry at ground level."
	d.share = Vector2(0.05, 0.09)
	d.anchors = [{"seq": 15, "u": 0.62, "v": 0.66}]
	d.temp_range = Vector2(0.35, 0.75)
	d.moist_range = Vector2(0.65, 1.0)
	d.adjacency = {&"coast": 0.45, &"slums": 0.3, &"moss": 0.2}
	# It IS the sea's: the drowned part of a coast, never inland.
	d.coastal = 1.0
	# Flat and LOW — the streets are at sea level because that is what drowned
	# them — with the towers doing all the standing up.
	d.relief = {
		&"base": 2.2, &"hills": 0.7, &"ridge": 1.2, &"terrace": 0.3, &"valley": 1.8,
		&"rain": 1.2, &"temp": 0.1, &"moist": 0.9, &"cliff": 0.35,
	}
	d.border_elevation = -0.8
	d.reach_out_high = Vector4(3.5, 0.05, 0.07, 0.25)
	d.reach_in_low = Vector3(6.0, 0.1, 0.35)
	d.hatch = Ink.NONE
	d.grounds = {
		Ground.FLOOR: P.ASH[3].lerp(P.SPRUCE[2], 0.3),
		Ground.ROAD: P.ASH[2].lerp(P.SLATE[2], 0.4),
		Ground.MUD: P.EARTH[2].lerp(P.SPRUCE[2], 0.45),
		Ground.SHINGLE: P.STONE[3].lerp(P.SPRUCE[2], 0.3),
		Ground.GRAVEL: P.STONE[3].lerp(P.ASH[3], 0.4),
		Ground.MOSS: P.MOSS[2].lerp(P.SPRUCE[2], 0.5),
		Ground.BLACKWATER: P.SPRUCE[1],
	}
	d.cliff_wash = P.ASH[2].lerp(P.SPRUCE[2], 0.35)
	d.strata = GroundColors.STRATA_SCRAP
	d.plain_ground = Ground.FLOOR
	d.bank_ground = Ground.MUD
	d.pool_rim_ground = Ground.MUD
	d.village_ground = Ground.FLOOR
	# Its inland water is the street, so it is drawn as water and never as a hole.
	d.water_wash = P.SPRUCE[2].lerp(P.MOSS[2], 0.3)
	d.decor = {Ground.MOSS: [0.55, Decor.TUFT, 20, Decor.SCRAP, 10]}
	d.grass_colors = [P.MOSS[2], P.SPRUCE[2]]
	d.rock_color = P.ASH[3]
	d.decor_tints = {&"fronds": [P.MOSS[2], P.SPRUCE[2], P.ASH[2]]}
	# Everything below the tide line is green and slick; everything above it is
	# salt-bleached concrete. That line is the whole palette.
	var dress := BiomeDressing.new()
	dress.stone = [P.ASH[3], P.STONE[3], P.SPRUCE[2]]
	dress.concrete = P.ASH[3]
	dress.walling = [P.ASH[2], P.STONE[3], P.SPRUCE[2], P.SLATE[2]]
	dress.sink = 0.16
	dress.lie = Vector2(-0.06, 0.1)
	d.dressing = dress
	# The city stands up, because it is a city: the same forms the Slums raises.
	# Blocks, because it was a city before the water came in — the streets between
	# them are what the sea is standing in now, and a `row` would make it one
	# waterfront rather than a grid with canals through it.
	# THIS WAS A PORT AND NEVER THE TALLEST CITY, which is most of why the water
	# took it: it was built low and near the water on purpose. No tower and no
	# spire, so the silhouette against the sea is a long flat one broken by
	# stacks, and the standing water reads as the thing that is out of place
	# rather than the buildings.
	d.built = BiomeForms.new()
	d.built.stock = [&"stack", &"block", &"shell", &"arcade"] as Array[StringName]
	d.built.plan = &"block"
	d.built.apart = BiomeForms.ROW_APART
	d.built.buildings = Vector2i(14, 22)
	d.built.repeat_apart = 11.0
	d.grade = Vector4(-0.06, 0.02, 0.06, -0.03)
	d.night_sky = 0.95
	d.props = [PropKind.RUIN, PropKind.DEBRIS, PropKind.WRECKAGE, PropKind.PIPE,
		PropKind.SEA_WALL, PropKind.TIDE_GAUGE, PropKind.HULL, PropKind.REEDS, PropKind.POLE]
	d.ore = [[PropKind.IRON_ORE, 0.02], [PropKind.COPPER_ORE, 0.018]]
	d.sites = {"tips": 2, "ruins": true}
	d.beached_wrecks = true
	d.pools = {"order": 2, "cell": 22, "chance": 0.7, "r_min": 2.4, "r_max": 5.5, "ground": Ground.BLACKWATER}
	d.villages = 1
	d.village_order = 15
	d.village_names = ["Tidemark", "Upper Quay"]
	d.weather = [
		[Weather.GREY, 28, 0.0], [Weather.RAIN, 26, 0.6], [Weather.FOG, 20, 0.0],
		[Weather.CLEAR, 18, 0.0], [Weather.STORM, 8, 0.5],
	]
	d.mist = 0.3
	# In the water more often than out of it, and the streets are deep enough to
	# be over your head where they dip.
	d.hazards = {&"wet": 0.7, &"toxins": 0.35}
	d.roster = {
		&"dredger": {"weight": 1.0},
		&"harvester": {"weight": 0.8},
		&"watcher": {"weight": 0.9},
		&"gulls": {"weight": 1.0, "hours": Vector2(5, 21)},
	}
	d.landmarks = [&"sump_pump", &"poured_pillar", &"leaning_mast", &"clerks_office"]
	d.sound_bed = &"bed_drowned_city"
	d.surface = _surface
	d.scatter = _scatter
	return d


## The tide line decides everything: under it is silt, at it is the slick, and
## above it is the floor somebody poured. One field, two borders.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.SHINGLE
	if f & BiomeSurface.APRON != 0:
		return Ground.GRAVEL
	if f & BiomeSurface.BANK != 0:
		return Ground.MUD
	if e <= 2.6:
		return Ground.MUD
	return Ground.MOSS if gb > 0.7 else Ground.FLOOR


## What grows here came in on the tide and stayed: reeds in the silt, nothing on
## the slabs.
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.MUD:
		return PropKind.REEDS if r < 0.05 else BiomeScatter.NONE
	return BiomeScatter.NONE
