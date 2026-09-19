extends TestCase
## What is under the pointer (`DevRegions.ground_under`), which is the one
## question both of the flyover's mouse controls rest on.
##
## Drag holds the ground still under the pointer and the wheel zooms about it,
## and both are that function twice with a subtraction in between. A tour cannot
## press a mouse, so this is where the arithmetic is held: if it is right, a drag
## that felt wrong is a tuning argument, and if it is wrong no amount of tuning
## will ever make the map feel attached to the hand.


## A camera IN THE TREE, because `project_ray_origin` answers off a viewport and
## a rig built on its own has none — the one thing that makes this test need a
## scene at all.
var _made: Array[Node] = []

func _rig(world: WorldData, at: Vector2, high: float) -> CameraRig:
	var cam := CameraRig.new()
	tree.root.add_child(cam)
	_made.append(cam)
	cam.view_height = high
	cam.snap_to(world.to_3d(at))
	cam.force_update_transform()
	return cam


func teardown() -> void:
	for n: Node in _made:
		n.queue_free()
	_made.clear()


func test_the_middle_of_the_screen_is_what_the_camera_is_on() -> void:
	var w := BootWorld.world(4, 128)
	var here := Vector2(64.0, 64.0)
	var cam := _rig(w, here, 30.0)
	var mid: Vector2 = Vector2(UiBase.screen().size) * 0.5
	var hit := DevRegions.new().ground_under(cam, mid, w)
	check(hit.is_finite(), "the middle of the frame is on the world")
	# Within a tile: the camera stands back from a point on the ground and the ray
	# is walked rather than solved, so a fraction of a tile is the honest bar.
	near(hit.x, here.x, 1.5, "x under the middle")
	near(hit.y, here.y, 1.5, "y under the middle")


func test_two_points_across_the_screen_are_a_frame_apart() -> void:
	# The scale has to be right or a drag moves the world at the wrong speed —
	# the single thing that makes a map feel detached from the hand.
	var w := BootWorld.world(4, 128)
	var cam := _rig(w, Vector2(64.0, 64.0), 20.0)
	var screen := Vector2(UiBase.screen().size)
	var dr := DevRegions.new()
	var left := dr.ground_under(cam, Vector2(screen.x * 0.25, screen.y * 0.5), w)
	var right := dr.ground_under(cam, Vector2(screen.x * 0.75, screen.y * 0.5), w)
	check(left.is_finite() and right.is_finite(), "both are on the world")
	# Half the frame's width across. The camera shows `view_height` world units
	# tall and the frame is 16:9, so half its width is view_height * 16/9 / 2.
	var want := 20.0 * (16.0 / 9.0) * 0.5
	near(left.distance_to(right), want, want * 0.25, "half a frame across")


func test_zooming_out_puts_more_world_under_the_same_two_points() -> void:
	var w := BootWorld.world(4, 128)
	var dr := DevRegions.new()
	var screen := Vector2(UiBase.screen().size)
	var a := Vector2(screen.x * 0.3, screen.y * 0.5)
	var b := Vector2(screen.x * 0.7, screen.y * 0.5)
	var near_cam := _rig(w, Vector2(64.0, 64.0), 15.0)
	var far_cam := _rig(w, Vector2(64.0, 64.0), 60.0)
	var close := dr.ground_under(near_cam, a, w).distance_to(dr.ground_under(near_cam, b, w))
	var wide := dr.ground_under(far_cam, a, w).distance_to(dr.ground_under(far_cam, b, w))
	gt(wide, close * 3.0, "four times the height is about four times the ground")


func test_off_the_world_is_nowhere_and_never_a_guess() -> void:
	# A drag that runs off the edge of the island must STOP, not warp: the mouse
	# handler reads INF as "do not move", and a point silently clamped to the last
	# tile would slide the map sideways every time the pointer left the land.
	#
	# Stood in the world's corner and asked about the far side of the frame, which
	# is off the world by construction. The first version of this asked about a
	# point four thousand pixels above the screen and assumed that was nowhere — it
	# is not: an orthographic ray from up there still comes down on the height
	# field, and where it lands is arithmetic rather than intuition.
	var w := BootWorld.world(4, 128)
	var cam := _rig(w, Vector2(3.0, 3.0), 40.0)
	var screen := Vector2(UiBase.screen().size)
	var dr := DevRegions.new()
	var off := dr.ground_under(cam, Vector2(screen.x * 0.02, screen.y * 0.98), w)
	check(not off.is_finite(), "past the corner of the world is nowhere, got %s" % off)
