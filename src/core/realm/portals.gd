class_name Portals
## Where the ways between realms ARE. Pure and deterministic: a world decides its
## own shafts, so the surface shaft a player found last week is in the same place
## this week, and the hall it comes out in is the same hall.
##
##   Portals.in_world(w) -> Array[Portal]    every shaft in `w`, in a fixed order
##   Portals.paired(w, id) -> Portal         the shaft `id` on THIS side
##   Portals.landing(w, id) -> Vector2       where a body arrives out of shaft id
##
## Pairing is by INDEX, not by coordinate: shaft 0 of the surface opens onto
## shaft 0 of the underground, and back. Two realms are two islands grown from
## two seeds (Realm.seed_for) and share no coordinates at all, so a pairing by
## position would have to move one realm's geography to suit the other's — which
## is what an era portal does (the same coordinates in another time, VISION §4)
## and what a realm portal must not.
##
## A shaft stands where the machines already had the rock open: one per REGION,
## biggest region first, on bare ground at the foot of a tall face, clear of the
## villages and the roads. A region that has no such place has no shaft, and the
## indices close up, so a world always has shaft 0 if it has any at all.

## At most this many shafts in one world: a handful is a map a player can hold.
const MOST := 4
## Tiles between the coarse candidates a region is searched on. Three is fine
## enough to find the foot of every face worth cutting and coarse enough that a
## 512-tile world is searched in a few milliseconds.
const STRIDE := 3
## Levels the ground must rise within LOOK tiles for a face to be worth sinking a
## shaft at: the machines cut where the rock was already standing open.
const FACE_RISE := 2
const FACE_LOOK := 3
## Tiles clear of a village's core. A road and any solid prop are read off one
## mask built for the whole world (GenPlaces.solid_mask), not asked prop by prop:
## a 512-tile world holds tens of thousands of props and this is a search over
## thousands of candidates.
const CLEAR_VILLAGE := 14.0
## Tiles from the nearest other shaft: two mouths in one hillside is one mouth.
const APART := 60.0
## A shaft is sunk inland, never on a shore: the ground has to be land this far
## out in every direction (a share of the world's width, so a small test island
## is not ruled out entirely). A mouth on a beach is a mouth a player walks out
## of into a frame of open water, which says the wrong thing about both realms.
const INLAND := 0.07
## Tiles a shaft keeps clear of where the player wakes (a share of the world's
## width). A way out of the realm lying at a player's feet on the first morning
## is not a place found, and on a small world — where the only ground that passes
## the rules above is the middle of the island, which is also where the spawn is
## — that is exactly where it landed.
const CLEAR_SPAWN := 0.09
## Tiles out from the mouth a body arrives on, along the way the shaft faces, so
## nobody lands inside the gate they just came through and goes straight back.
const STEP_OFF := 2.2

## Grounds a shaft is cut in. Bare rock and what falls off it — never turf, never
## a floor somebody swept, never sand or water.
const IN_ROCK: Array[int] = [Ground.ROCK, Ground.SCREE, Ground.GRAVEL, Ground.LIMESTONE,
	Ground.BONE, Ground.SHINGLE, Ground.CLINKER]

static var _cache: Dictionary = {}


## Every shaft in `w`. Held per world, because a system asks every frame and the
## search reads a region's whole bounding box.
static func in_world(w: WorldData) -> Array[Portal]:
	if w == null:
		return []
	var key := "%d:%d:%s" % [w.seed_value, w.size, w.realm]
	if _cache.has(key):
		return _cache[key]
	var out := _lay(w)
	_cache[key] = out
	return out


static func forget() -> void:
	_cache.clear()


static func count(w: WorldData) -> int:
	return in_world(w).size()


## Shaft `id` in `w` (wrapping, so a realm with fewer shafts than its neighbour
## still answers for every one of the neighbour's), or null in a world with none.
static func paired(w: WorldData, id: int) -> Portal:
	var all := in_world(w)
	if all.is_empty():
		return null
	return all[posmod(id, all.size())]


## The shaft in `w` nearest to `p`, or null.
static func nearest(w: WorldData, p: Vector2) -> Portal:
	var best: Portal = null
	var best_d := INF
	for q in in_world(w):
		var d := q.pos.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = q
	return best


## Where a body arrives in `w` out of shaft `id`: a step out of the mouth along
## the way it faces, pulled onto the nearest ground it can stand on.
static func landing(w: WorldData, id: int) -> Vector2:
	var q := paired(w, id)
	if q == null:
		return w.spawn
	var out := q.pos + Vector2.from_angle(q.facing) * STEP_OFF
	return standing(w, out, q.pos)


## The nearest tile to `p` a body can stand on, searched outward; `fallback` is
## what comes back when nothing near it will do.
static func standing(w: WorldData, p: Vector2, fallback: Vector2) -> Vector2:
	var solid := GenPlaces.solid_mask(w)
	var px := floori(p.x)
	var py := floori(p.y)
	for r in 8:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				if _stands(w, solid, px + dx, py + dy):
					return Vector2(px + dx + 0.5, py + dy + 0.5)
	return fallback


# --- laying them -------------------------------------------------------------

