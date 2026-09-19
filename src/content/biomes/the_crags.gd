## The Crags: fog on old stone, and ruins older than anything the machines built.
## Something is here that neither they nor the aliens have a file on. Owner's own,
## 2026-09-18: "a foggy crag land of ancient human ruins where myth and wonder
## still remain haunted by an unknown force even to the aliens and the machines".
##
## WHAT IT ARGUES WITH, and it is the only landscape that argues with the STORY
## rather than with the terrain. Everything else in this world is explained: the
## machines did it, the plan wants it, a person built it and left. This place is
## the one the explanation does not reach — and the two powers that between them
## can kill stars (docs/STORY.md §1) do not know what is in it either. That is
## worth more than another palette, because it is the only ground where a player
## can be told nothing and be right to be afraid.
##
## SO THE MACHINES ARE THIN HERE ON PURPOSE. The lightest roster of any surface
## landscape, no depot worth the name, and what is standing is old: the plan
## surveyed it, found nothing it wanted, and the survey posts are still up.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"the_crags"
	d.display_name = "the crags"
	d.order = 20
	d.style_note = "Wet grey rock in fog, stone that was cut by hand, and no machine light anywhere."
	d.share = Vector2(0.06, 0.1)
	d.anchors = [{"seq": 20, "u": 0.14, "v": 0.6}]
	d.temp_range = Vector2(0.15, 0.5)
	d.moist_range = Vector2(0.55, 1.0)
	d.adjacency = {&"moss": 0.3, &"pinewood": 0.25, &"bonelands": 0.25}
	d.coastal = 0.2
	# Broken, steep and high: crags rather than hills, with the valleys between
	# them deep enough to hold the fog all day.
	d.relief = {
		&"base": 11.0, &"hills": 5.5, &"ridge": 9.0, &"terrace": 0.6, &"valley": 2.8,
		&"rain": 1.3, &"temp": 0.14, &"moist": 0.75, &"cliff": 0.85,
	}
	d.border_elevation = 2.0
	d.reach_out_high = Vector4(6.0, 0.11, 0.13, 0.4)
	d.reach_in_low = Vector3(5.5, 0.09, 0.32)
	d.hatch = Ink.SPARSE
	d.grounds = {
		Ground.ROCK: P.SLATE[3].lerp(P.MOSS[2], 0.2),
		Ground.MOSS: P.MOSS[2].lerp(P.SPRUCE[2], 0.45),
		Ground.HEATH: P.MOSS[2].lerp(P.EARTH[2], 0.4),
		Ground.GRASS: P.MOSS[3].lerp(P.SPRUCE[2], 0.3),
		Ground.SCREE: P.SLATE[2].lerp(P.STONE[2], 0.4),
		Ground.PEAT: P.EARTH[2].lerp(P.SPRUCE[1], 0.4),
		Ground.LIMESTONE: P.STONE[3].lerp(P.MOSS[2], 0.25),
	}
	d.cliff_wash = P.SLATE[2].lerp(P.MOSS[2], 0.3)
	d.strata = GroundColors.STRATA_MOSS
	d.plain_ground = Ground.MOSS
	d.bank_ground = Ground.PEAT
	d.pool_rim_ground = Ground.PEAT
	d.village_ground = Ground.GRASS
	d.decor = {Ground.MOSS: [0.85, Decor.TUFT, 30, Decor.CROTTLE, 18, Decor.BOG_COTTON, 8]}
	d.grass_colors = [P.MOSS[2], P.SPRUCE[2]]
	d.rock_color = P.SLATE[3]
	d.decor_tints = {&"fronds": [P.MOSS[2], P.SPRUCE[2], P.EARTH[2]]}
	# Stone cut by hand, lichen over everything, and timber that went black rather
	# than grey because it has never once been dry.
	var dress := BiomeDressing.new()
	dress.stone = [P.SLATE[3], P.STONE[3], P.MOSS[2]]
	dress.walling = [P.SLATE[2], P.STONE[3], P.MOSS[2], P.SPRUCE[2]]
	dress.timber = [P.SPRUCE[1], P.SLATE[2]]
	dress.sink = 0.18
	dress.lie = Vector2(-0.08, 0.12)
	d.dressing = dress
	d.grade = Vector4(-0.04, 0.02, 0.04, 0.0)
	# THE DARKEST NIGHT IN THE GAME, and nothing of the machines' lights it. This
	# is the one place where a lantern is the only light there is.
	d.night_sky = 0.55
	d.props = [PropKind.STANDING_STONE, PropKind.CAIRN, PropKind.RUIN, PropKind.BOULDER,
		PropKind.CLINTS, PropKind.GRAVE, PropKind.MEMORIAL, PropKind.BUSH,
		PropKind.DEAD_TREE, PropKind.STONE_ORE]
	d.ore = [[PropKind.STONE_ORE, 0.028], [PropKind.IRON_ORE, 0.012]]
	d.sites = {"stone_circles": 3, "ruins": true, "summit": 1}
	d.beached_wrecks = false
	d.pools = {"order": 2, "cell": 28, "chance": 0.5, "r_min": 2.0, "r_max": 4.4, "ground": Ground.BLACKWATER}
	d.villages = 1
	d.village_order = 20
	d.village_names = ["Cairnwell", "Thin Ford"]
	d.weather = [
		[Weather.FOG, 34, 0.0], [Weather.GREY, 26, 0.0], [Weather.RAIN, 22, 0.55],
		[Weather.DRIZZLE, 12, 0.0], [Weather.CLEAR, 6, 0.0],
	]
	# The foggiest place there is: it is what the landscape is FOR.
	d.mist = 0.55
	# Wet and dark and nothing else — no machine exhaust, no spores, no glare.
	# What is dangerous here is not a pressure, which is exactly the point.
	d.hazards = {&"wet": 0.5, &"dark": 0.45}
	# THE THINNEST ROSTER OF ANY SURFACE LANDSCAPE. The plan surveyed this place,
	# found nothing it wanted, and left. What a player meets here is the land.
	d.roster = {
		&"watcher": {"weight": 0.5, "hours": Vector2(8, 18)},
		&"dog.feral": {"weight": 0.8},
	}
	d.landmarks = [&"cast_stones", &"firewatch", &"leaning_mast", &"clerks_office"]
	d.sound_bed = &"bed_the_crags"
	d.surface = _surface
	d.scatter = _scatter
	return d


## Bare rock on everything steep, moss over everything that holds water, and peat
## in the bottoms where it never drains. One field and one steep test.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.SHINGLE
	if f & BiomeSurface.APRON != 0:
		return Ground.SCREE
	if f & BiomeSurface.BANK != 0:
		return Ground.PEAT
	if rs > 1.4:
		return Ground.ROCK
	if e <= 6.0:
		return Ground.PEAT
	return Ground.MOSS


## Thorn in the sheltered pockets and nothing on the tops, which is what wind and
## seventy years of nobody cutting it leaves.
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.MOSS:
		return PropKind.BUSH if r < 0.03 else BiomeScatter.NONE
	return BiomeScatter.NONE
