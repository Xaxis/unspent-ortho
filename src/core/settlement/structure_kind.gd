class_name StructureKind
## Every piece a player can build, and what building it means (docs/VISION.md §9).
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

enum {
	## Shelter: a roof, a bed, a place to come back to.
	LEAN_TO,
	HUT,
	CELLAR,
	HEARTH,
	STORE,
	## Power: made, mended and stolen.
	SOLAR_ARRAY,
	WIND_SPINNER,
	PEDAL_DYNAMO,
	BATTERY_STACK,
	STOLEN_CELL,
	## Food and water.
	PLOT,
	GREENHOUSE,
	MUSHROOM_CELLAR,
	FISH_TRAP,
	SNARE_LINE,
	CATCHMENT,
	FILTER,
	STILL,
	## Work: these are the stations the making ladder asks for.
	FORGE,
	BENCH,
	MACHINE_SHOP,
	KILN,
	LOOM,
	RADIO_MAST,
	## Defence.
	PALISADE,
	PLATE_WALL,
	GATE,
	DITCH,
	TOWER,
	SNARE,
	MINE,
	EMP_STAKE,
	TURRET,
	DECOY_MAST,
	SPOOFER,
	NETTING,
	SHUTTERS,
	## Living: beds for the rescued, who staff the rest.
	BUNK,
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

## The three idioms a piece can be built in (docs/ART.md, docs/VISION.md §6):
## MADE is hand work, MENDED is machine parts bound with hand work, FOUND is
## machine technology taken whole and still humming.
enum Idiom {
	MADE,
	MENDED,
	FOUND,
}

## What a kind gives off that a machine can sense, and what it hides. Keys are
## Signature channels; `mask` is subtracted from every channel instead of added,
## which is how a spoofer, netting or a decoy earns its place. A kind with no row
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
	DECOY_MAST: {"mask": 0.35},
	SPOOFER: {"mask": 0.5},
	NETTING: {"mask": 0.2},
	SHUTTERS: {"mask": 0.15},
}

## Everything else a kind is, one row per kind. Read it through the helpers
## below, never by indexing: a kind with no row is one nobody has learnt to build
## yet, and every helper answers for it rather than breaking.
##
##   name      what the slate calls it
##   idiom     how it is drawn (docs/ART.md §12): MADE, MENDED or FOUND
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
	BATTERY_STACK: {
		"name": "battery stack", "idiom": Idiom.MENDED, "health": 9.0, "solid": 0.45,
		"cost": {&"scrap": 3, &"copper": 1}, "minutes": 80.0, "wear": 0.03,
		"banks": 6.0,
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
}

## The order the slate offers them in: a roof and a fire first, because that is
## the order a person builds in, and the pieces that shout last.
const BUILDABLE: Array[int] = [LEAN_TO, HEARTH, HUT, STORE, PLOT, CATCHMENT,
	PALISADE, PLATE_WALL, NETTING, WIND_SPINNER, BATTERY_STACK, RADIO_MAST]


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


static func makes(kind: int) -> Dictionary:
	return row(kind).get("makes", {}) as Dictionary


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
