extends TestCase
## THE BURNING'S FOUNDRY (src/content/interiors/foundry.gd): where the machines
## make what they fight with. Asked of every foundry the world grows on seed 4,
## with the real query and the room's real blocks (21_doors._walls), the real
## dark (21_doors.dark_at), the turrets' real lines (21_doors.screened), and the
## real loot, recipe and guide.

const Fx := preload("res://tests/survival/fixture.gd")
const STEP := 0.2

var _doors := load("res://src/systems/21_doors.gd") as GDScript


func _foundries() -> Array[InteriorGen.Pocket]:
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var out: Array[InteriorGen.Pocket] = []
	for t: Threshold in Interiors.thresholds(w):
		if t.kind == &"foundry":
			out.append(InteriorGen.grow(4, t))
	return out


func _reach(q: WorldQuery, from: Vector2) -> Dictionary:
	var seen := {Vector2i(roundi(from.x / STEP), roundi(from.y / STEP)): true}
	var todo: Array[Vector2i] = [seen.keys()[0]]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if seen.has(n):
				continue
			var a := Vector2(c) * STEP
			var b := Vector2(n) * STEP
			if q.move_body(a, b - a, Tuning.PLAYER_RADIUS).distance_to(b) < 0.02:
				seen[n] = true
				todo.append(n)
	return seen


func _reached(reach: Dictionary, at: Vector2) -> bool:
	var c := Vector2i(roundi(at.x / STEP), roundi(at.y / STEP))
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if reach.has(c + Vector2i(dx, dy)):
				return true
	return false


func _thing(l: InteriorLayout, kind: StringName) -> Dictionary:
	for t: Dictionary in l.things:
		if t.kind == kind:
			return t
	return {}


## Points along the quiet way: behind the racks, the length of them, `inset`
## in from their ends.
func _behind_racks(l: InteriorLayout, inset := 0.4) -> Array[Vector2]:
	var r := _thing(l, &"cast_rack")
	var f: Vector2 = r.face
	var s := Vector2(-f.y, f.x)
	var out: Array[Vector2] = []
	for i in 7:
		var u := -float(r.long) * 0.5 + inset + (float(r.long) - 2.0 * inset) * float(i) / 6.0
		out.append((r.at as Vector2) + s * u - f * 1.0)
	return out


## THE QUIET WAY AND THE LOUD WAY BOTH GO. From the hatch a body gets behind
## the racks the length of them, into the store to its box, and round the
## line's end to its panel and the warden's post; and the line with its furnace
## walls the hall across, so the north side is reached only round the line's end.
func test_every_foundry_can_be_walked_through() -> void:
	var n := 0
	for p: InteriorGen.Pocket in _foundries():
		n += 1
		var l := p.layout
		var q := WorldQuery.new(p.world)
		q.set_blocks(&"rooms", _doors.call(&"_walls", l) as Array[Vector3])
		var reach := _reach(q, l.inside())
		var box := _thing(l, &"strongbox")
		var panel := _thing(l, &"line_panel")
		check(_reached(reach, (box.at as Vector2) + (box.face as Vector2) * 0.8), "the store's box can be walked to")
		check(_reached(reach, (panel.at as Vector2) + (panel.face as Vector2) * 0.6), "the line's panel can be walked to")
		for at: Vector2 in _behind_racks(l):
			check(_reached(reach, at), "behind the racks at %s" % at)
		check(_reached(reach, l.residents[0].at as Vector2), "the warden's post, the loud way")
	gt(float(n), 0.0, "seed 4 has a foundry to walk")


## THE POUR'S LIGHT IS WHAT SHOWS YOU. Beside the line the room is lit; behind
## the racks it is darker than the darkest night outside (Senses.DARKEST).
func test_the_pour_lights_the_line_and_the_racks_keep_the_dark() -> void:
	for p: InteriorGen.Pocket in _foundries():
		var l := p.layout
		var line := _thing(l, &"line")
		var beside := (line.at as Vector2) + (line.face as Vector2) * 0.8
		lt(float(_doors.call(&"dark_at", p.kind, l, beside)), 0.05, "beside the pour there is no dark")
		for at: Vector2 in _behind_racks(l):
			gt(float(_doors.call(&"dark_at", p.kind, l, at)), Senses.DARKEST, "behind the racks at %s it is darker than night" % at)


