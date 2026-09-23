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
	d.share = Vector2(0.055, 0.095)
	# No journey anchor: it takes the temperate, half-dry middle, and it wants a
	# shore because that is where the plant took its water.
	d.temp_range = Vector2(0.35, 0.75)
	d.moist_range = Vector2(0.25, 0.65)
	d.site_count = Vector2i(1, 1)
	d.coastal = 0.3
	d.adjacency = {&"coast": 0.6, &"bonelands": 0.35,
		&"scrapwood": -0.3, &"salt_flats": -0.3, &"snowfield": -0.6, &"moss": -0.4}
	# Flat, and stepped rather than rolling: a city is built on platforms. The
	# terrace term is what gives the mesher long level slabs with a step between
	# them, which is what a street reads as from above; hills and ridge are near
	# zero because nothing here was allowed to stay a hill.
	#
	# AND THE PLATFORMS HAVE TO BE BIG ENOUGH TO BUILD A STREET ON, which is why
	# the terrace term is a third of what it first was and the hills half. Two
	# things demand it and neither was known when these were chosen: a `row` city
	# plan (`BiomeForms`) refuses any spot whose nine neighbouring tiles are not
	# level, so on terraced ground a street comes out with one building on it; and
	# `neon_reflect()` only mirrors a light where the ground's up-normal is 0.9 or
	# better, so a stretch of flat street is literally what buys the reflections
	# this landscape's wet look is made of. The stepping is still here — it is what
	# stops a city reading as a field — there is just more slab between the steps.
	# FLATTER AGAIN, because a street is only a street if a row of buildings can
	# stand on it: the `row` plan refuses any spot whose nine neighbours are not
	# all one level, and the city was coming out with TWO buildings in it.
	#
	# AND FLATNESS IS NOT THE WHOLE CAUSE, which is worth writing down so the next
	# person does not spend the afternoon here as I did. Measured on three seeds:
	# these values fixed seed 1, left seed 42 at two, and dropping `base` to 1.1
	# as well made seed 90210 WORSE (one building), because lower land is less
	# land once the sea has its share. The rest of the cap is in `GenScatter`s row
	# placement, not in this file -- see the task, and `ROW_RANKS`.
	d.relief = {
		&"base": 2.6, &"hills": 0.25, &"ridge": 0.0, &"near": 0.8, &"terrace": 0.30, &"valley": 0.2,
		&"rain": 0.85, &"temp": 0.6, &"moist": 0.42, &"cliff": 0.0,
	}
	# WHAT THIS CITY IS BUILT OF, and it is the whole point of the landscape: the
	# forms package exists because of this line. Without it the slums fell
	# through to `BiomeForms.PLAIN` — the eight one-storey shapes every landscape
	# raised before the field existed — so a megacity at permanent night rendered
	# as a shantytown of huts, braziers and fences with not one building of any
	# height in the frame. It was left out because it MOVES THE ISLAND (`built`
	# is TERRAIN in the stamp, deliberately: the stock's size is how many
	# buildings there are) and took some seed-pinned assertions with it. That is
	# a reason to fix the assertions, which are pinned to a world nobody promised
	# would never change, and never a reason to ship a city as a village.
	#
	# `row` is what makes a STREET: two frontages either side of a way through,
	# rather than `ring`'s detached houses round a green. The relief above was
	# already tuned for it — measured, at `terrace: 0.3, hills: 0.5` the level
	# check refused fifteen of sixteen spots and a street came out with one
	# building on it, which is why the terrace term is a third of what it was.
	d.built = BiomeForms.new()
	d.built.stock = BiomeForms.RAISED
	# A CITY IS BLOCKS, NOT A STREET. One frontage through the square is a village
	# with a street; this is several of them side by side, which is what lets the
	# count below be a city's rather than a stock's.
	d.built.plan = &"block"
	d.built.apart = BiomeForms.ROW_APART
	# Six shapes and six buildings is a village that happens to be tall. The pack
	# stays six; how many go up is said here, and a form may be dealt again past
	# the pack's size as long as no two of a kind stand within `repeat_apart` --
	# which is the whole of what the no-repeat rule was ever protecting.
	d.built.buildings = Vector2i(22, 34)
	d.built.repeat_apart = 15.0
	#
	# NOT the cause of the missing tips: `test_places_worth_walking_to` failed
	# without `built` too. That attribution was wrong when it was first written
	# down and is corrected here rather than left to mislead the next reader.
	# Under LANTERN this no longer picks a hatch — there is none. It is the
	# discriminator that tells one landscape's ground from another's in the lit
	# shaders (`style`), and CRACK is the right neighbour for poured concrete.
	d.hatch = Ink.CRACK
	# Every ground this city can show, named. A landscape only gets its own
	# colour for what it NAMES; the rest falls through to a shared table written
	# for a coast, which is how the scrapwood's own floor came out looking like
	# an ordinary wood on bare earth (playtest 6). The bleed-ins are named too,
	# because a ground that reaches in over a border still has to be in a city.
	# WHAT A GROUND IS MARKED AS, which is not the same question as what colour
	# it is, and here it is load-bearing rather than decorative.
	#
	# FLOOR had no row in `GroundColors._base_mark`, so it took PLAIN, and PLAIN
	# is the one code `world.gdshader` dispatches NOWHERE: not to `ground_mark`,
	# not to `ground_wear`, not to the works or survey marks. FLOOR is this
	# city's `plain_ground` and most of what is underfoot in it, so every street
	# drew as a flat untreated wash with the neon reflection lying on top of it,
	# and nothing anywhere said a word.
	#
	# It was found by forcing every ground here to PLAIN to localise it, and
	# watching the frame BRIGHTEN and the effect SPREAD instead of going away.
	# That is the measurement that named it; a guess would not have.
	#
	# THE MECHANISM FIRST WRITTEN HERE WAS WRONG, and the correction is worth
	# keeping because the wrong version is the plausible one. It said PLAIN and
	# GLOW are both 0 "so an unmarked ground IS a glowing one". They are both 0,
	# but nothing can confuse them: the shader's glow branch is guarded
	# `m >= 1 && m <= 16`, and `GroundColors.glow()` only ever spends GLOW as
	# `GLOW + clampi(..., 1, 16)`. Code 0 can be neither produced nor consumed by
	# that door. What an unmarked ground loses is its MATERIAL, not its darkness
	# -- the symptom was real and the cause named for it was not.
	#
	# The shared fix has landed (FLOOR takes ROAD in `_base_mark`) and
	# `tests/render/test_ground_marks.gd` now fails on any walkable ground with
	# no material, so the next landscape cannot walk into this silently. This
	# override is kept because it is this city's own statement about its streets
	# rather than an inherited default, and it is what the shared row was set to.
	d.ground_marks = {Ground.FLOOR: GroundColors.ROAD}
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
	# What people patch together in the lee of the lanes. A SHACK, and declared
	# rather than derived, because both the derivation and the obvious pick are
	# wrong here. Unset, the ladder would read `wet` 0.90 and give this place
	# STILTS — right for standing water, and this city is not flooded, it is a
	# dry street that never dries. And the lean-to it first asked for is what the
	# landscape before it in the order already builds, which is the one thing
	# `test_dressing` will not have: two neighbours in the registry raising the
	# same patched hut makes the order itself invisible.
	dress.shelter = &"shack"
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
	# RAISED FROM 1.15 toward the 1.80 ceiling, because the lid was winning.
	# Measured by Teammate 2 on seed 1 at 11:00 clear: the city read 36.8 mean
	# luma against the coast's 180.2 at the same hour, seed and weather -- 4.9x
	# darker, with a spire nine and a half units tall five tiles from the player
	# that did not read at all. The brightest pixel was nearly the same in both,
	# so it was not the tonemapper running out of range; almost nothing in the
	# frame was being lit.
	#
	# The arithmetic says the same: ambient lerps to `LID_AMBIENT` 0.26 against
	# the coast's `DAY_AMBIENT` 0.55 and the sun is cut to `LID_SUN` 0.035, so
	# noon under a full lid is night with the lights on. That is the lid working
	# as written -- and `night_sky` is the door the sky file names for exactly
	# this, the landscape saying its own LEVEL under a lid, spent into the day as
	# far as the lid is shut. The dome is lit from beneath by the city under it;
	# turning that up is the fiction, not a cheat around it.
	d.night_sky = 1.15
	# The darkness term is a lift like every other surface landscape's and it is
	# CLAMPED TO A NO-OP by the sky (a lift after the tonemapper has no ceiling
	# over it). It is not how this place is made dark — the light is. The cool
	# term is pushed to zero against SkyLight.NEON_DAY's 0.10, because a city
	# under sodium is the one landscape in the game that must not go blue.
	d.grade = Vector4(-0.50, 0.04, -0.10, 0.14)
	# THE WETTEST LAND IN THE GAME, and deliberately so: limestone_caves at 0.55 is
	# the next. The dome does not only stop the sun, it CONDENSES — what the plant
	# sends up comes back down as a permanent drip — so the street is wet at every
	# hour and in every weather rather than when it rains. Wet concrete under a low
	# warm light is the best thing this landscape has.
	#
	# It is also the ONE field the whole reflection path hangs on, which is why it
	# is this high rather than merely high: `wet` reaches `neon_wetness()` through
	# `SkyLight.neon_row` and the `neon_wet.x` global, and `neon_reflect()` — what
	# actually mirrors a light in the ground — EARLY-OUTS ENTIRELY under 0.05. A
	# modest number here would let the signs light the street and leave nothing in
	# the puddles, which is half this landscape's picture missing.
	d.wet = 0.90
	# The water in a city is what has run off it. Oily black-brown that gives
	# almost nothing back — but a WASH and not a hole (tests/render/test_water_wash),
	# so the soundings and the bank line still draw through it.
	d.water_wash = Color(0.105, 0.092, 0.080, 0.82)
	d.props = [PropKind.LAMP, PropKind.SIGN, PropKind.POLE, PropKind.FENCE, PropKind.BARRICADE,
		PropKind.DEBRIS, PropKind.VEHICLE, PropKind.WRECKAGE, PropKind.BENCH,
		PropKind.VENT, PropKind.VENT_CAP, PropKind.STACK, PropKind.WATER_TANK, PropKind.SLAG_HEAP,
		PropKind.RELAY, PropKind.CHECKPOINT, PropKind.ARCHIVE, PropKind.MEMORIAL, PropKind.GRAVE,
		PropKind.BOULDER, PropKind.STUMP, PropKind.BUSH, PropKind.DEAD_TREE,
		PropKind.IRON_ORE, PropKind.COPPER_ORE, PropKind.STONE_ORE, PropKind.COAL_ORE,
		# The wall somebody painted, and what got bolted over it. This landscape
		# is the only one that declares it, and until it did, nothing in the game
		# placed a mural and the kind was unreachable code.
		PropKind.MURAL]
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
	# A borough each. See BiomeDef.villages_each_region: this city laid three
	# regions on seed 1 and built in one of them.
	d.villages_each_region = true
	# The platform a city cuts for itself. Buildings are laid out to
	# GenSettle.HOUSE_REACH (14.5) and only FLAT (6.5) was ever levelled, so on
	# this landscape's own stepped relief everything past the platform's edge was
	# refused by the nine-tile level check -- villages asking for 22-34 buildings
	# stood 3, 6 and 9. See BiomeDef.village_platform.
	d.village_platform = 15.0
	d.village_names = ["Ninth Shift", "Lampway", "Cinderrow"]
	# SETTLED FIRST OF THE LANDSCAPES, and the line this replaces ("settled late:
	# the city takes what is left, which is what a city does") was a good sentence
	# that cost the landscape its whole reason for existing.
	#
	# Villages are dealt in `village_order` and no two may stand within `gap`
	# (56 x body_k; a borough of a city like this one within `GenSettle.borough_gap`,
	# since GEN 24). The slums is 5.4% of the island on seed 1 and it
	# borders coast, moss, salt flats and scrapwood — so by the time order 8 came
	# round, the eight villages already placed had crowded out every candidate it
	# had, and it got NONE. A city landscape with no settlement in it builds no
	# buildings, which is why the megacity rendered as braziers and huts however
	# `built` was declared. Measured on seed 1: eight villages, not one in the
	# slums, while the scrapwood at 5.2% — practically the same share — had one.
	#
	# `Landmarks` already solved this shape by going least-room-first so a small
	# landscape is not crowded out by a big one; `GenSettle` settles in declared
	# order instead. Until it does the same, the city asks first, because it is
	# the one landscape that is nothing without its settlement.
	d.village_order = 0
	# A STREET, AND NOT SIX PEOPLE. `35_folk` puts `PER_VILLAGE` (6) out round a
	# village and reads this where a landscape wants more. It was written for
	# exactly this city and this city never asked, so the one landscape in the game
	# where everybody is employed had the same handful of people in it as a fishing
	# hamlet. Thirty, because `CROWD_BLIND` is 8 within `CROWD_NEAR`: past that
	# nobody looks up at a stranger any more, and the player stops being an event
	# and becomes traffic. That is this landscape's whole argument about itself, and
	# this number is what decides whether it reads.
	#
	# A LOOK field in `WorldStamp` — worldgen lays the village, not the people in it
	# — so it moves no island and refuses no save.
	d.street_folk = 30
	# AND THE PLAN'S TRAFFIC OVERHEAD. The owner's direction for this landscape
	# names flying machines, and until now nothing in this game flew at all. Six
	# within reach: enough that the sky over a street is never empty and few
	# enough that one crossing the frame is still an event. They fly the machines'
	# own survey bearing, which is the line every ruled work on the island already
	# lies on, so the traffic runs on the same grid as everything else they laid.
	d.fliers = 6
	# AND LIGHT STANDING IN THE AIR. The boards on brackets are the advertising you
	# can read; this is the half you cannot — a column of light over a roof with
	# nothing holding it up, which is the one piece of a cyberpunk city this engine
	# had in no form at all. A third of the buildings, because a street where every
	# roof projects is a fairground and this city is supposed to be TIDY.
	#
	# THIS NUMBER IS NOW MEASURED AGAINST THE WRONG POPULATION AND IS LEFT ALONE
	# DELIBERATELY. `HoloView.ROOF_MOST` cuts eligibility to the LOW roofs, because
	# the frame cannot hold a column over a tower (#116), so a third is a third of
	# about five buildings instead of eight. Raising it to 0.8 was tried and
	# measured on seed 7: carriers went 2 -> 4 and IN FRAME stayed 0, because all
	# four stood further ahead than a 5.3 foot survives (5.5 tiles). The shortage is
	# not the share, it is how few low buildings a slums street has (#106), so the
	# share stays where it was until that moves.
	d.holograms = 0.34
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
	# `dark` is 0.20 and the number is LOAD-BEARING, so do not raise it.
	#
	# It was 0.50, put there to be FELT at every hour because the street is drawn
	# dark at noon under its lid. That is a LOOK (`sky_shut`) being expressed as a
	# PRESSURE, and it cost the landscape its own answer. The only piece in the
	# game that resists `dark` is the visor, and the visor is worn on the HEAD —
	# which is where the rebreather goes, and the rebreather is the strongest
	# answer to `fumes`, which is what this city is actually about. So a body
	# that answered the air went blind and a body that could see could not
	# breathe, and neither could live here.
	#
	# Measured, at the worst place and hour with the rebreather worn: 0.50 leaves
	# `dark` at 1.000, 0.30 at 0.680, 0.25 at 0.600, and 0.20 at 0.520 — the
	# first that clears BITE (0.55). It is still well over FELT (0.25) after dark,
	# so the unlit corners between the lamps press a body, which is the whole of
	# what the pressure can honestly say about a city its own scatter fills with
	# working streetlights.
	#
	# Making a LID press a body at noon is real and still wanted; it means
	# teaching `Hazards._hour_shift` about `BiomeDef.sky_shut`, which is another
	# package's file. Inflating a night hazard is not a stand-in for it — the
	# whole point is that the hazard's answer lives in a slot this landscape
	# already needs for something else.
	d.hazards = {&"fumes": 0.45, &"toxins": 0.28, &"dark": 0.20}
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
		# A party wall on a cleared lot, which is the only place a mural can
		# honestly stand: a building came down and left one gable up with a
		# picture on it.
		#
		# GRAVEL and never FLOOR, even though FLOOR is the plain ground and would
		# place these far more reliably. FLOOR is also `village_square_ground`,
		# and at one mural per 285 floor tiles one landed IN a village square on
		# seed 42 and took `test_villages_stand_in_clearings_with_a_square` from
		# 0.9 to 0.71 -- a six-tile wall across a market square, and an
		# intermittent failure that would have looked like flake. A wall belongs
		# on a cleared lot; the square is where people stand.
		if r < 0.035:
			return PropKind.MURAL
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
			# A VENT and not a PIPE, and the difference is a contract rather than
			# a preference. PIPE, CONVEYOR and DRILL_RIG are the plan's RUNS: the
			# works stage lays them ruled on the survey bearing at scale 1, and
			# `test_world_gen_works` holds every one of them in the world to that.
			# A landscape that scatters one as ordinary street furniture turns it
			# a random way and breaks the rule for the whole island -- which is
			# what this line did, and it read as three separate failures about
			# bearings rather than one about a kind nobody may deal.
			return PropKind.VENT
		if r < 0.072:
			return PropKind.VENT_CAP
		if r < 0.080:
			return PropKind.DEAD_TREE
		return PropKind.STACK if r > 0.94 and r < 0.945 else BiomeScatter.NONE
	return BiomeScatter.PASS
