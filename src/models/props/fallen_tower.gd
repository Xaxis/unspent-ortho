extends RefCounted
## A TOPPLED SKYSCRAPER (the owner's idea 8, "dense rainforest over decaying,
## toppled human cities and skyscrapers"): a city tower lying on its side through
## the canopy, broken where it hit into sections that lie a little apart and a
## little askew, each break showing the floors inside like ribs, and the forest
## grown along its length. From above it is a ridge of storeys running through
## the trees; at eye level a wall of glazing lying down, taller than a person.
##
## The storeys are Towers.shaft's own -- the same slabs, glazing bands and wear a
## standing tower is built of -- laid on their side, so a fallen tower and the
## standing ones round it are the same buildings. The growth on it is the land's
## own (BiomeDef.tree_tints), so it grows green in the green towers and would
## grow whatever grows wherever else one is dealt.
##
## A model faces +X, and a fallen tower runs along +X from its root (the stump of
## its ground floor, where the one circle a prop gets stops a body); what lies
## further along is climbed over or walked round.
##
##   tools/shot.sh shots/fallen_tower.png --scene=gallery --filter="fallen tower"

const Kit := preload("res://src/models/props/kit.gd")
const Towers := preload("res://src/models/props/towers.gd")
const Trees := preload("res://src/models/props/trees.gd")
const P := preload("res://src/render/palette.gd")

## Storeys in each broken section, per variant: a long fall, a short one broken
## twice, and one whose top section lies well away.
const SECTIONS: Array = [[4, 3, 3], [3, 3], [4, 4, 2]]
## The tower's plan: as wide as it is deep, a standing tower's.
const W := 2.5
const D := 2.9


static func build(k: Kit, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	var dress := BiomeDressing.of(c)
	var s := 9400 + v * 37 + c * 5
	var runs: Array = SECTIONS[v % SECTIONS.size()]
	var x := 0.3
	for i in runs.size():
		var n: int = runs[i]
		var len := float(n) * Towers.STOREY
		var last := i == runs.size() - 1
		# Each section lies a little askew and a little sunk, as it came down.
		var yaw := Kit.j(s, 10 + i, 0.14)
		var roll := Kit.j(s, 20 + i, 0.08)
		var sink := 0.25 + Rng.hash01(s, i, 30) * 0.35
		var at := Vector3(x, W * 0.5 - sink, Kit.j(s, 40 + i, 0.3))
		# What stands out of the break past the last storey: bare floor plates.
		var ribs := 0 if last else 1 + int(Rng.hash01(s, i, 60) * 2.0)
		# A standing shaft's +Y laid along +X: the tower's floors now stand as
		# walls across its length, and its faces lie up and down. Everything the
		# section carries is drawn standing, in that frame.
		var lay := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, roll) * Basis(Vector3.BACK, -PI * 0.5), at)
		var made_from := k.made.vertex_count()
		k.made.push(lay)
		k.found.push(lay)
		var top := Towers.shaft(k, W, D, n, 0.0, s + i * 101, c, false)
		var slab := GroundColors.made(GroundColors.down(dress.concrete, 0.2), GroundColors.CONCRETE)
		# The foot: the root's torn ground floor, or the snapped end of a length
		# that fell away from the one before it. Dark inside either way.
		_end(k, 0.0, s + i * 3)
		if last:
			# The crown: the roof slab, whole, the one end that never broke.
			k.slab(0.0, top, 0.0, W + 0.1, 0.16, D + 0.1, s + 9, slab, GroundColors.up(slab, 0.15), 0.02)
		else:
			_end(k, top, s + i * 3 + 1)
			_ribs(k, top, ribs, s + i * 7, slab)
		k.found.pop()
		k.made.pop()
		_drop_underside(k.made, made_from)
		var reach := len + float(ribs) * Towers.STOREY
		if not last:
			_rubble(k, at + Basis(Vector3.UP, yaw) * Vector3(reach, 0.0, 0.0), s + i * 11, dress)
		_growth(k, at, yaw, len, s + i * 19, c)
		x += reach + 0.3 + Rng.hash01(s, i, 50) * 0.6


## The face a laid length rests on points at the ground and is sunk into it: no
## bearing of the play camera sees it (tests/render/test_found_drawn), so its
## triangles are taken back out of `pen` from vertex `from` on.
static func _drop_underside(pen: MeshKit, from: int) -> void:
	var keep := PackedInt32Array()
	for t in range(from, pen.verts.size(), 3):
		if pen.normals[t].y > -0.7:
			keep.append(t)
	if keep.size() * 3 == pen.verts.size() - from:
		return
	var verts := pen.verts.slice(0, from)
	var normals := pen.normals.slice(0, from)
	var colors := pen.colors.slice(0, from)
	var uvs := pen.uvs.slice(0, from)
	var uv2s := pen.uv2s.slice(0, from)
	var custom := pen.custom0.slice(0, from * 4)
	for t in keep:
		for v in range(t, t + 3):
			verts.append(pen.verts[v])
			normals.append(pen.normals[v])
			colors.append(pen.colors[v])
			uvs.append(pen.uvs[v])
			uv2s.append(pen.uv2s[v])
			for q in 4:
				custom.append(pen.custom0[v * 4 + q])
	pen.verts = verts
	pen.normals = normals
	pen.colors = colors
	pen.uvs = uvs
	pen.uv2s = uv2s
	pen.custom0 = custom