## THE RACKS STAND TO THE CEILING: neither turret sees behind them along their
## run, and both see the line's side of them. Their ends are open -- round the
## end a turret across the hall sees in -- which is the sweep the quiet way
## has to time at the hatch and at the store.
func test_the_racks_screen_the_quiet_way_from_the_turrets() -> void:
	for p: InteriorGen.Pocket in _foundries():
		var l := p.layout
		var r := _thing(l, &"cast_rack")
		var turrets := 0
		for t: Dictionary in l.things:
			if t.kind != &"turret":
				continue
			turrets += 1
			for at: Vector2 in _behind_racks(l, 1.0):
				check(bool(_doors.call(&"screened", l, t.at, at)), "the turret at %s does not see %s behind the racks" % [t.at, at])
			var front := (r.at as Vector2) + (r.face as Vector2) * 0.8
			check(not bool(_doors.call(&"screened", l, t.at, front)), "the turret at %s sees the racks' front" % [t.at])
		eq(turrets, 2, "two turrets")


## THE STORE KEEPS WHAT THE RISK IS FOR: the burning's glass and the lance
## casting in every box, whatever the roll.
func test_the_store_keeps_the_glass_and_the_casting() -> void:
	Interiors.declare_loot(true)
	for instance in 12:
		var got := {}
		for row: Dictionary in Drops.roll(Interiors.loot_source(&"foundry"), 4, instance, &"burning"):
			got[row.item] = int(row.count)
		check(int(got.get(&"cinder_glass", 0)) >= 1, "box %d: the burning's glass (%s)" % [instance, got])
		eq(int(got.get(&"lance_casting", 0)), 1, "box %d: the lance casting" % instance)


## A CASTING IS WHAT A CAST LANCE IS BUILT ON: at a bench, with the found jig in
## hand, the casting and the glass go in and the lance comes out.
func test_a_cast_lance_is_built_on_the_casting() -> void:
	var g := Fx.flat()
	Fx.put(g, PropKind.HOUSE, Vector2(2.4, 0))
	var r := Crafting.recipe(&"lance_cast")
	check(not r.is_empty(), "there is a recipe")
	g.inventory.add(&"cinder_glass", 1)
	g.inventory.add(&"copper", 2)
	g.inventory.add(&"fab_jig", 1)
	check(not Crafting.can_make(g.inventory, r), "not without the casting")
	g.inventory.add(&"lance_casting", 1)
	check(Crafting.can_make(g.inventory, r), "with it")
	check(Crafting.make_in(g, r), "set going at the bench")
	eq(g.inventory.count(&"lance_casting"), 0, "the casting went into it")
	g.clock.skip(float(r.minutes))
	Survival.tick(g, 0.0)
	eq(g.inventory.count(&"lance_cast"), 1, "and the lance came out")
	eq(g.inventory.count(&"fab_jig"), 1, "the jig is kept")
	Fx.done(g)


## THE LONG GAME POINTS AT IT: once the burning's glass is held, the goal is the
## casting, and where it is kept, in the land's own words.
func test_the_goal_points_at_the_foundry_once_the_glass_is_held() -> void:
	var g := Fx.flat()
	Survival.build(g, &"fire", true)
	g.inventory.add(&"pick", 1)
	g.inventory.add(&"iron_ore", 1)
	check(not Guide.goal(g).contains("foundry"), "not before the glass: %s" % Guide.goal(g))
	g.inventory.add(&"cinder_glass", 1)
	var line := Guide.goal(g)
	eq(line, "Lance casting: kept in the foundry, %s." % BiomeRegistry.get_def(&"burning").spoken_in, "the casting and where")
	lt(float(Hud.goal_clip(line).end.x), float(UiBase.mid_x() - 120), "fits its window: %s" % line)
	g.inventory.add(&"lance_casting", 1)
	check(not Guide.goal(g).contains("foundry"), "held, it is not asked for again: %s" % Guide.goal(g))
	Fx.done(g)
