class_name CameraRig
extends Camera3D
## The fixed orthographic camera: 45 degrees of yaw, a steep pitch, following a
## target, snapped to whole texels so the picture never crawls. Also owns the
## full-screen shaft pass, on the tiers that have no volumetric air.

@export var yaw_deg := 45.0
## As with VIEW_HEIGHT below: a test rasterising a model the way the play camera
## sees it asks for this rather than writing 57 down a second time.
const PITCH_DEG := 57.0
@export var pitch_deg := PITCH_DEG
## Vertical extent of the view in world units. The const is here so anything
## sizing itself against the play camera off-screen — a test, a mark's floor —
## can ASK for it instead of writing 15 down a second time (docs/LOOK.md: name a
## number where it is drawn).
const VIEW_HEIGHT := 15.0
@export var view_height := VIEW_HEIGHT
## How far the camera stands back along its view axis. Orthographic, so it only
## has to clear the tallest land in front of the focus; close keeps the depth
## range (and the sun's shadow range, SkyLight) tight.
@export var distance := 30.0
## Room kept past the frame's own depth at both clip planes, for land that
## stands UP into the picture: a thing `h` high draws `h * sin(pitch)` nearer
## the eye than the ground it stands on. Small enough that the play camera never
## has to stand further back than `distance` (at 15 units the frame is 4.9 deep,
## so 28.9 < 30 and nothing about play moves).
const DEPTH_ROOM := 24.0
@export var follow_rate := 10.0
## Where the camera really stood this frame, which is `distance` until the view
## is wide enough to need more. Everything that reads a depth off the camera
## must read THIS, never the export -- SkyLight already measures the live
## position for its fog and its shadow range, which is why the air follows a
## zoom without being told.
var _back := 30.0

## A SECOND PROJECTION, off by default (the owner's "multiple projections /
## perspectives"; #120 wants it under a held Z for close combat while open
## battle keeps the Diablo-style orthographic).
##
## WHY IT EXISTS AT ALL, measured rather than argued. The orthographic frame
## shows 26.67 x 17.9 tiles of ground and only 8.95 tiles AHEAD of the player,
## whatever the thing's height -- and because a pitched orthographic camera has
## NO HORIZON, backing away from a tower loses its TOP first and its feet last.
## So a `spire` (16.3) or a `tower` (14.3) can never stand whole in the frame, a
## flier nineteen units up is never overhead, and a city cannot read as a city.
## `tests/render/test_read_reach.gd` measures all of it against a real camera.
##
## DEFAULT IS UNCHANGED, deliberately: `--lens=persp` is opt-in, so every frame,
## tour and canon picture in the repository is exactly what it was, and the two
## can be shot side by side at one place before anything is decided.
##
## **IT CAN BE CHANGED IN A RUNNING GAME NOW, AND IT COULD NOT BEFORE.** The
## projection was chosen once, in `_ready`, while `_apply` branched on `lens`
## every frame -- so setting `lens` mid-game built a perspective camera's
## transform under an ORTHOGRAPHIC projection, and the readers split: 18_crowns
## asks `lens`, while 30_mobs, WorldView, SkyLight, the fire and
## `units_per_pixel_of` ask `projection`. This setter is the one door, so the two
## can never disagree.
##
## THE SWITCH IS CONTINUOUS IN PITCH. The two lenses stand at different pitches
## (`pitch_deg`, `LENS_PITCH`), and a switch that took the new one at once would
## tip the whole picture seventeen degrees in a frame. So the difference is
## carried in `_pitch`, the lean's own eased offset: the frame after a switch is
## at the pitch the frame before was, and `_ease_lean` glides it home at the
## lean's rate. The projection itself cannot be eased; `lens_back` is what keeps
## a subject at the focal plane the same size across it.
##
## Before the rig is in the tree (boot: `game.gd` sets `--lens` first) there is
## no previous frame to be continuous with, so nothing is carried.
@export var lens: StringName = &"ortho":
	set(v):
		if v == lens:
			return
		var was := LENS_PITCH if lens == &"persp" else pitch_deg
		lens = v
		projection = PROJECTION_PERSPECTIVE if lens == &"persp" else PROJECTION_ORTHOGONAL
		if is_inside_tree():
			_pitch += was - (LENS_PITCH if lens == &"persp" else pitch_deg)
			# The near focus is orthographic arithmetic and is switched off under
			# the lens; coming back, it must rebuild rather than trust the last
			# size it saw, which was measured before the lens took over.
			_dof_size = -1.0
## The lens, when it is asked for. Pitched far shallower than the play camera
## because the whole point is to SEE height: at 30 degrees a 16-unit spire is a
## spire, where at 57 it is a lid.
const LENS_FOV := 55.0
## Pitched shallower than the play camera, and it may not be pitched shallower
## than HALF THE FOV: past `fov/2 < pitch` the top edge clears the horizon, the
## frame holds sky and the ground it covers runs to infinity, so the streamer's
## `near_limit` cap always binds. That is a decision about whether this game has
## a horizon in frame rather than a side effect of a field of view, and it is the
## owner's. Until he rules, this stays on the side that keeps it out.
##
## 40 rather than the 30 this shipped with, and the reason is the STREAMER, not
## the picture: at the matched distance a pitch of 30 holds ground to 152 tiles,
## past `WorldView.near_limit` (110), so the near square is capped and the coarse
## far world papers over the difference. At 40 the frame reaches 30.7 and needs
## no fallback at all -- and it leaves 12.5 degrees between the top edge and the
## horizon instead of 2.5, which is more than a lean can spend by accident.
const LENS_PITCH := 40.0

