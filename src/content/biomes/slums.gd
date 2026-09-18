## The Slums (docs/VISION.md §3, docs/STORY.md): the one landscape where the
## plan WORKED.
##
## Everywhere else in this game half-broken machines hunt the people living in
## the gaps. Here that is not happening, and it is worse. The city still runs.
## Everyone is employed. The lights are on, the lanes are swept, the clerks file,
## and nothing in it is hunting anybody — because there is nobody left in it who
## has not already agreed. This is the fork TAKEN, and the player is supposed to
## walk out of it relieved and then be disturbed at having been relieved.
##
## So nothing here is ruined on purpose. What reads as dystopia is that it is
## TIDY: a working city under a lid, going about its day, at midnight.
##
## WHY THE STREET IS DARK, and why it is not a filter. The city still runs its
## own atmosphere plant, and the smog dome it makes is thick enough that the
## street never gets the sun (`sky_shut`, see BiomeDef and SkyLight.LID_*). The
## hour is untouched — the clock, the weather, the schedule and the shadows all
## run — and what changes is only how much of the sky arrives. That is a piece of
## the world, not a grade laid over it, which is the rule this project has paid
## for once already (docs/LOOK.md: the retired no-ops in sky.gdshaderinc).
##
## THE COLOUR IS SODIUM, MERCURY AND DIRTY WARM WHITE, and never violet or teal.
## Two reasons, and the second is the one that matters. Sodium orange is what a
## real city at night actually is, and it is the surest way not to look like
## every cyberpunk frame ever made. And the machine ramps own the violet band
## (`Palette`, hue 240-336) with `LENS` amber as the only saturated thing on a
## machine — so in the most crowded frame in the game, the ONE violet thing is a
## machine and the player reads it instantly. That is the payoff, and nothing in
## this file may spend it.
##
## The washes below are therefore dirty low-chroma greys and browns. The sodium
## is in the LIGHT and never in the albedo: wet concrete is orange here because
## what falls on it is orange, which is LANTERN laws 1 and 2 doing the work a
## tint would have done badly.

const P := preload("res://src/render/palette.gd")


