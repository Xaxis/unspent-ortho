extends GameSystem
## The animals that live beside people and are no threat: a dog about each
## village, a few sheep grazing the nearest grass, gulls working the nearest
## beach, and a flock over every tip and wreck. They are not mobs (no group, no
## fight); fight's hostile animals come from FigureModel.create through the mob
## package. Streamed with the villages, and with the refuse near the player.
##
##   dog    wanders the village, stops to watch you, trots off again
##   sheep  graze in a loose flock and scatter when you walk into them
##   gulls  work the refuse (a flock to each tip or wreck, whatever village is
##          near) and peck along the tideline; they lift off when you come close, then
##          land again further along; at dusk they fly off out of sight, and
##          at dawn they fly back in and land
##
## Animals are built from a queue, one on every odd frame (35_folk takes the even
## ones), each built once already varied: a village streaming in never stalls.
##
## Shot option (BootOptions, characters):
##   --fauna=KIND:N[,KIND:N]   N of KIND in a ring round the player, e.g. gull:3,sheep:4

const NEAR := 36.0
const FAR := 48.0
const GRAZE: Array[int] = [Ground.GRASS, Ground.HEATH, Ground.MOSS]
const SHORE: Array[int] = [Ground.SAND, Ground.SHINGLE]
## Hours: gulls leave from DUSK and come back from DAWN, off the same curve as the
## villagers (35_folk): beasts settle SETTLE_BEFORE ahead of people, before the
## light has quite gone.
const SETTLE_BEFORE := 0.5
const DUSK := Weather.DUSK_END - SETTLE_BEFORE
const DAWN := Weather.DAWN_END - 0.5

## One animal: {model, kind, pos, home, facing, state, t, wait, target, village, fly}
var beasts: Array[Dictionary] = []
## Animals waiting to be built: {kind, pos, village, seed}.
var queue: Array[Dictionary] = []
var _spawned: Dictionary = {}
## Refuse the gulls work: {key, pos} per heap of tips and wrecks lying within
## SITE_JOIN of each other. Keys are REFUSE_KEY - the first prop's id, so they
## share _spawned and a beast's `village` with the villages (which are >= 0).
var sites: Array[Dictionary] = []
## Refuse whose flock came up short of what it was dealt: key -> Vector2i(placed,
## dealt). A heap walled in by water or cliff cannot always stand three gulls
## beside it, and a flock that quietly shrank read as nothing at all.
var refuse_short: Dictionary = {}
var _props_seen := 0
## `sites` by SITE_JOIN cell (Vector2i -> PackedVector2Array of site positions),
## so a heap is joined by asking the cells round it, not every site on the island.
var _site_grid: Dictionary = {}
## SITES ARE KEPT PER WORLD. A door puts the game in a pocket world and a shaft
## in another realm's, each with props of its own. One count for all of them
## reset on the pocket's smaller one, and coming back out the coast's rows below
## it were never looked at again, so their refuse lost its gulls; the rows above
## it were walked as WorldProp views in one frame, 987 ms at 1840. `_sites_of`
## is the world `sites` was found in; every other world's is set aside here,
## instance id -> [sites, props seen, grid], until that world is let go.
var _sites_of := 0
var _kept_sites: Dictionary = {}
const REFUSE_KEY := -1000
const SITE_JOIN := 7.0
## How far past a heap's edge a gull may stand and still be working it.
const REFUSE_REACH := 1.9
## Half a period behind 35_folk, so the two never stream in the same frame.
var _check := 0.25


func setup(g: Game) -> void:
	super.setup(g)
	name = "fauna"
	var ring := game.options.fauna if game.options != null else ""
	if ring != "":
		_ring(ring)
	_stream(true)


static func is_night(hour: float) -> bool:
	return hour >= DUSK or hour < DAWN


func _process(delta: float) -> void:
	if game == null or game.world == null or game.player == null:
		return
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_stream(false)
	if not queue.is_empty() and Engine.get_process_frames() % 2 == 1:
		pump()
	var night := is_night(game.clock.hour() if game.clock != null else 12.0)
	for b in beasts:
		_step(b, delta, night)


# ---------------------------------------------------------------- streaming

func _stream(now: bool = false) -> void:
	var at: Vector2 = game.player.pos
	for i in game.world.villages.size():
		var vp: Vector2 = game.world.villages[i].get("pos", Vector2(-9999, -9999))
		_stream_one(i, vp, at, now, _populate)
	_find_sites()
	for site in sites:
		_stream_one(int(site.key), site.pos, at, now, _populate_refuse)


