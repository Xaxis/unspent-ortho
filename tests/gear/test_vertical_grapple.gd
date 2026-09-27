extends TestCase
## THE VERTICAL LINE (mechanics improvement 5b; AbilityGrapple.vertical). At the
## foot of a face, of any ground, with something solid standing at its top, the
## grapple's line goes straight up to that hold and hauls the body up the face
## and over the lip, quick; no further than MAX_UP levels; with nothing to hold
## at the top it is the old line or none; and on the face the body is at the
## level it has been hauled to, as a climber is.

const Fx := preload("res://tests/survival/fixture.gd")
const LIP := 25


func _game(up: int) -> Game:
	var w := WorldData.new(11, 48)
	for y in 48:
		for x in 48:
			var i := y * 48 + x
			var rim := x == 0 or y == 0 or x == 47 or y == 47
			w.level[i] = -1 if rim else (2 + up if x >= LIP else 2)
			w.ground[i] = Ground.DEEP_WATER if rim else Ground.GRASS
			w.country[i] = Country.SEA if rim else Country.COAST
	w.spawn = Vector2(LIP - 0.6, 20.5)
	var g := Fx.from_world(w)
	g.player.pos = Vector2(LIP - 0.6, 20.5)
	g.player.facing = 0.0
	return g


func test_at_the_foot_of_a_face_with_a_post_on_top_the_line_goes_up() -> void:
	var g := _game(6)
	check(AbilityGrapple.vertical(g.world, g.query, g.player.pos, Vector2.RIGHT).is_empty(), "nothing on top: no vertical line")
	var post := Survival.add_prop(g, PropKind.POLE, Vector2(LIP + 1.2, 20.5))
	var a := AbilityGrapple.anchor(g.world, g.query, g.player.pos, Vector2.RIGHT)
	eq(a.get("what", &""), &"face", "a post at the top of a turf face is a hold for a line up it")
	var book := AbilityBook.new()
	book.fit([&"grapple"] as Array[StringName])
	var ctx := AbilityCtx.new()
	ctx.game = g
	ctx.now = 0.0
	ctx.fx = func(_w: StringName, _a: Dictionary) -> void: pass
	eq(book.press(&"grapple", ctx), &"", "the line takes")
	var m := ctx.motion
	eq(m.kind, &"haul", "and hauls")
	var p := g.player.pos
	var t := 0.0
	var highest := 0
	while not m.finished and t < 5.0:
		p = m.step(1.0 / 60.0, p, g.world, g.query, Tuning.PLAYER_RADIUS)
		highest = maxi(highest, m.at_level)
		t += 1.0 / 60.0
	check(m.finished, "the haul ends")
	eq(g.world.level_at(floori(p.x), floori(p.y)), 8, "on the top")
	lt(p.distance_to(post.pos), AbilityGrapple.HOLD_REACH + 0.5, "by the post it held")
	lt(t, 6.0 / AbilityGrapple.HAUL_RATE + 0.8, "six levels in about a second (%.2f s)" % t)
	gt(float(highest), 4.0, "and on the way it was at the level it had been hauled to")
	Fx.done(g)


func test_the_line_is_eight_levels_long_and_no_longer() -> void:
	var g := _game(10)
	Survival.add_prop(g, PropKind.POLE, Vector2(LIP + 1.2, 20.5))
	check(AbilityGrapple.vertical(g.world, g.query, g.player.pos, Vector2.RIGHT).is_empty(), "ten levels up: out of reach")
	check(AbilityGrapple.anchor(g.world, g.query, g.player.pos, Vector2.RIGHT).get("what", &"") != &"ledge", "and not a ledge pull either")
	Fx.done(g)


func test_the_line_goes_up_from_the_foot_not_from_across_the_field() -> void:
	var g := _game(6)
	Survival.add_prop(g, PropKind.POLE, Vector2(LIP + 1.2, 20.5))
	g.player.pos = Vector2(LIP - 3.5, 20.5)
	check(AbilityGrapple.vertical(g.world, g.query, g.player.pos, Vector2.RIGHT).is_empty(), "three tiles off the foot, the line is the old one")
	Fx.done(g)
