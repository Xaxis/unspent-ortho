extends RefCounted
## Stone: boulders, ore nodes, standing stones, clints, cairns, mussel rock and
## peat banks. The rock takes the country's geology: slate on the coast, mossy
## in the wet, snow-capped in the cold, pale limestone on the bones, basalt in
## the burning. Ore shows as bright facets on the faces toward the camera.
## What the machine age cast (a standing stone that is a concrete leg with bent
## rebar, a lens set on a cairn, a pipe through a peat face) is FOUND.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c) if kind != PropKind.PEAT_BANK else Ink.STIPPLE)
	match kind:
		PropKind.BOULDER: boulder(k, v, c)
		PropKind.STONE_ORE: stone_ore(k, v, c)
		PropKind.IRON_ORE: iron_ore(k, v, c)
		PropKind.COPPER_ORE: copper_ore(k, v, c)
		PropKind.COAL_ORE: coal_ore(k, v, c)
		PropKind.TIN_ORE: tin_ore(k, v, c)
		PropKind.STANDING_STONE: standing_stone(k, v, c)
		PropKind.CLINTS: clints(k, v, c)
		PropKind.CAIRN: cairn(k, v, c)
		PropKind.MUSSEL_ROCK: mussel_rock(k, v, c)
		PropKind.PEAT_BANK: peat_bank(k, v, c)


## Rock colour of a country: [body, shadowed body, what lies on top].
static func geology(c: int) -> Array[Color]:
	match c:
		Country.MOSS: return [P.SLATE[2], P.SLATE[1], P.MOSS[2]]
		Country.PINEWOOD: return [P.SLATE[2].lerp(P.SPRUCE[2], 0.3), P.SLATE[1], P.MOSS[2].lerp(P.SPRUCE[3], 0.4)]
		Country.SNOWFIELD: return [P.SLATE[3].lerp(P.RIME[3], 0.3), P.SLATE[2], P.RIME[5]]
		Country.BONELANDS: return [P.LINEN[3], P.LINEN[2], P.LINEN[4]]
		Country.BURNING: return [P.STONE[1], P.STONE[0], P.RUST[2]]
	return [P.SLATE[3], P.SLATE[2], P.LINEN[3]]


static func boulder(k: Kit, v: int, c: int) -> void:
	var g := geology(c)
	var s := 7000 + v * 37 + c
	var sides := 5 if c == Country.BONELANDS else 7
	var top := 0.0
	match v % 4:
		0:
			k.stone(0, -0.06, 0, 0.52, 0.72, s, g[0], sides, 0.12)
			top = 0.66
		1:
			k.stone(-0.12, -0.06, 0.05, 0.42, 0.6, s, g[0], sides, -0.1)
			k.stone(0.34, -0.06, -0.2, 0.26, 0.36, s + 1, g[1], 5, 0.2)
			top = 0.54
		2:
			# A flat slab split along its bedding, one half slipped.
			k.stone(-0.08, -0.06, 0, 0.6, 0.34, s, g[0], sides, 0.05)
			k.stone(0.26, -0.04, 0.12, 0.34, 0.3, s + 2, g[1], 5, 0.3)
			top = 0.3
		_:
			k.stone(0.02, -0.06, 0, 0.36, 1.05, s, g[0], sides, 0.18)
			k.stone(-0.34, -0.06, 0.24, 0.2, 0.3, s + 3, g[1], 5, -0.2)
			top = 0.95
	var cap_r: float = [0.32, 0.26, 0.4, 0.18][v % 4]
	match c:
		Country.SNOWFIELD:
			k.clump(0.06, top - 0.06, 0.0, cap_r + 0.04, 0.14, s + 9, P.RIME[5], 6)
		Country.MOSS, Country.PINEWOOD:
			k.clump(-0.06, top - 0.08, 0.03, cap_r, 0.12, s + 9, g[2], 6)
		Country.BURNING:
			k.fleck(Vector3(0.3, 0.02, 0.16), Vector3(0.36, 0.02, 0.04), Vector3(0.24, top * 0.7, 0.08), GroundColors.glow(P.EMBER[2], 0.4))
		_:
			# Lichen blooms on the weather side.
			for i in 3:
				var a := float(i) * 2.1 + v
				var p := Vector3(cos(a) * cap_r * 0.6 - 0.05, top + 0.005, sin(a) * cap_r * 0.6)
				k.fleck(p, p + Vector3(0.08, 0.02, 0.06), p + Vector3(0.1, 0.0, -0.03), g[2] if i != 1 else P.MOSS[4])


