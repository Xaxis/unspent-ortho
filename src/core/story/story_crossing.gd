class_name StoryCrossing
## THE CROSSING (ROADMAP slice 3, step 1): where a raft puts in from the home body
## and lands on the next leg's, for the goal line and the survey (49_cast places
## it as `the_crossing` and `the_landing`). The line from the crew's camp, the last
## place of the home leg, toward the archive, the next leg's: the last land of the
## home body on it, and the first of the far body. A ray, never a scan of the world.
##
## Two things he does are heard for the goal line (Guide.WAY): putting a craft
## afloat (44_crafts) and first standing on the far body (49_cast).

const PUT_IN := &"seen:raft_put_in"
const CROSSED := &"seen:far_shore"


## {launch: Vector2, land: Vector2, water: float (tiles)}, or {} where the line
## never leaves the body `from` stands on or never reaches the body `to` does.
static func find(world: WorldData, from: Vector2, to: Vector2) -> Dictionary:
	if world == null or world.same_body(from, to):
		return {}
	var d := to - from
	var steps := ceili(d.length())
	var launch := Vector2.INF
	for i in steps + 1:
		var p := from + d * (float(i) / float(maxi(1, steps)))
		var t := Vector2i(p.floor())
		if Ground.is_water(world.ground_at(t.x, t.y)):
			continue
		var here := Vector2(t) + Vector2(0.5, 0.5)
		if world.same_body(here, from):
			launch = here
		elif launch.is_finite() and world.same_body(here, to):
			return {"launch": launch, "land": here, "water": launch.distance_to(here)}
	return {}
