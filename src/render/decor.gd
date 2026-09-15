class_name Decor
extends RefCounted
## Small details scattered over a chunk and baked into one mesh: tufts, heather,
## flowers in bloom, stones, shells, bones, snow tufts, ash flakes, embers,
## glints, lichen, cones, bracken, bog cotton, and rubble at cliff feet.
##
## What grows is chosen by the ground and country DRAWN at each tile (the
## terrain chunk's keys), so across an ecotone the decor interleaves exactly
## with the washes. Only tiles that sit flat on one terrace with one key get
## decor, so nothing hangs over a lip or floats at an edge. Deterministic per
## chunk: one RNG seeded by the chunk, tiles visited in order.
##
## Plants sway by height (UV2.x) in world.gdshader; flowers follow a bloom field
## so a hillside flowers together and the next is still in bud.

enum {
	TUFT, TUFT_TALL, HEATHER, FLOWER, THISTLE, STONE, PEBBLES, SHELL, BONE,
	SNOW_TUFT, ASH_FLAKE, EMBER, GLASS, LICHEN, CONE, BRACKEN, MUSHROOM,
	BOG_COTTON, SEDGE, MARRAM, TWIG, CINDER, SPHAGNUM, ICE_SHARD, RUBBLE,
	SEA_GLASS, MOLEHILL, FERN, WRACK_BIT, CROTTLE,
}
const KINDS := 30
const STAGES := 3

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")

var world: WorldData
var _rng := RandomNumberGenerator.new()
var _bloom: FastNoiseLite
## ground -> [kinds: PackedInt32Array, cumulative: PackedFloat32Array, items per tile]
var _tables: Dictionary = {}
static var _templates: Dictionary = {}


## Raw arrays of one decor model.
class Tpl:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()


func _init(w: WorldData) -> void:
	world = w
	_bloom = FastNoiseLite.new()
	_bloom.seed = Rng.hash_ints(w.seed_value, 0xB100) & 0x7FFFFFFF
	_bloom.frequency = 1.0 / 38.0
	_bloom.fractal_octaves = 2
	_table(Ground.GRASS, 1.1, [TUFT, 46, TUFT_TALL, 12, FLOWER, 12, STONE, 5, THISTLE, 3, MOLEHILL, 2])
	_table(Ground.HEATH, 1.2, [HEATHER, 50, TUFT, 14, STONE, 5, FLOWER, 4, BRACKEN, 7])
	_table(Ground.SAND, 0.3, [MARRAM, 26, SHELL, 16, PEBBLES, 10, TWIG, 5, WRACK_BIT, 6])
	_table(Ground.SHINGLE, 0.5, [PEBBLES, 40, SEA_GLASS, 5, SHELL, 10, WRACK_BIT, 8, STONE, 12])
	_table(Ground.GRAVEL, 0.3, [PEBBLES, 30, STONE, 10, TUFT, 6])
	_table(Ground.MOSS, 1.2, [SEDGE, 30, BOG_COTTON, 22, SPHAGNUM, 16, TUFT, 8, FLOWER, 4])
	_table(Ground.MUD, 0.4, [SEDGE, 20, TWIG, 8, PEBBLES, 6])
	_table(Ground.PEAT, 0.7, [HEATHER, 30, BOG_COTTON, 28, SEDGE, 18])
	_table(Ground.NEEDLES, 0.8, [CONE, 30, BRACKEN, 20, TWIG, 18, MUSHROOM, 6, FERN, 8])
	_table(Ground.SNOW, 0.28, [SNOW_TUFT, 40, CROTTLE, 12, STONE, 8, TWIG, 4])
	_table(Ground.ICE, 0.08, [ICE_SHARD, 10])
	_table(Ground.BONE, 0.45, [FERN, 22, STONE, 26, TUFT, 20, FLOWER, 7, BONE, 3])
	_table(Ground.LIMESTONE, 0.45, [FERN, 22, STONE, 26, TUFT, 20, FLOWER, 7, BONE, 3])
	_table(Ground.SCREE, 0.9, [STONE, 55, PEBBLES, 30, LICHEN, 8])
	_table(Ground.ASH, 0.6, [ASH_FLAKE, 30, CINDER, 30, EMBER, 6, TWIG, 8])
	_table(Ground.CLINKER, 0.45, [GLASS, 26, CINDER, 40])
	_table(Ground.ROCK, 0.35, [LICHEN, 30, STONE, 34, TUFT, 6])
	_table(Ground.ROAD, 0.08, [PEBBLES, 10, TUFT, 3])


