extends TestCase
## The two doors onto a chapter, held to giving one answer.
##
## `Chapters.of` is the one door for a single region and reads the live game by
## sweeping `game.systems` three times, asking each for a property BY NAME.
## `Chapters.for_regions` answers many regions with those sweeps done once,
## because `24_holds` asks about every region that keeps a hold at once and that
## refresh is the largest `_process` cost in the game.
##
## TWO DOORS ONTO ONE ANSWER IS THE RISK THE SPEEDUP BUYS, and this file is the
## price of it. `chapters.gd`'s own header says the reason there is one door at
## all is so that the story, the way on, the slate, dev mode and a test cannot
## disagree about whether a chapter is done — a second path that drifts by a
## field would let exactly that happen, silently, in the half of the game that
## reads the cheap one.
##
## Field by field rather than on `answered` alone: `answered` is a conjunction of
## three, so two paths can agree on it while disagreeing about WHICH of explored,
## mined and defended is true, and the slate shows those separately.


func _game(args: PackedStringArray) -> Game:
	var o := BootOptions.parse(args)
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	return g


func test_the_bulk_door_answers_exactly_what_the_single_door_does() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=256", "--hour=11", "--weather=clear:0"]))
	var ids: Array = []
	for r: Dictionary in g.world.regions:
		ids.append(int(r.get("id", -1)))
	gt(float(ids.size()), 1.0, "a world with regions to compare over (%d)" % ids.size())
	var bulk := Chapters.for_regions(g, ids)
	var checked := 0
	for rid: int in ids:
		var one := Chapters.of(g, rid)
		check(bulk.has(rid), "the bulk door answered about region %d at all" % rid)
		var many: Dictionary = bulk.get(rid, {})
		for k: Variant in one:
			eq(str(many.get(k)), str(one[k]), "region %d, field %s" % [rid, k])
			checked += 1
	# The counter is what stops this being a test of nothing: two doors that both
	# answer about no regions agree perfectly.
	gt(float(checked), 10.0, "and it compared real fields (%d)" % checked)
	g.queue_free()


## The empty-game path is its own branch in both doors and is what a caller hits
## out on the sea, so it is held to agreeing too — including that a region id
## nobody knows about comes back unanswered rather than absent.
func test_both_doors_agree_when_there_is_no_world() -> void:
	var one := Chapters.of(null, 3)
	var many: Dictionary = Chapters.for_regions(null, [3]).get(3, {})
	check(not many.is_empty(), "the bulk door still answers about a region with no game")
	for k: Variant in one:
		eq(str(many.get(k)), str(one[k]), "field %s with no game" % k)
	check(not bool(one["answered"]), "and nothing is answered out there")


## WHAT THE BULK DOOR SAVES, and a guard that it goes on saving it.
##
## Best-of rather than mean: load only ever ADDS time, so the cheapest run is the
## honest one, and both doors are measured in the SAME process, alternating, so
## neither gets a colder machine than the other. That is CLAUDE.md's cost rule and
## LOOK.md's method 2 saying the same thing at two scales.
##
## `cost_lt` rather than a bare `lt`, because on a box busy enough that
## `machine_slack` cannot be trusted it prints UNMEASURED and declines to judge
## instead of inventing a verdict. This file was written on a night when two
## sessions were measuring on one machine and every timing between them was worth
## less than it looked.
##
## The bar is a SHARE of the single door's own cost measured in the same run, not
## a millisecond: a millisecond is a claim about this laptop, a share is a claim
## about the code. It is deliberately loose -- the saving measured in development
## was far larger, and a tight bar here would fail for being on a different
## machine rather than for a regression.
func test_asking_about_many_regions_is_cheaper_than_asking_one_at_a_time() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=256", "--hour=11", "--weather=clear:0"]))
	var ids: Array = []
	for r: Dictionary in g.world.regions:
		ids.append(int(r.get("id", -1)))
	gt(float(ids.size()), 1.0, "more than one region to ask about (%d)" % ids.size())
	var one := best_of(5, func() -> void:
		for rid: int in ids:
			@warning_ignore("return_value_discarded")
			Chapters.of(g, rid)) / 1000.0
	var many := best_of(5, func() -> void:
		@warning_ignore("return_value_discarded")
		Chapters.for_regions(g, ids)) / 1000.0
	print("chapters over %d regions: of() per region %.3f ms, for_regions() %.3f ms (%.1fx)"
		% [ids.size(), one, many, one / maxf(many, 0.0001)])
	cost_lt(many, one * 0.8, "asking about every region at once beats asking one at a time")
	g.queue_free()
