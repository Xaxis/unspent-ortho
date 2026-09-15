extends GameSystem
## Survival made visible, so taking reads without a word on screen:
## - while you work, chips come off the thing in time with the blows, coloured
##   by what it is (pale wood, grey stone with a rust or green fleck, wet wrack);
## - when it gives out, it goes the way that thing goes: a tree falls away from
##   you, rock bursts, reeds and driftwood lift toward your hands;
## - what you took leaves a mark while it is gone: a stump, rubble, cut stubble;
## - every fire burns: flames, embers, sparks, smoke drifting, and a pool of light.
## Reads SurvivalState and WorldData; writes nothing but its own nodes.

const CHIP_POOL := 128
const FIRE_RADIUS := 22.0
const REMNANT_RADIUS := 48.0
## Blows land at these fractions of Survival.WORK_SECONDS.
const BLOWS: Array[float] = [0.28, 0.62, 0.94]

const TREES: Array[int] = [PropKind.PINE, PropKind.SNOW_PINE, PropKind.BROADLEAF, PropKind.DEAD_TREE]
const ROCKS: Array[int] = [PropKind.BOULDER, PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.COPPER_ORE,
	PropKind.COAL_ORE, PropKind.TIN_ORE, PropKind.CLINTS, PropKind.RUIN]
const SCRAP: Array[int] = [PropKind.TIP, PropKind.WRECK, PropKind.POLE, PropKind.PYLON]

var _mat: ShaderMaterial
var _chips: MultiMesh
var _chip: Array[Dictionary] = []
var _next_chip := 0
var _job_prop: WorldProp = null
var _job_t := 0.0
var _blow := 0
var _anims: Array[Dictionary] = []
var _remnant_mm: Dictionary = {} # StringName -> MultiMesh
var _remnant_sig := ""
var _remnant_at := Vector2(-1e9, -1e9)
var _fires: Dictionary = {} # prop id -> FireModel
var _scan_in := 0.0
var _time := 0.0


func setup(g: Game) -> void:
	super.setup(g)
	_mat = g.view.world_material() if g.view != null else ShaderMaterial.new()
	_build_chips()
	_build_remnant_layers()


# --- Per frame ----------------------------------------------------------------

func _process(delta: float) -> void:
	if game == null:
		return
	_time += delta
	_follow_job(delta)
	_step_chips(delta)
	_step_anims(delta)
	_scan_in -= delta
	if _scan_in <= 0.0:
		_scan_in = 0.5
		_scan_fires()
		_refresh_remnants()


func _follow_job(delta: float) -> void:
	var job := SurvivalState.of(game).job
	var prop: WorldProp = job.get("prop", null)
	if prop != _job_prop:
		if _job_prop != null and game.world.depleted.has(_job_prop.id):
			_give_out(_job_prop)
		_job_prop = prop
		_job_t = 0.0
		_blow = 0
	if prop == null:
		return
	_job_t += delta
	var verb: StringName = job.option.verb
	while _blow < BLOWS.size() and _job_t >= BLOWS[_blow] * Survival.WORK_SECONDS:
		_blow += 1
		_strike(prop, verb)


# --- Chips --------------------------------------------------------------------

func _build_chips() -> void:
	var k := MeshKit.new()
	k.block(0, -0.05, 0, 0.13, 0.1, 0.09, Color.WHITE)
	_chips = MultiMesh.new()
	_chips.transform_format = MultiMesh.TRANSFORM_3D
	_chips.use_colors = true
	_chips.mesh = k.build()
	_chips.instance_count = CHIP_POOL
	for i in CHIP_POOL:
		_chip.append({"life": 0.0})
		_chips.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "chips"
	mmi.multimesh = _chips
	mmi.material_override = _mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 16384.0
	add_child(mmi)


