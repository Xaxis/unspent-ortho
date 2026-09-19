class_name Escort
extends RefCounted
## WALKING SOMEBODY HOME after the yard that held them has gone dark
## (docs/VISION.md §9.5; owner's sub-arc goals; agreed with the story seat
## 2026-09-18).
##
## THE FIRST THING IN THIS GAME THAT CAN FAIL SLOWLY, and that is the whole
## reason it exists. A raid is warned and settled, a fight is decided in seconds,
## a chapter is answered or it is not — every failure the game had was an event.
## An escort is minutes long and the danger is the WALK, not the destination: the
## interesting version is the one where he gets them out of the yard and does not
## get them home, which is why `TakenPerson.lost` is a state and not a grade.
##
## WHAT THIS FILE IS. Rules over plain data — a destination, a distance, a
## patience — and nothing else. It holds no nodes, reads no `Game`, moves nobody
## and draws nothing: 45_taken stands the person up and 35_folk walks them, the
## same split the harvest package keeps between the rule, the placement and the
## drawing. So every number below can be argued with in a test.
##
## WHERE THEY ARE WALKING TO, in order, and the last rung is the one that makes
## this reachable at all:
##
##   1. their own holding, if it still stands
##   2. the nearest holding that does
##   3. THE VILLAGE THEY CAME OUT OF, by name
##
## Three was missed by both of us until the staging was read. A person taken by a
## raid comes off a player's holding and has an index; a person the world starts
## out already holding (`--carried`) has `home = -1` and only a village NAME, and
## in a fresh game there are no holdings at all. Without rung three the escort
## could never be offered in the one world anybody would test it in — the rescue
## would be written, staged, and unreachable. It is also the better fiction:
## "somebody out of Oyster Row" walks back to Oyster Row, and a village is the
## one roof in this game that cannot be razed.
##
## The destination is fixed when the walk is ACCEPTED and never recomputed. If
## the roof they were walking toward is razed on the way, that is a thing that
## happened to them and there are words for it; a target that quietly slides to
## the next village makes the walk mean nothing and every line about it a lie.

## How far behind he may leave them, in tiles, and how long they may be that far
## before they are lost. The two are one decision: a hard distance alone loses
## somebody to a doorway or a rock, and the grace is what makes it a choice he
## made rather than a corner he cut badly.
##
## 22 is past the frame's own reach (the play camera shows about 26 x 18 tiles),
## so they are never lost while he can still see them — losing somebody on screen
## would read as a bug however correct it was.
const LOSE_TILES := 22.0
const LOSE_SECONDS := 12.0

## Near enough to the door. Generous, because arriving is not the interesting
## part and a person stuck on a doorstep is only annoying.
const HOME_REACH := 6.0

## How fast they walk, as a share of the player's own pace. Under 1 on purpose:
## they have been in a yard, and a person who keeps up perfectly is a camera
## attachment rather than somebody being helped.
const PACE := 0.82

## What the walk is doing this instant.
const WALKING := &"walking"
const BEHIND := &"behind"
const LOST := &"lost"
const HOME := &"home"


## Where a freed person is walking to, given the holdings that still stand and
## the world's villages. `Vector2.INF` when there is nowhere — and then the walk
## is never offered, the same rule the yard keeps: never raise what cannot be
## answered.
##
## `holdings` is an array of `{pos: Vector2, standing: bool, index: int}` and
## `villages` of `{pos: Vector2, name: String}`, so this stays arguable without a
## running game.
static func destination(holdings: Array, villages: Array, t: Taken.TakenPerson) -> Vector2:
	if t == null:
		return Vector2.INF
	for h: Dictionary in holdings:
		if int(h.get("index", -1)) == t.home and bool(h.get("standing", false)):
			return h.get("pos", Vector2.INF)
	var best := Vector2.INF
	var near := INF
	var from: Vector2 = t.at if t.at.is_finite() else Vector2.ZERO
	for h: Dictionary in holdings:
		if not bool(h.get("standing", false)):
			continue
		var p: Vector2 = h.get("pos", Vector2.INF)
		if not p.is_finite():
			continue
		var d := p.distance_to(from)
		if d < near:
			near = d
			best = p
	if best.is_finite():
		return best
	return village_named(villages, t.home_name)


## The village of that name, or INF. Matched on the name because that is the only
## thing the record keeps about where somebody came from — an index into
## `world.villages` would be a second answer to the same question, and the name
## is what gets said out loud anyway.
static func village_named(villages: Array, what: String) -> Vector2:
	if what == "":
		return Vector2.INF
	for v: Dictionary in villages:
		if str(v.get("name", "")) == what:
			return v.get("pos", Vector2.INF)
	return Vector2.INF


## What the walk is doing, given where they are, where they are going, where he
## is, and how long they have already been too far behind. Pure; the caller keeps
## the clock and hands it back.
static func read(at: Vector2, to: Vector2, player: Vector2, behind_for: float) -> StringName:
	if to.is_finite() and at.distance_to(to) <= HOME_REACH:
		return HOME
	if at.distance_to(player) <= LOSE_TILES:
		return WALKING
	return LOST if behind_for >= LOSE_SECONDS else BEHIND


## How long they have been too far behind, after `delta` more. Kept here with the
## bar it is measured against, so the two cannot drift apart in a caller.
static func behind_after(at: Vector2, player: Vector2, behind_for: float, delta: float) -> float:
	if at.distance_to(player) <= LOSE_TILES:
		return 0.0
	return behind_for + delta
