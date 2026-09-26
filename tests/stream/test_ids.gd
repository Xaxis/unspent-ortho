extends TestCase
## Prop ids are section ids (WorldStamp GEN 29, `GenIds`): a generated prop's id
## is (section << ORDINAL_BITS) | the order its section laid it, so a streamed
## section rebuilt from the plan gets the same ids, and a change in one section
## renumbers no other. A prop set down later takes BUILT_BIT | n.

const SIZE := 512
const SEED := 7

static var _w: WorldData


static func _world() -> WorldData:
	if _w == null:
		_w = WorldGen.generate(SEED, SIZE)
	return _w


func test_every_generated_id_names_its_own_section_in_the_order_it_was_laid() -> void:
	var w := _world()
	var across := WorldSections.across(SIZE)
	var next := {}
	var sections := {}
	for p in w.each_prop():
		var s := WorldSections.of(p.pos)
		var k := s.y * across + s.x
		sections[k] = true
		eq(p.id >> WorldData.ORDINAL_BITS, k, "prop at %s is in section %d" % [p.pos, k])
		eq(p.id & ((1 << WorldData.ORDINAL_BITS) - 1), int(next.get(k, 0)), "and comes next in it")
		next[k] = int(next.get(k, 0)) + 1
		check(WorldProp.same(w.prop(p.id), p), "its id finds it (%d)" % p.id)
		if not WorldProp.same(w.prop(p.id), p):
			return
	gt(float(sections.size()), 2.0, "the world spans several sections (%d)" % sections.size())
	check(w.prop(-1) == null and w.prop((across * across) << WorldData.ORDINAL_BITS) == null, "an id nothing holds finds nothing")


func test_the_ids_a_world_keeps_are_section_ids_too() -> void:
	var w := _world()
	var lines := 0
	for line: Dictionary in w.lines:
		for id: int in PackedInt32Array(line.get("props", [])):
			lines += 1
			check(w.prop(id) != null, "a line's mast %d is a prop" % id)
	gt(float(lines), 10.0, "the world strings lines (%d masts)" % lines)


func test_a_prop_set_down_later_takes_the_built_range() -> void:
	# Its own small world: a prop set down stays set down.
	var w := WorldGen.generate(SEED, 192)
	var id := w.next_id()
	check(id & WorldData.BUILT_BIT != 0, "a set-down prop's id is in the built range")
	var p := WorldProp.new(id, PropKind.FIRE, Vector2(100.5, 100.5), 0.0, 1.0)
	w.add_prop(p)
	check(WorldProp.same(w.prop(id), p), "and its id finds it")
	eq(w.id_at(w.position_of(id)), id, "position and id agree")
	eq(w.next_id(), WorldData.BUILT_BIT | 1, "the next one follows it")


func test_a_world_built_by_hand_keeps_its_list_positions_as_ids() -> void:
	var w := WorldData.new(1, 16)
	var a := WorldProp.new(w.next_id(), PropKind.FIRE, Vector2(2, 2), 0.0, 1.0)
	w.add_prop(a)
	var b := WorldProp.new(w.next_id(), PropKind.FIRE, Vector2(3, 3), 0.0, 1.0)
	w.add_prop(b)
	eq([a.id, b.id], [0, 1], "ids are positions")
	check(w.prop(1) == b, "and find their props")
