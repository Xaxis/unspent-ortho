extends GameSystem
## THE CLIMB UP A WALKER, IN PLAY (ROADMAP slice 3 step 7): one WalkerClimb
## (src/core/colossus/walker_climb.gd has its rules) up a leg of the straddling
## walker, the leg drawn under his hands (src/render/colossus/colossus_leg.gd),
## the body hung on it, and the climb's own eye on him.
##
## IT STARTS ON A PLANTED FOOT, FROM THE TREAD'S RIM: `use` at the lip of one of
## the craters a foot stands in, while it stands there, and he is on the drum.
## (How the body gets from the crater floor to the drum's first hold is step
## 7c; until then the press puts him on it.)
##
## THE KEYS ARE THE CLIMB'S while he is up (`Game.aloft`): the move up key takes
## him hold to hold. On a ledge he stops, and goes on only on a fresh press, so a
## key held up the whole leg rests on every ledge instead of leaving each one
## spent. Nothing moves while his leg swings, and a set-down with little breath
## off a ledge throws him (WalkerClimb). Nothing up here kills: a fall is a wound
## and lost minutes on the cable, and he climbs on from the pitch's foot.
##
## At the hub the climb is over, and the panel in the crown is read as any thing
## with words on it is (49_story `read`): reading it is being answered.
##
## THE BODY IS WHERE THE LEG IS, THIS FRAME. Numbered after the colossi (19),
## whose view poses every walker from the clock at the top of each frame: the
## step, the patch, the body and the eye are all set from that one pose here, so
## nothing of the climb trails the leg by a frame. A swinging foot carries him
## hundreds of metres a second, and a frame late is metres off his holds.
##
## THE EYE is a Camera3D of its own, made current while a climb is live, as the
## staged eye is (96_eye): out from the plate a little below him and to his
## right, looking at him and up the pitch. Riding up inside the bone he is not
## seen; the eye goes up the outside of the leg to the next pitch, bowed out
## from it, so the whole leg goes by. Everything that asks the viewport which
## camera is drawing (the colossi, the near foot, the air) asks it.
##
## `--climb=PITCH[:HOLD]` stages a climb at a hold (BootOptions), for a frame of
## any pitch without climbing to it.

const LegScript := preload("res://src/render/colossus/colossus_leg.gd")
const LegModel := preload("res://src/models/colossus_leg_model.gd")
const Treads := preload("res://src/core/colossus/colossus_treads.gd")
const Walk := preload("res://src/core/colossus/colossus_walk.gd")

## Where the eye stands in the frame of the hold he is at (+X across the leg, +Y
## up the pitch, +Z out of the plate), metres: back from the plate, down the
## pitch, to his right; and how far up the pitch past his hands it looks.
const EYE_OUT := 7.0
const EYE_DOWN := 2.5
const EYE_SIDE := 2.0
const LOOK_UP := 1.0
const EYE_FOV := 60.0
## THE EYE SEES FAR ENOUGH THAT THE LEG IT IS ON IS DRAWN TRUE. The colossi are
## drawn in compressed space, each VERTEX moved in along its ray past 0.82 of the
## far plane (colossus.gdshader). A facet of the far body is kilometres long, and
## seen from seven metres with its corners compressed, the flat between them came
## in nearer than the patch and the body on it and hid both (measured: a frame of
## nothing but the thigh's plate). Every triangle of a leg is inside a few
## kilometres of any point on it, so past this nothing near him moves.
const EYE_FAR := 20000.0
## How far out from the leg the eye's way up a ride bows, as a share of the way.
const RIDE_BOW := 0.25
## Where the body hangs from a hold: his feet this far down the pitch from the
## rung his hands are on, and his middle this far out from the plate.
const BODY_DROP := 1.35
const BODY_OUT := 0.45
## How near a crater's rim (Treads.rim_r) he may stand and still set off, tiles.
const RIM_REACH := 6.0
## Real seconds after the press that began a climb during which `use` is spent.
const SETTLE := 0.4

var climb: WalkerClimb = null
var leg_view: LegScript
## The colossi's walker being climbed, as its index in their view's defs.
var walker := -1
var _cam: Camera3D
## The tread a climb can begin from where he stands now, or {} (`_watch_rim`).
var _rim: Dictionary = {}
var _hinted := false
var _settle := 0.0
var _use_was := false
var _up_was := false
## A fresh press has been made on the ledge he is on: he may set off from it.
var _go := false
## Whether the body was going hand over hand last frame.
var _moving := false
## The panel at the hub has been read: the talk it opened is up, or was.
var _answered := false
## A climb this run went to the hub and came down.
var _climbed := false
## Whether the swing's hint has been said for the swing he is hanging through.
var _swing_said := false
## The events of the climb since a tour last asked (tour_seen `climb:EVENT`).
var _latched: Dictionary = {}
## For --stats: the real milliseconds the last frame's climb took.
var _cost_us := 0


