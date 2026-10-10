extends RefCounted
## The buried old world (docs/SALVAGE.md): where the land is cut, the ground the
## cities stood on shows through it, and that is where metal comes from. Nobody
## alive mines rock. A slab of road deck fringed with its rebar, a split duct
## spilling cable, a drift of dead appliances, a power station's coal tip.
##
## All of it was CAST or MADE in the old world, so it is drawn in the found pen
## (exact edges) and weathered by the land: rust runs, broken aggregate, snow on
## it in the cold. Two variants each, as the ores were (`PropModels.variants`),
## so no world deals a different hand.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
const Rocks := preload("res://src/models/props/rocks.gd")


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.REBAR_SLAB: rebar_slab(k, v, c)
		PropKind.CABLE_DUCT: cable_duct(k, v, c)
		PropKind.BOARD_DRIFT: board_drift(k, v, c)
		PropKind.COAL_TIP: coal_tip(k, v, c)
	var d := BiomeDressing.of(c)
	if d.cold():
		k.clump(-0.1, 0.1, 0.0, 0.34, 0.14, 9100 + kind * 7 + v, d.snow[0], 6)


## The land's concrete, or a plain grey where a landscape names none.
static func _concrete(c: int) -> Color:
	var d := BiomeDressing.of(c)
	var base: Color = d.concrete if d.concrete.a > 0.0 else P.STONE[3]
	return base.lerp(Rocks.geology(c)[0], 0.2)


## A thick round line through `pts`: cable, hose, a flex. Six sides a piece, so
## it reads as round from every bearing (`Kit.cable`'s three read as a strip).
static func _line(k: Kit, pts: Array[Vector3], r: float, col: Color) -> void:
	for i in pts.size() - 1:
		k.rod(pts[i], pts[i + 1], r, 6, col)


