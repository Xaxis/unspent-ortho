class_name SlotRoute
extends RefCounted
## THE WAY OUT OF THE MAZE, as a string laid along it (docs/MIDDENS_ROOMS.md,
## the face settlement's string): from the junction a door stands in to the
## nearest ramp up out of the slots, over the seed's slot plan (GenSlots), never
## the tiles. A breadth-first search along the plan's open ways, at most MOST
## nodes, so a settlement with no ramp in reach gives no route rather than a walk
## across the world.
##
##   SlotRoute.to_ramp(w, near) -> PackedVector2Array: the plan node nearest
##       `near` that is a junction room, each node's centre on the way, and the
##       ramp's top last; empty where there is none within MOST nodes.
##
## The plan's centres are where the slots were laid before the warp moved the
## land (GenSlots.WARP, up to 2.5 tiles): a route for the map, not a path to walk
## blind.

const MOST := 64
## How far from `near` the starting junction may be: a settlement's door is in
## its room's wall, a room radius and a face's reach off its centre.
const START_REACH := 12.0


static func to_ramp(w: WorldData, near: Vector2) -> PackedVector2Array:
	var plan := SlotDoors._plan(w)
	if plan == null:
		return PackedVector2Array()
	var pw := plan.width
	var start := -1
	var best := START_REACH
	var gx := roundi(near.x / GenSlots.PITCH)
	var gy := roundi(near.y / GenSlots.PITCH)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := gx + dx
			var y := gy + dy
			if x < 0 or y < 0 or x >= pw or y >= pw:
				continue
			var k := y * pw + x
			if k >= plan.centre.size() or plan.degree[k] < 3:
				continue
			var d := plan.centre[k].distance_to(near)
			if d < best:
				best = d
				start = k
	if start < 0:
		return PackedVector2Array()
	var from := {start: -1}
	var order: Array[int] = [start]
	var head := 0
	var found := -1
	while head < order.size() and order.size() <= MOST:
		var k: int = order[head]
		head += 1
		if plan.ramp[k] != 0:
			found = k
			break
		for n: int in _ways(plan, k):
			if not from.has(n):
				from[n] = k
				order.append(n)
	if found < 0:
		return PackedVector2Array()
	var back: Array[Vector2] = [plan.ramp_to[found]]
	var k := found
	while k >= 0:
		back.append(plan.centre[k])
		k = from[k]
	back.reverse()
	return PackedVector2Array(back)


## The nodes open to node `k` in the plan.
static func _ways(plan: GenSlots, k: int) -> Array[int]:
	var pw := plan.width
	var out: Array[int] = []
	var x := k % pw
	if x < pw - 1 and plan.east[k] != 0:
		out.append(k + 1)
	if x > 0 and plan.east[k - 1] != 0:
		out.append(k - 1)
	if k + pw < plan.centre.size() and plan.south[k] != 0:
		out.append(k + pw)
	if k - pw >= 0 and plan.south[k - pw] != 0:
		out.append(k - pw)
	return out
