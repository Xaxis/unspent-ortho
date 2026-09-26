extends TestCase
## What hides a body short of a wall: the ground, what grows in it, and the
## night. And the lamp, which undoes all of it.

const Fx := preload("res://tests/fight/fixture.gd")


func _world(ground: int) -> WorldData:
	return Fx.flat_world(32, ground)


func test_open_ground_in_daylight_hides_nothing() -> void:
	var w := _world(Ground.SAND)
	eq(Cover.at(w, null, Vector2(10.5, 10.5), false, 0.0, false), 0.0, "on bare sand at noon")


func test_the_heather_hides_a_body_that_gets_down_in_it() -> void:
	var w := _world(Ground.HEATH)
	var standing := Cover.at(w, null, Vector2(10.5, 10.5), false, 0.0, false)
	var down := Cover.at(w, null, Vector2(10.5, 10.5), true, 0.0, false)
	gt(standing, 0.0, "walking through it is worth something")
	gt(down, standing * 2.0, "getting down in it is worth a great deal more")
	lt(standing, 0.2, "but not much on its own")


func test_a_prop_you_can_get_behind_beats_the_ground() -> void:
	var w := _world(Ground.SAND)
	var q := WorldQuery.new(w)
	var at := Vector2(10.5, 10.5)
	eq(Cover.at(w, q, at, false, 0.0, false), 0.0, "nothing there yet")
	w.add_prop(WorldProp.new(1, PropKind.GORSE, at + Vector2(0.4, 0.0), 0.0, 1.0))
	q = WorldQuery.new(w)
	var behind := Cover.at(w, q, at, false, 0.0, false)
	near(behind, Cover.PROPS[PropKind.GORSE], 1e-4, "a gorse bush is most of the way")
	gt(Cover.at(w, q, at, true, 0.0, false), behind, "and better crouched")
	lt(Cover.at(w, q, at + Vector2(6.0, 0.0), false, 0.0, false), 0.05, "six tiles off it is nothing")


func test_a_prop_that_has_been_taken_away_is_not_cover() -> void:
	var w := _world(Ground.SAND)
	var at := Vector2(10.5, 10.5)
	w.add_prop(WorldProp.new(1, PropKind.GORSE, at + Vector2(0.3, 0.0), 0.0, 1.0))
	var q := WorldQuery.new(w)
	gt(Cover.at(w, q, at, false, 0.0, false), 0.4, "while it stands")
	w.depleted[1] = -1.0
	eq(Cover.at(w, q, at, false, 0.0, false), 0.0, "once it is gone")


func test_the_night_is_cover_and_it_stacks_with_what_you_are_standing_in() -> void:
	var w := _world(Ground.HEATH)
	var day := Cover.at(w, null, Vector2(10.5, 10.5), true, 0.0, false)
	var night := Cover.at(w, null, Vector2(10.5, 10.5), true, 1.0, false)
	gt(night, day, "the dark adds to the heather")
	gt(Cover.at(w, null, Vector2(10.5, 10.5), false, 1.0, false), 0.0, "and is worth something standing")
	lt(night, 1.0, "nothing is ever perfectly hidden")


func test_the_lamp_undoes_every_bit_of_it() -> void:
	var w := _world(Ground.HEATH)
	var at := Vector2(10.5, 10.5)
	w.add_prop(WorldProp.new(1, PropKind.GORSE, at + Vector2(0.3, 0.0), 0.0, 1.0))
	var q := WorldQuery.new(w)
	gt(Cover.at(w, q, at, true, 1.0, false), 0.6, "crouched in gorse at night")
	eq(Cover.at(w, q, at, true, 1.0, true), 0.0, "with the lamp lit, nothing at all")
