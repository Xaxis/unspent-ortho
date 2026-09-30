extends GameSystem
## Targeting: the slate put on a body while the key is held (owner, 2026-09-16).
##
##   hold Z        lock the nearest threat: the camera leans in behind the
##                 player, the body is bracketed, and the slate reads it
##   u / o, scroll cycle the lock along the list (what is on you first, then
##                 near, the last people after everything in the fight); pages a
##                 sweep. NEVER the move keys: a strafe round a locked body must
##                 not change which body it is (docs/CONTROLS.md, C3)
##   r while held  sweep: the camera eases back and every body in the field is
##                 read at once, none of them locked
##   release       the camera comes back square and the reads go
##
## A LOCK HOLDS THE BODY (owner, 2026-09-24): it faces what is locked, a strafe
## circles it, a swing goes at it and a dodge with no key held goes straight back
## from it. That is `LockOn`'s, applied by the simulation; this file's only write
## to the fight is `Hero.set_lock`, the point it holds, once a frame. What it
## draws is UiTargetView's; what it decides is Targeting's and TargetRead's.

const ACTION := &"target"
## The field is swept with the scan key: the same key the scanner lens fires on,
## because that is the same thing asked of the slate. A player without the lens
## has it free, and the sweep needs no key of its own.
const SWEEP_ACTION := &"ability_scan"
## The lock's own cycle keys (ControlScheme puts them on U and O in every
## scheme, and the scroll and a trackpad's swipe reach them through `take_scroll`).
const NEXT_ACTION := &"target_next"
const PREV_ACTION := &"target_prev"
## The lean of a lock: yaw toward the body, pitch a little lower for the
## perspective behind the player, and closer in. Slight on purpose (owner).
const LOCK_YAW := 11.0
const LOCK_PITCH := -4.5
const LOCK_ZOOM := 0.86
## The frame moves this far from the player toward the body, at most this many tiles.
const LOCK_SHARE := 0.38
const LOCK_MOST := 3.2
## A sweep stands back instead: a shade higher and wider, over the whole field.
const SWEEP_PITCH := 2.5
const SWEEP_ZOOM := 1.14
const SWEEP_SHARE := 0.5
const SWEEP_MOST := 5.0
## The read is taken this often (s): a fight moves faster than a panel needs to.
const READ_EVERY := 0.1

## What is locked — a fight body or a person — or null; the field a sweep reads.
var locked: TargetSubject = null
var sweeping := false
var field: Array[TargetSubject] = []
var read: Dictionary = {}
var rows: Array[Dictionary] = []
## Which page of a field the sweep is showing, and how many there are.
var page := 1
var pages := 1
var view: UiTargetView

## A shot's held key (--target): the same as a finger on it, for a still.
var _forced := false
var _held := false
var _was := {}
var _read_in := 0.0
var _list: Array[TargetSubject] = []
## When the locked subject left the list, -INF while it is still in it: a lock
## waits LOST_GRACE for it to come back. Not 0 or -1, because the fight's clock
## starts at 0 and a sentinel a real time can equal is a bug waiting for a frame.
var _lost_at := -INF
var _page := 0
## Steps of scroll or swipe taken this frame while the key was held.
var _scrolled := 0
var _scroll_left := 0.0
## Radians walked round the held lock since it was taken (or since a tour last
## asked): what `lock_circled` answers. The angle last seen, NAN for none.
var _circled := 0.0
var _circle_was := NAN


func setup(g: Game) -> void:
	super.setup(g)
	_ensure_action()
	ensure_cycle_actions()
	# --target[=sweep] holds the key for a shot, so a still can show a lock.
	_forced = g.options.target
	sweeping = g.options.target_sweep
	view = UiTargetView.new()
	view.name = "target"
	view.game = g
	add_child(view)


## The key is added here rather than in project.godot's hand-written list so a
## build that never had it still answers to it (and tours can press it).
func _ensure_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Z
	InputMap.action_add_event(ACTION, key)


## The cycle keys, for a build or a test that never installed a scheme.
static func ensure_cycle_actions() -> void:
	for pair: Array in [[NEXT_ACTION, KEY_O], [PREV_ACTION, KEY_U]]:
		if InputMap.has_action(pair[0]):
			continue
		InputMap.add_action(pair[0])
		var k := InputEventKey.new()
		k.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], k)


