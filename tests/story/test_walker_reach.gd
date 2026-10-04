extends TestCase
## THE CLIMB ON EVERY WORLD (#70, option A). The lame walker's tread is sited
## where a foot fits (GenTreads): on the Covenant's body on five seeds of twelve,
## across another water on the rest. The walker lead pins its crater wherever it
## is (`the_tread`, cast from the tread the world marks its people's), and the
## goal line reaches it: by walking on the Covenant's body, else by a second raft
## to the tread's body (StoryCrossing.to_walker), put in from the Covenant's shore
## or, where no open water joins the two, from home's. At the shipped size; each
## seed prints how it is reached.

const SEEDS: Array[int] = [1, 3, 4, 5, 7, 11, 17, 23, 29, 41, 42, 90210]
## Cells the sea is spread over from home, as the deal finds the landfall
## (GenBodies._landfall, LANDFALL_CELL).
const CELL := 8


## Tiles of water from home to each other body the sea reaches, by the deal's own
## spread: over the sea from every home cell, a body's first cell reached.
func _water_from_home(w: WorldData, home: int) -> Dictionary:
	var cw := ceili(float(w.size) / CELL)
	var ids := PackedInt32Array()
	ids.resize(cw * cw)
	for gy in cw:
		for gx in cw:
			ids[gy * cw + gx] = w.continent_at(mini(gx * CELL + CELL / 2, w.size - 1), mini(gy * CELL + CELL / 2, w.size - 1))
	var dist := PackedInt32Array()
	dist.resize(cw * cw)
	dist.fill(-1)
	var queue := PackedInt32Array()
	for k in cw * cw:
		if ids[k] == home:
			dist[k] = 0
			queue.append(k)
	var first := {}
	var head := 0
	while head < queue.size():
		var k := queue[head]
		head += 1
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := k % cw + o.x
			var ny := k / cw + o.y
			if nx < 0 or ny < 0 or nx >= cw or ny >= cw:
				continue
			var nk := ny * cw + nx
			if dist[nk] >= 0:
				continue
			dist[nk] = dist[k] + 1
			if ids[nk] <= 0 or ids[nk] == home:
				queue.append(nk)
			elif not first.has(ids[nk]):
				first[ids[nk]] = dist[nk] * CELL
	return first


## Where the climb goes up from, read off the world, not the cast: the ankle
## over the tread GenTreads marks its people's (`folk`), the lame leg's, the leg
## climbed to the enclave in the walker's crown. INF where none is marked.
func _climbed(w: WorldData) -> Vector2:
	for m: Dictionary in w.landmarks:
		if StringName(m.get("kind", &"")) == &"tread" and bool(m.get("folk", false)):
			return m.pos
	return Vector2.INF


func test_the_walker_lead_pins_a_crater_the_goal_line_reaches_on_every_world() -> void:
	var reached := 0
	for s: int in SEEDS:
		var w := WorldGen.generate(s, Tuning.WORLD_SIZE)
		StoryPlan.forget()
		var cast := StoryPlan.cast(w)
		var cov: Vector2 = cast[&"the_covenant"].pos if cast.has(&"the_covenant") else Vector2.INF
		var at: Vector2 = (cast[&"the_tread"] as Dictionary).pos if cast.has(&"the_tread") else Vector2.INF
		var how := "no crater pinned"
		if at.is_finite() and cov.is_finite() and w.same_body(at, cov):
			how = "on the Covenant's body, by walking"
		elif at.is_finite():
			var c := StoryCrossing.to_walker(w, cast)
			how = "across the water, but no crossing to it"
			if not c.is_empty():
				var camp: Vector2 = cast[&"the_camp"].pos if cast.has(&"the_camp") else Vector2.INF
				check(w.same_body(c.launch as Vector2, cov) or w.same_body(c.launch as Vector2, camp), "seed %d: the walker's raft puts in on the Covenant's body or home's" % s)
				check(w.same_body(c.land as Vector2, at), "seed %d: and lands on the tread's" % s)
				check(StoryCrossing._open_water(w, c.launch, c.land), "seed %d: over open water all the way" % s)
				how = "by a second raft from %s, %.0f tiles of water" % ["the Covenant's shore" if w.same_body(c.launch as Vector2, cov) else "home's shore", float(c.water)]
		# NO STOP IS NEARER HOME THAN THE LAST (docs/STORY.md). The stops are the
		# goals after leg 1's: the walker's crater (the_tread), and the enclave up
		# the leg that stands in it (the world's own `folk` tread, the lame leg's).
		# Each is on a body never home's and no nearer home by water than leg 1's,
		# the Covenant's. A put-in is a route, not a stop: on seed 42 the raft
		# puts in from home's own shore, and that is never asked here.
		if at.is_finite() and cov.is_finite():
			var home := w.continent_at(floori(w.spawn.x), floori(w.spawn.y))
			var water := _water_from_home(w, home)
			var leg1_water: int = water.get(w.continent_at(floori(cov.x), floori(cov.y)), -1)
			var goals := {"the walker's crater": at, "the enclave": _climbed(w)}
			for goal: String in goals:
				var g: Vector2 = goals[goal]
				check(g.is_finite(), "seed %d: %s stands somewhere" % [s, goal])
				if not g.is_finite():
					continue
				var body := w.continent_at(floori(g.x), floori(g.y))
				var far: int = water.get(body, -1)
				check(body != home, "seed %d: %s is not on the home body" % [s, goal])
				check(far >= leg1_water, "seed %d: %s is no nearer home by water than leg 1 (%d tiles against %d)" % [s, goal, far, leg1_water])
			var tread_body := w.continent_at(floori(at.x), floori(at.y))
			how += "; from home by water: leg 1 %d tiles, the walker's body %d" % [leg1_water, int(water.get(tread_body, -1))]
		print("  seed %d: %s" % [s, how])
		if how.begins_with("on the") or how.begins_with("by a second"):
			reached += 1
	eq(reached, SEEDS.size(), "every world's walker lead pins a crater the goal line reaches")
	StoryPlan.forget()
