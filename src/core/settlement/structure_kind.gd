class_name StructureKind
## Every piece a player can build, and what building it means (docs/VISION.md).
##
## A kind is data: what it costs, how much it takes, how loud it is to a machine,
## and which of the six families it belongs to. The settlement package fills the
## table out; the raids package reads SIGNS to decide what a passing machine
## notices and what a raiding party goes for. Nothing here knows how a piece is
## drawn: models do that, in the idiom the kind declares.
##
## The enum is saved and read by two packages: append, never reorder, never
## renumber. `family()` reads the ranges, so a new kind goes inside its family's
## own run.
##
## MORE KINDS ARE NAMED HERE THAN CAN BE BUILT, and that is allowed — `buildable()`
## exists so the raids package may name a piece nobody has learnt to put up. But an
## enum two and a half times the size of the game is the shape a system takes when
## it is called finished and is not, so **every name below says which it is**:
##
##   (built)     a player can put it up now: it is in ROWS and in BUILDABLE.
##   (planned)   meant, and something already leans on it — its physics, its
##               signature, or another package's test. The note says WHAT, so a
##               reader can tell a plan from a leftover without running the game.
##   (elsewhere) the game already has this under another package's name. A
##               duplicate, not a gap: nothing here should ever grow a row for it.
##
## **Nothing may be deleted from this enum in passing.** A kind is saved as its
## integer, so removing one renumbers every kind after it and silently turns a
## saved plate wall into a gate — and unlike a landscape change, no `WorldStamp`
## refuses that save, it just misreads it. Retiring the three (elsewhere) names is
## a real job with a `SaveFile.migrate` step behind it, not a tidy-up.

enum {
	## Shelter: a roof, a bed, a place to come back to.
	LEAN_TO,          # (built)
	HUT,              # (built)
	CELLAR,           # (built) stores a raid cannot loot — the answer to RaidRoles
	                  # going for the stores (SETTLE.md S4).
	HEARTH,           # (built)
	STORE,            # (built)
	## Power: made, mended and stolen.
	SOLAR_ARRAY,      # (built)
	WIND_SPINNER,     # (built)
	PEDAL_DYNAMO,     # (planned) power that costs a person instead of attention:
	                  # the only generator with no SIGNS row, which is its whole point.
	BATTERY_STACK,    # (built)
	STOLEN_CELL,      # (built) the loudest piece in the game (found_tech 1.0), and the
	                  # holding `tests/raid/test_attention.gd` weighs every other against.
	                  # Unlocked by reward: it wants a keeper's core (`needs_one`).
	## Food and water.
	PLOT,             # (built)
	GREENHOUSE,       # (planned) declares SIGNS light 0.5: lit glass at night is food
	                  # bought with being seen.
	MUSHROOM_CELLAR,  # (planned) food that wants no sun — the underground realm's, which exists.
	FISH_TRAP,        # (planned) food off water, for a coast holding.
	SNARE_LINE,       # (planned) food off the fauna 37_fauna already puts on the land.
	CATCHMENT,        # (built)
	FILTER,           # (planned) the thirst hazard's answer at holding scale.
	STILL,            # (planned) water out of brine: the salt flats', where a catchment cannot work.
	## Work. These are NOT "the stations the making ladder asks for", which is what
	## this line used to claim. The ladder asks for fire, bench, kiln, loom and
	## wheel, and `Recipes` / `Survival.STATION_KINDS` own every one of them. What
	## belongs to this package is the two the ladder has no station for.
	FORGE,            # (planned) nothing says `at: forge` yet, but it declares SIGNS
	                  # (smoke 0.7, noise 0.6) and `tests/settlement/test_defences.gd` builds one.
	BENCH,            # (elsewhere) `Recipes` builds it: {"builds": &"bench"}.
	MACHINE_SHOP,     # (planned) the FOUND-tier bench. SIGNS found_tech 0.5, and
	                  # `tests/settlement/test_contract.gd` builds one.
	KILN,             # (elsewhere) `Recipes` builds it: {"builds": &"kiln"}.
	LOOM,             # (elsewhere) `Survival.STATION_KINDS` puts one in a village house.
	RADIO_MAST,       # (built)
	## Defence.
	PALISADE,         # (built)
	PLATE_WALL,       # (built)
	GATE,             # (built) a wall you can get out of: a length of it a body walks
	                  # through, and the weak point a breaching party goes for.
	DITCH,            # (planned) defence that costs hours and no materials.
	TOWER,            # (planned) height, which a turret and a watch both want.
	SNARE,            # (planned) a trap that holds a raider.
	MINE,             # (planned) a trap that kills one.
	EMP_STAKE,        # (planned) the trap that answers a MACHINE specifically. Not the
	                  # raids package's `stake` — that is the plan's own survey stake
	                  # driven into the player's yard, and shares only the word.
	TURRET,           # (built)
	DECOY_MAST,       # (built)
	SPOOFER,          # (built)
	NETTING,          # (built)
	SHUTTERS,         # (planned) declares SIGNS mask 0.15: the cheapest mask there is.
	## Living: beds for the rescued, who staff the rest.
	BUNK,             # (built)
	COUNT,
}