## HOW FAR BACK THE EYE STANDS, DERIVED AND NEVER SPELLED — the one number that
## decides whether the switch into the lens is invisible or a jump.
##
## A projection cannot be lerped: at the instant `lens` changes, a subject keeps
## its size if and only if the two cameras agree about world units per screen
## pixel, and at the focal plane that is
##
##     2 * tan(fov/2) * back  ==  view_height
##
## The constants this shipped with (fov 55, back 9.0) give 9.37 against a view
## height of 15.0, so a body the player was holding Z on would have jumped 1.60x
## larger the instant the key went down. Deriving `back` instead of writing it
## down makes that unrepresentable: the free choices are the fov and the pitch,
## and the distance follows from them.
##
## It holds at every zoom for nothing, because `_apply` scales `size` by `_zoom`
## and `_apply_lens` scales this by the same `_zoom`, so both sides carry it
## linearly and the ratio cannot drift.
##
## MATCHING AT THE FOCAL PLANE IS THE ONLY MATCH THERE IS. Everything nearer is
## bigger under the lens and everything further is smaller — that is what
## perspective IS and it is the whole reason to switch. So "no pop" means "no pop
## for the subject the player is holding Z on", which is the thing worth holding
## still; anything else moving is the feature.
static func lens_back(height := VIEW_HEIGHT, degrees := LENS_FOV) -> float:
	return height / maxf(0.001, 2.0 * tan(deg_to_rad(degrees) * 0.5))

var target := Vector3.ZERO

## THE VIEW OVER THE SHOULDER (owner, 2026-09-23), a third pose for this rig:
## perspective, low behind the player's right shoulder, sky and horizon in frame.
## `41_shoulder` says whether it is wanted (`shoulder`), which way it looks
## (`shoulder_yaw`, `shoulder_pitch`, turned by the mouse and eased in behind a
## walking player) and how far back it may stand (`sight_room`, which walks the
## land and the solids between the head and the eye). The numbers are
## `Shoulder`'s (src/core/view/shoulder.gd).
##
## SEAMLESS BY CONSTRUCTION, both ways. The view is reached THROUGH the lens: the
## first frame asks for the lens (`hold_lens`), which is the matched switch at the
## focal plane that a held Z has always made (`lens_back`), and from there every
## number the picture is made of -- the focus, the yaw, the pitch, the distance,
## the field of view and the near plane -- is carried from the lens's pose to the
## shoulder's on one eased clock (`Shoulder.smooth`). Leaving runs the same clock
## backwards and gives the lens up only once the pose IS the lens's again, so the
## projection changes only at the one pose where the two agree.
##
## It enters at the yaw the screen is already at (`yaw_now`), so a key held down
## through the glide goes on walking the same way; the mouse turns it from there.
const Shoulder := preload("res://src/core/view/shoulder.gd")
var shoulder := false
var shoulder_yaw := 45.0
var shoulder_pitch := Shoulder.PITCH
var shoulder_back := Shoulder.BACK
## What a lock holds, in world space, or INF: over the shoulder the view turns
## onto it instead of leaning (42_target).
var subject := Vector3.INF
## (head: Vector3, eye: Vector3) -> float, the share of that line the eye may
## stand at (Shoulder.room). Unset, nothing is walked and the eye stands where
## the pose puts it (a gallery, a test with no world).
var sight_room := Callable()
## How much of a line from the head is clear, with no floor (41_shoulder
## `side_room`): asked to the player's right, so the eye stands off a wall there
## instead of hugging it. The right the eye actually stands at, eased.
var side_room := Callable()
var _side := Shoulder.RIGHT
## How much room the eye keeps between itself and a wall at the player's right.
const SIDE_CLEAR := 1.4
## The blend's own linear clock, 0 (top) to 1 (over the shoulder).
var _sh_t := 0.0
## How far the eye has moved out to `Shoulder.LOCK_RIGHT` for a lock, 0..1, eased
## at the lock's own rate so taking or letting go of one never jumps the frame.
var _lock_w := 0.0
## The bearing to what is locked as the last frame saw it, NAN for none: the view
## is turned by however far that bearing moved before the ease takes the rest.
var _lock_bearing := NAN
## Where the locked subject stood last frame: a subject that JUMPED (the lock
## cycled to another body) is a new lock, eased onto rather than carried to.
var _lock_was := Vector3.INF
## Degrees the view is asked to tip down to look over a person standing between
## the eye and a lock (41_shoulder writes it, `Shoulder.in_line`), and the tip it
## has eased to. Added to the pitch, so the eye rises and the focus holds still.
var shoulder_clear := 0.0
var _clear_tip := 0.0
## Further than this in one frame is a different body, not the same one moving.
const LOCK_JUMP := 1.5
var _room := 1.0
## How crowded in by a wall behind the eye is (Shoulder.crowd), eased, and which
## side of the player it has stepped to for it.
var _crowd := 0.0
var _crowd_left := false
var _dt := 0.0
var _yaw_drawn := 45.0
## Who is holding the lens on (a lock, the shoulder), and what the camera had
## before the first of them took it. Counted rather than remembered by each
## holder, so a lock let go while the shoulder still has the lens -- or the
## shoulder left while a lock still wants it -- hands back the right one.
var _lens_holds: Dictionary = {}
var _lens_before: StringName = &"ortho"

