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
		&"base": 6.0, &"hills": 2.6, &"ridge": 3.0, &"near": 4.5, &"terrace": 0.7, &"valley": 1.8,
		&"rain": 1.4, &"temp": 0.2, &"moist": 0.85, &"cliff": 0.45,
	}
	d.border_elevation = 0.6
	d.reach_out_high = Vector4(5.0, 0.08, 0.1, 0.32)
	d.reach_in_low = Vector3(5.0, 0.08, 0.3)
	d.hatch = Ink.SPARSE
	# MOSS and NEEDLES below are NOT reachable from `_surface`. Keep them, but for
	# the reason measured rather than the one it is tempting to assume.
	#
	# A country holds ground its own recipe never lays, because a neighbour's
	# reaches across the border, and `GroundColors` keys the wash on the COUNTRY
	# -- so an entry here decides what that neighbour looks like INSIDE this
	# landscape. Counted over five seeds at 512, between **3.5% and 11%** of this
	# landscape's tiles carry a ground `_surface` cannot return (heath, sand,
	# shingle, river, road on every seed). The mechanism is load-bearing.
	#
	# **But these two particular entries are not busy, and saying so stops the
	# next reader being surprised.** Asked of this landscape rather than another:
	# MOSS lands on 2 tiles of one seed in five; NEEDLES on none of the five.
	# MOSS is kept because `d.adjacency` above biases this place to lie beside the
	# moss at 0.2, so the seed that lands that adjacency makes it real. NEEDLES
	# has no declared adjacency to anywhere needled and nothing measured behind
	# it -- it is kept on the rule alone.
	#
	# THE RULE: unreachable from its own recipe is not the same as unused. Ask the
	# world which grounds a country's tiles really carry, not which ones its
	# recipe returns. Deleting on the second question hands a border back to the
	# shared default, silently, in the one case a per-country wash exists for.
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
	# THE CITY'S SIX, because three could not carry the rule this landscape sets
	# itself. `repeat_apart` 20 over a stock of three is satisfiable only on a
	# PERFECT ring: measured on Canopy Row, twelve houses between radius 5.8 and
	# 14.9, the best any deal could manage is a 21.0 gap against a bar of 20.0 --
	# and a village is not a perfect ring, so two of a kind stood 12.0 apart.
	# Any four houses near the square are inside 20 of each other whatever they
	# are dealt, so with three forms two of them must match. Six forms is the
	# same stock the slums already deal, it moves no house and no tile (the
	# positions are laid before the models are dealt), and a city that has been
	# taken back by the forest has no reason to have been built out of three
	# shapes in the first place.
	d.built.stock = BiomeForms.RAISED.duplicate()
	d.built.plan = &"ring"
	d.built.apart = BiomeForms.RING_APART
	d.built.buildings = Vector2i(8, 14)
	# MEASURED, LIKE ITS SIBLINGS, AND 20 WAS NOT. Every other city sits at what
	# its own settlements deliver -- the slums 15.0 of 15.0, the machine city
	# 6.0 of 6.0, the drowned city 11.0 of 11.2 -- and this asked for 20 over
	# five seeds and got 5.1, because nothing ever cleared the bar so the deal
	# fell back on a cycle that ignores where a building stands. With the
	# fallback taking the furthest instead, fourteen houses in this footprint
	# deliver 14.6, and a village of radius fifteen cannot do much better: four
	# houses near its square are inside 20 of each other whatever they are dealt.
	d.built.repeat_apart = 14.0
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
	# Clear at 10 of 100 came out just under the floor, so the wettest reading of
	# this place was also an accidental one. Still wet, still dark under the
	# canopy; a day in eight of it is bright.
	d.weather = [
		[Weather.RAIN, 30, 0.6], [Weather.GREY, 20, 0.0], [Weather.FOG, 18, 0.0],
		[Weather.CLEAR, 18, 0.0], [Weather.STORM, 14, 0.5],
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


## THE GREEN IS WINNING AND THE CITY IS STILL THERE UNDER IT, so both have to be
## in the ground at once or it reads as a wood with rubble in it. The FLOOR slabs
## are what is left standing and carry the ruins and the murals; the MOSS and the
## GRASS over them carry the trees that broke them; the NEEDLES are where the
## canopy has properly closed. The ore is in the ROCK, because that is the city
## opened up rather than covered over.
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.FLOOR:
		if r < 0.040:
			return PropKind.RUIN
		if r < 0.054:
			return PropKind.DEBRIS
		return PropKind.MURAL if r > 0.62 and r < 0.6275 else BiomeScatter.NONE
	if g == Ground.NEEDLES:
		if r < 0.110:
			return PropKind.BROADLEAF
		return PropKind.BUSH if r < 0.132 else BiomeScatter.NONE
	if g == Ground.MOSS or g == Ground.GRASS:
		if r < 0.068:
			return PropKind.BROADLEAF
		if r < 0.086:
			return PropKind.BUSH
		return PropKind.STUMP if r > 0.50 and r < 0.508 else BiomeScatter.NONE
	if g == Ground.GRAVEL:
		if r < 0.032:
			return PropKind.DEBRIS
		return PropKind.VEHICLE if r < 0.044 else BiomeScatter.NONE
	if g == Ground.ROCK:
		if r < 0.030:
			return PropKind.IRON_ORE
		return PropKind.COPPER_ORE if r < 0.042 else BiomeScatter.NONE
	if g == Ground.MUD:
		if r < 0.026:
			return PropKind.STUMP
		return PropKind.WRECKAGE if r < 0.036 else BiomeScatter.NONE
	return BiomeScatter.NONE
