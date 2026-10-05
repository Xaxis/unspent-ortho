extends GameSystem
## THE CLIMB UP A WALKER, IN PLAY (ROADMAP slice 3 step 7): one WalkerClimb
## (src/core/colossus/walker_climb.gd has its rules) up a leg of the straddling
## walker, the leg drawn under his hands (src/render/colossus/colossus_leg.gd),
## the body hung on it, and the climb's own eye on him.
##
## IT STARTS ON THE GROUND, IN THE TREAD: the line's cable hangs from a planted
## foot's drum down into the crater its middle toe stands in (WalkerClimb's first
## pitch). He walks down to its foot, and `use` within START_REACH of it, while
## the foot stands, has him on it; he climbs it to the drum as any pitch.
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
## THE CLIMB IS A SET PIECE IN TIME (the contract, tests/render/test_climb_time.gd):
## from his first hand-on to the cable (`_begin`) until he steps off at the hub
## (`_end`) the world clock runs at SET_PIECE of its rate, and the walkers at the
## whole of it (WorldClock.set_piece, walk_lead). The climb is played in real
## seconds and its drama is the lame leg's swing, 139 real seconds at full pace;
## at the world's own rate those 16 real minutes were a whole game day, and he
## reached the crown starving in the dark. The descent's lifts, in the time the
## rides took, keep the same split. A fall does not end the climb, and the minutes
## lost to one are the world's (WalkerClimb.CAUGHT_MINUTES).
##
## THE BODY IS WHERE THE LEG IS, THIS FRAME. Numbered after the colossi (19),
## whose view poses every walker from the clock at the top of each frame: the
## step, the patch, the body and the eye are all set from that one pose here, so
## nothing of the climb trails the leg by a frame. A swinging foot carries him
## hundreds of metres a second, and a frame late is metres off his holds.
##
## THE EYE is a Camera3D of its own, made current while a climb is live, as the
## staged eye is (96_eye): out from the plate above him and to his side, looking
## past him down the face to what is under it (EYE_OUT). Riding up inside the
## bone he is not seen; the eye goes up the outside of the leg to the next
## pitch, swung kilometres out off it to the island under the walker and back
## (`_ride`), so the whole leg goes by and the drop is seen. Everything that asks the
## viewport which camera is drawing (the colossi, the near foot, the air) asks
## it.
##
## `--climb=PITCH[:HOLD]` stages a climb at a hold (BootOptions), for a frame of
## any pitch without climbing to it.

## THE SET PIECE'S SHARE OF THE WORLD CLOCK'S RATE while he is up. An eighth:
## the proof's climb on seed 1, with its three waits on the lame leg's swing,
## took about 16 real minutes, which at 1.4 world minutes a second was 22.8 game
## hours; at an eighth it is 2.8, under three, so he reaches the crown in about
## the light he set out in and no meal later than he would on the ground.
const SET_PIECE := 0.125

const LegScript := preload("res://src/render/colossus/colossus_leg.gd")
const LegModel := preload("res://src/models/colossus_leg_model.gd")
const Treads := preload("res://src/core/colossus/colossus_treads.gd")
const Walk := preload("res://src/core/colossus/colossus_walk.gd")