enum Family {
	SHELTER,
	POWER,
	FOOD,
	WORK,
	DEFENCE,
	LIVING,
}

## The three idioms a piece can be built in (docs/LOOK.md, docs/VISION.md):
## MADE is hand work, MENDED is machine parts bound with hand work, FOUND is
## machine technology taken whole and still humming.
enum Idiom {
	MADE,
	MENDED,
	FOUND,
}

## What a kind gives off that a machine can sense, and what it hides. Keys are
## Signature channels; `mask` is subtracted from every channel instead of added,
## which is how a spoofer, netting or shutters earn their place. A kind with no row
## is seen by nobody: a palisade is just timber.
##
## A shelter, a plot and a water butt are deliberately not in this table, and
## that is the design rather than an omission: a place can be lived in without
## being found. Everything in here is a comfort or a power the player CHOSE, and
## every line of it can be given up again.
const SIGNS := {
	HEARTH: {"smoke": 0.5, "light": 0.4},
	STORE: {"traffic": 0.2},
	SOLAR_ARRAY: {"power": 0.6, "found_tech": 0.3},
	WIND_SPINNER: {"noise": 0.4, "power": 0.4},
	BATTERY_STACK: {"power": 0.5},
	STOLEN_CELL: {"found_tech": 1.0, "power": 0.8},
	GREENHOUSE: {"light": 0.5},
	FORGE: {"smoke": 0.7, "noise": 0.6},
	MACHINE_SHOP: {"noise": 0.7, "power": 0.6, "found_tech": 0.5},
	KILN: {"smoke": 0.8},
	RADIO_MAST: {"radio": 1.0, "power": 0.3},
	TURRET: {"found_tech": 0.5, "power": 0.4},
	# A decoy hides nothing where the holding stands. What it buys is readings
	# taken of IT instead (`lure` in ROWS), and one piece buys one thing: a decoy
	# that also masked the yard and cooled it would be a discount on everything
	# rather than a decision.
	SPOOFER: {"mask": 0.5},
	NETTING: {"mask": 0.2},
	SHUTTERS: {"mask": 0.15},
}

