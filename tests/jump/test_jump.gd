extends TestCase
## The jump (owner, 2026-09-17): up two levels, across a two-tile gap, down three,
## and no further. Every rule is held against a small hand-made world where the
## step, the gap or the drop is exactly what the test says it is.

const Fx := preload("res://tests/survival/fixture.gd")


## A field at `base` with a band of `level` from column `from` to `to` (inclusive)
## running the whole height of it: a ledge, a trench or a drop, by the numbers.
func _field(base: int, band_from: int, band_to: int, band: int, beyond: int = -999, band_ground: int = Ground.GRASS) -> WorldData:
	var size := 40
	var w := WorldData.new(21, size)
	for y in size:
		for x in size:
			var i := y * size + x
			var rim := x == 0 or y == 0 or x == size - 1 or y == size - 1
			var l := base
			var g := Ground.GRASS
			if x >= band_from and x <= band_to:
				l = band
				g = band_ground
			elif x > band_to and beyond != -999:
				l = beyond
			w.level[i] = -1 if rim else l
			w.ground[i] = Ground.DEEP_WATER if rim else g
			w.country[i] = Country.SEA if rim else Country.COAST
	w.spawn = Vector2(18.5, 20.5)
	return w


## A jump from just short of column 20, heading east, on the move.
func _jump_east(w: WorldData, start_x: float = 19.55) -> JumpPlan:
	var q := WorldQuery.new(w)
	return Jump.plan(w, q, Vector2(start_x, 20.5), Vector2.RIGHT, Jump.CARRY)


# --- the reach the owner asked for ----------------------------------------------

func test_a_ledge_two_levels_up_is_reached() -> void:
	var w := _field(2, 20, 38, 4)
	var p := _jump_east(w)
	eq(p.kind, Jump.UP, "two levels up is a jump")
	eq(p.to_level, 4, "and it lands on top")
	gt(p.to.x, 20.0 + Tuning.PLAYER_RADIUS * 0.5, "with the body over the ledge, not against its face")


func test_a_ledge_three_levels_up_is_a_wall() -> void:
	var w := _field(2, 20, 38, 5)
	var p := _jump_east(w)
	eq(p.to_level, 2, "three levels up is still a cliff: the jump comes down where it left")
	lt(p.to.x, 20.0, "and never inside the rock")


func test_walking_still_cannot_climb_what_a_jump_can() -> void:
	var w := _field(2, 20, 38, 4)
	var q := WorldQuery.new(w)
	check(not q.passable(19, 20, 20, 20), "the ledge is a cliff to a walk: the jump is what opens it")


func test_a_gap_two_tiles_wide_is_crossed() -> void:
	# A trench two tiles wide and four levels deep, the same ground either side.
	var w := _field(4, 20, 21, 0, 4)
	var p := _jump_east(w)
	eq(p.kind, Jump.ACROSS, "the trench is jumped")
	eq(p.to_level, 4, "landing on the far side, at the height it left")
	gt(p.to.x, 22.0, "clear of the trench")


func test_a_gap_two_tiles_wide_is_crossed_from_anywhere_on_the_lip() -> void:
	var w := _field(4, 20, 21, 0, 4)
	eq(_jump_east(w, 19.5).kind, Jump.ACROSS, "from the middle of the last tile")
	eq(_jump_east(w, 20.0 - Tuning.PLAYER_RADIUS).kind, Jump.ACROSS, "and from right against the edge")


func test_a_gap_three_tiles_wide_is_not() -> void:
	var w := _field(4, 20, 22, 0, 4)
	# From right against the edge, the furthest a walk can take a body before it.
	var p := _jump_east(w, 20.0 - Tuning.PLAYER_RADIUS)
	check(p.to.x < 20.0 + Tuning.PLAYER_RADIUS or p.to.x > 23.0, "never landing somewhere it did not plan")
	check(p.kind != Jump.ACROSS, "three tiles is too far to cross")
	check(p.to_level >= 4 - Jump.DOWN_LEVELS - 1, "and whatever it does it does not fall in the deep")