## WHERE THE EYE STANDS, in the frame of the face he is on, metres: out from
## the plate, up the face from him (against the way down it: the world's down
## laid on the plate) and across it; and how far down the face past him it
## looks. It keeps the world's up, so beside him the face falls away down the
## frame and what is under it fills the far side: the drum's crater a hundred
## metres down, the haze forty kilometres under the thigh. Measured on the five
## pitches, a quarter to a third of the frame looks past the walker and down.
const EYE_OUT := 5.0
const EYE_UP := 4.0
const EYE_SIDE := 10.0
const LOOK_DOWN := 6.0
const EYE_FOV := 60.0
## Riding up inside the bone the eye looks this far up the pitch past where he is.
const LOOK_UP := 1.0
## THE EYE SEES AS FAR AS ANY EYE DOES (SkyLight.HIGHEST_SEE): the ground under
## him, forty kilometres down from the thigh, and the leg he is on drawn true.
## The colossi are drawn in compressed space, each VERTEX moved in along its ray
## past 0.82 of the far plane (colossus.gdshader). A facet of the far body is
## kilometres long, and seen from seven metres with its corners compressed, the
## flat between them came in nearer than the patch and the body on it and hid
## both (measured at a 1400 m far: a frame of nothing but the thigh's plate).
## Every triangle of a walker is well inside this of any point on it, so nothing
## of one is moved at all.
## AND IT STARTS NO NEARER THAN IT HAS TO. Under Compatibility (the web) depth is
## not reversed, so a 24-bit step at a distance d is d^2 / (near 2^24): at the
## 0.05 this eye had, 1.9 km at the thigh's forty kilometres down, where a
## coast's shallows and a foot's waterline lie a few metres apart. Nothing comes
## nearer the eye than the plate it stands EYE_OUT off, so a metre costs nothing
## up here and is twenty times the depth below.
const EYE_NEAR := 1.0
## How far out from the leg the eye's way up a ride bows, as a share of the way.
const RIDE_BOW := 0.25
## How far the eye swings out across the leg to take in the island on a ride, as
## a share of its height, and the share of the ride it takes to swing out (and
## back in): it holds on the island between.
const RIDE_OUT := 0.5
const RIDE_TURN := 0.3
## AND ITS LENS LENGTHENS ON THE ISLAND: the island is two kilometres across
## and the eye twenty to fifty off, a few pixels of sea at the climb's own lens.
## Held, the island's half-width takes this share of the frame's half-height,
## and the near plane goes out with the eye, which is kilometres from anything,
## so a long lens on the web's depth (EYE_NEAR) does not lose the shore in the sea.
const RIDE_FRAME := 0.35
const RIDE_NEAR := 400.0
## THE ISLAND FIRST, AND THE LEG HE IS IN AT THE FRAME'S EDGE. Aimed straight at
## the island from beside the thigh, the lens held only the island, a map seen
## from nowhere, and once the walk had carried the leg away it held no walker
## at all (the real climb's thigh ride, 15:54). Widened to take in the leg, the
## island was a speck whenever the leg stood far from it. So the island comes
## first: the frame turns from it toward the part of the leg that lies nearest
## it on the glass, its foot or its shin, until that part is RIDE_LEG_EDGE of the
## way out to the frame's edge, on the shortest lens that holds both, never
## longer than the island's own (RIDE_FRAME) and never so wide that the
## island's half-width is under RIDE_FRAME_LEAST of the frame's. Where the leg
## will not fit even then, the frame turns toward it as far as the island allows.
const RIDE_LEG_EDGE := 0.85
const RIDE_FRAME_LEAST := 0.25
## How many points down the leg, hip to knee to ankle, are asked which lies
## nearest the island on the glass.
const RIDE_LEG_POINTS := 16
## The longest lens it takes (a camera refuses one under a degree).
const RIDE_FOV_LEAST := 2.0
## Where the body hangs from a hold: his feet this far down the pitch from the
## rung his hands are on, and his middle this far out from the plate.
const BODY_DROP := 1.35
const BODY_OUT := 0.45
## How near the foot of a planted foot's cable he may stand and take it, tiles:
## the crater's floor ring and the step above it, where the pad leaves room.
const START_REACH := 6.0
## How near the foot of a planted foot's cable he must be for the cable to be
## drawn hanging there before he takes it, tiles: from anywhere in its crater,
## and from its lip, he sees the way up.
const CABLE_SEEN := 120.0
## Real seconds after the press that began a climb during which `use` is spent.
const SETTLE := 0.4

var climb: WalkerClimb = null
var leg_view: LegScript
## The colossi's walker being climbed, as its index in their view's defs.
var walker := -1
var _cam: Camera3D
## The foot whose cable he can take from where he stands now, or {} (`_watch_cable`,
## one of `_feet_in_treads`).
var _rim: Dictionary = {}
var _hinted := false
## The line of the cable drawn hanging while nobody climbs it (`_show_cable`),
## and which walker's foot, by "walker:leg".
var _hung: WalkerClimb = null
var _hung_key := ""
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