## A rock drawn in bands: `rings` + 1 jittered rings rising to an apex, the
## band between ring i and i + 1 in cols[i]. Pushed through a tilt, the bands
## run across the faces as veins and beds, bold enough to read at 640x360.
## radii[i] and heights[i] give ring i; the last ring closes to `apex`.
static func banded(k: Kit, radii: Array, heights: Array, cols: Array, apex: Vector3, sides: int, seed_value: int, squash: float = 1.0) -> void:
	var rings: Array[PackedVector3Array] = []
	var rot := Rng.hash01(seed_value, 99) * TAU
	var jit := PackedFloat32Array()
	for e in sides:
		jit.append(0.8 + Rng.hash01(seed_value, e, 1) * 0.4)
	for r in radii.size():
		var ring := PackedVector3Array()
		var rr: float = radii[r]
		for e in sides:
			var a := rot + float(e) / sides * TAU + Kit.j(seed_value, e, 0.25)
			var wob := jit[e] * (1.0 + Kit.j(seed_value, e * 7 + r, 0.08))
			ring.append(Vector3(cos(a) * rr * wob, float(heights[r]) + Kit.j(seed_value, e * 5 + r * 3, 0.03), sin(a) * rr * wob * squash))
		rings.append(ring)
	for r in radii.size() - 1:
		var col: Color = cols[mini(r, cols.size() - 1)]
		for e in sides:
			var n := (e + 1) % sides
			k.made.quad(rings[r][n], rings[r][e], rings[r + 1][e], rings[r + 1][n], col if e % 2 == 0 else Kit.tone(col, 0.94))
	var top: Color = cols[cols.size() - 1]
	var last := rings[rings.size() - 1]
	for e in sides:
		k.made.tri(apex, last[(e + 1) % sides], last[e], top)


## Building stone: a pale bedded outcrop quarried on one side: the cut face
## is flat and shows its beds in bold lines and a row of wedge holes, and the
## split blocks lie tipped at its foot.
static func stone_ore(k: Kit, v: int, c: int) -> void:
	var pale := P.LINEN[4] if c != Country.BURNING else P.ASH[3]
	var bed := GroundColors.down(pale, 0.9)
	var s := 7500 + v * 41
	banded(k, [0.58, 0.6, 0.6, 0.56, 0.54, 0.46, 0.34], [-0.06, 0.12, 0.16, 0.34, 0.38, 0.56, 0.66], [pale, bed, GroundColors.down(pale, 0.15), bed, pale, GroundColors.up(pale, 0.15)], Vector3(-0.04, 0.72, 0.0), 7, s, 0.85)
	# The quarried face toward +x: flat, pale, beds and wedge holes ruled across.
	var fx := 0.5
	k.made.quad(Vector3(fx, -0.04, -0.4), Vector3(fx, -0.04, 0.4), Vector3(fx - 0.06, 0.6, 0.3), Vector3(fx - 0.06, 0.6, -0.3), GroundColors.up(pale, 0.3))
	for yy: float in [0.14, 0.36]:
		k.made.quad(Vector3(fx + 0.005 - yy * 0.1, yy - 0.02, -0.38 + yy * 0.1), Vector3(fx + 0.005 - yy * 0.1, yy - 0.02, 0.38 - yy * 0.1), Vector3(fx + 0.005 - yy * 0.1, yy + 0.02, 0.38 - yy * 0.1), Vector3(fx + 0.005 - yy * 0.1, yy + 0.02, -0.38 + yy * 0.1), bed)
	for w in 4:
		var z := -0.24 + w * 0.16
		k.made.quad(Vector3(fx - 0.045, 0.5, z - 0.025), Vector3(fx - 0.045, 0.5, z + 0.025), Vector3(fx - 0.04, 0.56, z + 0.025), Vector3(fx - 0.04, 0.56, z - 0.025), P.INK[2])
	for i in 2 + v:
		var a := -0.6 + i * 0.7
		k.made.push(Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.BACK, 0.25 + i * 0.1), Vector3(0.8 + i * 0.1, -0.02, -0.3 + i * 0.36)))
		k.slab(0, 0, 0, 0.34, 0.16, 0.22, s + i, pale, GroundColors.up(pale, 0.25), 0.02, 0.1, 0.0)
		k.made.pop()
	if v == 1:
		# A plate wedge left in the split.
		k.found.prism(fx - 0.02, 0.48, 0.1, 0.03, 0.66, 0.006, 4, P.PLATE[2], P.PLATE[3], PI * 0.25)


## Iron: a knobbly ironstone boss, rust-red and ochre in bold slanting beds.
static func iron_ore(k: Kit, v: int, c: int) -> void:
	var s := 7600 + v * 41 + c
	var cols := [P.RUST[2], P.EARTH[2], P.RUST[3], P.RUST[1], P.RUST[4], P.EARTH[3]]
	k.made.push(Transform3D(Basis(Vector3.BACK, 0.28) * Basis(Vector3.RIGHT, 0.12), Vector3(0, -0.08, 0)))
	banded(k, [0.52, 0.56, 0.5, 0.44, 0.34, 0.2], [0.0, 0.16, 0.3, 0.44, 0.56, 0.66], cols, Vector3(0.04, 0.74, 0.02), 7, s)
	k.made.pop()
	# Ironstone nodules standing out of the boss.
	for i in 3 + v:
		var a := float(i) * 2.2 + 0.4
		k.stone(cos(a) * 0.42, 0.1 + i * 0.08, sin(a) * 0.36, 0.14, 0.16, s + 20 + i, P.RUST[3] if i % 2 else P.RUST[1], 5, 0.2)
	# Ochre stain fanned out on the ground below it.
	k.made.tri(Vector3(0.3, 0.01, 0.3), Vector3(0.95, 0.01, 0.2), Vector3(0.6, 0.01, 0.75), P.RUST[4])
	k.made.tri(Vector3(0.3, 0.01, 0.3), Vector3(0.6, 0.01, 0.75), Vector3(0.1, 0.01, 0.62), P.EARTH[3])


