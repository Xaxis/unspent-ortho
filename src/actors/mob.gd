class_name Mob
extends Node3D
## A machine or creature in the world: draws a MobState (which FightSim steps)
## with a FigureModel. Contract for everyone else: joins group &"mobs" and
## exposes `kind`, `pos` (tile space), `alive`, `hostile` (false for things
## that only pester, like gulls, so the slate keeps its hints near them) and
## `aware` (it has noticed the player: alerted, chasing or attacking).
##
## The body telegraphs so a player can learn it: the alert pose when it
## notices you, the windup pose (and a lean back) through a bite's tell, the
## strike with a lean in. A blow that reached the working part flares it first,
## while it is still lit, and only then does it go dark and the body take the
## hurt pose: a figure draws no flare on a part that is out.

## An opening older than this when first drawn is not flared (a view catching up).
const OPEN_FLARE_MS := 200.0
## A machine making up its mind (MobState.suspicion) says so on its own body:
## the working part catches, slowly at the first stir and fast when it is
## nearly sure, and the body stands and looks where the noise came from. Never
## a word on screen (docs/VISION.md).
const SUSPECT_SLOW_MS := 560.0
const SUSPECT_FAST_MS := 130.0
const SUSPECT_FLOOR := 0.05
## A body that is killed folds down flat and over onto its side in this long, so
## from the camera above a dead machine never stands as it did alive.
const FOLD_MS := 300.0
const FOLD_ROLL := 0.55
const FOLD_FLAT := 0.4
const FOLD_SINK := 0.12

var kind: StringName = &""
var pos := Vector2.ZERO
var alive := true
var hostile := true
## Noticed the player: alerted, chasing or attacking (the score tenses for it).
var aware := false
var state: MobState
var model: FigureModel
## Carries the lean and the heave; the model sits on it facing +X.
var pivot: Node3D
var _z := 0.0
## Real-time msec until which a hit flash shows (real time, so a held shot still lets it go).
var _flash_until := 0
## Where in the world the blow landed, for a flash that is only the struck part.
var _flash_at := Vector3.ZERO
var _world: WorldData
var _was_lit := true
var _wake_in := 0.0
var _holding := false
var _flashing := false
## The lean kept as a quaternion: slerping the node's basis frame after frame
## drifts it off orthonormal, which the engine then refuses to read back.
var _tilt := Quaternion.IDENTITY
## The flare_until this view has already flared the part for.
var _flared_for := 0.0
## What the figure was last told about running something down: -1 nothing yet.
var _hunting := -1
## The opening (MobState.opened_at) this view has already flared the part for.
var _opened_for := -INF
## Sim ms at which the suspicion flicker next catches.
var _suspect_at := -INF


## `figure`: a body to draw with instead of FigureModel.create (tests).
func setup(s: MobState, world: WorldData, base_material: Material, figure: FigureModel = null) -> void:
	state = s
	s.node = self
	_world = world
	kind = s.kind
	pos = s.pos
	hostile = s.row.get("hostile", true)
	name = "mob_%s_%d" % [String(kind).replace(".", "_"), s.id]
	add_to_group(&"mobs")
	pivot = Node3D.new()
	pivot.name = "pivot"
	add_child(pivot)
	var model_kind: StringName = s.row.get("model", kind)
	if figure != null:
		model = figure
	elif s.row.get("machine", true):
		# On the side the landscape's own kind has it (BiomeDef.roster `over`).
		model = FigureModel.create(model_kind, base_material, s.part)
	else:
		# Animals are the hand's shapes varied by seed: no two yard dogs alike.
		model = AnimalModel.spawn(model_kind, base_material, Rng.hash_ints(world.seed_value, s.id, 0xA11))
	pivot.add_child(model)
	# A standing or walking machine is drawn at POSE_HZ, staggered by body so ten
	# of them do not all pose on one frame; its tells, strikes, hurts and death
	# every frame (MachineModel.pose_hz).
	if model is MachineModel:
		(model as MachineModel).pose_hz = POSE_HZ
		(model as MachineModel)._step_left = fposmod(float(s.id) * 0.37, 1.0) / POSE_HZ
	_z = world.height_at(s.pos)
	sync_view(0.0, 0.0)


## Poses a second a machine stands or walks at in a running game: half the
## screen's, which a machine's exact servo motion carries without a stutter, and
## half the cost of ten of them (measured 1.3 ms a frame posed every frame).
const POSE_HZ := 30.0
## How high a dropping body hops off its ledge before it falls, world units.
const DROP_HOP := 0.5