func _chip_colors(kind: int, verb: StringName) -> Array[Color]:
	if TREES.has(kind):
		if verb == &"tap":
			return [Palette.COPPER[4], Palette.COPPER[3]]
		return [Palette.SAND[5], Palette.EARTH[2], Palette.EARTH[4], Palette.SAND[4]]
	match kind:
		PropKind.IRON_ORE:
			return [Palette.STONE[3], Palette.RUST[3], Palette.RUST[4], Palette.STONE[4]]
		PropKind.COPPER_ORE:
			return [Palette.STONE[3], Palette.SPRUCE[4], Palette.SPRUCE[5], Palette.STONE[4]]
		PropKind.COAL_ORE:
			return [Palette.INK[3], Palette.INK[4], Palette.STONE[2]]
		PropKind.TIN_ORE:
			return [Palette.STONE[4], Palette.STONE[5], Palette.ASH[4]]
		PropKind.CLINTS:
			return [Palette.LINEN[5], Palette.LINEN[4], Palette.STONE[4]]
		PropKind.DRIFTWOOD:
			return [Palette.SAND[4], Palette.LINEN[4], Palette.SAND[3]]
		PropKind.WRACK:
			return [Palette.MOSS[2], Palette.EARTH[3], Palette.MOSS[3]]
		PropKind.MUSSEL_ROCK:
			return [Palette.BRINE[5], Palette.BRINE[4], Palette.INK[4]]
		PropKind.PEAT_BANK:
			return [Palette.EARTH[1], Palette.EARTH[2], Palette.EARTH[0]]
		PropKind.VENT:
			return [Palette.COPPER[4], Palette.ASH[3], Palette.COPPER[3]]
		PropKind.GORSE:
			return [Palette.MOSS[3], Palette.COPPER[4], Palette.MOSS[2]]
	if ROCKS.has(kind):
		return [Palette.STONE[3], Palette.STONE[4], Palette.SLATE[3]]
	if SCRAP.has(kind):
		return [Palette.PLATE[3], Palette.RUST[3], Palette.STONE[2], Palette.PLATE[4]]
	return [Palette.MOSS[4], Palette.MOSS[3], Palette.SAND[4]]


## Where a blow meets the thing: its near side, at a height that suits it.
func _contact(prop: WorldProp) -> Vector3:
	var p := game.player.pos
	var to := (prop.pos - p)
	var dir := to.normalized() if to.length() > 0.01 else Vector2.RIGHT
	var edge := prop.pos - dir * prop.solid * 0.9
	var h := 0.12
	if TREES.has(prop.kind):
		h = 0.45
	elif ROCKS.has(prop.kind) or SCRAP.has(prop.kind):
		h = 0.3 * prop.scale
	return game.world.to_3d(edge) + Vector3(0, h, 0)


func _strike(prop: WorldProp, verb: StringName) -> void:
	var colors := _chip_colors(prop.kind, verb)
	var at := _contact(prop)
	var away := game.world.to_3d(game.player.pos).direction_to(game.world.to_3d(prop.pos))
	away.y = 0.0
	var n := 8
	if verb == &"gather" or verb == &"turn" or verb == &"scrape":
		n = 3
	elif verb == &"tap":
		n = 2
	var seed_i := prop.id * 7 + _blow * 131 + int(_time * 60.0)
	for i in n:
		var spread := Vector3(Rng.hash01(seed_i, i, 1) - 0.5, 0.0, Rng.hash01(seed_i, i, 2) - 0.5) * 2.2
		# Chips fly back toward the worker and up; a tap only drips.
		var vel: Vector3 = (-away * (0.6 + Rng.hash01(seed_i, i, 3) * 1.4) + spread) * (0.25 if verb == &"tap" else 1.0)
		vel.y = 0.2 if verb == &"tap" else 1.6 + Rng.hash01(seed_i, i, 4) * 1.8
		_emit_chip(at, vel, colors[i % colors.size()], 0.5 + Rng.hash01(seed_i, i, 5) * 0.5, 0.7 + Rng.hash01(seed_i, i, 6) * 0.8)
	# A blow to a trunk shakes needles or leaves out of the crown; they come down slowly.
	if verb == &"fell":
		var crown := Palette.RIME[5] if prop.kind == PropKind.SNOW_PINE else (Palette.ASH[2] if prop.kind == PropKind.DEAD_TREE else Palette.SPRUCE[3])
		for i in 5:
			var off := Vector3(Rng.hash01(seed_i, i, 21) - 0.5, 0.0, Rng.hash01(seed_i, i, 22) - 0.5) * 0.9 * prop.scale
			var top := game.world.to_3d(prop.pos) + off + Vector3(0, (1.0 + Rng.hash01(seed_i, i, 23) * 0.9) * prop.scale, 0)
			_emit_chip(top, Vector3(off.x, 0.6, off.z), crown if i % 2 else Palette.SPRUCE[4], 1.1, 0.8, 0.9)
	# Iron on stone or plate strikes a spark.
	if verb == &"break" and (ROCKS.has(prop.kind) or SCRAP.has(prop.kind)):
		_emit_chip(at + Vector3(0, 0.05, 0), Vector3(-away.x, 2.4, -away.z), Palette.EMBER[5], 0.25, 0.5)