func _table(g: int, density: float, pairs: Array) -> void:
	var kinds := PackedInt32Array()
	var cum := PackedFloat32Array()
	var total := 0.0
	for i in range(0, pairs.size(), 2):
		total += float(pairs[i + 1])
	var acc := 0.0
	for i in range(0, pairs.size(), 2):
		acc += float(pairs[i + 1]) / total
		kinds.append(pairs[i])
		cum.append(acc)
	_tables[g] = [kinds, cum, density]


## Items per tile of a ground (0 for grounds that carry none).
func density(g: int) -> float:
	if not _tables.has(g):
		return 0.0
	return _tables[g][2]


func build(ch: TerrainMesher.Chunk) -> ArrayMesh:
	_rng.seed = Rng.hash_ints(world.seed_value, ch.cx, ch.cy, 0xDEC0)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var np := ch.n + 1
	for ty in ch.h:
		for tx in ch.w:
			# A tile's 3x3 lattice points: one key, one terrace, or no decor.
			var li := ty * 2 * np + tx * 2
			var k := ch.key[li + np + 1]
			var t := ch.t[li + np + 1]
			if t <= 0 or (k & 0x10000) != 0:
				continue
			var ok := true
			for o: int in [0, 1, 2, np, np + 2, np * 2, np * 2 + 1, np * 2 + 2]:
				if ch.key[li + o] != k or ch.t[li + o] != t:
					ok = false
					break
			if not ok:
				continue
			var g := k & 0xFF
			var table: Array = _tables.get(g, [])
			if table.is_empty():
				continue
			var count := int(float(table[2]) + _rng.randf())
			if count <= 0:
				continue
			var country := (k >> 8) & 0xFF
			var h := TerrainMesher.level_height(t) - 0.004
			var shore := ch.shore[ty * ch.w + tx]
			var wx := ch.x0 + tx
			var wy := ch.y0 + ty
			for i in count:
				var kind := _pick(table, _rng.randf())
				if (kind == WRACK_BIT or kind == SHELL or kind == SEA_GLASS) and shore < -3.0:
					kind = PEBBLES if g == Ground.SHINGLE else (MARRAM if g == Ground.SAND else TUFT)
				var fx := 0.08 + _rng.randf() * 0.84
				var fy := 0.08 + _rng.randf() * 0.84
				var stage := 0
				if kind == FLOWER:
					var bl := _bloom.get_noise_2d(wx + fx, wy + fy) * 0.5 + 0.5
					if bl < 0.4:
						kind = TUFT
					stage = clampi(int((bl - 0.4) / 0.6 * STAGES), 0, STAGES - 1)
				else:
					stage = _rng.randi() % STAGES
				var tpl := template(kind, country, stage)
				var s := 0.8 + _rng.randf() * 0.45
				var basis := Basis(Vector3.UP, _rng.randf() * TAU)
				var xf := Transform3D(basis.scaled(Vector3(s, s, s)), Vector3(wx + fx, h, wy + fy))
				v.append_array(xf * tpl.v)
				n.append_array(Transform3D(basis, Vector3.ZERO) * tpl.n)
				c.append_array(tpl.c)
				uv.append_array(tpl.uv)
				uv2.append_array(tpl.uv2)
	# Rubble fallen from cliff faces, more of it where the rock is hard.
	for fi in ch.feet.size():
		var foot := ch.feet[fi]
		var out := ch.feet_out[fi]
		var country := int(ch.feet_country[fi])
		var chance := 0.55 if country == Country.BONELANDS or country == Country.BURNING or country == Country.SNOWFIELD else 0.35
		if _rng.randf() > chance:
			continue
		var p := foot + out * (0.05 + _rng.randf() * 0.25)
		if not _flat_at(ch, p.x, p.z):
			continue
		var along := Vector3(-out.z, 0, out.x)
		var tpl := template(RUBBLE, country, _rng.randi() % STAGES)
		var s := 0.7 + _rng.randf() * 0.6
		var basis := Basis(Vector3.UP, _rng.randf() * TAU)
		v.append_array(Transform3D(basis.scaled(Vector3(s, s, s)), p + along * (_rng.randf() - 0.5) * 0.4) * tpl.v)
		n.append_array(Transform3D(basis, Vector3.ZERO) * tpl.n)
		c.append_array(tpl.c)
		uv.append_array(tpl.uv)
		uv2.append_array(tpl.uv2)
	if v.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## True when the lattice cell under (x, y) is one dry terrace.
func _flat_at(ch: TerrainMesher.Chunk, x: float, y: float) -> bool:
	if x < ch.x0 or y < ch.y0 or x >= ch.x0 + ch.w or y >= ch.y0 + ch.h:
		return false
	return ch.settled(x, y) and (ch.key_at(x, y) & 0x10000) == 0


