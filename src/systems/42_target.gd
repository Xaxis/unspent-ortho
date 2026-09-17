extends GameSystem
## Targeting: the slate put on a body while the key is held (owner, 2026-09-16).
##
##   hold Z        lock the nearest threat: the camera leans in behind the
##                 player, the body is bracketed, and the slate reads it
##   a / d         cycle the lock along the list (what is on you first, then near)
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

## The body locked, or null; the field a sweep reads; and what they read as.
var locked: MobState = null
var sweeping := false
var field: Array[MobState] = []
var read: Dictionary = {}
var rows: Array[Dictionary] = []
var view: UiTargetView

## A shot's held key (--target): the same as a finger on it, for a still.
var _forced := false
var _held := false
var _was := {}
var _read_in := 0.0
var _list: Array[MobState] = []


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
	var down := _forced or (InputMap.has_action(ACTION) and Input.is_action_pressed(ACTION))
	# An app on the glass has the keys; a target held into one is let go.
	if not game.open_screens.is_empty():
		down = false
	var cycle := signi(int(_went_down(&"move_right")) - int(_went_down(&"move_left")))
	var sweep_pressed := _went_down(SWEEP_ACTION)
	if down and not _held and not _forced:
		sweeping = false
		locked = null
	_held = down
	if not down:
		_let_go(delta)
		return
	_list = Targeting.candidates(_bodies(), game.player.pos, _reach())
	if sweep_pressed:
		sweeping = not sweeping
		Events.sfx.emit(&"ui_slate_switch" if sweeping else &"ui_slate_click", Vector3.ZERO)
	if sweeping:
		locked = null
		field = Targeting.sweep(_list)
	else:
		field = []
		var was := locked
		locked = Targeting.cycle(_list, locked, cycle) if cycle != 0 and locked != null else Targeting.pick(_list, locked)
		if locked != was and locked != null:
			Events.sfx.emit(&"ui_slate_ping" if was == null else &"ui_slate_click", Vector3.ZERO)
	_lean()
	_read_in -= delta
	if _read_in <= 0.0:
		_read_in = READ_EVERY
		_take_read()


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
		read = TargetRead.of(locked, from, moment, game.world, game.query, now)
	else:
		read = {}
	rows = []
	for m in field:
		rows.append({
			"id": m.id,
			"name": TargetRead.words(m.kind),
			"machine": m.machine,
			"tag": TargetRead.tag(m, now),
			"thinking": TargetRead.thinking(m, now),
			"distance": m.pos.distance_to(from),
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
	var to := locked.pos - here
	cam.lean_yaw = LOCK_YAW * _yaw_share(to)
	cam.lean_pitch = LOCK_PITCH
	cam.lean_zoom = LOCK_ZOOM
	var at := Targeting.focus_between(here, locked.pos, LOCK_SHARE, LOCK_MOST)
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
		&"target_none":
			return locked == null and not sweeping and not game.camera.leaning()
	return false
