extends GameSystem
## The animals that live beside people and are no threat: a dog about each
## village, a few sheep grazing the nearest grass, gulls working the nearest
## beach. They are not mobs (no group, no fight); fight's hostile animals come
## from FigureModel.create through the mob package. Streamed with the villages.
##
##   dog    wanders the village, stops to watch you, trots off again
##   sheep  graze in a loose flock and scatter when you walk into them
##   gulls  peck along the tideline and lift off when you come close, then
##          land again further along
##
## Shot flag (parsed here so no shared file changes):
##   --fauna=KIND:N[,KIND:N]   N of KIND in a ring round the player, e.g. gull:3,sheep:4

const NEAR := 36.0
const FAR := 48.0
const GRAZE: Array[int] = [Ground.GRASS, Ground.HEATH, Ground.MOSS]
const SHORE: Array[int] = [Ground.SAND, Ground.SHINGLE]

## One animal: {model, kind, pos, home, facing, state, t, wait, target, village, fly}
var beasts: Array[Dictionary] = []
var _spawned: Dictionary = {}
var _check := 0.0


func setup(g: Game) -> void:
	super.setup(g)
	name = "fauna"
	var ring := _arg("fauna", "")
	if ring != "":
		_ring(ring)
	_stream()


func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.trim_prefix("--" + key + "=")
	return fallback


func _process(delta: float) -> void:
	if game == null or game.world == null or game.player == null:
		return
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_stream()
	var hour := game.clock.hour() if game.clock != null else 12.0
	var night := hour < 5.5 or hour > 21.5
	for b in beasts:
		_step(b, delta, night)


# ---------------------------------------------------------------- streaming

func _stream() -> void:
	var at: Vector2 = game.player.pos
	for i in game.world.villages.size():
		var vp: Vector2 = game.world.villages[i].get("pos", Vector2(-9999, -9999))
		var d := vp.distance_to(at)
		if d < NEAR and not _spawned.has(i):
			_spawned[i] = true
			_populate(i, vp)
		elif d > FAR and _spawned.has(i):
			_spawned.erase(i)
			for b: Dictionary in beasts.duplicate():
				if b.village == i:
					(b.model as Node).queue_free()
					beasts.erase(b)


func _populate(index: int, centre: Vector2) -> void:
	var s := game.world.seed_value
	if Rng.hash01(s, index, 1) < 0.85:
		var spot := _find(centre, 4.0, [], 11 + index)
		if spot.x > -1.0:
			_add(&"dog", spot, index, s * 7 + index)
	var pasture := _find(centre, 12.0, GRAZE, 23 + index)
	if pasture.x > -1.0:
		var flock := 2 + int(Rng.hash01(s, index, 2) * 3.0)
		for n in flock:
			var p := pasture + Vector2(Rng.hash01(s, index, n, 3) - 0.5, Rng.hash01(s, index, n, 4) - 0.5) * 3.0
			if _ok(p):
				_add(&"sheep", p, index, s * 13 + index * 5 + n)
	var beach := _find(centre, 16.0, SHORE, 37 + index)
	if beach.x > -1.0:
		var n_gulls := 2 + int(Rng.hash01(s, index, 5) * 3.0)
		for n in n_gulls:
			var p := beach + Vector2(Rng.hash01(s, index, n, 6) - 0.5, Rng.hash01(s, index, n, 7) - 0.5) * 2.5
			if _ok(p):
				_add(&"gull", p, index, s * 17 + index * 3 + n)


func _ring(spec: String) -> void:
	var at: Vector2 = game.player.pos
	var i := 0
	for part: String in spec.split(",", false):
		var kv := part.split(":")
		var count := kv[1].to_int() if kv.size() > 1 else 1
		for n in count:
			var a := TAU * float(i) / 7.0 + 0.3
			var p := at + Vector2(cos(a), sin(a)) * (2.2 + 0.6 * (i % 3))
			i += 1
			_add(StringName(kv[0]), p, -2, i * 101)


## A standable tile near `at` (within r) whose ground is one of `grounds` (any if empty).
func _find(at: Vector2, r: float, grounds: Array[int], salt: int) -> Vector2:
	var s := game.world.seed_value
	for attempt in 40:
		var a := Rng.hash01(s, salt, attempt, 1) * TAU
		var d := r * (0.35 + 0.65 * Rng.hash01(s, salt, attempt, 2))
		var p := at + Vector2(cos(a), sin(a)) * d
		if not _ok(p):
			continue
		if grounds.is_empty() or grounds.has(game.world.ground_at(floori(p.x), floori(p.y))):
			return p
	return Vector2(-1, -1)


func _ok(p: Vector2) -> bool:
	var w := game.world
	var x := floori(p.x)
	var y := floori(p.y)
	return w.in_bounds(x, y) and game.query.standable(x, y) and not Ground.is_water(w.ground_at(x, y))


func _add(kind: StringName, at: Vector2, village: int, seed_value: int) -> void:
	var m := FigureModel.create(kind, game.view.world_material() if game.view != null else null)
	if m is AnimalModel:
		(m as AnimalModel).vary(seed_value)
	m.name = "%s_%d" % [kind, beasts.size()]
	add_child(m)
	var b := {
		"model": m, "kind": kind, "pos": at, "home": at, "facing": Rng.hash01(seed_value, 9) * TAU,
		"state": &"stand", "t": Rng.hash01(seed_value, 3) * 4.0, "wait": Rng.hash01(seed_value, 4) * 3.0,
		"target": at, "village": village, "seed": seed_value,
	}
	_place(b, 0.0)
	beasts.append(b)