func _pick(table: Array, r: float) -> int:
	var kinds: PackedInt32Array = table[0]
	var cum: PackedFloat32Array = table[1]
	for i in cum.size():
		if r <= cum[i]:
			return kinds[i]
	return kinds[kinds.size() - 1]


static func template(kind: int, country: int, stage: int = 0) -> Tpl:
	var key := (kind * 8 + country) * 4 + stage
	if not _templates.has(key):
		var k := kit(kind, country, stage)
		var t := Tpl.new()
		t.v = k.made.verts
		t.n = k.made.normals
		t.c = k.made.colors
		t.uv = k.made.uvs
		t.uv2 = k.made.uv2s
		_templates[key] = t
	return _templates[key]


## Grass colours of a country: [blade, tip].
static func grass(c: int) -> Array[Color]:
	match c:
		Country.MOSS: return [P.SPRUCE[3], P.MOSS[3]]
		Country.PINEWOOD: return [P.SPRUCE[2], P.MOSS[2]]
		Country.SNOWFIELD: return [P.ASH[3], P.LINEN[3]]
		Country.BONELANDS: return [P.MOSS[4].lerp(P.SAND[4], 0.4), P.SAND[4]]
		Country.BURNING: return [P.EARTH[3], P.ASH[2]]
	return [P.MOSS[3], P.MOSS[4].lerp(P.SLATE[3], 0.2)]


static func rock_of(c: int) -> Color:
	match c:
		Country.BONELANDS: return P.LINEN[3]
		Country.BURNING: return P.INK[3]
		Country.SNOWFIELD: return P.SLATE[3]
		Country.MOSS, Country.PINEWOOD: return P.SLATE[2].lerp(P.SPRUCE[2], 0.3)
	return P.SLATE[3]