## Copper: a tall jagged spur of dark slate streaked top to bottom in
## verdigris, bright green running down its faces.
static func copper_ore(k: Kit, v: int, c: int) -> void:
	var g := geology(c)
	var s := 7700 + v * 41 + c
	var host := P.SLATE[1].lerp(g[1], 0.3)
	k.made.push(Transform3D(Basis(Vector3.BACK, -0.14), Vector3.ZERO))
	banded(k, [0.4, 0.36, 0.3, 0.22, 0.14], [-0.06, 0.3, 0.62, 0.9, 1.12], [host, P.SPRUCE[4], host, P.SPRUCE[5], host], Vector3(0.08, 1.4, -0.04), 5, s)
	k.made.pop()
	# Verdigris runs down the faces that are seen, bold, two tones.
	for i in 4:
		var a := -0.6 + i * 0.45
		var top := Vector3(cos(a) * 0.3, 1.0 - i * 0.12, sin(a) * 0.3)
		var out := Vector3(cos(a), 0.0, sin(a)) * 0.08
		var side := Vector3(-sin(a), 0.0, cos(a)) * 0.05
		k.made.quad(top + out * 0.6 - side, top + out * 0.6 + side, Vector3(top.x * 1.35, 0.02, top.z * 1.35) + out + side * 0.4, Vector3(top.x * 1.35, 0.02, top.z * 1.35) + out - side * 0.4, P.SPRUCE[4] if i % 2 == 0 else P.SPRUCE[5])
	if v == 1:
		k.stone(0.42, -0.04, 0.28, 0.2, 0.34, s + 3, host, 5, 0.3, P.SPRUCE[4])


## Coal: a low wide bank of grey beds with thick black seams between, the
## seams catching a glint; slack spilled at its foot.
static func coal_ore(k: Kit, v: int, c: int) -> void:
	var g := geology(c)
	var s := 7800 + v * 41 + c
	var bed := P.STONE[3].lerp(g[0], 0.25)
	k.made.push(Transform3D(Basis(Vector3.BACK, 0.08), Vector3.ZERO))
	# The seam is the darkest thing in the land, and it is still ink: `banded`
	# tones its bands down, so drawing it at INK[0] put coal under the pen
	# (docs/ART.md section 6, nothing is pure black).
	banded(k, [0.78, 0.74, 0.7, 0.62, 0.52], [-0.06, 0.12, 0.26, 0.4, 0.5], [bed, GroundColors.glint(P.INK[1]), bed, P.INK[1], GroundColors.up(bed, 0.2)], Vector3(0.0, 0.56, 0.0), 8, s, 0.62)
	k.made.pop()
	for i in 6:
		var a := float(i) * 1.1 + 0.3
		k.stone(0.55 + cos(a) * 0.3, -0.03, 0.25 + sin(a) * 0.25, 0.07, 0.06, s + 30 + i, P.INK[1] if i % 2 else P.INK[2], 4)
	if v == 1:
		k.slab(-0.62, -0.04, -0.32, 0.4, 0.14, 0.3, s + 40, P.INK[1], P.INK[2], 0.03, 0.1, 0.0)


## Tin: a cluster of angular pale quartz prisms with dark crystals in them,
## white veins that glint across a grey host.
static func tin_ore(k: Kit, v: int, c: int) -> void:
	var g := geology(c)
	var s := 7900 + v * 41 + c
	var host := P.STONE[2].lerp(g[0], 0.3)
	banded(k, [0.42, 0.44, 0.34], [-0.06, 0.16, 0.34], [host, P.STONE[5], host], Vector3(0.0, 0.42, 0.0), 6, s)
	var spikes := [[0.0, 0.3, 0.0, 0.16, 0.62, 0.1], [0.24, 0.2, 0.16, 0.12, 0.5, -0.3], [-0.22, 0.18, 0.12, 0.12, 0.44, 0.35], [0.06, 0.2, -0.26, 0.1, 0.4, -0.2]]
	for i in spikes.size():
		if v == 1 and i == 3:
			continue
		var sp: Array = spikes[i]
		k.made.push(Transform3D(Basis(Vector3.BACK, float(sp[5])) * Basis(Vector3.RIGHT, float(sp[5]) * 0.6), Vector3(sp[0], sp[1], sp[2])))
		k.made.prism(0, 0, 0, sp[3], sp[4] * 0.7, float(sp[3]) * 0.85, 5, P.ASH[4] if i % 2 == 0 else P.STONE[4], GroundColors.glint(P.STONE[5]))
		k.made.prism(0, sp[4] * 0.7, 0, float(sp[3]) * 0.85, sp[4], 0.0, 5, P.STONE[5])
		# A dark cassiterite crystal set in it.
		k.made.quad(Vector3(sp[3] * 0.9, 0.1, -0.03), Vector3(sp[3] * 0.9, 0.1, 0.03), Vector3(sp[3] * 0.9, 0.22, 0.03), Vector3(sp[3] * 0.9, 0.22, -0.03), P.INK[1])
		k.made.pop()