## `--climb=PITCH[:HOLD]`: hung at that hold, up the leg standing in (or over)
## the tread nearest the start. `--climb=PITCH:ride[:SHARE]`: riding up from that
## pitch's top, SHARE of the ride gone. Either way with the far land built.
func _stage(spec: String) -> void:
	var parts := spec.split(":")
	var p := -1
	for i in WalkerClimb.PITCHES.size():
		if String(WalkerClimb.PITCHES[i].id) == parts[0] or str(i) == parts[0]:
			p = i
	var feet := _feet_in_treads()
	if p < 0 or feet.is_empty():
		push_warning("--climb: no pitch %s, or no foot in a tread here with its walker drawn" % parts[0])
		return
	walker = int(feet[0].walker)
	var c := WalkerClimb.begin(int(feet[0].leg), game.world.seed_value)
	c.pitch = p
	if parts.size() > 1 and parts[1] == "ride" and float(WalkerClimb.PITCHES[p].ride) > 0.0:
		c.hold = c.holds_in(p) - 1
		c.state = WalkerClimb.RIDE
		c.busy = float(WalkerClimb.PITCHES[p].ride) * (1.0 - clampf(parts[2].to_float() if parts.size() > 2 else 0.0, 0.0, 1.0))
	else:
		c.hold = clampi(parts[1].to_int() if parts.size() > 1 else 0, 0, c.holds_in(p) - 1)
	_begin(c)
	# A staged hold is a moment deep in the climb, when the workers have long
	# built the far land under it: built now, so its first frames are not holes.
	if game.view != null:
		game.view.ensure_far()


func _begin(c: WalkerClimb) -> void:
	climb = c
	if game.clock != null:
		game.clock.set_piece = SET_PIECE
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
		_cam.near = EYE_NEAR
		_cam.far = SkyLight.HIGHEST_SEE
		# Looking down the leg it is still an eye out in the air, not the play
		# camera looking down on the ground (SkyLight.horizon_share).
		_cam.set_meta(SkyLight.LOOKS_OUT, true)
		add_child(_cam)
	_cam.make_current()
	_lift_near(true)
	_latch(&"began")


## Up the leg the plate near the eye is lit as form, on the far body and the
## near foot as on the patch (colossus_leg_model.gd NEAR_LIFT), and the walker
## he is on is drawn all there, never given to the air by its hub's distance
## (ColossusView.climbed).
func _lift_near(on: bool) -> void:
	var c := _colossi()
	for part: StringName in [&"view", &"foot"]:
		if c != null and c.get(part) != null:
			(c.get(part) as Object).call(&"lift_near", on)
	if c != null and c.get(&"view") != null:
		(c.get(&"view") as Object).set(&"climbed", walker if on else -1)


## The level the fight is told the body is at while he is up a leg: far past any
## blow's reach from the ground (FightRules.levels_meet).
const ALOFT_LEVEL := 100000


func _colossi() -> Node:
	return get_tree().get_first_node_in_group(&"colossi")


## Every foot standing in a tread, or over one, now, nearest the player first:
## {walker (its index in the colossi's view), leg, pads (Array[Vector3], tile
## space), planted}. Asked of the walks the treads were handed to
## (Treads.over), never of the world's whole list of landmarks.
func _feet_in_treads() -> Array:
	var out: Array = []
	var c := _colossi()
	if c == null or c.get("view") == null or game.player == null:
		return out
	var m: float = c.call(&"minutes")
	for i in (c.view.defs as Array).size():
		var d: RefCounted = c.view.defs[i]
		for o: Dictionary in Treads.over(d, c.view.routes[i], m):
			var t: Vector4 = o.tread
			var centre := Vector2(t.x, t.z)
			out.append({"walker": i, "leg": int(o.leg), "planted": bool(o.planted),
				"pads": Treads.pads(d, centre, t.w), "d": centre.distance_to(game.player.pos)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.d) < float(b.d))
	return out


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_settle = maxf(0.0, _settle - delta)
	var use_down := Input.is_action_pressed(&"use")
	var use_edge := use_down and not _use_was and not Survival.ask_pending(game)
	_use_was = use_down
	var c := _colossi()
	if climb == null:
		_show_cable(c)
		_watch_cable(use_edge)
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
	leg_view.update(def, climb, pose, dome)
	_say_swing(pose)
	if climb.state == WalkerClimb.RIDE:
		_ride(def, pose)
	else:
		var f := body_frame(def, pose)
		_hang(f)
		_cam.fov = EYE_FOV
		_cam.near = EYE_NEAR
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
			# At the top of the pitch just climbed: the pitch moves on when the ride ends.
			Events.message.emit(String((StoryContent.CLIMB[&"climb_ride"] as Dictionary)[WalkerClimb.PITCHES[climb.pitch].id]))
			if model != null:
				model.visible = false
		&"slipped":
			_go = false
			Events.message.emit(String(StoryContent.CLIMB[&"climb_slipped"]))
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
	Events.message.emit(String(StoryContent.CLIMB[&"climb_fell"]))


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
		_hint(&"climb_swing")
	_swing_said = swing


