## Ruined Metropolis: a dead megacity. Collapsed towers, broken highways stacked
## in tiers, plazas of shattered glass — and districts the machines still run,
## lit and clean and patrolled, beside districts left to rot. VISION §3 row 15,
## and the oldest thing on this project's task list.
##
## WHAT IT ARGUES WITH, and why it is the last of the seven rather than the first:
## it is the only landscape that contains its own opposite. Everywhere else is one
## condition — the coast is lived in, the bonelands is empty, the server fields
## are theirs. Here a street the machines keep runs into a street nobody has stood
## in for seventy years, and the border between them is a few metres of kerb.
##
## So the surface rule does something no other landscape's does: it reads the
## SAME field twice, once for how high the ground is and once for how far into a
## kept district it is, and hands back a swept floor or a drift of rubble from it.
## What makes the place is walking out of one into the other without a loading
## screen or a line of dialogue telling you.
##
## The Undercroft (VISION §3 row 21) lies beneath it and is the underground
## realm's, not this file's.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"ruined_metropolis"
	d.display_name = "the ruined metropolis"
	d.order = 17
	d.style_note = "Grey on grey, tiers of broken road, and one district in six with its lights still on."
	d.share = Vector2(0.07, 0.12)
	d.anchors = [{"seq": 16, "u": 0.5, "v": 0.42}]
	d.temp_range = Vector2(0.3, 0.7)
	d.moist_range = Vector2(0.2, 0.6)
	d.adjacency = {&"slums": 0.4, &"scrapwood": 0.25, &"bonelands": 0.2}
	d.coastal = -0.2
	# Tiered, because the highways are: long flat benches with hard steps between
	# them where a deck has come down. The terraces do the work here that canyon
	# walls do in the mesas.
	d.relief = {
		&"base": 8.5, &"hills": 3.0, &"ridge": 4.5, &"terrace": 1.4, &"valley": 2.0,
		&"rain": 0.8, &"temp": 0.12, &"moist": 0.3, &"cliff": 0.75,
	}
	d.border_elevation = 1.0
	d.reach_out_high = Vector4(5.5, 0.09, 0.11, 0.35)
	d.reach_in_low = Vector3(5.0, 0.08, 0.32)
	d.hatch = Ink.NONE
	d.grounds = {
		Ground.FLOOR: P.ASH[3].lerp(P.STONE[3], 0.45),
		Ground.ROAD: P.ASH[2].lerp(P.SLATE[2], 0.35),
		Ground.GRAVEL: P.STONE[3].lerp(P.ASH[3], 0.5),
		Ground.SCREE: P.ASH[2].lerp(P.STONE[2], 0.45),
		Ground.ROCK: P.SLATE[3].lerp(P.ASH[3], 0.4),
		Ground.GRASS: P.MOSS[2].lerp(P.ASH[2], 0.55),
		Ground.MUD: P.EARTH[2].lerp(P.ASH[2], 0.4),
	}
	d.cliff_wash = P.ASH[2].lerp(P.SLATE[2], 0.4)
	d.strata = GroundColors.STRATA_SCRAP
	d.plain_ground = Ground.FLOOR
	d.bank_ground = Ground.GRAVEL
	d.pool_rim_ground = Ground.GRAVEL
	d.village_ground = Ground.FLOOR
	d.decor = {Ground.GRASS: [0.5, Decor.TUFT, 18, Decor.SCRAP, 14]}
	d.grass_colors = [P.MOSS[2], P.ASH[3]]
	d.rock_color = P.SLATE[3]
	d.decor_tints = {&"fronds": [P.MOSS[2], P.ASH[2], P.STONE[2]]}
	# Poured concrete gone grey, glass in drifts where a face came down, and the
	# one clean thing anywhere is whatever the machines still wash.
	var dress := BiomeDressing.new()
	dress.stone = [P.ASH[3], P.STONE[3], P.SLATE[3]]
	dress.concrete = P.ASH[3]
	dress.walling = [P.ASH[2], P.STONE[3], P.SLATE[2], P.STONE[2]]
	dress.sink = 0.06
	dress.lie = Vector2(-0.02, 0.05)
	d.dressing = dress
	# The same stock and the same plan the Slums raises, because it IS the same
	# city a century on: what these two argue about is what happened to it, not
	# how it was laid out.
	d.built = BiomeForms.new()
	d.built.stock = BiomeForms.RAISED
	d.built.plan = &"block"
	d.built.apart = BiomeForms.ROW_APART
	d.grade = Vector4(-0.05, -0.01, 0.03, -0.02)
	# Half of it is lit and half of it is not, and that is the whole picture at
	# night: a night sky near the coast's, with the kept districts burning holes
	# in it.
	d.night_sky = 0.9
	d.props = [PropKind.RUIN, PropKind.DEBRIS, PropKind.WRECKAGE, PropKind.VEHICLE,
		PropKind.BARRICADE, PropKind.MURAL, PropKind.ARCHIVE, PropKind.LAMP,
		PropKind.PYLON, PropKind.STACK, PropKind.CHECKPOINT]
	d.ore = [[PropKind.IRON_ORE, 0.03], [PropKind.COPPER_ORE, 0.026], [PropKind.STONE_ORE, 0.02]]
	d.sites = {"tips": 3, "ruins": true}
	d.beached_wrecks = false
	d.pools = {"order": 3, "cell": 36, "chance": 0.3, "r_min": 1.8, "r_max": 3.6, "ground": Ground.WATER}
	d.villages = 1
	d.village_order = 17
	d.village_names = ["Eighth Ward", "The Cut"]
	d.weather = [
		[Weather.GREY, 32, 0.0], [Weather.CLEAR, 22, 0.0], [Weather.RAIN, 20, 0.5],
		[Weather.DUST, 16, 0.5], [Weather.FOG, 10, 0.0],
	]
	d.mist = 0.22
	# What a dead city does to a body: the dust off it, and the drop off a deck
	# that is not there any more.
	d.hazards = {&"dark": 0.35, &"collapse": 0.5}
	d.roster = {
		&"warden": {"weight": 1.0},
		&"sweeper": {"weight": 1.0},
		&"watcher": {"weight": 0.9},
		&"clerk": {"weight": 0.6},
		&"dog.feral": {"weight": 0.7},
	}
	d.landmarks = [&"clerks_office", &"poured_pillar", &"blinking_stack", &"cast_stones"]
	d.sound_bed = &"bed_ruined_metropolis"
	d.surface = _surface
	d.scatter = _scatter
	return d


## TWO CITIES, ONE FIELD. The ground blend decides which district a tile is in —
## low blend is a street the machines still sweep, high blend is one nobody has
## walked in seventy years — and the height decides which tier of road it is on.
## Two borders, and the one that matters is the one between kept and left.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.GRAVEL
	if f & BiomeSurface.APRON != 0:
		return Ground.SCREE
	if f & BiomeSurface.BANK != 0:
		return Ground.MUD
	# A face that came down: rubble against the foot of everything steep.
	if rs > 1.6:
		return Ground.SCREE
	# Left to rot, and green coming up through it.
	if gb > 0.74:
		return Ground.GRASS
	return Ground.FLOOR


## Nothing is planted. What grows came up through a slab in the half of the city
## nobody keeps, so it follows the same field the ground does.
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.GRASS:
		return PropKind.BUSH if r < 0.03 else BiomeScatter.NONE
	return BiomeScatter.NONE
