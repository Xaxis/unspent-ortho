class_name Spawner
## Where and when the coast puts a machine or a creature near the player
## (design-extract §7.4). Pure: a roll is a function of the seed, the roll
## number, the world, the moment and where the player stands.
##
##   every 200 ms: hash % 2000 < sum of `chance` over rows whose moment fits
##   (country and ground aside: hour, day, weather, wind); then a tile in the
##   square ring 11-18 around the player that the camera cannot see; then a
##   weighted pick among the rows that fit at that tile.
## At most 6 living; beyond 24 tiles (Chebyshev) a body is culled.

const ROLL_MS := 200
const MAX_LIVING := 6
const RING_MIN := 11
const RING_MAX := 18
const CULL := 24.0
const TILE_TRIES := 10
## Tiles within this Chebyshev distance of a near_props kind.
const NEAR_PROP := 4.0
## A rise: no tile within this radius stands higher.
const RISE_RADIUS := 3
## Wind above this grounds the flock.
const CALM_WIND := 0.35

## The camera `in_view` scores against, as a FALLBACK. A running game overwrites
## the height and the pitch before every spawn (`30_mobs`), so these decide
## nothing in play and everything in a headless test.
##
## `view_height` read 14.0 under a comment saying "(CameraRig defaults)", and the
## rig's `VIEW_HEIGHT` is 15.0 -- a header naming the rule one line above
## breaking it, which this repository has three recorded cases of. It is spelled
## rather than imported because this is `src/core`: a pure rules file may not
## reach into `src/render` for a constant, so `tests/render/test_read_reach.gd`
## holds the two equal instead, and will fail here if the rig ever moves.
var yaw_deg := 45.0
var pitch_deg := 57.0
var view_height := 15.0
var aspect := 16.0 / 9.0
## A dart (warden, flock, clerk, gulls) comes to take and go; nothing to fight,
## so it counts this share of its weight in the gate and the pick. At the full
## weight a clerk country read the player every minute.
const DART_SHARE := 0.3

## Rate against the source's (whose every-200-ms gate filled a ring of six in seconds; the coast here wants a trickle).
var rate := 0.3


## A row's weight in a roll: its chance, a dart's at DART_SHARE.
static func weight_of(row: Dictionary) -> float:
	var w := float(row.get("chance", 0))
	return w * DART_SHARE if row.get("approach", &"") == &"dart" else w


## A hunter's share of its weight by day: rare on the first day, thicker as the
## days go (VISION §2: more of them as interference rises; there is no
## interference yet, so time stands in for it).
const HUNTER_SHARE_BY_DAY: Array[float] = [0.35, 0.7, 1.0]


static func is_hunter(row: Dictionary) -> bool:
	return row.get("disposition", &"hostile") == &"hostile" and row.get("approach", &"") != &"dart" \
			and row.get("hostile", true)


## The row's weight at this moment: weight_of, thinned for hunters early on.
static func weight_at(row: Dictionary, m: Moment) -> float:
	var w := weight_of(row)
	if is_hunter(row):
		w *= HUNTER_SHARE_BY_DAY[clampi(m.day() - 1, 0, HUNTER_SHARE_BY_DAY.size() - 1)]
	return w


## Does the row's moment (not its place) fit right now?
static func moment_fits(row: Dictionary, m: Moment) -> bool:
	var where: Dictionary = row.get("where", {})
	if m.day() < int(where.get("day_min", 1)):
		return false
	var hours: Array = where.get("hours", [])
	if hours.size() == 2 and not hour_in(m.hour(), float(hours[0]), float(hours[1])):
		return false
	var weather: Array = where.get("weather", [])
	if not weather.is_empty() and m.weather_strength > 0.05 and not weather.has(String(m.weather)):
		return false
	if where.get("calm", false) and absf(m.wind) > CALM_WIND:
		return false
	return true


## [from, to) in hours, wrapping past midnight when from > to (20-5 is curfew).
static func hour_in(h: float, from: float, to: float) -> bool:
	h = fposmod(h, 24.0)
	if from <= to:
		return h >= from and h < to
	return h >= from or h < to


