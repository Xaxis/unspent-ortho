class_name CraftKinds
## Every craft, as data (docs/VISION.md). A craft is a thing a person makes
## out of machine parts and then stands on: it opens ground a body cannot cross
## and it can be lost or wrecked.
##
## A craft is NOT a second movement system. All a row here says is what the body
## may cross while it carries them and how fast it goes; the fight simulation
## still moves the body (`Hero.ride` -> `WorldQuery.move_body`), so a blow, a
## dodge, a grip and a shoulder all land on the deck exactly as they do on foot.
##
## A row:
##   name: String          what the player sees (the item's display name is Items')
##   opens: String         why it exists, for the docs and the slate
##   grounds: Array[int]   Ground ids it travels over. Nothing else: a raft on
##                         land is a beached raft, so the shore stops it the way
##                         deep water stops a walker
##   levels: int           how many levels it may step (a walker rig takes a cliff)
##   walk/run: float       tiles per second, in place of Hero.ground_speed
##   hull: float           what it can take before it wrecks
##   wear: {ground: float} hull lost per tile over that ground
##   wear_any: float       hull lost per tile over anything else
##   wear_step: float      hull lost for each level it climbs or drops
##   launch: float         tiles from the body a craft may be set down or stepped off
##   afloat: bool          it needs water under it: launched past the shallows,
##                         and a wreck sinks in deep water instead of being left
##   sit: float            world units the drawing is dropped by, so a hull floats
##                         at its own waterline
##   stand: float          world units the body riding is raised by: the height of
##                         the deck it is standing on, above the ground
##   salvage: {item: n}    what a wreck gives back to the hands that made it
const LIST := {
	&"raft": {
		"name": "raft",
		"opens": "rivers, the coast, drowned streets",
		"grounds": [Ground.WATER, Ground.DEEP_WATER, Ground.RIVER, Ground.BLACKWATER],
		# Water is water: the sea floor under it is nothing a float has to climb.
		"levels": 6,
		# WHAT IT SOUNDS LIKE UNDERFOOT. Lashed timber, so a step on the deck is
		# timber and not the water it is floating on -- which is what you heard
		# before, because a footfall was keyed on the TILE and a raft is not one
		# (task #140). Unset on a craft means the ground shows through, which is
		# the right answer for a sled that hovers over it rather than a deliberate
		# gap: declare one only where the body is really standing on the craft.
		"step": &"wood",
		"walk": 2.2, "run": 3.2,
		"hull": 100.0,
		"wear": {Ground.WATER: 0.4, Ground.RIVER: 0.3, Ground.DEEP_WATER: 0.08, Ground.BLACKWATER: 0.25},
		"wear_any": 0.4, "wear_step": 0.0,
		"launch": 3.0,
		"sit": -0.06, "stand": 0.36,
		"afloat": true,
		"salvage": {&"driftwood": 2, &"scrap": 1},
	},
	&"hover_sled": {
		"name": "hover sled",
		"opens": "bog, salt, ice and black water at speed",
		# Everything a body can stand on, and the open sea is the raft's.
		"grounds": [],
		"levels": 1,
		"walk": 4.4, "run": 6.8,
		"hull": 140.0,
		"wear": {Ground.SCREE: 0.5, Ground.ROCK: 0.3, Ground.CLINKER: 0.5, Ground.SWARF: 0.6,
			Ground.WATER: 0.2, Ground.BLACKWATER: 0.2, Ground.RIVER: 0.2},
		"wear_any": 0.06, "wear_step": 0.4,
		"launch": 2.2,
		"sit": 0.0, "stand": 0.24,
		"afloat": false,
		"salvage": {&"scrap": 2, &"iron": 1},
	},
	&"walker_rig": {
		"name": "walker rig",
		"opens": "cliffs, scree and deep snow under a load",
		"grounds": [],
		# The whole point of legs: two levels is a cliff to a body and a stride to this.
		"levels": 2,
		"walk": 3.0, "run": 4.2,
		"hull": 200.0,
		"wear": {Ground.SCREE: 0.15, Ground.SWARF: 0.2},
		"wear_any": 0.08, "wear_step": 1.5,
		"launch": 2.2,
		"sit": 0.0, "stand": 0.0,
		"afloat": false,
		"salvage": {&"scrap": 3, &"iron": 1},
	},
}

## A craft the player carries is the item of the same id: one name for the bundle
## of spars, drums and plate and for the thing it becomes.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in LIST:
		out.append(id)
	return out


static func row(kind: StringName) -> Dictionary:
	return LIST.get(kind, {})


static func known(kind: StringName) -> bool:
	return LIST.has(kind)


static func display_name(kind: StringName) -> String:
	return String(row(kind).get("name", String(kind)))


static func hull(kind: StringName) -> float:
	return float(row(kind).get("hull", 100.0))


static func launch_reach(kind: StringName) -> float:
	return float(row(kind).get("launch", 2.2))


## World units the drawing sits below the ground: a raft's drums are half under
## the water it floats in, so the deck comes up under a body's feet.
static func sit(kind: StringName) -> float:
	return float(row(kind).get("sit", 0.0))


## How high the body riding stands above the ground: the deck under its feet. A
## walker rig is nothing: a body stands inside that one, on its own feet.
static func stand(kind: StringName) -> float:
	return float(row(kind).get("stand", 0.0))


## The footfall family a body standing on this craft's deck makes, or &"" when
## the craft has not claimed one and the ground underneath should be heard.
static func step_family(kind: StringName) -> StringName:
	return row(kind).get("step", &"")


static func afloat(kind: StringName) -> bool:
	return bool(row(kind).get("afloat", false))


static func salvage(kind: StringName) -> Dictionary:
	return row(kind).get("salvage", {})


## What the fight and the world query read while this craft carries a body.
static func ride(kind: StringName) -> CraftRide:
	var r := row(kind)
	if r.is_empty():
		return null
	var out := CraftRide.new()
	out.kind = kind
	for g: int in (r.get("grounds", []) as Array):
		out.grounds[g] = true
	out.levels = int(r.get("levels", 1))
	out.walk = float(r.get("walk", Tuning.WALK_SPEED))
	out.run = float(r.get("run", Tuning.RUN_SPEED))
	return out
