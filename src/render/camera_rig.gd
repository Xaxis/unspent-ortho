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
@export var lens: StringName = &"ortho"
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
## Eased per second: in quickly enough to feel like a lean, out more gently.
const LEAN_IN := 7.0
const LEAN_OUT := 4.5
## Under these the lean is nothing and the camera is square again.
const LEAN_STILL := 0.01

var _smoothed := Vector3.ZERO
var _outline: MeshInstance3D
var _yaw := 0.0
var _pitch := 0.0
var _zoom := 1.0
var _bias := Vector3.ZERO


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
	if lens == &"persp":
		attributes = null
		_dof_size = -1.0
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


func yaw_now() -> float:
	return yaw_deg + _yaw


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


func _process(delta: float) -> void:
	_smoothed = _smoothed.lerp(target, 1.0 - exp(-follow_rate * delta))
	_clear_now = lerpf(_clear_now, maxf(DOF_CLEAR_LIFT, clear_lift), 1.0 - exp(-CLEAR_EASE * delta))
	_ease_lean(delta)
	_apply()


## Each part of the lean eased toward what the system asked for: in at LEAN_IN,
## back to square at LEAN_OUT.
## The perspective lens. It shares the rig's yaw, its smoothing and its lean, so
## a target lock still turns the head; what it does not share is the texel snap,
## which is an ORTHOGRAPHIC device -- `size` is world units per screen height and
## a perspective frame has no single one, so snapping to it would pin the picture
## to a number that no longer means anything.
func _apply_lens() -> void:
	rotation = Vector3(deg_to_rad(-(LENS_PITCH + _pitch)), deg_to_rad(yaw_deg + _yaw), 0.0)
	var b := Basis.from_euler(rotation)
	# Derived from the fov and the height the orthographic frame would show, so
	# the switch cannot pop (`lens_back`). Reads the LIVE `view_height` and `fov`
	# rather than the constants, because 09_view and dev mode both move the first.
	_back = lens_back(view_height, fov) * _zoom
	far = 500.0
	if attributes != null:
		_near_focus()
	global_position = (_smoothed + _bias) + b.z * _back


func _ease_lean(delta: float) -> void:
	var to_in := 1.0 - exp(-LEAN_IN * delta)
	var to_out := 1.0 - exp(-LEAN_OUT * delta)
	_yaw = lerpf(_yaw, lean_yaw, to_out if is_zero_approx(lean_yaw) else to_in)
	_pitch = lerpf(_pitch, lean_pitch, to_out if is_zero_approx(lean_pitch) else to_in)
	_zoom = lerpf(_zoom, lean_zoom, to_out if is_equal_approx(lean_zoom, 1.0) else to_in)
	_bias = _bias.lerp(lean_bias, to_out if lean_bias.length() < LEAN_STILL else to_in)


func _apply() -> void:
	if lens == &"persp":
		_apply_lens()
		return
	size = view_height * _zoom
	rotation = Vector3(deg_to_rad(-(pitch_deg + _pitch)), deg_to_rad(yaw_deg + _yaw), 0.0)
	var b := Basis.from_euler(rotation)
	# Express the focus in camera space, snap its screen-plane axes to texels, go back.
	var texel := size / float(get_viewport().get_visible_rect().size.y)
	var local := b.inverse() * (_smoothed + _bias)
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
	global_position = focus + b.z * _back
	# The focal plane follows the picture: a lean zooms and tilts, and a plane
	# left where the square-on frame put it would blur the near half of a
	# zoomed-out one. Does nothing until `size` really moves.
	if attributes != null or bool(Quality.current().get("near_focus", false)) \
			or bool(Quality.current().get("near_stand_in", false)):
		_near_focus()
	# Ink patterns are drawn in screen pixels; shifting them by the camera's own
	# texel offset pins every hatch line to the world instead of the glass.
	RenderingServer.global_shader_parameter_set("world_px", Vector2(roundf(local.x / texel), roundf(local.y / texel)))