func _went_down(action: StringName) -> bool:
	var now := InputMap.has_action(action) and Input.is_action_pressed(action)
	var was: bool = _was.get(action, false)
	_was[action] = now
	return (now and not was) or (InputMap.has_action(action) and Input.is_action_just_pressed(action))


func _process(delta: float) -> void:
	if game == null or game.world == null or game.player == null:
		return
	# Held, or pressed once and left on, as the player asked for it
	# (PlayerSettings, playing.target).
	var down := _forced or HoldToggle.on(ACTION, &"playing.target")
	# An app on the glass has the keys; a target held into one is let go.
	if not game.open_screens.is_empty():
		down = false
		HoldToggle.forget()
	var cycle := signi(int(_went_down(NEXT_ACTION)) - int(_went_down(PREV_ACTION)) + _scrolled)
	_scrolled = 0
	var sweep_pressed := _went_down(SWEEP_ACTION)
	if down and not _held and not _forced:
		sweeping = false
		locked = null
	_held = down
	if not down:
		_let_go(delta)
		_publish()
		return
	_list = Targeting.candidates(_bodies(), game.player.pos, _reach(), _people(), _places())
	if sweep_pressed:
		sweeping = not sweeping
		_page = 0
		Events.sfx.emit(&"ui_slate_switch" if sweeping else &"ui_slate_click", Vector3.ZERO)
	pages = Targeting.pages_of(_list)
	if sweeping:
		var readable := _sweep_seen()
		pages = Targeting.pages_of(readable)
		locked = null
		_lost_at = -INF
		if cycle != 0 and pages > 1:
			_page = posmod(_page + cycle, pages)
			Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
		field = Targeting.sweep(readable, _page)
		page = posmod(_page, pages) + 1
	else:
		field = []
		_lock(cycle)
	_publish()
	_lean()
	_read_in -= delta
	if _read_in <= 0.0:
		_read_in = READ_EVERY
		_take_read()


## The lock: cycled by hand, else the one already held, else the nearest threat.
## A subject that has stepped out of the list — behind a house, a stride past the
## reach — is held for LOST_GRACE first. A machine that was there half a second
## ago is the same machine, and a lock that flicks to its neighbour is a lock
## nobody trusts.
func _lock(cycle: int) -> void:
	var was := locked
	if cycle != 0 and locked != null:
		locked = Targeting.cycle(_seen(locked), locked, cycle)
		_lost_at = -INF
	else:
		var again := Targeting.same_in(_list, locked)
		if again != null:
			locked = again
			_lost_at = -INF
		elif locked != null and locked.alive() and _waited() < Targeting.LOST_GRACE:
			if is_inf(_lost_at):
				_lost_at = _now()
		else:
			locked = Targeting.pick(_seen(null), null)
			_lost_at = -INF
	if locked == null or was == null:
		if locked != null:
			Events.sfx.emit(&"ui_slate_ping", Vector3.ZERO)
	elif locked.id != was.id:
		Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)


## THE ONE WRITE TO THE FIGHT: where the lock is, or INF. Asked of the subject
## every frame, so a body that moves is followed and one that dies or goes out of
## reach -- which clears `locked` -- lets the body go the frame it happens.
func _publish() -> void:
	var hero: Hero = game.player.hero if game.player != null else null
	if hero == null:
		return
	var at := Vector2.INF
	if locked != null and not sweeping and locked.alive():
		at = locked.here()
	hero.set_lock(at, _now())
	if at.is_finite() and (hero.pos - at).length() > LockOn.NEAR:
		var a := (hero.pos - at).angle()
		if not is_nan(_circle_was):
			_circled += wrapf(a - _circle_was, -PI, PI)
		_circle_was = a
	else:
		_circle_was = NAN
		_circled = 0.0


## While the key is held the scroll and a trackpad's swipe cycle the lock, and
## the zoom is off (owner's ruling): 08_pointer offers each step here first.
func take_scroll(steps: Vector2) -> bool:
	if not _held:
		return false
	# A wheel's notch is one step; a trackpad's glide arrives in fractions and
	# is gathered until it makes one, so a swipe moves the lock once, not ten times.
	_scroll_left += steps.y if absf(steps.y) >= absf(steps.x) else steps.x
	while absf(_scroll_left) >= 1.0:
		_scrolled += signi(roundi(signf(_scroll_left)))
		_scroll_left -= signf(_scroll_left)
	return true


