class_name RaidStage
## The four steps the plan takes against a holding, and what each one is
## (docs/VISION.md §9.4). Pure data and the arithmetic over it.
##
##   survey   one machine comes, looks, and leaves a stake in the ground
##   probe    two come, take something, and test the wall
##   raid     a party with a purpose: breach, harvest, snatch
##   siege    the region's own keeper leads what is left of its force
##
## **Every step is warned before it lands.** `warn_minutes` is the world time
## between the warning the world gives — horizon lights, a drone at dusk, the
## radio going wrong, birds up — and the machines arriving. That window is the
## whole of what makes a raid answerable: it is long enough to fortify, to take
## the people off the pieces, to kill the mast, to fire the signet, or to walk
## away and come back to whatever is left. A step that arrived with its warning
## would be a step nobody could answer, which is the one thing this system is
## not allowed to be.

const SURVEY := &"survey"
const PROBE := &"probe"
const RAID := &"raid"
const SIEGE := &"siege"

const ORDER: Array[StringName] = [SURVEY, PROBE, RAID, SIEGE]
## Attention at which each step becomes due (Attention: 0..1, 1 is the keeper).
const AT: Array[float] = [0.22, 0.45, 0.70, 1.0]
## World minutes between the world's warning and the machines.
const WARN: Array[float] = [25.0, 45.0, 75.0, 110.0]
## Bodies in the party (the keeper of the region is extra, at a siege).
const PARTY: Array[int] = [1, 2, 3, 4]
## World minutes a party stays once it is there, when the player is present to
## fight it. It is how long they have to be answered in, and a raid that ran out
## before anybody could reach it would answer itself.
const MINUTES: Array[float] = [20.0, 70.0, 190.0, 260.0]
## How hard it comes: the damage the party brings to bear on what it targets,
## before the holding's own defences take their share.
const FORCE: Array[float] = [0.0, 6.0, 26.0, 60.0]
## What paying the step costs the plan, taken off attention once it is over. A
## survey confirms and spends nothing, which is why a surveyed place goes on
## heating up; a raid spends most of what brought it.
const SPENDS: Array[float] = [0.0, 0.06, 0.30, 0.55]
## Under this share of the attention that brought it, a step is called off at the
## warning: the place went dark, or the signet answered for it, and the machines
## that were coming have nothing to come for.
const CALLED_OFF_UNDER := 0.8
## A step never begins on a holding that gives off less than this at the moment
## the party would arrive. This is what evacuating and running dark BUY: not a
## better roll, but the machines turning round.
const NEEDS_SIGNATURE: Array[float] = [0.05, 0.08, 0.10, 0.12]


static func index(stage: StringName) -> int:
	return ORDER.find(stage)


## The step a holding at this attention is due, or -1 for a place nothing has
## decided anything about yet.
static func due_at(attention: float) -> int:
	var out := -1
	for i in AT.size():
		if attention >= AT[i]:
			out = i
	return out


static func name_of(i: int) -> StringName:
	return ORDER[clampi(i, 0, ORDER.size() - 1)]


static func warn_minutes(stage: StringName) -> float:
	return WARN[clampi(index(stage), 0, WARN.size() - 1)]


static func party_size(stage: StringName) -> int:
	return PARTY[clampi(index(stage), 0, PARTY.size() - 1)]


## World minutes it lasts, once it has arrived.
static func minutes(stage: StringName) -> float:
	return MINUTES[clampi(index(stage), 0, MINUTES.size() - 1)]


static func force(stage: StringName) -> float:
	return FORCE[clampi(index(stage), 0, FORCE.size() - 1)]


static func spends(stage: StringName) -> float:
	return SPENDS[clampi(index(stage), 0, SPENDS.size() - 1)]


static func needs_signature(stage: StringName) -> float:
	return NEEDS_SIGNATURE[clampi(index(stage), 0, NEEDS_SIGNATURE.size() - 1)]


## The region's keeper leads this one (docs/VISION.md §9.7).
static func led_by_keeper(stage: StringName) -> bool:
	return stage == SIEGE


## What the world does to say a step is coming. The warning is never a line of
## UI on its own: it names a thing that happens out there, which the systems that
## own those things draw and sound.
##
##   survey  lights on the horizon, along the bearing the plan surveyed
##   probe   something small over the yard at dusk
##   raid    the radio goes wrong, and the birds go up
##   siege   the keeper's own note, from a long way off
const WARNINGS := {
	SURVEY: {"sfx": &"raid_horizon", "says": "Lights out along the survey line, and they do not move."},
	PROBE: {"sfx": &"raid_drone", "says": "Something small crosses the yard, twice, and goes."},
	RAID: {"sfx": &"raid_static", "says": "The set is all static, and every bird in the place is up."},
	SIEGE: {"sfx": &"raid_keeper", "says": "One long note over the land. The people stop working to listen."},
}


static func warning(stage: StringName) -> Dictionary:
	return WARNINGS.get(stage, {})


## What it is, when it is on the way, in the world's own words.
static func says_coming(stage: StringName) -> String:
	match stage:
		SURVEY: return "Something is coming to look at %s."
		PROBE: return "Something is coming to try %s."
		RAID: return "They are coming for %s."
		SIEGE: return "The keeper of this land is coming for %s."
	return "Something is coming to %s."
