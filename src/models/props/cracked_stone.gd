extends RefCounted
## A STONE OF THE ROOF HANGING CRACKED (CrackedRoof, FightSim.hangings): a thick
## stalactite of the cave's calcite, split through near its root where the lid
## gave round the tear, the split dark and rust-run, grit hanging from it. It must
## read from below as the one stone in the roof that will come down: fatter than
## the drips round it, its crack a dark band a hand wide, and a stain run down it.
## Held in sight (GroundColors.HELD): over the player it is the thing to see, and
## the cuts that open the roof over a body never open it. And its split GLOWS,
## cold, as the cave's own seams do under the lid (an ember mark: always lit):
## up in a black roof a lamp never reaches, the glowing crack is how a player finds
## the one stone that will come down.
##
## Built from its root down, local to the root at (0, 0, 0); `fallen` is the same
## stone lying on the floor in pieces where it came down.

const MARK := GroundColors.HELD
const LENGTH := 1.5
## The split's glow: an ember mark (strength / 8, lit at every hour), the seams' cold.
const SPLIT_MARK := 8
const SPLIT := Color(0.30, 0.78, 0.82)


static func _col(c: Color) -> Color:
	return Color(c.r, c.g, c.b, float(MARK) / 255.0)


## `length`: from the lid to its tip, world units.
static func mesh(seed_value: int, length: float = LENGTH) -> ArrayMesh:
	var lime := [_col(Palette.LINEN[3]), _col(Palette.LINEN[4]), _col(Palette.LINEN[4]), _col(Palette.SAND[4]), _col(Palette.LINEN[5]), _col(Palette.LINEN[4])]
	var crack := Color(SPLIT.r, SPLIT.g, SPLIT.b, float(SPLIT_MARK) / 255.0)
	var rust := _col(Palette.RUST[2])
	var k := FoundKit.matter_kit(Ink.NONE)
	var len := length
	# Thicker the longer it has grown.
	var r := (0.3 + Rng.hash01(seed_value, 2, 3) * 0.08) * clampf(length / LENGTH, 1.0, 1.8)
	# Turned UP from its tip, so its faces wind outward (a lathe down its length
	# turns them in, and from below the stone was not drawn at all).
	FoundKit.lathe(k, Vector3(0, -len, 0), Vector3.UP,
		[Vector2(0.0, 0.0), Vector2(r * 0.22, len * 0.08), Vector2(r * 0.6, len * 0.3), Vector2(r * 0.9, len * 0.65), Vector2(r * 0.95, len - 0.28), Vector2(r, len - 0.2)],
		8, lime, Rng.hash01(seed_value, 3, 3) * TAU)
	# The collar where it grew from the lid.
	FoundKit.lathe(k, Vector3(0, -0.2, 0), Vector3.UP, [Vector2(r, 0.0), Vector2(r * 1.15, 0.08), Vector2(r * 1.5, 0.22)], 8, lime)
	# The split: a glowing band round it a hand below the collar.
	FoundKit.lathe(k, Vector3(0, -0.34, 0), Vector3.UP, [Vector2(r * 1.06, 0.0), Vector2(r * 1.06, 0.12)], 8, [crack, crack, crack, crack, crack, crack])
	# And the split runs on down one face, glowing, the way it will break.
	var b0 := Rng.hash01(seed_value, 6, 3) * TAU
	var down := Vector3(cos(b0), 0, sin(b0))
	FoundKit.tbar(k, down * r * 1.02 + Vector3(0, -0.3, 0), down * r * 0.8 + Vector3(0, -len * 0.5, 0), 0.035, 0.015, 4, [crack, crack, crack, crack, crack, crack])
	# A stain run down from the split.
	var a := Rng.hash01(seed_value, 4, 3) * TAU
	var face := Vector3(cos(a), 0, sin(a))
	FoundKit.tbar(k, face * r * 0.98 + Vector3(0, -0.3, 0), face * r * 0.7 + Vector3(0, -len * 0.62, 0), 0.05, 0.02, 4, [rust, rust, rust, rust, rust, rust])
	# Grit hanging off the split.
	for j in 3:
		var b := a + (float(j) - 1.0) * 1.9
		var at := Vector3(cos(b), 0, sin(b)) * r * 0.95 + Vector3(0, -0.3, 0)
		var g := 0.1 + Rng.hash01(seed_value, j, 5) * 0.1
		FoundKit.lathe(k, at - Vector3(0, g, 0), Vector3.UP, [Vector2(0.0, 0.0), Vector2(0.03, g)], 4, lime)
	return k.build()


## The stone come down: broken in three on the floor, local to where it landed.
static func fallen(seed_value: int) -> ArrayMesh:
	var lime := [_col(Palette.LINEN[3]), _col(Palette.LINEN[4]), _col(Palette.LINEN[4]), _col(Palette.SAND[4]), _col(Palette.LINEN[4]), _col(Palette.LINEN[3])]
	var k := FoundKit.matter_kit(Ink.NONE)
	for j in 3:
		var a := Rng.hash01(seed_value, j, 7) * TAU
		var d := 0.2 + Rng.hash01(seed_value, j, 8) * 0.5
		var at := Vector3(cos(a) * d, 0.0, sin(a) * d)
		var along := Vector3(cos(a + 1.3), 0.0, sin(a + 1.3))
		var len := 0.35 + Rng.hash01(seed_value, j, 9) * 0.35
		FoundKit.lathe(k, at - along * len * 0.5 + Vector3(0, 0.14, 0), along, [Vector2(0.18 - j * 0.03, 0.0), Vector2(0.15, len * 0.6), Vector2(0.0, len)], 7, lime)
	for j in 5:
		var a := Rng.hash01(seed_value, j, 10) * TAU
		var d := 0.3 + Rng.hash01(seed_value, j, 11) * 0.6
		k.rock(cos(a) * d, 0.0, sin(a) * d, 0.08, 0.06, seed_value * 7 + j, lime[j % 6], 5)
	return k.build()
