class_name StoryPlan
## The guided path, and the test that makes it real (docs/STORY_SYSTEM.md §6).
##
## The owner's ruling: a procedurally generated world must still offer a general
## guided path toward success. That is a promise about EVERY seed, so it is worth
## exactly as much as the check behind it — `problems(world)` is that check, and it
## runs in the gate over a sample of worlds beside the ones `Landmarks`,
## `GearEconomy` and `BiomeRegistry` already make.
##
## Without it the guided path is a claim. With it, a world that cannot carry the
## story is a content error somebody sees in `tools/check.sh`, rather than a player
## stuck at three in the morning on seed 12.

## The load-bearing slots. Per-REGION features only, on purpose (StorySlot.NEEDS
## says why): a village, a works depot, a landmark. Every continent has those
## whatever landscapes it drew.
##
## `home` is the one slot allowed to name a landscape, because the coast is the one
## landscape a world cannot be without — the player wakes beside a coast village
## (`GenSettle.spawn`). Everything else asks for a KIND of place and lets the world
## decide which.
##
## This is the spine's skeleton, not its content: the words, the leads and the
## stages hang off these ids and are being written against them.
const SPINE: Array[Dictionary] = [
	{"id": &"home", "needs": &"village", "land": &"coast", "require": true},
	{"id": &"the_yard", "needs": &"works", "apart": 24.0, "require": true},
	{"id": &"the_walk", "needs": &"landmark", "apart": 32.0, "require": true},
	# Colour, not load: a crossing is a thread worth finding and the spine must be
	# finishable without it.
	{"id": &"the_shaft", "needs": &"portal", "apart": 20.0, "require": false},
]


static func slots() -> Array[StorySlot]:
	var out: Array[StorySlot] = []
	for d: Dictionary in SPINE:
		out.append(StorySlot.make(d))
	return out


static func cast(world: WorldData) -> Dictionary:
	return StoryCasting.cast(world, slots())


## Everything wrong with the story in THIS world, in words a writer can act on.
## Empty is the promise kept.
static func problems(world: WorldData) -> Array[String]:
	var out: Array[String] = []
	var ss := slots()
	var seen := {}
	for s: StorySlot in ss:
		if s.id == &"":
			out.append("a slot with no id")
			continue
		if seen.has(s.id):
			out.append("%s is declared twice" % s.id)
		seen[s.id] = true
		if not StorySlot.NEEDS.has(s.needs):
			out.append("%s needs %s, which is not a kind of place" % [s.id, s.needs])
		# Contract 3 (docs/STORY_SYSTEM.md §11). A required slot may only name a
		# landscape every world is guaranteed to carry. An exclusive one carries
		# colour, never load — a beat gating an arc on a landscape a world may not
		# contain strands any player who never crosses the ocean.
		if s.require and s.land != &"" and not StoryWorld.guaranteed(s.land):
			out.append("%s REQUIRES %s, which a world is not guaranteed to carry — make it colour, or have that landscape declare spread.least >= 1" % [s.id, s.land])
	if world == null:
		return out
	var done := StoryCasting.cast(world, ss)
	for s: StorySlot in ss:
		if s.require and not done.has(s.id):
			out.append("%s could not be cast in seed %d (%s, %d wide): the spine cannot be finished there" % [s.id, world.seed_value, world.realm, world.size])
	return out
