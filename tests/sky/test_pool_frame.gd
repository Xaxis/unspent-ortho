extends TestCase
## The lamp pool goes to what the player SEES first (15_lights `pool_before`):
## tier 0 a light on screen, tier 1 one whose pool only spills in, tier 2 the
## rest, nearest first within a tier. The picture is held by `perf lights` at
## burning dusk, where the web tier's seven lit two sources out of the frame and
## never the stolen neon in the middle of it.

const Lights := preload("res://src/systems/15_lights.gd")


func _pick(cands: Array, budget: int) -> Array:
	var c := cands.duplicate()
	c.sort_custom(Lights.pool_before)
	return c.slice(0, budget)


## THE CASE THAT FOOLED THE FIRST RULE: two lights just out of the frame whose
## reach spills into it, nearer than a light that is IN the frame. A rule asking
## only "does its reach touch the frame" called all three in and fell back to
## distance, and so does the old distance-only rule: both take the two spillers.
func test_a_light_on_screen_beats_nearer_ones_whose_pool_only_spills_in() -> void:
	var spill_a := [4.0, {"name": "spill a"}, 1]
	var spill_b := [5.0, {"name": "spill b"}, 1]
	var on_screen := [20.0, {"name": "neon on screen"}, 0]
	var got := _pick([spill_a, spill_b, on_screen], 2)
	check(got.has(on_screen), "with a budget of two the light on screen is taken")


func test_a_spilling_pool_beats_a_nearer_light_nowhere_near_the_frame() -> void:
	var behind := [2.0, {"name": "behind the camera"}, 2]
	var spill := [9.0, {"name": "spills in"}, 1]
	eq(_pick([behind, spill], 1), [spill], "a pool the player sees part of beats one they see none of")


func test_within_a_tier_the_nearer_wins() -> void:
	check(Lights.pool_before([4.0, {}, 0], [9.0, {}, 0]), "on screen, nearer first")
	check(Lights.pool_before([4.0, {}, 2], [9.0, {}, 2]), "and off it, nearer first too")


## A LAMP JUST BELOW THE FRAME'S EDGE is not on screen, even though a point two
## units above it is -- the body door (`sees_ground`) counted it by that raised
## point and a lamp off the frame outranked the stolen neon in it. Asked of a
## real pitched camera: find a point below the bottom edge whose raised point is
## inside, and with no reach to spill it must be tier 2.
func test_a_lamp_below_the_edge_is_not_on_screen_by_its_raised_point() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 15.0
	tree.root.add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0.0, 25.2, 16.3)
	cam.look_at(Vector3.ZERO)
	var found := false
	var below := Vector3.ZERO
	for i in 400:
		var at := Vector3(0.0, 0.0, float(i) * 0.05)
		if not CameraRig.sees_point(cam, at, 0.0) and CameraRig.sees_ground(cam, at, 0.0):
			below = at
			found = true
			break
	check(found, "a point exists just past the bottom edge whose raised point is in the frame")
	if found:
		eq(Lights.frame_tier(cam, below, 0.0), 2, "a lamp there with no reach is tier 2, not on screen")
		eq(Lights.frame_tier(cam, Vector3.ZERO, 0.0), 0, "and one at the centre of the frame is tier 0")
	cam.free()
