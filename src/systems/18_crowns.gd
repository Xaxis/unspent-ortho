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

var _mat: ShaderMaterial
var _slots := PackedVector4Array()


func setup(g: Game) -> void:
	super.setup(g)
	_slots.resize(SLOTS)
	_mat = g.view.world_material() if g.view != null else null
	if _mat != null:
		_mat.set_shader_parameter("crown_clear", _slots)


func _process(_delta: float) -> void:
	if _mat == null or game == null or game.player == null:
		return
	var mobs: Array[Vector2] = []
	for m in get_tree().get_nodes_in_group(&"mobs"):
		if mobs.size() >= SLOTS - 1:
			break
		if not bool(m.get(&"alive")):
			continue
		var p: Vector2 = m.get(&"pos")
		if p.distance_to(game.player.pos) <= NEAR:
			mobs.append(p)
	fill(_slots, game.player.pos, mobs, func(p: Vector2) -> float: return game.view.surface_height(p))
	_mat.set_shader_parameter("crown_clear", _slots)


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