static func standing_stone(k: Kit, v: int, c: int) -> void:
	var g := geology(c)
	var s := 8000 + v * 43 + c
	var cap_y := 0.0
	var concrete := P.STONE[3].lerp(g[0], 0.2)
	match v % 3:
		0:
			# Quarried long ago: a tall leaning slab, lichen on the weather side.
			k.slab(0.0, -0.08, 0.0, 0.52, 1.8, 0.3, s, g[0], GroundColors.up(g[0], 0.2), 0.05, 0.35, 0.06)
			k.made.quad(Vector3(-0.19, 1.05, 0.13), Vector3(0.02, 1.07, 0.12), Vector3(0.04, 1.3, 0.1), Vector3(-0.16, 1.28, 0.11), P.LINEN[3])
			k.made.quad(Vector3(0.02, 0.44, 0.155), Vector3(0.2, 0.46, 0.155), Vector3(0.2, 0.62, 0.15), Vector3(0.02, 0.6, 0.15), P.MOSS[4])
			cap_y = 1.7
		1:
			# Cast, not quarried: a machine's leg snapped off, tilted in the
			# ground. The break is a slanting fracture with bars bent out of it.
			k.found.push(Transform3D(Basis(Vector3.BACK, 0.08) * Basis(Vector3.RIGHT, -0.05), Vector3.ZERO))
			var tops: Array[float] = [1.8, 1.58, 1.36, 1.3, 1.2, 1.42, 1.54, 1.84]
			cast_leg(k, 0.44, 0.36, 0.07, -0.12, tops, 1.46, concrete, GroundColors.down(concrete, 0.1))
			# A cast collar, and a spall off the front corner showing a bar.
			k.chamfer(0.0, 0.62, 0.0, 0.5, 0.08, 0.42, 0.08, GroundColors.down(concrete, 0.35), concrete)
			k.found.quad(Vector3(0.2, 0.9, 0.181), Vector3(0.2, 0.9, 0.06), Vector3(0.2, 1.14, 0.09), Vector3(0.2, 1.1, 0.181), P.STONE[4])
			k.rod(Vector3(0.212, 0.86, 0.13), Vector3(0.212, 1.2, 0.13), 0.014, 4, P.RUST[2])
			_rebar(k, [Vector3(-0.12, 1.5, 0.09), Vector3(0.1, 1.42, 0.1), Vector3(-0.1, 1.5, -0.1), Vector3(0.12, 1.4, -0.09)],
				[Vector3(-0.34, 1.9, 0.2), Vector3(0.42, 1.62, 0.26), Vector3(-0.2, 2.02, -0.3), Vector3(0.36, 1.2, -0.2)])
			# Rust runs down the faces from the bars.
			_run(k, Vector3(0.1, 1.38, 0.182), 0.09, 0.95, Vector3(0, 0, 1))
			_run(k, Vector3(0.222, 1.36, -0.02), 0.07, 0.7, Vector3(1, 0, 0))
			# A number cast into the side, three ticks under a bar.
			k.found.quad(Vector3(-0.14, 0.3, 0.183), Vector3(0.02, 0.3, 0.183), Vector3(0.02, 0.33, 0.183), Vector3(-0.14, 0.33, 0.183), P.STONE[2])
			for i in 3:
				var x := -0.12 + i * 0.05
				k.found.quad(Vector3(x, 0.38, 0.183), Vector3(x + 0.02, 0.38, 0.183), Vector3(x + 0.02, 0.5, 0.183), Vector3(x, 0.5, 0.183), P.STONE[2])
			k.found.pop()
			cap_y = 1.5
		_:
			# A cast foot sheared off at the knee: the stump of a leg standing
			# out of its pad, bars bent back where it broke, one bolt cut and one
			# pulled.
			var pad_tops: Array[float] = [0.5, 0.52, 0.5, 0.47, 0.44, 0.46, 0.49, 0.5]
			cast_leg(k, 0.86, 0.72, 0.12, -0.08, pad_tops, 0.51, concrete, GroundColors.up(concrete, 0.2))
			var stump: Array[float] = [0.94, 0.72, 0.62, 0.6, 0.64, 0.84, 0.98, 1.04]
			k.found.push(Transform3D(Basis.IDENTITY, Vector3(-0.04, 0.0, 0.02)))
			cast_leg(k, 0.44, 0.38, 0.07, 0.46, stump, 0.74, GroundColors.down(concrete, 0.15), GroundColors.down(concrete, 0.25))
			k.found.pop()
			_rebar(k, [Vector3(-0.16, 0.9, 0.1), Vector3(0.08, 0.8, 0.12), Vector3(-0.14, 0.95, -0.1), Vector3(0.1, 0.78, -0.08)],
				[Vector3(-0.5, 1.08, 0.2), Vector3(0.36, 0.64, 0.42), Vector3(-0.26, 1.3, -0.2), Vector3(0.44, 0.9, -0.3)])
			k.found.prism(0.3, 0.5, 0.26, 0.035, 0.62, 0.035, 6, P.STONE[1], P.STONE[4])
			k.found.prism(-0.3, 0.5, -0.26, 0.04, 0.54, 0.04, 6, P.INK[1])
			_run(k, Vector3(0.18, 0.76, 0.2), 0.07, 0.3, Vector3(0, 0, 1))
			_run(k, Vector3(0.4, 0.47, 0.1), 0.1, 0.5, Vector3(1, 0, 0))
			# A chunk lies where it fell, a bar still in it.
			k.found.push(Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3.BACK, 0.4), Vector3(0.66, -0.04, -0.46)))
			var chunk: Array[float] = [0.22, 0.18, 0.12, 0.1, 0.14, 0.2, 0.24, 0.25]
			cast_leg(k, 0.3, 0.24, 0.05, 0.0, chunk, 0.2, GroundColors.down(concrete, 0.1), GroundColors.down(concrete, 0.3))
			k.found.pop()
			k.rod(Vector3(0.6, 0.12, -0.44), Vector3(0.9, 0.34, -0.62), 0.013, 4, P.RUST[2])
			cap_y = 0.55
	# Turf round the foot.
	k.clump(0.3, -0.05, 0.12, 0.16, 0.16, s + 30, P.MOSS[2], 5)
	k.clump(-0.28, -0.05, -0.1, 0.13, 0.14, s + 31, P.MOSS[3], 5)
	if c == Country.SNOWFIELD:
		k.clump(0.0, cap_y, 0.0, 0.2, 0.12, s + 5, P.RIME[5], 6)


