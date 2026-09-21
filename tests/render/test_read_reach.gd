extends TestCase
## What the play camera can actually hold, asked of a real camera rather than
## derived — and the case `Landmarks.read_reach` does not cover.
##
## `read_reach`'s header is careful and correct: it names three limits (up the
## screen a base is in frame to `half / sin p`, about 8.9 tiles; down the screen
## height BUYS distance; across there is none to spend) and then deliberately
## returns the smaller of the last two, "in frame over most of the compass". So
## it is not wrong, it is PARTIAL: it omits the up-screen limit on purpose,
## because a landmark may lie at any bearing.
##
## The omission stops being harmless the moment the thing's FOOT is off the
## ground. Under this camera both height and away-distance project UP-screen and
## they ADD, so an object hung `foot` units up has already spent `foot * cos p`
## of the half-frame before it is any distance away at all:
##
##     ahead reach = (half - foot * cos p) / sin p
##
## At `foot` 0 that is the header's 8.9. At a slums hologram's foot over a
## `block` roof (4.6 + HoloView.LIFT) it is 5.5 tiles, and over a `stack` or a
## `spire` it is NEGATIVE — no distance ahead of the player puts it in frame.
## `HoloView` gathers on an unsigned 24-tile radius and keeps the nearest ten, so
## it fills its pool with buildings that cannot be on screen (task #116: four
## measured, every screen Y between 562 and 1665 pixels above the top edge).
##
## Nothing here is derived: every number is read off `unproject_position`.

const ASPECT := 16.0 / 9.0
## Feet worth asking about, in world units off the ground: a landmark standing on
## it, then a hologram over each RAISED roof (`BiomeForms.FORMS` high + LIFT).
const FEET: Array[float] = [0.0, 5.3, 11.3, 17.0]


func _camera() -> Camera3D:
	var vp := SubViewport.new()
	vp.size = UiBase.SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(vp)
	var cam := Camera3D.new()
	# Exactly what CameraRig._ready sets, asked of the rig rather than respelled.
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = CameraRig.VIEW_HEIGHT
	cam.near = 1.0
	cam.far = 250.0
	cam.rotation = Vector3(deg_to_rad(-CameraRig.PITCH_DEG), deg_to_rad(45.0), 0.0)
	vp.add_child(cam)
	# Orthographic: where the camera sits along its OWN view axis cannot move a
	# screen position, so standing it back is only ever about the clip planes.
	cam.position = cam.global_transform.basis.z * 30.0
	return cam


func _away(cam: Camera3D) -> Vector3:
	var a := -cam.global_transform.basis.z
	return Vector3(a.x, 0.0, a.z).normalized()


## The furthest AHEAD (up-screen) a point `foot` units off the ground is still
## inside the top edge. Stepped finely and read off the camera.
func _measured_ahead(cam: Camera3D, foot: float) -> float:
	var away := _away(cam)
	var last := -1.0
	var d := 0.0
	while d < 40.0:
		if cam.unproject_position(away * d + Vector3(0.0, foot, 0.0)).y < 0.0:
			break
		last = d
		d += 0.05
	return last


func test_a_lifted_foot_loses_its_reach_ahead_of_the_player() -> void:
	var cam := _camera()
	var p := deg_to_rad(CameraRig.PITCH_DEG)
	var half := CameraRig.VIEW_HEIGHT * 0.5
	for foot: float in FEET:
		var got := _measured_ahead(cam, foot)
		var rule := (half - foot * cos(p)) / sin(p)
		var partial := Landmarks.read_reach(CameraRig.VIEW_HEIGHT, CameraRig.PITCH_DEG, ASPECT, foot)
		print("foot %5.1f -> camera holds it ahead to %5.2f tiles, rule %5.2f, read_reach %5.2f"
			% [foot, got, rule, partial])
		if rule <= 0.0:
			lt(got, 0.0, "a foot %.1f up is off the top at every distance ahead, but the camera held it to %.2f"
				% [foot, got])
		else:
			near(got, rule, 0.1,
				"the ahead rule answers %.2f tiles for a foot %.1f up; the camera drops it at %.2f"
					% [rule, foot, got])
	cam.get_parent().queue_free()


## The claim task #116 could only make by running a whole game: the pool is fed
## buildings the frame cannot reach. Asked here of the camera and the form table.
func test_a_hologram_over_a_tall_roof_is_never_in_frame_ahead() -> void:
	var p := deg_to_rad(CameraRig.PITCH_DEG)
	var half := CameraRig.VIEW_HEIGHT * 0.5
	var never: Array[String] = []
	for form: StringName in BiomeForms.RAISED:
		var row: Variant = BiomeForms.FORMS.get(form)
		if not (row is Dictionary):
			continue
		var high := float((row as Dictionary).get(BiomeForms.HIGH, 0.0))
		if high < 4.0:
			continue
		var foot := high + HoloView.LIFT
		var ahead := (half - foot * cos(p)) / sin(p)
		print("form %-8s roof %5.1f -> hologram foot %5.1f, in frame ahead to %6.2f tiles"
			% [form, high, foot, ahead])
		if ahead <= 0.0:
			never.append(String(form))
	check(not never.is_empty(),
		"expected some raised forms to hang a hologram the frame can never hold ahead; none did")
	print("forms whose hologram is never in frame ahead of the player: %s" % ", ".join(never))
