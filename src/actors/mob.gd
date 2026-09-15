class_name Mob
extends Node3D
## A machine or creature in the world: draws a MobState (which FightSim steps)
## with a FigureModel. Contract for everyone else: joins group &"mobs" and
## exposes `kind`, `pos` (tile space) and `alive`.
##
## The body telegraphs so a player can learn it: the alert pose when it
## notices you, the windup pose (and a lean back) through a bite's tell, the
## strike with a lean in; the working part goes dark when it is hurt and
## flares only when a blow reached it.

var kind: StringName = &""
var pos := Vector2.ZERO
var alive := true
var state: MobState
var model: FigureModel
## Carries the lean and the heave; the model sits on it facing +X.
var pivot: Node3D
var _mat: ShaderMaterial
var _z := 0.0
## Real-time msec until which a hit flash shows (real time, so a held shot still lets it go).
var _flash_until := 0
var _world: WorldData
var _was_lit := true
var _placeholder := false
var _holding := false


func setup(s: MobState, world: WorldData, base_material: Material) -> void:
	state = s
	s.node = self
	_world = world
	kind = s.kind
	pos = s.pos
	name = "mob_%s_%d" % [String(kind).replace(".", "_"), s.id]
	add_to_group(&"mobs")
	if base_material is ShaderMaterial:
		_mat = (base_material as ShaderMaterial).duplicate() as ShaderMaterial
	pivot = Node3D.new()
	pivot.name = "pivot"
	add_child(pivot)
	model = FigureModel.create(s.row.get("model", kind), _mat)
	pivot.add_child(model)
	_placeholder = model.get_script() == FigureModel
	if _placeholder:
		# The machines package's figure is not here yet: size the stand-in to the body so a fight still reads.
		var r: float = s.radius
		var h: float = s.row.get("height", 1.0)
		model.scale = Vector3(r * 2.2 / 0.8, h, r * 2.2 / 0.8)
	_z = world.height_at(s.pos)
	sync_view(0.0, 0.0)


## Draw the state at simulation time `now_ms`. delta 0 holds the pose (hitstop).
## `holding`: this body has hold of the player.
func sync_view(delta: float, now_ms: float, holding: bool = false) -> void:
	var s := state
	_holding = holding
	pos = s.pos
	alive = s.alive
	var ground := _world.height_at(s.pos)
	_z = ground if delta == 0.0 else lerpf(_z, ground, 1.0 - exp(-12.0 * delta))
	position = Vector3(s.pos.x, _z, s.pos.y)
	model.rotation.y = -s.facing
	var p := _pose(now_ms)
	if p != model.pose:
		model.set_pose(p)
	var lit := s.alive and now_ms >= s.dark_until
	if lit != _was_lit:
		model.set_part_lit(lit)
		_was_lit = lit
	_lean(now_ms, delta)
	if delta > 0.0:
		model.animate(delta, s.speed)
	if _mat != null:
		_mat.set_shader_parameter(&"emission_strength", 0.45 if Time.get_ticks_msec() < _flash_until else 0.0)


func _pose(now_ms: float) -> StringName:
	var s := state
	if not s.alive:
		return &"dead"
	if _holding:
		return &"strike"
	var phase := s.blow_phase(now_ms)
	if phase == &"windup":
		return &"windup"
	if phase == &"active" or phase == &"recovery":
		return &"strike"
	if s.node != null and now_ms < s.dark_until:
		return &"hurt"
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
	if not s.alive:
		target_rise = -0.08
	var rate := 1.0 if delta == 0.0 else 1.0 - exp(-30.0 * delta)
	var fwd := Vector3(cos(s.facing), 0.0, sin(s.facing))
	pivot.position = pivot.position.lerp(fwd * target_push + Vector3(0, target_rise, 0), rate)
	# Tilt about the body's own right axis: positive leans the front down.
	var right := Vector3(-sin(s.facing), 0.0, cos(s.facing))
	pivot.basis = pivot.basis.slerp(Basis(right, -target_tilt), rate)


func flash(seconds: float = 0.06) -> void:
	_flash_until = Time.get_ticks_msec() + int(seconds * 1000.0)


func flare() -> void:
	model.flare_part()