## A cast member, exact in plan (eight-sided, corners cut), standing from y0 to
## a broken top: `tops` are the heights of its eight top corners and `peak` the
## height the fracture rises to in the middle. The break is the fresh, paler face.
static func cast_leg(k: Kit, w: float, d: float, cut: float, y0: float, tops: Array[float], peak: float, col: Color, broken: Color) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var pts: Array[Vector2] = [Vector2(hw - cut, -hd), Vector2(hw, -hd + cut), Vector2(hw, hd - cut), Vector2(hw - cut, hd),
		Vector2(-hw + cut, hd), Vector2(-hw, hd - cut), Vector2(-hw, -hd + cut), Vector2(-hw + cut, -hd)]
	for i in 8:
		var a := pts[i]
		var b := pts[(i + 1) % 8]
		var shade := col if i < 4 else GroundColors.down(col, 0.12)
		k.found.quad(Vector3(b.x, y0, b.y), Vector3(a.x, y0, a.y), Vector3(a.x, tops[i], a.y), Vector3(b.x, tops[(i + 1) % 8], b.y), shade)
	# The fracture: facets from a point well off centre, in the rough grey of
	# the broken aggregate, alternating in tone so the break reads as torn.
	var centre := Vector3(-hw * 0.3, peak, hd * 0.25)
	for i in 8:
		var a := pts[i]
		var b := pts[(i + 1) % 8]
		k.found.tri(centre, Vector3(b.x, tops[(i + 1) % 8], b.y), Vector3(a.x, tops[i], a.y), broken if i % 3 != 1 else GroundColors.down(broken, 0.4))


## Reinforcing bars out of a break: each from its root to where it was bent,
## with a knee part way so it reads as bent, not stuck on.
static func _rebar(k: Kit, roots: Array, ends: Array) -> void:
	for i in roots.size():
		var a: Vector3 = roots[i]
		var b: Vector3 = ends[i]
		var knee := a + Vector3(0, 0.14, 0) + (b - a) * 0.15
		k.rod(a - Vector3(0, 0.05, 0), knee, 0.018, 4, P.RUST[2])
		k.rod(knee, b, 0.016, 4, P.RUST[3] if i % 2 == 0 else P.RUST[2])


## A rust run down a face from `top`: a streak `width` wide at the top, drying
## to a thread `length` below. `out` is the face's outward normal.
## Wound from the direction it is meant to be seen from, not from corner order:
## see props/works.gd `run`, which had the same fault and never drew at all.
static func _run(k: Kit, top: Vector3, width: float, length: float, out: Vector3) -> void:
	var along := Vector3(out.z, 0, -out.x) * width * 0.5
	if along.cross(Vector3.DOWN).dot(out) < 0.0:
		along = -along
	var lift := out * 0.004
	var mid := top + Vector3(0, -length * 0.45, 0)
	var foot := top + Vector3(0, -length, 0)
	k.found.quad(top - along + lift, top + along + lift, mid + along * 0.5 + lift, mid - along * 0.6 + lift, P.RUST[3])
	k.found.quad(mid - along * 0.6 + lift, mid + along * 0.5 + lift, foot + along * 0.12 + lift, foot - along * 0.1 + lift, P.RUST[2])


