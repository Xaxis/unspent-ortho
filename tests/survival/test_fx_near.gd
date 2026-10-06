extends TestCase
## WHAT TAKING LEFT, AND THE FIRES, ARE READ NEAR THE PLAYER (52_survival_fx).
## The remnants' signature moves with any take on the island, so while a walker
## strides it moved every half second, and each time every depleted id and spent
## key in the world was walked as WorldProps. Now the rows in reach are read off
## the table. And a fire coming back within reach is drawn from the meshes its
## seed was built with (FireModel.meshes), not built again from nothing.

const Fx := preload("res://tests/survival/fixture.gd")
const FX := "res://src/systems/52_survival_fx.gd"


## A field of `size` with pines on a grid every `step` tiles; the player stands
## in the middle.
static func _field(size: int, step: float) -> Game:
	var w := WorldData.new(11, size)
	w.level.fill(2)
	w.ground.fill(Ground.GRASS)
	w.country.fill(Country.COAST)
	w.spawn = Vector2(size * 0.5 + 0.25, size * 0.5 + 0.25)
	var y := 1.5
	while y < size - 1:
		var x := 1.5
		while x < size - 1:
			w.add_prop(WorldProp.new(w.next_id(), PropKind.PINE, Vector2(x, y), 0.0, 1.0))
			x += step
		y += step
	return Fx.from_world(w)


static func _fx(g: Game) -> GameSystem:
	var f: GameSystem = (load(FX) as GDScript).new()
	f.game = g
	f.call("_build_remnant_layers")
	return f


static func _free(g: Game, f: GameSystem) -> void:
	f.free()
	g.player.free()
	g.free()


## Fell every pine within `r` of `at`, or beyond `r` when `beyond`; tap every
## `tap_every`th pine left standing on the same side (a spent option that keeps).
static func _take(g: Game, at: Vector2, r: float, beyond: bool, tap_every: int) -> void:
	var w := g.world
	var state := SurvivalState.of(g)
	var n := 0
	for row in w.table.size():
		var d := w.table.pos[row].distance_to(at)
		if (d > r) != beyond:
			continue
		n += 1
		if n % tap_every == 0:
			state.spent[SurvivalState.key(w.table.id[row], _tap_index())] = INF
		elif n % 3 == 0:
			w.depleted[w.table.id[row]] = INF


static func _tap_index() -> int:
	var opts := Takes.options(PropKind.PINE)
	for i in opts.size():
		if (opts[i] as Dictionary).verb == &"tap":
			return i
	return 0


## Every mark the remnants would draw here, as "layer x z", sorted. Read off
## `remnants_near`, which `_refresh_remnants` draws: headless, the dummy
## renderer keeps no multimesh transforms to read back.
static func _drawn(f: GameSystem) -> Array:
	var g: Game = f.game
	var out := []
	var lists: Dictionary = f.call("remnants_near", g.player.pos)
	for name: StringName in lists:
		for p: WorldProp in lists[name]:
			var o := g.world.to_3d(p.pos)
			out.append("%s %.2f %.2f" % [name, o.x, o.z])
	out.sort()
	return out


## The marks the old way: every depleted id and every spent key in the world,
## kept where within REMNANT_RADIUS.
static func _marks_by_walking(g: Game, reach: float) -> Array:
	var w := g.world
	var here := g.player.pos
	var out := []
	for id: int in w.depleted:
		var p := w.prop(id)
		var r := RemnantModels.for_kind(p.kind)
		if r != &"" and p.pos.distance_to(here) <= reach:
			var o := w.to_3d(p.pos)
			out.append("%s %.2f %.2f" % [r, o.x, o.z])
	var marked := {}
	for key: String in SurvivalState.of(g).spent:
		var id := key.get_slice(":", 0).to_int()
		var p := w.prop(id)
		if w.depleted.has(id) or p.pos.distance_to(here) > reach:
			continue
		var opts := Takes.options(p.kind)
		var index := key.get_slice(":", 1).to_int()
		var mark := RemnantModels.worked_for(p.kind, (opts[index] as Dictionary).verb)
		if not marked.has("%d:%s" % [id, mark]):
			marked["%d:%s" % [id, mark]] = true
			var o := w.to_3d(p.pos)
			out.append("%s %.2f %.2f" % [mark, o.x, o.z])
	out.sort()
	return out


