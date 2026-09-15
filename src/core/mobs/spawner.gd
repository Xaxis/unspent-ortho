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

## The camera the view test assumes (CameraRig defaults).
var yaw_deg := 45.0
var pitch_deg := 57.0
var view_height := 14.0
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


## Does the row fit at this tile (country, ground, distance from a village, rise, props)?
static func place_fits(row: Dictionary, world: WorldData, query: WorldQuery, tx: int, ty: int) -> bool:
	if not world.in_bounds(tx, ty):
		return false
	var g := world.ground_at(tx, ty)
	if g == Ground.DEEP_WATER:
		return false
	var where: Dictionary = row.get("where", {})
	var countries: Array = where.get("countries", [])
	if not countries.is_empty():
		var c := world.country_at(tx, ty)
		if c < 0 or c >= Country.NAMES.size() or not countries.has(Country.NAMES[c]):
			return false
	var grounds: Array = where.get("grounds", [])
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


## Is a point on the ground within the camera's view of a player at `centre`, with margin?
func in_view(centre: Vector2, p: Vector2, margin: float = 2.0) -> bool:
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
			sum += weight_of(row)
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
			if place_fits(Roster.row(k), world, query, tx, ty):
				here.append(k)
				weight += weight_of(Roster.row(k))
		if here.is_empty() or weight <= 0.0:
			continue
		var pick := r.randf() * weight
		for k in here:
			pick -= weight_of(Roster.row(k))
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


static func should_cull(mob_pos: Vector2, centre: Vector2) -> bool:
	return Senses.chebyshev(mob_pos, centre) > CULL
