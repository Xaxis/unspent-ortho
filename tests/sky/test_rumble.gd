extends TestCase
## THE FELT QUEUE (src/core/sky/rumble.gd): what a far event sends the player,
## each on its own real speed. It was 19_colossi's `_coming`; pulling it out for
## the falls must leave every colossus landing arriving exactly when and in the
## order it did.

const Rumble := preload("res://src/core/sky/rumble.gd")
const Walk := preload("res://src/core/colossus/colossus_walk.gd")


## THE QUEUE AS 19_colossi HAD IT (its `_land` and `_arrive` before the
## extraction, with colossus_walk.gd's delays as they were written then, d / 3000
## and d / 343): the reference the extracted queue is held to.
class Before:
	var coming: Array = []
	func land(at: Vector3, d: float) -> void:
		coming.append([d / 3000.0, &"quake", at, d])
		coming.append([d / 3000.0, &"thump", at, d])
		coming.append([d / 343.0, &"boom", at, d])
	func arrive(delta: float) -> Array:
		var out: Array = []
		var i := 0
		while i < coming.size():
			var c: Array = coming[i]
			c[0] = float(c[0]) - delta
			if float(c[0]) > 0.0:
				i += 1
				continue
			coming.remove_at(i)
			out.append([c[1], c[2], c[3]])
		return out


## Landings at many distances, sent over many frames of uneven length: every
## arrival on the same frame, in the same order, with the same numbers.
func test_colossus_landings_arrive_as_they_did() -> void:
	var old := Before.new()
	var now := Rumble.new()
	var frame := 0
	var arrived := 0
	while frame < 20000 or (now.size() > 0 and frame < 100000):
		# A landing now and then, 400 m to 200 km off.
		if frame % 97 == 0 and frame < 20000:
			var d := 400.0 * pow(500.0, Rng.hash01(3, frame))
			var at := Vector3(d, 0.0, float(frame))
			old.land(at, d)
			now.landing(at, d)
		var delta := 0.004 + 0.05 * Rng.hash01(5, frame)
		var a := old.arrive(delta)
		var b := now.arrive(delta)
		eq(b.size(), a.size(), "frame %d: as many arrive" % frame)
		if b.size() != a.size():
			return
		for i in a.size():
			eq(b[i].what, a[i][0], "frame %d: the same thing" % frame)
			eq(b[i].at, a[i][1], "from the same place")
			eq(b[i].d, a[i][2], "as far off")
		arrived += a.size()
		frame += 1
	gt(float(arrived), 600.0, "hundreds of arrivals compared")
	eq(now.size(), 0, "and nothing left on its way")


## The two speeds the queue is stated in are the ground's and the air's, the
## colossi's numbers unchanged.
func test_the_ground_and_the_air_carry_it_at_their_speeds() -> void:
	near(Rumble.ground_delay(30000.0), 10.0, 1e-4, "the ground at 3 km/s")
	near(Rumble.air_delay(34300.0), 100.0, 1e-4, "the air at 343 m/s")
	for d: float in [10.0, 1000.0, 55000.0, 149000.0]:
		eq(Walk.ground_delay(d), Rumble.ground_delay(d), "the walk's ground delay is the queue's at %.0f m" % d)
		eq(Walk.air_delay(d), Rumble.air_delay(d), "and its air delay")


## Anything may be sent on it: a fall's boom rides the same queue.
func test_anything_can_be_sent() -> void:
	var r := Rumble.new()
	r.send(2.0, &"fall_boom", Vector3.ONE, 700.0)
	eq(r.arrive(1.5).size(), 0, "not yet")
	var got := r.arrive(0.6)
	eq(got.size(), 1, "then it arrives")
	eq(got[0].what, &"fall_boom", "what was sent")
	r.send(5.0, &"x", Vector3.ZERO, 1.0)
	r.clear()
	eq(r.size(), 0, "a queue can be emptied (a world swapped under it)")
