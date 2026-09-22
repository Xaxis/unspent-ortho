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
func _measured_ahead(cam: Camera3D, foot: float, limit := 40.0, step := 0.05) -> float:
	var away := _away(cam)
	var last := -1.0
	var d := 0.0
	while d < limit:
		if cam.unproject_position(away * d + Vector3(0.0, foot, 0.0)).y < 0.0:
			break
		last = d
		d += step
	return last


## The furthest BEHIND the focus (down-screen) a point is still inside the bottom
## edge. Stops the moment the point passes behind the camera's own near plane,
## because `unproject_position` mirrors what is behind it and would answer
## confidently with nonsense -- the exact failure this file exists to avoid.
func _measured_behind(cam: Camera3D, foot: float, limit := 60.0, step := 0.05) -> float:
	var away := _away(cam)
	var rows: float = cam.get_viewport().get_visible_rect().size.y
	var inv := cam.global_transform.affine_inverse()
	var last := -1.0
	var d := 0.0
	while d < limit:
		var at := away * -d + Vector3(0.0, foot, 0.0)
		if (inv * at).z > -cam.near:
			break
		if cam.unproject_position(at).y > rows:
			break
		last = d
		d += step
	return last


## The camera the LENS makes, exactly as `CameraRig._ready` and `_apply_lens`
## build it: perspective, its own fov and pitch, and stood `lens_back()` back along
## its own axis from the focus -- which for a perspective camera is not a free
## choice the way it is above, because where the eye sits decides the picture.
func _lens_camera() -> Camera3D:
	var vp := SubViewport.new()
	vp.size = UiBase.SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = CameraRig.LENS_FOV
	# `_ready` sets this from `view_height` whatever the lens is, and NOTHING
	# writes it afterwards -- so a lens camera really is carrying 15.0 in a
	# property its projection ignores, and leaving it at Godot's default 1.0 here
	# would have this file print a stale value the game never actually holds.
	cam.size = CameraRig.VIEW_HEIGHT
	cam.near = 1.0
	cam.far = 500.0
	cam.rotation = Vector3(deg_to_rad(-CameraRig.LENS_PITCH), deg_to_rad(45.0), 0.0)
	vp.add_child(cam)
	cam.position = cam.global_transform.basis.z * CameraRig.lens_back()
	return cam


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


## WHAT THE SECOND PROJECTION REACHES, and the reason the spawner cannot follow
## it with a corrected constant.
##
## The orthographic frame is SYMMETRIC about the player -- `half / sin p` ahead
## and the same behind -- which is the shape `Spawner.in_view` is built on and
## the reason its ring has always been safely outside the picture. A frustum has
## no such shape: pitched shallow, its top edge runs nearly level with the
## horizon and the ground it holds runs away an order of magnitude further, while
## the bottom edge is only a few tiles behind the player.
##
## Both numbers are read off `unproject_position`, never derived, because the
## whole value of this file is that it asks the object.
func test_the_lens_holds_ground_the_orthographic_frame_cannot() -> void:
	var lens := _lens_camera()
	var ahead := _measured_ahead(lens, 0.0, 260.0, 0.1)
	var behind := _measured_behind(lens, 0.0, 60.0, 0.1)
	var ortho := _camera()
	var o_ahead := _measured_ahead(ortho, 0.0)
	var o_behind := _measured_behind(ortho, 0.0)
	print("ortho vh %.1f pitch %.0f -> ahead %6.2f  behind %6.2f tiles"
		% [CameraRig.VIEW_HEIGHT, CameraRig.PITCH_DEG, o_ahead, o_behind])
	print("lens  fov %.0f pitch %.0f back %.1f -> ahead %6.2f  behind %6.2f tiles"
		% [CameraRig.LENS_FOV, CameraRig.LENS_PITCH, CameraRig.lens_back(), ahead, behind])
	# The negative this run has to be able to produce: if the frustum were built
	# wrong, the lens would answer somewhere near the orthographic 8.9 and every
	# claim below would be false.
	# The bars are stated against the ORTHOGRAPHIC frame rather than as absolute
	# tile counts, because the pitch is a live choice: at 30 the lens reached 152
	# tiles and at 40 it reaches 31, and a bar of "40 tiles" would have been a bar
	# on the pitch wearing a bar on the projection.
	gt(ahead, o_ahead * 2.0, "the lens reaches %.2f ahead against the frame's %.2f" % [ahead, o_ahead])
	# And it is NOT symmetric, which is the whole of why a box cannot stand in.
	lt(behind, ahead * 0.4, "the lens holds %.2f behind against %.2f ahead" % [behind, ahead])
	# Inside the streamer's cap, which is what the pitch was chosen for: past it
	# the near square is capped and `world_far` carries the rest.
	lt(ahead, 110.0, "the lens reaches %.2f, past WorldView.near_limit" % ahead)
	near(o_ahead, o_behind, 0.2, "the orthographic frame is symmetric: %.2f ahead, %.2f behind" % [o_ahead, o_behind])
	lens.get_parent().queue_free()
	ortho.get_parent().queue_free()


