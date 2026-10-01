extends TestCase
## A PIN IS A BEARING, NEVER "HERE". A place he has been told of that lies off the
## glass is pinned at its edge on its bearing (UiMapScreen.pin); the survey opens
## framed so that pin stands well clear of his own mark and points the way the
## world does (UiMapScreen.opening). Measured on real worlds, seeds 1 and 7, at
## the two moments a pin matters: at the spawn, told of the crew's camp; at the
## camp, having walked there, told of the archive across the water; and at the
## archive, told of the shaft on another body, which seed 1 pins into the scale
## bar's corner: a pin never stands under the survey's compass or scale bar
## (UiMapScreen.clear_of).

## The least distance, in survey pixels, between his mark and a pin.
const APART := 200.0
## The most a pin's bearing may differ from the world's, in degrees.
const WITHIN := 5.0


func _check(world: WorldData, seen: Rect2i, player: Vector2, target: Vector2, what: String) -> void:
	var told: Array[Vector2] = [target]
	var f := UiMapScreen.opening(seen, player, told, UiMapScreen.MAP_RECT.size, UiMapScreen.SCALES)
	var scale := float(f.scale)
	var me := UiMapScreen.glass_at(f.centre, scale, player)
	var at := UiMapScreen.glass_at(f.centre, scale, target)
	var r := UiMapScreen.MAP_RECT.grow(-UiMapScreen.PIN_INSET)
	if r.has_point(at):
		return
	var pin := UiMapScreen.pin(me, at, r)
	gt(Vector2(pin).distance_to(Vector2(me)), APART, "seed %d %s: the pin stands well clear of his own mark" % [world.seed_value, what])
	var want := rad_to_deg((target - player).angle())
	var got := rad_to_deg(Vector2(pin - me).angle())
	lt(absf(wrapf(got - want, -180.0, 180.0)), WITHIN, "seed %d %s: and points the way the world does" % [world.seed_value, what])
	var fixed := UiMapScreen.furniture(UiMapScreen.MAP_RECT, scale)
	var half := 5 * UiBase.PITCH
	var clear := UiMapScreen.clear_of(pin, fixed, half, UiMapScreen.MAP_RECT.get_center().y)
	print("  seed %d %s: pinned at %s, clear of the furniture at %s" % [world.seed_value, what, pin, clear])
	for b: Rect2i in fixed:
		check(not b.grow(half).has_point(clear), "seed %d %s: and it stands under neither the compass nor the scale bar" % [world.seed_value, what])
	lt(absf(wrapf(rad_to_deg(Vector2(clear - me).angle()) - want, -180.0, 180.0)), WITHIN, "seed %d %s: still on its bearing" % [world.seed_value, what])


func test_a_pin_points_the_way_and_is_never_here() -> void:
	for s: int in [1, 7]:
		var w := WorldGen.generate(s, 1840)
		var cast := StoryPlan.cast(w)
		var home: Vector2 = w.spawn
		# Waking: the land seen is what he has walked round the spawn.
		var woke := Rect2i(Vector2i(home) - Vector2i(20, 20), Vector2i(40, 40))
		if cast.has(&"the_camp"):
			_check(w, woke, home, cast[&"the_camp"].pos, "the crew from the spawn")
		if cast.has(&"the_camp") and cast.has(&"the_archive"):
			# At the camp, having walked there: the land seen runs from the spawn to him.
			var camp: Vector2 = cast[&"the_camp"].pos
			var walked := woke.expand(Vector2i(camp)).grow(10)
			_check(w, walked, camp, cast[&"the_archive"].pos, "the archive from the camp")
		if cast.has(&"the_archive") and cast.has(&"the_shaft"):
			# Across at the archive, told of the relay below by the man there.
			var arc: Vector2 = cast[&"the_archive"].pos
			_check(w, Rect2i(Vector2i(arc) - Vector2i(20, 20), Vector2i(40, 40)), arc, cast[&"the_shaft"].pos, "the shaft from the archive")
	StoryPlan.forget()


## Two places on nearly one bearing pin side by side at the glass's edge (from the
## Covenant, the narrows he landed at and the crew's camp beyond them): the second
## word goes on its mark's left rather than being dropped (UiMapScreen.word_box).
func test_two_pins_side_by_side_both_keep_their_words() -> void:
	var glass := UiMapScreen.MAP_RECT
	var placed: Array[Rect2i] = []
	var free := func(box: Rect2i) -> bool: return not placed.any(func(o: Rect2i) -> bool: return o.intersects(box))
	var crew := Vector2i(glass.get_center().x + 20, glass.end.y - UiMapScreen.PIN_INSET)
	var a := UiMapScreen.word_box(crew, "the crew", glass, free)
	check(a.has_area(), "the first pin's word is placed")
	check(a.position.x > crew.x, "on its mark's right")
	placed.append(a)
	var narrows := crew - Vector2i(46, 0)
	var b := UiMapScreen.word_box(narrows, "the narrows", glass, free)
	check(b.has_area(), "the pin beside it keeps its word")
	check(b.end.x < narrows.x, "on its mark's left")
	check(not b.intersects(a), "clear of the first word")