func test_a_drop_of_three_levels_is_jumped_down() -> void:
	var w := _field(5, 20, 38, 2)
	var p := _jump_east(w)
	eq(p.kind, Jump.DOWN, "three down is a jump")
	eq(p.to_level, 2, "landing at the bottom")


func test_a_drop_deeper_than_a_jump_is_not_gone_off() -> void:
	var w := _field(7, 20, 38, 2)
	var p := _jump_east(w)
	eq(p.to_level, 7, "five down is the glide's: the jump comes down at the lip")
	lt(p.to.x, 20.0, "on the high side")


func test_a_drop_into_deep_water_is_a_dive_whatever_its_height() -> void:
	var w := _field(7, 20, 38, -2, -999, Ground.DEEP_WATER)
	var p := _jump_east(w)
	eq(p.kind, Jump.DIVE, "the water takes a body from any height")
	gt(p.to.x, 20.0, "and the body is in it")


func test_a_stretch_of_water_two_tiles_wide_is_cleared_dry() -> void:
	var w := _field(2, 20, 21, -1, 2, Ground.DEEP_WATER)
	var p := _jump_east(w)
	eq(p.kind, Jump.ACROSS, "the channel is jumped")
	check(w.ground_at(floori(p.to.x), floori(p.to.y)) != Ground.DEEP_WATER, "landing dry on the far bank")


func test_a_jump_on_flat_ground_is_a_hop_and_comes_down_where_it_should() -> void:
	var w := _field(2, 0, -1, 2)
	var q := WorldQuery.new(w)
	var p := Jump.plan(w, q, Vector2(10.5, 20.5), Vector2.RIGHT, Jump.CARRY)
	eq(p.kind, Jump.HOP, "nothing to reach is a hop")
	near(p.peak(), Jump.APEX, 0.05, "rising to the apex")
	near(p.to.x - 10.5, Jump.CARRY * p.seconds, 0.05, "and carried along at its pace")
	var still := Jump.plan(w, q, Vector2(10.5, 20.5), Vector2.ZERO, 0.0)
	near(still.to.x, 10.5, 1e-4, "a jump with nowhere to go comes down where it left")


func test_a_solid_thing_stops_a_body_in_the_air() -> void:
	var g := Fx.flat()
	var at := g.player.pos
	var rock := Fx.put(g, PropKind.BOULDER, Vector2(1.2, 0))
	check(rock != null and rock.solid > 0.0, "a boulder in the way")
	var p := Jump.plan(g.world, g.query, at, Vector2.RIGHT, Jump.CARRY)
	lt(p.to.x, rock.pos.x - rock.solid, "the jump does not go through it")


func test_the_plan_is_the_same_every_time() -> void:
	var w := _field(2, 20, 38, 4)
	var a := _jump_east(w)
	var b := _jump_east(w)
	eq(a.points.size(), b.points.size(), "the same arc")
	eq(a.to, b.to, "to the same place")


# --- the ability: legs are everybody's --------------------------------------------

func test_every_body_can_jump_without_wearing_anything() -> void:
	var book := AbilityBook.new()
	book.fit(Abilities.with_innate([] as Array[StringName]))
	check(book.has(&"jump"), "no gear, and still a jump")
	check(InputMap.has_action(&"jump"), "it has a key")
	var space := false
	for e: InputEvent in InputMap.action_get_events(&"jump"):
		var k := e as InputEventKey
		if k != null and k.physical_keycode == KEY_SPACE:
			space = true
	check(space, "the key is Space")
	for e: InputEvent in InputMap.action_get_events(&"swing"):
		var k := e as InputEventKey
		check(k == null or k.physical_keycode != KEY_SPACE, "and swing is no longer on it")
	check(not Abilities.IDS.has(&"jump"), "and nothing sold as gear grants it")


func _ctx(g: Game) -> AbilityCtx:
	var c := AbilityCtx.new()
	c.game = g
	c.now = 100.0
	return c


