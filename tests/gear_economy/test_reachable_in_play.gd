extends TestCase
## The last mile of "obtainable", and the one nothing measured before.
##
## `test_obtainable.gd` walks the TABLES — this roster row names that country, so
## the material is reachable. `test_in_a_real_world.gd` asks whether the gate
## landscape is on the island a seed grew. Neither asks the question a player
## actually asks: **stand in the best place at the right hour and does the machine
## come?**
##
## It is a different question because `Spawner.roll` puts a body on a tile in the
## square ring 11..18 around the player, and only after `place_fits` has passed on
## THAT tile. What decides whether a kind can be met is therefore not how much of
## the island suits it but how much suits it AT ONCE, inside one ring. Two kinds
## fail that and `NOT_ROLLED` names them, because a gate the spawner cannot
## satisfy is an elite material nobody can have.

const SIZE := 256
## Rolls come every 200 ms of play, so this is about 40 minutes of standing still
## in the best place on the island.
const ROLLS := 12000
const HOURS: Array[float] = [2.0, 7.0, 12.0, 17.0, 22.0]

## Measured here, on seed 1, and each is a debt rather than a decision. Take a
## line out when its `where` is loosened; do not add one to make this pass.
##
##   lineman   `near_props` (a pylon or pole within 4) and `green_min` 34 and the
##             snowfield's own grounds leave SIX tiles on a 65536-tile island, and
##             40 minutes stood at the best of them rolled nothing. A lineman is a
##             worker, so nothing sends one either: `line_coil` has no door.
##   longlegs  `green_min` 55, and seed 1's island only reaches 56 from green at
##             its deepest. It is rolled almost nowhere — but it is a HUNTER, and
##             a hunted network SENDS one past `place_fits` entirely
##             (`32_disposition._spot_for`), which is the door
##             `test_the_jig_at_the_top_of_the_ladder_is_reachable_by_being_hunted`
##             walks. So this line is about the roll, not about the material.
const NOT_ROLLED: Array[StringName] = [&"lineman", &"longlegs"]


func _declared() -> void:
	GearEconomy.declare(true)
	Sources.clear()


func _game(args: PackedStringArray) -> Game:
	var o := BootOptions.parse(args)
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	return g


## Tiles the spawner would take `kind` on, as a flat 0/1 grid.
static func _marks(kind: StringName, w: WorldData, q: WorldQuery, hour: float, step: int) -> PackedInt32Array:
	var row := Roster.row(kind)
	var g := PackedInt32Array()
	g.resize(SIZE * SIZE)
	for ty: int in range(0, SIZE, step):
		for tx: int in range(0, SIZE, step):
			if Spawner.place_fits(row, w, q, tx, ty, kind, hour):
				g[ty * SIZE + tx] = 1
	return g


## Inclusive prefix sums with a row and column of padding, so a box is four reads.
static func _sums(g: PackedInt32Array) -> PackedInt32Array:
	var s := PackedInt32Array()
	s.resize((SIZE + 1) * (SIZE + 1))
	for y: int in SIZE:
		var acc := 0
		for x: int in SIZE:
			acc += g[y * SIZE + x]
			s[(y + 1) * (SIZE + 1) + x + 1] = s[y * (SIZE + 1) + x + 1] + acc
	return s


static func _box(s: PackedInt32Array, x0: int, y0: int, x1: int, y1: int) -> int:
	x0 = clampi(x0, 0, SIZE)
	y0 = clampi(y0, 0, SIZE)
	x1 = clampi(x1 + 1, 0, SIZE)
	y1 = clampi(y1 + 1, 0, SIZE)
	if x1 <= x0 or y1 <= y0:
		return 0
	var w := SIZE + 1
	return s[y1 * w + x1] - s[y0 * w + x1] - s[y1 * w + x0] + s[y0 * w + x0]


## How many marked tiles the spawn ring around (x, y) covers.
static func _in_ring(s: PackedInt32Array, x: int, y: int) -> int:
	var out := Spawner.RING_MAX
	var inn := Spawner.RING_MIN - 1
	return _box(s, x - out, y - out, x + out, y + out) - _box(s, x - inn, y - inn, x + inn, y + inn)


