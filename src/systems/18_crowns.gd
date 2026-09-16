extends GameSystem
## A fight is never hidden by a tree. Crowns and leaves standing over the player,
## or over any body near enough for the player to be dealing with, thin out to
## stipple and then go (world.gdshader `crown_clear`, cut by a world-pinned
## stipple, never a fade). Trunks, walls and the land stay: only geometry that
## sways and stands clear of the ground can open up, so a wood still reads as a
## wood from a step away.
##
## Written every frame on the one world material WorldView hands out. A slot is
## (x, the ground's own height there, z, reach in tiles); reach 0 is unused.

## Slots in world.gdshader's crown_clear array.
const SLOTS := 6
## Tiles of clear ground round a point: gone inside about 0.7 of it, thinning to
## nothing by the whole of it, so the hole is never a hard disc.
const REACH := 1.6
## A mob this far from the player is part of the same moment and gets its own.
const NEAR := 14.0
## What a body must stand above its own ground before a leaf counts as in the
## way, and the sway weight below which geometry never opens at all: both are
## world.gdshader's, held to it by tests/render/test_crowns.gd.
const LIFT := 0.85
const SWAY_MIN := 0.25

var _mat: ShaderMaterial
var _slots := PackedVector4Array()
var _pos: Array[Vector2] = []
var _hostile := PackedByteArray()
var _aware := PackedByteArray()


func setup(g: Game) -> void:
	super.setup(g)
	_slots.resize(SLOTS)
	_mat = g.view.world_material() if g.view != null else null
	if _mat != null:
		_mat.set_shader_parameter("crown_clear", _slots)


func _process(_delta: float) -> void:
	if _mat == null or game == null or game.player == null:
		return
	var here: Vector2 = game.player.pos
	_pos.clear()
	_hostile.clear()
	_aware.clear()
	for m in get_tree().get_nodes_in_group(&"mobs"):
		if not bool(m.get(&"alive")):
			continue
		var p: Vector2 = m.get(&"pos")
		if p.distance_to(here) > NEAR:
			continue
		_pos.append(p)
		_hostile.append(1 if bool(m.get(&"hostile")) else 0)
		_aware.append(1 if bool(m.get(&"aware")) else 0)
	fill(_slots, here, choose(_pos, _hostile, _aware, here, SLOTS - 1),
		func(p: Vector2) -> float: return game.view.surface_height(p))
	_mat.set_shader_parameter("crown_clear", _slots)


## Which bodies get a clearing when more are near than there are slots. The
## group hands them over in whatever order they were added, so taking the first
## few let a flock of gulls twelve tiles off fill every slot and leave the
## machine swinging at the player two tiles away under a crown — the one case
## the clearing exists for. Ranked instead: a body that has noticed the player
## comes before one that has not, a hostile before a pest, and then the nearest.
## Pure: `pos[i]`, `hostile[i]` and `aware[i]` describe the same body.
static func choose(pos: Array[Vector2], hostile: PackedByteArray, aware: PackedByteArray,
		player: Vector2, limit: int) -> Array[Vector2]:
	var order: Array[int] = []
	for i in pos.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var ra := int(aware[a]) * 2 + int(hostile[a])
		var rb := int(aware[b]) * 2 + int(hostile[b])
		if ra != rb:
			return ra > rb
		return pos[a].distance_squared_to(player) < pos[b].distance_squared_to(player))
	var out: Array[Vector2] = []
	for i in mini(limit, order.size()):
		out.append(pos[order[i]])
	return out


## Lay the player and the bodies about them into `slots`, tallest priority first,
## and blank the rest. `ground` answers the drawn height under a point. Pure
## given its inputs: the player always takes slot 0, so a crowd never crowds the
## player out of their own clearing.
static func fill(slots: PackedVector4Array, player: Vector2, mobs: Array[Vector2], ground: Callable) -> void:
	slots[0] = Vector4(player.x, ground.call(player), player.y, REACH)
	var n := mini(mobs.size(), slots.size() - 1)
	for i in n:
		var p: Vector2 = mobs[i]
		slots[i + 1] = Vector4(p.x, ground.call(p), p.y, REACH)
	for i in range(n + 1, slots.size()):
		slots[i] = Vector4.ZERO
