class_name Decor
extends RefCounted
## Small details scattered over a chunk and baked into one mesh: tufts, heather,
## flowers in bloom, stones, shells, bones, snow tufts, ash flakes, embers,
## glints, lichen, cones, bracken, bog cotton, rubble at cliff feet.
##
## What grows on a tile is chosen by its ground and its country; across an
## ecotone each item takes the neighbouring country with probability `blend`,
## and some items are that country's signature creeping in (snow tufts toward the
## Snowfield, cinders toward the Burning). Deterministic per chunk: one RNG
## seeded by the chunk, tiles visited in order.

enum {
	TUFT, TUFT_TALL, HEATHER, FLOWER, THISTLE, STONE, PEBBLES, SHELL, BONE,
	SNOW_TUFT, ASH_FLAKE, EMBER, GLASS, LICHEN, CONE, BRACKEN, MUSHROOM,
	BOG_COTTON, SEDGE, MARRAM, TWIG, PAPER, CINDER, SPHAGNUM, ICE_SHARD,
	RUBBLE, SEA_GLASS, MOLEHILL, FERN, WRACK_BIT, CROTTLE,
}
const KINDS := 31
const STAGES := 4

const P := preload("res://src/render/palette.gd")
const Craft := preload("res://src/models/props/craft.gd")

var world: WorldData
var mesher: TerrainMesher
var _rng := RandomNumberGenerator.new()
var _bloom: FastNoiseLite
var _tables: Dictionary = {} # ground -> [types: PackedInt32Array, cumulative: PackedFloat32Array, density]
static var _templates: Dictionary = {}


func _init(w: WorldData, m: TerrainMesher) -> void:
	world = w
	mesher = m
	_bloom = FastNoiseLite.new()
	_bloom.seed = Rng.hash_ints(w.seed_value, 0xB100) & 0x7FFFFFFF
	_bloom.frequency = 1.0 / 38.0
	_bloom.fractal_octaves = 2
	_table(Ground.GRASS, 1.25, [TUFT, 46, TUFT_TALL, 12, FLOWER, 10, STONE, 5, THISTLE, 3, MOLEHILL, 2])
	_table(Ground.HEATH, 1.5, [HEATHER, 50, TUFT, 14, STONE, 5, FLOWER, 4, BRACKEN, 6])
	_table(Ground.SAND, 0.32, [MARRAM, 22, SHELL, 18, PEBBLES, 10, TWIG, 5, WRACK_BIT, 6])
	_table(Ground.SHINGLE, 0.55, [PEBBLES, 40, SEA_GLASS, 6, SHELL, 10, WRACK_BIT, 8, STONE, 12])
	_table(Ground.GRAVEL, 0.35, [PEBBLES, 30, STONE, 10, TUFT, 6])
	_table(Ground.MOSS, 1.5, [SEDGE, 30, BOG_COTTON, 22, SPHAGNUM, 18, TUFT, 8, FLOWER, 4])
	_table(Ground.MUD, 0.45, [SEDGE, 20, TWIG, 8, PEBBLES, 6])
	_table(Ground.PEAT, 0.8, [HEATHER, 30, BOG_COTTON, 30, SEDGE, 18])
	_table(Ground.NEEDLES, 0.9, [CONE, 30, BRACKEN, 22, TWIG, 18, MUSHROOM, 7, TUFT, 8, FERN, 6])
	_table(Ground.SNOW, 0.32, [SNOW_TUFT, 40, CROTTLE, 12, STONE, 8, TWIG, 4])
	_table(Ground.ICE, 0.08, [ICE_SHARD, 10])
	_table(Ground.BONE, 0.5, [BONE, 26, STONE, 30, TUFT, 20, FLOWER, 4])
	_table(Ground.LIMESTONE, 0.42, [STONE, 26, FERN, 22, TUFT, 16, FLOWER, 7, BONE, 3])
	_table(Ground.SCREE, 1.0, [STONE, 55, PEBBLES, 30, LICHEN, 8])
	_table(Ground.ASH, 0.75, [ASH_FLAKE, 30, CINDER, 28, EMBER, 7, PAPER, 5, TWIG, 8])
	_table(Ground.CLINKER, 0.5, [GLASS, 28, CINDER, 40])
	_table(Ground.ROCK, 0.4, [LICHEN, 36, STONE, 30, TUFT, 8])
	_table(Ground.ROAD, 0.1, [PEBBLES, 10, TUFT, 3])


