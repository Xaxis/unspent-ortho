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
	d.spoken_in = "in the ruined metropolis"
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
		&"base": 8.5, &"hills": 3.0, &"ridge": 4.5, &"near": 5.5, &"terrace": 1.0, &"valley": 2.0,
		&"rain": 0.8, &"temp": 0.12, &"moist": 0.3, &"cliff": 0.75,
		# Its streets' spacing: the ground is laid a level to a block
		# (GenRelief.flatten_streets), on the grid its works line (`_streets`).
		&"streets": BLOCK,
	}
	d.border_elevation = 1.0
	d.reach_out_high = Vector4(5.5, 0.09, 0.11, 0.35)
	d.reach_in_low = Vector3(5.0, 0.08, 0.32)
	d.hatch = Ink.NONE
	d.grounds = {
		# Poured concrete seventy years under the weather, gone the warm grey of
		# dust and rust: not pale (at ASH[3] it read as snow at eye level), and not
		# the slums' blue-grey either, which is the living city next door.
		Ground.FLOOR: P.ASH[2].lerp(P.EARTH[2], 0.62),
		Ground.ROAD: P.ASH[2].lerp(P.SLATE[2], 0.35),
		Ground.GRAVEL: P.STONE[3].lerp(P.ASH[3], 0.5),
		Ground.SCREE: P.ASH[2].lerp(P.STONE[2], 0.45),
		Ground.ROCK: P.SLATE[3].lerp(P.ASH[3], 0.4),
		Ground.GRASS: P.MOSS[2].lerp(P.ASH[2], 0.55),
		Ground.MUD: P.EARTH[2].lerp(P.ASH[2], 0.4),
	}
	# Grounds this place never lays, named anyway: anything left unnamed falls
	# through to the shared table, which is the COAST's and is far brighter than
	# here, so it would arrive as the loudest object in the frame. Each takes this
	# landscape's own gravel, because they only have to be in key.
	for g: int in [Ground.BONE, Ground.ICE, Ground.LIMESTONE, Ground.PAN, Ground.SALT, Ground.SAND, Ground.SHINGLE, Ground.SNOW]:
		d.grounds[g] = d.grounds[Ground.GRAVEL]
	d.cliff_wash = P.ASH[2].lerp(P.SLATE[2], 0.4)
	# ITS OWN FLOOR AND WALLS, and LOOK only (no seed moves): the floor is a city's
	# (GroundColors.CITY_FLOOR) and every terrace is the broken edge of a deck
	# (STRATA_DECK). It was a pale wash over the scrapwood's bank of made ground.
	d.ground_marks = {Ground.FLOOR: GroundColors.CITY_FLOOR}
	d.strata = GroundColors.STRATA_DECK
	d.plain_ground = Ground.FLOOR
	d.bank_ground = Ground.GRAVEL
	d.pool_rim_ground = Ground.GRAVEL
	d.village_ground = Ground.FLOOR
	d.decor = {
		Ground.GRASS: [0.5, Decor.TUFT, 18, Decor.SCRAP, 14],
		# What a dead city sheds on its floor: cast stone with its rebar out,
		# glass, cans, a tuft up through a crack.
		Ground.FLOOR: [0.35, Decor.REBAR, 10, Decor.SEA_GLASS, 10, Decor.CAN, 6, Decor.SCRAP, 8, Decor.TUFT, 6],
	}
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
	# What people put up here is a dead tower's ground floor walled in with
	# salvaged doors (props/remains.gd `_infill`): nobody in a city builds a
	# hut when there is a frame standing on every block.
	dress.shelter = &"infill"
	# A ruin in a city is the stump of a tower, never a crofter's walls.
	dress.ruin_form = &"tower"
	d.dressing = dress
	# The same PLAN the Slums raises, because it IS the same city a century on,
	# and its own STOCK, because what happened to it is the whole argument: the
	# towers are dead, so what people build here is built INSIDE what fell — a
	# ground floor walled in with salvaged doors under a tower's frame, a shack
	# on a fallen deck, rooms hung inside a lift core, shop fronts re-shuttered
	# as homes (BiomeForms.FORMS; docs/LANDSCAPES.md). Four forms, so a
	# settlement here is four buildings: a ward, not a city.
	# Its streets (`_streets`): the city's grid on the survey bearing, lined with
	# the stumps of its towers, its shopfronts and lift cores, decks fallen
	# across the crossings, and the plan's demolition face.
	GenWorks.register(&"ruined_metropolis", {
		"host": load("res://src/content/biomes/ruined_metropolis.gd"),
		"works": &"_streets",
	})
	d.built = BiomeForms.new()
	d.built.stock = [&"infill", &"deck_house", &"shaft_loft", &"stall_row"] as Array[StringName]
	# The infill is a dead tower's lobby walled in and lived in; its room is its
	# own (content/interiors/tower_lobby.gd).
	d.interiors = {&"form:infill": &"tower_lobby", &"house": &"home"}
	# Behind the other forms, the stallholder, who carries the counter in off the
	# stall row at night, and the hoister who brings things up the shafts.
	d.home = {"households": {
		&"stallholder": {"wants": [&"counter", &"sorted_bins", &"ledgers", &"shelf"], "by_hearth": []},
		&"hoister": {"wants": [&"pulley", &"rope_coil", &"workbench", &"coil"], "by_hearth": []},
	}}
	d.built.plan = &"block"
	d.built.apart = BiomeForms.ROW_APART
	d.grade = Vector4(-0.05, -0.01, 0.03, -0.02)
	# Half of it is lit and half of it is not, and that is the whole picture at
	# night: a night sky near the coast's, with the kept districts burning holes
	# in it.
	d.night_sky = 0.9
	d.props = [PropKind.RUIN, PropKind.DEBRIS, PropKind.WRECKAGE, PropKind.VEHICLE,
		PropKind.BARRICADE, PropKind.MURAL, PropKind.ARCHIVE, PropKind.LAMP,
		PropKind.PYLON, PropKind.STACK, PropKind.CHECKPOINT,
		# Its own (docs/LANDSCAPES.md, src/models/props/metropolis.gd), declared
		# here so the city is the ONE landscape whose things these are: that is
		# what makes the lift cable's gate the city's (Sources.lands_yielding).
		# The bands that lay them, the works row that stands the gantry and the
		# bales at the demolition face, are the placement wave's; declaring a
		# kind places nothing until a recipe returns it.
		PropKind.DECK_SPAN, PropKind.LIFT_SHAFT, PropKind.SHOPFRONT,
		PropKind.SORTED_BALE, PropKind.DEMOLITION_GANTRY]
	d.ore = [[PropKind.REBAR_SLAB, 0.03], [PropKind.CABLE_DUCT, 0.026], [PropKind.STONE_ORE, 0.02]]
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
	# Concrete dust off the demolition: grey, cold and fine.
	d.weather_style = {&"dust": {"air": Color(0.64, 0.63, 0.60), "thick": 1.1}}
	# What a dead city does to a body: the dark of it, the drop off a deck that
	# is not there any more, and the dust off crushed concrete on the skin — a
	# plain 0.25, felt and never biting on its own, because `_weather_shift`
	# scales toxins under ASH and not under the DUST the city mostly gets; a
	# respirator or a scarf answers it (docs/LANDSCAPES.md).
	d.hazards = {&"dark": 0.35, &"collapse": 0.5, &"toxins": 0.25}
	d.roster = {
		&"warden": {},
		&"sweeper": {"grounds": ["floor", "road", "mud", "grass"]},
		&"watcher": {},
		&"clerk": {"grounds": ["floor", "road", "gravel", "rock"]},
		&"dog.feral": {},
		# The city's own worker, found nowhere else: the machine taking it apart
		# (Roster, `demolisher`). Its own row keeps it to the floor and the rubble.
		&"demolisher": {},
	}
	d.landmarks = [&"clerks_office", &"poured_pillar", &"blinking_stack", &"cast_stones"]
	# Its keeper: the gantry crane taking the city apart (src/core/sentinel/
	# designs/unbuilder.gd). The one door by which a landscape claims one.
	d.sentinel = &"unbuilder"
	d.sound_bed = &"bed_wreck"
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
	if gb > 0.40:
		return Ground.GRASS
	return Ground.FLOOR


