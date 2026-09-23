class_name TurretRules
## When a holding's turret shoots, at what, and how hard (owner, 2026-09-17,
## docs/VISION.md). Pure rules over the fight's own bodies; the system that
## runs them is 47_defences, and the blow itself is `FightSim.strike`, so a turret
## meets exactly the rules a swing does — the plate, the hit window, the stall.
##
## What it shoots is the whole of the design, so it is short and it is said:
##   a raider             anything the plan sent against a holding, first
##   a body in a fight    anything pressing an attack (chasing, attacking)
##   nothing else         a worker on its round, a watcher on its rise, a gull
##
## A turret that shot every machine that walked past would make the yard the
## loudest thing on the coast and turn every passing worker into a filed kill
## (32_disposition files a machine it did not send). It answers what comes FOR
## the place, which is the only thing a defence is for.

## Tiles it reaches: a yard's width, and short of what a machine sees from, so a
## turret is a thing to be drawn onto rather than a watchtower.
const REACH := 7.5
## Sim ms from taking a new target to the first shot. The head turns and the
## lens catches first: the tell a player (and a fight) can read, and the reason a
## body that darts through the yard is not simply deleted.
const AIM_MS := 520.0
## Sim ms between shots at the same body.
const EVERY_MS := 1400.0
## What a shot carries. A repeater's bolt: light, and it burns through plate (the
## machines built it to hurt machines), so where the turret stands decides
## nothing about sides — where the machine is decides whether it is in reach.
const DMG := 3
const KNOCK := 3.0
const KNOCK_MS := 140


static func blow() -> Blow:
	var b := Blow.new()
	b.windup = 0
	b.active = 0
	b.recovery = 0
	b.cooldown = 0
	b.dmg = DMG
	b.knock = KNOCK
	b.knock_ms = KNOCK_MS
	b.cuts = true
	b.verb = &"shot"
	return b


## A turret that could shoot now: standing, whole enough to work, armed and fed.
static func armed(p: Structure) -> bool:
	return p != null and p.kind == StructureKind.TURRET and p.working()


## How much a turret wants this body: 2 a raider, 1 a body pressing a fight, 0
## leave it be.
static func wants(m: MobState) -> int:
	if m == null or not m.alive or m.removed:
		return 0
	if m.raider:
		return 2
	if m.roused() and not m.indifferent():
		return 1
	return 0


## The body it should be shooting at from `from`, or null. Wanted most first,
## nearest among those, and only what `clear` (a line of sight) allows.
static func pick(bodies: Array, from: Vector2, clear: Callable = Callable()) -> MobState:
	var best: MobState = null
	var best_want := 0
	var best_d := INF
	for q: Variant in bodies:
		var m := q as MobState
		var want := wants(m)
		if want <= 0:
			continue
		var d := from.distance_to(m.pos)
		if d > REACH:
			continue
		if want < best_want or (want == best_want and d >= best_d):
			continue
		if clear.is_valid() and not bool(clear.call(m)):
			continue
		best = m
		best_want = want
		best_d = d
	return best


## Still worth shooting at: alive, wanted and in reach. A body that stops
## pressing, or steps out of reach, is let go of rather than chased with bolts.
static func keeps(m: MobState, from: Vector2) -> bool:
	return wants(m) > 0 and from.distance_to(m.pos) <= REACH