## Does the row fit at this tile (landscape, ground, distance from a village,
## rise, props)? `kind` is the roster id, so a landscape that names this thing in
## its own roster (BiomeDef.roster) admits it whatever the row's own list says,
## and keeps it to the hours that roster gives it. `hour` < 0 skips the clock.
static func place_fits(row: Dictionary, world: WorldData, query: WorldQuery, tx: int, ty: int, kind: StringName = &"", hour: float = -1.0) -> bool:
	if not world.in_bounds(tx, ty):
		return false
	var g := world.ground_at(tx, ty)
	if g == Ground.DEEP_WATER:
		return false
	var where: Dictionary = row.get("where", {})
	var here := BiomeRegistry.by_index(world.country_at(tx, ty))
	var mine: Dictionary = here.roster.get(kind, {})
	var countries: Array = where.get("countries", [])
	if not countries.is_empty() and not countries.has(String(here.id)) and mine.is_empty():
		return false
	var hours: Variant = mine.get("hours")
	if hour >= 0.0 and hours is Vector2 and not hour_in(hour, (hours as Vector2).x, (hours as Vector2).y):
		return false
	# A landscape that took a thing onto its own roster says what it walks on
	# here, because a lander's grounds are not the grounds it was written for.
	var grounds: Array = mine.get("grounds", where.get("grounds", []))
	if not grounds.is_empty() and not ground_matches(g, grounds):
		return false
	var keeps: Array = row.get("keeps_to", [])
	if grounds.is_empty() and not keeps.is_empty() and not ground_matches(g, keeps):
		return false
	if keeps.is_empty() and Ground.is_water(g):
		return false
	var p := Vector2(tx + 0.5, ty + 0.5)
	var green := green_distance(world, p)
	if green < float(where.get("green_min", 0)):
		return false
	if where.has("green_max") and green > float(where.green_max):
		return false
	if where.get("rise", false) and not is_rise(world, tx, ty):
		return false
	var near: Array = where.get("near_props", [])
	if not near.is_empty():
		var kinds: Array[int] = []
		for n: String in near:
			var k := PropKind.NAMES.find(n)
			if k >= 0:
				kinds.append(k)
		if query == null or query.nearest_prop(p, NEAR_PROP, kinds) == null:
			return false
	return true

## A staging token for a body put out for a shot: `runner`, or `runner@-112` to
## say which way it faces (DEGREES, 0 east, 90 south, as `--face`). Boot's
## `--spawn`, the tour's `spawn` and the test that holds tours to their claims
## all read it here, so the three cannot drift apart.
##
## TO REPRODUCE A BEARING OFF `tests/models/test_machines_silhouette.gd`:
## **facing = -yaw**, and nothing else. That test rasterises the model turned by
## `Basis(UP, yaw)` through the GAME camera's own basis (euler -57, 45, the
## CameraRig's own numbers), and a body in the world is drawn at
## `rotation.y = -facing`, so the two meet with no correction for where the
## camera stands. The sweeper's worst fill is yaw 0.79 and the runner's 1.96,
## which are `@-45` and `@-112`.
static func staged(token: String) -> Dictionary:
	var at := token.strip_edges().split("@", false)
	var facing := NAN
	if at.size() > 1:
		facing = deg_to_rad(at[1].to_float())
	return {"id": Roster.resolve(at[0].strip_edges()) if not at.is_empty() else &"", "facing": facing}

## Ground names are the roster's; ones this world does not have are skipped.
static func ground_matches(g: int, names: Array) -> bool:
	if g < 0 or g >= Ground.NAMES.size():
		return false
	return names.has(Ground.NAMES[g])


## Chebyshev tiles to the nearest village green (INF if none).
static func green_distance(world: WorldData, p: Vector2) -> float:
	var best := INF
	for v: Dictionary in world.villages:
		best = minf(best, Senses.chebyshev(p, v.pos as Vector2))
	return best


static func is_rise(world: WorldData, tx: int, ty: int) -> bool:
	var l := world.level_at(tx, ty)
	var lower := 0
	for dy in range(-RISE_RADIUS, RISE_RADIUS + 1):
		for dx in range(-RISE_RADIUS, RISE_RADIUS + 1):
			var n := world.level_at(tx + dx, ty + dy)
			if n > l:
				return false
			if n < l:
				lower += 1
	return lower >= 6


## THE REAL QUESTION, when whoever owns the camera can ask it: `sees.call(p,
## margin)` answers true or false for a ground tile, or anything else to mean "ask
## the box". Empty by default, so every headless caller and every test gets the
## box, which is what this file has always been.
##
## It exists because the box is SYMMETRIC about the player and a perspective frame
## is not. Measured under the lens: 95.2 tiles ahead and 4.9 behind, against the
## box's 8.9 either way, and every distance of the 11..18 spawn ring lands at
## screen Y 160..232 of 1080 -- so the box called on-screen tiles unseen and
## machines materialised in full view (tests/render/test_read_reach.gd). A
## corrected constant cannot fix a wrong shape; asking the camera can. Core stays
## pure because it only ever holds a Callable, never a camera.
var sees: Callable = Callable()