## drag 0..1: how much less a chip falls (needles drift, stone drops).
func _emit_chip(at: Vector3, vel: Vector3, col: Color, life: float, size: float, drag: float = 0.0) -> void:
	var i := _next_chip
	_next_chip = (_next_chip + 1) % CHIP_POOL
	_chip[i] = {"life": life, "max": life, "pos": at, "vel": vel, "size": size, "spin": Rng.hash01(i, int(_time * 100.0)) * TAU,
		"drag": drag}
	_chips.set_instance_color(i, col)


func _step_chips(delta: float) -> void:
	for i in CHIP_POOL:
		var c := _chip[i]
		if float(c.life) <= 0.0:
			continue
		c.life = float(c.life) - delta
		var vel: Vector3 = c.vel
		var drag: float = c.drag
		vel.y -= 9.0 * (1.0 - drag) * delta
		if drag > 0.0:
			vel.y = maxf(vel.y, -0.9)
			vel.x += sin(float(c.spin) * 1.3) * delta * 0.8
		var pos: Vector3 = c.pos + vel * delta
		var ground := game.world.height_at(Vector2(pos.x, pos.z)) + 0.03
		if pos.y < ground:
			pos.y = ground
			vel = Vector3(vel.x * 0.3, absf(vel.y) * 0.25, vel.z * 0.3)
		c.vel = vel
		c.pos = pos
		c.spin = float(c.spin) + delta * 9.0
		var s: float = c.size * clampf(float(c.life) / (float(c.max) * 0.35), 0.0, 1.0)
		if float(c.life) <= 0.0:
			s = 0.0
		var b := Basis(Vector3(0.3, 1.0, 0.2).normalized(), c.spin).scaled(Vector3.ONE * s)
		_chips.set_instance_transform(i, Transform3D(b, pos))


# --- Giving out: the thing goes the way that thing goes -----------------------

func _give_out(prop: WorldProp) -> void:
	var node := MeshInstance3D.new()
	node.mesh = PropModels.mesh(prop.kind)
	node.material_override = _mat
	var pivot := Node3D.new()
	pivot.position = game.world.to_3d(prop.pos)
	pivot.add_child(node)
	node.rotation.y = prop.rot
	node.scale = Vector3.ONE * prop.scale
	add_child(pivot)
	var away := prop.pos - game.player.pos
	away = away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	var kind := &"lift"
	if TREES.has(prop.kind):
		kind = &"fall"
	elif ROCKS.has(prop.kind) or SCRAP.has(prop.kind) or prop.kind == PropKind.PEAT_BANK:
		kind = &"burst"
		var colors := _chip_colors(prop.kind, &"break")
		var at := game.world.to_3d(prop.pos) + Vector3(0, 0.25 * prop.scale, 0)
		for i in 14:
			var a := Rng.hash01(prop.id, i, 1) * TAU
			var v := Vector3(cos(a), 0.0, sin(a)) * (0.6 + Rng.hash01(prop.id, i, 2) * 1.6)
			v.y = 1.2 + Rng.hash01(prop.id, i, 3) * 2.4
			_emit_chip(at, v, colors[i % colors.size()], 0.7 + Rng.hash01(prop.id, i, 4) * 0.6, 1.0 + Rng.hash01(prop.id, i, 5) * 1.2)
	_anims.append({"pivot": pivot, "t": 0.0, "kind": kind, "away": away, "prop": prop, "landed": false})


func _step_anims(delta: float) -> void:
	for i in range(_anims.size() - 1, -1, -1):
		var a := _anims[i]
		a.t = float(a.t) + delta
		var t: float = a.t
		var pivot: Node3D = a.pivot
		var done := false
		match a.kind:
			&"fall":
				# Tip slowly, then fast, as a tree does; lie a moment; settle into the ground.
				var away: Vector2 = a.away
				var axis := Vector3.UP.cross(Vector3(away.x, 0.0, away.y)).normalized()
				var f := clampf(t / 0.7, 0.0, 1.0)
				pivot.basis = Basis(axis, f * f * (PI * 0.5 - 0.08))
				if f >= 1.0 and not a.landed:
					a.landed = true
					_land_burst(a.prop, away)
				if t > 1.3:
					var sink := clampf((t - 1.3) / 0.5, 0.0, 1.0)
					pivot.scale = Vector3.ONE * (1.0 - sink)
					pivot.position.y -= delta * 0.4
				done = t > 1.8
			&"burst":
				var k := clampf(t / 0.18, 0.0, 1.0)
				pivot.scale = Vector3(1.0 + k * 0.15, 1.0 - k, 1.0 + k * 0.15)
				done = t > 0.18
			_:
				var k := clampf(t / 0.35, 0.0, 1.0)
				var toward := game.world.to_3d(game.player.pos) + Vector3(0, 0.7, 0)
				var from := game.world.to_3d((a.prop as WorldProp).pos)
				pivot.position = from.lerp(toward, k * k) + Vector3(0, sin(k * PI) * 0.35, 0)
				pivot.scale = Vector3.ONE * (1.0 - k * 0.9)
				done = t > 0.35
		if done:
			pivot.queue_free()
			_anims.remove_at(i)


