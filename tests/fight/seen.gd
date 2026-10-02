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

## Faster than this a body is seen moving. A run told from close in eases to a
## creep (FightSim), and a person still sees it creeping at them along its line.
## Read as standing, an eased run's bite caught readers who would have stepped
## out of its row (tests/sentinel/test_ways, the lock fights).
const RUN_SEEN := 0.1


## A run under way: a charge coming on along its line, however slowly, as it is drawn.
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