## Draw the state at simulation time `now_ms`. delta 0 holds the pose (hitstop).
## `holding`: this body has hold of the player.
func sync_view(delta: float, now_ms: float, holding: bool = false) -> void:
	var s := state
	_holding = holding
	pos = s.pos
	alive = s.alive
	aware = s.alive and (s.mood == MobState.ALERTED or s.mood == MobState.CHASING or s.mood == MobState.ATTACKING)
	# The machine's eyes lock on a hunt, not on an errand that only walks near.
	var hunting := s.alive and s.approach != &"errand" and (s.mood == MobState.CHASING or s.mood == MobState.ATTACKING)
	if int(hunting) != _hunting:
		_hunting = int(hunting)
		model.set_hunting(hunting)
	# A body still at its round is not a threat to hush the notebook for, whether
	# it is working calmly or watching the player hard (MobState.at_work).
	hostile = bool(s.row.get("hostile", true)) and not (s.at_work() and not s.roused())
	# In water over its head it floats at the surface, not on the bed below it
	# (Swim): the bed under deep water is the zero plane and the sheet is drawn
	# above it, so a body left on the ground there is a body under the sea.
	var swimming := Swim.swims(s.row) and Swim.deep(_world, s.pos)
	var ground := _world.height_at(s.pos) + (Swim.WATER_Y - Swim.sink_of(s.row) if swimming else 0.0)
	var fall := s.drop_fall(now_ms)
	if fall >= 0.0 and fall < 1.0:
		# Through the air (Brains `drop`): off the ledge's height with a hop, and
		# down onto where it lands falling faster as it goes.
		_z = lerpf(_world.height_at(s.drop_from), _world.height_at(s.drop_at), fall * fall) + DROP_HOP * 4.0 * fall * (1.0 - fall)
	else:
		_z = ground if delta == 0.0 else lerpf(_z, ground, 1.0 - exp(-12.0 * delta))
	position = Vector3(s.pos.x, _z, s.pos.y)
	_wake(delta, swimming)
	model.rotation.y = -s.facing
	var p := _pose(now_ms)
	if p != model.pose:
		if p == &"windup" and s.blow != null and model is MachineModel:
			(model as MachineModel).tell_s = s.blow.windup / 1000.0
		model.set_pose(p)
	# Asleep in a dock its optics are dark, beams and all, until it stirs: they
	# come on as it grows unsure, which is how a player sees one waking.
	var lit := s.alive and not s.part_dark(now_ms) and (not s.asleep or s.suspicion > SUSPECT_FLOOR)
	if lit != _was_lit:
		model.set_part_lit(lit)
		_was_lit = lit
	_lean(now_ms, delta)
	var flare := s.alive and s.part_flaring(now_ms) and s.flare_until != _flared_for
	if flare:
		_flared_for = s.flare_until
		model.flare_part()
	# Its bite spent and missed: the working part flares once, while it is still
	# lit and the body is in its strike, so the opening is seen and not only timed.
	var opened := s.alive and s.opened_at != _opened_for and now_ms - s.opened_at < OPEN_FLARE_MS and lit
	if opened:
		_opened_for = s.opened_at
		model.flare_part()
		flare = true
	if _suspecting(now_ms, lit):
		model.flare_part()
		flare = true
	if delta > 0.0:
		model.animate(delta, s.speed)
	elif flare:
		# Held in the hitstop: the flare still has to be on the part now.
		model.animate(0.0, 0.0)
	var flashing := Time.get_ticks_msec() < _flash_until
	if flashing != _flashing:
		_flashing = flashing
		# EVERY BODY FLASHES THROUGH ITS OWN MATERIAL, not only machines. A radius
		# of 0 is what sends `MobFx.set_flash` down the ink-era path — an unshaded
		# paper silhouette laid over the whole body — and a person or an animal
		# went down it for no reason anybody wrote down. Both lit shaders carry
		# `flash_at`/`flash_r` (world.gdshader for MADE, found.gdshader for FOUND),
		# so a struck villager now goes hot where it was hit and stays the material
		# it is. A machine still flashes by PART, which is the narrower thing and
		# the reason the point was being carried in the first place.
		var h := float(s.row.get("height", 1.0))
		var r := MobFx.flash_radius(h) if s.machine else maxf(h, MobFx.flash_radius(h))
		MobFx.set_flash(model, flashing, _flash_at, r)


## Is the working part due to catch again? A body that is sure of the player
## is past this: from then on it is the alert pose and the eyes that say so.
func _suspecting(now_ms: float, lit: bool) -> bool:
	var s := state
	if not (s.alive and s.machine and lit) or s.roused() or s.suspicion <= SUSPECT_FLOOR:
		_suspect_at = -INF
		return false
	if now_ms < _suspect_at:
		return false
	_suspect_at = now_ms + lerpf(SUSPECT_SLOW_MS, SUSPECT_FAST_MS, clampf(s.suspicion, 0.0, 1.0))
	return true


## Rings on the water off a body swimming, the same mark the player leaves: what
## says a thing is IN the water rather than drawn over it.
func _wake(delta: float, swimming: bool) -> void:
	if not swimming:
		_wake_in = 0.0
		return
	_wake_in -= delta
	if _wake_in > 0.0:
		return
	_wake_in = 0.62
	MobFx.ring(get_parent(), Vector3(state.pos.x, Swim.WATER_Y, state.pos.y),
		Palette.COLD[3], 0.5 + float(state.row.get("radius", 0.4)), 0.5)


