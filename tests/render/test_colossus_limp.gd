extends TestCase
## The half-broken walker's limp (ColossusDef.limp, colossus_walk.gd `window`):
## timing alone. Its lame leg is longer in the air and hangs still over its plant
## before it sets down; every plant is where the sound gait set it, so the
## treads, their craters and the folk in them do not move (the world's own
## digests are tests/biome/test_parity.gd's).

const Def := preload("res://src/core/colossus/colossus_def.gd")
const Route := preload("res://src/core/colossus/colossus_route.gd")
const Walk := preload("res://src/core/colossus/colossus_walk.gd")
const Treads := preload("res://src/core/colossus/colossus_treads.gd")

## Every walker's plants over a lap and the treads it asks world generation for,
## on seeds 1 and 7, as main had them before the limp (6e437cb8; sha256 of
## `_plants`).
const PLANTS := {
	1: "17ede16a99d2aca646a8ecc2871c4aa1fc9623eb9c78d9683f9ed184268143d5",
	7: "cc50ce278e02895d5cd3ab1c2819dd5ec5ca1b6229a3d2aac440e08918ffa8f8",
}


## Every plant every walker sets down over its lap, with the way it faces, and
## the treads asked for, as one run of numbers.
func _plants(seed_value: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for d: RefCounted in Def.walkers(Tuning.WORLD_SIZE):
		var r: RefCounted = Route.make(d, seed_value, Tuning.WORLD_SIZE)
		for k in 3:
			for j in int(r.cycles()):
				var p: Vector3 = Walk.plant(d, r, k, j)
				out.append_array([p.x, p.y, p.z, Walk.plant_yaw(d, r, k, j)])
	for row: Dictionary in Treads.wanted(seed_value, Tuning.WORLD_SIZE):
		var at: Vector2 = row.natural
		out.append_array([float(row.leg), float(row.j), at.x, at.y, float(row.yaw)])
	return out


func _sha(a: PackedFloat64Array) -> String:
	var h := HashingContext.new()
	@warning_ignore("return_value_discarded")
	h.start(HashingContext.HASH_SHA256)
	@warning_ignore("return_value_discarded")
	h.update(a.to_byte_array())
	return h.finish().hex_encode()


func test_the_limp_moves_no_plant() -> void:
	for s: int in PLANTS:
		var got := _sha(_plants(s))
		print("  seed %d plants: %s" % [s, got])
		eq(got, PLANTS[s], "seed %d: every plant and tread asked for is main's" % s)


## Minutes leg `k` is in the air over one whole cycle, and the longest run of
## them its foot hung still, off the ground.
func _air(d: RefCounted, r: RefCounted, k: int) -> Vector2:
	var cyc: float = d.cycle_minutes
	var step := 0.25
	var up := 0.0
	var still := 0.0
	var most := 0.0
	var was := Vector3.INF
	var t := 0.0
	while t < cyc:
		var fs: Array = Walk.foot(d, r, k, t)
		var at: Vector3 = fs[0]
		if float(fs[1]) >= 0.0:
			up += step
			still = still + step if at.distance_to(was) < 1e-3 and at.y > 50.0 else 0.0
			most = maxf(most, still)
		was = at
		t += step
	return Vector2(up, most)


func test_the_lame_leg_swings_longer_and_hangs_before_it_plants() -> void:
	var d: RefCounted = Def.tripod(&"C")
	var sound: float = d.swing_minutes
	for s: int in [1, 7]:
		var r: RefCounted = Route.make(d, s, Tuning.WORLD_SIZE)
		check(r.lame >= 0, "seed %d: the straddling walker limps" % s)
		eq(r.lame, int(Treads.wanted(s, Tuning.WORLD_SIZE)[0].leg), "seed %d: on the leg of the nearest tread, the one climbed" % s)
		for k in 3:
			var air := _air(d, r, k)
			print("  seed %d leg %d: %.1f minutes up, hung still %.1f" % [s, k, air.x, air.y])
			if k == r.lame:
				gt(air.x, sound * 1.25, "seed %d: the lame leg is up longer than a sound one" % s)
				gt(air.y, air.x * float(d.hitch) * 0.95, "and hangs still before it plants")
			else:
				lt(air.x, sound, "seed %d leg %d: a sound leg steps quicker to cover it" % [s, k])
				lt(air.y, 1.0, "and never hangs")


## Only a walker that limps has a lame leg: the others' gait is the sound one.
func test_only_the_half_broken_walker_limps() -> void:
	for d: RefCounted in Def.walkers(Tuning.WORLD_SIZE):
		var r: RefCounted = Route.make(d, 1, Tuning.WORLD_SIZE)
		eq(r.lame >= 0, d.circuit == &"C", "%s limps only if it is the straddling one" % d.id)
		if r.lame < 0:
			for k in 3:
				eq(Walk.window(d, r, k), Vector2(float(k) / 3.0, d.swing_share()), "%s leg %d: the sound window" % [d.id, k])
