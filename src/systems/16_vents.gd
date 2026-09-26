extends GameSystem
## The Burning breathes: every vent near the player lets out a slow puff of pale
## steam and ash every few seconds, each on its own beat (docs/LOOK.md section 3,
## "vents breathing"). Their light breathes too, in 15_lights.

## Tiles round the player whose vents are drawn breathing.
const REACH := 20.0
## Seconds between breaths, before each vent's own stretch.
const BREATH := 3.2

var _t := 0.0
var _scan := 0.0
var _vents: Array[WorldProp] = []
var _layer: Node3D
## THE PUFFS ARE POOLED, IN ONE DRAW. Seen close, every breath was eight new
## nodes, materials and tweens over seventy vents in reach (about 0.9 ms a frame
## in the sulphur jungle, all churn). Every puff is now an instance of one
## MultiMesh: a breath writes each puff's whole life into the next instance of
## a fixed ring once, and plume.gdshader runs it against `plume_now`.
var _puffs: MultiMeshInstance3D
var _next_puff := 0


func setup(g: Game) -> void:
	super.setup(g)
	_layer = Node3D.new()
	_layer.name = "vent_breath"
	g.add_child(_layer)


func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	RenderingServer.global_shader_parameter_set("plume_now", _t)
	_scan -= delta
	if _scan <= 0.0:
		_scan = 1.0
		_vents.clear()
		for q in game.query.props_near(game.player.pos, REACH):
			if game.world.depleted.has(q.id):
				continue
			# A capped vent leaks only where the land says its vents breathe hard.
			if q.kind == PropKind.VENT or (q.kind == PropKind.VENT_CAP and BiomeRegistry.at(game.world, q.pos).vent_breath.a > 1.0):
				_vents.append(q)
	if _vents.is_empty():
		_t += delta
		return
	var before := _t
	_t += delta
	var wind := Vector2(0.35, -0.2)
	for v in _vents:
		var h := Rng.hash01(game.world.seed_value, v.id, 0x7E47)
		# The land's own breath (BiomeDef.vent_breath): its colour, and how big
		# and how often. Unset is the Burning's slow ash.
		var own := BiomeRegistry.at(game.world, v.pos).vent_breath
		var much := own.a if own.a > 0.0 else 1.0
		var col := Color(own.r, own.g, own.b) if own.a > 0.0 else Palette.ASH[4]
		var period := BREATH * (0.75 + 0.6 * h) / sqrt(much)
		var offset := h * period
		if floorf((before + offset) / period) == floorf((_t + offset) / period):
			continue
		var at := game.world.to_3d(v.pos) + Vector3(0, 0.55 * v.scale, 0)
		# A land that says what its vents breathe gets exactly that colour; the
		# Burning's ash is its own grey, barely lifted: a white plume lit by the vent
		# from below read as cotton wool.
		var size := (0.5 + 0.25 * h) * much
		var seconds := (2.2 + h) * sqrt(much)
		var lighten := 0.0 if own.a > 0.0 else 0.15
		if MobFx.close_eye(_layer):
			_plume_pooled(at, col.lightened(lighten), size, seconds, wind * (0.6 + h), v.id * 31 + int(_t))
		else:
			_plume(at, col, size, seconds, wind * (0.6 + h), v.id * 31 + int(_t), lighten)


## How many puffs one breath is laid as, from the vent's mouth up.
## Enough, and wide enough against their spacing, that neighbours overlap and
## the soft puffs read as one column.
const PLUME := 8


## A breath as a PLUME, not a ball: a column of puffs laid at once from a
## narrow mouth up, each higher one wider, fainter-lived and further
## downwind, so the whole leans and shears with the wind and breaks up at
## its top into wisps set off to either side. One soft ball per breath read as
## a string of cotton wool over every vent. `size` is the breath's width at
## its widest.
func _plume(at: Vector3, col: Color, size: float, seconds: float, drift: Vector2, seed_value: int, lighten: float) -> void:
	for i in PLUME:
		var f := float(i) / float(PLUME - 1)
		var rise := size * (0.15 + f * 1.6)
		var shear := drift * f * f * 1.4
		# The top breaks into wisps: offset across the wind, one side or the other.
		var side := (Rng.hash01(seed_value, i, 3) - 0.5) * size * 0.9 * f
		var across := Vector2(-drift.y, drift.x).normalized() * side
		var p := at + Vector3(shear.x + across.x, rise, shear.y + across.y)
		var w := size * lerpf(0.45, 1.25, f)
		# A land's own colour is passed through unwhitened: a white plume lit red
		# from below and blue from the night sky came out pink.
		MobFx.breath(_layer, p, col, w, seconds * lerpf(0.55, 1.1, f), drift * lerpf(0.5, 1.6, f), seed_value * 11 + i, lighten)


## The ring of puffs every vent in reach shares: at most this many alive at once.
## Seventy vents breathing every three seconds or so, eight puffs a breath each
## living up to six: about 1100 at the very worst, and the oldest are the ones
## the ring takes back first.
const PUFFS := 1024


## The same plume as `_plume`, laid on the shared puffs.
func _plume_pooled(at: Vector3, col: Color, size: float, seconds: float, drift: Vector2, seed_value: int) -> void:
	if _puffs == null:
		_make_puffs()
	var mm := _puffs.multimesh
	for i in PLUME:
		var f := float(i) / float(PLUME - 1)
		var rise := size * (0.15 + f * 1.6)
		var shear := drift * f * f * 1.4
		var side := (Rng.hash01(seed_value, i, 3) - 0.5) * size * 0.9 * f
		var across := Vector2(-drift.y, drift.x).normalized() * side
		var p := at + Vector3(shear.x + across.x, rise, shear.y + across.y)
		var w := size * lerpf(0.45, 1.25, f)
		var life := seconds * lerpf(0.55, 1.1, f)
		var d := drift * lerpf(0.5, 1.6, f)
		var turn := Rng.hash01(seed_value * 11 + i, 3) * 0.3
		var born := w * (0.55 + turn)
		var basis := Basis(Vector3(born, 0.0, 0.0), Vector3(d.x, w * 0.6, d.y), Vector3(0.0, 0.0, 1.0))
		mm.set_instance_transform(_next_puff, Transform3D(basis, p))
		mm.set_instance_color(_next_puff, Color(col.r, col.g, col.b, Rng.hash01(seed_value * 11 + i, 5)))
		mm.set_instance_custom_data(_next_puff, Color(_t, life, (1.4 + turn) / (0.55 + turn), 0.5))
		_next_puff = (_next_puff + 1) % PUFFS


func _make_puffs() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = MobFx.PLUME_SHADER
	mat.render_priority = 11
	mat.set_shader_parameter("pooled", true)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = FireModel.smoke_mesh()
	mm.instance_count = PUFFS
	for i in PUFFS:
		mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
	_puffs = MultiMeshInstance3D.new()
	_puffs.name = "puffs"
	_puffs.multimesh = mm
	_puffs.material_override = mat
	_puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The puffs are placed by the shader, anywhere in reach of the player.
	_puffs.custom_aabb = AABB(Vector3(-4096, -64, -4096), Vector3(8192, 256, 8192))
	_layer.add_child(_puffs)