## One of the climb's two hints ([line, actions], as Guide.HINTS) on the teaching
## channel: the line in the player's own keys, and the first of them on the cap.
static func _hint(key: StringName) -> void:
	var h: Array = StoryContent.CLIMB[key]
	var keys: Array = h[1]
	Events.hint.emit(PlayerSettings.spell(String(h[0]), keys), PlayerSettings.cap_of(keys[0]) if not keys.is_empty() else "")


## Where a climb can begin, and the press that begins it.
func _watch_cable(use_edge: bool) -> void:
	_rim = {}
	for f: Dictionary in _feet_in_treads():
		if bool(f.planted) and _cable_foot(f).distance_to(game.player.pos) <= START_REACH:
			_rim = f
			break
	if _rim.is_empty():
		_hinted = false
		return
	if not _hinted:
		_hinted = true
		_hint(&"climb_begin")
	if use_edge and _cable_takes():
		walker = int(_rim.walker)
		_begin(WalkerClimb.begin(int(_rim.leg), game.world.seed_value))


## A press now takes hold of the cable in reach (`_rim`): the one answer
## `_watch_cable` acts on and `use_line` names.
func _cable_takes() -> bool:
	return climb == null and not _rim.is_empty() and not game.input_blocked() and not _spent_elsewhere() \
			and not Survival.words_in_front(game)


## The hint for the press the cable would take (UiLink.use_hint), or "".
func use_line() -> String:
	return "cable - climb" if game != null and not Survival.ask_pending(game) and _cable_takes() else ""


## THE CABLE HANGS WHETHER OR NOT ANYBODY CLIMBS IT: at its foot, with the
## climb's hint on the glass, there is a way up to see. It is the patch of the
## climb's hanging pitch (colossus_leg_model.gd `_cable`), so the nearest planted
## foot's cable within CABLE_SEEN is drawn hanging at its first hold, and a climb
## begun on it takes the same patch.
func _show_cable(c: Node) -> void:
	var near: Dictionary = {}
	for f: Dictionary in _feet_in_treads():
		if bool(f.planted) and _cable_foot(f).distance_to(game.player.pos) <= CABLE_SEEN:
			near = f
			break
	var pose: Dictionary = c.view.poses[int(near.walker)] if not near.is_empty() else {}
	if pose.is_empty():
		leg_view.update(null, null, {}, {})
		return
	var key := "%d:%d" % [int(near.walker), int(near.leg)]
	if key != _hung_key:
		_hung_key = key
		_hung = WalkerClimb.begin(int(near.leg), game.world.seed_value)
	var dome: Dictionary = game.sky.seen_air().get("dome", {}) if game.sky != null else {}
	leg_view.update(c.view.defs[int(near.walker)], _hung, pose, dome)


## Where the cable of foot `f` (one of `_feet_in_treads`) comes down, on this
## frame's pose: the ground under its first hold, tile space.
func _cable_foot(f: Dictionary) -> Vector2:
	var c := _colossi()
	var pose: Dictionary = c.view.poses[int(f.walker)]
	if pose.is_empty():
		return Vector2.INF
	var line := WalkerClimb.begin(int(f.leg), game.world.seed_value)
	var bone: Transform3D = (pose.bones as Array)[line.bone_index(0)]
	var at := bone * line.surface_at(c.view.defs[int(f.walker)], 0, 0.0, 0.0, 0.0)
	return Vector2(at.x, at.z)


