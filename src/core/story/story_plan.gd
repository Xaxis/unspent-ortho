class_name StoryPlan
## The guided path, and the test that makes it real (docs/DESIGN.md).
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

## The load-bearing slots, leg by leg (docs/STORY.md). The story crosses every
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


## Colour, one local per landscape (docs/STORY.md): each stands at the village
## of their own land nearest to where he woke, on whatever body that is. Never
## required and never ordered: a world not dealt that land has no such local,
## and meeting one moves the journey nowhere. Maren keeps the fire at `home`; the
## coast's local is at the next coast village along, `apart` so it is never hers.
##
## A land nobody lives in (`villages = 0`) still has a face: they camp by its
## landmark nearest home, because a landmark is the one per-region place every
## land holds. So does the mesas, whose single village is not grown on every
## world (seed 42 has none) while its landmarks are.
const LOCALS: Array[Dictionary] = [
	{"id": &"local_coast", "needs": &"village", "land": &"coast", "nearest": true, "ordered": false, "apart": 24.0},
	{"id": &"local_bonelands", "needs": &"village", "land": &"bonelands", "nearest": true, "ordered": false},
	{"id": &"local_burning", "needs": &"village", "land": &"burning", "nearest": true, "ordered": false},
	{"id": &"local_drowned_city", "needs": &"village", "land": &"drowned_city", "nearest": true, "ordered": false},
	{"id": &"local_green_towers", "needs": &"village", "land": &"green_towers", "nearest": true, "ordered": false},
	{"id": &"local_grey_orchards", "needs": &"village", "land": &"grey_orchards", "nearest": true, "ordered": false},
	{"id": &"local_machine_city", "needs": &"village", "land": &"machine_city", "nearest": true, "ordered": false},
	{"id": &"local_mesas", "needs": &"landmark", "land": &"mesas", "nearest": true, "ordered": false},
	{"id": &"local_moss", "needs": &"village", "land": &"moss", "nearest": true, "ordered": false},
	{"id": &"local_pinewood", "needs": &"village", "land": &"pinewood", "nearest": true, "ordered": false},
	{"id": &"local_ruined_metropolis", "needs": &"village", "land": &"ruined_metropolis", "nearest": true, "ordered": false},
	{"id": &"local_salt_flats", "needs": &"village", "land": &"salt_flats", "nearest": true, "ordered": false},
	{"id": &"local_scrapwood", "needs": &"village", "land": &"scrapwood", "nearest": true, "ordered": false},
	{"id": &"local_slums", "needs": &"village", "land": &"slums", "nearest": true, "ordered": false},
	{"id": &"local_snowfield", "needs": &"village", "land": &"snowfield", "nearest": true, "ordered": false},
	{"id": &"local_sulphur_jungle", "needs": &"village", "land": &"sulphur_jungle", "nearest": true, "ordered": false},
	{"id": &"local_the_crags", "needs": &"village", "land": &"the_crags", "nearest": true, "ordered": false},
	{"id": &"local_frost_sea", "needs": &"landmark", "land": &"frost_sea", "nearest": true, "ordered": false},
	{"id": &"local_glass_desert", "needs": &"landmark", "land": &"glass_desert", "nearest": true, "ordered": false},
	{"id": &"local_server_fields", "needs": &"landmark", "land": &"server_fields", "nearest": true, "ordered": false},
	{"id": &"local_the_middens", "needs": &"landmark", "land": &"the_middens", "nearest": true, "ordered": false},
	{"id": &"local_limestone_caves", "needs": &"village", "land": &"limestone_caves", "realm": &"underground", "nearest": true, "ordered": false},
]


## The lame walker's people (docs/STORY.md, the walkers): Tull, at the crater the
## walker lead pins (Guide.WAY `walker`), by the same rule (StoryCasting.crater_near),
## so where he stands and where the survey sends him never disagree. The walker's,
## not a landscape's, and colour: a world with no crater on the Covenant's body
## casts nobody here.
const WALKER: Array[Dictionary] = [
	{"id": &"the_tread", "needs": &"tread", "near": &"the_covenant", "ordered": false},
]