static func kit(kind: int, c: int, stage: int) -> Kit:
	var k := Kit.new()
	k.hand(Ink.COUNTRY_STYLE[c])
	var gr := grass(c)
	var rock := rock_of(c)
	var s := kind * 131 + c * 17 + stage * 7
	match kind:
		TUFT, TUFT_TALL:
			var blades := 5 if kind == TUFT else 7
			var hh := 0.15 if kind == TUFT else 0.28
			for i in blades:
				var a := float(i) / blades * TAU + Kit.j(s, i, 0.4)
				var base := Vector3(cos(a) * 0.035, 0, sin(a) * 0.035)
				var tip := base * 2.6 + Vector3(0.02, hh * (0.7 + Rng.hash01(s, i) * 0.5), 0)
				k.blade(base, tip, 0.045, a + 1.57, gr[i % 2])
			k.sway_by_height(0, 0.0, hh, 0.8)
		HEATHER:
			var cols: Array[Color] = [P.EARTH[2].lerp(P.MOSS[1], 0.5), P.MOSS[1], P.EARTH[1]]
			k.clump(0, -0.01, 0, 0.13, 0.14, s, cols[stage % 3], 6)
			for i in 4:
				var a := float(i) * 1.7
				var p := Vector3(cos(a) * 0.08, 0.1 + i * 0.012, sin(a) * 0.08)
				k.fleck(p, p + Vector3(0.035, 0.0, 0.01), p + Vector3(0.01, 0.035, 0.0), P.BLOOM[1] if i % 2 else P.BLOOM[2])
			k.sway_by_height(0, 0.0, 0.14, 0.25)
		FLOWER:
			var head: Color
			match c:
				Country.COAST: head = [P.BLOOM[2], P.BLOOM[3], P.BLOOM[4]][stage]
				Country.BONELANDS: head = [P.BRINE[3], P.BRINE[4], P.LINEN[4]][stage]
				Country.MOSS: head = [P.RUST[4], P.SAND[5], P.RUST[5]][stage]
				Country.BURNING: head = [P.BLOOM[1], P.BLOOM[2], P.ASH[3]][stage]
				_: head = [P.RUST[4], P.SAND[5], P.LINEN[4]][stage]
			for i in 2 + stage % 2:
				var a := float(i) * 2.4
				var base := Vector3(cos(a) * 0.03, 0, sin(a) * 0.03)
				var tip := base + Vector3(cos(a) * 0.03, 0.13 + i * 0.03, sin(a) * 0.03)
				k.blade(base, tip, 0.025, a, gr[0])
				var hs := 0.03 + stage * 0.008
				k.fleck(tip, tip + Vector3(hs, 0.01, 0.0), tip + Vector3(0.0, hs, hs * 0.6), head)
				k.fleck(tip, tip + Vector3(-hs * 0.6, hs * 0.8, 0.0), tip + Vector3(0.0, 0.01, -hs), head)
			k.sway_by_height(0, 0.0, 0.18, 0.7)
		THISTLE:
			k.blade(Vector3.ZERO, Vector3(0.01, 0.28, 0), 0.03, 0.0, gr[0])
			for i in 3:
				var a := float(i) * 2.1
				k.blade(Vector3(0, 0.05, 0), Vector3(cos(a) * 0.12, 0.1, sin(a) * 0.12), 0.05, a + 1.57, P.SPRUCE[3])
			var tp := Vector3(0.01, 0.28, 0)
			k.fleck(tp, tp + Vector3(0.05, 0.02, 0), tp + Vector3(0.02, 0.06, 0.03), P.BLOOM[2])
			k.sway_by_height(0, 0.0, 0.3, 0.6)
		STONE:
			k.stone(0, -0.02, 0, 0.08 + stage * 0.02, 0.08 + stage * 0.01, s, rock, 5, 0.1)
		PEBBLES:
			for i in 3:
				var a := float(i) * 2.2
				k.stone(cos(a) * 0.07, -0.01, sin(a) * 0.07, 0.035, 0.03, s + i, [P.STONE[2], P.STONE[3], P.SAND[3]][i], 4)
		SHELL:
			k.fleck(Vector3(0, 0.012, 0), Vector3(0.06, 0.012, 0.05), Vector3(0.07, 0.02, -0.03), P.LINEN[5])
			k.fleck(Vector3(0, 0.014, 0), Vector3(0.07, 0.02, -0.03), Vector3(0.02, 0.014, -0.07), P.LINEN[4])
		BONE:
			k.limb(Vector3(-0.09, 0.02, 0), Vector3(0.09, 0.02, 0.03), 0.015, 0.012, 3, P.LINEN[4])
			k.stone(0.1, -0.005, 0.03, 0.03, 0.035, s, P.LINEN[5], 4)
		SNOW_TUFT:
			k.clump(0, -0.02, 0, 0.11, 0.05, s, P.RIME[5], 6)
			for i in 4:
				var a := float(i) * 1.6
				var base := Vector3(cos(a) * 0.03, 0, sin(a) * 0.03)
				k.blade(base, base * 2.0 + Vector3(0, 0.15, 0), 0.035, a + 1.57, P.ASH[3] if i % 2 else P.LINEN[3])
			k.sway_by_height(0, 0.02, 0.15, 0.6)
		ASH_FLAKE:
			k.fleck(Vector3(-0.05, 0.012, -0.03), Vector3(-0.04, 0.012, 0.04), Vector3(0.06, 0.014, 0.03), P.LINEN[3] if stage == 0 else P.ASH[0])
		EMBER:
			k.fleck(Vector3(0, 0.01, 0), Vector3(0.05, 0.01, 0.02), Vector3(0.01, 0.03, 0.04), GroundColors.glow(P.EMBER[3], 1.1))
		GLASS:
			k.fleck(Vector3(-0.03, 0.01, 0), Vector3(0.03, 0.05, 0.01), Vector3(0.04, 0.01, -0.03), GroundColors.glint(P.SPRUCE[3]))
		LICHEN:
			k.stone(0, -0.02, 0, 0.1, 0.06, s, rock, 5)
			k.fleck(Vector3(-0.04, 0.045, -0.02), Vector3(-0.02, 0.05, 0.05), Vector3(0.05, 0.045, 0.01), P.LINEN[3] if stage % 2 == 0 else P.MOSS[4])
		CONE:
			k.made.push(Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, 0.03, 0.0)))
			k.made.prism(0, -0.05, 0, 0.03, 0.05, 0.012, 5, P.EARTH[2], P.EARTH[3])
			k.made.pop()
		BRACKEN:
			var fronds: Array[Color] = [P.RUST[3], P.EARTH[3], P.RUST[2]]
			if c == Country.SNOWFIELD or c == Country.BURNING:
				fronds = [P.EARTH[2], P.EARTH[1], P.ASH[2]]
			for i in 4:
				var a := float(i) / 4.0 * TAU + 0.3
				k.blade(Vector3(0, 0.02, 0), Vector3(cos(a) * 0.2, 0.2, sin(a) * 0.2), 0.09, a + 1.57, fronds[i % 3])
			k.sway_by_height(0, 0.0, 0.2, 0.7)
		MUSHROOM:
			k.made.prism(0, 0, 0, 0.012, 0.05, 0.012, 4, P.LINEN[4])
			k.made.prism(0, 0.05, 0, 0.045, 0.08, 0.0, 6, P.RUST[3] if stage % 2 == 0 else P.LINEN[3])
		BOG_COTTON:
			for i in 3:
				var a := float(i) * 2.1
				var base := Vector3(cos(a) * 0.03, 0, sin(a) * 0.03)
				var tip := base * 2.0 + Vector3(0, 0.2 + i * 0.03, 0)
				k.blade(base, tip, 0.02, a, P.MOSS[2])
				k.clump(tip.x, tip.y - 0.01, tip.z, 0.028, 0.045, s + i, P.LINEN[5], 4)
			k.sway_by_height(0, 0.0, 0.25, 0.8)
		SEDGE:
			for i in 6:
				var a := float(i) / 6.0 * TAU + Kit.j(s, i, 0.3)
				var base := Vector3(cos(a) * 0.03, 0, sin(a) * 0.03)
				k.blade(base, base * 4.0 + Vector3(0, 0.22, 0), 0.035, a + 1.57, P.SPRUCE[3] if i % 2 else gr[0])
			k.sway_by_height(0, 0.0, 0.22, 0.8)
		MARRAM:
			for i in 6:
				var a := float(i) / 6.0 * TAU
				var base := Vector3(cos(a) * 0.03, 0, sin(a) * 0.03)
				k.blade(base, base * 3.0 + Vector3(0.04, 0.34, 0), 0.03, a + 1.57, P.SAND[4] if i % 2 else P.MOSS[4].lerp(P.SAND[4], 0.5))
			k.sway_by_height(0, 0.0, 0.34, 0.9)
		TWIG:
			k.limb(Vector3(-0.12, 0.02, 0), Vector3(0.12, 0.02, 0.04), 0.013, 0.008, 3, P.EARTH[1] if c != Country.BURNING else P.INK[2])
			k.limb(Vector3(0.0, 0.02, 0.01), Vector3(0.06, 0.02, 0.08), 0.008, 0.005, 3, P.EARTH[2])
		CINDER:
			k.stone(0, -0.01, 0, 0.04, 0.035, s, P.INK[2], 4)
		SPHAGNUM:
			k.clump(0, -0.02, 0, 0.12, 0.05, s, P.RUST[2] if stage % 2 == 0 else P.MOSS[3], 6)
		ICE_SHARD:
			k.fleck(Vector3(-0.08, 0.01, 0), Vector3(0.05, 0.08, 0.02), Vector3(0.08, 0.01, -0.04), GroundColors.glint(P.RIME[4]))
		RUBBLE:
			k.stone(0, -0.03, 0, 0.15, 0.14, s + 3, rock, 5, 0.2)
			k.stone(0.14, -0.03, 0.08, 0.08, 0.08, s + 4, GroundColors.down(rock, 0.3), 4)
			if stage >= 1:
				k.stone(-0.13, -0.03, 0.1, 0.1, 0.07, s + 5, GroundColors.up(rock, 0.2), 5)
		SEA_GLASS:
			k.fleck(Vector3(0, 0.01, 0), Vector3(0.04, 0.012, 0.02), Vector3(0.01, 0.02, 0.03), GroundColors.glint(P.SPRUCE[4] if stage % 2 == 0 else P.BRINE[5]))
			k.stone(0.06, -0.01, 0.04, 0.035, 0.03, s, P.STONE[3], 4)
		MOLEHILL:
			k.clump(0, -0.03, 0, 0.12, 0.1, s, P.EARTH[2], 6)
		FERN:
			for i in 5:
				var a := float(i) / 5.0 * TAU
				k.blade(Vector3(0, 0.01, 0), Vector3(cos(a) * 0.16, 0.15, sin(a) * 0.16), 0.06, a + 1.57, P.SPRUCE[3] if i % 2 else P.MOSS[3])
			k.sway_by_height(0, 0.0, 0.16, 0.6)
		WRACK_BIT:
			k.made.quad(Vector3(-0.12, 0.012, -0.02), Vector3(-0.1, 0.012, 0.03), Vector3(0.12, 0.012, 0.02), Vector3(0.1, 0.012, -0.03), P.EARTH[1])
			k.made.quad(Vector3(-0.02, 0.014, -0.08), Vector3(-0.01, 0.014, 0.07), Vector3(0.03, 0.014, 0.07), Vector3(0.02, 0.014, -0.08), P.SPRUCE[1])
		CROTTLE:
			k.stone(0, -0.02, 0, 0.1, 0.09, s, P.SLATE[2], 5)
			k.fleck(Vector3(-0.04, 0.075, -0.03), Vector3(-0.03, 0.08, 0.04), Vector3(0.04, 0.075, 0.03), P.LINEN[3])
	return k