## Everything else a kind is, one row per kind. Read it through the helpers
## below, never by indexing: a kind with no row is one nobody has learnt to build
## yet, and every helper answers for it rather than breaking.
##
##   name      what the slate calls it
##   idiom     how it is drawn (docs/LOOK.md): MADE, MENDED or FOUND
##   health    what it stands up to before it is wreckage
##   solid     collision radius in tiles (0 = walked through; at or over 0.42 a
##             machine cannot see through it either, src/core/mobs/senses.gd)
##   cost      {item id: count} out of the creel; `minutes` of the world clock
##   wear      health lost per world hour standing (the weather adds to it)
##   staff     it makes nothing until somebody is on it
##   draw      power it wants before it works; `power` what it makes at full
##   makes     {item id: per world hour} at full condition, staffed and powered
##   store     how much more the holding can lay by while it stands
##   banks     charge it holds
##   sleeps    residents who can live here
##   defence   what a raiding party has to get through (the raids package reads it)
##   water     it makes HALF unless the holding catches its own water
##   water_gives  it is what catches the water
##   lure      it shouts for the holding from where IT stands, this loud, so a
##             machine that would have read the yard reads it instead
##             (`Settlement.lures`); only counted out past `Settlement.LURE_APART`
const ROWS := {
	LEAN_TO: {
		"name": "lean-to", "idiom": Idiom.MADE, "health": 6.0, "solid": 0.8,
		"cost": {&"driftwood": 3, &"rag": 1}, "minutes": 30.0, "wear": 0.035,
		"sleeps": 1,
	},
	HUT: {
		"name": "hut", "idiom": Idiom.MENDED, "health": 16.0, "solid": 1.15,
		"cost": {&"timber": 2, &"scrap": 2, &"rag": 1}, "minutes": 110.0, "wear": 0.02,
		"sleeps": 2,
	},
	HEARTH: {
		"name": "hearth", "idiom": Idiom.MADE, "health": 5.0, "solid": 0.45,
		"cost": {&"stone": 3, &"deadwood": 2}, "minutes": 25.0, "wear": 0.05,
	},
	# Dug in and lined with stone under a lid of seasoned timber, the pinewood saw
	# hall's reward: what lies within `keeps` of it a raid does not take, on paper
	# or by the harvester in the yard (RaidResolve.take_stores). It is also room.
	CELLAR: {
		"name": "cellar", "idiom": Idiom.MADE, "health": 18.0, "solid": 0.0,
		"cost": {&"stone": 4, &"timber": 2, &"seasoned_timber": 1}, "minutes": 90.0, "wear": 0.008,
		"store": 12.0, "keeps": 20.0,
	},
	STORE: {
		"name": "store", "idiom": Idiom.MADE, "health": 8.0, "solid": 0.65,
		"cost": {&"timber": 1, &"reeds": 3}, "minutes": 45.0, "wear": 0.025,
		"store": 24.0,
	},
	PLOT: {
		"name": "plot", "idiom": Idiom.MADE, "health": 4.0, "solid": 0.0,
		"cost": {&"deadwood": 2, &"stone": 1}, "minutes": 60.0, "wear": 0.06,
		"staff": true, "makes": {&"berries": 0.5}, "water": true,
	},
	CATCHMENT: {
		"name": "catchment", "idiom": Idiom.MENDED, "health": 7.0, "solid": 0.55,
		"cost": {&"scrap": 3, &"pitch": 1}, "minutes": 50.0, "wear": 0.03,
		"water_gives": true,
	},
	WIND_SPINNER: {
		"name": "wind spinner", "idiom": Idiom.MENDED, "health": 9.0, "solid": 0.4,
		"cost": {&"timber": 1, &"scrap": 2, &"iron": 1}, "minutes": 95.0, "wear": 0.05,
		"power": 2.0,
	},
	# The other half of the answer to "where does the power come from", and the
	# opposite bargain from the spinner: the spinner is free and unreliable — a
	# still week kills it — while an array is dear, wants charge cells nobody makes,
	# and is dependable right up until the sun goes down. Neither alone keeps a mast
	# up through a still night; an array and a battery stack do, which is the point.
	#
	# Its physics were written long before this row was (`SettlementRules.source`
	# has carried its day curve and its weather dimming the whole time) and could
	# not run, because nobody could build one.
	#
	# `power` is higher than the spinner's on purpose: `source` averages about 0.35
	# over a whole day against the spinner's ~0.38 at typical wind, so 2.4 against
	# 2.0 puts the two within a hair of each other per day and leaves the DIFFERENCE
	# where it belongs — in when the power arrives, not how much.
	SOLAR_ARRAY: {
		"name": "solar array", "idiom": Idiom.MENDED, "health": 8.0, "solid": 0.45,
		"cost": {&"wick": 2, &"scrap": 3, &"copper": 1}, "minutes": 100.0, "wear": 0.03,
		"power": 2.4,
	},
	BATTERY_STACK: {
		"name": "battery stack", "idiom": Idiom.MENDED, "health": 9.0, "solid": 0.45,
		"cost": {&"scrap": 3, &"copper": 1}, "minutes": 80.0, "wear": 0.03,
		"banks": 6.0,
	},
	# A keeper's core in a timber cradle, its lens lit: power the machines made
	# for themselves, day and night, in any weather. The build list grows by what
	# the player ends (SETTLE.md S5): any one of `needs_one` goes into it on top of
	# `cost`, and lives outside `cost` so mending never asks for another core and
	# salvage never hands one back. The loudest thing a holding can stand up.
	STOLEN_CELL: {
		"name": "stolen cell", "idiom": Idiom.FOUND, "health": 10.0, "solid": 0.45,
		"cost": {&"scrap": 2, &"copper": 2}, "minutes": 90.0, "wear": 0.02,
		"power": 4.0,
		"needs_one": [&"reaper_core", &"rake_core", &"plumb_core", &"anvil_core",
			&"unbuilder_core", &"lockkeeper_core", &"anchor_core"],
	},
	RADIO_MAST: {
		"name": "radio mast", "idiom": Idiom.MENDED, "health": 6.0, "solid": 0.3,
		"cost": {&"timber": 1, &"scrap": 1, &"copper": 1}, "minutes": 70.0, "wear": 0.03,
		"draw": 0.6, "staff": true,
	},
	PALISADE: {
		"name": "palisade", "idiom": Idiom.MADE, "health": 10.0, "solid": 0.5,
		"cost": {&"timber": 1, &"deadwood": 1}, "minutes": 30.0, "wear": 0.03,
		"defence": 1.0,
	},
	# A hurdle hung between two posts: walked through (no footprint), a wall
	# still for what it turns of a raid, and the weak point in the ring --
	# RaidRoles.breach_target goes for it first, so the breach comes where the
	# player chose to put it (SETTLE.md S3).
	GATE: {
		"name": "gate", "idiom": Idiom.MADE, "health": 8.0, "solid": 0.0,
		"cost": {&"timber": 2, &"scrap": 1}, "minutes": 40.0, "wear": 0.035,
		"defence": 0.6,
	},
	PLATE_WALL: {
		"name": "plate wall", "idiom": Idiom.MENDED, "health": 22.0, "solid": 0.55,
		"cost": {&"timber": 1, &"scrap": 3}, "minutes": 60.0, "wear": 0.015,
		"defence": 2.2,
	},
	NETTING: {
		"name": "netting", "idiom": Idiom.MADE, "health": 4.0, "solid": 0.0,
		"cost": {&"reeds": 2, &"rag": 2}, "minutes": 35.0, "wear": 0.06,
		"defence": 0.4,
	},
	# The answer that sends the machines' eyes somewhere else. A lashed pole with
	# plate shards that catch the light and rag that moves, stood out past the
	# yard: it says what the holding says, louder, from where nobody lives. It is
	# torn at by the weather and by whatever it fooled, so it wears like netting.
	DECOY_MAST: {
		"name": "decoy mast", "idiom": Idiom.MENDED, "health": 7.0, "solid": 0.3,
		"cost": {&"timber": 2, &"scrap": 2, &"rag": 2}, "minutes": 55.0, "wear": 0.05,
		"lure": 0.7,
	},
	# A relay's own voice box, answering the plan's pings in the plan's own
	# language. It wants a machine's power to do it — dark, it is a box on a stake
	# — and it is built round a record taken off a carrier, because nobody out
	# here knows what the machines say to each other until they have read some
	# (docs/DESIGN.md §Raids: the record as the gate to a spoofer).
	SPOOFER: {
		"name": "spoofer", "idiom": Idiom.FOUND, "health": 6.0, "solid": 0.35,
		"cost": {&"record": 1, &"copper": 2, &"scrap": 2}, "minutes": 90.0, "wear": 0.025,
		"draw": 1.0,
	},
	# A repeater taken off a machine and mounted on a crib of logs, so the yard can
	# answer back. It is the one piece that fights, and it pays for it three ways:
	# it wants more power than anything else, it is stolen technology humming in
	# the walls the whole time it is armed (SIGNS), and a party that is shot at
	# goes for it. Built round a repeater a player could have carried instead.
	# Narrow enough (solid) that a body can see past it, or it would blind itself.
	TURRET: {
		"name": "turret", "idiom": Idiom.FOUND, "health": 12.0, "solid": 0.4,
		"cost": {&"rep_light": 1, &"scrap": 4, &"copper": 2, &"iron": 1}, "minutes": 120.0, "wear": 0.02,
		"draw": 1.2, "defence": 1.2,
	},
	# The LIVING family's one piece, and what makes `sleeps` mean anything at all.
	# Until it had a row the family was empty, `Settlement.beds()` was called by
	# nobody, and the slate printed "sleeps 2" on a hut's build card while beds
	# decided nothing — a holding took in as many people as it had jobs and housed
	# them in the open.
	#
	# A lean-to and a hut sleep the player's own household; a bunk is the piece
	# whose whole job is somebody else's bed, so it is the only cheap way past two.
	# It gives off nothing of its own and gets no SIGNS row on purpose — like a
	# shelter and a plot, it is not a comfort a machine can smell. What it is loud
	# with is PEOPLE: `Settlement.signature` already reads the residents as
	# `traffic`, so filling a bunk is heard, and an empty one never is.
	BUNK: {
		"name": "bunk", "idiom": Idiom.MADE, "health": 7.0, "solid": 0.5,
		"cost": {&"timber": 2, &"reeds": 3, &"rag": 2}, "minutes": 70.0, "wear": 0.035,
		"sleeps": 4,
	},
}

