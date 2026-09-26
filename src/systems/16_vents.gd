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
		_plume(at, col, (0.5 + 0.25 * h) * much, (2.2 + h) * sqrt(much), wind * (0.6 + h), v.id * 31 + int(_t))


## How many puffs one breath is laid as, from the vent's mouth up.
const PLUME := 5


## A breath as a PLUME, not a ball: a column of puffs laid at once from a
## narrow mouth up, each higher one wider, fainter-lived and further
## downwind, so the whole leans and shears with the wind and breaks up at
## its top into wisps set off to either side. One soft ball per breath read as
## a string of cotton wool over every vent. `size` is the breath's width at
## its widest.
func _plume(at: Vector3, col: Color, size: float, seconds: float, drift: Vector2, seed_value: int) -> void:
	for i in PLUME:
		var f := float(i) / float(PLUME - 1)
		var rise := size * (0.15 + f * 1.6)
		var shear := drift * f * f * 1.4
		# The top breaks into wisps: offset across the wind, one side or the other.
		var side := (Rng.hash01(seed_value, i, 3) - 0.5) * size * 0.9 * f
		var across := Vector2(-drift.y, drift.x).normalized() * side
		var p := at + Vector3(shear.x + across.x, rise, shear.y + across.y)
		var w := size * lerpf(0.28, 1.0, f)
		MobFx.breath(_layer, p, col, w, seconds * lerpf(0.55, 1.1, f), drift * lerpf(0.5, 1.6, f), seed_value * 11 + i)

