extends TestCase
## GROUND ABOVE THE GROUND, S0 (WorldData.overhead; scratchpad DESIGN_ABOVE): the
## layer and its reads, and every rule that assumed nothing hangs overhead asked
## again with something there. Synthetic worlds, no content: a flat field at
## level 2 (1.0 up) with mass hung over bands of it.

const F := preload("res://tests/fight/fixture.gd")
const Shoulder := preload("res://src/core/view/shoulder.gd")
const GROUND := 2


func _world() -> WorldData:
	return F.flat_world(64, Ground.GRASS, Country.COAST, GROUND)


## A band of roof over columns x0..x1, `room` levels above the ground, 4 thick.
func _roof(w: WorldData, x0: int, x1: int, room: int) -> void:
	for x in range(x0, x1 + 1):
		for y in w.size:
			w.set_overhead(x, y, GROUND + room, GROUND + room + 4)


## THE READS: nothing over a tile is open all the way up; mass over it is solid
## between its underside and its top and air below; headroom counts levels.
func test_the_reads() -> void:
	var w := _world()
	eq(w.headroom_at(10, 10), WorldData.OPEN_ABOVE, "nothing overhead: open")
	check(not w.solid_at(Vector2(10.5, 10.5), 3.0), "air over open ground")
	check(w.solid_at(Vector2(10.5, 10.5), 0.5), "and ground under the ground")
	w.set_overhead(10, 10, GROUND + 6, GROUND + 10)
	eq(w.headroom_at(10, 10), 6, "six levels of room")
	check(not w.solid_at(Vector2(10.5, 10.5), 2.5), "under the roof, air")
	check(w.solid_at(Vector2(10.5, 10.5), 4.5), "inside the roof, solid")
	check(not w.solid_at(Vector2(10.5, 10.5), 6.5), "over its top, air")


## THE WALK: a person walks under a roof with room for them and is stopped by one
## without; a runner, shorter, gets under the low one.
func test_a_low_roof_is_a_wall_to_a_person_and_a_crawlway_to_a_runner() -> void:
	var w := _world()
	_roof(w, 26, 28, 6)
	_roof(w, 34, 36, 3)
	var q := WorldQuery.new(w)
	var person := FightSim.HERO_TALL
	var runner := FightSim.tall_of(Roster.row(&"runner"))
	gt(float(person), 3.0, "a person needs more than three levels (%d)" % person)
	lt(float(runner), 4.0, "a runner three or fewer (%d)" % runner)
	var walk := func(tall: int) -> Vector2:
		var p := Vector2(20.5, 20.5)
		for i in 400:
			p = q.move_body(p, Vector2(0.05, 0.0), Tuning.PLAYER_RADIUS, null, false, tall)
		return p
	var went: Vector2 = walk.call(person)
	gt(went.x, 29.0, "a person walks under the high roof (%.2f)" % went.x)
	lt(went.x, 34.0, "and is stopped at the low one (%.2f)" % went.x)
	gt((walk.call(runner) as Vector2).x, 37.0, "a runner gets under both")
	gt((walk.call(0) as Vector2).x, 37.0, "and a move that asks nothing overhead is as it was")


## SIGHT AND SHOT: a roof across the line at the height it runs hides one end
## from the other; a high one does not.
func test_a_roof_across_the_line_hides_as_a_wall_does() -> void:
	var w := _world()
	var q := WorldQuery.new(w)
	var a := Vector2(20.5, 20.5)
	var b := Vector2(30.5, 20.5)
	check(Senses.line_clear(w, q, a, b), "open: the line is clear")
	# The line runs Senses.SIGHT_HEIGHT (0.9) over the ground: mass hanging to
	# 0.5 over it cuts the line, mass from 1.5 up is over it.
	w.set_overhead(25, 20, GROUND + 1, GROUND + 8)
	check(not Senses.line_clear(w, q, a, b), "mass coming down past the line's height blocks it")
	w.set_overhead(25, 20, GROUND + 3, GROUND + 8)
	check(Senses.line_clear(w, q, a, b), "a roof over it does not")


