extends TestCase
## Props as packed columns (`PropTable`, the streaming design's S7). While the
## objects still stand beside it, the table must be them, row for row, and what
## play changes on a prop must change on its row.

const SIZE := 512
const SEED := 7

static var _w: WorldData


static func _world() -> WorldData:
	if _w == null:
		_w = WorldGen.generate(SEED, SIZE)
	return _w


func test_every_row_is_its_prop() -> void:
	var w := _world()
	var t := w.table
	eq(t.size(), w.prop_count(), "a row for every prop")
	var bad := 0
	for i in w.prop_count():
		var p := w.prop_at(i)
		if t.kind[i] != p.kind or t.pos[i] != p.pos or t.rot[i] != p.rot or t.scale[i] != p.scale \
				or t.solid[i] != p.solid or t.variant[i] != p.variant or float(t.shown.get(i, 1.0)) != p.shown:
			bad += 1
			if bad < 4:
				fail("row %d differs from prop %d (%s at %s)" % [i, p.id, PropKind.NAMES[p.kind], p.pos])
	eq(bad, 0, "no row differs")
	lt(float(t.bytes()) / maxf(1.0, t.size()), 40.0, "a row is under 40 bytes (%d B)" % (t.bytes() / maxi(1, t.size())))


func test_what_play_changes_changes_the_row() -> void:
	var w := _world()
	var i := w.prop_count() / 2
	var p := w.prop_at(i)
	var was := [p.scale, p.solid, p.shown]
	w.set_shown(p, 0.4)
	w.set_scale(p, 0.7)
	w.set_solid(p, 0.2)
	eq([p.shown, p.scale, p.solid], [0.4, 0.7, 0.2], "the prop holds it")
	eq([w.table.shown.get(i, 1.0), w.table.scale[i], w.table.solid[i]], [0.4, 0.7, 0.2], "and so does its row")
	w.set_shown(p, 1.0)
	check(not w.table.shown.has(i), "a whole prop leaves the sparse column")
	w.set_scale(p, was[0])
	w.set_solid(p, was[1])
	# A prop the world does not hold (a settlement's ghost) changes, and no row does.
	var ghost := WorldProp.new(-7, PropKind.HOUSE, Vector2(10, 10), 0.0, 1.0)
	var rows := w.table.size()
	w.set_solid(ghost, 0.0)
	eq(ghost.solid, 0.0, "the ghost takes it")
	eq(w.table.size(), rows, "and the table is untouched")


func test_a_prop_set_down_later_gets_a_row() -> void:
	var w := WorldData.new(1, 16)
	w.add_prop(WorldProp.new(w.next_id(), PropKind.FIRE, Vector2(3.5, 3.5), 0.25, 1.0))
	eq(w.table.size(), 1, "one row")
	eq(w.table.pos[0], Vector2(3.5, 3.5), "where it stands")
	eq(w.table.rot[0], 0.25, "turned as it was")


## THE NUMBER S7 IS BUYING DOWN. Every WorldProp alive after a world is grown:
## today every prop is one, so this is the world's prop count and more. Recorded
## here, and bounded to the working set near the camera once the columns are the
## truth (S7f).
func test_the_live_props_are_recorded() -> void:
	var w := _world()
	print("props/live: %d WorldProps alive for %d props" % [WorldProp.live, w.prop_count()])
	check(WorldProp.live >= w.prop_count(), "every prop is still an object (%d alive, %d props)" % [WorldProp.live, w.prop_count()])