## A held key has the zoom keys too, so + and - cannot move the camera under a lock.
func owns_zoom() -> bool:
	return _held


## THE SUBJECTS A LOCK MAY BE TAKEN ON FRESH (teammate1, 2026-09-24): a machine
## or a person is picked, or cycled onto, only when the player's head SEES it past
## what is drawn (41_shoulder `sight_clear`, Shoulder.sees). Locked through a
## wall, the slate read whatever stood behind it, which in a game about not
## being seen is a free scan. The one already `held` stays in the list whatever
## stands between (it keeps its LOST_GRACE behind cover, as it always did), so a
## cycle goes on from it. A PLACE is a landmark read at a distance by what shows
## of it over everything else, and keeps its own rule.
##
## While nothing is in sight it is asked again at most every SIGHT_EVERY: with
## nobody in view and the key held, every candidate's line was walked every frame.
func _seen(held: TargetSubject) -> Array[TargetSubject]:
	var sight: Node = null
	for s in game.systems:
		if s.has_method(&"sight_clear"):
			sight = s
	if sight == null:
		return _list
	var now := Time.get_ticks_msec() / 1000.0
	if held == null and now < _sight_next:
		return [] as Array[TargetSubject]
	var out: Array[TargetSubject] = []
	for s: TargetSubject in _list:
		if held != null and s.id == held.id:
			out.append(s)
			continue
		if _in_sight(s, sight):
			out.append(s)
	# Nothing in sight: the lines are not walked again for SIGHT_EVERY. Only
	# after a miss -- a pick that found something is never held back.
	if held == null and out.is_empty() and not _list.is_empty():
		_sight_next = now + SIGHT_EVERY
	return out


## Whether the player's head sees `s` past what is drawn. A place keeps its own
## rule (it is read by what shows of it over everything else).
func _in_sight(s: TargetSubject, sight: Node) -> bool:
	if s.body == null and not s.person:
		return true
	var head := game.player.position + Vector3(0.0, HEAD_UP, 0.0)
	var at := s.here()
	var ground := game.view.surface_height(at) if game.view != null else game.world.height_at(at)
	return bool(sight.call(&"sight_clear", head, Vector3(at.x, ground + s.height * 0.5, at.y)))


## THE SWEEP IS HELD TO SIGHT TOO (teammate1, 2026-09-24), or it is the free scan
## the fresh-pick rule closes: what the field reads is what is seen, and a body
## that has come for the player (alerted, chasing, striking), which is on its way
## and would be heard whatever stands between. Which ones pass is worked out every
## SIGHT_EVERY and kept by id, because the list is rebuilt every frame and the
## sweep reads it every frame.
func _sweep_seen() -> Array[TargetSubject]:
	var sight: Node = null
	for s in game.systems:
		if s.has_method(&"sight_clear"):
			sight = s
	if sight == null:
		return _list
	var now := Time.get_ticks_msec() / 1000.0
	if now >= _sweep_next:
		_sweep_next = now + SIGHT_EVERY
		_sweep_ids.clear()
		for s: TargetSubject in _list:
			if (s.body != null and _coming(s.body)) or _in_sight(s, sight):
				_sweep_ids[s.id] = true
	var out: Array[TargetSubject] = []
	for s: TargetSubject in _list:
		if _sweep_ids.has(s.id):
			out.append(s)
	return out


## A body that has noticed the player and come for them.
static func _coming(m: MobState) -> bool:
	return m.alive and (m.mood == MobState.ALERTED or m.mood == MobState.CHASING or m.mood == MobState.ATTACKING)


var _sweep_next := 0.0
var _sweep_ids: Dictionary = {}


## The player's eyes, above the ground under them; and how often a fresh pick
## with nothing in sight asks again.
const HEAD_UP := 1.45
const SIGHT_EVERY := 0.1
var _sight_next := 0.0


## How long the lock has been waiting for a subject that left the list.
func _waited() -> float:
	return 0.0 if is_inf(_lost_at) else _now() - _lost_at


