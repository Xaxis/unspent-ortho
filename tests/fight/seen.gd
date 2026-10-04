extends RefCounted
## WHAT A PERSON SEES OF A MACHINE, the one place the readers read a body's
## motion from. A reader decides on what is drawn: where the body stands and
## faces, the phase of a tell as its windup and strike show it, its lamps, a run
## under way. It never decides on the brain's own clocks and flags. Twice a
## reader decided on hidden run state and measured fights nobody plays: a run's
## tell read where the body stood rather than where the run carries it (#6), and
## a stand with its bite told read as the pause between runs (#26), so the
## readers walked into the bite. tests/fight/test_seen.gd holds the readers'
## sources to this file.

## Faster than this a body is visibly coming on, not standing or creeping
## (FightSim's own line between a standing body and a moving one).
const RUN_SEEN := 1.0


## A run under way: a charge coming on at a run, as it is drawn.
static func running(m: MobState) -> bool:
	return m.charging and m.speed > RUN_SEEN


## A blow told and not yet over: the windup and strike poses.
static func telling(m: MobState, now: float) -> bool:
	return m.blow != null and m.blow_phase(now) in [&"windup", &"active"]


## Standing: not coming on.
static func standing(m: MobState) -> bool:
	return m.speed <= RUN_SEEN


## Which way a run under way is carrying it: the line it is seen to move along.
static func heading(m: MobState) -> Vector2:
	return m.bearing
