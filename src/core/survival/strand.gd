class_name Strand
## The way in, within a walk of the spawn: driftwood and wrack along the strand,
## mussel rock at the water's edge, and a tip of old plate inland. The first
## hours of the game run on these (a fire, food, a haft, the first pick), so a
## world that lacks them near the spawn has them laid here, the same way every
## time for a seed.
##
## The generator is the proper place for all of it. Until it places them this
## fills the gap, and it steps back kind by kind: whatever the generator already
## put within reach of the spawn is counted, and only the shortfall is laid.
##
##   Strand.lay(game) -> Array[WorldProp]   lay the shortfall (50_survival calls it at setup)
##   Strand.plan(game) -> Array[Dictionary] {kind, pos} it would lay, laying nothing

## Tiles from the spawn that count as within a walk.
const RADIUS := 34.0
## A tip may be a longer walk: it is a place you set out for.
const TIP_RADIUS := 60.0
## How many of each the first hours want in reach.
const WANT := {PropKind.DRIFTWOOD: 8, PropKind.WRACK: 4, PropKind.MUSSEL_ROCK: 4}
const TIP_HEAPS := 3
## Laid things keep this far apart, so a strand reads as a scatter and not a row.
const SPACING := 2.6
const SHORE_GROUNDS: Array[int] = [Ground.SAND, Ground.SHINGLE, Ground.MUD]


static func lay(game: Game) -> Array[WorldProp]:
	var out: Array[WorldProp] = []
	for p: Dictionary in plan(game):
		out.append(Survival.add_prop(game, int(p.kind), p.pos, float(p.rot), float(p.scale)))
	return out


static func plan(game: Game) -> Array[Dictionary]:
	var w := game.world
	var home := w.spawn
	var laid: Array[Dictionary] = []
	var have := {}
	# WorldQuery.props_near can hand back a prop twice when its square runs off the
	# map's side (tile keys wrap into the next row), so count each prop once.
	var seen := {}
	for q in game.query.props_near(home, TIP_RADIUS):
		var r := TIP_RADIUS if q.kind == PropKind.TIP else RADIUS
		if not seen.has(q.id) and q.pos.distance_to(home) <= r and not game.world.depleted.has(q.id):
			seen[q.id] = true
			have[q.kind] = int(have.get(q.kind, 0)) + 1
	var shore := _shore_tiles(w, home)
	for kind: int in WANT:
		var short := int(WANT[kind]) - int(have.get(kind, 0))
		if short <= 0:
			continue
		# Mussels cling where the water touches; wood and weed lie a step up the beach.
		var reach := 1 if kind == PropKind.MUSSEL_ROCK else 2
		var candidates: Array = []
		for t: Dictionary in shore:
			if int(t.water) <= reach:
				candidates.append(t)
		_pick(game, laid, candidates, kind, short, 11 + kind)
	if int(have.get(PropKind.TIP, 0)) == 0:
		_lay_tip(game, laid)
	return laid


