extends TestCase
## THE GULLS' REFUSE, FOUND ONCE PER WORLD (37_fauna `_find_sites`). After any
## door the fauna walked every prop of the 1840 coast as WorldProp views in one
## frame (987 ms), because its count of props seen was one for every world:
## the pocket's smaller count reset it, and coming back out it walked from the
## pocket's count up, so the coast's rows below that were never looked at again
## and their tips and wrecks lost their flocks. Sites are kept per world now,
## and found along the kind column, the rows joined in row order as before.

const FAUNA := "res://src/systems/37_fauna.gd"
const REFUSE: Array[int] = [PropKind.TIP, PropKind.WRECK, PropKind.HULL]


## A packed world of `n` props as generation leaves one (the table is the
## truth, a prop a view of its row), with `heaps` heaps of refuse three to a
## heap, a heap's pieces in rows far apart as a real coast's are.
static func _packed(n: int, heaps: int, size: int = 1840) -> WorldData:
	var w := WorldData.new(9, size)
	var t := PropTable.new()
	t.id.resize(n)
	t.kind.resize(n)
	t.pos.resize(n)
	t.rot.resize(n)
	t.scale.resize(n)
	t.solid.resize(n)
	t.variant.resize(n)
	t.kind.fill(PropKind.PINE)
	t.scale.fill(1.0)
	t.variant.fill(-1)
	for i in n:
		t.id[i] = i
		t.pos[i] = Vector2(Rng.hash01(9, i, 1), Rng.hash01(9, i, 2)) * float(size)
	for h in heaps:
		var at := Vector2(Rng.hash01(9, h, 3), Rng.hash01(9, h, 4)) * float(size - 40) + Vector2(20, 20)
		for j in 3:
			var row := (h * 7919 + j * (n / 3)) % n
			t.kind[row] = REFUSE[j]
			t.pos[row] = at + Vector2(j * 1.5, j * 0.7)
	w.table = t
	w.packed = true
	return w


static func _fauna(w: WorldData) -> GameSystem:
	var g := Game.new()
	g.world = w
	var f: GameSystem = (load(FAUNA) as GDScript).new()
	f.game = g
	return f


static func _free(f: GameSystem) -> void:
	f.game.free()
	f.free()


## The sites the old way: every prop in row order, each joined to any site
## already found within SITE_JOIN.
static func _sites_by_walking(w: WorldData, join: float) -> Array:
	var out := []
	for row in w.table.size():
		if not REFUSE.has(w.table.kind[row]):
			continue
		var p := w.table.pos[row]
		var joined := false
		for s: Array in out:
			if (s[1] as Vector2).distance_to(p) < join:
				joined = true
				break
		if not joined:
			out.append([w.table.id[row], p])
	return out


static func _as_rows(sites: Array) -> Array:
	var out := []
	for s: Dictionary in sites:
		out.append([-1000 - int(s.key), s.pos])
	return out


func test_the_sites_are_the_ones_every_prop_walked_would_find() -> void:
	var w := _packed(20000, 400, 600)
	var f := _fauna(w)
	f.call("_find_sites")
	var want := _sites_by_walking(w, float(f.get("SITE_JOIN")))
	gt(float(want.size()), 50.0, "a coast with refuse on it (%d sites)" % want.size())
	eq(_as_rows(f.get("sites")), want, "the same sites, the same keys, in the same order")
	# And a heap set down later joins, or founds, exactly as it would have.
	var near_one: Vector2 = (want[0][1] as Vector2) + Vector2(2.0, 0.0)
	w.table.append(WorldProp.new(20000, PropKind.TIP, near_one, 0.0, 1.0))
	w.table.append(WorldProp.new(20001, PropKind.WRECK, Vector2(3.0, 3.0), 0.0, 1.0))
	f.call("_find_sites")
	eq(_as_rows(f.get("sites")), _sites_by_walking(w, float(f.get("SITE_JOIN"))), "and the new rows the same")
	_free(f)


func test_a_door_trip_keeps_the_coasts_refuse() -> void:
	var coast := _packed(20000, 400, 600)
	# The pocket a door opens on: a few props of its own, one of them a tip, and
	# far fewer than the coast has.
	var pocket := _packed(60, 1, 40)
	var f := _fauna(coast)
	var g: Game = f.game
	f.call("_find_sites")
	var before: Array = (f.get("sites") as Array).duplicate(true)
	gt(float(before.size()), 50.0, "the coast's refuse is found")
	g.world = pocket
	f.call("_find_sites")
	eq((f.get("sites") as Array).size(), 1, "inside, the pocket's own heap")
	g.world = coast
	f.call("_find_sites")
	eq(f.get("sites"), before, "back out, every one of the coast's sites, not those past the pocket's count")
	# In again and out again: each world keeps its own.
	g.world = pocket
	f.call("_find_sites")
	eq((f.get("sites") as Array).size(), 1, "the pocket's heap again")
	g.world = coast
	var back := TestCase.best_of(1, func() -> void: f.call("_find_sites"))
	eq(f.get("sites"), before, "and the coast's")
	print("  coming back out of the door: %.0f us" % back)
	cost_lt(back / 1000.0, 1.0, "coming back out finds nothing to look at (ms)")
	_free(f)


func test_finding_an_islands_refuse_costs_a_few_ms() -> void:
	# A shipped coast's count of props, and of heaps.
	var w := _packed(130000, 900)
	var spent: Array[float] = []
	var found := 0
	for r in 3:
		var f := _fauna(w)
		var t0 := Time.get_ticks_usec()
		f.call("_find_sites")
		spent.append((Time.get_ticks_usec() - t0) / 1000.0)
		found = (f.get("sites") as Array).size()
		_free(f)
	gt(float(found), 500.0, "the island's refuse is found (%d sites)" % found)
	print("  every refuse site of 130k props found in %s ms" % str(spent))
	cost_lt(spent.min(), 25.0, "finding an island's refuse (ms)")
