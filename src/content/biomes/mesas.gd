## Mesas: red canyons cut a thousand feet down, wind that never stops, and the
## machines' roads carried across the gaps on trestles because nothing else could
## cross. VISION §3 row 13.
##
## WHAT IT ARGUES WITH, and the reason it is the first of the new seven: every
## landscape this game has is a SURFACE with things on it, and the difference
## between one and the next is what is scattered and what colour it is. This one
## differs in its RELIEF — the ground itself is the content. A canyon is a wall
## you walk round, a rim is a road, and a drop is the thing that makes a place
## take an hour instead of a minute. That is the owner's "too small" answered with
## terrain rather than with tiles.
##
## So `relief` here is unlike anything else in the registry: a high flat base, a
## deep valley cut and the hardest cliff factor in the game. The `_surface` rule
## reads that height and hands back rock on the walls, scree on the aprons and
## sand in the wash at the bottom, so the layering reads as strata from the air —
## which is what the flyover will show and what a player walks down through.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"mesas"
	d.display_name = "the mesas"
	d.order = 11
	d.style_note = "Banded red rock, hard shadow, the horizon cut into steps."
	d.share = Vector2(0.07, 0.12)
	d.anchors = [{"seq": 7, "u": 0.72, "v": 0.44}, {"seq": 11, "u": 0.86, "v": 0.6, "chance": 0.5}]
	d.temp_range = Vector2(0.55, 0.9)
	d.moist_range = Vector2(0.0, 0.3)
	# NOT beside the Burning, and the surface test is what argued it. Both are hot
	# and dry, so they were dealt a long shared border — and a border between two
	# landscapes that agree about everything is where the ground goes to salad:
	# seed 90210 pushed the Burning's own edge share over its bar. Red rock belongs
	# against the salt and the bone, which it argues with.
	d.adjacency = {&"salt_flats": 0.4, &"bonelands": 0.3}
	d.coastal = -0.7
	# THE LANDSCAPE'S WHOLE ARGUMENT IS IN THIS ROW. A high table (`base`), cut
	# deep (`valley`), with the steepest walls anything here declares (`cliff`) and
	# terraces wide enough to walk — so the shape is mesa, bench, canyon floor
	# rather than hill and dale.
	d.relief = {
		# MEASURED AGAINST A FRAME, not chosen by analogy. The first pass had hills
		# 2.2 and ridge 4.0 — LOWER than a snowfield's 3.0 and 6.5 — under a header
		# about thousand-foot canyons, and the shot came back a gently rolling sandy
		# plain. `hills` and `ridge` are AMPLITUDES (`GenRelief`), so the landscape
		# whose whole argument is its relief has to declare the biggest ones here.
		&"base": 10.0, &"hills": 8.0, &"ridge": 4.0, &"near": 7.0, &"terrace": 1.0, &"valley": 2.6,
		&"rain": 0.4, &"temp": 0.2, &"moist": 0.1, &"cliff": 1.0,
	}
	d.border_elevation = 1.9
	d.reach_out_high = Vector4(7.0, 0.12, 0.14, 0.4)
	d.reach_in_low = Vector3(5.5, 0.1, 0.35)
	d.hatch = Ink.SPARSE
	d.grounds = {
		Ground.ROAD: P.EARTH[3].lerp(P.RUST[3], 0.3),
		Ground.SAND: P.SAND[4].lerp(P.RUST[4], 0.4),
		Ground.SHINGLE: P.STONE[3].lerp(P.RUST[3], 0.35),
		Ground.GRASS: P.MOSS[2].lerp(P.SAND[3], 0.5),
		Ground.HEATH: P.EARTH[2].lerp(P.RUST[2], 0.35),
		Ground.ROCK: P.RUST[3].lerp(P.STONE[3], 0.25),
		# RED CANYONS, so the scree keeps its red. This was `.lerp(P.STONE[2], 0.4)`
		# -- two fifths grey -- which left it 0.069 from the Middens' swarf, the same
		# `P.RUST[2]` pulled the same distance toward SLATE instead of STONE, and two
		# greys are not far apart. Less grey is both truer to the place and further
		# from the other two it was crowding.
		#
		# And a tenth, not the 0.22 it was cut to next: at 0.22 it sat 0.0724 from the
		# pine floor, under the 0.08 every home turf must keep from every other. This
		# was SOLVED AS A SET rather than nudged, because nudging the pine floor darker
		# was tried and only moved the collision onto two new pairs. All 22 home turfs
		# were measured off `GroundColors.wash`, and nothing else in the game is red:
		# every other turf is green, grey, blue, bone or white. So redder scree moves
		# into empty space. At 0.10 its nearest neighbour is 0.108 away and the
		# tightest pair left anywhere is pine floor against the Middens at 0.0865,
		# which this does not touch. `tests/render/test_terrain.gd` holds all of it.
		Ground.SCREE: P.RUST[2].lerp(P.STONE[2], 0.10),
		Ground.GRAVEL: P.SAND[3].lerp(P.RUST[3], 0.3),
	}
	# Grounds this place never lays, named anyway: anything left unnamed falls
	# through to the shared table, which is the COAST's and is far brighter than
	# here, so it would arrive as the loudest object in the frame. Each takes this
	# landscape's own sand, because they only have to be in key.
	for g: int in [Ground.BONE, Ground.ICE, Ground.LIMESTONE, Ground.PAN, Ground.SALT, Ground.SNOW]:
		d.grounds[g] = d.grounds[Ground.SAND]
	d.cliff_wash = P.RUST[2].lerp(P.EARTH[2], 0.3)
	d.strata = GroundColors.STRATA_SAND
	d.plain_ground = Ground.SCREE
	d.bank_ground = Ground.SAND
	d.pool_rim_ground = Ground.GRAVEL
	d.village_ground = Ground.GRAVEL
	d.decor = {Ground.HEATH: [0.5, Decor.TUFT, 22, Decor.CROTTLE, 8]}
	d.grass_colors = [P.SAND[3], P.EARTH[3]]
	d.rock_color = P.RUST[3]
	d.decor_tints = {&"fronds": [P.SAND[2], P.EARTH[2], P.RUST[2]]}
	# Cut stone, sun-bleached bone, and timber that went silver rather than grey:
	# nothing rots up here, it only dries out and splits.
	var dress := BiomeDressing.new()
	dress.stone = [P.RUST[3], P.RUST[2], P.STONE[3]]
	dress.walling = [P.RUST[2], P.STONE[2], P.SAND[3], P.EARTH[2]]
	dress.bleach = P.SAND[5]
	dress.sink = 0.05
	dress.lie = Vector2(-0.02, 0.04)
	d.dressing = dress
	d.grade = Vector4(0.0, -0.02, -0.05, 0.02)
	# Dry air and no cloud: a hard bright night with black shadows under the walls.
	d.night_sky = 1.1
	d.props = [PropKind.BOULDER, PropKind.DEAD_TREE, PropKind.STONE_ORE, PropKind.IRON_ORE,
		PropKind.COPPER_ORE, PropKind.BUSH, PropKind.STUMP,
		# Its own (docs/LANDSCAPES.md §6, src/models/props/mesas.gd), declared here
		# so the mesas are the ONE landscape whose things these are: that is what
		# makes the span wire's gate the mesas' (Sources.lands_yielding). The
		# bands that lay them and the works row that stands the ropeway are the
		# placement wave's; declaring a kind places nothing until a recipe
		# returns it.
		PropKind.HOODOO, PropKind.ARCH_RIB, PropKind.FALLEN_SPAN, PropKind.CISTERN,
		PropKind.SPAN_PYLON]
	d.ore = [[PropKind.STONE_ORE, 0.03], [PropKind.IRON_ORE, 0.026], [PropKind.COPPER_ORE, 0.02]]
	d.sites = {"tips": 2, "summit": 2, "stone_circles": 1}
	d.beached_wrecks = false
	d.pools = {"order": 3, "cell": 44, "chance": 0.28, "r_min": 1.8, "r_max": 3.4, "ground": Ground.WATER}
	d.villages = 1
	d.village_order = 7
	d.village_names = ["Rimgate", "Drywater"]
	# Nothing falls here. What the weather does is BLOW, and the dust it lifts is
	# what takes the horizon away.
	# Clear was 46 of 100, which is not a mesa with weather on it, it is a mesa
	# with a forecast. Weather has to be an EVENT (tests/sky/test_weather.gd: a
	# landscape keeps clear days between 12% and 40% of spells), and what a mesa
	# does when it is not clear is blow dust.
	d.weather = [
		[Weather.CLEAR, 30, 0.0], [Weather.GREY, 12, 0.0], [Weather.DUST, 34, 0.7],
		[Weather.HEAT, 16, 0.0], [Weather.DRY_STORM, 8, 0.6],
	]
	d.mist = 0.04
	# The wind is not in `Hazards.IDS` and is not invented here: what a mesa
	# actually presses a body with is the sun on bare rock and no water in reach.
	d.hazards = {&"heat": 0.5, &"thirst": 0.55}
	d.roster = {
		&"cutter": {"weight": 1.0, "grounds": ["rock", "scree", "gravel"]},
		&"hauler": {"weight": 0.8},
		&"watcher": {"weight": 1.0, "hours": Vector2(5, 21)},
		&"dog.feral": {"weight": 0.8},
	}
	d.landmarks = [&"cast_stones", &"blinking_stack", &"poured_pillar", &"clerks_office"]
	# Its keeper: the anchor, a climber that drives the ropeway's bolts into the
	# scarps and keeps them driven (src/core/sentinel/designs/anchor.gd).
	d.sentinel = &"anchor"
	d.sound_bed = &"bed_wind"
	d.surface = _surface
	d.scatter = _scatter
	# The web's day contrast here (BiomeDef.web_contrast): inferred from the bonelands: bright rock.
	d.web_contrast = 1.1
	return d


