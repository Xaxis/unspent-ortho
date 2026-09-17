class_name WorksSite
extends RefCounted
## One depot of the plan, in one region (docs/VISION.md §2). Pure record: where
## it stands, what trade it is in, which way it is squared to, and the three
## working parts a player has to get through to put it out.
##
## A site is DERIVED from the world, never stored in it: `Works.sites(world)`
## finds the same depots in the same places every time the same island is grown,
## so a works walked to yesterday is where it was. What has been DONE to one is
## the only thing that is saved (`WorksState`).

## Region id it serves (`WorldData.regions`), which is also the plan network the
## disposition package keeps its file on (`Interference.network`).
var region := -1
## The landscape type it stands in.
var land: StringName = &""
## The yard's heart, in tiles, and the bearing it is squared to (the machines'
## own survey line: everything they built lies along it, GenWorks.bearing).
var pos := Vector2.ZERO
var facing := 0.0
## What this depot is in the trade of: the kind of the nearest work of the plan
## it was founded on (&"intake", &"relay", &"drill_field"…). It is what the slate
## calls it and what a sentinel's station reads as.
var trade: StringName = &"depot"
## How many of the plan's own works stood in its yard when the world was grown.
## A yard with more in it is a bigger depot, which is the whole of how a region
## says how much the machines are doing in it.
var yard := 0


## The three working parts, in the order a player meets them, in tiles. Each is a
## real place to stand: the offsets are along the survey bearing and across it, so
## a depot's parts lie square to the land the way everything the machines built does.
func part(i: int) -> Vector2:
	var along := Vector2.from_angle(facing)
	var across := Vector2(-along.y, along.x)
	var o: Vector2 = Works.PART_OFFSETS[clampi(i, 0, Works.PART_OFFSETS.size() - 1)]
	return pos + along * o.x + across * o.y


## A part's name, for the slate and for a tour that says which one it broke.
func part_name(i: int) -> StringName:
	return Works.PART_NAMES[clampi(i, 0, Works.PART_NAMES.size() - 1)]


## Is `p` inside the yard (the ground the depot itself stands on)?
func in_yard(p: Vector2) -> bool:
	return p.distance_to(pos) <= Works.YARD


## Is `p` on ground this works holds — near enough that the machines here are
## its machines and the file kept on the player is its region's?
func holds(p: Vector2) -> bool:
	return p.distance_to(pos) <= Works.REACH
