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

## The load-bearing slots, leg by leg (docs/STORY.md §5). The story crosses every
## continent in order, from the coast Elias wakes on to the farthest shore, where
## the Tether stands: `leg` says which, and `StoryJourney` says where that is in
## THIS world. Per-REGION features only (StorySlot.NEEDS says why), and only
## `home` names a landscape, because the coast is the one a world cannot be without.
##
## The orbit leg is declared as COLOUR until the orbital realm is grown: a required
## slot in a realm nobody can reach would fail every world, so `the_ring` casts
## nowhere today and whoever stands there (Oksana) waits for it.
const SPINE: Array[Dictionary] = [
	# Leg 0, the home coast: where he wakes, his town, the first works.
	{"id": &"home", "needs": &"village", "land": &"coast", "leg": 0, "nearest": true, "require": true},
	# The old THRESHOLD site in the sea off that coast, where he died and was grown.
	{"id": &"the_black_site", "needs": &"black_site", "leg": 0, "require": true},
	{"id": &"the_yard", "needs": &"works", "leg": 0, "apart": 24.0, "require": true},
	# The Holdfast's camp, where Rook's crew waits.
	{"id": &"the_camp", "needs": &"landmark", "leg": 0, "apart": 20.0, "require": true},
	# Leg 1, across the water: the Covenant's seat, and the archive of the war.
	{"id": &"the_covenant", "needs": &"village", "leg": 1, "require": true},
	{"id": &"the_archive", "needs": &"landmark", "leg": 1, "apart": 32.0, "require": true},
	# Leg 2, below: the way down to HALCYON's deep plant.
	{"id": &"the_shaft", "needs": &"portal", "leg": 2, "require": true},
	# Leg 3, the far shore: the Emissary's works at the Tether's foot.
	{"id": &"the_far_works", "needs": &"works", "leg": 3, "require": true},
	# Leg 4, orbit: the dead ring, where the last colonist is still calling.
	{"id": &"the_ring", "needs": &"landmark", "realm": &"orbital", "leg": 4, "require": false},
]


## Colour, one local per landscape (docs/STORY.md §8): each stands at the village
## of their own land nearest to where he woke, on whatever body that is. Never
## required and never ordered: a world not dealt that land has no such local,
## and meeting one moves the journey nowhere. The coast's is Maren, at `home`.
const LOCALS: Array[Dictionary] = [
	{"id": &"local_bonelands", "needs": &"village", "land": &"bonelands", "nearest": true, "ordered": false},
	{"id": &"local_burning", "needs": &"village", "land": &"burning", "nearest": true, "ordered": false},
	{"id": &"local_moss", "needs": &"village", "land": &"moss", "nearest": true, "ordered": false},
	{"id": &"local_pinewood", "needs": &"village", "land": &"pinewood", "nearest": true, "ordered": false},
	{"id": &"local_salt_flats", "needs": &"village", "land": &"salt_flats", "nearest": true, "ordered": false},
	{"id": &"local_scrapwood", "needs": &"village", "land": &"scrapwood", "nearest": true, "ordered": false},
	{"id": &"local_slums", "needs": &"village", "land": &"slums", "nearest": true, "ordered": false},
	{"id": &"local_snowfield", "needs": &"village", "land": &"snowfield", "nearest": true, "ordered": false},
	{"id": &"local_limestone_caves", "needs": &"village", "land": &"limestone_caves", "realm": &"underground", "nearest": true, "ordered": false},
]


## 2029, relived (docs/STORY.md §6). The Before is this same coast tile for tile
## (Realm.ERA, unspent-ortho-df), so each place of his old life is cast exactly
## where a 2098 place of the story stands (`mirror`): his house is the village he
## wakes beside, Cairn's lab is where the first works yard rose, his handler met
## him where the Holdfast now camps, and THRESHOLD is the platform in the sea.
## Colour until a gate opens into the era.
const THEN: Array[Dictionary] = [
	{"id": &"then_home", "needs": &"village", "land": &"coast", "realm": &"era", "nearest": true, "ordered": false, "mirror": &"home"},
	{"id": &"then_lab", "needs": &"works", "realm": &"era", "apart": 24.0, "ordered": false, "mirror": &"the_yard"},
	{"id": &"then_meet", "needs": &"landmark", "realm": &"era", "apart": 20.0, "ordered": false, "mirror": &"the_camp"},
	{"id": &"then_site", "needs": &"black_site", "realm": &"era", "ordered": false, "mirror": &"the_black_site"},
]


static func slots() -> Array[StorySlot]:
	var out: Array[StorySlot] = []
	for d: Dictionary in SPINE:
		out.append(StorySlot.make(d))
	for d: Dictionary in LOCALS:
		out.append(StorySlot.make(d))
	for d: Dictionary in THEN:
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
		# A slot in another realm is checked when that realm's world is grown.
		if s.realm != world.realm:
			continue
		if s.require and not done.has(s.id):
			out.append("%s could not be cast in seed %d (%s, %d wide): the spine cannot be finished there" % [s.id, world.seed_value, world.realm, world.size])
	return out