func _stream_one(key: int, centre: Vector2, at: Vector2, now: bool, populate: Callable) -> void:
	var d := centre.distance_to(at)
	if d < NEAR and not _spawned.has(key):
		_spawned[key] = true
		populate.call(key, centre)
		if now:
			while pump():
				pass
	elif d > FAR and _spawned.has(key):
		_spawned.erase(key)
		queue = queue.filter(func(q: Dictionary) -> bool: return q.village != key)
		for b: Dictionary in beasts.duplicate():
			if b.village == key:
				(b.model as Node).queue_free()
				beasts.erase(b)


## Gather the tips and wrecks into sites. Props are only ever appended (worldgen,
## then the strand and whatever is built), so only the new rows are looked at,
## and only their kinds: each refuse kind is found along the kind column by the
## engine, and the rows found are joined in row order, as they always were.
func _find_sites() -> void:
	var w := game.world
	_sites_for(w)
	w.sync_table()
	var t := w.table
	var n := t.size()
	if n < _props_seen:
		# Fewer rows than were seen is a world laid again in place.
		sites.clear()
		_site_grid.clear()
		_props_seen = 0
	if n == _props_seen:
		return
	var rows := PackedInt32Array()
	var kinds := t.kind
	for k: int in REFUSE:
		var at := kinds.find(k, _props_seen)
		while at >= 0:
			rows.append(at)
			at = kinds.find(k, at + 1)
	rows.sort()
	for row in rows:
		var p := t.pos[row]
		if not _joins(p):
			sites.append({"key": REFUSE_KEY - t.id[row], "pos": p})
			var c := _site_cell(p)
			var cell: PackedVector2Array = _site_grid.get(c, PackedVector2Array())
			cell.append(p)
			_site_grid[c] = cell
	_props_seen = n


## Make `w`'s sites the ones in hand, setting the last world's aside.
func _sites_for(w: WorldData) -> void:
	var id := w.get_instance_id()
	if id == _sites_of:
		return
	if _sites_of != 0:
		_kept_sites[_sites_of] = [sites, _props_seen, _site_grid]
	for old: int in _kept_sites.keys():
		if not is_instance_id_valid(old):
			_kept_sites.erase(old)
	var kept: Array = _kept_sites.get(id, [])
	_kept_sites.erase(id)
	_sites_of = id
	if kept.is_empty():
		sites = [] as Array[Dictionary]
		_props_seen = 0
		_site_grid = {}
	else:
		sites = kept[0]
		_props_seen = kept[1]
		_site_grid = kept[2]


static func _site_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / SITE_JOIN), floori(p.y / SITE_JOIN))


## Whether a heap at `p` is within SITE_JOIN of a site already found: one in
## its cell or the eight round it, which are all a site that near can be in.
func _joins(p: Vector2) -> bool:
	var c := _site_cell(p)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cell: PackedVector2Array = _site_grid.get(c + Vector2i(dx, dy), PackedVector2Array())
			for q in cell:
				if q.distance_to(p) < SITE_JOIN:
					return true
	return false


## Build the next queued animal. Returns false when there was none.
func pump() -> bool:
	if queue.is_empty():
		return false
	var q: Dictionary = queue.pop_front()
	_add(q.kind, q.pos, q.village, q.seed)
	return true


func _enqueue(kind: StringName, at: Vector2, village: int, seed_value: int) -> void:
	queue.append({"kind": kind, "pos": at, "village": village, "seed": seed_value})


func _populate(index: int, centre: Vector2) -> void:
	var s := game.world.seed_value
	if Rng.hash01(s, index, 1) < 0.85:
		var spot := _find(centre, 4.0, [], 11 + index)
		if spot.x > -1.0:
			_enqueue(&"dog", spot, index, s * 7 + index)
	var pasture := _find(centre, 12.0, GRAZE, 23 + index)
	if pasture.x > -1.0:
		var flock := 2 + int(Rng.hash01(s, index, 2) * 3.0)
		for n in flock:
			var p := pasture + Vector2(Rng.hash01(s, index, n, 3) - 0.5, Rng.hash01(s, index, n, 4) - 0.5) * 3.0
			if _ok(p):
				_enqueue(&"sheep", p, index, s * 13 + index * 5 + n)
	# Refuse has its own flock (_populate_refuse); the village's gulls keep the tideline.
	var beach := _find(centre, 16.0, SHORE, 37 + index)
	if beach.x > -1.0:
		var n_gulls := 2 + int(Rng.hash01(s, index, 5) * 3.0)
		for n in n_gulls:
			var p := beach + Vector2(Rng.hash01(s, index, n, 6) - 0.5, Rng.hash01(s, index, n, 7) - 0.5) * 2.5
			if _ok(p):
				_enqueue(&"gull", p, index, s * 17 + index * 3 + n)


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


## A beached trawler's hull is worked like a tip. Scattered debris is not: it lies
## round villages in every landscape, and gulls over the snow would lie.
const REFUSE: Array[int] = [PropKind.TIP, PropKind.WRECK, PropKind.HULL]


