extends GameSystem
## Daylight through a torn lid (`Dome`, `BiomeDef.sky_shut`).
##
## A landscape that is shut off from the sky gets its darkness at the LIGHT, in
## SkyLight, and this is the other half of the same idea: the lid is not perfect.
## Where it is torn, a hard column of dirty daylight comes down, and the patch it
## lays on the street is the brightest thing in the landscape. It moves with the
## hour, because the sun does.
##
## WHY THIS IS A SPOT LIGHT AND NOT A HOLE IN SOMETHING. A real hole wants a real
## lid, and a lid is geometry between the camera and the player, which belongs to
## `depth` and to whoever is building the city above the street. A spot light at
## the tear's own height, aimed along the sun's own bearing, lands its pool where
## a hole would and reads as a solid column through the volumetric air — which is
## LANTERN law 2 doing exactly the job it was rebuilt for. When the towers land,
## the same light will be cut by them for free.
##
## IT IS ONE LIGHT PER TEAR AND IT DOES NOT CAST. The shadow budget is the lights
## system's (`Quality.ROWS.shadow_lights`) and it is already spent on lamps and
## fires; a shaft that cast would take that argument out of another package's
## hands. The column and the pool carry the picture without it. What is lost is
## that a shaft passes through anything standing in it, which nothing in the
## street is tall enough for today and the towers will be — so this is the line
## to revisit when they arrive, and it is a budget conversation, not a bug.

## Tiles round the player whose tears are lit.
const REACH := 30.0
## How many shafts stand at once. Three is what the camera can hold: the play
## camera shows about 27 x 18 tiles, and the tears are dealt on a 26-tile grid.
const MOST := 3
## Under this much lid there is no dome to tear, so nothing is drawn at all and
## an open landscape pays nothing for this file existing.
const SHUT_FLOOR := 0.25

## The shaft's own light, linear, at noon and in the dead of night. The night end
## is not zero: the lid is torn, and what comes through a tear at midnight is
## moonlight and whatever the sky over the lid is carrying. It is small on
## purpose — THE SHAFT IS WHERE THE HOUR LIVES in a shut landscape, and if it did
## not go out the landscape would have no day and no night at all.
## They were 7.4 and 0.30 and the pool came back a flat white ellipse: over the
## tonemapper's shoulder the colour is gone and only the shape is left, which is
## the one failure `TONEMAP` exists to prevent and which a light can still walk
## into from below. Held here the pool keeps the sun's own dirty orange and is
## still far and away the brightest thing in the street.
const SHAFT_NOON := 2.9
const SHAFT_NIGHT := 0.14
## Daylight that has come through a mile of smog: warm, and never white. Toward
## the second at the ends of the day, which is the struck-match colour a sun has
## when a lid is the only thing you can see it through.
const SHAFT_HIGH := Color(1.0, 0.72, 0.42)
const SHAFT_LOW := Color(1.0, 0.46, 0.16)
## How solid the column is in the air. Well over 1: the whole reason a shaft
## reads as a THING rather than as a bright patch is the air it is standing in.
const SHAFT_FOG := 5.0
## Sharpness of the cone's edge. A tear has a hard edge, not a vignette.
const SHAFT_FALLOFF := 0.35
## How far the pool may be from the player before its shaft is not worth lighting.
const PATCH_REACH := 22.0

var _layer: Node3D
var _shafts: Array[SpotLight3D] = []
var _scan := 0.0
var _tears: Array[Vector2] = []
## The last shut this system composed with, and where each live pool landed, so
## a tour can be answered off the world instead of off a latch.
var _shut := 0.0
var _pools: Array[Vector2] = []


func setup(g: Game) -> void:
	super.setup(g)
	_layer = Node3D.new()
	_layer.name = "dome_shafts"
	g.add_child(_layer)
	for i in MOST:
		var s := SpotLight3D.new()
		s.name = "shaft_%d" % i
		s.shadow_enabled = false
		s.spot_range = Dome.HEIGHT * 2.4
		s.spot_angle = Dome.cone_degrees()
		s.spot_angle_attenuation = SHAFT_FALLOFF
		# A shaft falls off almost not at all over its own length: it is a column
		# of light and not a bulb, and an inverse-square roll-off over thirteen
		# units would put the pool at a tenth of the air above it.
		s.spot_attenuation = 0.22
		s.light_volumetric_fog_energy = SHAFT_FOG
		s.light_energy = 0.0
		s.visible = false
		_layer.add_child(s)
		_shafts.append(s)


func realm_changed(_from: StringName, _to: StringName) -> void:
	_tears.clear()
	_pools.clear()
	_scan = 0.0
	for s in _shafts:
		s.visible = false


func _process(delta: float) -> void:
	if game == null or game.player == null or game.sky == null:
		return
	# The same blended number the sky composed its light from, so the shafts can
	# never disagree with the darkness they are a hole in. Squared shares means a
	# walk out of a shut landscape takes its shafts with it.
	_shut = SkyLight.sky_shut_at(game.sky.neon_shares)
	if _shut < SHUT_FLOOR:
		_pools.clear()
		for s in _shafts:
			s.visible = false
		return
	var at: Vector2 = game.player.pos
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.7
		_tears = Dome.tears(game.world.seed_value, at, REACH)
	var sun := SkyLight.sun_at(game.sky.clock_hour)
	var lit := 1.0 - SkyLight.day_gone(game.sky.clock_hour)
	var az := float(sun.azimuth)
	var el := float(sun.elevation)
	# The colour and the level are the SUN's, seen through the lid: what the hour
	# is doing is the one thing a shaft still carries into a shut street.
	var col := SHAFT_LOW.lerp(SHAFT_HIGH, clampf(lit, 0.0, 1.0))
	var energy := lerpf(SHAFT_NIGHT, SHAFT_NOON, clampf(lit, 0.0, 1.0)) * _shut
	# Nearest POOL first, not nearest tear: what the player sees is where the
	# light lands, and at a low sun those are two different places entirely.
	var live: Array[Vector2] = []
	for t in _tears:
		var p := Dome.patch(t, az, el)
		if p.distance_to(at) <= PATCH_REACH:
			live.append(t)
	live.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return Dome.patch(a, az, el).distance_squared_to(at) < Dome.patch(b, az, el).distance_squared_to(at))
	_pools.clear()
	for i in MOST:
		var s := _shafts[i]
		if i >= live.size():
			s.visible = false
			continue
		var tear: Vector2 = live[i]
		var pool := Dome.patch(tear, az, el)
		# The lid stands over the ground the TEAR is above, so the column starts
		# at one height and lands at whatever the street under the pool is doing.
		var base := game.world.to_3d(tear)
		s.global_position = Vector3(tear.x, base.y + Dome.HEIGHT, tear.y)
		s.rotation_degrees = Vector3(-el, az, 0.0)
		s.light_color = col
		s.light_energy = energy
		s.visible = true
		_pools.append(pool)


## Answer a tour off the LIVE world, never off a latch: a shaft is a thing that
## is either standing in front of you or is not, and a latch in front of a live
## computation is the bug `tests/tours/test_tour_claims.gd` exists to catch.
func tour_seen(what: StringName) -> bool:
	match what:
		&"dome":
			return _shut >= SHUT_FLOOR
		&"shaft":
			return not _pools.is_empty()
		&"shaft_near":
			if game == null or game.player == null:
				return false
			for p in _pools:
				if p.distance_to(game.player.pos) <= Dome.SPREAD * 2.0:
					return true
			return false
	return false
