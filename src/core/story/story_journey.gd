class_name StoryJourney
## The order the story crosses the world in (docs/STORY.md, docs/DESIGN.md).
##
## The story spans every continent, and in an order (owner, 2026-09-18): it begins
## where Elias wakes and walks outward, and the Tether stands on the farthest. A
## world is procedural, so the order cannot name continents; it is worked out here,
## from the world, the same way every time the world is grown.
##
##   StoryJourney.bodies(world)      -> body ids in the order the story visits them
##   StoryJourney.body_for(world, n) -> the body leg n is cast on
##
## Pure and derived, so it is never saved.

## Every body people live on, in journey order: the spawn's first, then the rest
## by how far their centres lie from it, nearest first. A body counts only if a
## VILLAGE stands on it. Measured, not assumed: a 1024 world has four continents
## and forty islets, and a handful of those islets carry a region of their own, so
## "holds a region" let a rock with nobody on it become a leg of the story.
static func bodies(world: WorldData) -> Array[int]:
	var out: Array[int] = []
	if world == null:
		return out
	var home := world.continent_at(floori(world.spawn.x), floori(world.spawn.y))
	var held := {}
	for v: Dictionary in world.villages:
		var c: Vector2 = v.get("pos", Vector2.ZERO)
		var id := world.continent_at(floori(c.x), floori(c.y))
		if id != 0:
			held[id] = true
	var rest: Array[Dictionary] = []
	for b: Dictionary in world.continents:
		var id := int(b.id)
		if id == home or not held.has(id):
			continue
		var centre: Vector2 = b.centre
		rest.append({"id": id, "far": centre.distance_to(world.spawn)})
	# Ties broken by id, so two bodies the same distance off still come out in one order.
	rest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.far) < float(b.far) or (is_equal_approx(float(a.far), float(b.far)) and int(a.id) < int(b.id)))
	if home != 0:
		out.append(home)
	for r: Dictionary in rest:
		out.append(int(r.id))
	return out


## The body leg `leg` is cast on. A world with fewer bodies than the story has legs
## puts the later legs on its LAST body, so the farthest land still holds the end
## and every world holds the whole journey: the one-island worlds of every test and
## tour hold it all on the island.
static func body_for(world: WorldData, leg: int) -> int:
	var order := bodies(world)
	if order.is_empty():
		return 0
	return order[clampi(leg, 0, order.size() - 1)]