func setup(g: Game) -> void:
	super.setup(g)
	leg_view = LegScript.new()
	leg_view.name = "colossus_leg"
	add_child(leg_view)


func started() -> void:
	if game.options.climb != "":
		_stage(game.options.climb)


## `--climb=PITCH[:HOLD]`: hung at that hold, up the leg of the tread nearest the
## start.
func _stage(spec: String) -> void:
	var parts := spec.split(":")
	var p := -1
	for i in WalkerClimb.PITCHES.size():
		if String(WalkerClimb.PITCHES[i].id) == parts[0] or str(i) == parts[0]:
			p = i
	var m := _nearest_tread()
	if p < 0 or m.is_empty() or not _walker_of(m):
		push_warning("--climb: no pitch %s, or no tread here with its walker drawn" % parts[0])
		return
	var c := WalkerClimb.begin(int(m.leg), game.world.seed_value)
	c.pitch = p
	c.hold = clampi(parts[1].to_int() if parts.size() > 1 else 0, 0, c.holds_in(p) - 1)
	_begin(c)


func _begin(c: WalkerClimb) -> void:
	climb = c
	_go = false
	_swing_said = false
	game.player.hanging = true
	game.aloft = true
	_settle = SETTLE
	# Up the leg, nothing on the ground reaches him: no blow passes between his
	# level and theirs (FightSim.hero_level).
	if game.player.sim != null:
		game.player.sim.hero_level = ALOFT_LEVEL
	if _cam == null:
		_cam = Camera3D.new()
		_cam.name = "climb_eye"
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.keep_aspect = Camera3D.KEEP_HEIGHT
		_cam.fov = EYE_FOV
		_cam.near = 0.05
		_cam.far = EYE_FAR
		add_child(_cam)
	_cam.make_current()
	_latch(&"began")


## The level the fight is told the body is at while he is up a leg: far past any
## blow's reach from the ground (FightRules.levels_meet).
const ALOFT_LEVEL := 100000


func _colossi() -> Node:
	return get_tree().get_first_node_in_group(&"colossi")


## The tread nearest the player: where the walker's foot comes down in this world.
func _nearest_tread() -> Dictionary:
	var best := {}
	for m: Dictionary in game.world.landmarks:
		if StringName(m.get("kind", &"")) != &"tread":
			continue
		if best.is_empty() or (m.pos as Vector2).distance_to(game.player.pos) < (best.pos as Vector2).distance_to(game.player.pos):
			best = m
	return best


## Take tread `m`'s walker as the one climbed; false when the colossi are not
## drawing it this run.
func _walker_of(m: Dictionary) -> bool:
	var c := _colossi()
	if c == null or c.get("view") == null:
		return false
	var defs: Array = c.view.defs
	for i in defs.size():
		if defs[i].id == StringName(m.walker):
			walker = i
			return true
	return false


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_settle = maxf(0.0, _settle - delta)
	var use_down := Input.is_action_pressed(&"use")
	var use_edge := use_down and not _use_was
	_use_was = use_down
	var c := _colossi()
	if climb == null:
		leg_view.update(null, null, {}, 0.0)
		_watch_rim(c, use_edge)
		_cost_us = Time.get_ticks_usec() - t0
		return
	if c == null or walker < 0:
		return
	var def: RefCounted = c.view.defs[walker]
	var pose: Dictionary = c.view.poses[walker]
	if pose.is_empty():
		return
	for e: StringName in climb.step(delta, pose, _up_key()):
		_on(e)
	# His grip is his breath, and the wrist unit's wind line shows it while he is
	# up (90_ui reads the body after this, the fight writes it again only on the
	# ground's next step, and its own wind is not touched).
	game.body.wind = climb.breath
	game.body.max_wind = FightRules.WIND
	if climb.state == WalkerClimb.DONE and _answered and not game.talking:
		_end()
		_cost_us = Time.get_ticks_usec() - t0
		return
	var dome: Dictionary = game.sky.seen_air().get("dome", {}) if game.sky != null else {}
	leg_view.update(def, climb, pose, float(dome.get(&"dome_night", 0.0)))
	_say_swing(pose)
	if climb.state == WalkerClimb.RIDE:
		_ride(def, pose)
	else:
		var f := body_frame(def, pose)
		_hang(f)
		_cam.global_transform = eye_at(f)
	_quake()
	_cost_us = Time.get_ticks_usec() - t0


