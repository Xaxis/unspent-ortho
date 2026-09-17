class_name Notices
## How a machine comes to know a holding is there (docs/VISION.md §9.2), as pure
## rules over a `Signature` and one roster row.
##
## The whole of the raid system hangs off this file, so it is worth saying what
## it refuses to do. It never rolls to decide whether a place is noticed. A body
## noticed it or it did not: it was near enough, the channel carries that far,
## the reading beat the floor, and its role is one that reports. Every number
## below is a thing the player can change by building differently, and the
## holding app already draws the seven channels with the loudest one named, so a
## player can read the same number the machine reads before it ever arrives.
##
##   Notices.read(sig, holding, from, row)   what that body makes of the place
##   Notices.kind_of(row)                    what it is, in the world's own words
##   Notices.worth(notice)                   attention it files if it gets away

## How far the loudest possible channel carries (tiles). Every channel's reach is
## this times its `Signature.CARRY`, so a mast at full strength is heard across a
## whole valley and the noise of a forge is a local matter. A machine is culled
## by the coast at `Spawner.CULL` (24 tiles from the player), so the channels
## above that only ever matter to a player standing in their own holding — which
## is the point: the radio is what reaches the machine you never saw.
const CARRY_TILES := 34.0
## Below this a reading is not worth carrying home. A holding whose every channel
## reads under the floor at the range a body passed at is a holding nobody filed,
## and that is the reward for running dark.
const FLOOR := 0.1

## How good a reading each role takes. A watcher's whole trade is seeing and
## filing; a worker on its round notices the way anyone notices a light.
const READS := {
	&"watcher": 1.0,
	&"keeper": 0.8,
	&"hunter": 0.55,
	&"worker": 0.5,
	&"recycler": 0.4,
}

## A body must be at least this far from the holding before what it carries is
## clear of it: closer than this and the player can still catch it in their own
## yard. Beyond `GOT_AWAY` it has gone, whatever else happens.
const CLEAR_OF := 12.0
const GOT_AWAY := 30.0
## World minutes a carrier is given to get clear before a game that never looked
## at it again counts the record as filed. It is not a timer on the raid: it is
## the answer to "the player walked away and the carrier was culled", which
## otherwise leaves a reading in limbo for ever.
const HOME_MINUTES := 45.0


## What this body would call itself in a report (`Events.settlement_noticed`).
## Read off what the body IS rather than from a list of kinds, so a landscape
## that brings its own roster gets the right word with no edit here.
static func kind_of(row: Dictionary) -> StringName:
	var role := Roles.of_row(row)
	var dart: bool = row.get("approach", &"") == &"dart"
	if role == Roles.WATCHER:
		# A clerk comes in close, reads and runs; a watcher stands on its rise.
		return &"clerk" if dart else &"watcher"
	if dart:
		# Anything else that comes over, takes what it came for and goes.
		return &"drone"
	return &"worker"


## Does a body of this row report at all? Everything in the plan does — that is
## what a plan is — but a creature has no one to tell.
static func reports(row: Dictionary) -> bool:
	return bool(row.get("machine", false))


## How far a channel carries, in tiles.
static func reach(channel: StringName) -> float:
	return CARRY_TILES * float(Signature.CARRY.get(channel, 0.0))


## What a body at `from` makes of a holding at `to`: `{channel, strength}`, or an
## empty dictionary for a place it cannot read. The strongest single channel
## wins, weighed by how far that channel carries and by how well this role reads.
##
## `masked` is what the holding's own spoofing has already taken off (it is
## inside the Signature it is handed, so nothing is done with it here) — the one
## thing added on top is `blind`, 0..1, what the player's own spoofed signature
## does to a reading taken while they stand in the place.
static func read(sig: Signature, to: Vector2, from: Vector2, row: Dictionary, blind: float = 0.0) -> Dictionary:
	if sig == null or not reports(row):
		return {}
	var d := from.distance_to(to)
	var sees: float = READS.get(Roles.of_row(row), 0.5)
	var best: StringName = &""
	var top := 0.0
	for c: StringName in Signature.CHANNELS:
		var r := reach(c)
		if r <= 0.0 or d >= r:
			continue
		# Linear along the channel's own reach: at the edge it is nothing, and
		# under the holding's nose it is the whole of what the place gives off.
		var v := sig.get_channel(c) * (1.0 - d / r) * sees * (1.0 - clampf(blind, 0.0, 1.0))
		if v > top:
			top = v
			best = c
	if best == &"" or top < FLOOR:
		return {}
	return {"channel": best, "strength": clampf(top, 0.0, 1.0)}


## The attention a reading files when it gets home. A clerk's record is worth
## more than a worker's passing remark, because a clerk went and looked.
static func worth(n: Notice) -> float:
	var by: float = READS.get(Roles.of(n.carrier), 0.5) if n.carrier != &"" else 0.6
	return Attention.NOTICE_FULL * clampf(n.strength, 0.0, 1.0) * clampf(0.5 + by * 0.5, 0.0, 1.0)


## It is clear of the holding it read: far enough that the player cannot catch it
## in their own yard any more.
static func clear_of_holding(n: Notice, where: Vector2) -> bool:
	return where.distance_to(n.at) >= CLEAR_OF


## Nothing can stop it now.
static func got_away(n: Notice, where: Vector2) -> bool:
	return where.distance_to(n.at) >= GOT_AWAY


## Which way a carrier makes for: the bearing the machines surveyed this world
## along (GenWorks), so a player who follows one home is walking the plan's own
## line and not a random heading.
static func home_bearing(seed_value: int, from: Vector2, holding: Vector2) -> Vector2:
	var along := Vector2.from_angle(GenWorks.bearing(seed_value))
	var away := from - holding
	if away.length_squared() < 0.01:
		return along
	# Along the survey line, in whichever of its two directions leads away from
	# the place it just read.
	return along if along.dot(away.normalized()) >= 0.0 else -along