## THE HEADLINE, asked of both objects rather than argued: under the lens, every
## tile the spawner is allowed to put a machine on is in the picture.
##
## `Spawner.in_view` is what decides where a body may land, and `30_mobs` feeds
## it `camera.view_height` and `camera.pitch_deg` before every spawn. Neither is
## written by `_apply_lens` -- it rotates from `LENS_PITCH` and leaves both
## exports alone -- so under the lens the spawner scores a 15-unit box pitched 57
## against a picture taken at 30 with a 55 degree fov, and answers confidently.
func test_under_the_lens_every_spawn_ring_tile_is_on_screen() -> void:
	var cam := _lens_camera()
	var rows: float = cam.get_viewport().get_visible_rect().size.y
	var cols: float = cam.get_viewport().get_visible_rect().size.x
	# What 30_mobs hands the spawner while the lens is drawing: the rig's own
	# exports, untouched by `_apply_lens`.
	var sp := Spawner.new()
	sp.view_height = CameraRig.VIEW_HEIGHT
	sp.pitch_deg = CameraRig.PITCH_DEG
	var yaw := deg_to_rad(sp.yaw_deg)
	var up := Vector2(-sin(yaw), -cos(yaw))
	var drawn_tiles := 0
	var on_screen_but_unseen := 0
	for ring in range(Spawner.RING_MIN, Spawner.RING_MAX + 1):
		var tile := up * float(ring)
		var at := Vector3(tile.x, 0.0, tile.y)
		var s := cam.unproject_position(at)
		var drawn := s.y >= 0.0 and s.y <= rows and s.x >= 0.0 and s.x <= cols
		var hidden := not sp.in_view(Vector2.ZERO, tile)
		if drawn:
			drawn_tiles += 1
		if drawn and hidden:
			on_screen_but_unseen += 1
		print("ring %2d ahead -> screen (%6.0f,%6.0f) drawn %s, spawner calls it unseen %s"
			% [ring, s.x, s.y, drawn, hidden])
	var span := Spawner.RING_MAX - Spawner.RING_MIN + 1
	eq(drawn_tiles, span, "every tile of the spawn ring ahead of the player is in the lens's picture")
	# ALL BUT THE NEAREST. The box reaches `half / sin 57` plus its 2-tile margin,
	# which is 9.5 tiles along the view, so ring 11 (9.22 along it) is the one
	# distance it still catches -- and the first version of this test asserted all
	# eight, which is the claim being one tile larger than the evidence. The shape
	# is what is wrong; the boundary is exactly where the arithmetic puts it.
	eq(on_screen_but_unseen, span - 1,
		"every ring tile past the nearest is drawn by the lens and called unseen by the spawner")
	cam.get_parent().queue_free()