## The move up key, as the climb reads it: held, and on a ledge only once it has
## gone down again since he came onto it.
func _up_key() -> bool:
	var held := InputMap.has_action(&"move_up") and Input.is_action_pressed(&"move_up") \
		and game.open_screens.is_empty() and not game.talking
	var edge := held and not _up_was
	_up_was = held
	if climb.state != WalkerClimb.CLIMB or climb.busy > 0.0 or not climb.is_stance(climb.hold):
		return held
	if edge:
		_go = true
	return held and _go


func _on(e: StringName) -> void:
	_latch(e)
	var model := game.player.model
	match e:
		&"moved":
			if climb.is_stance(climb.hold):
				_go = false
				_latch(&"ledge")
		&"rode":
			_say(&"ride")
			if model != null:
				model.visible = false
		&"slipped":
			_go = false
			_say(&"slipped")
		&"fell":
			_go = false
			_fell()
		&"at_hub":
			_at_hub()
			_answered = game.talking


## Shaken off, and caught on the cable at the pitch's foot: wounded, never
## killed, and the minutes on the cable pass.
func _fell() -> void:
	var b := game.body
	b.health = maxi(1, b.health - climb.wound)
	if game.player.hero != null:
		game.player.hero.health = b.health
	game.player.flash(0.12)
	game.player.shudder(0.4)
	Events.sfx.emit(&"jump_land", game.player.model.global_position if game.player.model != null else Vector3.ZERO)
	var minutes := climb.lost_minutes
	climb.lost_minutes = 0.0
	if minutes > 0.0:
		game.clock.skip(minutes)
		Events.time_skipped.emit(minutes, &"fell")
	_say(&"fell")


## The climb is over at the hub: the panel in the crown is read, and reading it
## is being answered (StoryContent `enclave_panel`, talk `the_enclave`).
func _at_hub() -> void:
	for s: GameSystem in game.systems:
		if s.has_method(&"read") and s.name == "49_story":
			s.call(&"read", &"enclave_panel")
			return


## The swing's hint, once each time his leg goes up under him while he hangs.
func _say_swing(pose: Dictionary) -> void:
	var swing := climb.state == WalkerClimb.CLIMB and climb.swinging(pose)
	if swing and not _swing_said:
		_say(&"swing")
	_swing_said = swing


## A line of the climb's, if the story has one for it (StoryContent.CLIMB).
func _say(key: StringName) -> void:
	var line := String(StoryContent.CLIMB.get(key, ""))
	if line != "":
		Events.message.emit(line)


## Where a climb can begin, and the press that begins it.
func _watch_rim(c: Node, use_edge: bool) -> void:
	_rim = {}
	if c == null or c.get("view") == null or game.player == null:
		return
	var here: Vector2 = game.player.pos
	var m := _nearest_tread()
	if not m.is_empty() and _at_rim(m, here) and _walker_of(m) and _planted(c, m):
		_rim = m
	if _rim.is_empty():
		_hinted = false
		return
	if not _hinted:
		_hinted = true
		var line := String(StoryContent.CLIMB.get(&"begin", ""))
		if line != "":
			Events.hint.emit(PlayerSettings.spell(line, [&"use"]), PlayerSettings.cap_of(&"use"))
	if use_edge and not game.input_blocked() and not _spent_elsewhere():
		_begin(WalkerClimb.begin(int(_rim.leg), game.world.seed_value))


static func _at_rim(m: Dictionary, here: Vector2) -> bool:
	for p: Vector3 in (m.pads as Array):
		if Vector2(p.x, p.y).distance_to(here) <= Treads.rim_r(p) + RIM_REACH:
			return true
	return false


## Whether tread `m`'s leg is standing in it now.
func _planted(c: Node, m: Dictionary) -> bool:
	for o: Dictionary in Treads.over(c.view.defs[walker], c.view.routes[walker], float(c.call(&"minutes"))):
		var t: Vector4 = o.tread
		if int(o.leg) == int(m.leg) and bool(o.planted) and Vector2(t.x, t.z).distance_to(m.pos as Vector2) < 1.0:
			return true
	return false


func _spent_elsewhere() -> bool:
	for s: GameSystem in game.systems:
		if s != self and s.has_method(&"use_spent") and bool(s.call(&"use_spent")):
			return true
	return false


