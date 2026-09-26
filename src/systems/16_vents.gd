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
## Seconds to the next beat of each geyser that is going (vent id -> seconds).
var _geyser_gap: Dictionary = {}


## Where a tour can be stood by name (98_tour `near NAME`): `geyser`, four tiles
## off the nearest geyser in reach, with the clock put a moment before its next
## warning so the frame that follows sees it go up.
const TOUR_PLACES: Array[String] = ["geyser"]
var _face := NAN


func tour_place(what: String) -> Vector2:
	if what != "geyser" or game == null or game.player == null:
		return Vector2.INF
	var best: WorldProp = null
	for q in game.query.props_near(game.player.pos, 60.0):
		if q.kind != PropKind.VENT:
			continue
		var row := BiomeRegistry.at(game.world, q.pos).geysers
		if not Geysers.is_geyser(row, game.world.seed_value, q.id):
			continue
		if best == null or q.pos.distance_to(game.player.pos) < best.pos.distance_to(game.player.pos):
			best = q
	if best == null:
		return Vector2.INF
	var row := BiomeRegistry.at(game.world, best.pos).geysers
	var m := game.clock.minutes
	for i in 400:
		var st := Geysers.state(row, game.world.seed_value, best.id, m + float(i) * 0.25)
		if int(st.stage) == Geysers.WARNING:
			game.clock.minutes = m + float(i) * 0.25
			break
	# Stood six tiles off, looking toward it.
	var off := Vector2(6.0, 0.0).rotated(Rng.hash01(game.world.seed_value, best.id, 9) * TAU)
	# Turned a little off it, so the column stands in the frame's right third and
	# not behind the player's head.
	_face = (-off).angle() - 0.45
	return best.pos + off


func tour_face(what: String) -> float:
	return _face if what == "geyser" else NAN


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
		var land := BiomeRegistry.at(game.world, v.pos)
		if Geysers.is_geyser(land.geysers, game.world.seed_value, v.id):
			_geyser(v, land.geysers, delta)
			continue
		var own := land.vent_breath
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



## A geyser at its stage (Geysers): resting it breathes nothing; warning, a low
## skirt of steam spreads round the mouth; erupting, a column stands up to its
## height, holds and falls, with spray thrown out round its foot.
func _geyser(v: WorldProp, row: Dictionary, delta: float) -> void:
	var st := Geysers.state(row, game.world.seed_value, v.id, game.clock.minutes)
	var stage := int(st.stage)
	if stage == Geysers.RESTING:
		return
	var key := v.id
	var gap := float(_geyser_gap.get(key, 0.0)) - delta
	if gap > 0.0:
		_geyser_gap[key] = gap
		return
	var col: Color = row.get("colour", Color(0.9, 0.9, 0.85))
	var at := game.world.to_3d(v.pos) + Vector3(0, 0.3 * v.scale, 0)
	var eye := MobFx.close_eye(_layer)
	var seed_value := v.id * 53 + int(_t * 7.0)
	if stage == Geysers.WARNING:
		_geyser_gap[key] = 0.35
		# The skirt: wide low puffs round the mouth, hugging the ground.
		var a := Rng.hash01(seed_value, 1) * TAU
		var p := at + Vector3(cos(a) * 0.5, -0.1, sin(a) * 0.5)
		if eye:
			_plume_pooled(p, col, 0.5, 1.6, Vector2(cos(a), sin(a)) * 0.8, seed_value)
		else:
			_plume(p, col, 0.4, 1.4, Vector2(cos(a), sin(a)) * 0.6, seed_value, 0.0)
		return
	_geyser_gap[key] = 0.12
	var hold := Geysers.column(float(st.k))
	if hold <= 0.02:
		return
	var height := float(row.get("height", 6.0)) * hold
	if eye:
		_column_pooled(at, col, height, seed_value)
	else:
		# From above, a column is its foot: a burst of wide puffs.
		_plume(at, col, 1.2 * hold, 1.6, Vector2(0.3, -0.2), seed_value, 0.0)


## One beat of a standing column: puffs stacked from the mouth to `height`, each
## rising a little further and dying quickly, so the column is renewed from
## below and holds; a few thrown sideways at its top are the spray falling back.
func _column_pooled(at: Vector3, col: Color, height: float, seed_value: int) -> void:
	if _puffs == null:
		_make_puffs()
	var mm := _puffs.multimesh
	var n := 10
	for i in n + 3:
		var f := float(i) / float(n - 1)
		var p: Vector3
		var w: float
		var travel: Vector3
		if i < n:
			p = at + Vector3(Rng.hash01(seed_value, i, 2) * 0.2 - 0.1, height * f, Rng.hash01(seed_value, i, 3) * 0.2 - 0.1)
			w = lerpf(0.9, 2.0, f)
			travel = Vector3(0.0, height * 0.25, 0.0)
		else:
			var a := Rng.hash01(seed_value, i, 4) * TAU
			p = at + Vector3(0.0, height * 0.85, 0.0)
			w = 0.9
			travel = Vector3(cos(a) * 1.8, -height * 0.6, sin(a) * 1.8)
		var basis := Basis(Vector3(w * 0.7, 0.0, 0.0), travel, Vector3(0.0, 0.0, 1.0))
		mm.set_instance_transform(_next_puff, Transform3D(basis, p))
		mm.set_instance_color(_next_puff, Color(col.r, col.g, col.b, Rng.hash01(seed_value, i, 5)))
		mm.set_instance_custom_data(_next_puff, Color(_t, 1.2, 1.6, 0.8))
		_next_puff = (_next_puff + 1) % PUFFS