## The order the slate offers them in: a roof and a fire first, because that is
## the order a person builds in, and the pieces that shout last. The two answers
## to being read stand after what gives a place away, because a player reaches
## for them once something has: the decoy wants nothing but hands, the spoofer a
## record and a holding with power in it.
##
## The bunk stands with the roofs it is one of, straight after the hut, because
## the moment a player wants one is the moment a piece asks for hands they have
## not got. The array stands beside the spinner it is the alternative to.
const BUILDABLE: Array[int] = [LEAN_TO, HEARTH, HUT, BUNK, STORE, CELLAR, PLOT, CATCHMENT,
	PALISADE, PLATE_WALL, GATE, NETTING, WIND_SPINNER, SOLAR_ARRAY, BATTERY_STACK, STOLEN_CELL, RADIO_MAST,
	DECOY_MAST, SPOOFER, TURRET]


## How loud a piece is to the region that watches it go up (SETTLE.md S2,
## Interference `&"built"`): 1 for anything, plus what it gives off, with found
## tech counted two and a half times -- the plan knows its own parts.
static func loudness(kind: int) -> float:
	var loud := 1.0
	var signs := signs(kind)
	for ch: String in signs:
		if ch == "mask":
			continue
		loud += float(signs[ch]) * (2.5 if ch == "found_tech" else 1.0)
	return loud


