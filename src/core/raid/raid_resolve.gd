class_name RaidResolve
## What a party does to a holding, as pure arithmetic (docs/VISION.md-9.6).
##
## Two things call it and they must agree. When the player is standing in their
## own yard, 48_raids gives the party bodies and this file only says what each
## machine is for and how much a blow of theirs is worth. When the player is a
## day's walk away — which is a legitimate answer and always was — the same
## numbers settle the whole thing on paper, so coming home to a burnt plot is the
## same event, reached the same way, and never a different, cheaper one.
##
## Nothing here reads a clock or rolls for whether a raid happens. It is handed a
## holding, a step and a seed, and it says what is broken.
##
## The two paths agree about WALLS as well as about force: a blow thrown by a
## machine standing in the yard is scaled by the same `turned(defence_total)`
## that this file takes off a raid settled on paper (48_raids `_blow_of`). A
## second plate wall has to be worth the same afternoon whether the player is
## standing behind it or a day's walk away, or building one is only ever worth
## doing before leaving.

## A holding's defence is worth this much: what a party has to spend before
## anything it brings reaches a piece. Two plate walls (4.4) turn a probe aside
## and take a third of a raid.
const WALL := 9.0
## The most a wall can ever turn: a siege gets through, and that is the point of
## a siege. Walls buy pieces and time, never immunity.
const MOST_TURNED := 0.8
## Force a snatcher needs before it gets somebody out of the place.
const SNATCH_NEEDS := 6.0
## Wear is the raid's, not the weather's: a piece struck loses at least this, so
## nothing is ever "raided" and unmarked.
const LEAST := 1.0


## What `defence_total` buys: 0..MOST_TURNED of everything coming.
static func turned(defence: float) -> float:
	if defence <= 0.0:
		return 0.0
	return minf(MOST_TURNED, defence / (defence + WALL))


## The force that actually reaches the holding.
static func through(stage: StringName, defence: float) -> float:
	return RaidStage.force(stage) * (1.0 - turned(defence))


## Settle a whole raid on paper.
##
## `present` says the player was there to fight it: when they were, this is only
## ever called for what the party got done before it was over, with `force`
## already spent on the bodies that were killed. `seed_value` and `instance` make
## it the same raid every time the same game reaches it.
##
## Returns {broke: [piece ids], ruined: [piece ids], took: [person ids],
##          stores: {item: count}, outcome}.
static func resolve(s: Settlement, stage: StringName, seed_value: int, instance: int, share: float = 1.0) -> Dictionary:
	var out := {"broke": [] as Array[int], "ruined": [] as Array[int],
		"took": [] as Array[int], "stores": {}, "outcome": &"held"}
	if s == null:
		return out
	var force := through(stage, s.defence_total()) * clampf(share, 0.0, 1.0)
	if force <= 0.0:
		out["outcome"] = &"held"
		return out
	# Hands first: a harvester takes what is lying in the store and leaves the
	# store standing, which is what paying them off looks like from the outside.
	var tribute := take_stores(s, force)
	out["stores"] = tribute
	var paid := 0.0
	for k: Variant in tribute:
		paid += float(tribute[k])
	if paid >= RaidRoles.TRIBUTE:
		# They came for salvage and found it loose in the yard. Nothing is broken
		# and nobody is taken: the holding held, and it is poorer.
		out["outcome"] = &"held"
		return out
	force -= paid
	if force <= 0.0:
		out["outcome"] = &"held"
		return out
	var roles: Array = RaidRoles.roles_for(stage)
	var i := 0
	for role: StringName in roles:
		i += 1
		var mine: float = force * float(RaidRoles.SHARE.get(role, 0.0))
		if mine <= 0.0:
			continue
		if role == RaidRoles.SNATCHER:
			if mine < SNATCH_NEEDS:
				continue
			var who := RaidRoles.snatch_target(s)
			if who >= 0 and not (out["took"] as Array[int]).has(who):
				(out["took"] as Array[int]).append(who)
			continue
		var piece_id := RaidRoles.target_for(role, s)
		var p := s.piece(piece_id)
		if p == null or not p.standing():
			continue
		# A little of the party's own luck, so two raids on the same holding from
		# the same seed are not the same blow twice.
		var swing := 0.8 + 0.4 * Rng.hash01(seed_value, instance, 0x4A1D + i)
		var dealt := maxf(LEAST, mine * swing)
		var broken := p.damage(dealt)
		if not (out["broke"] as Array[int]).has(p.id):
			(out["broke"] as Array[int]).append(p.id)
		if broken:
			(out["ruined"] as Array[int]).append(p.id)
	out["outcome"] = outcome_of(s, out)
	return out


## Whatever is loose in the store, up to what the party can carry. The live
## harvester standing in the yard takes it through this same door (48_raids
## `_tribute`), so paying them off is one answer however it is reached.
static func take_stores(s: Settlement, force: float) -> Dictionary:
	# What lies in a cellar is out of reach (SETTLE.md S4): only what is over its
	# room is loose in the yard.
	var loose := maxf(0.0, s.stored() - s.kept_room())
	var want := minf(minf(RaidRoles.TRIBUTE, force), loose)
	var took := {}
	for id: Variant in s.stores.keys():
		if want <= 0.0:
			break
		var have := int(s.stores[id])
		if have <= 0:
			continue
		var n := mini(have, ceili(want))
		took[id] = n
		want -= float(n)
		if n >= have:
			s.stores.erase(id)
		else:
			s.stores[id] = have - n
	return took


## What the yard says happened. A holding with nothing left standing is razed and
## stays in the world as ruins to reclaim (46_settlements keeps a wreck where it
## fell); anything broken or anybody taken is `broken`; otherwise it held.
static func outcome_of(s: Settlement, report: Dictionary) -> StringName:
	if s.standing().is_empty() and not s.pieces.is_empty():
		return &"razed"
	if not (report.get("ruined", []) as Array).is_empty():
		return &"broken"
	if not (report.get("took", []) as Array).is_empty():
		return &"broken"
	if not (report.get("broke", []) as Array).is_empty():
		return &"broken"
	return &"held"


## Nobody was home and the place was dark: the party arrives, finds a signature
## under the step's floor, and goes. `left` is not a win — attention is barely
## spent — but nothing is lost either, and that is what evacuating buys.
static func nothing_here(s: Settlement, stage: StringName) -> bool:
	return s.signature().total() < RaidStage.needs_signature(stage)
