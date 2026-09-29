extends TestCase
## A PIN IS A BEARING, NEVER "HERE". A place he has been told of that lies off the
## glass is pinned at its edge on its bearing (UiMapScreen.pin); the survey opens
## framed so that pin stands well clear of his own mark and points the way the
## world does (UiMapScreen.opening). Measured on real worlds, seeds 1 and 7, at
## the two moments a pin matters: at the spawn, told of the crew's camp; at the
## camp, having walked there, told of the archive across the water.

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
	StoryPlan.forget()
