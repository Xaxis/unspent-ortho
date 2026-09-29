extends RefCounted
## THE STEEL DOCUMENT BOX AT THE HOLDFAST'S CAMP, USED AS A TABLE (StoryContent
## STOOD, `handler_note`). Left where his handler met him; the crew have eaten
## off its lid for years and never opened it. A long low service box in worn
## paint, its hasp rusted shut, up on two blocks at the height a sitting man eats
## at; on the lid a tin plate with a spoon across it, and a mug. The box is FOUND stock (ruled, exact: it was made in a factory), the
## blocks MADE (hatched). Plain colours on every found piece: a made mark there
## reads as a lamp built into it and blinks (kit.gd).
##
## A model faces +X: its long side runs along X.
##
##   tools/shot.sh shots/doc_box.png --scene=gallery --filter="document box"

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")

## The box, in tiles: long, deep, tall, and the height its blocks raise it.
const LONG := 1.05
const DEEP := 0.55
const TALL := 0.34
const RAISE := 0.3


static func build(k: Kit, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	var s := 10300 + v * 17 + c * 5
	var paint := P.MOSS[3].lerp(P.PLATE[4], 0.35)
	var worn := P.MOSS[4].lerp(P.LINEN[3], 0.4)
	var rust := P.RUST[2]
	var top := RAISE + TALL
	# The two blocks it stands on, one under each end: cinder, chipped.
	for side: float in [-1.0, 1.0]:
		k.slab(side * LONG * 0.34, -0.02, 0.0, 0.3, RAISE + 0.02, DEEP * 0.8, s + int(side + 2.0), P.ASH[2].lerp(P.EARTH[3], 0.3), P.ASH[3], 0.07, 0.08)
	# The box: body, and a lid a finger proud of it all round.
	k.chamfer(0.0, RAISE, 0.0, LONG, TALL - 0.05, DEEP, 0.03, paint, worn)
	k.chamfer(0.0, top - 0.05, 0.0, LONG + 0.04, 0.05, DEEP + 0.04, 0.015, worn, paint.lerp(P.LINEN[3], 0.2))
	# Rust where the paint went first: the corners and the seam under the lid.
	for side: float in [-1.0, 1.0]:
		k.found.quad(Vector3(side * LONG * 0.5 + side * 0.001, RAISE + 0.02, -DEEP * 0.5), Vector3(side * LONG * 0.5 + side * 0.001, RAISE + 0.02, DEEP * 0.5),
			Vector3(side * LONG * 0.5 + side * 0.001, RAISE + 0.12, DEEP * 0.5), Vector3(side * LONG * 0.5 + side * 0.001, RAISE + 0.12, -DEEP * 0.5), rust)
	k.found.quad(Vector3(-LONG * 0.5, top - 0.07, DEEP * 0.5 + 0.002), Vector3(LONG * 0.5, top - 0.07, DEEP * 0.5 + 0.002),
		Vector3(LONG * 0.5, top - 0.05, DEEP * 0.5 + 0.002), Vector3(-LONG * 0.5, top - 0.05, DEEP * 0.5 + 0.002), rust)
	# Carry handles at the ends, and the hasp on the front, rusted shut.
	for side: float in [-1.0, 1.0]:
		var x := side * (LONG * 0.5 + 0.03)
		k.rod(Vector3(x, top - 0.13, -0.12), Vector3(x, top - 0.13, 0.12), 0.012, 5, P.PLATE[4])
	k.chamfer(0.0, top - 0.16, DEEP * 0.5 + 0.015, 0.08, 0.11, 0.03, 0.005, rust, P.RUST[3])
	# A stencilled stripe the paint still holds: somebody's inventory, once.
	k.found.quad(Vector3(-0.3, RAISE + 0.12, DEEP * 0.5 + 0.003), Vector3(-0.08, RAISE + 0.12, DEEP * 0.5 + 0.003),
		Vector3(-0.08, RAISE + 0.17, DEEP * 0.5 + 0.003), Vector3(-0.3, RAISE + 0.17, DEEP * 0.5 + 0.003), P.LINEN[3])
	# On the lid: a tin plate with a spoon across it, and a mug.
	var px := -0.18 + Kit.j(s, 1, 0.04)
	var pz := -0.04 + Kit.j(s, 2, 0.04)
	k.found.prism(px, top, pz, 0.13, top + 0.012, 0.15, 12, P.ASH[3], P.ASH[4])
	k.rod(Vector3(px - 0.1, top + 0.02, pz - 0.03), Vector3(px + 0.09, top + 0.018, pz + 0.05), 0.008, 4, P.PLATE[5])
	var mx := 0.27 + Kit.j(s, 3, 0.03)
	var mz := 0.08 + Kit.j(s, 4, 0.03)
	k.found.prism(mx, top, mz, 0.05, top + 0.11, 0.052, 10, P.COLD[2], P.LINEN[4])
	k.hoop(Vector3(mx + 0.065, top + 0.055, mz), 0.03, 8, 0.008, P.COLD[2], Vector3.BACK)