## What a target lock does to the camera (42_target, docs/DESIGN.md §Targeting):
## degrees of yaw and pitch added to the fixed angles, a factor on the view's
## height, and a bias of the frame from the player toward what they are reading.
## The system says where it wants them; the rig eases them, so only one place
## knows how a lean moves. Everything else about the camera is unchanged: the
## angles are fixed, the projection orthographic, the grid snapped to texels.
var lean_yaw := 0.0
var lean_pitch := 0.0
var lean_zoom := 1.0
var lean_bias := Vector3.ZERO
## Where the frame from above is drawn toward besides the body it follows, eased
## like a lean: a room is framed on its middle, not on the player standing in
## its doorway (21_doors is the one writer). Kept apart from `lean_bias` because
## targeting squares that to zero every frame its key is up.
var frame_bias := Vector3.ZERO
## Eased per second: in quickly enough to feel like a lean, out more gently.
const LEAN_IN := 7.0
const LEAN_OUT := 4.5
## Under these the lean is nothing and the camera is square again.
const LEAN_STILL := 0.01

var _smoothed := Vector3.ZERO
## Radians the lens nods and rolls per world unit of quake: a third of a unit
## (a foot a kilometre off) tips the horizon over a degree, and the looming
## walker fifty kilometres out about a third of one: measured on frames, a
## fifth of that moved nothing a player could see.
const QUAKE_TIP := 0.06
## Quakes running (strength, seconds, hz, age) and where they put the eye now.
var _quakes: Array[Vector4] = []
var _quake_at := Vector2.ZERO
var _outline: MeshInstance3D
var _yaw := 0.0
var _pitch := 0.0
var _zoom := 1.0
var _bias := Vector3.ZERO
var _frame := Vector3.ZERO


func _ready() -> void:
	projection = PROJECTION_PERSPECTIVE if lens == &"persp" else PROJECTION_ORTHOGONAL
	fov = LENS_FOV
	keep_aspect = KEEP_HEIGHT
	size = view_height
	near = 1.0
	_back = distance
	far = 250.0
	rotation = Vector3(deg_to_rad(-pitch_deg), deg_to_rad(yaw_deg), 0.0)
	_near_focus()
	# The screen-space light shafts, and ONLY on a tier with no volumetric air:
	# where the renderer can do real volumetrics a lamp throws a real cone and
	# this quad would draw a second, worse one over it. LOOK.md's degradation
	# table is the authority and Quality.ROWS is where it is written down; this
	# reads the row rather than deciding anything (docs/LOOK.md, Quality).
	if not bool(Quality.current().get("volumetric", false)):
		_outline = MeshInstance3D.new()
		_outline.name = "shaft_pass"
		var q := QuadMesh.new()
		q.size = Vector2(2, 2)
		q.flip_faces = true
		_outline.mesh = q
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://src/render/shafts.gdshader")
		_outline.material_override = mat
		_outline.extra_cull_margin = 16384.0
		_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_outline)


## NEAR DEPTH OF FIELD (docs/LOOK.md law 3), where the tier allows it.
##
## An orthographic camera draws a thing at depth 10 and a thing at depth 50 at
## exactly the same size and moves them across the screen by exactly the same
## number of pixels. Focus is the one cue it CANNOT flatten: a lens has one
## focal plane whatever the projection, so a bough eight units in front of the
## place is soft and the place is sharp, and the eye reads that as distance
## before it reads anything else in the frame.
##
## Only the NEAR side is blurred. A far blur would soften the land at the top of
## the picture, which is the air's job (`Air`) and which fog does in colour
## rather than in focus -- and softening what a player is walking toward is how
## a depth cue becomes a readability failure.
##
## WHERE IT MAY BEGIN IS A READABILITY QUESTION, and it is the hard part.
##
## The frame is only about ten units deep, and the foreground layer lives in the
## SAME depths the world's tall things do: a piece at four units over ground at
## depth 26 is at depth 22.6, and so is a four-unit tower standing at the near
## edge. Blur cannot tell them apart, so a near plane chosen for the boughs also
## softens whatever is standing at the bottom of the frame -- which is where
## something comes at you from. Measured at a near plane of 25.4: a machine at
## the bottom edge went soft, and that is the package's own rule broken by its
## prettiest feature.
##
## So the plane is not a constant. It is the nearest ground the frame holds, less
## the height a thing may stand there and still be SHARP: nothing under
## DOF_CLEAR_LIFT off the ground is ever touched, anywhere in the picture. What
## is left to blur is what is genuinely overhead, which is what this is for.
##
## 2.6 units is a machine (about 1.8) with room over it, so a hunter at the very
## bottom edge of the frame is crisp. It is the FLOOR now rather than the answer:
## see `clear_lift`.
const DOF_CLEAR_LIFT := 2.6
## How far past the plane the blur reaches full, in world units.
const DOF_RAMP := 4.5
const DOF_AMOUNT := 0.14
## How fast the clear lift crosses a border, per second. Slow enough that walking
## into the city pulls focus rather than snapping it.
const CLEAR_EASE := 1.6

## HOW TALL A THING MAY BE AT THE NEAR EDGE AND STAY SHARP, set by whoever knows
## what this landscape builds (`12_landscape`, off `BiomeForms.tallest`).
##
## Measured, in the city, and it is the same shape as every other long-lived bug
## in this project: a correct rule whose premise moved. DOF_CLEAR_LIFT was fitted
## to a stock of one-storey buildings — the tallest thing anybody raised was 2.8
## — so "2.6 clears a machine with room over it" cleared everything there was.
## Then a landscape was allowed to build a 14.3 tower and a 16.3 spire, and the
## two tallest buildings in the Slums came out as unreadable smears at the bottom
## of the frame: the near blur was eating precisely what makes a city a city.
##
## The rule itself was never wrong. It just stopped being asked of the right
## number, and a constant cannot notice that. So the height belongs to the stock
## that decides it, and this is only where the camera keeps the answer.
var clear_lift := DOF_CLEAR_LIFT

