extends TestCase
## NO STORY PLACE ON A KEEPER'S GROUND (#72, StoryCasting's keeper ladder). Every
## place the story deals (a village, a works, a landmark, a shaft) takes the best
## step of the ladder its own body allows: 1, past every keeper's reach of its
## lair by StoryWorld.STOOD_REACH, so the people and the thing cast round it are
## off it too; 2, off the ground, only nearer; 3, where nothing on the body is off
## it, the place farthest from any. A slot never leaves its leg for a keeper and
## is never lost to one. Measured on main at 1840: 9 of 329 inside, among them
## seed 42's Sefa on the pan_rake's den and seed 41's whole Covenant seat 17
## tiles from the lockkeeper's, on a leg-1 body that is all the lockkeeper's.

const SEEDS: Array[int] = [1, 3, 4, 5, 7, 11, 17, 23, 29, 41, 42, 90210]
## The slots casting deals from the world's own places; the rest stand where the
## world says (a crater, the landfall, the black site) or mirror one of these.
const DEALT: Array[StringName] = [StorySlot.VILLAGE, StorySlot.WORKS, StorySlot.LANDMARK, StorySlot.PORTAL]


func test_no_story_place_stands_on_a_keepers_ground() -> void:
	var asked := 0
	var inside := 0
	var steps := {1: [], 2: [], 3: []}
	for s: int in SEEDS:
		var w := WorldGen.generate(s, Tuning.WORLD_SIZE)
		StoryPlan.forget()
		var cast := StoryPlan.cast(w)
		var keepers := StoryCasting._keeper_grounds(w)
		gt(float(keepers.size()), 0.0, "seed %d has keepers to keep off" % s)
		for slot: StorySlot in StoryPlan.slots():
			if slot.require and slot.realm == w.realm and not cast.has(slot.id):
				check(false, "seed %d: the required %s is cast" % [s, slot.id])
			if not DEALT.has(slot.needs) or slot.mirror != &"" or not cast.has(slot.id):
				continue
			var at: Vector2 = cast[slot.id].pos
			var step := int(cast[slot.id].get("keeper_step", 0))
			var margin := StoryCasting._keeper_margin(at, keepers)
			asked += 1
			(steps[step] as Array).append("s%d %s (%.0f off)" % [s, slot.id, margin])
			if step == 1:
				check(margin > StoryWorld.STOOD_REACH, "seed %d: %s, on step 1, stands %.0f past a keeper's ground, within %.0f" % [s, slot.id, margin, StoryWorld.STOOD_REACH])
			elif step == 2:
				check(margin > 0.0, "seed %d: %s, on step 2, is off every keeper's ground (%.0f)" % [s, slot.id, margin])
			else:
				check(step == 3, "seed %d: %s took a step of the ladder (%d)" % [s, slot.id, step])
			if margin <= 0.0 and step != 3:
				inside += 1
	print("       %d of %d story places on a keeper's ground; step 2: %s; step 3, the farthest its body allows: %s" % [
		inside, asked, steps[2], steps[3]])
	gt(float(asked), 200.0, "the story's places were asked (%d)" % asked)
	eq(inside, 0, "no place on a keeper's ground but where its body has no other")
	StoryPlan.forget()
