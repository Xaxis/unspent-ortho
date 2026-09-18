class_name SiteKinds
extends RefCounted
## THE PLACES A LANDSCAPE IS MADE OF, as data (owner, 2026-09-18, docs/VISION.md
## §10: landscapes must be far more immense and detailed, with story elements,
## challenges and barriers).
##
## MEASURED, and it is the whole reason this file exists. Before it there were
## four kinds of place in the entire game — a tip, a stone circle, a ruin, a
## fumarole — and `GenScatter.sites` laid them from an ABSOLUTE count per
## landscape TYPE across the whole island. The coast is about 37,400 land tiles
## at 512 and lays four tips: one place per 9,350 tiles. So a region made bigger
## was a bigger EMPTY one, exactly, and no amount of work on the size would have
## changed that.
##
## A PLACE IS FOUR THINGS AT ONCE, which is why this is the answer to four of the
## owner's five complaints rather than one:
##
##   a REASON to walk there      `holds`  — what it gives that the open ground does not
##   DETAIL                      `props`  — it is furnished, not a patch of recoloured ground
##   a CHALLENGE                 `guard`  — what is already there, and what that costs
##   a BARRIER                   `behind` — what you need before you can have it at all
##
## and the fifth, story, is what somebody says about it, which is the story
## package's and never this file's.
##
## WHAT THIS FILE IS NOT. It places nothing and draws nothing. `GenScatter` reads
## it and lays what it says; the models are the props' own. A kind here is a
## sentence about a place, and a landscape claims the ones it holds by name in
## `BiomeDef.sites` — so adding a place to the game is adding a row here and a
## word in one landscape file, and no worldgen stage learns a new name.
##
## COMPOSED FROM PROPS THAT ALREADY EXIST, deliberately: a kind that needs a new
## model cannot land until somebody draws it, and this project has a long list of
## things declared and never claimed. Every row below can be built today.

## What a site may stand on, beyond its landscape saying it holds one. `&""` is
## anywhere the landscape puts it.
## A site that lays no patch of its own and stands on whatever is already there.
const KEEP := -1

const ANY := &""

## What a place may be BEHIND: the thing a player needs before it is theirs.
## These are the game's own existing walls, never new ones — deep water is
## `Swim`, a drop is `Jump`, and a pressure is `Hazards` answered by gear.
const OPEN := &"open"
const WATER := &"water"
const HEIGHT := &"height"
const PRESSURE := &"pressure"