var _dof_size := -1.0
var _clear_now := DOF_CLEAR_LIFT
var _dof_clear := -1.0


## How much of the frame's height the web pass's near blur spreads a pixel over
## at full blur (`near_stand_in`). Matched by eye and by frame against the
## desktop's CameraAttributesPractical at DOF_AMOUNT, on the canon's pinewood
## bough: the same softness at the same place.
const NEAR_STAND_IN_REACH := 0.015


## Where the near blur begins, in view depth, for the picture as it is shown: the
## nearest ground the frame holds, less the height a thing may stand there and
## stay sharp. One answer for the real blur and for the web's stand-in, so the two
## soften exactly the same things.
func near_plane(shown: float) -> float:
	var near_ground := _back - Air.frame_depth(shown, pitch_deg + _pitch)
	var begin := near_ground - _clear_now * sin(deg_to_rad(pitch_deg + _pitch))
	return maxf(near + 1.0, begin)


## Whether this rig is the camera the frame is drawn through. Out of the tree
## (a test building a rig on its own) it is, since there is nothing else.
func _drawing() -> bool:
	return not is_inside_tree() or get_viewport().get_camera_3d() == self


## Put the near blur on, or take it off, by the tier's own row. Never re-derived:
## `Quality.ROWS` is the one place that says what a tier may spend.
##
## Compatibility draws no depth of field at all (measured: `perf features`, the
## frame does not move), so a tier with `near_stand_in` hands the same plane to
## the screen-space pass it already runs for shafts (shafts.gdshader), which
## blurs what is nearer than it out of the frame it already reads.
func _near_focus() -> void:
	# NO NEAR BLUR UNDER THE LENS. Every number this function works from is an
	# ORTHOGRAPHIC one -- `near_plane` is `_back - Air.frame_depth(size, pitch)`,
	# and `size` is world units per screen height, which a perspective frame does
	# not have. Left on, it focused on a plane that means nothing and blurred most
	# of the picture. It is also not wanted: the near blur exists to stop a bough
	# at the edge of a FLAT frame dominating it, which is not a problem a camera
	# standing behind the player has.
	#
	# AND THE WEB'S STAND-IN IS THE SAME BLUR, so it goes off with it. It lives in
	# the shaft pass, a quad parented to this rig that draws over whatever camera
	# is current, and this branch used to clear only `attributes` -- so on the web
	# tier the last orthographic plane (about 25 units) stayed in the pass and
	# blurred everything within 25 units of the eye under the lens and over the
	# shoulder. A camera that is not this rig (96_eye's stand) is the same case:
	# the plane is arithmetic about THIS rig's frame and means nothing in anyone
	# else's.
	if lens == &"persp" or not _drawing():
		attributes = null
		_dof_size = -1.0
		if _outline != null:
			(_outline.material_override as ShaderMaterial).set_shader_parameter("near_begin", -1.0)
		return
	if not bool(Quality.current().get("near_focus", false)):
		attributes = null
		if _outline != null and bool(Quality.current().get("near_stand_in", false)):
			var shown_web := size
			if not is_equal_approx(shown_web, _dof_size):
				_dof_size = shown_web
				var m := _outline.material_override as ShaderMaterial
				m.set_shader_parameter("near_begin", near_plane(shown_web))
				m.set_shader_parameter("near_ramp", DOF_RAMP)
				m.set_shader_parameter("near_reach", NEAR_STAND_IN_REACH)
			return
		_dof_size = -1.0
		return
	var a := attributes as CameraAttributesPractical
	if a == null:
		a = CameraAttributesPractical.new()
		# Auto exposure would fight the one tonemapper SkyLight owns, and a second
		# thing deciding how bright the frame is is exactly the failure LOOK.md's
		# ceiling rule exists to stop.
		a.auto_exposure_enabled = false
		a.exposure_multiplier = 1.0
		# Only the near side. A far blur would soften the land at the top of the
		# picture, which is the AIR's job (`Air`) and which fog does in colour
		# rather than in focus -- and softening what a player is walking toward is
		# how a depth cue becomes a readability failure.
		a.dof_blur_far_enabled = false
		a.dof_blur_near_enabled = true
		a.dof_blur_amount = DOF_AMOUNT
		attributes = a
	var shown := size
	# Both inputs, or a landscape that changes how tall it builds without changing
	# the zoom leaves the plane where the last one put it.
	if is_equal_approx(shown, _dof_size) and is_equal_approx(_clear_now, _dof_clear):
		return
	_dof_size = shown
	_dof_clear = _clear_now
	# The nearest ground the frame holds, from the camera that is really drawing
	# -- so a zoom or a target lean moves the plane with the picture instead of
	# quietly blurring the near half of a zoomed-out frame.
	a.dof_blur_near_distance = near_plane(shown)
	a.dof_blur_near_transition = DOF_RAMP