## Where the raft from home comes ashore: the world's landfall (StorySlot.LANDFALL),
## for the crossing 49_cast places (StoryCrossing). Nobody stands there.
const ASHORE: Array[Dictionary] = [
	{"id": &"the_landfall", "needs": &"landfall", "ordered": false},
]


## 2029, relived (docs/STORY.md). The Before is this same coast tile for tile
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
	for d: Dictionary in WALKER:
		out.append(StorySlot.make(d))
	for d: Dictionary in ASHORE:
		out.append(StorySlot.make(d))
	for d: Dictionary in THEN:
		out.append(StorySlot.make(d))
	return out


## Where every slot of the story stands in this world. Held per world, because
## it is pure and derived and the systems ask it on a beat: `20_realms` asks
## twice every 0.2 s through `StoryGates.all` and `.open`, and rebuilding it cost
## **15-44 ms a call** on a 1300-tile world -- the whole of the proc-side hitch
## left after the chapters one (#126, docs/DESIGN.md). Casting re-searches the
## world for a village, a works, a landmark and the black site per slot, and
## nothing it reads can move while a world stands.
##
## **KEYED ON THE WORLD ITSELF, NOT ON ITS SEED**, and the difference is a test
## that would have gone green against the bug. `tests/story/test_plan.gd` grows
## the same seed TWICE and casts both to prove the casting is deterministic — so
## a cache keyed `seed:size:realm` would hand the second world the first one's
## answer and that test would pass without the casting being deterministic at
## all. Identity cannot do that, and it also makes a realm crossing a miss for
## free, since the other realm is a different object.
static var _cast_world: WorldData = null
static var _cast: Dictionary = {}


static func cast(world: WorldData) -> Dictionary:
	if world == null:
		return {}
	if world == _cast_world:
		return _cast
	_cast_world = world
	var ready := _take_ready(world)
	_cast = ready[1] if bool(ready[0]) else StoryCasting.cast(world, slots())
	return _cast


## A world's casting worked out beside its raise (RealmWarm), for the first ask
## of that world to take: the first ask is a system's at setup, on the main
## thread the start waits on. Locked, because the raise is a worker; held weakly,
## so a world nobody entered takes its casting with it.
static var _ready: Dictionary = {}
static var _ready_lock := Mutex.new()


## Returns the casting, or {} where none was got ready.
static func prepare(world: WorldData) -> Dictionary:
	# The era's only where the surface it mirrors is cast already
	# (StoryCasting._twin): where it is not, it would grow a whole surface on the
	# worker.
	if world == null or (world.realm == Realm.ERA and not StoryCasting.has_twin(world)):
		return {}
	var got := StoryCasting.cast(world, slots())
	_ready_lock.lock()
	for k: int in _ready.keys():
		if ((_ready[k] as Array)[0] as WeakRef).get_ref() == null:
			_ready.erase(k)
	_ready[world.get_instance_id()] = [weakref(world), got]
	_ready_lock.unlock()
	return got


## [true, casting] when `world`'s was got ready, taken; else [false, {}].
static func _take_ready(world: WorldData) -> Array:
	_ready_lock.lock()
	var got: Array = _ready.get(world.get_instance_id(), [])
	_ready.erase(world.get_instance_id())
	_ready_lock.unlock()
	if got.is_empty() or (got[0] as WeakRef).get_ref() != world:
		return [false, {}]
	return [true, got[1]]


## Only the tests want this; a running game casts once per world for its life.
static func forget() -> void:
	_cast_world = null
	_cast = {}
	_ready_lock.lock()
	_ready.clear()
	_ready_lock.unlock()


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
		# Contract 3 (docs/DESIGN.md). A required slot may only name a
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