## Land tiles of the strand within RADIUS: {tile: Vector2i, water: tiles to the sea (1..2), d: from home}.
static func _shore_tiles(w: WorldData, home: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := int(RADIUS)
	var hx := floori(home.x)
	var hy := floori(home.y)
	for y in range(hy - r, hy + r + 1):
		for x in range(hx - r, hx + r + 1):
			if not w.in_bounds(x, y) or w.level_at(x, y) <= 0:
				continue
			if not SHORE_GROUNDS.has(w.ground_at(x, y)):
				continue
			var d := Vector2(x + 0.5, y + 0.5).distance_to(home)
			if d > RADIUS:
				continue
			var water := 3
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if Ground.is_water(w.ground_at(x + dx, y + dy)) or w.level_at(x + dx, y + dy) <= 0:
						water = mini(water, maxi(absi(dx), absi(dy)))
			if water <= 2:
				out.append({"tile": Vector2i(x, y), "water": water, "d": d})
	return out


## Choose `n` of `candidates` for `kind`: nearer home first, shuffled by the seed so
## the strand is scattered, never on another prop or on something laid.
static func _pick(game: Game, laid: Array[Dictionary], candidates: Array, kind: int, n: int, salt: int) -> void:
	var w := game.world
	var s := w.seed_value
	var scored: Array = []
	for t: Dictionary in candidates:
		var tile: Vector2i = t.tile
		scored.append([Rng.hash01(s, tile.x, tile.y, salt) + float(t.d) / RADIUS * 0.9, t])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var got := 0
	for pair: Array in scored:
		if got >= n:
			return
		var tile: Vector2i = (pair[1] as Dictionary).tile
		var pos := Vector2(tile.x + 0.25 + Rng.hash01(s, tile.x, tile.y, salt + 1) * 0.5,
			tile.y + 0.25 + Rng.hash01(s, tile.x, tile.y, salt + 2) * 0.5)
		if not _room(game, laid, pos, PropKind.SOLID[kind], SPACING):
			continue
		laid.append({"kind": kind, "pos": pos, "rot": Rng.hash01(s, tile.x, tile.y, salt + 3) * TAU,
			"scale": 0.8 + Rng.hash01(s, tile.x, tile.y, salt + 4) * 0.4})
		got += 1


## A tip: a few heaps on flat dry ground that is not beach, a short way inland.
static func _lay_tip(game: Game, laid: Array[Dictionary]) -> void:
	var w := game.world
	var s := w.seed_value
	var home := w.spawn
	var best := Vector2(INF, INF)
	var best_score := INF
	var r := int(TIP_RADIUS)
	for y in range(maxi(1, floori(home.y) - r), mini(w.size - 1, floori(home.y) + r + 1), 2):
		for x in range(maxi(1, floori(home.x) - r), mini(w.size - 1, floori(home.x) + r + 1), 2):
			var c := Vector2(x + 0.5, y + 0.5)
			var d := c.distance_to(home)
			if d < 8.0 or d > TIP_RADIUS:
				continue
			# A walk of about sixteen tiles is best; the seed breaks the ties.
			var score := absf(d - 16.0) / 16.0 + Rng.hash01(s, x, y, 41) * 0.6
			if score >= best_score:
				continue
			var level := w.level_at(x, y)
			var g := w.ground_at(x, y)
			if level <= 0 or Ground.is_water(g) or SHORE_GROUNDS.has(g) or g == Ground.ROAD:
				continue
			# Somewhere the whole heap fits: flat for two tiles around, and clear.
			if not _flat(w, x, y, 2, level) or not _room(game, laid, c, 2.4, 0.0):
				continue
			best_score = score
			best = c
	if not best.is_finite():
		return
	var solid: float = PropKind.SOLID[PropKind.TIP]
	for i in TIP_HEAPS:
		var a := float(i) / TIP_HEAPS * TAU + Rng.hash01(s, i, 43) * 0.8
		var pos := best + Vector2.from_angle(a) * (0.0 if i == 0 else 2.3 + Rng.hash01(s, i, 44) * 0.4)
		if i > 0 and not _room(game, laid, pos, solid, 0.0):
			continue
		laid.append({"kind": PropKind.TIP, "pos": pos, "rot": Rng.hash01(s, i, 45) * TAU, "scale": 0.85 + Rng.hash01(s, i, 46) * 0.3})


static func _flat(w: WorldData, x: int, y: int, r: int, level: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if w.level_at(x + dx, y + dy) != level or Ground.is_water(w.ground_at(x + dx, y + dy)):
				return false
	return true


## Nothing standing or already laid within `radius` + its own body + `spacing`.
static func _room(game: Game, laid: Array[Dictionary], pos: Vector2, radius: float, spacing: float) -> bool:
	for q in game.query.props_near(pos, radius + 3.0):
		var gap := maxf(q.solid, 0.3) + radius + 0.35
		if q.kind == PropKind.HOUSE:
			gap += 2.0
		if q.pos.distance_squared_to(pos) < gap * gap:
			return false
	for p: Dictionary in laid:
		var gap := maxf(float(PropKind.SOLID[int(p.kind)]), 0.3) + radius + 0.35
		gap = maxf(gap, spacing) if int(p.kind) != PropKind.TIP else maxf(gap, 2.2)
		if (p.pos as Vector2).distance_squared_to(pos) < gap * gap:
			return false
	return true