## The inside of a snapped length, seen at its broken end: dark, a hair inside
## the storey's walls, which are open at both ends.
static func _end(k: Kit, y: float, s: int) -> void:
	var dark := P.INK[1]
	k.slab(0.0, y - 0.03, 0.0, W * 0.94, 0.03, D * 0.94, s, dark, dark, 0.01)


## THE RIBS: past the snapped end, the floor plates it tore out of the next
## length, each hung on its columns, bare of any wall, broken off short and
## narrower the further out; bars bent out of the last. Drawn standing.
static func _ribs(k: Kit, top: float, n: int, s: int, slab: Color) -> void:
	var col := GroundColors.down(slab, 0.12)
	var prev := top
	for r in n:
		var y := top + Towers.STOREY * float(r + 1)
		var keep := 0.78 - 0.2 * float(r) - Rng.hash01(s, r, 1) * 0.3
		var off := (1.0 - keep) * W * 0.5 * (1.0 if Rng.hash01(s, r, 2) < 0.5 else -1.0)
		k.slab(off, y, Kit.j(s, r, 0.08), W * keep, Towers.SLAB, D * (0.5 + Rng.hash01(s, r, 3) * 0.35), s + r * 5, col, GroundColors.up(col, 0.18), 0.06, 0.0, Kit.j(s, r + 4, 0.1))
		# Its columns, the ones still standing up to it; the rest snapped short.
		for q in 4:
			var cx := (W * 0.44) * (1.0 if q % 2 == 0 else -1.0)
			var cz := (D * 0.42) * (1.0 if q < 2 else -1.0)
			var hold := Rng.hash01(s, r * 4 + q, 6)
			var reach := Towers.STOREY if hold < 0.55 else Towers.STOREY * (0.25 + hold * 0.4)
			k.slab(cx, prev, cz, 0.14, reach, 0.14, s + r * 9 + q, col, col, 0.02)
			if hold >= 0.55:
				var tip := Vector3(cx, prev + reach, cz)
				k.rod(tip, tip + Vector3(Kit.j(s, q, 0.25), 0.35, Kit.j(s, q + 9, 0.25)), 0.014, 4, P.RUST[2])
		prev = y
	# The bars the last plate snapped off: bent out of its edge.
	for b in 5:
		var at := Vector3((float(b) / 4.0 - 0.5) * W * 0.8, prev + Towers.SLAB * 0.5, D * 0.4 * (1.0 if b % 2 == 0 else -1.0))
		k.rod(at, at + Vector3(Kit.j(s, b + 20, 0.2), 0.25 + Rng.hash01(s, b, 21) * 0.3, 0.2 * signf(at.z)), 0.012, 4, P.RUST[2])


## Rubble spilled under a break, round `o` on the ground.
static func _rubble(k: Kit, o: Vector3, s: int, dress: BiomeDressing) -> void:
	for i in 6:
		var a := Rng.hash01(s, i, 7) * TAU
		var r := 0.3 + Rng.hash01(s, i, 8) * 0.9
		k.stone(o.x + cos(a) * r, -0.06, o.z + sin(a) * r, 0.12 + Rng.hash01(s, i, 9) * 0.16, 0.12, s + 60 + i, dress.stone[i % 3], 5)


## The forest along one length: saplings rooted in the cracks along its top at
## `at` (turned `yaw`), crowns grown out of it, roots run down its side to the
## ground.
static func _growth(k: Kit, at: Vector3, yaw: float, length: float, s: int, c: int) -> void:
	var b := Basis(Vector3.UP, yaw)
	var top := at.y + W * 0.5
	var leaves := BiomeDressing.tint(c, &"leaf", [P.MOSS[2], P.MOSS[3], P.SPRUCE[3], P.MOSS[4]])
	var trunk := BiomeDressing.tint1(c, &"trunk", P.EARTH[2])
	var start := k.leaf.vertex_count()
	var n := 1 + int(length / 2.5)
	var x0 := 0.4
	length -= 0.8
	for i in n:
		var x := x0 + length * (float(i) + 0.5) / float(n) + Kit.j(s, 70 + i, 0.4)
		var z := Kit.j(s, 80 + i, 0.7)
		var h := 0.9 + Rng.hash01(s, i, 81) * 1.4
		var foot := at + b * Vector3(x, W * 0.5 - 0.15, z)
		var crown := foot + Vector3(Kit.j(s, 90 + i, 0.3), h, Kit.j(s, 95 + i, 0.3))
		k.limb(foot, crown, 0.07, 0.035, 5, trunk)
		var mass: Array[Color] = [leaves[i % 3], leaves[(i + 1) % 3], leaves[3]]
		var r := 0.45 + h * 0.2
		k.canopy(crown.x, crown.y - 0.3, crown.z, r, 0.6 + h * 0.2, s + i * 13, mass, Kit.LEAF_BROAD, Trees.BROAD_CARD, Trees.leaf_cards(r, 0.6 + h * 0.2, Trees.BROAD_CARD))
		# A root down the side to where it found the ground.
		if i % 2 == 0:
			var side := 1.0 if Rng.hash01(s, i, 85) < 0.5 else -1.0
			var ground := at + b * Vector3(x + 0.2, 0.0, side * (D * 0.5 + 0.35))
			k.limb(foot + b * Vector3(0.0, 0.0, side * 0.3), Vector3(ground.x, -0.05, ground.z), 0.04, 0.02, 4, trunk)
	k.sway_by_height(start, top, top + 3.0, 0.5, k.leaf)