## THE STRATA ARE THE POINT, but a stratum is a WASH and not a stripe. The first
## rule here switched on four thresholds — steepness, two heights and a second
## steepness — and `test_grounds_are_washes_not_salad` caught it at 0.30 against a
## 0.28 bar: every one of those lines is an edge, and enough edges is a patchwork
## rather than banded rock.
##
## So it decides on ONE field, height, with a single steepness override for a
## genuinely vertical wall. Three grounds, two borders, and the bands come out
## wide enough to be walked along.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.SAND
	if f & BiomeSurface.APRON != 0:
		return Ground.SCREE
	if f & BiomeSurface.BANK != 0:
		return Ground.SAND
	# A wall is bare rock whatever height it stands at: that is the one thing
	# steepness may say here, and it is what makes a canyon read as a canyon.
	if rs > 1.9:
		return Ground.ROCK
	if e <= 7.0:
		return Ground.SAND
	return Ground.SCREE


## RED ROCK AND WHAT LIVES ON IT, which is almost nothing. That is the point of
## the place and it is not the same thing as EMPTY, which is what one prop kind
## made it. The boulders came off the scarps, so they lie on scree and rock and
## never on the flats; the dead trees are the only things that ever stood in the
## sand; and the ore is in the cut faces rather than the floors, because that is
## where the rock is broken open instead of covered.
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.SCREE:
		if r < 0.048:
			return PropKind.BOULDER
		return PropKind.STONE_ORE if r < 0.060 else BiomeScatter.NONE
	if g == Ground.ROCK:
		if r < 0.040:
			return PropKind.BOULDER
		if r < 0.052:
			return PropKind.IRON_ORE
		return PropKind.COPPER_ORE if r < 0.062 else BiomeScatter.NONE
	if g == Ground.SAND:
		if r > 0.70 and r < 0.7075:
			return PropKind.DEAD_TREE
		return PropKind.BOULDER if r > 0.30 and r < 0.3065 else BiomeScatter.NONE
	if g == Ground.HEATH or g == Ground.GRASS:
		if r < 0.030:
			return PropKind.BUSH
		return PropKind.STUMP if r > 0.55 and r < 0.5565 else BiomeScatter.NONE
	if g == Ground.GRAVEL or g == Ground.SHINGLE:
		return PropKind.BOULDER if r < 0.024 else BiomeScatter.NONE
	return BiomeScatter.NONE