static func clints(k: Kit, v: int, c: int) -> void:
	var stone := P.LINEN[4] if c != Country.BURNING else P.ASH[3]
	var side := P.LINEN[2] if c != Country.BURNING else P.ASH[1]
	var s := 8500 + v * 7
	# Flat worn slabs of limestone, barely proud of the turf, split by grikes:
	# irregular polygons, never bricks.
	var slabs := [[-0.34, -0.18, 0.38], [0.3, -0.24, 0.32], [-0.06, 0.32, 0.4], [0.44, 0.3, 0.22]]
	for i in slabs.size():
		if v == 2 and i == 3:
			continue
		var b: Array = slabs[i]
		var h := 0.1 + Kit.j(s, i, 0.03)
		var r: float = b[2]
		var sides := 6 + (i + v) % 2
		var ring: Array[Vector3] = []
		for e in sides:
			var ang := float(e) / sides * TAU + Kit.j(s, i * 10 + e, 0.3)
			var rr := r * (0.75 + Rng.hash01(s, i * 10 + e, 2) * 0.35)
			ring.append(Vector3(b[0] + cos(ang) * rr, 0.0, b[1] + sin(ang) * rr * 0.8))
		var top_y := h + Kit.j(s, 40 + i, 0.02)
		var centre := Vector3(b[0], top_y, b[1])
		for e in sides:
			var p0 := ring[e]
			var p1 := ring[(e + 1) % sides]
			var t0 := Vector3(p0.x, top_y + Kit.j(s, i * 20 + e, 0.015), p0.z).lerp(centre, 0.06)
			var t1 := Vector3(p1.x, top_y + Kit.j(s, i * 20 + (e + 1) % sides, 0.015), p1.z).lerp(centre, 0.06)
			k.made.quad(Vector3(p1.x, -0.04, p1.z), Vector3(p0.x, -0.04, p0.z), t0, t1, side)
			k.made.tri(centre, t1, t0, stone if i % 2 == 0 else P.LINEN[5])
		# A row of drill holes across the slab: the machine age in the stone.
		if (i + v) % 2 == 0:
			for d in 4:
				var q := Vector3(b[0] - r * 0.4 + d * r * 0.26, top_y + 0.004, b[1] + Kit.j(s, 60 + i, 0.05))
				k.made.tri(q + Vector3(-0.02, 0, -0.015), q + Vector3(0.02, 0, -0.015), q + Vector3(0.0, 0, 0.02), P.LINEN[1])
	if v == 1:
		# A slab split by a wedge, the halves apart.
		k.stone(-0.02, 0.0, 0.0, 0.13, 0.16, s + 50, side, 5, 0.2, P.LINEN[5])
		k.stone(0.22, 0.0, -0.02, 0.12, 0.14, s + 51, side, 5, -0.2, P.LINEN[5])
		k.found.prism(0.1, 0.1, -0.01, 0.03, 0.26, 0.008, 4, P.PLATE[2], P.PLATE[3], PI * 0.25)
	# Ferns in the grikes.
	k.hand(Ink.hand_of(c), 0.0)
	var fs := k.made.vertex_count()
	for i in 3:
		var p := Vector3(-0.05 + i * 0.3, -0.02, 0.05 - i * 0.15)
		for f in 4:
			var a := float(f) * 1.57 + i
			k.blade(p, p + Vector3(cos(a) * 0.14, 0.14, sin(a) * 0.14), 0.06, a + 1.57, P.MOSS[3] if f % 2 else P.SPRUCE[3])
	k.sway_by_height(fs, 0.0, 0.14, 0.5)