## Is a point on the ground within the camera's view of a player at `centre`, with
## margin? Every caller in the game comes through here -- the roll, the patrol's
## start, the first meeting, the coast's "gone", the racket's "heard, not seen" and
## the staged spawn -- so spawning and culling cannot disagree about what is on
## the picture, which is the difference between a body that arrives and one that
## pops.
func in_view(centre: Vector2, p: Vector2, margin: float = 2.0) -> bool:
	if sees.is_valid():
		var asked: Variant = sees.call(p, margin)
		if asked is bool:
			return asked
	var yaw := deg_to_rad(yaw_deg)
	var right := Vector2(cos(yaw), -sin(yaw))
	var up := Vector2(-sin(yaw), -cos(yaw))
	var d := p - centre
	var half_h := view_height * 0.5
	var half_w := half_h * aspect
	var sx := absf(d.dot(right))
	var sy := absf(d.dot(up)) * sin(deg_to_rad(pitch_deg))
	return sx <= half_w + margin and sy <= half_h + margin


## One roll. Returns {kind, pos} or {} for nothing this time. `shut`: kinds
## that may not come out now (Coast's cooldowns), as keys.
func roll(roll_index: int, world: WorldData, query: WorldQuery, m: Moment, centre: Vector2, living: int, shut: Dictionary = {}) -> Dictionary:
	if living >= MAX_LIVING:
		return {}
	var fitting: Array[StringName] = []
	var sum := 0.0
	for k: StringName in Roster.DEFS:
		var row := Roster.row(k)
		if not shut.has(k) and moment_fits(row, m):
			fitting.append(k)
			sum += weight_at(row, m)
	if sum <= 0.0:
		return {}
	if Rng.hash_ints(m.seed_value, roll_index, 0x5a17) % 2000 >= int(sum * rate):
		return {}
	var r := Rng.make(m.seed_value, roll_index)
	for i in TILE_TRIES:
		var tile := ring_tile(r, centre)
		if in_view(centre, tile):
			continue
		var tx := floori(tile.x)
		var ty := floori(tile.y)
		var here: Array[StringName] = []
		var weight := 0.0
		for k in fitting:
			if place_fits(Roster.row(k), world, query, tx, ty, k, m.hour()):
				here.append(k)
				weight += weight_at(Roster.row(k), m)
		if here.is_empty() or weight <= 0.0:
			continue
		var pick := r.randf() * weight
		for k in here:
			pick -= weight_at(Roster.row(k), m)
			if pick < 0.0:
				return {"kind": k, "pos": Vector2(tx + 0.5, ty + 0.5)}
		return {"kind": here[here.size() - 1], "pos": Vector2(tx + 0.5, ty + 0.5)}
	return {}


## A tile in the square ring RING_MIN..RING_MAX around centre.
static func ring_tile(r: RandomNumberGenerator, centre: Vector2) -> Vector2:
	var d := r.randi_range(RING_MIN, RING_MAX)
	var along := r.randi_range(-d, d)
	var o := Vector2i.ZERO
	match r.randi_range(0, 3):
		0: o = Vector2i(along, -d)
		1: o = Vector2i(d, along)
		2: o = Vector2i(along, d)
		_: o = Vector2i(-d, along)
	return Vector2(floori(centre.x) + o.x + 0.5, floori(centre.y) + o.y + 0.5)


static func should_cull(mob_pos: Vector2, centre: Vector2, patrol: bool = false) -> bool:
	return Senses.chebyshev(mob_pos, centre) > (PATROL_CULL if patrol else CULL)


## Patrols: a worker on its round, put out where the player will see it cross
## the land at a distance and go on its way. The line passes the player at
## PATROL_PASS tiles, runs PATROL_LENGTH, and starts out of view.
const PATROL_PASS_MIN := 8.0
const PATROL_PASS_MAX := 11.0
const PATROL_LENGTH := 26.0
const PATROL_CULL := 34.0
const PATROL_TRIES := 8


## The kinds that go on rounds now: indifferent machines that walk (not errands, not darts).
static func patrol_kinds(m: Moment) -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in Roster.DEFS:
		var row := Roster.row(k)
		if row.get("machine", false) and row.get("disposition", &"hostile") == &"indifferent" \
				and not row.get("approach", &"") in [&"errand", &"dart"] and moment_fits(row, m):
			out.append(k)
	return out


