class_name CrackedRoof
extends RefCounted
## WHERE A ROOF HANGS CRACKED (FightSim.hangings, AbilityGrapple): stones of the
## lid a cave already has, worked out from the world as it stands at play time
## -- the lid WorldGen laid (WorldData.overhead) and the landscape's own
## `collapse` pressure (BiomeDef.hazards) -- and nothing written into the world,
## so no seed moves.
##
## The weak roof is the RIM of a tear: where the lid already gave way and let
## the day in, the stone round the hole hangs split, RIM_FROM..RIM_TO tiles in
## from open ground. One chance a CELL, the tile in it chosen by hash, taken at
## `collapse` x DENSITY; over ground a body stands on, with room under it for a
## stone over a person's head (MIN_ROOM levels). Pure and deterministic: the same
## world gives the same stones, so a stone brought down can be remembered by its
## tile and stay down.

const CELL := 4
const RIM_FROM := 1
const RIM_TO := 3
const DENSITY := 1.6
const MIN_ROOM := 8
## Its tip hangs TIP_OVER above the floor, in a body's reach and the eye's, however
## high the lid; and never less than MIN_HANG below the lid.
const TIP_OVER := 3.4
const MIN_HANG := 1.2
const SALT := 0x5a1ac


## The stones hanging within `r` tiles of `centre`: {key: Vector2i (its tile),
## at: Vector2, y: float (its tip's world height), top: float (the lid's)}.
static func stones_near(world: WorldData, centre: Vector2, r: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if world == null or not world.has_overhead():
		return out
	var c0 := Vector2i(floori((centre.x - r) / CELL), floori((centre.y - r) / CELL))
	var c1 := Vector2i(floori((centre.x + r) / CELL), floori((centre.y + r) / CELL))
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var s := stone_in(world, cx, cy)
			if not s.is_empty() and (s.at as Vector2).distance_to(centre) <= float(r):
				out.append(s)
	return out


## The stone in cell (cx, cy), or {}.
static func stone_in(world: WorldData, cx: int, cy: int) -> Dictionary:
	var seed_value := world.seed_value
	var tx := cx * CELL + int(Rng.hash01(seed_value, cx, cy, SALT) * CELL)
	var ty := cy * CELL + int(Rng.hash01(seed_value, cx, cy, SALT + 1) * CELL)
	if not world.in_bounds(tx, ty) or world.level_at(tx, ty) <= 0 or Ground.is_water(world.ground_at(tx, ty)):
		return {}
	var o := world.overhead_at(tx, ty)
	if o.x < 0 or world.headroom_at(tx, ty) < MIN_ROOM:
		return {}
	var p := Vector2(tx + 0.5, ty + 0.5)
	var collapse := float(BiomeRegistry.at(world, p).hazards.get(&"collapse", 0.0))
	if collapse <= 0.0 or Rng.hash01(seed_value, cx, cy, SALT + 2) >= collapse * DENSITY:
		return {}
	if not _on_rim(world, tx, ty):
		return {}
	var top := float(o.x) * WorldData.STEP
	var floor_y := float(world.level_at(tx, ty)) * WorldData.STEP
	return {"key": Vector2i(tx, ty), "at": p, "y": minf(floor_y + TIP_OVER, top - MIN_HANG), "top": top}


## Within RIM_TO tiles of land with nothing over it (a tear, a shaft's mouth), and
## not nearer than RIM_FROM.
static func _on_rim(world: WorldData, tx: int, ty: int) -> bool:
	var near := INF
	for dy in range(-RIM_TO, RIM_TO + 1):
		for dx in range(-RIM_TO, RIM_TO + 1):
			var x := tx + dx
			var y := ty + dy
			if not world.in_bounds(x, y) or world.level_at(x, y) <= 0:
				continue
			if world.overhead_at(x, y).x < 0:
				near = minf(near, float(maxi(absi(dx), absi(dy))))
	return near >= RIM_FROM and near <= RIM_TO
