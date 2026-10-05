extends TestCase
## ORE A WALKER CRUSHED WAS NEVER HIS TO TAKE. A walker's pads come down on what
## the world laid in their craters before he arrives (Treads.crushed), ore
## among it, and a chapter's "mined" measures what HE took: the crushed ore is
## neither standing (it was never there to mine) nor taken. On seed 7 at 1840 a
## new game's first frame had 45 crushed ore counted as taken across the
## regions, and the same ore counted as standing.


func test_a_new_game_starts_with_no_ore_taken_and_only_standing_ore_counted() -> void:
	var w := WorldGen.generate(7, Tuning.WORLD_SIZE)
	RealmWarm.prepare(w)
	w.sync_table()
	var standing := {}
	var crushed_ore := 0
	for row in w.table.size():
		var at: Vector2 = w.table.pos[row]
		var rid := w.region_at(floori(at.x), floori(at.y))
		if not Chapter.ore_kinds(w, rid).has(int(w.table.kind[row])):
			continue
		if w.depleted.has(w.table.id[row]):
			crushed_ore += 1
		else:
			standing[rid] = int(standing.get(rid, 0)) + 1
	gt(float(crushed_ore), 0.0, "the treads crushed ore to count (%d)" % crushed_ore)
	var taken := 0
	var off := 0
	for r: Dictionary in w.regions:
		var rid := int(r.get("id", -1))
		taken += Chapter.ore_taken(w, rid)
		if Chapter.ore_standing(w, rid) != int(standing.get(rid, 0)):
			off += 1
	eq(taken, 0, "no ore is taken on the first frame")
	eq(off, 0, "every region counts as standing the ore that stands")
