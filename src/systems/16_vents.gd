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


func setup(g: Game) -> void:
	super.setup(g)
	_layer = Node3D.new()
	_layer.name = "vent_breath"
	g.add_child(_layer)


func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
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
		MobFx.breath(_layer, at, col, (0.5 + 0.25 * h) * much, (2.2 + h) * sqrt(much), wind * (0.6 + h), v.id * 31 + int(_t))