const TOUR_PLACES: Array[String] = ["climb:cable", "climb:lip"]


## `walkto at:climb:cable`: the foot of the nearest planted foot's cable; and
## `at climb:lip`: on the lip of the crater it hangs into, above it, so the walk
## down to it is his own (`_lip_over`).
func tour_place(what: String) -> Vector2:
	var lip := what == "climb:lip"
	if not what in TOUR_PLACES:
		return Vector2.INF
	var best := Vector2.INF
	var best_f: Dictionary = {}
	for f: Dictionary in _feet_in_treads():
		if not bool(f.planted):
			continue
		var at := _cable_foot(f)
		if not best.is_finite() or at.distance_to(game.player.pos) < best.distance_to(game.player.pos):
			best = at
			best_f = f
	if not lip or best_f.is_empty():
		return best
	return _lip_over(best, (best_f.pads as Array)[1])


## How far in from a crater's rim (Treads.rim_r) `at climb:lip` stands.
const LIP_IN := 2.0
## How far round the crater from the cable's own bearing, either way (radians),
## the lip may be sought, in steps of LIP_TURN; and how far in toward the cable
## it may come, in steps of LIP_STEP metres, short of LIP_NEAREST of it.
const LIP_SWING := 1.2
const LIP_TURN := 0.1
const LIP_STEP := 2.0
const LIP_NEAREST := 6.0


## THE LIP IS WHERE THE WALK DOWN IS HIS OWN, on any world. Straight out from the
## pad's middle through the cable, at the rim, the walk down met a wall on seed
## 1 at GEN 47: twelve metres in the line rose two levels onto the spoil, a body
## steps one, and the walk stopped 8.7 tiles short of the cable. So the
## lip is the spot nearest that one, round the rim and in from it, from which
## the straight walk to the cable never steps more than a body can
## (WorldQuery.passable), on dry ground.
func _lip_over(cable: Vector2, pad: Vector3) -> Vector2:
	var centre := Vector2(pad.x, pad.y)
	var out := (cable - centre).normalized()
	var rim := Treads.rim_r(pad) - LIP_IN
	var first := centre + out * rim
	var r := rim
	while r >= cable.distance_to(centre) + LIP_NEAREST:
		var turn := 0.0
		while turn <= LIP_SWING:
			for side: float in ([1.0] if turn == 0.0 else [1.0, -1.0]):
				var at := centre + out.rotated(turn * side) * r
				if _walk_clear(at, cable):
					return at
			turn += LIP_TURN
		r -= LIP_STEP
	return first


## Whether a body walks straight from `a` to `b` on its own feet: every tile on
## the way dry and a body's one level (WorldQuery.passable) from the one before.
## Read from a window round the line, never the whole world.
func _walk_clear(a: Vector2, b: Vector2) -> bool:
	var win := TileWindow.of(game.world, floori(minf(a.x, b.x)) - 1, floori(minf(a.y, b.y)) - 1,
		floori(maxf(a.x, b.x)) + 2, floori(maxf(a.y, b.y)) + 2)
	var n := ceili(a.distance_to(b) / 0.25)
	var prev := -1
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(maxi(n, 1)))
		var t := Vector2i(floori(p.x), floori(p.y))
		if not game.world.in_bounds(t.x, t.y) or not win.has(t.x, t.y):
			return false
		var at := win.at(t.x, t.y)
		if Ground.is_water(win.ground[at]):
			return false
		if prev >= 0 and absi(win.level[at] - win.level[prev]) > 1:
			return false
		prev = at
	return true


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
		var t := 1.0 - climb.busy / WalkerClimb.move_secs(climb.pitch)
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
		model.play_action(&"climb", WalkerClimb.move_secs(climb.pitch))
	elif not moving and (_moving or not model.busy()):
		model.pose_at(&"climb", 0.2)
	_moving = moving