func _table(g: int, density: float, pairs: Array) -> void:
	var types := PackedInt32Array()
	var cum := PackedFloat32Array()
	var total := 0.0
	for i in range(0, pairs.size(), 2):
		total += float(pairs[i + 1])
	var acc := 0.0
	for i in range(0, pairs.size(), 2):
		acc += float(pairs[i + 1]) / total
		types.append(pairs[i])
		cum.append(acc)
	_tables[g] = [types, cum, density]


## The item a country pushes into its neighbour's ground across an ecotone.
static func signature(c: int, r: float) -> int:
	match c:
		Country.COAST: return TUFT if r < 0.7 else FLOWER
		Country.MOSS: return SEDGE if r < 0.45 else (BOG_COTTON if r < 0.75 else SPHAGNUM)
		Country.PINEWOOD: return CONE if r < 0.4 else (TWIG if r < 0.7 else BRACKEN)
		Country.SNOWFIELD: return SNOW_TUFT
		Country.BONELANDS: return STONE if r < 0.75 else BONE
		Country.BURNING: return ASH_FLAKE if r < 0.5 else (CINDER if r < 0.93 else EMBER)
	return TUFT


## Items per tile of a ground (0 for grounds that carry none).
func density(g: int) -> float:
	if not _tables.has(g):
		return 0.0
	return _tables[g][2]


func build(ch: TerrainMesher.Chunk) -> ArrayMesh:
	var w := world
	_rng.seed = Rng.hash_ints(w.seed_value, ch.cx, ch.cy, 0xDEC0)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	for ty in range(ch.y0, ch.y0 + ch.h):
		for tx in range(ch.x0, ch.x0 + ch.w):
			var i := ty * w.size + tx
			var g := w.ground[i]
			if not _tables.has(g):
				continue
			var t := (ty - ch.y0) * ch.w + (tx - ch.x0)
			var table: Array = _tables[g]
			var d: float = table[2]
			var blend := ch.blend[t]
			var home := ch.country[t]
			var away := ch.country2[t]
			# Drier toward the burning, sparser in the snow.
			if blend > 0.0:
				if away == Country.BURNING or away == Country.SNOWFIELD:
					d *= 1.0 - blend * 0.5
			var count := int(d + _rng.randf())
			if count <= 0:
				continue
			var shore := ch.shore[t]
			for k in count:
				var fx := _rng.randf()
				var fy := _rng.randf()
				var country := home
				var kind: int
				var r := _rng.randf()
				if _rng.randf() < blend:
					country = away
					kind = signature(away, r) if _rng.randf() < 0.55 else _pick(table, r)
				else:
					kind = _pick(table, r)
				if (kind == WRACK_BIT or kind == SHELL) and shore < -2.5:
					kind = PEBBLES if g == Ground.SHINGLE else TUFT
				var stage := 0
				if kind == FLOWER:
					var b := _bloom.get_noise_2d(tx + fx, ty + fy) * 0.5 + 0.5
					if b < 0.42:
						kind = TUFT
					stage = clampi(int((b - 0.42) / 0.58 * STAGES), 0, STAGES - 1)
				var tpl := template(kind, country, stage)
				var px := tx + fx
				var py := ty + fy
				var a := lerpf(ch.corners[t * 4], ch.corners[t * 4 + 1], fx)
				var b2 := lerpf(ch.corners[t * 4 + 3], ch.corners[t * 4 + 2], fx)
				var h := lerpf(a, b2, fy)
				var basis := Basis(Vector3.UP, _rng.randf() * TAU)
				var s := 0.8 + _rng.randf() * 0.45
				var xf := Transform3D(basis.scaled(Vector3(s, s, s)), Vector3(px, h - 0.005, py))
				v.append_array(xf * tpl.v)
				n.append_array(Transform3D(basis, Vector3.ZERO) * tpl.n)
				c.append_array(tpl.tones[1])
				uv.append_array(tpl.uv)
	# Rubble fallen from cliff faces.
	for foot: Array in ch.feet:
		var p: Vector3 = foot[0]
		var normal: Vector3 = foot[1]
		var country: int = foot[2]
		var drop: float = foot[3]
		var fx := floori(p.x + normal.x * 0.3)
		var fy := floori(p.z + normal.z * 0.3)
		if TerrainMesher.is_wet(w.ground_at(fx, fy)):
			continue
		var along := Vector3(-normal.z, 0, normal.x)
		var pieces := 1 + int(_rng.randf() * minf(4.0, drop * 1.6))
		for k in pieces:
			var off := along * (_rng.randf() - 0.5) * 0.9 + normal * (0.08 + _rng.randf() * _rng.randf() * 0.7)
			var tpl := template(RUBBLE, country, int(_rng.randf() * 2.0))
			var basis := Basis(Vector3.UP, _rng.randf() * TAU)
			var s := 0.7 + _rng.randf() * 0.7
			v.append_array(Transform3D(basis.scaled(Vector3(s, s, s)), p + off) * tpl.v)
			n.append_array(Transform3D(basis, Vector3.ZERO) * tpl.n)
			c.append_array(tpl.tones[1])
			uv.append_array(tpl.uv)
	if v.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _pick(table: Array, r: float) -> int:
	var types: PackedInt32Array = table[0]
	var cum: PackedFloat32Array = table[1]
	for i in cum.size():
		if r <= cum[i]:
			return types[i]
	return types[types.size() - 1]


