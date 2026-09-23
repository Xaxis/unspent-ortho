class_name SentinelPhase
extends RefCounted
## One phase of a sentinel: what its body IS while it lasts (docs/VISION.md §3).
##
## A phase is a ROSTER ROW, not a script of special moves. Entering it rewrites
## the live body's own copy of its row — its working part, whether that part
## throws blows off, its bite, its speeds, how fast it comes round — so every
## reader the game already has tells the truth about it without knowing what a
## sentinel is: FightSim lands the new bite, Brains times the new tell, the Mob
## draws the new pose, and `TargetRead` reads the new part and the new powers off
## the same row while the player holds the key.
##
## That is the whole of the spine: a phase changes the body, and the body is the
## only thing anything reads.

## Which phase this is, for a save, a test and the sound it enters on.
var id: StringName = &""
## It begins at or below this share of full health (the first phase is 1.0).
var at := 1.0
## The working part while it lasts: front back left right. Never none — a
## sentinel with no side to find is a sentinel beaten by trading hits.
var part: StringName = &"front"
## That part throws a blow off like plate unless the machine is open: spent after
## a bite, stalled, or not yet roused (FightSim.reaches_part).
var guarded := false
## Its bite this phase, in the roster's shape: {swing: [windup, active, recovery,
## cooldown], reach, width, dmg, knock, knock_ms, grip}.
var bite: Dictionary = {}
## Tiles/s on the source's scale (FightRules.SPEED_SCALE is applied on the body),
## and `quick` the close-quarters speed x 100, as a roster row gives them.
var pace := 4.0
var dash := 8.0
var quick := 300
## Radians/s it comes round in. Every phase must leave the working side reachable
## by a player walking round it (tests/sentinel/test_phases.gd holds this).
var turn := 1.5
## A tell on the GROUND for this phase's bite: &"" (none — the body's own pose
## is the whole tell, as it is for every other machine) or &"ring", a pale ring
## drawn where the bite will land when its windup begins, for a blow that comes
## down from above rather than out of a limb. It is a picture and not a rule:
## 44_sentinels draws it over the box `FightRules.box_hits` will test, and
## FightSim lands the bite off `bite` exactly as it would with no tell at all.
var tell: StringName = &""
## Levels its body may step in one move while this phase lasts (the roster's
## `climbs`), or -1 to leave the row's own. A keeper that walks up scarps and is
## brought down off them says so here, so the phase that lames it also puts it
## back on a walker's one level (FightSim.climber).
var climbs := -1
## Why this phase exists and what the player is meant to read off the body:
## review notes, never shown to anyone.
var note := ""


static func make(phase_id: StringName, at_health: float, part_side: StringName, bite_row: Dictionary) -> SentinelPhase:
	var p := SentinelPhase.new()
	p.id = phase_id
	p.at = at_health
	p.part = part_side
	p.bite = bite_row
	return p


## The roster keys this phase writes onto a live body's own row copy.
func row_patch() -> Dictionary:
	var patch := {"part": part, "guarded": guarded, "bite": bite, "pace": pace, "dash": dash, "quick": quick}
	if climbs >= 0:
		patch["climbs"] = climbs
	return patch