## The fight's own clock, so the grace is the one the simulation keeps.
func _now() -> float:
	var sim := game.player.sim
	return sim.now if sim != null else Time.get_ticks_msec() / 1000.0


## The villagers about: 35_folk keeps them as rows, not bodies, so a person can be
## read like anything else the player can look at. One indoors is out of sight.
func _people() -> Array:
	var folk := _folk()
	if folk == null:
		return []
	var out: Array = []
	for row: Dictionary in folk.get("folk"):
		if StringName(str(row.get("state", &"out"))) == &"in":
			continue
		out.append(row)
	return out


## THE PLACES IN REACH. A depot and a place worth the walk are both things a
## player can stand and look at, and until this existed the slate had nothing to
## say about the biggest set piece in the game. Each system answers for its own
## (`target_rows`), so this one goes on knowing nothing about depots or towers
## and a package that adds a new kind of place needs no line here.
func _places() -> Array:
	var out: Array = []
	for sys in game.systems:
		if sys.has_method(&"target_rows"):
			out.append_array(sys.call(&"target_rows", game.player.pos, _reach()) as Array)
	return out


## 35_folk renames its own node "folk" in setup, so it is asked for by its script
## and not by a name that is not the file's.
func _folk() -> Node:
	for s in game.systems:
		var script := s.get_script() as Script
		if script != null and script.resource_path.ends_with("35_folk.gd"):
			return s
	return null


## Everything in the fight's own list of bodies, which is what a machine or a
## creature actually is; the nodes in the `mobs` group are only their views.
func _bodies() -> Array:
	var sim := game.player.sim
	return sim.mobs if sim != null else []


## How far the slate reads: further with a scanner lens on (the gear's own reach).
func _reach() -> float:
	var gear := _gear()
	var has_lens := false
	if gear != null:
		var loadout: Loadout = gear.get("loadout")
		has_lens = loadout != null and loadout.all_ids().has(&"scanner_lens")
	return Targeting.reach_with(has_lens)


func _gear() -> Node:
	for s in game.systems:
		if s.name == "54_gear":
			return s
	return null


func _take_read() -> void:
	var moment: Moment = game.player.sim.moment if game.player.sim != null else null
	var from := game.player.pos
	var now := game.player.sim.now if game.player.sim != null else 0.0
	if locked != null:
		read = TargetRead.of_subject(locked, from, moment, game.world, game.query, now)
	else:
		read = {}
	rows = []
	for s in field:
		rows.append({
			"id": s.id,
			"name": s.name,
			"machine": s.machine,
			"person": s.person,
			# A person has no health and no working part: an empty tag, because the
			# slate will not draw pips for a life it cannot read.
			"tag": TargetRead.tag(s.body, now) if s.body != null else {},
			"thinking": TargetRead.thinking(s.body, now) if s.body != null else TargetRead.doing(s.folk),
			"distance": s.here().distance_to(from),
		})


## The camera leans while a lock is on, and stands back for a sweep.
func _lean() -> void:
	var cam := game.camera
	var here := game.player.pos
	if sweeping:
		var centre := Targeting.centre_of(field, here)
		var at := Targeting.focus_between(here, centre, SWEEP_SHARE, SWEEP_MOST)
		cam.lean_yaw = 0.0
		cam.lean_pitch = SWEEP_PITCH
		cam.lean_zoom = SWEEP_ZOOM
		cam.lean_bias = game.world.to_3d(at) - game.world.to_3d(here)
		cam.subject = Vector3.INF
		# A sweep reads a FIELD and stands back, which is the flat camera's job.
		_hold_lens(false)
		return
	if locked == null:
		_square()
		return
	# Over the shoulder a lock does not lean: the view turns onto what it holds
	# (CameraRig `subject`). The lean is still asked for, because it is the pose
	# the view glides back to if the shoulder is let go while the lock is held.
	cam.subject = game.world.to_3d(locked.here())
	var to := locked.here() - here
	cam.lean_yaw = LOCK_YAW * _yaw_share(to)
	cam.lean_pitch = LOCK_PITCH
	cam.lean_zoom = LOCK_ZOOM
	var at := Targeting.focus_between(here, locked.here(), LOCK_SHARE, LOCK_MOST)
	cam.lean_bias = game.world.to_3d(at) - game.world.to_3d(here)
	_hold_lens(true)