func test_the_marks_are_the_ones_a_walk_of_every_take_would_draw() -> void:
	var g := _field(160, 3.0)
	var f := _fx(g)
	var reach := float(f.get("REMNANT_RADIUS"))
	# Taken near and far, felled and tapped.
	_take(g, g.player.pos, 70.0, false, 5)
	_take(g, g.player.pos, 70.0, true, 7)
	f.call("_refresh_remnants")
	var want := _marks_by_walking(g, reach)
	gt(float(want.size()), 100.0, "a good many marks in reach (%d)" % want.size())
	eq(_drawn(f), want, "every mark in reach, and none beyond it")
	var mms: Dictionary = f.get("_remnant_mm")
	eq((mms[&"stump"] as MultiMesh).instance_count, want.filter(func(m: String) -> bool: return m.begins_with("stump ")).size(), "and as many stumps drawn")
	# A step on, inside the reach the rows were taken for, a pine felled there
	# and one set down and felled since: the rows in hand still hold them.
	g.player.pos += Vector2(7.0, 4.0)
	var late := WorldProp.new(g.world.next_id(), PropKind.PINE, g.player.pos + Vector2(-46.0, 0.5), 0.0, 1.0)
	g.world.add_prop(late)
	g.query.add_prop(late)
	g.world.depleted[late.id] = INF
	for row in g.query.rows_near(g.player.pos + Vector2(40.0, 0.0), 2.0):
		g.world.depleted[g.world.table.id[row]] = INF
	eq(_drawn(f), _marks_by_walking(g, reach), "a step on, the same marks a walk would find")
	check(_drawn(f).has("stump %.2f %.2f" % [g.world.to_3d(late.pos).x, g.world.to_3d(late.pos).z]), "the one set down since among them")
	# And far on, where the rows are taken again.
	g.player.pos += Vector2(-35.0, 20.0)
	eq(_drawn(f), _marks_by_walking(g, reach), "far on, the same again")
	_free(g, f)


func test_what_was_taken_far_off_costs_nothing_here() -> void:
	var g := _field(900, 2.5)
	var f := _fx(g)
	# What the player took round them.
	_take(g, g.player.pos, 40.0, false, 5)
	# A walker's stride: the signature moves and the player does not.
	var refresh := func() -> void:
		f.set("_remnant_sig", "")
		f.call("_refresh_remnants")
	# A step walked: the rows taken again and the spent options asked after.
	var walk_on := func() -> void:
		f.set("_rows_of", 0)
		refresh.call()
	var alone := TestCase.best_of(5, refresh)
	var walked_alone := TestCase.best_of(3, walk_on)
	# And across the rest of the island, a walker's whole stride of it.
	_take(g, g.player.pos, 120.0, true, 9)
	print("  taken far off: %d depleted, %d spent" % [g.world.depleted.size(), SurvivalState.of(g).spent.size()])
	var beside := TestCase.best_of(5, refresh)
	var walked := TestCase.best_of(3, walk_on)
	print("  the remnants refreshed on a stride in %.0f us, %.0f us beside the island's takes; on a step walked %.0f us, %.0f us beside them" % [alone, beside, walked_alone, walked])
	ratio_lt(beside / maxf(alone, 1.0), 1.5, "a stride's refresh beside the island's takes, as a share of it alone")
	ratio_lt(walked / maxf(walked_alone, 1.0), 1.5, "a step's refresh beside the island's takes, as a share of it alone")
	_free(g, f)


func test_a_fire_come_back_into_reach_is_not_built_again() -> void:
	var mat := ShaderMaterial.new()
	var cold: Array[float] = []
	var warm: Array[float] = []
	# Seeds no other fire in this process has had.
	for s: int in [9100003, 9100019, 9100037]:
		for pass_ in 2:
			var t0 := Time.get_ticks_usec()
			var fire := FireModel.new()
			fire.build(mat, s)
			var spent := float(Time.get_ticks_usec() - t0)
			(cold if pass_ == 0 else warm).append(spent)
			eq(fire.get_child_count(), 7, "a whole fire: hearth, bed, sticks, flame, light, smoke, sparks")
			fire.free()
	var again := FireModel.new()
	again.build(mat, 9100003)
	var first := FireModel.meshes(9100003)
	check((again.get_child(0) as MeshInstance3D).mesh == first[0], "drawn from the meshes its seed was built with")
	eq((first[3] as Array).size(), FireModel.FRAMES, "every frame of its flame")
	again.free()
	print("  a fire built %s us cold, %s us again" % [str(cold), str(warm)])
	ratio_lt(warm.min() / maxf(cold.min(), 1.0), 0.5, "a fire built again, as a share of building it new")