## A cairn: flat stones laid in courses, each smaller and set back, so it
## tapers to a point you can see from the next hill. One carries a lens off a
## machine looking out; one a crane arm stood up as a marker.
static func cairn(k: Kit, v: int, c: int) -> void:
	var g := geology(c)
	var s := 8700 + v * 3 + c
	var y := -0.06
	var r := 0.46
	const COURSES := 7
	for i in COURSES:
		var n := 4 if i < 2 else (3 if i < 5 else 1)
		var lean := Vector2(Kit.j(s, i * 3, 0.025), Kit.j(s, i * 3 + 1, 0.025)) * i
		var ch := 0.13 + (COURSES - i) * 0.01
		for jj in n:
			var a := float(jj) / n * TAU + i * 0.9
			var rr := r * (0.5 if n > 1 else 0.0)
			var col := g[0] if (i + jj) % 3 != 0 else GroundColors.up(g[0], 0.2)
			k.made.push(Transform3D(Basis(Vector3.UP, a + Kit.j(s, i * 10 + jj, 0.3)) * Basis(Vector3.BACK, Kit.j(s, i * 20 + jj, 0.1)), Vector3(cos(a) * rr + lean.x, y, sin(a) * rr + lean.y)))
			k.slab(0.0, 0.0, 0.0, r * (0.95 if n > 1 else 1.3), ch, r * (0.7 if n > 1 else 1.1), s + i * 10 + jj, GroundColors.down(col, 0.25), GroundColors.up(col, 0.3), 0.015, 0.22, 0.0)
			k.made.pop()
		y += ch * 0.95
		r *= 0.84
	# The capstone, upright.
	k.slab(0.02, y - 0.02, 0.0, 0.16, 0.34, 0.1, s + 90, g[0], GroundColors.up(g[0], 0.3), 0.02, 0.35, 0.03)
	y += 0.3
	match v % 3:
		1:
			# A lens from a machine set on top on a bar, looking out to sea: a
			# ruled hoop, dark glass, a cold glint.
			var top := Vector3(0.0, y + 0.3, 0.0)
			k.rod(Vector3(0, y - 0.2, 0), top, 0.03, 6, P.STONE[1])
			var rc := top + Vector3(0.0, 0.16, 0.0)
			k.hoop(rc, 0.2, 14, 0.035, P.PLATE[3], Vector3.RIGHT)
			k.found.push(Transform3D(Basis(Vector3.BACK, PI * 0.5), rc))
			k.found.prism(0, -0.02, 0, 0.17, 0.02, 0.17, 12, P.COLD[1], P.COLD[2])
			k.found.pop()
			k.found.quad(rc + Vector3(0.03, 0.02, 0.03), rc + Vector3(0.03, 0.02, 0.1), rc + Vector3(0.03, 0.09, 0.1), rc + Vector3(0.03, 0.09, 0.03), P.COLD[3])
		2:
			# A crane arm off a machine, stood up as a marker, its hook hanging.
			k.rod(Vector3(0, y - 0.3, 0), Vector3(0.12, y + 0.9, 0), 0.045, 4, P.PLATE[3])
			k.rod(Vector3(0.12, y + 0.9, 0), Vector3(0.7, y + 0.78, 0), 0.035, 4, P.PLATE[3])
			k.rod(Vector3(0.06, y + 0.3, 0), Vector3(0.4, y + 0.82, 0), 0.02, 4, P.PLATE[2])
			k.rod(Vector3(0.7, y + 0.78, 0), Vector3(0.7, y + 0.4, 0), 0.01, 3, P.INK[2])
			k.found.prism(0.7, y + 0.3, 0, 0.05, y + 0.4, 0.05, 4, P.PLATE[2], P.PLATE[4], PI * 0.25)
	if c == Country.SNOWFIELD:
		k.clump(0, y - 0.34, 0, 0.18, 0.1, s + 60, P.RIME[5], 6)


static func mussel_rock(k: Kit, v: int, _c: int) -> void:
	var s := 8900 + v * 11
	k.hand(Ink.WIND)
	k.stone(0, -0.1, 0, 0.55, 0.36, s, P.SLATE[1], 7, 0.1, P.SLATE[2])
	if v % 3 == 1:
		k.stone(0.44, -0.1, 0.26, 0.3, 0.26, s + 1, P.SLATE[1], 6, 0.2)
	# Mussels in clumps: small dark blue-black shells, a few gaping.
	for i in 18:
		var a := float(i) * 2.39996
		var r := 0.18 + fmod(float(i) * 0.137, 0.3)
		var y := 0.2 - r * 0.28
		var p := Vector3(cos(a) * r, y, sin(a) * r)
		var d := Vector3(cos(a + 1.1), 0.0, sin(a + 1.1)) * 0.06
		var col := P.INK[2] if i % 3 else P.BRINE[1]
		k.fleck(p, p + d + Vector3(0, 0.03, 0), p + d * 0.3 + Vector3(0.02, 0.05, 0.02), col)
		k.fleck(p, p + d * 0.3 + Vector3(0.02, 0.05, 0.02), p - d * 0.2 + Vector3(0, 0.02, 0.03), P.BRINE[2] if i % 4 == 0 else col)
	for i in 9:
		var a := float(i) * 1.71 + 0.2
		var p := Vector3(cos(a) * 0.3, 0.2, sin(a) * 0.3)
		k.fleck(p, p + Vector3(0.03, 0.0, 0.01), p + Vector3(0.0, 0.02, 0.03), P.LINEN[4])
	# Weed fringe at the waterline.
	var ws := k.made.vertex_count()
	for i in 11:
		var a := float(i) / 11.0 * TAU
		var base := Vector3(cos(a) * 0.52, -0.03, sin(a) * 0.52)
		k.blade(base, base + Vector3(cos(a) * 0.16, 0.07, sin(a) * 0.16), 0.08, a + 1.57, P.MOSS[1] if i % 2 else P.EARTH[2])
	k.sway_by_height(ws, -0.03, 0.05, 0.5)