## A CITY THAT DIED WITH PEOPLE IN IT AND IS HALF KEPT, which is two statements
## and the landscape has to make both. The FLOOR slabs carry what fell and what
## somebody painted; the ROAD carries what was abandoned trying to LEAVE, which
## is why the cars and the barricades and the checkpoints are only ever on it;
## and the lamps and the archive are the half that is still kept -- something is
## still changing the bulbs in a city with nobody in it.
static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.FLOOR:
		if r < 0.038:
			return PropKind.DEBRIS
		if r < 0.052:
			return PropKind.RUIN
		if r < 0.060:
			return PropKind.LAMP
		if r > 0.55 and r < 0.5565:
			return PropKind.MURAL
		return PropKind.ARCHIVE if r > 0.88 and r < 0.8835 else BiomeScatter.NONE
	if g == Ground.ROAD:
		if r < 0.030:
			return PropKind.VEHICLE
		if r < 0.044:
			return PropKind.BARRICADE
		return PropKind.CHECKPOINT if r > 0.70 and r < 0.7065 else BiomeScatter.NONE
	if g == Ground.SCREE or g == Ground.GRAVEL:
		if r < 0.034:
			return PropKind.DEBRIS
		return PropKind.WRECKAGE if r < 0.046 else BiomeScatter.NONE
	if g == Ground.GRASS:
		if r > 0.30 and r < 0.3075:
			return PropKind.PYLON
		return PropKind.STACK if r > 0.80 and r < 0.8055 else BiomeScatter.NONE
	if g == Ground.ROCK or g == Ground.MUD:
		if r < 0.024:
			return PropKind.DEBRIS
		return PropKind.RUIN if r < 0.034 else BiomeScatter.NONE
	return BiomeScatter.NONE