## The yaw the screen is actually at, lean and all: screen-relative input and
## anything else drawn in screen space must ask for this, not the fixed angle,
## or the keys stop matching the picture while the camera leans.
## WORLD UNITS PER SCREEN PIXEL, at the plane the camera is focused on. The one
## door for everything that used to divide `cam.size` by the viewport's height.
##
## Under the orthographic projection it is exactly that and nothing has moved.
## Under the lens it cannot be: `size` is a property Godot keeps on every
## Camera3D and the perspective projection ignores, `_ready` sets it from
## `view_height` and `_apply_lens` never writes it, so dividing it would answer
## 15.0 for the life of the game -- a confident wrong answer, which is worse than
## no answer because nothing anywhere would say so.
##
## A frustum has no single figure at all, so this one is stated AT THE FOCAL
## PLANE: the ground the camera is looking at, `_back` away along its own axis,
## which is where the player is standing and where every caller's mark, texel or
## pool is being sized. Anything nearer is bigger on screen than this says and
## anything further is smaller, and that is a property of the lens rather than an
## error in the number.
static func units_per_pixel_of(cam: Camera3D, rows: float) -> float:
	var h := maxf(1.0, rows)
	if cam == null:
		return VIEW_HEIGHT / h
	if cam.projection != PROJECTION_PERSPECTIVE:
		return cam.size / h
	# The only camera in this game that is ever perspective is this rig, which
	# knows how far back it stands; a bare Camera3D that somehow got here is
	# answered with the lens's own resting distance rather than with a guess
	# dressed up as a measurement.
	var rig := cam as CameraRig
	var focal := rig._back if rig != null else lens_back()
	return 2.0 * tan(deg_to_rad(cam.fov) * 0.5) * maxf(focal, 0.001) / h


## How tall a body is for the question below: a point this far above the ground
## is its head. Two is the height of most of the roster's walkers; it only has to
## be tall enough that a machine whose feet are just off the bottom of the frame
## but whose head is on it is counted as seen, because that is a machine that
## would pop into view.
const SEEN_HEAD := 2.0


## IS THIS PLACE ON THE PICTURE, asked of the camera that is drawing it. True when
## the ground at `foot`, or a head `SEEN_HEAD` above it, lands inside the rect
## grown by `margin` world units (negative shrinks it, which is how a caller asks
## "well inside"). The margin is converted at the focal plane, `units_per_pixel_of`,
## so far out, where a world unit is fewer pixels, the same margin covers MORE than
## `margin` world units. For "not seen" that pushes spawns further away, which is
## the right way for it to be wrong: toward no pop-in. Converting per point would
## be more exact and would make far spawns land closer to the edge of the frame.
##
## A point behind the camera's near plane is skipped rather than projected:
## `unproject_position` mirrors what is behind the eye to a position that can land
## inside the rect, and an unguarded test counts it as seen.
##
## Correct under either projection. The spawner only asks it under the lens,
## because under the orthographic camera its own box is exactly this question
## already and changing the answer there would move the shipped game.
static func sees_ground(cam: Camera3D, foot: Vector3, margin: float, head := SEEN_HEAD) -> bool:
	if cam == null or not cam.is_inside_tree():
		return false
	var rect: Vector2 = cam.get_viewport().get_visible_rect().size
	var out := margin / maxf(units_per_pixel_of(cam, rect.y), 1e-6)
	var inv := cam.global_transform.affine_inverse()
	for lift: float in [0.0, head]:
		var at := foot + Vector3(0.0, lift, 0.0)
		if (inv * at).z > -cam.near:
			continue
		var s := cam.unproject_position(at)
		if s.x >= -out and s.x <= rect.x + out and s.y >= -out and s.y <= rect.y + out:
			return true
	return false


## The rig's own, for the viewport it is drawing into.
func units_per_pixel() -> float:
	var rows := float(get_viewport().get_visible_rect().size.y) if is_inside_tree() else float(UiBase.SIZE.y)
	return units_per_pixel_of(self, rows)


## THE YAW THE SCREEN IS ACTUALLY AT, as the last frame drew it: a lean, the
## glide down to the shoulder and the mouse turning it all included. Screen-
## relative input and anything else drawn in screen space asks for this, never
## `yaw_deg`, or the keys stop matching the picture.
func yaw_now() -> float:
	return _yaw_drawn


## Ask for the lens, or give up asking. The lens is drawn while anybody holds it
## and the camera goes back to what it had before the first holder once the last
## lets go. `lens` is still the only writer of `projection`; this only decides
## what `lens` is.
func hold_lens(who: StringName, on: bool) -> void:
	if on:
		if _lens_holds.has(who):
			return
		if _lens_holds.is_empty():
			_lens_before = lens
		_lens_holds[who] = true
		lens = &"persp"
	elif _lens_holds.has(who):
		@warning_ignore("return_value_discarded")
		_lens_holds.erase(who)
		if _lens_holds.is_empty():
			lens = _lens_before


## How far over the shoulder the picture is, 0 (top) to 1 (there), eased.
func shoulder_share() -> float:
	return Shoulder.smooth(_sh_t)


## Wholly over the shoulder, and not on the way there or back.
func over_shoulder() -> bool:
	return _sh_t >= 1.0


## The facing a swing takes: where the camera looks, once the view is more over
## the shoulder than not; NAN otherwise, which leaves the swing's own rule alone.
func aim() -> float:
	return Shoulder.aim_of(_yaw_drawn) if _sh_t > 0.5 else NAN


## Put the view where it is asked for with no glide: a game that opens over the
## shoulder, a shot. The lens is taken or given up to match.
func snap_view() -> void:
	_sh_t = 1.0 if shoulder else 0.0
	_room = 1.0
	hold_lens(&"shoulder", shoulder)
	if shoulder:
		_pitch = lean_pitch
	_apply()


## The camera is leaning (a lock, a sweep) rather than square on.
func leaning() -> bool:
	return absf(_yaw) > LEAN_STILL or absf(_pitch) > LEAN_STILL \
		or absf(_zoom - 1.0) > LEAN_STILL * 0.1 or _bias.length() > LEAN_STILL