## A loop of cable from `a` to `b`, heaved `lift` above the ground at its middle
## and swung `swing` to one side, in `n` pieces.
static func _loop(a: Vector3, b: Vector3, lift: float, swing: Vector3, n: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in n + 1:
		var t := float(i) / n
		var bow := 4.0 * t * (1.0 - t)
		out.append(a.lerp(b, t) + Vector3(0.0, lift * bow, 0.0) + swing * bow)
	return out


## Rebar: a slab of road deck broken out of the ground and tilted, its torn edge
## rough with aggregate and fringed with both mats of bars it was cast round; or
## a pier sheared at the knee with its cage bent out of the break. Rust weeps
## down from every bar.
static func rebar_slab(k: Kit, v: int, c: int) -> void:
	var s := 7600 + v * 41 + c
	var concrete := _concrete(c)
	var torn := GroundColors.down(concrete, 0.18)
	if v == 0:
		k.found.push(Transform3D(Basis(Vector3.BACK, 0.3) * Basis(Vector3.RIGHT, -0.1), Vector3(0.0, -0.1, 0.0)))
		k.chamfer(-0.08, 0.0, 0.0, 0.94, 0.26, 0.84, 0.06, concrete, GroundColors.up(concrete, 0.12))
		# The torn edge: broken aggregate, not a cut face.
		for i in 4:
			var z := -0.33 + i * 0.22
			Rocks.faceted(k, Vector3(0.4, 0.0, z), Vector3(0.14, 0.26, 0.12), 8, s + i, torn if i % 2 else GroundColors.down(torn, 0.1))
		# Both mats of bars out of the break, cut short, bent where they tore.
		var roots: Array = []
		var ends: Array = []
		for i in 7:
			var z := -0.36 + i * 0.12
			var y := 0.06 if i % 2 == 0 else 0.2
			roots.append(Vector3(0.42, y, z))
			var reach := 0.16 + Rng.hash01(s, i) * 0.26
			var droop := -0.08 + Rng.hash01(s, i, 2) * 0.3
			ends.append(Vector3(0.48 + reach, y + droop, z + Kit.j(s, i + 9, 0.1)))
		Rocks.rebar(k, roots, ends)
		k.found.pop()
		Rocks.rust_run(k, Vector3(-0.08, 0.06, 0.425), 0.1, 0.12, Vector3(0, 0, 1))
		# A piece broken off the edge, a bar still in it.
		k.found.push(Transform3D(Basis(Vector3.UP, 0.6) * Basis(Vector3.BACK, -0.3), Vector3(0.82, -0.05, 0.4)))
		k.chamfer(0.0, 0.0, 0.0, 0.3, 0.16, 0.24, 0.04, torn, concrete)
		k.found.pop()
		k.rod(Vector3(0.74, 0.08, 0.36), Vector3(1.02, 0.16, 0.5), 0.016, 4, P.RUST[2])
	else:
		# A pier sheared at the knee, standing out of the ground it fell into.
		var tops: Array[float] = [0.86, 0.7, 0.62, 0.58, 0.66, 0.8, 0.94, 0.98]
		k.found.push(Transform3D(Basis(Vector3.BACK, -0.12), Vector3.ZERO))
		Rocks.cast_leg(k, 0.6, 0.52, 0.09, -0.1, tops, 0.74, concrete, torn)
		Rocks.rebar(k, [Vector3(-0.2, 0.8, 0.16), Vector3(0.18, 0.66, 0.18), Vector3(-0.18, 0.84, -0.16), Vector3(0.2, 0.62, -0.17), Vector3(0.0, 0.76, 0.2)],
			[Vector3(-0.42, 0.96, 0.3), Vector3(0.4, 0.62, 0.42), Vector3(-0.3, 1.06, -0.3), Vector3(0.46, 0.84, -0.26), Vector3(0.04, 1.02, 0.4)])
		Rocks.rust_run(k, Vector3(0.18, 0.55, 0.262), 0.08, 0.5, Vector3(0, 0, 1))
		Rocks.rust_run(k, Vector3(0.302, 0.52, -0.04), 0.07, 0.42, Vector3(1, 0, 0))
		k.found.pop()
		# The deck it carried, fallen against it.
		k.found.push(Transform3D(Basis(Vector3.UP, -0.5) * Basis(Vector3.RIGHT, 0.5), Vector3(-0.5, -0.06, 0.32)))
		k.chamfer(0.0, 0.0, 0.0, 0.62, 0.14, 0.4, 0.04, GroundColors.down(concrete, 0.08), concrete)
		k.found.pop()
		Rocks.faceted(k, Vector3(0.46, -0.04, 0.3), Vector3(0.14, 0.18, 0.12), 8, s + 9, torn)
	# Ochre where the rust has bled into the ground.
	k.stone(0.62, -0.06, -0.22, 0.12, 0.05, s + 30, P.RUST[3], 5)


## Cable: a duct split open in the ground, its lid slewed off, and the armoured
## cable it carried heaved out of it in loops, one end cut through to the copper;
## or a pit with its cover prised up and the runs looping out of it.
static func cable_duct(k: Kit, v: int, c: int) -> void:
	var s := 7700 + v * 41 + c
	var concrete := _concrete(c)
	var sheath := P.INK[2]
	var armour := P.PLATE[2]
	if v == 0:
		# The trough's two walls, one heaved and leaning out.
		k.chamfer(0.0, -0.12, -0.24, 1.2, 0.3, 0.14, 0.03, concrete)
		k.found.push(Transform3D(Basis(Vector3.RIGHT, -0.32), Vector3(0.0, -0.12, 0.26)))
		k.chamfer(0.0, 0.0, 0.0, 1.2, 0.3, 0.14, 0.03, GroundColors.down(concrete, 0.08))
		k.found.pop()
		k.found.push(Transform3D(Basis(Vector3.UP, 0.42) * Basis(Vector3.BACK, 0.18), Vector3(-0.34, 0.12, -0.46)))
		k.chamfer(0.0, 0.0, 0.0, 0.58, 0.08, 0.46, 0.03, GroundColors.up(concrete, 0.1))
		k.found.pop()
		# Three runs heaved out where the ground moved, none of them alike.
		_line(k, _loop(Vector3(-0.64, 0.0, -0.06), Vector3(0.6, 0.0, 0.02), 0.46, Vector3(0.0, 0.0, 0.3), 6), 0.05, sheath)
		_line(k, _loop(Vector3(-0.6, 0.0, 0.06), Vector3(0.2, 0.04, 0.0), 0.22, Vector3(0.0, 0.0, -0.18), 5), 0.045, armour)
		_line(k, _loop(Vector3(-0.1, 0.0, -0.1), Vector3(0.66, 0.0, -0.12), 0.3, Vector3(0.12, 0.0, 0.0), 5), 0.04, sheath)
		_cut_end(k, s, Vector3(0.2, 0.04, 0.0), Vector3(0.62, 0.32, 0.24), sheath)
		# Verdigris down the far wall's inner face, where the copper weeps.
		k.found.quad(Vector3(0.42, 0.17, -0.165), Vector3(0.3, 0.17, -0.165), Vector3(0.28, -0.06, -0.165), Vector3(0.44, -0.06, -0.165), P.SPRUCE[4].lerp(concrete, 0.35))
	else:
		# The pit's kerb set in the ground, dark inside, its cover prised up.
		k.chamfer(0.0, -0.1, 0.0, 0.86, 0.2, 0.86, 0.08, concrete, P.INK[1])
		k.found.push(Transform3D(Basis(Vector3.RIGHT, -0.75), Vector3(0.0, 0.1, -0.4)))
		k.plate(Vector3(-0.36, 0.0, 0.0), Vector3(-0.36, 0.0, 0.62), Vector3(0.36, 0.0, 0.62), Vector3(0.36, 0.0, 0.0), P.PLATE[3], P.PLATE[1], P.RUST[2])
		k.found.pop()
		for i in 3:
			var a := float(i) * 2.1 + 0.5
			var out := Vector3(cos(a), 0.0, sin(a))
			_line(k, _loop(out * 0.14 + Vector3(0.0, 0.08, 0.0), out * (0.66 + Rng.hash01(s, i) * 0.2) + Vector3(0.0, -0.04, 0.0), 0.2 + Rng.hash01(s, i, 2) * 0.16, out.cross(Vector3.UP) * 0.12, 5), 0.045, sheath if i % 2 else armour)
		_cut_end(k, s, Vector3(-0.08, 0.1, 0.06), Vector3(-0.26, 0.5, 0.2), sheath)


## A run cut through: the sheath stops and the copper fans out of it.
static func _cut_end(k: Kit, s: int, from: Vector3, cut: Vector3, sheath: Color) -> void:
	_line(k, _loop(from, cut, 0.06, Vector3.ZERO, 3), 0.05, sheath)
	var on := (cut - from).normalized()
	for i in 5:
		var spread := Vector3(Kit.j(s, i + 20, 0.07), Kit.j(s, i + 21, 0.07), Kit.j(s, i + 22, 0.07))
		k.rod(cut, cut + on * 0.12 + spread, 0.009, 3, P.COPPER[3] if i % 2 else P.COPPER[4])


## Boards: a slump of dead appliances where a landfill's face came down: a
## washing machine on its side with its round door, a screen gone dark, and
## circuit boards standing out of the spill, green, with the chips on them and
## the solder bright along their edge.
static func board_drift(k: Kit, v: int, c: int) -> void:
	var s := 10900 + v * 17 + c
	var spill := GroundColors.down(Rocks.geology(c)[0], 0.1).lerp(P.EARTH[3], 0.5)
	var enamel := P.LINEN[4].lerp(P.SAND[4], 0.5)
	var board := P.SPRUCE[5].lerp(P.MOSS[5], 0.4)
	k.clump(0.0, -0.12, 0.0, 0.7, 0.3 + v * 0.08, s, spill, 9)
	k.clump(0.46, -0.1, -0.32, 0.36, 0.2, s + 1, GroundColors.down(spill, 0.12), 7)
	# The washing machine on its back, the door up to the sky, round and dark,
	# its rim bright.
	k.found.push(Transform3D(Basis(Vector3.UP, 0.4 + v * 0.8) * Basis(Vector3.RIGHT, 0.2), Vector3(-0.28, 0.12, 0.08)))
	k.chamfer(0.0, -0.22, 0.0, 0.44, 0.44, 0.42, 0.04, enamel, GroundColors.down(enamel, 0.2))
	k.found.prism(0.0, 0.22, 0.0, 0.14, 0.235, 0.14, 12, P.INK[2], P.INK[1])
	k.hoop(Vector3(0.0, 0.235, 0.0), 0.15, 12, 0.018, P.STONE[5])
	k.found.pop()
	# A screen face-up in the spill, dark and cracked across.
	# It lies on the bank, so it rides as high as the bank does (v 1's is taller).
	k.found.push(Transform3D(Basis(Vector3.UP, 0.25) * Basis(Vector3.RIGHT, -0.15), Vector3(0.22, 0.2 + v * 0.1, -0.3)))
	k.plate(Vector3(-0.24, 0.0, 0.0), Vector3(-0.24, 0.0, 0.32), Vector3(0.24, 0.0, 0.32), Vector3(0.24, 0.0, 0.0), P.INK[2], P.STONE[2], P.STONE[3])
	k.found.quad(Vector3(-0.2, 0.014, 0.04), Vector3(-0.17, 0.014, 0.04), Vector3(0.18, 0.014, 0.28), Vector3(0.15, 0.014, 0.28), P.STONE[4])
	k.found.pop()
	# The boards on edge out of the spill: chips, and the solder along the top.
	for i in 3 + v:
		var a := -1.2 + i * 1.0 + Kit.j(s, i, 0.25)
		var at := Vector3(cos(a) * 0.36, 0.14 + v * 0.08 + Rng.hash01(s, i, 4) * 0.06, sin(a) * 0.32 + 0.1)
		# Turned to the play camera's quarter (+x +z), so a board shows its face.
		k.found.push(Transform3D(Basis(Vector3.UP, PI * 0.25 + Kit.j(s, i + 7, 0.6)) * Basis(Vector3.BACK, Kit.j(s, i + 5, 0.4)), at))
		k.found.quad(Vector3(-0.16, 0.0, 0.0), Vector3(0.16, 0.0, 0.0), Vector3(0.16, 0.26, 0.0), Vector3(-0.16, 0.26, 0.0), board)
		k.found.quad(Vector3(0.16, 0.0, -0.008), Vector3(-0.16, 0.0, -0.008), Vector3(-0.16, 0.26, -0.008), Vector3(0.16, 0.26, -0.008), GroundColors.down(board, 0.12))
		k.found.quad(Vector3(-0.1, 0.09, 0.009), Vector3(0.0, 0.09, 0.009), Vector3(0.0, 0.17, 0.009), Vector3(-0.1, 0.17, 0.009), P.INK[1])
		k.found.quad(Vector3(0.04, 0.05, 0.009), Vector3(0.11, 0.05, 0.009), Vector3(0.11, 0.12, 0.009), Vector3(0.04, 0.12, 0.009), P.INK[1])
		k.found.quad(Vector3(-0.16, 0.235, 0.01), Vector3(0.16, 0.235, 0.01), Vector3(0.16, 0.26, 0.01), Vector3(-0.16, 0.26, 0.01), P.STONE[5])
		k.found.pop()
	# A flex out of the machine, trailed into the spill.
	_line(k, _loop(Vector3(-0.1, 0.24, 0.24), Vector3(0.58, -0.02, 0.52), 0.1, Vector3(0.1, 0.0, 0.0), 4), 0.018, P.INK[2])


## Coal: the tip a dead power station left, a low black bank with the glint in
## its seams, a rusted hopper fallen on it and a conveyor's end out of the spoil;
## or an open skip on its side with the coal run out of its mouth.
static func coal_tip(k: Kit, v: int, c: int) -> void:
	var s := 7800 + v * 41 + c
	var coal := P.INK[1]
	var glint := GroundColors.glint(P.INK[1])
	k.clump(0.0, -0.12, 0.0, 0.76, 0.42, s, coal, 9)
	k.clump(-0.34, -0.1, 0.32, 0.36, 0.2, s + 1, P.INK[2], 7)
	for i in 6:
		var a := float(i) * 1.1 + 0.3
		k.stone(0.55 + cos(a) * 0.3, -0.03, 0.25 + sin(a) * 0.25, 0.07, 0.06, s + 30 + i, glint if i % 2 else P.INK[2], 4)
	if v == 0:
		# A hopper: a rusted funnel on short legs, fallen over on the bank.
		k.found.push(Transform3D(Basis(Vector3.BACK, 1.1) * Basis(Vector3.UP, 0.4), Vector3(-0.18, 0.36, -0.2)))
		k.found.prism(0.0, 0.0, 0.0, 0.08, 0.3, 0.3, 4, P.RUST[2], P.RUST[3], PI * 0.25)
		for i in 4:
			var a := PI * 0.25 + i * PI * 0.5
			k.rod(Vector3(cos(a) * 0.2, 0.2, sin(a) * 0.2), Vector3(cos(a) * 0.24, -0.16, sin(a) * 0.24), 0.016, 4, P.RUST[1])
		k.found.pop()
		# The conveyor's end: two rails and the rollers between them.
		for side: float in [-1.0, 1.0]:
			k.rod(Vector3(0.2, 0.32, 0.12 * side - 0.1), Vector3(0.86, 0.08, 0.12 * side - 0.1), 0.018, 4, P.RUST[2])
		for i in 4:
			var t := 0.2 + i * 0.2
			var p := Vector3(0.2, 0.32, -0.1).lerp(Vector3(0.86, 0.08, -0.1), t)
			k.rod(p + Vector3(0, 0.02, -0.13), p + Vector3(0, 0.02, 0.13), 0.022, 6, P.PLATE[2])
	else:
		# An open skip on its side, its mouth to the bank, coal run out of it:
		# a floor, two raked ends and a back, the mouth left open.
		var steel := P.RUST[2]
		var inner := GroundColors.down(P.RUST[1], 0.3)
		k.found.push(Transform3D(Basis(Vector3.UP, 0.5), Vector3(0.34, -0.06, -0.24)))
		k.found.quad(Vector3(-0.32, 0.0, 0.22), Vector3(0.32, 0.0, 0.22), Vector3(0.32, 0.5, 0.22), Vector3(-0.32, 0.5, 0.22), steel)
		k.found.quad(Vector3(0.32, 0.0, 0.2), Vector3(-0.32, 0.0, 0.2), Vector3(-0.32, 0.5, 0.2), Vector3(0.32, 0.5, 0.2), inner)
		for side: float in [-1.0, 1.0]:
			var x := 0.32 * side
			k.found.quad(Vector3(x, 0.0, -0.2), Vector3(x, 0.0, 0.2), Vector3(x, 0.5, 0.2), Vector3(x, 0.5, -0.06), inner if side > 0.0 else steel)
			k.found.quad(Vector3(x, 0.0, 0.2), Vector3(x, 0.0, -0.2), Vector3(x, 0.5, -0.06), Vector3(x, 0.5, 0.2), steel if side > 0.0 else inner)
			k.rod(Vector3(x, 0.5, -0.06), Vector3(x, 0.5, 0.2), 0.02, 4, P.RUST[3])
		k.found.pop()
		k.clump(0.22, -0.08, 0.02, 0.32, 0.18, s + 2, coal, 7)