## Tiles between one street's centre line and the next, both ways.
const BLOCK := 19.0
## A street frontage stands this far off the street's centre line.
const FRONT := 5.2
## Along a frontage, one building every this many tiles.
const PLOT := 3.6

## THE CITY'S STREETS (GenWorks.register). The metropolis was terraces with a
## block on them: nothing at eye level said a street had run here. Its grid is
## ruled on the survey bearing like everything else the plan measured, a street
## every BLOCK tiles each way, and each frontage is lined, a plot at a time, with
## what the city left standing: mostly a tower's stump (BiomeDressing.ruin_form),
## now and then a shopfront or a lift core; a deck fallen across a crossing;
## and in each region the plan's demolition face, a gantry and its bales.
static func _streets(L: Object) -> void:
	var c: GenContext = L.c
	var d: Vector2 = L.d
	var nrm: Vector2 = L.nrm
	# The demolition face first, before the streets take the room: the plan
	# taking the city down, a gantry over the cut
	# and the bales it sorted the rubble into, in a row along the bearing.
	for n in GenWorks._n(L, 1.0):
		var s := GenWorks._site(L, 5, 2, [], 40.0, 700, 0.4)
		if s.x >= 0:
			GenWorks._work(L, &"_demolition_face", Vector2(s) + Vector2(0.5, 0.5))
	for rect: Rect2 in L.rects:
		var corners := [rect.position, rect.position + Vector2(rect.size.x, 0.0), rect.end, rect.position + Vector2(0.0, rect.size.y)]
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q: Vector2 in corners:
			var uv := Vector2(q.dot(d), q.dot(nrm))
			lo = lo.min(uv)
			hi = hi.max(uv)
		# Streets along the bearing (their centre lines at nrm = m * BLOCK), then
		# across it (d = m * BLOCK).
		for axis in 2:
			var along := d if axis == 0 else nrm
			var across := nrm if axis == 0 else d
			var a_lo := lo.x if axis == 0 else lo.y
			var a_hi := hi.x if axis == 0 else hi.y
			var c_lo := lo.y if axis == 0 else lo.x
			var c_hi := hi.y if axis == 0 else hi.x
			for m in range(ceili(c_lo / BLOCK), floori(c_hi / BLOCK) + 1):
				for side: float in [-1.0, 1.0]:
					var off := float(m) * BLOCK + side * FRONT
					var t := a_lo + PLOT * 0.5
					while t < a_hi:
						var p := along * t + across * off
						t += PLOT
						var tx := floori(p.x)
						var ty := floori(p.y)
						if not c.w.in_bounds(tx, ty) or not L.home(tx, ty):
							continue
						# Leave the crossings open, and a gap now and then.
						var into := fposmod(t, BLOCK)
						# Each plot's roll is keyed on the plot itself, never on a
						# shared stream: a street that did not move keeps what
						# stands along it whatever else the world lays.
						var key := Vector2i(roundi(p.x * 4.0), roundi(p.y * 4.0))
						if into < FRONT + 0.6 or into > BLOCK - FRONT - 0.6 or Rng.hash01(c.s, key.x, key.y, 0x57E1) < 0.18:
							continue
						var roll := Rng.hash01(c.s, key.x, key.y, 0x57E2)
						var kind := PropKind.RUIN
						if roll < 0.14:
							kind = PropKind.SHOPFRONT
						elif roll < 0.19:
							kind = PropKind.LIFT_SHAFT
						# Its face to the street.
						var facing := (-across * side).angle()
						GenWorks._put(L, kind, p, facing, -99, 0.4)
				# A deck fallen across the street at a crossing, now and then.
				for n in range(ceili(a_lo / BLOCK), floori(a_hi / BLOCK) + 1):
					var x := along * (float(n) * BLOCK + BLOCK * 0.5) + across * float(m) * BLOCK
					if Rng.hash01(c.s, roundi(x.x), roundi(x.y), 0x57E3) > 0.12:
						continue
					if c.w.in_bounds(floori(x.x), floori(x.y)) and L.home(floori(x.x), floori(x.y)):
						GenWorks._put(L, PropKind.DECK_SPAN, x, across.angle(), -99, 0.4)


## The plan taking the city down at `at`: a gantry over the cut and the bales it
## sorted the rubble into, in a row along the bearing on whichever side has room.
## A row of its own (`GenWorks._work`), so a region lays it alone as in the world.
static func _demolition_face(L: Object, at: Vector2, _a: Array) -> bool:
	var d: Vector2 = L.d
	var nrm: Vector2 = L.nrm
	if GenWorks._put(L, PropKind.DEMOLITION_GANTRY, at, d.angle(), -99, 1.0) == null:
		return false
	GenWorks._record(L.c, &"demolition_face", at, d, Vector2(6.0, 4.0))
	for side: float in [1.0, -1.0, 2.0, -2.0]:
		if GenWorks._run(L, PropKind.SORTED_BALE, at + nrm * 3.0 * side - d * 3.0, d, 4, 1.8, -99, 0.1).size() > 0:
			break
	return true