static func make() -> BiomeDef:
	var d := BiomeDef.new()
	d.id = &"slums"
	d.display_name = "the slums"
	# After the scrapwood (7), well clear of the M1 six, who keep indices 1..6.
	d.order = 8
	d.style_note = "Flat rule and low tone: a city drawn in concrete and lit in sodium."
	# A city is compact. It does not sprawl across an island the way a bog does.
	d.share = Vector2(0.045, 0.075)
	# No journey anchor: it takes the temperate, half-dry middle, and it wants a
	# shore because that is where the plant took its water.
	d.temp_range = Vector2(0.35, 0.75)
	d.moist_range = Vector2(0.25, 0.65)
	d.site_count = Vector2i(1, 1)
	d.coastal = 0.3
	d.adjacency = {&"coast": 0.6, &"bonelands": 0.35, &"scrapwood": 0.3, &"salt_flats": 0.2,
		&"snowfield": -0.6, &"moss": -0.4}
	# Flat, and stepped rather than rolling: a city is built on platforms. The
	# terrace term gives the mesher long level slabs with a step between them,
	# which is what a street reads as from above; hills and ridge are near zero
	# because nothing here was allowed to stay a hill.
	#
	# FLATTER THAN THE FIRST DRAFT, and two independent reasons converge on it.
	# A `row` plan refuses any spot whose nine neighbouring tiles are not level,
	# so on terraced ground it lays a street with one building on it and calls
	# that a city. And `neon_reflect` only mirrors where the ground's up-normal
	# is at least 0.9, so a stepped street holds the billboards nowhere. Both
	# wanted the same thing, which is how you know it is the ground and not a
	# taste: hills 0.5 -> 0.25, terrace 0.85 -> 0.30.
	d.relief = {
		&"base": 2.6, &"hills": 0.5, &"ridge": 0.0, &"terrace": 0.85, &"valley": 0.2,
		&"rain": 0.85, &"temp": 0.6, &"moist": 0.42, &"cliff": 0.0,
	}
	# TODO(dome): `d.built` with BiomeForms.RAISED and plan &"row" belongs here and
	# is the whole point of the landscape. Landing it blind moved the island far
	# enough that seed 1 lays no tips in the slums at all (`test_places_worth
	# _walking_to`), and re-siting a landscape's sites is its author's work with
	# the gate in front of them, not an integrator's guess.
	# Under LANTERN this no longer picks a hatch — there is none. It is the
	# discriminator that tells one landscape's ground from another's in the lit
	# shaders (`style`), and CRACK is the right neighbour for poured concrete.
	d.hatch = Ink.CRACK
	# Every ground this city can show, named. A landscape only gets its own
	# colour for what it NAMES; the rest falls through to a shared table written
	# for a coast, which is how the scrapwood's own floor came out looking like
	# an ordinary wood on bare earth (playtest 6). The bleed-ins are named too,
	# because a ground that reaches in over a border still has to be in a city.
	d.grounds = {
		# The slab. Poured concrete that has been walked on for a lifetime:
		# a mid grey with the warmth of the dust that never washes off it.
		Ground.FLOOR: P.STONE[2].lerp(P.LINEN[1], 0.42),
		# The lanes. Darker than the slab and slightly warmer — tar, not stone.
		Ground.ROAD: P.INK[3].lerp(P.STONE[1], 0.55).lerp(P.EARTH[1], 0.14),
		# Where the slab has broken up and nobody has poured it again.
		Ground.GRAVEL: P.STONE[2].lerp(P.SAND[1], 0.32),
		# What the plant throws out, banked where the wind drops it.
		Ground.CLINKER: P.ASH[0].lerp(P.EMBER[0], 0.30),
		Ground.ASH: P.ASH[1].lerp(P.EARTH[1], 0.18),
		Ground.ROCK: P.STONE[1].lerp(P.ASH[0], 0.3),
		Ground.SCREE: P.STONE[1].lerp(P.SAND[0], 0.35),
		# City mud is black: it is what runs off everything else.
		Ground.MUD: P.EARTH[1].lerp(P.INK[2], 0.42),
		Ground.PEAT: P.INK[2].lerp(P.EARTH[0], 0.4),
		# A dock, and the grit that gathers at the end of a lane.
		Ground.SHINGLE: P.STONE[2].lerp(P.ASH[0], 0.4),
		Ground.SAND: P.SAND[1].lerp(P.ASH[0], 0.42),
		# What grows in a crack. Nothing here is green for long.
		Ground.GRASS: P.MOSS[2].lerp(P.ASH[0], 0.45),
		Ground.MOSS: P.MOSS[1].lerp(P.INK[2], 0.30),
		Ground.HEATH: P.EARTH[2].lerp(P.ASH[0], 0.45),
		Ground.NEEDLES: P.EARTH[2].lerp(P.INK[2], 0.35),
		Ground.LIMESTONE: P.LINEN[2].lerp(P.ASH[0], 0.42),
		Ground.BONE: P.LINEN[2].lerp(P.ASH[0], 0.38),
		Ground.SALT: P.LINEN[2].lerp(P.STONE[2], 0.35),
		Ground.PAN: P.LINEN[1].lerp(P.ASH[0], 0.3),
		# Snow does not lie clean on a city that is still burning something.
		Ground.SNOW: P.RIME[3].lerp(P.ASH[0], 0.42),
		Ground.ICE: P.RIME[2].lerp(P.SLATE[2], 0.35),
	}
	d.cliff_wash = P.STONE[1].lerp(P.LINEN[0], 0.35)
	d.strata = GroundColors.STRATA_COAST
	d.plain_ground = Ground.FLOOR
	d.bank_ground = Ground.GRAVEL
	d.pool_rim_ground = Ground.MUD
	d.rock_ground = Ground.ROCK
	d.village_ground = Ground.ROAD
	d.village_square_ground = Ground.FLOOR
	d.tip_ground = Ground.CLINKER
	d.decor = {
		Ground.FLOOR: [0.55, Decor.BOLT, 30, Decor.SCRAP, 24, Decor.WIRE, 18, Decor.TUFT, 12, Decor.FILINGS, 8],
		Ground.ROAD: [0.4, Decor.SCRAP, 32, Decor.BOLT, 26, Decor.WIRE, 20, Decor.TUFT, 10],
		Ground.GRAVEL: [0.8, Decor.SCRAP, 28, Decor.BOLT, 20, Decor.TUFT, 18, Decor.FERN, 10, Decor.WIRE, 10],
		Ground.CLINKER: [0.7, Decor.FILINGS, 34, Decor.SCRAP, 24, Decor.BOLT, 18, Decor.TWIG, 8],
	}
	# What little grows is gone grey. The tip is where a weed catches most light.
	d.grass_colors = [P.MOSS[1].lerp(P.ASH[0], 0.4), P.MOSS[3].lerp(P.ASH[1], 0.35)]
	d.rock_color = P.STONE[2].lerp(P.ASH[0], 0.35)
	d.decor_tints = {
		&"bloom": [P.EMBER[2], P.LENS[1], P.EMBER[3]],
		&"fronds": [P.MOSS[2].lerp(P.ASH[0], 0.4), P.MOSS[3].lerp(P.ASH[0], 0.35), P.MOSS[1]],
		&"twig": [P.EARTH[1].lerp(P.INK[2], 0.3)],
		&"spoil": [P.ASH[0]],
	}
	# A tree in this city grew out of a crack and has been breathing the plant's
	# exhaust its whole life: sparse, grey-green, half of it dead wood.
	d.tree_tints = {
		&"leaf": [P.MOSS[2].lerp(P.ASH[0], 0.42), P.MOSS[3].lerp(P.ASH[1], 0.3),
			P.SPRUCE[2].lerp(P.ASH[0], 0.4), P.MOSS[2].lerp(P.ASH[1], 0.3)],
		&"trunk": [P.EARTH[1].lerp(P.INK[2], 0.35)],
		&"scrub": [P.MOSS[2].lerp(P.ASH[0], 0.45), P.SPRUCE[2].lerp(P.ASH[0], 0.4),
			P.MOSS[1].lerp(P.ASH[0], 0.3)],
		&"dead": [P.EARTH[2].lerp(P.ASH[0], 0.45), P.ASH[0]],
	}
	# A city dresses its things in poured concrete, soaked timber and soot.
	var dress := BiomeDressing.new()
	dress.stone = [P.STONE[2].lerp(P.LINEN[1], 0.4), P.STONE[1], P.STONE[3].lerp(P.SAND[1], 0.3)]
	dress.timber = [P.SLATE[1].lerp(P.EARTH[1], 0.42), P.SLATE[2].lerp(P.ASH[0], 0.3)]
	dress.concrete = P.STONE[2].lerp(P.LINEN[1], 0.5)
	# An enamel sign in a working city is still legible, and it is warm, because
	# everything the eye reads down here is lit by sodium.
	dress.sign = [P.EMBER[4].lerp(P.LINEN[4], 0.35), P.INK[1]]
	dress.growth = P.MOSS[2].lerp(P.ASH[0], 0.35)
	# Soot, not drift: something is still burning, and it settles on everything
	# anybody leaves out.
	dress.covers = &"ash"
	# What people patch together against a wall, in the lee of the lanes.
	dress.shelter = &"lean_to"
	dress.crown = &"bare"
	# Concrete takes nothing in, and the canyons are out of the wind.
	dress.sink = 0.02
	dress.wind = 0.0
	d.dressing = dress
	# A WARM CAST AND NOT AN ORANGE FILTER. This multiplies the sun, the ambient
	# and the underside of the lid alike (`SkyLight.type_light` -> `mood`), so a
	# saturated value here would be exactly the global grade the owner has already
	# rejected once. The saturated sodium belongs to the LAMPS and the SHAFTS,
	# which are real lights somebody can stand in.
	d.light_tint = Color(1.0, 0.88, 0.72)
	# THE LID. 0.93 rather than 1.0 on purpose: at 1 there is no hour left in the
	# landscape at all, and the residue is what a player reads the time of day off
	# when they are standing in a torn place. See BiomeDef.sky_shut.
	d.sky_shut = 0.93
	# And the city kept its lights. The dome GLOWS — lit from beneath by the place
	# under it — so there is more light at street level here at midnight than on
	# bare coast, and `night_sky` is over 1 for a landscape that has a lid on it,
	# which is the opposite of what every other shut place in this game wants.
	# That contradiction is the landscape: it is dark because of the dome and
	# bright because of the city, and both are true at once.
	d.night_sky = 1.15
	# The darkness term is a lift like every other surface landscape's and it is
	# CLAMPED TO A NO-OP by the sky (a lift after the tonemapper has no ceiling
	# over it). It is not how this place is made dark — the light is. The cool
	# term is pushed to zero against SkyLight.NEON_DAY's 0.10, because a city
	# under sodium is the one landscape in the game that must not go blue.
	d.grade = Vector4(-0.50, 0.04, -0.10, 0.14)
	# It rains often and the lanes never dry: wet concrete under a low warm light
	# is the best thing this landscape has, and `wet` is what buys the sheen.
	# The wettest land in the game by design — limestone_caves at 0.55 is next.
	# It is not raining: the dome condenses on everything above and comes down as
	# a permanent drip, so the street is wet at every hour in every weather, which
	# is better than rain because it is always there and it is this place's own.
	# And it is the one field the whole reflection path hangs on: `neon_reflect`
	# early-outs under 0.05, and a modest value leaves the puddles holding nothing
	# — which would throw away half the light in the frame, since what the
	# billboards do to standing water is the second picture this landscape has.
	d.wet = 0.90
	# The water in a city is what has run off it. Oily black-brown that gives
	# almost nothing back — but a WASH and not a hole (tests/render/test_water_wash),
	# so the soundings and the bank line still draw through it.
	d.water_wash = Color(0.105, 0.092, 0.080, 0.82)
	d.props = [PropKind.LAMP, PropKind.SIGN, PropKind.POLE, PropKind.FENCE, PropKind.BARRICADE,
		PropKind.DEBRIS, PropKind.VEHICLE, PropKind.WRECKAGE, PropKind.BENCH, PropKind.PIPE,
		PropKind.VENT, PropKind.VENT_CAP, PropKind.STACK, PropKind.WATER_TANK, PropKind.SLAG_HEAP,
		PropKind.RELAY, PropKind.CHECKPOINT, PropKind.ARCHIVE, PropKind.MEMORIAL, PropKind.GRAVE,
		PropKind.BOULDER, PropKind.STUMP, PropKind.BUSH, PropKind.DEAD_TREE,
		PropKind.IRON_ORE, PropKind.COPPER_ORE, PropKind.STONE_ORE, PropKind.COAL_ORE]
	# What a city's rock gives is what was poured into it: iron and copper come
	# up out of the rubble easily, stone hardly at all.
	d.ore = [[PropKind.IRON_ORE, 0.055], [PropKind.COPPER_ORE, 0.095], [PropKind.COAL_ORE, 0.115],
		[PropKind.STONE_ORE, 0.125]]
	d.gravel_ore = true
	d.reed_chance = 0.0
	d.sites = {"tips": 3, "ruins": false, "summit": 0}
	# Sumps: standing water in the low places, going nowhere.
	d.pools = {"order": 6, "cell": 30, "chance": 0.35, "r_min": 1.8, "r_max": 3.2, "ground": Ground.BLACKWATER}
	d.beached_wrecks = false
	d.villages = 1
	d.village_names = ["Ninth Shift", "Lampway", "Cinderrow"]
	# Settled late: the city takes what is left, which is what a city does.
	d.village_order = 8
	# Smog weather. The cliché is rain, so rain is here and is not the most of it:
	# what a city under a working plant really gets is haze and flat grey, and the
	# clear days are the ones the wind took the dome sideways.
	d.weather = [
		[Weather.CLEAR, 20, 0.0], [Weather.GREY, 24, 0.0], [Weather.HAZE, 18, 0.0],
		[Weather.DRIZZLE, 16, 0.0], [Weather.RAIN, 14, 0.2], [Weather.FOG, 8, 0.0],
	]
	d.mist = 0.7
	# What it presses a body with. Fumes are the plant's and they are declared
	# just under BITE (0.55) on purpose, the way the Burning's are: haze is this
	# city's commonest weather and `_weather_shift` takes them over the line when
	# it falls, so the air is always noticed and only unbreathable when the smog
	# settles — which is exactly when a respirator earns its slot.
	#
	# `dark` is honest but incomplete, and the gap is worth writing down: the
	# hazards package reads the HOUR, and knows nothing about `sky_shut`. So the
	# street is drawn dark at noon while the pressure only bites after dusk. It is
	# declared high enough to be FELT at every hour, which is the closest the
	# current rules can come. Making a lid press a body properly means teaching
	# `Hazards._hour_shift` about it, and that is another package's file.
	d.hazards = {&"fumes": 0.45, &"toxins": 0.28, &"dark": 0.50}
	# NOTHING HERE HUNTS ANYBODY, and that is the landscape's whole argument. The
	# roster is workers, filers and observers — the plan at its work — and it
	# holds no runner and no cutter. A warden walks the small hours because a
	# working city has a curfew, not because it is looking for you.
	var lanes := ["floor", "road", "gravel", "clinker", "scree", "shingle", "mud"]
	d.roster = {
		&"clerk": {"weight": 1.6, "grounds": lanes},
		&"sweeper": {"weight": 1.4, "grounds": lanes},
		&"lineman": {"weight": 1.1, "grounds": lanes},
		&"watcher": {"weight": 1.0, "grounds": lanes},
		&"warden": {"weight": 0.7, "hours": Vector2(22, 5), "grounds": lanes},
		&"gulls": {"weight": 0.6, "hours": Vector2(6, 20), "grounds": lanes},
	}
	d.sentinel = &""
	# The places worth the walk (docs/VISION.md §3). Each of these names the slums
	# back in `Landmarks._build`, and `Landmarks.problems` fails if the two ever
	# stop agreeing.
	d.landmarks = [&"blinking_stack", &"clerks_office", &"leaning_mast"]
	# A city that still runs makes one sound under everything else.
	d.sound_bed = &"bed_hum"
	# No borrowed motif: it composes its own from its id (ScoreLandscapes).
	d.music_motif = &""
	d.surface = _surface
	d.scatter = _scatter
	return d