## Every place a landscape can hold.
##
##   ground   the patch it lays under itself, or KEEP for none (it stands on what
##            is already there). A patch is what makes a site read as a PLACE
##            from across a valley rather than as props on grass.
##   radius   the patch's own reach, in tiles
##   wants    the ground it looks for, or ANY
##   props    [[kind, count, spread], ...] — what stands there. `spread` is in
##            tiles from the middle, so a thing with a small spread is a heap and
##            a thing with a large one is a scatter.
##   holds    what walking there is FOR, in the economy's own words. A place that
##            holds nothing is scenery, and scenery is what we already had.
##   behind   the wall in front of it (OPEN, WATER, HEIGHT, PRESSURE)
##   guard    how much of the plan is already standing there, 0..1: nothing, a
##            worker on its round, a keeper's own picket
##   clear    tiles it keeps from a village, so a place is a walk and not a
##            doorstep
const ROWS := {
	# --- what the machines left ------------------------------------------------
	&"tip": {
		"ground": KEEP, "radius": 6.0, "wants": ANY,
		"props": [[PropKind.DEBRIS, 7, 5.0], [PropKind.WRECKAGE, 2, 4.0], [PropKind.BARRICADE, 2, 5.0]],
		"holds": &"plate", "behind": OPEN, "guard": 0.0, "clear": 22.0,
	},
	&"quarry": {
		# A face cut into rising ground and left open, with the seam still showing.
		# The ore is the reason and the cut is the barrier: what is worth taking is
		# in the face, and the face is a drop.
		"ground": Ground.SCREE, "radius": 7.0, "wants": ANY,
		"props": [[PropKind.STONE_ORE, 4, 5.0], [PropKind.IRON_ORE, 3, 5.0],
			[PropKind.DEBRIS, 3, 6.0], [PropKind.CONVEYOR, 1, 3.0]],
		"holds": &"iron", "behind": HEIGHT, "guard": 0.25, "clear": 26.0,
	},
	&"sump": {
		# A works the ground took back. Everything worth having is under the water,
		# which is the raft's first real reason to exist outside a crossing.
		"ground": Ground.MUD, "radius": 8.0, "wants": ANY,
		"props": [[PropKind.PUMP_HOUSE, 1, 2.0], [PropKind.PIPE, 3, 6.0],
			[PropKind.DEBRIS, 4, 7.0], [PropKind.REEDS, 6, 8.0]],
		"holds": &"copper", "behind": WATER, "guard": 0.1, "clear": 24.0,
	},
	&"picket": {
		# The plan standing on something it does not want walked through. This is
		# the kind that is a CHALLENGE before it is anything else, and the only one
		# whose guard is near certain.
		"ground": Ground.GRAVEL, "radius": 5.0, "wants": ANY,
		"props": [[PropKind.CHECKPOINT, 1, 0.0], [PropKind.RELAY, 1, 3.0],
			[PropKind.FENCE, 6, 5.0], [PropKind.LAMP, 2, 4.0]],
		"holds": &"record", "behind": OPEN, "guard": 0.9, "clear": 30.0,
	},
	# --- what people left -------------------------------------------------------
	&"camp": {
		# People living rough outside anybody's village: a fire, a shelter, a bench.
		# The one place in the list whose reason is a PERSON, which is the story's
		# door into a region that has no settlement in it at all.
		"ground": KEEP, "radius": 5.0, "wants": ANY,
		"props": [[PropKind.FIRE, 1, 0.0], [PropKind.SHACK, 1, 2.5],
			[PropKind.BENCH, 1, 2.0], [PropKind.DEBRIS, 2, 4.0]],
		"holds": &"", "behind": OPEN, "guard": 0.0, "clear": 34.0,
	},
	&"cache": {
		# Somebody hid something and did not come back. Small, unmarked, and worth
		# the most of anything in the list — a place you only find by looking.
		"ground": KEEP, "radius": 2.5, "wants": ANY,
		"props": [[PropKind.CAIRN, 1, 0.0], [PropKind.DEBRIS, 1, 2.0]],
		"holds": &"salvage_kit", "behind": OPEN, "guard": 0.0, "clear": 28.0,
	},
	&"memorial": {
		# What a place remembers. Holds nothing and is not meant to: it is a reason
		# to stop, and what it says is the story's.
		"ground": KEEP, "radius": 3.5, "wants": ANY,
		"props": [[PropKind.MEMORIAL, 1, 0.0], [PropKind.GRAVE, 3, 3.0],
			[PropKind.STANDING_STONE, 1, 3.0]],
		"holds": &"", "behind": OPEN, "guard": 0.0, "clear": 20.0,
	},
	# --- what the land does on its own ------------------------------------------
	&"stone_circle": {
		"ground": KEEP, "radius": 5.0, "wants": ANY,
		"props": [[PropKind.STANDING_STONE, 7, 4.5]],
		"holds": &"", "behind": OPEN, "guard": 0.0, "clear": 26.0,
	},
	&"ruin": {
		"ground": KEEP, "radius": 5.5, "wants": ANY,
		"props": [[PropKind.RUIN, 2, 3.0], [PropKind.DEBRIS, 3, 5.0], [PropKind.BUSH, 3, 5.0]],
		"holds": &"plate", "behind": OPEN, "guard": 0.0, "clear": 24.0,
	},
	&"fumarole": {
		# A place that presses a body the whole time it is being worked, which is
		# the pressure system earning its keep as a barrier rather than a gauge.
		"ground": Ground.ASH, "radius": 5.0, "wants": ANY,
		"props": [[PropKind.VENT, 2, 4.0], [PropKind.VENT_CAP, 1, 3.0], [PropKind.BOULDER, 3, 5.0]],
		"holds": &"", "behind": PRESSURE, "guard": 0.0, "clear": 24.0,
	},
	&"den": {
		# Something lives here. The reason is what it is sitting on; the challenge
		# is that it is sitting on it.
		"ground": KEEP, "radius": 4.0, "wants": ANY,
		"props": [[PropKind.BONES, 4, 3.5], [PropKind.BOULDER, 3, 4.0], [PropKind.STUMP, 2, 4.0]],
		"holds": &"", "behind": OPEN, "guard": 0.0, "clear": 26.0,
	},
}


## Every kind there is, for a test and for whoever places them.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in ROWS:
		out.append(StringName(k))
	return out


static func has(id: StringName) -> bool:
	return ROWS.has(id)


static func row(id: StringName) -> Dictionary:
	return ROWS.get(id, {})


## How many of a kind a REGION of this many tiles holds, given what the landscape
## declared. The declared number is per CHAPTER — a region big enough to be one —
## and everything else is a share of that, so a spur gets one and a landscape you
## cannot cross in a minute gets a landscape's worth.
##
## This is the line that answers "a bigger region was a bigger empty one": the
## count is no longer per island, per TYPE, absolute, which is what it was when
## the whole world was one island and every landscape was two screens across.
const CHAPTER_TILES := 42000.0

static func want(declared: int, region_tiles: int) -> int:
	if declared <= 0:
		return 0
	var share := float(region_tiles) / CHAPTER_TILES
	return maxi(1, roundi(float(declared) * share))