## THE SPAWNER'S FALLBACK IS THE RIG'S, and this is the only thing holding the
## two together: `src/core/mobs/spawner.gd` may not import `CameraRig`, because
## core is pure rules and the rig is a node in `src/render`. So the number is
## spelled there and asserted here.
##
## It read 14.0 for the life of the file, under a comment saying "(CameraRig
## defaults)". In play nothing moved -- `30_mobs` overwrites it at setup and
## before every spawn -- so the delta is entirely in headless callers, and it is
## exactly one tile of the ring: along the view axis a ring tile sits
## `r * sin 57` out, the box reaches `half + 2.0`, so ring 11 (9.22) was OUTSIDE
## a 14-unit box (9.0) and is INSIDE a 15-unit one (9.5). Ring 11 directly ahead
## of the player stopped being somewhere a test may put a machine.
func test_the_spawners_camera_fallback_is_the_rigs() -> void:
	var sp := Spawner.new()
	eq(sp.view_height, CameraRig.VIEW_HEIGHT, "the spawner falls back to the rig's own view height")
	eq(sp.pitch_deg, CameraRig.PITCH_DEG, "and to its pitch")
	# The tile the change moved, stated as the boundary rather than as a count:
	# the 14-unit box did not hold it and the 15-unit box does.
	var yaw := deg_to_rad(sp.yaw_deg)
	var up := Vector2(-sin(yaw), -cos(yaw))
	var ring := up * float(Spawner.RING_MIN)
	check(sp.in_view(Vector2.ZERO, ring), "ring %d ahead is inside the frame the rig really has" % Spawner.RING_MIN)
	var was := Spawner.new()
	was.view_height = 14.0
	check(not was.in_view(Vector2.ZERO, ring),
		"and was outside the 14-unit box this file's own delta is about")
	print("ring %d ahead: %.2f tiles along the view; box reaches %.2f at vh 14, %.2f at vh %.1f"
		% [Spawner.RING_MIN, float(Spawner.RING_MIN) * sin(deg_to_rad(sp.pitch_deg)),
			14.0 * 0.5 + 2.0, CameraRig.VIEW_HEIGHT * 0.5 + 2.0, CameraRig.VIEW_HEIGHT])


## THE ONE DOOR for world units per screen pixel, which five sites used to open
## by dividing `cam.size` by the viewport height.
##
## Under the orthographic projection it must still be exactly that division, or
## every mark, texel and hatch offset in the game moves. Under the lens it must
## NOT be: `size` is a property Godot keeps on any Camera3D and a perspective
## projection ignores, so the old arithmetic answers 15.0 for ever -- confidently,
## which is the failure this whole thread is about.
func test_one_door_answers_for_both_projections() -> void:
	var rows := float(UiBase.SIZE.y)
	var ortho := _camera()
	var was := ortho.size / rows
	near(CameraRig.units_per_pixel_of(ortho, rows), was, 1e-9,
		"the orthographic answer is the division it replaces, to the bit")
	var lens := _lens_camera()
	# A DELIBERATELY MISMATCHED LENS, because the shipped one no longer can be.
	# `lens_back` derives the distance so the two projections agree at the focal
	# plane, which means the door's answer and the stale `size / rows` are now
	# equal for the shipped constants -- and an assertion that they DIFFER was
	# really an assertion that the lens was still broken. So the claim is made
	# where it can be made: a lens standing somewhere the invariant does not put
	# it, where the frustum and the property genuinely disagree.
	# The lever is the FOV, not the position: for a bare Camera3D the door uses
	# the lens's own resting distance by design (it is not a rig and cannot be
	# asked where it stands), so moving it changes nothing and would have proved
	# nothing. Widening the frustum changes what a pixel covers and leaves `size`
	# exactly where `_ready` put it.
	lens.fov = 90.0
	var got := CameraRig.units_per_pixel_of(lens, rows)
	var stale := lens.size / rows
	# What the lens really shows per pixel at the focal plane, from its own fov
	# and how far back it stands -- and what the old arithmetic would have said.
	var rule := 2.0 * tan(deg_to_rad(90.0) * 0.5) * CameraRig.lens_back() / rows
	print("units per pixel: ortho %.6f | lens %.6f (rule %.6f), `size / rows` would say %.6f"
		% [was, got, rule, stale])
	near(got, rule, 1e-9, "the lens answers from its own frustum")
	check(absf(got - stale) > 1e-4,
		"the lens answer must differ from the stale `size / rows`, or nothing was fixed")
	# And the sharpest part of it: the stale answer is not nonsense, it is the
	# ORTHOGRAPHIC answer exactly, whatever the lens is really doing. `size` is
	# set from `view_height` in `_ready` and nothing writes it again, so the five
	# old sites would have gone on returning the play camera's own texel, to the
	# bit, for a camera standing anywhere at all.
	near(stale, was, 1e-9, "the stale reading is the orthographic one wherever the lens stands")
	ortho.get_parent().queue_free()
	lens.get_parent().queue_free()