## Slabs, and the lanes between them. The lanes run along the ZERO LINE of the
## broad mass field rather than on a grid, because a grid on screen is the one
## thing this game may never draw — so the streets curve, meet at angles nobody
## planned, and read as a city from above without a single square in them.
static func _surface(t: BiomeSurface, i: int, e: float, rs: float, gb: float, f: int) -> int:
	if f & BiomeSurface.SHORE != 0:
		return Ground.SHINGLE
	if f & BiomeSurface.APRON != 0:
		return Ground.SCREE
	if f & BiomeSurface.BANK != 0:
		return Ground.MUD
	# The sumps: the low places the city drains into and never empties.
	if rs < -0.75 and gb < -0.15:
		return Ground.MUD
	# The lanes.
	if absf(gb) < 0.16:
		return Ground.ROAD
	# The high ground stands in the plant's own fallout.
	if e >= 7.0 or rs > 1.1:
		return Ground.CLINKER
	# Where the slab broke up and nobody poured it again.
	if gb < -0.45:
		return Ground.GRAVEL
	return Ground.FLOOR


static func _scatter(t: BiomeScatter, i: int, g: int, r: float) -> int:
	if g == Ground.FLOOR:
		# The lit furniture of a working street. Lamps are common on purpose:
		# they are the landscape's own light and the reason it is readable.
		if r < 0.030:
			return PropKind.LAMP
		if r < 0.044:
			return PropKind.SIGN
		if r < 0.056:
			return PropKind.POLE
		if r < 0.064:
			return PropKind.BENCH
		if r < 0.072:
			return PropKind.VENT
		if r < 0.080:
			return PropKind.DEBRIS
		return PropKind.VEHICLE if r > 0.90 and r < 0.906 else BiomeScatter.NONE
	if g == Ground.ROAD:
		if r < 0.034:
			return PropKind.LAMP
		if r < 0.046:
			return PropKind.POLE
		if r < 0.054:
			return PropKind.BARRICADE
		if r < 0.062:
			return PropKind.SIGN
		return PropKind.VEHICLE if r > 0.88 and r < 0.892 else BiomeScatter.NONE
	if g == Ground.GRAVEL:
		if r < 0.05:
			return PropKind.DEBRIS
		if r < 0.075:
			return PropKind.WRECKAGE
		if r < 0.09:
			return PropKind.BOULDER
		if r < 0.10:
			return PropKind.STUMP
		return PropKind.BUSH if r < 0.115 else BiomeScatter.NONE
	if g == Ground.CLINKER:
		if r < 0.04:
			return PropKind.SLAG_HEAP
		if r < 0.06:
			return PropKind.PIPE
		if r < 0.072:
			return PropKind.VENT_CAP
		if r < 0.080:
			return PropKind.DEAD_TREE
		return PropKind.STACK if r > 0.94 and r < 0.945 else BiomeScatter.NONE
	return BiomeScatter.PASS
