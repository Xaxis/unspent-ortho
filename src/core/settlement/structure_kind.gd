class_name StructureKind
## Every piece a player can build, and what building it means (docs/VISION.md §9).
##
## A kind is data: what it costs, how much it takes, how loud it is to a machine,
## and which of the six families it belongs to. The settlement package fills the
## table out; the raids package reads SIGNS to decide what a passing machine
## notices and what a raiding party goes for. Nothing here knows how a piece is
## drawn: models do that, in the idiom the kind declares.

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
## is seen by nobody: a palisade is just timber. The settlement package fills the
## rest of this table in as it builds each piece; the shape does not change.
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