## THE SWITCH MAY NOT POP, and this is the only thing standing between that and
## somebody retuning the lens for a nicer frame.
##
## A projection cannot be lerped. At the instant `lens` changes, a subject at the
## focal plane keeps its size if and only if the two cameras agree about world
## units per pixel, which is `2 * tan(fov/2) * back == view_height`. The lens
## shipped with fov 55 and a spelled back of 9.0, which is 9.37 against 15.0 -- a
## body the player was holding Z on would have jumped 1.60x larger on the key
## press. `CameraRig.lens_back` derives the distance so that cannot be written.
func test_the_two_projections_agree_about_size_at_the_focal_plane() -> void:
	var rows := float(UiBase.SIZE.y)
	var ortho := _camera()
	var lens := _lens_camera()
	var a := CameraRig.units_per_pixel_of(ortho, rows)
	var b := CameraRig.units_per_pixel_of(lens, rows)
	print("units per pixel: ortho %.6f | lens %.6f -> a subject at the focal plane changes by x%.4f"
		% [a, b, a / b])
	near(b, a, 1e-9, "the lens and the frame it replaces agree, so the switch is invisible")
	# The invariant itself, stated as the two sides rather than as the ratio.
	near(2.0 * tan(deg_to_rad(CameraRig.LENS_FOV) * 0.5) * CameraRig.lens_back(),
		CameraRig.VIEW_HEIGHT, 1e-9, "2 * tan(fov/2) * back == view_height")
	# AND AT EVERY ZOOM, for nothing: `size` and `_back` both carry `_zoom`.
	for zoom: float in [0.6, 1.0, 2.2]:
		var o := CameraRig.VIEW_HEIGHT * zoom / rows
		var l := 2.0 * tan(deg_to_rad(CameraRig.LENS_FOV) * 0.5) * CameraRig.lens_back() * zoom / rows
		near(l, o, 1e-9, "zoom %.1f keeps the match" % zoom)
	# And a view height the player moved (09_view, dev mode) keeps it too.
	near(2.0 * tan(deg_to_rad(CameraRig.LENS_FOV) * 0.5) * CameraRig.lens_back(26.0), 26.0, 1e-9,
		"a zoomed-out view height is matched by the distance derived from it")
	ortho.get_parent().queue_free()
	lens.get_parent().queue_free()


## THE HORIZON IS A DECISION, NOT A SIDE EFFECT. Past `fov/2 < pitch` the top
## edge clears the horizon: the frame holds sky, the ground runs to infinity and
## the streamer's cap always binds. Which side of that line the game sits on is
## the owner's call; this holds it to the side that keeps the horizon out until
## he rules, so nobody crosses it by widening a fov for a nicer frame.
func test_the_lens_keeps_the_horizon_out_of_the_frame() -> void:
	lt(CameraRig.LENS_FOV * 0.5, CameraRig.LENS_PITCH,
		"half the fov (%.1f) must stay under the pitch (%.1f) or the frame holds sky"
			% [CameraRig.LENS_FOV * 0.5, CameraRig.LENS_PITCH])
	var lens := _lens_camera()
	var ahead := _measured_ahead(lens, 0.0, 400.0, 0.5)
	gt(ahead, 0.0, "the ground really does meet the top edge somewhere ahead")
	print("top edge %.1f deg under the horizon -> the lens holds ground to %.1f tiles ahead"
		% [CameraRig.LENS_PITCH - CameraRig.LENS_FOV * 0.5, ahead])
	lens.get_parent().queue_free()