func _pose(now_ms: float) -> StringName:
	var s := state
	if not s.alive:
		return &"dead"
	# Nothing strikes, stands or works while it is swimming: it is keeping its
	# head up, and a dog that came in after you is still coming.
	if Swim.swims(s.row) and Swim.deep(_world, s.pos):
		return &"swim"
	if _holding:
		return &"strike"
	var phase := s.blow_phase(now_ms)
	if phase == &"windup":
		return &"windup"
	if phase == &"active" or phase == &"recovery":
		return &"strike"
	if s.part_dark(now_ms):
		return &"hurt"
	if s.machine and s.spent(now_ms):
		# Winding back after a bite it missed: powered down, not on guard.
		return &"stand"
	if s.crowded_since >= 0.0 or (now_ms < s.glance_until and s.speed <= 0.2):
		# A worker held up by someone in its way, or one standing that looked up.
		return &"alert"
	if now_ms < s.look_until and s.speed <= 0.2:
		# It heard something: stopped, stood up and put its optics on it.
		return &"alert"
	match s.mood:
		MobState.ALERTED:
			return &"alert"
		MobState.ATTACKING:
			if s.speed > 0.2:
				return &"walk"
			return &"alert"
		MobState.CHASING, MobState.FLEEING:
			return &"walk" if s.speed > 0.2 else &"alert"
	return &"walk" if s.speed > 0.2 else &"stand"


## Leans back through a tell and in through the strike, along the facing. Errands
## never lunge (they are only nearer); the dead settle.
func _lean(now_ms: float, delta: float) -> void:
	var s := state
	var target_tilt := 0.0
	var target_push := 0.0
	var target_rise := 0.0
	if s.alive and _holding:
		# Hauling: jaw down, bearing back against the pull.
		var t := Time.get_ticks_msec() * 0.001
		target_tilt = 0.12 + sin(t * 9.0) * 0.03
		target_push = -0.05
	elif s.alive and s.approach != &"errand" and s.blow != null:
		var e := now_ms - s.blow_at
		var b := s.blow
		if e < b.windup:
			var k := e / maxf(1.0, b.windup)
			target_tilt = -0.16 * k
			target_push = -0.10 * k
			target_rise = 0.05 * k
		elif e < b.windup + b.active:
			target_tilt = 0.14
			target_push = 0.22
		elif e < b.committed():
			target_tilt = 0.05
			target_push = 0.08
	elif s.alive and s.mood == MobState.ALERTED:
		target_rise = 0.04
	var fwd := Vector3(cos(s.facing), 0.0, sin(s.facing))
	if not s.alive:
		_fold(now_ms, fwd)
		return
	var rate := 1.0 if delta == 0.0 else 1.0 - exp(-30.0 * delta)
	pivot.position = pivot.position.lerp(fwd * target_push + Vector3(0, target_rise, 0), rate)
	# Tilt about the body's own right axis: positive leans the front down.
	var right := Vector3(-sin(s.facing), 0.0, cos(s.facing))
	_tilt = _tilt.slerp(Quaternion(right, -target_tilt), rate).normalized()
	pivot.quaternion = _tilt


## Dead: over onto its side and flat to the ground, eased out over FOLD_MS from
## the moment it died. Set outright (not eased frame to frame), so a held shot
## and a slow frame both show where the fold is.
func _fold(now_ms: float, fwd: Vector3) -> void:
	var k := folded(now_ms)
	pivot.position = Vector3(0, -FOLD_SINK * k, 0)
	_tilt = Quaternion(fwd, FOLD_ROLL * k)
	pivot.quaternion = _tilt
	pivot.scale = Vector3(1.0 + 0.1 * k, lerpf(1.0, FOLD_FLAT, k), 1.0 + 0.1 * k)


## How far a dead body has folded, 0..1 (0 while alive).
func folded(now_ms: float) -> float:
	if state == null or state.alive:
		return 0.0
	var t := clampf((now_ms - state.dead_at) / FOLD_MS, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t)


## A blow landed on this body: paper-white, for `seconds`.
##
## A MACHINE whitens only round its WORKING PART (the sphere in found.gdshader,
## which leaves the lit part itself alone): it is the one body big enough that
## flashing it whole hides what the player needs to see — its violet, its wear
## and the amber part they are aiming at. That is where every blow on a machine
## is aimed and where its hit mark is drawn, so the white, the mark and the
## thing struck are all one place. A dog or a person is a few pixels across and
## flashes whole, as it always has.
func flash(seconds: float = 0.06) -> void:
	_flash_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	_flash_at = part_position()


## The point of the drawn body highest on screen (`up`: the camera's up), so a
## mark can stand clear of the whole silhouette, a long body's far end included.
## The figure says where its posed body reaches (FigureModel.top_toward: a
## machine reads its bones as posed, a raised mast included); never lower than
## the roster's height.
func screen_top(up: Vector3) -> Vector3:
	var best := global_position + Vector3(0, float(state.row.get("height", 1.0)), 0)
	var top := model.top_toward(up)
	return top if top.dot(up) > best.dot(up) else best


## Where the working part is in the world (the body's middle when it has none,
## or when the figure cannot say).
func part_position() -> Vector3:
	if model.has_method(&"part_position"):
		return model.call(&"part_position")
	return global_position + Vector3(0, float(state.row.get("height", 1.0)) * 0.5, 0)