## A worker's round past the player: {kind, from, to} or {}. The start is out
## of view, the line crosses the land about the player on walkable ground, and
## the worker fits where it starts and where it passes.
func patrol(roll_index: int, world: WorldData, query: WorldQuery, m: Moment, centre: Vector2) -> Dictionary:
	var kinds := patrol_kinds(m)
	if kinds.is_empty():
		return {}
	var r := Rng.make(m.seed_value, roll_index * 7 + 0x9a7)
	for i in PATROL_TRIES:
		var a := r.randf() * TAU
		var radial := Vector2.from_angle(a)
		var tangent := radial.orthogonal() * (1.0 if r.randf() < 0.5 else -1.0)
		var mid := centre + radial * r.randf_range(PATROL_PASS_MIN, PATROL_PASS_MAX)
		var from := mid - tangent * PATROL_LENGTH * 0.5
		var to := mid + tangent * PATROL_LENGTH * 0.5
		if in_view(centre, from) or not _walkable_line(world, query, from, to):
			continue
		var here: Array[StringName] = []
		for k in kinds:
			var row := _on_round(Roster.row(k))
			if place_fits(row, world, query, floori(from.x), floori(from.y), k, m.hour()) and place_fits(row, world, query, floori(mid.x), floori(mid.y), k, m.hour()):
				here.append(k)
		if here.is_empty():
			continue
		return {"kind": here[r.randi_range(0, here.size() - 1)], "from": from, "to": to}
	return {}


## A worker on its round keeps out of a village but passes nearer one than it
## would be put out to work: from the spawn, on a village's edge, the fields
## are where the first machines are seen.
const PATROL_GREEN := 12.0


static func _on_round(row: Dictionary) -> Dictionary:
	var where: Dictionary = row.get("where", {})
	if float(where.get("green_min", 0.0)) <= PATROL_GREEN:
		return row
	var r := row.duplicate()
	var w := where.duplicate()
	w["green_min"] = PATROL_GREEN
	r["where"] = w
	return r


## Dry ground all along, sampled every tile, with no cliff between two samples.
static func _walkable_line(world: WorldData, _query: WorldQuery, a: Vector2, b: Vector2) -> bool:
	var steps := maxi(1, ceili(a.distance_to(b)))
	var prev := Vector2i(floori(a.x), floori(a.y))
	for s in steps + 1:
		var p := a.lerp(b, float(s) / steps)
		var t := Vector2i(floori(p.x), floori(p.y))
		if not world.in_bounds(t.x, t.y) or Ground.is_water(world.ground_at(t.x, t.y)):
			return false
		if absi(world.level_at(prev.x, prev.y) - world.level_at(t.x, t.y)) > 1:
			return false
		prev = t
	return true


## Where the first meeting walks its round: from a tile FIRST_RING_MIN to
## FIRST_RING_MAX out (straight line), well inside the camera's view, further
## than `notice` (Chebyshev) so it is seen before it notices, on ground a hunter
## of `kind` could stand on at least FIRST_GREEN from a village; to a point
## FIRST_PASS beside the player, across their front, on walkable ground all the
## way. {from, to}, or {} if none this time.
const FIRST_RING_MIN := 8.0
const FIRST_RING_MAX := 10.5
const FIRST_GREEN := 10.0
const FIRST_PASS := 4.0
## Tiles inside the edge of the view the start must be.
const FIRST_VIEW_MARGIN := -1.0


func first_meeting_spot(roll_index: int, world: WorldData, query: WorldQuery, kind: StringName, centre: Vector2, notice: float) -> Dictionary:
	var r := Rng.make(roll_index, 0xf1257)
	var row := Roster.row(kind)
	var where: Dictionary = row.get("where", {})
	var grounds: Array = where.get("grounds", [])
	for i in TILE_TRIES * 3:
		var d := r.randf_range(FIRST_RING_MIN, FIRST_RING_MAX)
		var radial := Vector2.from_angle(r.randf() * TAU)
		var t := centre + radial * d
		var tile := Vector2i(floori(t.x), floori(t.y))
		if not world.in_bounds(tile.x, tile.y) or not in_view(centre, t, FIRST_VIEW_MARGIN):
			continue
		if Senses.chebyshev(t, centre) <= notice + 1.5:
			continue
		var g := world.ground_at(tile.x, tile.y)
		if Ground.is_water(g) or not query.standable(tile.x, tile.y):
			continue
		if not grounds.is_empty() and not ground_matches(g, grounds):
			continue
		if green_distance(world, t) < FIRST_GREEN:
			continue
		var side := 1.0 if r.randf() < 0.5 else -1.0
		var to := centre + radial.orthogonal() * side * FIRST_PASS + radial * 1.0
		if not world.in_bounds(floori(to.x), floori(to.y)) or not query.standable(floori(to.x), floori(to.y)):
			continue
		if not NavField.line_walkable(world, t, to) or not NavField.line_walkable(world, t, centre):
			continue
		return {"from": t, "to": to}
	return {}