## A HELD LOCK ANSWERED WITH THE LENS, when the owner's row says so (#120: close
## combat behind the player, open battle on the flat camera). `rules.lock_lens` is
## ON by default: the owner kept the lens and it became the default once its cost
## cleared the slums and the works depot (docs/ROADMAP.md, DECIDED 1). Off, this
## does nothing at all, so a held Z is exactly the orthographic lean it always was.
##
## Read live, so the row can be flipped from dev mode mid-lock and the camera
## follows. Everything else is `CameraRig.lens`'s job: the projection, and the
## pitch carried across so the switch does not tip the picture.
##
## The camera counts who holds the lens (`CameraRig.hold_lens`), so a lock and the
## view over the shoulder can each take it and let it go in any order: leaving
## the shoulder while a lock still wants the lens lands on the lens, and a game
## booted with `--lens=persp` is handed back what it had.
func _hold_lens(on: bool) -> void:
	var cam := game.camera
	if cam == null or not is_instance_valid(cam):
		return
	cam.hold_lens(&"target", on and bool(GameConfig.value("rules.lock_lens")))


## How far round to lean, -1..1: the body's bearing against the screen's own
## right, so the camera turns the short way toward what is being read and the
## player is never spun round behind it.
func _yaw_share(to: Vector2) -> float:
	if to.length() < 0.01:
		return 0.0
	var yaw := deg_to_rad(game.camera.yaw_deg)
	var right := Vector2(cos(yaw), -sin(yaw))
	return clampf(to.normalized().dot(right), -1.0, 1.0)


func _square() -> void:
	_hold_lens(false)
	var cam := game.camera
	cam.subject = Vector3.INF
	cam.lean_yaw = 0.0
	cam.lean_pitch = 0.0
	cam.lean_zoom = 1.0
	cam.lean_bias = Vector3.ZERO


func _let_go(_delta: float) -> void:
	if locked != null or sweeping or not read.is_empty() or not rows.is_empty():
		locked = null
		sweeping = false
		field = []
		read = {}
		rows = []
		_list = []
		_page = 0
		page = 1
		pages = 1
		_lost_at = -INF
	_square()


func _exit_tree() -> void:
	if game != null and game.camera != null and is_instance_valid(game.camera):
		_square()


## `lock_circled` is a distance walked, so a tour asking twice is asking about
## the walk since it last asked.
func tour_forget(what: StringName) -> void:
	if what == &"lock_circled":
		_circled = 0.0


## What a tour may await of targeting. `target:KIND` is the lock on that kind (the
## roster id or its prefix), so a frame can say WHAT is locked and not only that
## something is -- a cycle that landed on a villager passed as a cycle before.
func tour_seen(what: StringName) -> bool:
	if String(what).begins_with("target:"):
		var kind := String(what).substr(7)
		return locked != null and not sweeping and String(locked.kind).begins_with(kind)
	match what:
		# The body is turned onto what it holds (LockOn), asked of the fight's own
		# body and not of this file's intent.
		&"lock_facing":
			var hero: Hero = game.player.hero
			if hero == null or not hero.lock.is_finite():
				return false
			var to := hero.lock - hero.pos
			return to.length() >= LockOn.NEAR and absf(wrapf(hero.facing - to.angle(), -PI, PI)) < 0.25
		# A quarter of a circle walked round the lock without letting it go.
		&"lock_circled":
			return absf(_circled) >= PI * 0.5
		&"target":
			return locked != null
		&"target_sweep":
			return sweeping and not field.is_empty()
		&"target_lean":
			return game.camera.leaning()
		&"target_person":
			return locked != null and locked.person
		&"target_paged":
			return sweeping and pages > 1
		&"target_none":
			return locked == null and not sweeping and not game.camera.leaning()
		# Which lens is drawing, asked of BOTH halves of it, so a frame named for
		# the lens cannot pass on a camera whose `lens` and `projection` disagree
		# -- which is exactly what they did before `CameraRig.lens` had a setter.
		&"target_lens":
			return game.camera.lens == &"persp" \
					and game.camera.projection == Camera3D.PROJECTION_PERSPECTIVE
		&"target_flat":
			return game.camera.lens == &"ortho" \
					and game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	return false
