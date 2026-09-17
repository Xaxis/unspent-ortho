class_name RaidRoles
## What each machine in a party came for, and which piece of the holding it goes
## at (docs/VISION.md §9.5). Pure rules over a `Settlement`.
##
## The pillar this file keeps: **a party targets what MAKES the signature**, so
## the player's own build decides the fight. A holding given away by its mast is
## a holding whose mast is walked to first, by a machine that ignores the walls
## on its way to it; a holding given away by its stolen cell loses the cell. That
## is the loop closing — the seven bars the slate already draws are not a readout,
## they are the machines' shopping list.
##
##   scout      looks, marks, and leaves (a survey; the probe's eyes)
##   breacher   the wall between it and the rest: the highest defence standing
##   harvester  the loudest piece that is not a wall
##   snatcher   the people

const SCOUT := &"scout"
const BREACHER := &"breacher"
const HARVESTER := &"harvester"
const SNATCHER := &"snatcher"

## Who comes, per step, in the order they are given their targets. A survey is
## one pair of eyes; a probe is eyes and one pair of hands; a raid is the three
## trades; a siege is all of them twice over, and the keeper.
const BY_STAGE := {
	RaidStage.SURVEY: [SCOUT],
	RaidStage.PROBE: [SCOUT, HARVESTER],
	RaidStage.RAID: [BREACHER, HARVESTER, SNATCHER],
	RaidStage.SIEGE: [BREACHER, BREACHER, HARVESTER, SNATCHER],
}

## Share of the party's force each trade brings to what it targets.
const SHARE := {
	SCOUT: 0.0,
	BREACHER: 0.5,
	HARVESTER: 0.35,
	SNATCHER: 0.15,
}

## A harvester will take this much out of the stores instead of breaking
## anything, if the holding has it laid by. Leaving a full store out is paying
## them off: it is a real answer, and it is expensive.
const TRIBUTE := 8.0


static func roles_for(stage: StringName) -> Array:
	return BY_STAGE.get(stage, [SCOUT])


## The roster kind that takes this trade here. Chosen by what a body IS rather
## than from a list of names, so a landscape that brings its own roster is raided
## by its own machines with no edit in this file.
##
## `fits` is asked of every candidate first (the world and the hour), and only if
## nothing in the whole roster fits does a trade fall back to the best body for
## the job wherever it stands: a party the plan decided to send is sent.
static func kind_for(role: StringName, fits: Callable = Callable()) -> StringName:
	var best: StringName = &""
	var best_score := -INF
	var loose: StringName = &""
	var loose_score := -INF
	for kind: StringName in Roster.kinds():
		var row := Roster.row(kind)
		if not row.get("machine", false) or row.get("sentinel", &"") != &"":
			continue
		var score := score_for(role, row)
		if score <= -INF:
			continue
		if score > loose_score:
			loose_score = score
			loose = kind
		if fits.is_valid() and not bool(fits.call(kind, row)):
			continue
		if score > best_score:
			best_score = score
			best = kind
	return best if best != &"" else loose


## How well a body suits a trade. A breacher is whatever hits hardest; a
## harvester is one of the plan's own working machines; a snatcher is whatever
## is fastest at coming over, taking and going.
static func score_for(role: StringName, row: Dictionary) -> float:
	var bite: Dictionary = row.get("bite", {})
	var dmg := float(bite.get("dmg", 0))
	var reach := float(bite.get("reach", 0.0))
	var dart: bool = row.get("approach", &"") == &"dart"
	match role:
		BREACHER:
			if dmg <= 0.0:
				return -INF
			return dmg * 2.0 + reach + float(row.get("life", 0)) * 0.03
		HARVESTER:
			if Roles.of_row(row) != Roles.WORKER:
				return -INF
			return float(row.get("life", 0)) * 0.05 + dmg
		SNATCHER:
			if not dart and not row.get("hits", {}).has("minutes"):
				# Anything that will run somebody down instead.
				return float(row.get("dash", 0.0)) * 0.1
			return 10.0 + float(row.get("dash", 0.0)) * 0.1
		SCOUT:
			if Roles.of_row(row) != Roles.WATCHER:
				return -INF
			return float(row.get("sees", 0))
	return -INF


# --- what it goes for --------------------------------------------------------

## The piece a breacher walks to: the strongest thing still standing between the
## yard and the outside. Nothing defended, and it goes for the shelter instead,
## because a holding with no wall is a holding whose roof is the wall.
static func breach_target(s: Settlement) -> int:
	var best := -1
	var top := 0.0
	for p in s.pieces:
		if not p.standing():
			continue
		var d := StructureKind.defence(p.kind) * p.condition()
		if d > top:
			top = d
			best = p.id
	if best >= 0:
		return best
	return _biggest_of_family(s, StructureKind.Family.SHELTER)


## The piece a harvester walks to: whatever is shouting loudest. The channel is
## the holding's own `loudest()`, so what the slate names on its page is the
## thing that gets taken apart.
static func harvest_target(s: Settlement) -> int:
	var loudest := s.signature().loudest()
	var best := -1
	var top := 0.0
	for p in s.pieces:
		if not p.standing() or StructureKind.is_defence(p.kind):
			continue
		var signs := p.signs()
		var v := float(signs.get(String(loudest), 0.0)) * float(Signature.CARRY.get(loudest, 0.0))
		if v <= 0.0:
			# Not the channel that gave the place away, but it still gives off
			# something: worth a fraction, so a holding with nothing running is
			# not a holding nothing comes for.
			for c: StringName in Signature.CHANNELS:
				v = maxf(v, float(signs.get(String(c), 0.0)) * float(Signature.CARRY.get(c, 0.0)) * 0.25)
		if v > top:
			top = v
			best = p.id
	if best >= 0:
		return best
	# Nothing gives anything off: they take the stores, which means the store.
	var store := _biggest_of_family(s, StructureKind.Family.FOOD)
	return store if store >= 0 else _biggest_of_family(s, StructureKind.Family.SHELTER)


## Who a snatcher comes for: whoever is at work, first — the plan takes hands.
static func snatch_target(s: Settlement) -> int:
	for p in s.pieces:
		if p.standing() and p.staffed_by >= 0:
			return p.staffed_by
	return s.people[0] if not s.people.is_empty() else -1


## The target of one trade: a piece id for a breacher and a harvester, a person
## id for a snatcher, -1 for a scout (it came to look).
static func target_for(role: StringName, s: Settlement) -> int:
	match role:
		BREACHER: return breach_target(s)
		HARVESTER: return harvest_target(s)
		SNATCHER: return snatch_target(s)
	return -1


static func _biggest_of_family(s: Settlement, family: StructureKind.Family) -> int:
	var best := -1
	var top := 0.0
	for p in s.pieces:
		if not p.standing() or p.family() != family:
			continue
		var v := StructureKind.health(p.kind) * p.condition()
		if v > top:
			top = v
			best = p.id
	return best
