extends TestCase
## `WorldQuery.reach_near` with a set of kinds is the same props as without it,
## kept to those kinds: it only skips making objects for the rest (49_story asks
## it every frame for the readable things in front of him).

const Sx := preload("res://tests/save/save_fixture.gd")


func test_a_kind_filtered_reach_is_the_whole_reach_kept_to_those_kinds() -> void:
	Sx.use_root("reach-kinds")
	var g := Sx.game(tree, ["--seed=1", "--hour=11", "--weather=clear:0"])
	await tree.process_frame
	var checked := 0
	for off: Vector2 in [Vector2.ZERO, Vector2(6, -3), Vector2(-9, 4), Vector2(14, 11), Vector2(-20, -15)]:
		var p := g.player.pos + off
		var every := g.query.reach_near(p, 6.0)
		var want: Array[int] = []
		for q in every:
			if StoryProps.READABLE.has(q.kind) or q.kind == PropKind.DRIFTWOOD:
				want.append(q.id)
		var kinds := StoryProps.READABLE.duplicate()
		kinds[PropKind.DRIFTWOOD] = true
		var got: Array[int] = []
		for q in g.query.reach_near(p, 6.0, kinds):
			got.append(q.id)
		eq(got, want, "near %s: the same props, in the same order" % p)
		checked += every.size()
	gt(float(checked), 20.0, "there was something to keep or skip (%d props)" % checked)
	Sx.end(g)