## What this kind gives off, standing and working. Empty for most pieces.
static func signs(kind: int) -> Dictionary:
	return SIGNS.get(kind, {})


static func family(kind: int) -> Family:
	if kind <= STORE:
		return Family.SHELTER
	if kind <= STOLEN_CELL:
		return Family.POWER
	if kind <= STILL:
		return Family.FOOD
	if kind <= RADIO_MAST:
		return Family.WORK
	if kind <= SHUTTERS:
		return Family.DEFENCE
	return Family.LIVING


static func is_defence(kind: int) -> bool:
	return family(kind) == Family.DEFENCE


static func row(kind: int) -> Dictionary:
	return ROWS.get(kind, {})


## Whether a player can put this kind up now. A kind in the enum with no row is
## one the raids package may still name and nobody has learnt to build.
## Tiles round a standing gate's middle that no body but the player's passes
## (FightSim.mob_walls, set by 46_settlements): the length of the ring it hangs in.
const GATE_HOLD := 0.8


static func buildable(kind: int) -> bool:
	return BUILDABLE.has(kind)


static func display_name(kind: int) -> String:
	var r := row(kind)
	if r.has("name"):
		return String(r["name"])
	return "piece %d" % kind


static func idiom(kind: int) -> Idiom:
	return row(kind).get("idiom", Idiom.MADE) as Idiom