## A flock over a heap of refuse: three to five gulls standing about its tips
## and wrecks, each beside its own heap and on its own side of it.
func _populate_refuse(key: int, centre: Vector2) -> void:
	var s := game.world.seed_value
	var heaps: Array[WorldProp] = []
	var seen := {}
	for p in game.query.props_near(centre, SITE_JOIN):
		if REFUSE.has(p.kind) and not seen.has(p.id):
			seen[p.id] = true
			heaps.append(p)
	if heaps.is_empty():
		return
	var n_gulls := 3 + int(Rng.hash01(s, key, 5) * 3.0)
	var taken: Array[Vector2] = []
	for n in n_gulls:
		var spot := _beside(heaps[n % heaps.size()], Rng.hash01(s, key, n, 6), Rng.hash01(s, key, n, 7), taken)
		if spot.x > -1.0:
			taken.append(spot)
			_enqueue(&"gull", spot, key, s * 19 + absi(key) * 3 + n)
	if taken.size() < n_gulls:
		refuse_short[key] = Vector2i(taken.size(), n_gulls)


## A standable spot beside a heap, starting `turn` (0..1) of the way round it and
## `out` (0..1) further off than its edge, and not on top of a gull already
## `taken` there; (-1, -1) if it is walled in.
##
## ONE RING OF EIGHT BEARINGS DROPPED A GULL WHEREVER THE LAND WAS NARROW. A tip on
## seed 5 stands on a spit one tile wide with shelf water on both sides, and the
## eight bearings at one radius found two of its three standable neighbours: the
## flock "three to five" came out as two and nothing said so. So the search goes
## round again finer and at every distance still BESIDE the heap -- never further
## than `REFUSE_REACH` past its edge, or a gull is working the tideline and not
## the refuse.
func _beside(p: WorldProp, turn: float, out: float, taken: Array[Vector2] = []) -> Vector2:
	var first := p.solid + 0.5 + out * 1.2
	for i in 8:
		var spot := p.pos + Vector2.from_angle(TAU * (turn + i / 8.0)) * first
		if _ok(spot) and _clear_of(spot, taken):
			return spot
	var r := p.solid + 0.5
	while r <= p.solid + REFUSE_REACH:
		for i in 16:
			var spot := p.pos + Vector2.from_angle(TAU * (turn + i / 16.0)) * r
			if _ok(spot) and _clear_of(spot, taken):
				return spot
		r += 0.35
	return Vector2(-1, -1)


func _clear_of(spot: Vector2, taken: Array[Vector2]) -> bool:
	for t in taken:
		if t.distance_squared_to(spot) < 0.25:
			return false
	return true


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
	var m := AnimalModel.spawn(kind, game.view.world_material() if game.view != null else null, seed_value)
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
	if kind == &"gull" and _gull_night(b, night):
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


## Dusk sends gulls off out of sight; dawn brings them back. Returns true while
## the gull is away (nothing else to do this frame).
func _gull_night(b: Dictionary, night: bool) -> bool:
	var m := b.model as AnimalModel
	if night and not b.get("away", false):
		if not b.get("leaving", false):
			b.leaving = true
			var dir := Vector2.from_angle(Rng.hash01(int(b.seed), 31) * TAU)
			if b.state != &"flee" and b.state != &"fly":
				b.state = &"flee"
			b.target = (b.pos as Vector2) + dir * 40.0
			b.wait = 1.0
		elif m.pose_time > 1.0 and not _seen(b.pos):
			b.away = true
			b.leaving = false
			m.visible = false
		return false
	if b.get("away", false):
		if night:
			return true
		# Back in from off-screen, down onto its own stretch of shore.
		b.away = false
		var from := Vector2.from_angle(Rng.hash01(int(b.seed), 32) * TAU) * 18.0
		b.pos = (b.home as Vector2) + from
		b.target = b.home
		b.state = &"fly"
		b.wait = 0.0
		m.set_pose(&"fly")
		m.visible = true
	elif not night and b.get("leaving", false):
		b.leaving = false
		b.target = b.home
	return false


## Whether the camera can see a spot. False with no camera (tests, headless).
func _seen(p: Vector2) -> bool:
	if not is_inside_tree():
		return false
	var cam := get_viewport().get_camera_3d()
	return cam != null and cam.is_position_in_frustum(game.world.to_3d(p) + Vector3(0, 0.3, 0))


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
		if float(b.wait) < 0.0 and d.length() < 0.3 and not b.get("leaving", false):
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
			# No shore that way (inland, or a shingle-less spit): any standing
			# ground away from the stranger, never back at its feet.
			land = _find((b.pos as Vector2) + away * 7.0, 3.0, [] as Array[int], int(b.seed) + int(b.t * 11.0))
		if land.x < 0.0:
			land = (b.pos as Vector2) + away * 6.0
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
