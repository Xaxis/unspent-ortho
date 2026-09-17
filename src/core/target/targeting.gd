class_name Targeting
## Who the player can put the slate's scan on, and in what order (owner,
## 2026-09-16). Pure: the system (42_target) hands it bodies and a place to
## look from, and it answers with a list; nothing here draws or reads input.
##
## Targeting never changes a fight. It does not aim a blow, slow a body or
## hold one still: it is the player asking the slate what something is, and
## the camera leaning in while they ask.
##
##   Targeting.candidates(bodies, from, reach)   what may be locked, in order
##   Targeting.pick(candidates, held)            the one a fresh hold locks
##   Targeting.cycle(candidates, held, dir)      the next one along
##
## The order is what a person would look at first: whatever is coming for them,
## then whatever is near. Distance breaks ties, so the list never shuffles while
## a body walks past another.

## How far the slate reads a body at all (tiles). A scanner lens carries further.
const REACH := 22.0
const LENS_REACH := 30.0
## Bodies read at once in a sweep: a field, not a census. A field bigger than
## this is paged with the same keys that cycle a lock, so nothing is unreachable.
const SWEEP_MOST := 8
## A lock held on a subject that has left the list waits this long for it to come
## back (seconds): a machine behind a house for a moment is the same machine.
const LOST_GRACE := 1.5
## Where a person sits in the order: below anything in the fight, and further down
## the further off they are. A villager is not a threat and never sorts like one.
const THREAT_PERSON := -1000.0
## What each thing about a body adds when the list is ordered. Coming for you
## outweighs everything; a body that has not noticed you sits at the bottom.
const THREAT_ATTACKING := 100.0
const THREAT_CHASING := 70.0
const THREAT_AWARE := 40.0
const THREAT_STIRRED := 20.0
const THREAT_HOSTILE := 10.0
## Every tile of distance takes this much off, so near beats far at the same rung.
const THREAT_PER_TILE := 1.0


## How far the slate reads, with what the player is wearing on.
static func reach_with(has_lens: bool) -> float:
	return LENS_REACH if has_lens else REACH


## The bodies that may be locked, nearest threat first. `bodies` are MobStates
## (alive, not removed); `from` is the player.
static func candidates(bodies: Array, from: Vector2, reach: float = REACH, people: Array = []) -> Array[TargetSubject]:
	var out: Array[TargetSubject] = []
	for b: Variant in bodies:
		var m := b as MobState
		if m == null or not m.alive or m.removed:
			continue
		if m.pos.distance_to(from) > reach:
			continue
		out.append(TargetSubject.from_body(m))
	for i in people.size():
		var row: Dictionary = people[i]
		var at: Vector2 = row.get("pos", Vector2.INF)
		if not at.is_finite() or at.distance_to(from) > reach:
			continue
		out.append(TargetSubject.from_folk(row, i))
	out.sort_custom(func(a: TargetSubject, c: TargetSubject) -> bool:
		var ta := threat_of(a, from)
		var tc := threat_of(c, from)
		if is_equal_approx(ta, tc):
			# A stable order, so two subjects at one rung never swap as they move.
			return a.id < c.id
		return ta > tc)
	return out


## What the list is sorted by, for any subject: a person sits below every body.
static func threat_of(s: TargetSubject, from: Vector2) -> float:
	if s.body == null:
		return THREAT_PERSON - s.here().distance_to(from) * THREAT_PER_TILE
	return threat(s.body, from)


## What the list is sorted by: what it is doing about the player, less its distance.
static func threat(m: MobState, from: Vector2) -> float:
	var t := 0.0
	match m.mood:
		MobState.ATTACKING:
			t = THREAT_ATTACKING
		MobState.CHASING:
			t = THREAT_CHASING
		MobState.ALERTED:
			t = THREAT_AWARE
		_:
			t = THREAT_STIRRED if m.suspicion > 0.05 else 0.0
	if t <= 0.0 and not m.at_work() and m.row.get("hostile", true):
		t = THREAT_HOSTILE
	return t - m.pos.distance_to(from) * THREAT_PER_TILE


## The body a fresh hold locks: the one already held if it is still there
## (a lock survives a moment's loss of sight), else the first in the list.
static func pick(list: Array[TargetSubject], held: TargetSubject = null) -> TargetSubject:
	var again := same_in(list, held)
	if again != null:
		return again
	return list[0] if not list.is_empty() else null


## The subject in `list` that is the one already held (the list is rebuilt every
## frame, so it is a different wrapper round the same body or person).
static func same_in(list: Array[TargetSubject], held: TargetSubject) -> TargetSubject:
	if held == null:
		return null
	for s in list:
		if s.id == held.id:
			return s
	return null


## One step along the list from `held` (dir -1 left, +1 right), wrapping.
static func cycle(list: Array[TargetSubject], held: TargetSubject, dir: int) -> TargetSubject:
	if list.is_empty():
		return null
	var here := same_in(list, held)
	var at := list.find(here) if here != null else -1
	if at < 0:
		return list[0]
	return list[posmod(at + signi(dir), list.size())]


## What a sweep reads: one page of the list, SWEEP_MOST at a time, so a field of
## twenty is read in three pages rather than cut off at eight.
static func sweep(list: Array[TargetSubject], page: int = 0) -> Array[TargetSubject]:
	if list.is_empty():
		return []
	var pages := pages_of(list)
	var at := posmod(page, pages) * SWEEP_MOST
	return list.slice(at, mini(at + SWEEP_MOST, list.size()))


static func pages_of(list: Array) -> int:
	return maxi(1, ceili(float(list.size()) / float(SWEEP_MOST)))


## Where the camera leans to hold both the player and what they are reading: a
## point `share` of the way from the player toward the body, never further than
## `most` tiles, so a body across the island does not pull the frame off them.
static func focus_between(player: Vector2, body: Vector2, share: float, most: float) -> Vector2:
	var to := body - player
	var by := to * share
	if by.length() > most:
		by = by.normalized() * most
	return player + by


## The middle of a field, for the sweep's frame.
static func centre_of(list: Array, player: Vector2) -> Vector2:
	if list.is_empty():
		return player
	var sum := Vector2.ZERO
	for s: TargetSubject in list:
		sum += s.here()
	return sum / float(list.size())