## The eye on a body hung at frame `f` (world space).
static func eye_at(f: Transform3D) -> Transform3D:
	var b := f.basis.orthonormalized()
	var n := b.z
	# Down the face; down the pitch where the face is level and has none.
	var down := Vector3.DOWN - n * Vector3.DOWN.dot(n)
	down = down.normalized() if down.length() > 0.1 else -b.y
	var at := f.origin + n * EYE_OUT - down * EYE_UP + down.cross(n) * EYE_SIDE
	var to := f.origin + down * LOOK_DOWN
	var up := Vector3.UP if absf((to - at).normalized().y) < 0.98 else -down
	return Transform3D(Basis.looking_at(to - at, up), at)


## Where the land is: the middle of the island, at the sea. --stats says where
## it lies from the eye: the walker straddles it, and from the pitches measured
## (seed 1) it lay into the face he is on, behind the leg, or behind the eye.
func _land() -> Vector3:
	if game == null or game.world == null:
		return Vector3.INF
	var half := float(game.world.size) * 0.5
	return Vector3(half, TerrainMesher.WATER_Y, half)


## Up inside the bone: the eye goes from where it stood on this pitch's top to
## where it will stand on the next one's foot, bowed out from the leg, as the ride
## goes; the ride runs only while his leg stands, and so does the eye. Both ends
## are on the live pose, so the way up rides with the walk.
## AND IT TAKES IN THE ISLAND: he is not seen in there, so over the ride's first
## RIDE_TURN share the eye swings out RIDE_OUT off the leg and turns from where
## he is down to the island under the walker, holds on it, and over the last
## share comes back to him on the next pitch. It swings out across the plane
## the leg bends in: the island lies by the foot, in that plane, so from beside
## it the leg falls away to the foot and nothing of it stands in between, and
## the frame holds the shin's fall to its foot with the island (RIDE_LEG).
func _ride(def: RefCounted, pose: Dictionary) -> void:
	var p := climb.pitch
	var share := clampf(1.0 - climb.busy / maxf(float(WalkerClimb.PITCHES[p].ride), 1e-3), 0.0, 1.0)
	var t := smoothstep(0.0, 1.0, share)
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
	var look := (him - at).normalized()
	var fov := EYE_FOV
	var land := _land()
	var wide := smoothstep(0.0, RIDE_TURN, share) * smoothstep(0.0, RIDE_TURN, 1.0 - share)
	if land.is_finite() and wide > 0.0:
		var k := climb.leg
		var bend: Vector3 = ((pose.knees[k] as Vector3) - (pose.hips[k] as Vector3)).cross((pose.ankles[k] as Vector3) - (pose.knees[k] as Vector3))
		var side := Vector3(bend.x, 0.0, bend.z)
		if side.length() > 1e-3:
			side = side.normalized()
			side *= signf(side.dot(out)) if absf(side.dot(out)) > 1e-3 else 1.0
			at += side * maxf(at.y, 0.0) * RIDE_OUT * wide
		var to_land := (land - at).normalized()
		var half := float(game.world.size) * 0.5
		var island := atan(half / at.distance_to(land))
		var to_leg := _nearest_on_leg(pose, k, at, to_land)
		var gap := to_land.angle_to(to_leg)
		# The shortest lens that holds the island whole and the leg's part at
		# RIDE_LEG_EDGE, between the island's own and its floor.
		var off := maxf(0.0, (gap - RIDE_LEG_EDGE * island) / (1.0 + RIDE_LEG_EDGE))
		var hold := clampf(off + island, atan(half / (RIDE_FRAME * at.distance_to(land))), atan(half / (RIDE_FRAME_LEAST * at.distance_to(land))))
		var turn := clampf(gap - RIDE_LEG_EDGE * hold, 0.0, hold - island)
		var aim := to_land.slerp(to_leg, turn / gap) if gap > 1e-4 else to_land
		look = (him - at).normalized().slerp(aim, wide)
		fov = lerpf(EYE_FOV, rad_to_deg(2.0 * hold), wide)
	_cam.fov = clampf(fov, RIDE_FOV_LEAST, EYE_FOV)
	_cam.near = maxf(EYE_NEAR, RIDE_NEAR * wide * wide)
	var up := Vector3.UP if absf(look.y) < 0.98 else out
	_cam.global_transform = Transform3D(Basis.looking_at(look, up), at)