func _game_with_hero(w: WorldData) -> Game:
	var g := Fx.from_world(w)
	var hero := Hero.new()
	hero.body = g.body
	hero.inventory = g.inventory
	hero.pos = g.player.pos
	g.player.hero = hero
	return g


func test_a_jump_is_refused_from_the_water_a_deck_a_grip_and_the_air() -> void:
	var w := _field(2, 0, -1, 2)
	var g := _game_with_hero(w)
	var book := AbilityBook.new()
	book.fit(Abilities.with_innate([] as Array[StringName]))
	var hero: Hero = g.player.hero
	hero.swimming = true
	eq(book.press(&"jump", _ctx(g)), &"swimming", "nothing under the feet in the water")
	hero.swimming = false
	hero.airborne = true
	eq(book.press(&"jump", _ctx(g)), &"airborne", "nor in the air")
	hero.airborne = false
	hero.grip = 2
	eq(book.press(&"jump", _ctx(g)), &"held", "nor with something holding on")
	hero.grip = 0
	g.player.ride = CraftRide.new()
	eq(book.press(&"jump", _ctx(g)), &"riding", "nor off a deck")
	g.player.ride = null
	var ctx := _ctx(g)
	eq(book.press(&"jump", ctx), &"", "on the ground, it jumps")
	check(ctx.motion != null and ctx.motion.kind == &"jump", "handing over a jump to run")


func test_nothing_swings_or_rolls_from_the_air() -> void:
	var hero := Hero.new()
	hero.body = Body.new()
	hero.inventory = Inventory.new()
	hero.airborne = true
	eq(hero.swing_refusal(0.0), &"airborne", "a blow wants something to push against")
	eq(hero.dodge_refusal(0.0), &"airborne", "and so does a roll")


func test_the_motion_replays_the_plan_and_says_its_height_honestly() -> void:
	var w := _field(2, 20, 38, 4)
	var q := WorldQuery.new(w)
	var p := _jump_east(w)
	var m := AbilityMotion.jump(p)
	var at := p.from
	var highest := 0.0
	var over_ledge_low := INF
	for i in 400:
		at = m.step(1.0 / 60.0, at, w, q, Tuning.PLAYER_RADIUS)
		highest = maxf(highest, m.lift)
		if at.x > 20.1 and not m.finished:
			over_ledge_low = minf(over_ledge_low, m.lift)
		if m.finished:
			break
	check(m.finished, "it comes down")
	near(at.x, p.to.x, 1e-4, "where the plan said")
	eq(m.lift, 0.0, "on the ground")
	gt(highest, WorldData.STEP * 2.0, "having been higher than the ledge it climbed")
	# Over the ledge the ground under the body is two levels higher, so its height
	# above THAT ground is small: the shadow a lit world places from `lift` sits on
	# the ledge, not on the field the jump left.
	lt(over_ledge_low, Jump.APEX - WorldData.STEP * 2.0 + 0.05, "and its height is measured from the ground actually under it")


# --- finding one by name --------------------------------------------------------

func test_a_jump_of_each_kind_is_found_by_name() -> void:
	var up := _field(2, 20, 38, 4)
	var found := Jump.find(up, WorldQuery.new(up), Vector2(12.5, 20.5), Jump.UP)
	check(not found.is_empty(), "a ledge is found")
	if not found.is_empty():
		eq((found.plan as JumpPlan).kind, Jump.UP, "and a jump from there really is up")
	var down := _field(5, 20, 38, 2)
	check(not Jump.find(down, WorldQuery.new(down), Vector2(12.5, 20.5), Jump.DOWN).is_empty(), "a drop is found")
	var gap := _field(4, 20, 21, 0, 4)
	check(not Jump.find(gap, WorldQuery.new(gap), Vector2(12.5, 20.5), Jump.ACROSS).is_empty(), "a gap is found")
	var flat := _field(2, 0, -1, 2)
	check(Jump.find(flat, WorldQuery.new(flat), Vector2(12.5, 20.5), Jump.UP, 8.0).is_empty(), "and nothing where there is nothing")
