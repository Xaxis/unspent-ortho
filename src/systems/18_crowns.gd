extends GameSystem
## A fight is never hidden by a tree. Crowns and leaves standing over the player,
## or over any body near enough for the player to be dealing with, thin out to
## stipple and then go (world.gdshader `crown_clear`, cut by a world-pinned
## stipple, never a fade). Trunks, walls and the land stay: only geometry that
## sways and stands clear of the ground can open up, so a wood still reads as a
## wood from a step away.
##
## Written every frame on the world material WorldView hands out, and on its leaf
## material, which cuts a canopy's cards by the same rule (leaf.gdshader). A slot
## is (x, the ground's own height there, z, reach in tiles); reach 0 is unused.

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
var _leaf: ShaderMaterial
var _slots := PackedVector4Array()
var _pos: Array[Vector2] = []
var _hostile := PackedByteArray()
var _aware := PackedByteArray()


func setup(g: Game) -> void:
	super.setup(g)
	_slots.resize(SLOTS)
	_mat = g.view.world_material() if g.view != null else null
	_leaf = g.view.leaf_material() if g.view != null else null
	if _mat != null:
		_mat.set_shader_parameter("crown_clear", _slots)
	_set_tall_floor()
	if _leaf != null:
		_leaf.set_shader_parameter("crown_clear", _slots)


## How short a BUILT thing has to be before it may stand between the camera and
## the player. The world does not decide this, the CAMERA does: at the play
## pitch of 57 the eye sees over a two-metre post, and under the third-person
## lens at 30 it does not. Written here because this file already holds the
## world material; the shader defaults to 3.0, so the orthographic game is
## unchanged whether this runs or not.
func _set_tall_floor() -> void:
	var cam := game.camera if game != null else null
	if cam == null or _mat == null:
		return
	var floor_now := 3.0
	if cam.lens == &"persp":
		# The flatter the eye, the shorter a thing has to be to cover you:
		# 3.0 scaled by the ratio of the two pitches' 1/tan, which is what the
		# shader's own `cam_lean` measures.
		floor_now = 3.0 * (1.0 / tan(deg_to_rad(CameraRig.PITCH_DEG))) \
			/ (1.0 / tan(deg_to_rad(CameraRig.LENS_PITCH)))
	_mat.set_shader_parameter("tall_floor", floor_now)
	if _leaf != null:
		_leaf.set_shader_parameter("tall_floor", floor_now)


func _process(_delta: float) -> void:
	if _mat == null or game == null or game.player == null:
		return
	var here: Vector2 = game.player.pos
	_pos.clear()
	_hostile.clear()
	_aware.clear()
	for m: Node in get_tree().get_nodes_in_group(&"mobs"):
		# Read as the rest of the game does: a body in the group answers for
		# `alive`, `pos`, `hostile` and `aware`, and anything that does not is
		# not one (75_music, 70_audio).
		var alive: Variant = m.get(&"alive")
		var pos: Variant = m.get(&"pos")
		if (alive is bool and not alive) or not pos is Vector2:
			continue
		var p := pos as Vector2
		if p.distance_to(here) > NEAR:
			continue
		var hostile: Variant = m.get(&"hostile")
		var aware: Variant = m.get(&"aware")
		_pos.append(p)
		_hostile.append(0 if hostile is bool and not hostile else 1)
		_aware.append(1 if aware is bool and aware else 0)
	fill(_slots, here, choose(_pos, _hostile, _aware, here, SLOTS - 1),
		func(p: Vector2) -> float: return game.view.surface_height(p))
	_mat.set_shader_parameter("crown_clear", _slots)
	if _leaf != null:
		_leaf.set_shader_parameter("crown_clear", _slots)


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