## THE AIR MEASURES THE FRAME IT IS ACTUALLY IN (`Air.frame_depth_lens`).
##
## Every constant in `Air` is stated as a multiple of the frame's own depth
## half-span, which is what makes the header's promise -- "a change of rig cannot
## put the air outside the picture again" -- survive a change of PROJECTION too,
## once that number is computed honestly instead of from a `view_size` a frustum
## does not have.
##
## Checked two independent ways, because a formula agreeing with itself proves
## nothing: the derived span against the one measured off the camera's own edges.
func test_the_air_measures_the_frame_it_is_actually_in() -> void:
	# The orthographic path is unchanged BY CONSTRUCTION -- `fov_deg` defaults to
	# 0, which means orthographic -- so this pins that rather than trusting it.
	var half := Air.frame_depth(CameraRig.VIEW_HEIGHT, CameraRig.PITCH_DEG)
	var r := Air.reach(30.0, CameraRig.VIEW_HEIGHT, CameraRig.PITCH_DEG)
	# 1e-5 and not 1e-9: `reach` hands back a Vector2, whose components are
	# 32-bit, so this compares a rounded value against a 64-bit recomputation.
	# At 1e-9 it failed by one part in ten million and read exactly like a real
	# difference -- "expected 37.890302, got 37.890301".
	near(r.x, 30.0 - half * Air.BEGIN_K, 1e-5, "the orthographic reach is what it always was")
	near(r.y, 30.0 + half * Air.END_K, 1e-5, "at both ends")

	# The lens, derived from its own geometry...
	var back := CameraRig.lens_back()
	var derived := Air.frame_depth_lens(back, CameraRig.LENS_PITCH, CameraRig.LENS_FOV)
	# ...and the same span measured off the camera's edges: the ground the frame
	# holds, resolved onto the view axis. Two derivations that share no arithmetic.
	var lens := _lens_camera()
	var span := (_measured_ahead(lens, 0.0, 260.0, 0.1) + _measured_behind(lens, 0.0, 60.0, 0.1)) \
			* cos(deg_to_rad(CameraRig.LENS_PITCH)) * 0.5
	print("frame depth: ortho %.2f | lens derived %.2f, measured off its edges %.2f"
		% [half, derived, span])
	near(derived, span, 0.1, "the derived half-span is the one the camera really has")
	gt(derived, half * 2.0, "and the lens frame is deeper than the orthographic one")

	# THE CLAMP, which is the horizon fork: walking the pitch down toward the top
	# edge must DEGRADE the air, never delete it. Unclamped this runs to 16907 at
	# a hundredth of a degree, which puts the fog's begin and end past everything
	# in the world -- the failure `lit` was built to fix, from the other side.
	var at_horizon := Air.frame_depth_lens(back, CameraRig.LENS_FOV * 0.5 + 0.01, CameraRig.LENS_FOV)
	lt(at_horizon, half * 40.0, "a pitch at the horizon is capped, not infinite: %.1f" % at_horizon)
	print("pitch a hundredth of a degree off the horizon -> half-span %.1f (capped)" % at_horizon)
	lens.get_parent().queue_free()


## THE FIX FOR THE CASE ABOVE, asked the same way: under the lens, with the
## spawner handed the camera's own question, not one tile of the ring the lens
## draws is called unseen -- where the box, measured in the test above, calls
## seven of eight unseen. The two tests together are the before and the after.
func test_under_the_lens_the_spawner_asks_the_camera() -> void:
	var cam := _lens_camera()
	var rows: float = cam.get_viewport().get_visible_rect().size.y
	var cols: float = cam.get_viewport().get_visible_rect().size.x
	var sp := Spawner.new()
	sp.sees = func(p: Vector2, margin: float) -> Variant:
		return CameraRig.sees_ground(cam, Vector3(p.x, 0.0, p.y), margin)
	var yaw := deg_to_rad(sp.yaw_deg)
	var up := Vector2(-sin(yaw), -cos(yaw))
	var drawn_tiles := 0
	var wrong := 0
	for ring in range(Spawner.RING_MIN, Spawner.RING_MAX + 1):
		var tile := up * float(ring)
		var s := cam.unproject_position(Vector3(tile.x, 0.0, tile.y))
		var drawn := s.y >= 0.0 and s.y <= rows and s.x >= 0.0 and s.x <= cols
		if drawn:
			drawn_tiles += 1
			if not sp.in_view(Vector2.ZERO, tile):
				wrong += 1
	gt(drawn_tiles, 0, "the lens draws the ring, or this asks nothing")
	eq(wrong, 0, "no tile the lens draws is called unseen once the spawner asks the camera")
	# And behind the camera is not "seen", however the projection mirrors it.
	check(not sp.in_view(Vector2.ZERO, -up * 30.0), "thirty tiles behind the eye is not on the picture")
	cam.get_parent().queue_free()