# ---------------------------------------------------------------- behaviour

func _step(b: Dictionary, delta: float, night: bool) -> void:
	var m: FigureModel = b.model
	var kind: StringName = b.kind
	if kind == &"gull":
		m.visible = not night
		if night:
			return
	b.t = float(b.t) + delta
	var to_player: Vector2 = game.player.pos - (b.pos as Vector2)
	var near := to_player.length()
	var speed := 0.0
	match kind:
		&"dog":
			speed = _dog(b, delta, near, to_player)
		&"sheep":
			speed = _sheep(b, delta, near, to_player)
		&"gull":
			speed = _gull(b, delta, near, to_player)
	m.set_pose(b.state)
	m.animate(delta, speed)
	_place(b, delta)


func _dog(b: Dictionary, delta: float, near: float, to_player: Vector2) -> float:
	if near < 3.0 and game.player.speed < 0.5:
		# Stops to watch a still stranger.
		b.state = &"alert"
		b.facing = lerp_angle(float(b.facing), to_player.angle(), 1.0 - exp(-4.0 * delta))
		return 0.0
	return _wander(b, delta, 5.0, 2.2, 1.0, 4.0)


func _sheep(b: Dictionary, delta: float, near: float, to_player: Vector2) -> float:
	if near < 2.2 and game.player.speed > 0.5:
		b.state = &"flee"
		b.wait = 1.4
		var away := -to_player.normalized()
		return _move(b, away, 3.6, delta)
	if b.state == &"flee" and float(b.wait) > 0.0:
		b.wait = float(b.wait) - delta
		return _move(b, Vector2.from_angle(float(b.facing)), 3.0, delta)
	return _wander(b, delta, 3.0, 0.8, 4.0, 9.0)


func _gull(b: Dictionary, delta: float, near: float, to_player: Vector2) -> float:
	var m := b.model as AnimalModel
	if b.state == &"land":
		if m.pose_time >= 0.75:
			b.state = &"stand"
			b.wait = 2.0 + Rng.hash01(int(b.seed), int(b.t * 10.0)) * 4.0
		return 0.0
	if b.state == &"flee" or b.state == &"fly":
		b.wait = float(b.wait) - delta
		var target: Vector2 = b.target
		var d := target - (b.pos as Vector2)
		if float(b.wait) < 0.0 and d.length() < 0.3:
			b.state = &"land"
			return 0.0
		if m.pose_time > 0.6:
			b.state = &"fly"
		# Airborne: nothing on the ground stops it.
		var step := d.normalized() * minf(d.length(), 4.5 * delta)
		b.pos = (b.pos as Vector2) + step
		if step.length() > 1e-4:
			b.facing = lerp_angle(float(b.facing), step.angle(), 1.0 - exp(-6.0 * delta))
		return 4.5
	if near < 4.0:
		b.state = &"flee"
		b.wait = 1.5
		var away := -to_player.normalized().rotated((Rng.hash01(int(b.seed), int(b.t)) - 0.5) * 1.2)
		var land := _find((b.pos as Vector2) + away * 9.0, 4.0, SHORE, int(b.seed) + int(b.t * 7.0))
		if land.x < 0.0:
			land = (b.home as Vector2)
		b.target = land
		return 0.0
	return _wander(b, delta, 1.5, 0.7, 1.5, 5.0)


## Stand a while, walk to a spot near home, repeat.
func _wander(b: Dictionary, delta: float, radius: float, pace: float, wait_lo: float, wait_hi: float) -> float:
	if float(b.wait) > 0.0:
		b.wait = float(b.wait) - delta
		b.state = &"stand"
		return 0.0
	var target: Vector2 = b.target
	var d := target - (b.pos as Vector2)
	if d.length() < 0.15:
		var h := Rng.hash01(int(b.seed), int(b.t * 13.0))
		var next: Vector2 = (b.home as Vector2) + Vector2.from_angle(h * TAU) * radius * (0.3 + 0.7 * Rng.hash01(int(b.seed), int(b.t * 17.0), 1))
		if _ok(next):
			b.target = next
		b.wait = lerpf(wait_lo, wait_hi, Rng.hash01(int(b.seed), int(b.t * 19.0), 2))
		b.state = &"stand"
		return 0.0
	b.state = &"walk"
	return _move(b, d.normalized(), minf(pace, d.length() / maxf(delta, 1e-3)), delta)


func _move(b: Dictionary, dir: Vector2, pace: float, delta: float) -> float:
	var from: Vector2 = b.pos
	var to := from + dir * pace * delta
	if not _ok(to):
		b.target = b.pos
		return 0.0
	b.pos = to
	b.facing = lerp_angle(float(b.facing), dir.angle(), 1.0 - exp(-8.0 * delta))
	return pace


func _place(b: Dictionary, _delta: float) -> void:
	var m: Node3D = b.model
	m.position = game.world.to_3d(b.pos)
	m.rotation.y = -float(b.facing)