static func template(kind: int, country: int, stage: int = 0) -> PropModels.Template:
	var key := (kind * 8 + country) * 4 + stage
	if not _templates.has(key):
		_templates[key] = PropModels.extract(kit(kind, country, stage))
	return _templates[key]


## Grass colours of a country: [blade, tip].
static func grass(c: int) -> Array[Color]:
	match c:
		Country.MOSS: return [P.SPRUCE[3], P.MOSS[3]]
		Country.PINEWOOD: return [P.SPRUCE[2], P.MOSS[2]]
		Country.SNOWFIELD: return [P.ASH[3], P.LINEN[3]]
		Country.BONELANDS: return [P.MOSS[4].lerp(P.SAND[4], 0.4), P.SAND[4]]
		Country.BURNING: return [P.EARTH[3], P.ASH[2]]
	return [P.MOSS[3], P.MOSS[4]]


static func kit(kind: int, c: int, stage: int) -> MeshKit:
	var k := MeshKit.new()
	var gr := grass(c)
	var rock := P.SLATE[2]
	match c:
		Country.BONELANDS: rock = P.LINEN[3]
		Country.BURNING: rock = P.INK[3]
		Country.SNOWFIELD: rock = P.SLATE[3]
		Country.MOSS, Country.PINEWOOD: rock = P.SLATE[2].lerp(P.SPRUCE[2], 0.3)
	var seed_value := kind * 131 + c * 17 + stage
	match kind:
		TUFT, TUFT_TALL:
			var blades := 5 if kind == TUFT else 7
			var hh := 0.16 if kind == TUFT else 0.3
			for i in blades:
				var a := float(i) / blades * TAU + Craft.j(seed_value, i, 0.4)
				var base := Vector3(cos(a) * 0.04, 0, sin(a) * 0.04)
				var tip := base * 2.5 + Vector3(0, hh * (0.7 + Rng.hash01(seed_value, i) * 0.5), 0)
				Craft.blade(k, base, tip, 0.05, a + 1.57, PropModels.sway(gr[i % 2], 0.8))
		HEATHER:
			var cols: Array[Color] = [P.EARTH[2].lerp(P.MOSS[1], 0.5), P.MOSS[1], P.EARTH[1]]
			Craft.blob(k, 0, -0.01, 0, 0.13, 0.13, seed_value, PropModels.sway(cols[stage % 3], 0.25), 5)
			for i in 3:
				var a := float(i) * 2.1
				k.block(cos(a) * 0.07, 0.08 + i * 0.015, sin(a) * 0.07, 0.04, 0.04, 0.04, PropModels.sway(P.BLOOM[1] if i != 1 else P.BLOOM[2], 0.3))
		FLOWER:
			var head: Color
			match c:
				Country.COAST: head = [P.BLOOM[2], P.BLOOM[3], P.BLOOM[4], P.LINEN[3]][stage]
				Country.BONELANDS: head = [P.RIME[2], P.BRINE[3], P.BRINE[4], P.LINEN[3]][stage]
				Country.MOSS: head = [P.RUST[3], P.RUST[4], P.RUST[5], P.EARTH[3]][stage]
				Country.BURNING: head = [P.BLOOM[1], P.BLOOM[2], P.BLOOM[3], P.ASH[3]][stage]
				_: head = [P.RUST[3], P.RUST[5], P.SAND[5], P.LINEN[3]][stage]
			for i in 2 + stage % 2:
				var a := float(i) * 2.4
				var base := Vector3(cos(a) * 0.03, 0, sin(a) * 0.03)
				var tip := base + Vector3(cos(a) * 0.03, 0.14 + i * 0.03, sin(a) * 0.03)
				Craft.blade(k, base, tip, 0.03, a, PropModels.sway(gr[0], 0.7))
				var hs := 0.035 + stage * 0.008
				k.block(tip.x, tip.y - 0.01, tip.z, hs, hs * 0.8, hs, PropModels.sway(head, 1.0))
		THISTLE:
			Craft.blade(k, Vector3.ZERO, Vector3(0.01, 0.28, 0), 0.03, 0.0, PropModels.sway(gr[0], 0.6))
			Craft.blade(k, Vector3.ZERO, Vector3(0.01, 0.28, 0), 0.03, 1.57, PropModels.sway(gr[0], 0.6))
			for i in 3:
				var a := float(i) * 2.1
				Craft.blade(k, Vector3(0, 0.05, 0), Vector3(cos(a) * 0.12, 0.1, sin(a) * 0.12), 0.05, a + 1.57, PropModels.sway(P.SPRUCE[3], 0.3))
			k.block(0.01, 0.26, 0, 0.06, 0.06, 0.06, PropModels.sway(P.BLOOM[2], 1.0))
		STONE:
			k.rock(0, -0.02, 0, 0.09 + stage * 0.02, 0.09, seed_value, rock, 5)
		PEBBLES:
			for i in 3:
				var a := float(i) * 2.2
				k.rock(cos(a) * 0.07, -0.01, sin(a) * 0.07, 0.035, 0.035, seed_value + i, [P.STONE[2], P.STONE[3], P.SAND[3]][i], 4)
		SHELL:
			k.tri(Vector3(0, 0.012, 0), Vector3(0.06, 0.012, 0.05), Vector3(0.07, 0.012, -0.03), P.LINEN[5])
			k.tri(Vector3(0, 0.014, 0), Vector3(0.07, 0.014, -0.03), Vector3(0.02, 0.014, -0.07), P.LINEN[4])
		BONE:
			k.strut(Vector3(-0.09, 0.02, 0), Vector3(0.09, 0.02, 0.03), 0.015, 3, P.LINEN[4])
			k.rock(0.1, 0.0, 0.03, 0.03, 0.035, seed_value, P.LINEN[5], 4)
		SNOW_TUFT:
			k.rock(0, -0.02, 0, 0.1, 0.05, seed_value, P.RIME[5], 5)
			for i in 4:
				var a := float(i) * 1.6
				var base := Vector3(cos(a) * 0.03, 0, sin(a) * 0.03)
				Craft.blade(k, base, base * 2.0 + Vector3(0, 0.15, 0), 0.04, a + 1.57, PropModels.sway(P.ASH[3] if i % 2 else P.LINEN[3], 0.7))
		ASH_FLAKE:
			k.quad(Vector3(-0.05, 0.012, -0.03), Vector3(-0.04, 0.012, 0.04), Vector3(0.06, 0.012, 0.03), Vector3(0.05, 0.012, -0.04), P.ASH[3] if stage % 2 == 0 else P.ASH[0])
		EMBER:
			k.block(0, 0.0, 0, 0.05, 0.025, 0.04, PropModels.glow(P.EMBER[3], 1.1))
		GLASS:
			k.tri(Vector3(-0.03, 0.01, 0), Vector3(0.03, 0.05, 0.01), Vector3(0.04, 0.01, -0.03), PropModels.glint(P.SPRUCE[3]))
		LICHEN:
			k.quad(Vector3(-0.06, 0.012, -0.02), Vector3(-0.02, 0.012, 0.06), Vector3(0.07, 0.012, 0.02), Vector3(0.03, 0.012, -0.06), P.LINEN[3] if stage % 2 == 0 else P.MOSS[4])
		CONE:
			k.push(Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, 0.03, 0.0)))
			k.prism(0, -0.05, 0, 0.03, 0.05, 0.015, 5, P.EARTH[2], P.EARTH[3])
			k.pop()
		BRACKEN:
			var fronds: Array[Color] = [P.RUST[3], P.EARTH[3], P.RUST[2]]
			if c == Country.SNOWFIELD or c == Country.BURNING:
				fronds = [P.EARTH[2], P.EARTH[1], P.ASH[2]]
			for i in 4:
				var a := float(i) / 4.0 * TAU + 0.3
				Craft.blade(k, Vector3(0, 0.02, 0), Vector3(cos(a) * 0.2, 0.2, sin(a) * 0.2), 0.1, a + 1.57, PropModels.sway(fronds[i % 3], 0.8))
		MUSHROOM:
			k.prism(0, 0, 0, 0.012, 0.05, 0.012, 4, P.LINEN[4])
			k.prism(0, 0.05, 0, 0.045, 0.08, 0.0, 6, P.RUST[3] if stage % 2 == 0 else P.LINEN[3])
		BOG_COTTON:
			for i in 3:
				var a := float(i) * 2.1
				var base := Vector3(cos(a) * 0.03, 0, sin(a) * 0.03)
				var tip := base * 2.0 + Vector3(0, 0.2 + i * 0.03, 0)
				Craft.blade(k, base, tip, 0.02, a, PropModels.sway(P.MOSS[2], 0.7))
				k.block(tip.x, tip.y, tip.z, 0.05, 0.05, 0.05, PropModels.sway(P.LINEN[5], 1.0))
		SEDGE:
			for i in 6:
				var a := float(i) / 6.0 * TAU + Craft.j(seed_value, i, 0.3)
				var base := Vector3(cos(a) * 0.03, 0, sin(a) * 0.03)
				Craft.blade(k, base, base * 4.0 + Vector3(0, 0.22, 0), 0.04, a + 1.57, PropModels.sway(P.SPRUCE[3] if i % 2 else gr[0], 0.8))
		MARRAM:
			for i in 6:
				var a := float(i) / 6.0 * TAU
				var base := Vector3(cos(a) * 0.03, 0, sin(a) * 0.03)
				Craft.blade(k, base, base * 3.0 + Vector3(0.03, 0.34, 0), 0.035, a + 1.57, PropModels.sway(P.SAND[4] if i % 2 else P.MOSS[4].lerp(P.SAND[4], 0.5), 0.9))
		TWIG:
			k.strut(Vector3(-0.12, 0.02, 0), Vector3(0.12, 0.02, 0.04), 0.012, 3, P.EARTH[1] if c != Country.BURNING else P.INK[2])
			k.strut(Vector3(0.0, 0.02, 0.01), Vector3(0.06, 0.02, 0.08), 0.008, 3, P.EARTH[2])
		PAPER:
			k.quad(Vector3(-0.05, 0.013, -0.035), Vector3(-0.05, 0.013, 0.035), Vector3(0.05, 0.013, 0.04), Vector3(0.05, 0.013, -0.03), P.LINEN[3])
			k.quad(Vector3(-0.045, 0.015, 0.0), Vector3(-0.045, 0.015, 0.008), Vector3(0.045, 0.015, 0.012), Vector3(0.045, 0.015, 0.004), P.LINEN[1])
		CINDER:
			k.rock(0, -0.01, 0, 0.04, 0.04, seed_value, P.INK[2], 4)
		SPHAGNUM:
			Craft.blob(k, 0, -0.02, 0, 0.12, 0.06, seed_value, P.RUST[2] if stage % 2 == 0 else P.MOSS[3], 6, 0.3)
		ICE_SHARD:
			k.tri(Vector3(-0.08, 0.01, 0), Vector3(0.05, 0.08, 0.02), Vector3(0.08, 0.01, -0.04), PropModels.glint(P.RIME[4]))
			k.tri(Vector3(0.08, 0.01, -0.04), Vector3(0.05, 0.08, 0.02), Vector3(0.0, 0.01, 0.06), P.RIME[5])
		RUBBLE:
			var rc := rock
			if c == Country.COAST:
				rc = P.SLATE[2]
			k.rock(0, -0.03, 0, 0.14, 0.14, seed_value + 3, rc, 5)
			k.rock(0.13, -0.03, 0.07, 0.08, 0.08, seed_value + 4, rc.darkened(0.15), 4)
			if stage == 1:
				k.rock(-0.12, -0.03, 0.1, 0.1, 0.07, seed_value + 5, rc.lightened(0.08), 5)
		SEA_GLASS:
			k.block(0, 0.0, 0, 0.04, 0.02, 0.03, PropModels.glint(P.SPRUCE[4] if stage % 2 == 0 else P.BRINE[5]))
			k.rock(0.06, -0.01, 0.04, 0.035, 0.03, seed_value, P.STONE[3], 4)
		MOLEHILL:
			Craft.blob(k, 0, -0.03, 0, 0.12, 0.1, seed_value, P.EARTH[2], 6, 0.35)
		FERN:
			for i in 5:
				var a := float(i) / 5.0 * TAU
				Craft.blade(k, Vector3(0, 0.01, 0), Vector3(cos(a) * 0.16, 0.16, sin(a) * 0.16), 0.07, a + 1.57, PropModels.sway(P.SPRUCE[3] if i % 2 else P.MOSS[3], 0.7))
		WRACK_BIT:
			k.quad(Vector3(-0.12, 0.012, -0.02), Vector3(-0.1, 0.012, 0.03), Vector3(0.12, 0.012, 0.02), Vector3(0.1, 0.012, -0.03), P.EARTH[1])
			k.quad(Vector3(-0.02, 0.014, -0.08), Vector3(0.02, 0.014, -0.08), Vector3(0.03, 0.014, 0.07), Vector3(-0.01, 0.014, 0.07), P.SPRUCE[1])
		CROTTLE:
			k.rock(0, -0.02, 0, 0.1, 0.09, seed_value, P.SLATE[2], 5)
			k.quad(Vector3(-0.04, 0.075, -0.03), Vector3(-0.03, 0.075, 0.04), Vector3(0.04, 0.07, 0.03), Vector3(0.03, 0.07, -0.04), P.LINEN[3])
	return k
