extends GameSystem
## Targeting: the slate put on a body while the key is held (owner, 2026-09-16).
##
##   hold Z        lock the nearest threat: the camera leans in behind the
##                 player, the body is bracketed, and the slate reads it
##   a / d         cycle the lock along the list (what is on you first, then near,
##                 the last people after everything in the fight); pages a sweep
##   r while held  sweep: the camera eases back and every body in the field is
##                 read at once, none of them locked
##   release       the camera comes back square and the reads go
##
## It changes no fight: no aim, no slow, no hold. A player who never presses it
## fights exactly as before, and nothing here writes to the simulation. What it
## draws is UiTargetView's; what it decides is Targeting's and TargetRead's.

const ACTION := &"target"
## The field is swept with the scan key: the same key the scanner lens fires on,
## because that is the same thing asked of the slate. A player without the lens
## has it free, and the sweep needs no key of its own.
const SWEEP_ACTION := &"ability_scan"
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


func setup(g: Game) -> void:
	super.setup(g)
	_ensure_action()
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
	var cycle := signi(int(_went_down(&"move_right")) - int(_went_down(&"move_left")))
	var sweep_pressed := _went_down(SWEEP_ACTION)
	if down and not _held and not _forced:
		sweeping = false
		locked = null
	_held = down
	if not down:
		_let_go(delta)
		return
	_list = Targeting.candidates(_bodies(), game.player.pos, _reach(), _people(), _places())
	if sweep_pressed:
		sweeping = not sweeping
		_page = 0
		Events.sfx.emit(&"ui_slate_switch" if sweeping else &"ui_slate_click", Vector3.ZERO)
	pages = Targeting.pages_of(_list)
	if sweeping:
		locked = null
		_lost_at = -INF
		if cycle != 0 and pages > 1:
			_page = posmod(_page + cycle, pages)
			Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
		field = Targeting.sweep(_list, _page)
		page = posmod(_page, pages) + 1
	else:
		field = []
		_lock(cycle)
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
		locked = Targeting.cycle(_list, locked, cycle)
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
			locked = Targeting.pick(_list, null)
			_lost_at = -INF
	if locked == null or was == null:
		if locked != null:
			Events.sfx.emit(&"ui_slate_ping", Vector3.ZERO)
	elif locked.id != was.id:
		Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)


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
		return
	if locked == null:
		_square()
		return
	var to := locked.here() - here
	cam.lean_yaw = LOCK_YAW * _yaw_share(to)
	cam.lean_pitch = LOCK_PITCH
	cam.lean_zoom = LOCK_ZOOM
	var at := Targeting.focus_between(here, locked.here(), LOCK_SHARE, LOCK_MOST)
	cam.lean_bias = game.world.to_3d(at) - game.world.to_3d(here)


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
	var cam := game.camera
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


## What a tour may await of targeting.
func tour_seen(what: StringName) -> bool:
	match what:
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
	return false