func test_standing_in_the_best_place_really_rolls_the_machine_that_carries_it() -> void:
	_declared()
	var w := WorldGen.generate(1, SIZE)
	var q := WorldQuery.new(w)
	var spawner := Spawner.new()
	var m := Moment.new()
	m.seed_value = w.seed_value
	for id: StringName in EliteStock.ids():
		var kind := EliteStock.kind_of(id)
		if kind == &"":
			continue
		# The hour this kind works, taken coarsely, then marked tile by tile.
		var best_hour := -1.0
		var most := -1
		for hour: float in HOURS:
			var n := 0
			for v: int in _marks(kind, w, q, hour, 4):
				n += v
			if n > most:
				most = n
				best_hour = hour
		var g := _marks(kind, w, q, best_hour, 1)
		var marked := 0
		for v: int in g:
			marked += v
		var s := _sums(g)
		# Stand where the ring covers the most of them.
		var stood := Vector2.INF
		var cover := 0
		for y: int in range(0, SIZE, 2):
			for x: int in range(0, SIZE, 2):
				if Ground.is_water(w.ground_at(x, y)) or not q.standable(x, y):
					continue
				var n := _in_ring(s, x, y)
				if n > cover:
					cover = n
					stood = Vector2(x + 0.5, y + 0.5)
		check(stood != Vector2.INF, "%s: nowhere to stand whose ring covers a %s tile" % [id, kind])
		if stood == Vector2.INF:
			continue
		# Late enough that a hunter's share is up and every `day_min` is met.
		m.minutes = 24.0 * 60.0 * 6.0 + best_hour * 60.0
		var got := 0
		for i in ROLLS:
			if StringName(spawner.roll(i, w, q, m, stood, 0).get("kind", &"")) == kind:
				got += 1
		print("  %s (%s): %d tiles island-wide at %02d:00, best ring covers %d, %d of %d rolls put one out"
			% [id, kind, marked, int(best_hour), cover, got, ROLLS])
		if NOT_ROLLED.has(kind):
			eq(got, 0, "%s rolls now: take %s out of NOT_ROLLED and say so" % [kind, kind])
			continue
		gt(float(got), 0.0,
			"%s is cut out of a %s, and standing at the best place on the island at its own hour never rolled one in %d rolls"
			% [id, kind, ROLLS])


## The jig is the whole top of the making ladder — `CraftTiers.JIG` is what every
## PRIME and RELIC recipe is made on, and it is cut out of a longlegs, which the
## spawner will barely roll. The door that is really there is the other one: a
## network at `hunted` SENDS a hunter, and `32_disposition._spot_for` falls back
## past `place_fits` because "this one was sent, not rolled for". So the top of
## the ladder is paid for by making the plan come after you, which is a better
## price than a walk into empty country — but nothing said so, and nothing held
## it, so a change to `_hunter_for_here` could take the jig out of the game
## without a single test going red.
func test_the_jig_at_the_top_of_the_ladder_is_reachable_by_being_hunted() -> void:
	_declared()
	eq(EliteStock.kind_of(CraftTiers.JIG_TOOL), &"longlegs", "the jig is the hunter's")
	var g := _game(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0"]))
	# Past the longlegs' own `day_min` of 3. The moment is read off the clock
	# every frame, so moving the clock is the whole of it.
	g.clock.minutes = 24.0 * 60.0 * 3.0 + 11.0 * 60.0
	await frames(3)
	gt(float(g.clock.day()), 2.0, "the third day or later")
	var sys := g.get_node("32_disposition")
	var sim := g.player.sim
	var coast: Node = g.get_node("30_mobs")
	(coast.get(&"coast") as Coast).spawning = false
	sim.clear_mobs()
	await frames(20)
	eq(sim.living(), 0, "nothing is rolled here, so what comes was sent")
	var f: Interference = sys.get(&"interference")
	f.levels[Interference.network(g.world, g.player.pos)] = Interference.THRESHOLDS[3] + 0.05
	await frames(60)
	var sent: StringName = &""
	for mob: MobState in sim.mobs:
		if mob.sent and mob.alive:
			sent = mob.kind
			break
	eq(sent, &"longlegs",
		"a hunted network on day 4 sends the longlegs the jig is cut out of; it sent %s" % sent)
	g.queue_free()
	await frames(1)