## Jump straight to the target (no easing): startup, teleports, screenshots.
func snap_to(p: Vector3) -> void:
	target = p
	_smoothed = p
	_yaw = lean_yaw
	_pitch = lean_pitch
	_zoom = lean_zoom
	_bias = lean_bias
	_frame = frame_bias
	_apply()


## A short shake of `strength` world units, decaying over `seconds`. Moves only
## h_offset/v_offset, rounded to whole texels so the pixel grid holds.
## `PlayerSettings` may turn this down to nothing: it is the only thing that moves
## the whole picture without the player asking, so it is theirs to refuse.
func shake(strength: float, seconds: float = 0.12) -> void:
	strength *= float(PlayerSettings.value(&"picture.shake"))
	if strength <= 0.001:
		return
	if not is_inside_tree():
		return
	var texel := view_height / float(get_viewport().get_visible_rect().size.y)
	var seed_ms := Time.get_ticks_msec()
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var k := strength * (1.0 - t)
		h_offset = roundf(sin(t * 47.0 + seed_ms) * k / texel) * texel
		v_offset = roundf(cos(t * 61.0 + seed_ms * 0.7) * k / texel) * texel, 0.0, 1.0, seconds)
	tw.tween_callback(func() -> void:
		h_offset = 0.0
		v_offset = 0.0)


## A LONG, LOW SHAKE: the ground moving under the camera, not a blow. Where
## `shake` is a rattle over a tenth of a second, a quake is `hz` cycles a second
## (one or two: something enormous landing a long way off) rising in a quarter of
## a second and dying over `seconds`, the picture swaying rather than jumping.
## Several may run at once and they add. The player's `picture.shake` scales it
## like every other movement they did not ask for, down to nothing.
func quake(strength: float, seconds: float, hz: float = 1.6) -> void:
	strength *= float(PlayerSettings.value(&"picture.shake"))
	if strength <= 0.001 or seconds <= 0.0:
		return
	_quakes.append(Vector4(strength, seconds, hz, 0.0))


## Whether the ground is moving under the camera now (a tour's `colossus_quake`).
func quaking() -> bool:
	return not _quakes.is_empty()


## Where the quakes running now put the eye (across and up the picture, world
## units), for a camera that is not this rig but stands on the same ground --
## 96_eye's stand -- so a landing is felt whichever camera is drawing. The nod
## and roll that go with it are `QUAKE_TIP` radians per unit.
func quake_offset() -> Vector2:
	return _quake_at


## Where the quakes running now put the eye, across and up the picture, in world
## units, and each one's clock advanced by `delta`.
func _quake_step(delta: float) -> Vector2:
	var out := Vector2.ZERO
	var i := 0
	while i < _quakes.size():
		var q := _quakes[i]
		q.w += delta
		if q.w >= q.y:
			_quakes.remove_at(i)
			continue
		_quakes[i] = q
		var env := smoothstep(0.0, 0.25, q.w) * pow(1.0 - q.w / q.y, 1.5)
		var ph := TAU * q.z * q.w
		out += Vector2(sin(ph + q.x * 17.0) * 0.6, sin(ph * 1.31 + 0.7)) * q.x * env
		i += 1
	return out


func _process(delta: float) -> void:
	_quake_at = _quake_step(delta)
	_smoothed = _smoothed.lerp(target, 1.0 - exp(-follow_rate * delta))
	_clear_now = lerpf(_clear_now, maxf(DOF_CLEAR_LIFT, clear_lift), 1.0 - exp(-CLEAR_EASE * delta))
	_ease_lean(delta)
	_ease_shoulder(delta)
	_dt = delta
	_apply()


## One frame of the glide. Entering from the top takes the yaw the screen is at,
## so nothing turns; the lens is held for as long as any of the view is showing.
func _ease_shoulder(delta: float) -> void:
	if not shoulder and _sh_t <= 0.0:
		hold_lens(&"shoulder", false)
		return
	if _sh_t <= 0.0:
		shoulder_yaw = yaw_now()
		shoulder_pitch = Shoulder.PITCH
		_room = 1.0
	hold_lens(&"shoulder", true)
	_sh_t = Shoulder.blend_step(_sh_t, shoulder, delta)
	_clear_tip = Shoulder.clear_step(_clear_tip, shoulder_clear if shoulder else 0.0, delta)
	var k := 1.0 - exp(-Shoulder.LOCK_RATE * delta)
	var locking := subject.is_finite() and shoulder
	_lock_w = lerpf(_lock_w, 1.0 if locking else 0.0, k)
	if locking:
		# Aimed from the shoulder the eye stands behind, never from the head: the
		# head is in front of the eye, and a line from it runs through the body.
		var from := shoulder_aim_from()
		var to := Vector2(subject.x - from.x, subject.z - from.z)
		if to.length() > 0.3:
			var bearing := Shoulder.yaw_along(to)
			# Carried round with the target first, so a circle walked close in
			# keeps it where it was in the frame: eased alone, the view trailed a
			# body circled at a tile and a half by more than twenty degrees.
			if _lock_was.is_finite() and _lock_was.distance_to(subject) > LOCK_JUMP:
				_lock_bearing = NAN
			if not is_nan(_lock_bearing):
				shoulder_yaw += Shoulder.turn(_lock_bearing, bearing)
			_lock_bearing = bearing
			shoulder_yaw += Shoulder.turn(shoulder_yaw, bearing) * k
		else:
			_lock_bearing = NAN
		_lock_was = subject
	else:
		_lock_bearing = NAN
		_lock_was = Vector3.INF
	if _sh_t <= 0.0:
		hold_lens(&"shoulder", false)