## The way from `at` to the point of leg `k`, hip to knee to ankle, that lies
## nearest the way `to` on the glass.
func _nearest_on_leg(pose: Dictionary, k: int, at: Vector3, to: Vector3) -> Vector3:
	var hip: Vector3 = pose.hips[k]
	var knee: Vector3 = pose.knees[k]
	var ankle: Vector3 = pose.ankles[k]
	var best := (ankle - at).normalized()
	for i in RIDE_LEG_POINTS + 1:
		var s := float(i) / float(RIDE_LEG_POINTS)
		var p := hip.lerp(knee, s * 2.0) if s < 0.5 else knee.lerp(ankle, s * 2.0 - 1.0)
		var d := (p - at).normalized()
		if d.angle_to(to) < best.angle_to(to):
			best = d
	return best


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
	_lift_near(false)
	# The lifts down in the time the rides up took, at the set piece's split: the
	# world's share of those seconds passes, and the walkers walk the whole.
	var walked := down * (game.clock.rate if game.clock != null else Tuning.MINUTES_PER_SECOND)
	var minutes := walked * SET_PIECE
	game.clock.skip(minutes)
	game.clock.walk_lead += walked - minutes
	game.clock.set_piece = 1.0
	Events.time_skipped.emit(minutes, &"climbed")
	_climbed = true
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
## him is drawn), `climb_cable` (he stands at a cable's foot, where a climb
## begins), `climb_ready` (on
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
		&"climb_cable":
			return not _rim.is_empty()
		&"climb_foot_seen":
			return _foot_seen()
		&"climb_ready":
			return _ready_to_go()
		&"climb_riding":
			return climb != null and climb.state == WalkerClimb.RIDE
		&"climbed":
			return climb == null and _climbed
	return false


## Whether the nearest planted foot's cable comes down FOOT_IN_FRAME inside the
## play frame (CameraRig.sees_point): the way up, in sight, not on its edge.
func _foot_seen() -> bool:
	for f: Dictionary in _feet_in_treads():
		if bool(f.planted):
			var at := _cable_foot(f)
			return at.is_finite() and CameraRig.sees_point(game.camera, game.world.to_3d(at), -FOOT_IN_FRAME)
	return false


## How far inside the frame's edge the cable's foot stands to be in sight, tiles.
const FOOT_IN_FRAME := 3.0


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
	var section := WalkerClimb.move_secs(climb.pitch) * float(WalkerClimb.STANCE_EVERY / WalkerClimb.HOLD_EVERY) + 2.0
	var rate: float = game.clock.rate if game.clock != null else Tuning.MINUTES_PER_SECOND
	var m: float = c.call(&"minutes")
	for ahead: float in [0.0, section * 0.5, section]:
		var p: Dictionary = Walk.pose(c.view.defs[walker], c.view.routes[walker], m + ahead * rate)
		if climb.swinging(p):
			return false
	return true


func stats_line() -> String:
	if climb == null:
		return "\nworld climb: none%s" % (", at a planted foot's cable" if not _rim.is_empty() else "")
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
	var land := _land()
	if _cam != null and land.is_finite() and climb.state == WalkerClimb.CLIMB:
		var c := _colossi()
		var f := body_frame(c.view.defs[walker], c.view.poses[walker]) if c != null and walker >= 0 else Transform3D()
		var glass := "behind the eye" if _cam.is_position_behind(land) else "at %s of the glass" % [(_cam.unproject_position(land) / get_viewport().get_visible_rect().size).snapped(Vector2(0.01, 0.01))]
		var out_of := rad_to_deg(asin(clampf((land - at).normalized().dot(f.basis.orthonormalized().z), -1.0, 1.0)))
		out += "\nworld climb land: %.0f km off, %s, its way %.0f degrees out of the face he is on (under 0, into it)" % [
			at.distance_to(land) / 1000.0, glass, out_of]
	return out