static func health(kind: int) -> float:
	return float(row(kind).get("health", 6.0))


static func solid(kind: int) -> float:
	return float(row(kind).get("solid", 0.0))


static func cost(kind: int) -> Dictionary:
	return row(kind).get("cost", {}) as Dictionary


static func minutes(kind: int) -> float:
	return float(row(kind).get("minutes", 30.0))


## Health a standing piece loses every world hour. Nothing is free to keep: the
## weather takes the hand's work apart and the machines' plate only rusts slower
## (SettlementRules weighs the weather onto this).
static func wear(kind: int) -> float:
	return float(row(kind).get("wear", 0.03))


static func needs_staff(kind: int) -> bool:
	return bool(row(kind).get("staff", false))


static func draw_power(kind: int) -> float:
	return float(row(kind).get("draw", 0.0))


static func makes_power(kind: int) -> float:
	return float(row(kind).get("power", 0.0))


## The rewards a piece takes one of on top of its cost (SETTLE.md S5): empty for
## anything a player can put up from what the land gives.
static func needs_one(kind: int) -> Array:
	return row(kind).get("needs_one", []) as Array


static func makes(kind: int) -> Dictionary:
	return row(kind).get("makes", {}) as Dictionary


## What a standing piece keeps from a raid's hands (a cellar's `keeps`).
static func keeps(kind: int) -> float:
	return float(row(kind).get("keeps", 0.0))


static func store_room(kind: int) -> float:
	return float(row(kind).get("store", 0.0))


static func banks(kind: int) -> float:
	return float(row(kind).get("banks", 0.0))


static func sleeps(kind: int) -> int:
	return int(row(kind).get("sleeps", 0))


static func defence(kind: int) -> float:
	return float(row(kind).get("defence", 0.0))


## A plot dries out: half a crop unless the holding catches its own water.
static func wants_water(kind: int) -> bool:
	return bool(row(kind).get("water", false))


static func gives_water(kind: int) -> bool:
	return bool(row(kind).get("water_gives", false))


## How loud it shouts for the holding from where it stands, 0 for a piece that
## does not (see `lure` in ROWS).
static func lure(kind: int) -> float:
	return float(row(kind).get("lure", 0.0))


static func masks(kind: int) -> bool:
	return float(signs(kind).get("mask", 0.0)) > 0.0


## A piece a player switches by hand: it runs on power and nobody has to stand at
## it. A mast is switched by taking its hands off; a turret or a spoofer is
## switched off, which is how a holding goes dark without pulling anything down.
static func switched(kind: int) -> bool:
	return draw_power(kind) > 0.0 and not needs_staff(kind)