## Each part of the lean eased toward what the system asked for: in at LEAN_IN,
## back to square at LEAN_OUT.
## The perspective lens. It shares the rig's yaw, its smoothing and its lean, so
## a target lock still turns the head; what it does not share is the texel snap,
## which is an ORTHOGRAPHIC device -- `size` is world units per screen height and
## a perspective frame has no single one, so snapping to it would pin the picture
## to a number that no longer means anything.
func _apply_lens() -> void:
	var yaw_a := yaw_deg + _yaw
	var pitch_a := LENS_PITCH + _pitch
	var focus_a := _smoothed + _bias
	# Derived from the fov and the height the orthographic frame would show, so
	# the switch cannot pop (`lens_back`). Reads the LIVE `view_height` rather
	# than the constant, because 09_view and dev mode both move it.
	var back_a := lens_back(view_height, LENS_FOV) * _zoom
	var w := Shoulder.smooth(_sh_t)
	# Every frame, not only while `attributes` is set: the web's stand-in has no
	# attributes to notice, and was left blurring (see `_near_focus`).
	_near_focus()
	if w <= 0.0:
		_set_yield(0.0)
		fov = LENS_FOV
		near = 1.0
		far = 500.0
		rotation = Vector3(deg_to_rad(-pitch_a), deg_to_rad(yaw_a), 0.0)
		_back = back_a
		_yaw_drawn = yaw_a
		global_position = focus_a + Basis.from_euler(rotation).z * _back + (basis.x * _quake_at.x + basis.y * _quake_at.y)
		rotation += Vector3(_quake_at.y * QUAKE_TIP, 0.0, _quake_at.x * QUAKE_TIP)
		return
	# Every number the picture is made of, carried from the lens's pose to the
	# shoulder's on the one eased clock. The yaw goes the short way round.
	var yb := deg_to_rad(shoulder_yaw)
	var right := Vector3(cos(yb), 0.0, -sin(yb))
	# THE EYE DOES NOT HUG A WALL AT THE PLAYER'S RIGHT. Down a corridor it stood
	# a hand's width off the wall, which filled half the frame, and the lantern in
	# that hand blew it out. So the shoulder offset gives way to the wall: the
	# eye stands `SIDE_CLEAR` off it, toward the corridor's middle, as far over
	# as the player's own left side allows.
	# Crowded in by a wall behind (Shoulder.crowd), it stands further over, to
	# whichever side has the room, and may come nearer the wall there. Never
	# under a lock, which is framed from the right.
	var c := _crowd * (1.0 - _lock_w)
	var want := lerpf(_right_now(), Shoulder.CROWD_SIDE, c)
	var clear := lerpf(SIDE_CLEAR, Shoulder.CROWD_SIDE_CLEAR, c)
	var fit := want
	if side_room.is_valid() and w > 0.01:
		var head := _smoothed + Vector3(0.0, Shoulder.HEAD_UP, 0.0)
		var reach := want + clear
		fit = clampf(float(side_room.call(head, head + right * reach)) * reach - clear, -0.3, want)
		if c > 0.05:
			var fit_l := clampf(float(side_room.call(head, head - right * reach)) * reach - clear, -0.3, want)
			_crowd_left = Shoulder.crowd_left(_crowd_left, fit, fit_l)
			if _crowd_left:
				fit = -fit_l
		else:
			_crowd_left = false
	# Pulled toward the player at once by a wall on its own side; everything
	# else, a change of side included, eased.
	if signf(fit) == signf(_side) and absf(fit) < absf(_side):
		_side = fit
	else:
		_side = lerpf(_side, fit, 1.0 - exp(-Shoulder.ROOM_OUT * _dt))
	var focus_b := _smoothed + Vector3(0.0, lerpf(Shoulder.FOCUS_UP, Shoulder.CROWD_FOCUS_UP, c), 0.0) + right * _side
	var yaw := yaw_a + Shoulder.turn(yaw_a, shoulder_yaw) * w
	var pitch := lerpf(pitch_a, minf(shoulder_pitch + _clear_tip, Shoulder.PITCH_MOST), w)
	var focus := focus_a.lerp(focus_b, w)
	var back := lerpf(back_a, shoulder_back, w)
	fov = lerpf(LENS_FOV, Shoulder.FOV, w)
	near = lerpf(1.0, Shoulder.NEAR, w)
	far = Shoulder.FAR
	rotation = Vector3(deg_to_rad(-pitch), deg_to_rad(yaw), 0.0)
	var eye := focus + Basis.from_euler(rotation).z * back
	# Never inside the land or a house: the line from the head to the eye is
	# walked, and the eye stands where it is first clear. Pulled in at once, let
	# back out gently, so a wall behind the player is never drawn from inside.
	# Walked from the point it looks at, so a pulled-in eye keeps its aim and
	# never comes round beside the head (Shoulder.LEAST_BACK) -- unless that point
	# is itself in a wall at the player's right, when it comes in toward the head.
	if sight_room.is_valid():
		var head := _smoothed + Vector3(0.0, Shoulder.HEAD_UP, 0.0)
		var pivot := head.lerp(focus, clampf(float(sight_room.call(head, focus)), 0.0, 1.0))
		var span := maxf(0.001, pivot.distance_to(eye))
		var room := clampf(float(sight_room.call(pivot, eye)), minf(1.0, Shoulder.LEAST_BACK / span), 1.0)
		_room = room if room < _room else lerpf(_room, room, 1.0 - exp(-Shoulder.ROOM_OUT * _dt))
		eye = pivot.lerp(eye, _room)
	var crowd_want := Shoulder.crowd(eye.distance_to(focus)) if sight_room.is_valid() else 0.0
	_crowd = lerpf(_crowd, crowd_want, 1.0 - exp(-Shoulder.CROWD_RATE * _dt))
	# Tipped up past the ordinary limit, the eye comes to the face and the body
	# it passes through is stippled away (Shoulder.rise).
	var r := Shoulder.rise(shoulder_pitch) * w
	if r > 0.0:
		var ahead := Vector3(-sin(yb), 0.0, -cos(yb))
		eye = eye.lerp(_smoothed + Vector3(0.0, Shoulder.EYE_UP, 0.0) + ahead * Shoulder.EYE_FORWARD, r)
	# And an eye pressed into the body itself stipples it (Shoulder.inside).
	var d := Vector2(eye.x - _smoothed.x, eye.z - _smoothed.z).length()
	var gone := Shoulder.inside(d) * w if eye.y < _smoothed.y + 2.0 else 0.0
	_set_yield(maxf(r, gone))
	global_position = eye + (basis.x * _quake_at.x + basis.y * _quake_at.y)
	# Under a lens a sway of the eye barely moves anything far off, and a quake
	# is felt in the horizon: so the head nods and rolls with it too.
	rotation += Vector3(_quake_at.y * QUAKE_TIP, 0.0, _quake_at.x * QUAKE_TIP)
	_back = maxf(0.001, eye.distance_to(focus))
	_yaw_drawn = yaw