static func peat_bank(k: Kit, v: int, _c: int) -> void:
	var s := 9100 + v * 5
	# A cut bank: a long low hump of moor, one side sliced back to a dark face
	# with spade marks, heather grown over the top.
	var n := 7
	var len := 1.2
	var top: Array[Vector3] = []
	var back: Array[Vector3] = []
	var face_top: Array[Vector3] = []
	var face_bot: Array[Vector3] = []
	for i in n:
		var t := float(i) / (n - 1)
		var x := (t - 0.5) * len
		var bow := sin(t * PI) * 0.12
		var hh := 0.28 + sin(t * PI) * 0.22 + Kit.j(s, i, 0.04)
		face_bot.append(Vector3(x, -0.04, 0.16 + bow))
		face_top.append(Vector3(x + Kit.j(s, i + 10, 0.03), hh, 0.12 + bow + Kit.j(s, i + 20, 0.02)))
		top.append(Vector3(x, hh + 0.04, -0.12 + bow * 0.5))
		back.append(Vector3(x * 0.9, -0.04, -0.5 + bow * 0.3))
	for i in n - 1:
		# The cut face, dark, and the moor on top and behind.
		k.made.quad(face_bot[i], face_bot[i + 1], face_top[i + 1], face_top[i], P.EARTH[1])
		k.made.quad(face_top[i], face_top[i + 1], top[i + 1], top[i], P.MOSS[1])
		k.made.quad(top[i], top[i + 1], back[i + 1], back[i], P.EARTH[1].lerp(P.MOSS[1], 0.5))
	k.fleck(face_bot[0], back[0], top[0], P.EARTH[1])
	k.fleck(face_bot[0], top[0], face_top[0], P.EARTH[1])
	k.fleck(back[n - 1], face_bot[n - 1], top[n - 1], P.EARTH[1])
	k.fleck(top[n - 1], face_bot[n - 1], face_top[n - 1], P.EARTH[1])
	# Spade marks: short dark cuts down the face.
	for i in 9:
		var t := 0.08 + i * 0.105
		var seg := clampi(int(t * (n - 1)), 0, n - 2)
		var f := t * (n - 1) - seg
		var a := face_top[seg].lerp(face_top[seg + 1], f).lerp(face_bot[seg].lerp(face_bot[seg + 1], f), 0.25) + Vector3(0, 0, 0.02)
		var b := face_top[seg].lerp(face_top[seg + 1], f).lerp(face_bot[seg].lerp(face_bot[seg + 1], f), 0.7 + Kit.j(s, 60 + i, 0.15)) + Vector3(0, 0, 0.02)
		k.made.quad(b + Vector3(0.03, 0, 0), b, a, a + Vector3(0.03, 0, 0), P.EARTH[0])
	var hs := k.made.vertex_count()
	for i in 6:
		var p := top[1 + i % (n - 2)].lerp(top[mini(n - 1, 2 + i % (n - 2))], Kit.j(s, 40 + i, 0.5) + 0.5)
		k.clump(p.x, p.y - 0.08, p.z + Kit.j(s, 30 + i, 0.08), 0.2, 0.2, s + 10 + i, P.EARTH[2].lerp(P.MOSS[2], 0.6) if i % 2 else P.MOSS[2], 6)
		k.fleck(p + Vector3(0.02, 0.08, 0.02), p + Vector3(0.06, 0.09, 0.03), p + Vector3(0.03, 0.12, 0.0), P.BLOOM[2] if i % 2 else P.BLOOM[1])
	k.sway_by_height(hs, 0.3, 0.6, 0.2)
	# Black water gathered at the foot of the cut.
	k.made.tri(Vector3(-0.3, 0.004, 0.22), Vector3(0.2, 0.004, 0.24), Vector3(-0.05, 0.004, 0.38), P.BRINE[0])
	# Cut peats stood up in a little cone to dry.
	for i in 4:
		var a := float(i) / 4.0 * TAU + 0.4
		var foot := Vector3(0.95 + cos(a) * 0.12, -0.03, 0.4 + sin(a) * 0.12)
		k.limb(foot, Vector3(0.95, 0.24, 0.4), 0.05, 0.03, 4, P.EARTH[1] if i % 2 else P.EARTH[2])
	if v % 3 == 1:
		# A pipe through the face, an ochre stain fanning from it.
		k.rod(Vector3(-0.2, 0.3, -0.35), Vector3(-0.2, 0.3, 0.2), 0.07, 8, P.PLATE[2])
		k.hoop(Vector3(-0.2, 0.3, 0.2), 0.085, 8, 0.015, P.PLATE[3], Vector3.BACK)
		k.found.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.2, 0.3, 0.205)))
		k.found.prism(0, 0, 0, 0.055, 0.004, 0.055, 8, P.INK[1])
		k.found.pop()
		k.fleck(Vector3(-0.2, 0.25, 0.2), Vector3(-0.44, -0.02, 0.24), Vector3(0.04, -0.02, 0.24), P.RUST[4])
		k.made.tri(Vector3(-0.2, 0.006, 0.25), Vector3(-0.42, 0.006, 0.5), Vector3(0.02, 0.006, 0.54), P.RUST[2])