## THE JUMP: under a low roof the head meets the underside, the rise stops, and
## the same jump lands short of where it lands in the open.
func test_a_jump_under_a_low_roof_lands_short() -> void:
	var w := _world()
	var q := WorldQuery.new(w)
	var open := Jump.plan(w, q, Vector2(20.5, 20.5), Vector2(1, 0), Jump.CARRY)
	# Five levels (2.5) of room: a person stands under it with 0.7 to spare, and
	# a jump's apex (Jump.APEX, 1.25) would put the head into it.
	_roof(w, 18, 40, 5)
	var under := Jump.plan(w, q, Vector2(20.5, 20.5), Vector2(1, 0), Jump.CARRY)
	var peak := 0.0
	for h: float in under.heights:
		peak = maxf(peak, h)
	lt(peak, float(GROUND + 5) * WorldData.STEP - Tuning.PLAYER_HEIGHT + 0.01, "the head never goes into the roof")
	lt(under.to.x, open.to.x - 0.2, "and it lands short (%.2f against %.2f)" % [under.to.x, open.to.x])


## THE CLIMB: a rock face is climbed in the open; with mass hanging low over its
## foot, or over its shelf, it is not a climb at all.
func test_a_climb_needs_room_over_its_foot_and_its_top() -> void:
	var w := _world()
	for y in w.size:
		for x in range(30, w.size):
			w.level[y * w.size + x] = GROUND + 4
			w.ground[y * w.size + x] = Ground.ROCK
	var q := WorldQuery.new(w)
	var at := Vector2(29.6, 20.5)
	check(not Climb.face(w, q, at, Vector2(1, 0)).is_empty(), "in the open, a face")
	w.set_overhead(29, 20, GROUND + 5, GROUND + 9)
	check(Climb.face(w, q, at, Vector2(1, 0)).is_empty(), "an overhang over its foot: none")
	w.overhead.clear()
	w.set_overhead(30, 20, GROUND + 4 + 2, GROUND + 4 + 6)
	check(Climb.face(w, q, at, Vector2(1, 0)).is_empty(), "a shelf with no room over it: none")


## THE EYE: a roof over the line from the head back to the eye pulls the eye in,
## as a wall does; with none, all the room there is.
func test_the_shoulder_eye_comes_in_under_a_roof() -> void:
	var flat := func(_p: Vector2) -> float: return float(GROUND) * WorldData.STEP
	var head := Vector3(20.5, 2.6, 20.5)
	var eye := Vector3(20.5, 3.4, 24.0)
	var solids: Array[Vector4] = []
	var none: Array[PackedFloat32Array] = []
	near(Shoulder.room(head, eye, flat, solids, none), 1.0, 0.001, "open: all the room")
	var roof: Array[PackedFloat32Array] = []
	for z in range(21, 26):
		roof.append(Shoulder.box_over(20, z, 3.0, 5.0))
	lt(Shoulder.room(head, eye, flat, solids, roof), 1.0, "under a roof the eye comes in")


## THE COST: with nothing overhead, a step asks one `is_empty` more than it did.
## Best of five interleaved runs each, so a busy machine slows both alike.
func test_the_open_path_costs_nothing_measurable() -> void:
	var w := _world()
	var q := WorldQuery.new(w)
	var run := func(tall: int) -> int:
		var t0 := Time.get_ticks_usec()
		var p := Vector2(20.5, 20.5)
		for i in 4000:
			p = q.move_body(p, Vector2(0.0005, 0.0), Tuning.PLAYER_RADIUS, null, false, tall)
		return Time.get_ticks_usec() - t0
	var bare := 1 << 40
	var asked := 1 << 40
	for i in 5:
		bare = mini(bare, run.call(0))
		asked = mini(asked, run.call(FightSim.HERO_TALL))
	print("overhead cost: 4000 steps, asking nothing %d us, asking headroom over empty %d us" % [bare, asked])
	lt(float(asked), float(bare) * 1.3 + 1000.0, "asking headroom where nothing hangs is about free")