## The share of the player's own figure stippled away for the eye, handed to
## every body's shader (sight.gdshaderinc `eye_yield`). Written only when it
## changes, so the top-down game never touches it.
var yield_share := 0.0
func _set_yield(r: float) -> void:
	if r == 0.0 and yield_share == 0.0:
		return
	yield_share = r
	RenderingServer.global_shader_parameter_set(&"eye_yield", Vector4(_smoothed.x, _smoothed.y, _smoothed.z, r))


## How far right of the player the eye stands now: a lock moves it out.
func _right_now() -> float:
	return lerpf(Shoulder.RIGHT, Shoulder.LOCK_RIGHT, _lock_w)


## The point over the shoulder the view looks out from, on the ground plane's
## height of the player: what a lock is aimed from, and what a tour asks the
## lock's bearing of (41_shoulder `shoulder_locked`).
## How far the view is tipped over a person on the line to the lock, degrees.
func clear_tip() -> float:
	return _clear_tip


func shoulder_aim_from() -> Vector3:
	var yb := deg_to_rad(shoulder_yaw)
	return _smoothed + Vector3(cos(yb), 0.0, -sin(yb)) * _right_now()


func _ease_lean(delta: float) -> void:
	var to_in := 1.0 - exp(-LEAN_IN * delta)
	var to_out := 1.0 - exp(-LEAN_OUT * delta)
	_yaw = lerpf(_yaw, lean_yaw, to_out if is_zero_approx(lean_yaw) else to_in)
	_pitch = lerpf(_pitch, lean_pitch, to_out if is_zero_approx(lean_pitch) else to_in)
	_zoom = lerpf(_zoom, lean_zoom, to_out if is_equal_approx(lean_zoom, 1.0) else to_in)
	_bias = _bias.lerp(lean_bias, to_out if lean_bias.length() < LEAN_STILL else to_in)
	_frame = _frame.lerp(frame_bias, to_out)


func _apply() -> void:
	if lens == &"persp":
		_apply_lens()
		return
	_set_yield(0.0)
	size = view_height * _zoom
	rotation = Vector3(deg_to_rad(-(pitch_deg + _pitch)), deg_to_rad(yaw_deg + _yaw), 0.0)
	var b := Basis.from_euler(rotation)
	# Express the focus in camera space, snap its screen-plane axes to texels, go back.
	var texel := size / float(get_viewport().get_visible_rect().size.y)
	var local := b.inverse() * (_smoothed + _bias + _frame)
	local.x = roundf(local.x / texel) * texel
	local.y = roundf(local.y / texel) * texel
	var focus := b * local
	# THE CLIP PLANES FOLLOW THE FRAME. Orthographic depth runs with the ground:
	# at the play pitch a point one tile further from the eye is 0.54 deeper, so
	# a 1300-tile island spans about 700 units of depth -- while `near` and `far`
	# were 1 and 250, constants sized for a 15-unit view. Everything outside that
	# slab was clipped, which drew the world as a BAND across the middle of the
	# frame with black either side of it. That is what the owner has been looking
	# at, and neither the streamer nor the pitch was ever the cause of it.
	var half := Air.frame_depth(size, pitch_deg + _pitch)
	_back = maxf(distance, half + DEPTH_ROOM)
	far = maxf(250.0, _back + half + DEPTH_ROOM)
	# A quake moves the eye by whole texels, like everything else here, so the
	# pixel grid holds while the ground sways.
	var qx := roundf(_quake_at.x / texel) * texel
	var qy := roundf(_quake_at.y / texel) * texel
	global_position = focus + b.z * _back + b.x * qx + b.y * qy
	_yaw_drawn = yaw_deg + _yaw
	# The focal plane follows the picture: a lean zooms and tilts, and a plane
	# left where the square-on frame put it would blur the near half of a
	# zoomed-out one. Does nothing until `size` really moves.
	if attributes != null or bool(Quality.current().get("near_focus", false)) \
			or bool(Quality.current().get("near_stand_in", false)):
		_near_focus()
	# Ink patterns are drawn in screen pixels; shifting them by the camera's own
	# texel offset pins every hatch line to the world instead of the glass.
	RenderingServer.global_shader_parameter_set("world_px", Vector2(roundf(local.x / texel), roundf(local.y / texel)))