static func _lay(w: WorldData) -> Array[Portal]:
	var out: Array[Portal] = []
	var to := Realm.beyond(w.realm)
	var solid := GenPlaces.solid_mask(w)
	for region: Dictionary in w.regions:
		if out.size() >= MOST:
			break
		var found := _in_region(w, solid, region, out, 0)
		if found == null:
			continue
		found.region = int(region.get("id", -1))
		out.append(found)
	# EVERY world has a way out of it, or a realm can be generated and never
	# reached — and a small island, a world with no region big enough to be a
	# place, or a shape with no cliff foot inland would all be one. So the rule
	# is loosened a step at a time rather than given up on: any bare rock, then
	# any ground at all, then wherever a body can stand near the spawn.
	for ease: int in [1, 2]:
		if not out.is_empty():
			break
		var one := _whole(w, solid, ease)
		if one != null:
			out.append(one)
	if out.is_empty():
		var last := Portal.new()
		var away := maxf(8.0, w.size * CLEAR_SPAWN)
		last.pos = standing(w, w.spawn + Vector2(away, away) * 0.71, w.spawn)
		out.append(last)
	for i in out.size():
		out[i].id = i
		out[i].realm = w.realm
		out[i].to_realm = to
	return out


## The best shaft head in one region, or null.
static func _in_region(w: WorldData, solid: PackedByteArray, region: Dictionary, taken: Array[Portal], ease: int) -> Portal:
	var b: Rect2 = region.get("bounds", Rect2())
	if b.size.x < 8.0 or b.size.y < 8.0:
		return null
	var id := int(region.get("id", -1))
	var best: Portal = null
	var best_score := 0.0
	var y := int(b.position.y)
	while y < int(b.end.y):
		var x := int(b.position.x)
		while x < int(b.end.x):
			if w.region_at(x, y) == id:
				var score := _score(w, solid, x, y, taken, ease)
				if score > best_score:
					best_score = score
					best = _at(w, x, y)
			x += STRIDE
		y += STRIDE
	return best


## The best shaft head anywhere in the world at leniency `ease`.
static func _whole(w: WorldData, solid: PackedByteArray, ease: int) -> Portal:
	var best: Portal = null
	var best_score := 0.0
	var empty: Array[Portal] = []
	var y := 3
	while y < w.size - 3:
		var x := 3
		while x < w.size - 3:
			var score := _score(w, solid, x, y, empty, ease)
			if score > best_score:
				best_score = score
				best = _at(w, x, y)
			x += STRIDE
		y += STRIDE
	return best


## How good a shaft head this tile is, 0 for none. The rock has to be standing
## open beside it, and the tile itself has to be one a body can walk up to.
## `ease` loosens it for a world that has no such place: 1 wants no face, 2 will
## take any ground.
static func _score(w: WorldData, solid: PackedByteArray, x: int, y: int, taken: Array[Portal], ease: int) -> float:
	if not _stands(w, solid, x, y):
		return 0.0
	if ease < 2 and not IN_ROCK.has(w.ground_at(x, y)):
		return 0.0
	var here := w.level_at(x, y)
	# The face: how far the ground stands above this tile within FACE_LOOK, and
	# which way the open ground lies (the shaft is cut facing away from the rock).
	var rise := 0
	var away := Vector2.ZERO
	for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var up := w.level_at(x + d.x * FACE_LOOK, y + d.y * FACE_LOOK) - here
		rise = maxi(rise, up)
		away -= Vector2(d.x, d.y) * float(up)
	if ease < 1 and rise < FACE_RISE:
		return 0.0
	var inland := maxi(6, int(w.size * INLAND))
	for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP,
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		if w.level_at(x + d.x * inland, y + d.y * inland) <= 0:
			return 0.0
	var at := Vector2(x + 0.5, y + 0.5)
	if at.distance_to(w.spawn) < maxf(8.0, w.size * CLEAR_SPAWN):
		return 0.0
	for v: Dictionary in w.villages:
		if at.distance_to(v.pos as Vector2) < CLEAR_VILLAGE:
			return 0.0
	for q in taken:
		if at.distance_to(q.pos) < APART:
			return 0.0
	# Room in front of it, so the gate is not drawn into a crack: the four tiles
	# the open side lies on have to be walkable too.
	var face := away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	for step: float in [1.5, 2.5, 3.5]:
		var f := at + face * step
		if not _stands(w, solid, floori(f.x), floori(f.y)):
			return 0.0
	return float(rise) + Rng.hash01(w.seed_value, x, y, 0x5AF7) * 0.9


static func _at(w: WorldData, x: int, y: int) -> Portal:
	var p := Portal.new()
	p.pos = Vector2(x + 0.5, y + 0.5)
	var here := w.level_at(x, y)
	var away := Vector2.ZERO
	for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		away -= Vector2(d.x, d.y) * float(w.level_at(x + d.x * FACE_LOOK, y + d.y * FACE_LOOK) - here)
	p.facing = away.angle() if away.length() > 0.01 else 0.0
	return p


## A tile a body can walk onto: land, out of the water, off the road, not under a
## solid prop, and no cliff step to its neighbours.
static func _stands(w: WorldData, solid: PackedByteArray, x: int, y: int) -> bool:
	if x < 3 or y < 3 or x >= w.size - 3 or y >= w.size - 3:
		return false
	var i := y * w.size + x
	if w.level[i] < 1 or Ground.is_water(w.ground[i]) or w.ground[i] == Ground.ROAD:
		return false
	if solid[i] != 0:
		return false
	var l := w.level[i]
	if absi(w.level[i - 1] - l) > 1 or absi(w.level[i + 1] - l) > 1:
		return false
	return absi(w.level[i - w.size] - l) <= 1 and absi(w.level[i + w.size] - l) <= 1