## The press that set him on the leg is spent (49_story and 50_survival ask),
## and while he is up there `use` is nobody's on the ground.
func use_spent() -> bool:
	return climb != null or _settle > 0.0


## Where the body is on the pitch, in world space: the frame of the hold he is
## at (LegModel.hold_frame on the pitch's posed bone), eased on toward the next
## while a move is under way. +X across, +Y up the pitch, +Z out of the plate.
func body_frame(def: RefCounted, pose: Dictionary) -> Transform3D:
	var bone: Transform3D = (pose.bones as Array)[climb.bone_index(climb.pitch)]
	var f := LegModel.hold_frame(def, climb, climb.pitch, climb.hold)
	if climb.state == WalkerClimb.CLIMB and climb.busy > 0.0 and climb.hold + 1 < climb.holds_in(climb.pitch):
		var t := 1.0 - climb.busy / (float(WalkerClimb.HOLD_EVERY) / Climb.RATE)
		f = f.interpolate_with(LegModel.hold_frame(def, climb, climb.pitch, climb.hold + 1), smoothstep(0.0, 1.0, t))
	return bone * f


## The body on the hold: facing into the plate, up the pitch its up, and hand
## over hand while a move is under way.
func _hang(f: Transform3D) -> void:
	var model := game.player.model
	if model == null:
		return
	model.visible = true
	var b := f.basis.orthonormalized()
	# PersonModel faces +X: into the plate, with his head up the pitch.
	model.global_transform = Transform3D(Basis(-b.z, b.y, b.x), f.origin - b.y * BODY_DROP + b.z * BODY_OUT)
	var moving := climb.busy > 0.0 and climb.state == WalkerClimb.CLIMB
	if moving and not _moving:
		model.play_action(&"climb", float(WalkerClimb.HOLD_EVERY) / Climb.RATE)
	elif not moving and (_moving or not model.busy()):
		model.pose_at(&"climb", 0.2)
	_moving = moving


## The eye on a body hung at frame `f` (world space).
static func eye_at(f: Transform3D) -> Transform3D:
	var b := f.basis.orthonormalized()
	var at := f.origin + b.x * EYE_SIDE - b.y * EYE_DOWN + b.z * EYE_OUT
	var to := f.origin + b.y * LOOK_UP
	var up := Vector3.UP if absf((to - at).normalized().y) < 0.98 else b.y
	return Transform3D(Basis.looking_at(to - at, up), at)


## Up inside the bone: the eye goes from where it stood on this pitch's top to
## where it will stand on the next one's foot, bowed out from the leg, as the ride
## goes, and looks all the way at where he is in it; the ride runs only while his
## leg stands, and so does the eye. Both ends are on the live pose, so the way up
## rides with the walk.
func _ride(def: RefCounted, pose: Dictionary) -> void:
	var p := climb.pitch
	var t := smoothstep(0.0, 1.0, 1.0 - climb.busy / maxf(float(WalkerClimb.PITCHES[p].ride), 1e-3))
	var next := WalkerClimb.begin(climb.leg, climb.seed_value)
	next.pitch = mini(p + 1, WalkerClimb.PITCHES.size() - 1)
	var bone: Transform3D = (pose.bones as Array)[next.bone_index(next.pitch)]
	var here := body_frame(def, pose)
	var there := bone * LegModel.hold_frame(def, next, next.pitch, 0)
	var from := eye_at(here)
	var to := eye_at(there)
	# An eye looks down its -Z, so its +Z is out of the plate it faces.
	var out := (from.basis.z + to.basis.z).normalized()
	var bow := out * from.origin.distance_to(to.origin) * RIDE_BOW * sin(PI * t)
	var at := from.origin.lerp(to.origin, t) + bow
	var him := (here.origin + here.basis.orthonormalized().y * LOOK_UP).lerp(there.origin + there.basis.orthonormalized().y * LOOK_UP, t)
	var up := Vector3.UP if absf((him - at).normalized().y) < 0.98 else out
	_cam.global_transform = Transform3D(Basis.looking_at(him - at, up), at)


## THE CLIMB IS OVER, the panel at the hub read and put down: the lifts inside
## the leg take him back down to the rim he set off from, in the time the rides
## up took, and the ground is his again. (How the way down is seen and said is
## for a later step; this is its time and its place.)
func _end() -> void:
	var down := 0.0
	for row: Dictionary in WalkerClimb.PITCHES:
		down += float(row.ride)
	climb = null
	var model := game.player.model
	if model != null:
		model.transform = Transform3D.IDENTITY
		model.visible = true
		model.play_action(&"", 0.0)
	game.player.hanging = false
	game.aloft = false
	if game.player.sim != null:
		game.player.sim.hero_level = -1
	if game.camera != null:
		game.camera.make_current()
	var minutes := down * (game.clock.rate if game.clock != null else Tuning.MINUTES_PER_SECOND)
	game.clock.skip(minutes)
	Events.time_skipped.emit(minutes, &"climbed")
	_climbed = true
	_say(&"down")
	_latch(&"down")


