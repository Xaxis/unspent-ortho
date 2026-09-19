## Green Towers: rainforest that has taken a city. Toppled skyscrapers lying
## under a canopy, roots through every slab, and the shape of streets still
## readable from the air if you know to look. Owner's own, 2026-09-18: "dense rain
## forest covering decaying and toppled human cities and skyscrapers".
##
## WHAT IT ARGUES WITH, and this is the fourth city in the game on purpose. The
## Slums is a city people still live in. The Ruined Metropolis is one that died
## with people in it and is half kept. The Machine City was never for people. This
## one has been WON BACK — not by people and not by the machines, but by what was
## here before either, and it is the only place in this world where something has
## beaten the plan without fighting it.
##
## SO THE GEOMETRY IS A CITY AND THE SURFACE IS A FOREST, and neither gives way.
## The ground under the buildings is the thickest growth outside the sulphur
## jungle, which is what "covering" has to mean if it is to mean anything — and
## the buildings are only the three forms a forest could not pull down, so the
## city reads as survivors in trees rather than as a city with trees in it.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"green_towers"
	d.display_name = "the green towers"
	d.order = 22
	d.style_note = "Canopy to the horizon with concrete through it, and a grid nobody has swept in seventy years."
	d.share = Vector2(0.06, 0.1)
	d.anchors = [{"seq": 22, "u": 0.74, "v": 0.86}]
	d.temp_range = Vector2(0.6, 0.95)
	d.moist_range = Vector2(0.7, 1.0)
	d.adjacency = {&"sulphur_jungle": 0.3, &"drowned_city": 0.25, &"moss": 0.2}
	d.coastal = 0.1
	# A city's ground: flat where the plan of it was, broken where a tower came
	# down and made a hill of itself.
	d.relief = {
		&"base": 6.0, &"hills": 2.6, &"ridge": 3.0, &"terrace": 0.7, &"valley": 1.8,
		&"rain": 1.4, &"temp": 0.2, &"moist": 0.85, &"cliff": 0.45,
	}
	d.border_elevation = 0.6
	d.reach_out_high = Vector4(5.0, 0.08, 0.1, 0.32)
	d.reach_in_low = Vector3(5.0, 0.08, 0.3)
	d.hatch = Ink.SPARSE
	d.grounds = {
		Ground.GRASS: P.MOSS[3].lerp(P.SPRUCE[3], 0.35),
		Ground.MOSS: P.SPRUCE[2].lerp(P.MOSS[2], 0.45),
		Ground.NEEDLES: P.SPRUCE[2].lerp(P.EARTH[2], 0.45),
		Ground.MUD: P.EARTH[3].lerp(P.SPRUCE[2], 0.3),
		Ground.FLOOR: P.ASH[3].lerp(P.MOSS[2], 0.45),
		Ground.GRAVEL: P.STONE[3].lerp(P.MOSS[2], 0.3),
		Ground.ROCK: P.SLATE[3].lerp(P.MOSS[2], 0.2),
	}
	# Grounds this place never lays, named anyway: anything left unnamed falls
	# through to the shared table, which is the COAST's and is far brighter than
	# here, so it would arrive as the loudest object in the frame. Each takes this
	# landscape's own gravel, because they only have to be in key.
	for g: int in [Ground.BONE, Ground.ICE, Ground.LIMESTONE, Ground.PAN, Ground.SALT, Ground.SAND, Ground.SHINGLE, Ground.SNOW]:
		d.grounds[g] = d.grounds[Ground.GRAVEL]
	d.cliff_wash = P.ASH[2].lerp(P.MOSS[2], 0.4)
	d.strata = GroundColors.STRATA_MOSS
	d.plain_ground = Ground.GRASS
	d.bank_ground = Ground.MUD
	d.pool_rim_ground = Ground.MUD
	d.village_ground = Ground.FLOOR
	d.decor = {Ground.GRASS: [0.95, Decor.TUFT, 34, Decor.CROTTLE, 16]}
	d.grass_colors = [P.MOSS[3], P.SPRUCE[3]]
	d.rock_color = P.SLATE[3]
	d.tree_tints = {&"leaf": [P.SPRUCE[3], P.MOSS[3], P.SPRUCE[2], P.MOSS[2]]}
	d.decor_tints = {&"fronds": [P.MOSS[3], P.SPRUCE[3], P.EARTH[2]]}
	# Concrete gone green, and nothing here has been dry since the last person
	# left it.
	var dress := BiomeDressing.new()
	dress.stone = [P.ASH[3].lerp(P.MOSS[2], 0.3), P.STONE[3], P.SPRUCE[2]]
	dress.concrete = P.ASH[3].lerp(P.MOSS[2], 0.35)
	dress.walling = [P.ASH[2], P.MOSS[2], P.STONE[3], P.SPRUCE[2]]
	dress.crown = &"full"
	dress.sink = 0.24
	dress.lie = Vector2(-0.1, 0.16)
	d.dressing = dress
	# ONLY WHAT COULD NOT FALL IS STILL STANDING, and in this table that means the
	# three TALL forms and nothing else: a tower, a spire and a stack are the only
	# rows high enough to still be over the canopy. The low ones — block, arcade
	# and the gutted shell — are all about a storey and a half, which down here is
	# under the leaves and is the ground rather than the skyline. So the stock is
	# three, they stand scattered rather than along a street, and each reads as an
	# individual survivor instead of a row.
	d.built = BiomeForms.new()
	d.built.stock = [&"tower", &"spire", &"stack"] as Array[StringName]
	d.built.plan = &"ring"
	d.built.apart = BiomeForms.RING_APART
	d.built.buildings = Vector2i(8, 14)
	d.built.repeat_apart = 20.0
	d.grade = Vector4(-0.02, 0.05, 0.0, 0.03)
	# Under a closed canopy at night there is nothing at all, and no machine keeps
	# a light here.
	d.night_sky = 0.6
	d.props = [PropKind.BROADLEAF, PropKind.BUSH, PropKind.RUIN, PropKind.DEBRIS,
		PropKind.VEHICLE, PropKind.MURAL, PropKind.STUMP, PropKind.WRECKAGE,
		PropKind.IRON_ORE, PropKind.COPPER_ORE]
	d.ore = [[PropKind.IRON_ORE, 0.028], [PropKind.COPPER_ORE, 0.024]]
	d.sites = {"ruins": true, "tips": 2}
	d.beached_wrecks = false
	d.pools = {"order": 2, "cell": 28, "chance": 0.55, "r_min": 2.0, "r_max": 4.2, "ground": Ground.WATER}
	d.villages = 1
	d.village_order = 22
	d.village_names = ["Canopy Row", "Fallen Mile"]
	d.weather = [
		[Weather.RAIN, 34, 0.6], [Weather.GREY, 22, 0.0], [Weather.FOG, 20, 0.0],
		[Weather.STORM, 14, 0.5], [Weather.CLEAR, 10, 0.0],
	]
	d.mist = 0.4
	# Wet under the canopy, dark under the canopy, and the towers are still coming
	# down one at a time.
	d.hazards = {&"wet": 0.55, &"dark": 0.4, &"collapse": 0.35}
	d.roster = {
		&"harvester": {"weight": 0.9, "grounds": ["grass", "moss", "floor"]},
		&"cutter": {"weight": 0.8, "grounds": ["rock", "gravel", "floor"]},
		&"sweeper": {"weight": 0.7, "grounds": ["floor", "gravel", "mud", "needles"]},
		&"dog.feral": {"weight": 0.9},
		&"bull.field": {"weight": 0.6, "grounds": ["grass", "moss"]},
	}
	d.landmarks = [&"poured_pillar", &"clerks_office", &"firewatch", &"blinking_stack"]
	d.sound_bed = &"bed_pines"
	d.surface = _surface
	d.scatter = _scatter
	return d


## THE STREETS ARE STILL THERE, under it. The ground blend decides: where the
## slab held, a floor shows through the leaf litter; where it did not, the forest
## has the whole of it. That is what makes the grid readable from the air without
## anything having to draw a grid.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.GRAVEL
	if f & BiomeSurface.APRON != 0:
		return Ground.GRAVEL
	if f & BiomeSurface.BANK != 0:
		return Ground.MUD
	if rs > 1.5:
		return Ground.ROCK
	if e <= 4.2:
		return Ground.MUD
	# A slab that held, with seventy years of leaf on it.
	return Ground.FLOOR if gb < 0.22 else Ground.GRASS


## Thick, and it grows straight out of the streets: the second-densest canopy in
## the game, behind the sulphur jungle only because concrete is harder than warm
## ground to put a root through.
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.GRASS:
		if r < 0.095:
			return PropKind.BROADLEAF
		return PropKind.BUSH if r < 0.15 else BiomeScatter.NONE
	# Even the slabs are going: something has got in at every joint.
	if g == Ground.FLOOR:
		return PropKind.BUSH if r < 0.015 else BiomeScatter.NONE
	return BiomeScatter.NONE