func _land_burst(prop: WorldProp, away: Vector2) -> void:
	var colors: Array[Color] = [Palette.SPRUCE[3], Palette.SPRUCE[2], Palette.SAND[4], Palette.LINEN[4]]
	if prop.kind == PropKind.SNOW_PINE:
		colors = [Palette.RIME[5], Palette.RIME[4], Palette.SPRUCE[3]]
	elif prop.kind == PropKind.DEAD_TREE:
		colors = [Palette.ASH[3], Palette.ASH[2], Palette.SAND[4]]
	var top := game.world.to_3d(prop.pos + away * 1.6 * prop.scale)
	for i in 12:
		var v := Vector3(Rng.hash01(prop.id, i, 11) - 0.5, 0.0, Rng.hash01(prop.id, i, 12) - 0.5) * 2.4
		v.y = 0.8 + Rng.hash01(prop.id, i, 13) * 1.4
		var along := away * (Rng.hash01(prop.id, i, 14) * 2.0 - 0.3) * prop.scale
		_emit_chip(top + Vector3(along.x, 0.15, along.y), v, colors[i % colors.size()], 0.6 + Rng.hash01(prop.id, i, 15) * 0.5, 1.0 + Rng.hash01(prop.id, i, 16))


# --- Remnants: what taking leaves behind ---------------------------------------

func _build_remnant_layers() -> void:
	for name in RemnantModels.NAMES:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = RemnantModels.mesh(name)
		mm.instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "remnant_%s" % name
		mmi.multimesh = mm
		mmi.material_override = _mat
		add_child(mmi)
		_remnant_mm[name] = mm


func _refresh_remnants() -> void:
	var w := game.world
	var here := game.player.pos
	var sig := "%d:%d" % [w.depleted.size(), w.props.size()]
	if sig == _remnant_sig and here.distance_to(_remnant_at) < 12.0:
		return
	_remnant_sig = sig
	_remnant_at = here
	var lists := {}
	for name: StringName in _remnant_mm:
		lists[name] = []
	for id: int in w.depleted:
		if id < 0 or id >= w.props.size():
			continue
		var p := w.props[id]
		var r := RemnantModels.for_kind(p.kind)
		if r == &"" or p.pos.distance_to(here) > REMNANT_RADIUS:
			continue
		lists[r].append(p)
	for name: StringName in lists:
		var mm: MultiMesh = _remnant_mm[name]
		var list: Array = lists[name]
		mm.instance_count = list.size()
		for j in list.size():
			var p: WorldProp = list[j]
			var s := p.scale * (1.3 if p.kind == PropKind.BROADLEAF else 1.0)
			mm.set_instance_transform(j, Transform3D(Basis(Vector3.UP, p.rot).scaled(Vector3.ONE * s), w.to_3d(p.pos)))
			var tint := Color.WHITE
			match p.kind:
				PropKind.IRON_ORE:
					tint = Color(1.0, 0.84, 0.78)
				PropKind.COPPER_ORE:
					tint = Color(0.86, 1.0, 0.92)
				PropKind.COAL_ORE:
					tint = Color(0.6, 0.6, 0.68)
				PropKind.DEAD_TREE:
					tint = Color(0.8, 0.82, 0.88)
			var k := 0.92 + Rng.hash01(w.seed_value, p.id, 91) * 0.16
			mm.set_instance_color(j, Color(tint.r * k, tint.g * k, tint.b * k))


# --- Fires -----------------------------------------------------------------------

func _scan_fires() -> void:
	var here := game.player.pos
	var seen := {}
	for q in game.query.props_near(here, FIRE_RADIUS):
		if q.kind != PropKind.FIRE or game.world.depleted.has(q.id):
			continue
		seen[q.id] = true
		if not _fires.has(q.id):
			var f := FireModel.new()
			f.name = "fire_%d" % q.id
			f.position = game.world.to_3d(q.pos)
			add_child(f)
			f.build(_mat, q.id)
			_fires[q.id] = f
	for id: int in _fires.keys():
		if not seen.has(id):
			(_fires[id] as Node3D).queue_free()
			_fires.erase(id)
	var dark := FireModel.darkness_at(game.clock.hour())
	for id: int in _fires:
		(_fires[id] as FireModel).darkness = dark