## A landing felt where he hangs sways the eye, as it sways the rig (CameraRig).
func _quake() -> void:
	if game.camera == null:
		return
	var q: Vector2 = game.camera.quake_offset()
	if q != Vector2.ZERO:
		var cb := _cam.global_transform.basis
		_cam.global_position += cb.x * q.x + cb.y * q.y


func _latch(e: StringName) -> void:
	_latched[e] = true


func tour_forget(what: StringName) -> void:
	var s := String(what)
	if s.begins_with("climb:"):
		_latched.erase(StringName(s.substr(6)))


## What a tour asks the climb. Live: `climbing`, `climb_patch` (the leg under
## him is drawn), `climb_rim` (he stands where a climb begins), `climb_ready` (on
## a ledge, breath full, and his leg will stand for the next section: the gait
## read as a climber reads it), `climb_riding`, `climbed` (a climb this run is
## over and he is on the ground); latched until asked, `climb:EVENT`
## (WalkerClimb's events, `ledge` when a move ends on one, `began`).
func tour_seen(what: StringName) -> bool:
	var s := String(what)
	if s.begins_with("climb:"):
		return _latched.has(StringName(s.substr(6)))
	match what:
		&"climbing":
			return climb != null
		&"climb_patch":
			return leg_view.drawn
		&"climb_rim":
			return not _rim.is_empty()
		&"climb_ready":
			return _ready_to_go()
		&"climb_riding":
			return climb != null and climb.state == WalkerClimb.RIDE
		&"climbed":
			return climb == null and _climbed
	return false


## On a ledge with a full breath, and his leg standing through the time the next
## section takes.
func _ready_to_go() -> bool:
	if climb == null or climb.state != WalkerClimb.CLIMB or climb.busy > 0.0 or not climb.is_stance(climb.hold):
		return false
	if climb.breath < FightRules.WIND - 1.0:
		return false
	var c := _colossi()
	if c == null or walker < 0:
		return false
	var section := float(WalkerClimb.STANCE_EVERY) / Climb.RATE + 2.0
	var rate: float = game.clock.rate if game.clock != null else Tuning.MINUTES_PER_SECOND
	var m: float = c.call(&"minutes")
	for ahead: float in [0.0, section * 0.5, section]:
		var p: Dictionary = Walk.pose(c.view.defs[walker], c.view.routes[walker], m + ahead * rate)
		if climb.swinging(p):
			return false
	return true


func stats_line() -> String:
	if climb == null:
		return "\nworld climb: none%s" % (", at a planted foot's rim" if not _rim.is_empty() else "")
	var at := _cam.global_position if _cam != null else Vector3.ZERO
	var out := "\nworld climb: pitch %s hold %d of %d, %s, breath %.0f, patch %d tris (%s), %d uploaded, eye %.0f m up at %.0f,%.0f, %d us" % [
		WalkerClimb.PITCHES[climb.pitch].id, climb.hold, climb.holds_in(climb.pitch),
		["climbing", "riding", "at the hub"][climb.state], climb.breath,
		leg_view.triangles, "drawn" if leg_view.drawn else "not drawn", leg_view.uploaded, at.y, at.x, at.z, _cost_us]
	# THE PRECISION AT HEIGHT: a position is a 32-bit float, whose step at the
	# eye's magnitude is the most any placement here can be off by, against the
	# size of a pixel on the body at the eye's distance.
	var model := game.player.model
	if _cam != null and model != null:
		var big := maxf(absf(at.x), maxf(absf(at.y), absf(at.z)))
		var ulp := pow(2.0, floorf(log(maxf(big, 1.0)) / log(2.0)) - 23.0)
		var rows := maxf(1.0, get_viewport().get_visible_rect().size.y)
		var px := 2.0 * at.distance_to(model.global_position) * tan(deg_to_rad(_cam.fov) * 0.5) / rows
		out += "\nworld climb precision: a float's step at the eye %.2f mm, a pixel on him %.2f mm, %.2f px" % [ulp * 1000.0, px * 1000.0, ulp / px]
	return out
