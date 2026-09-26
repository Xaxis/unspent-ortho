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
## Across an ecotone the neighbour's small life arrives before its wash: a
## share of the items on a tile (growing toward the border) are the other
## country's, so the first snow tufts and ash flakes are seen well before the
## ground itself turns.
##
## Plants sway by height (UV2.x); flowers follow a bloom field so a hillside
## flowers together and the next is still in bud.
##
## TWO SURFACES. Whatever sways (a template with any UV2.x above 0: tufts,
## reeds, flowers, fronds) is laid into the chunk's `grass` arrays and drawn on
## grass.gdshader, which bends it in the wind and parts it round bodies; stones,
## shells and litter are laid into the `decor` arrays on the world material.

enum {
	TUFT, TUFT_TALL, HEATHER, FLOWER, THISTLE, STONE, PEBBLES, SHELL, BONE,
	SNOW_TUFT, ASH_FLAKE, EMBER, GLASS, LICHEN, CONE, BRACKEN, MUSHROOM,
	BOG_COTTON, SEDGE, MARRAM, TWIG, CINDER, SPHAGNUM, ICE_SHARD, RUBBLE,
	SEA_GLASS, MOLEHILL, FERN, WRACK_BIT, CROTTLE,
	# What the world before left in the grass, and what the works shed.
	SCRAP, WIRE, CAN, SHELL_CASE, BOLT, SPOIL,
	# What the M2 landscapes shed: a lifted plate of salt crust, and iron
	# filings drawn into a comb by a field nothing turned off.
	SALT_PLATE, FILINGS,
	# What the drilling left behind it: a core pulled out of the rock and laid
	# where it was pulled, and a lump of cast stone with its rebar showing.
	DRILL_CORE, REBAR,
	# What the glassing left standing in its own floor: a plate of the sheet
	# broken and tipped up on edge, and a fulgurite, the fused tube a strike
	# drove into the sand, branching, dug half out by the wind.
	GLASS_SHARD, FULGURITE,
	# What the flood left on the drowned city's floor when it went down: a shoe,
	# a child's toy boat, a bottle, each silted and weeded where it came to rest.
	DROWNED_LITTER,
	# A flat slab in the crags with rings and a cup pecked into it by hand, older
	# than anything anybody here remembers.
	CUP_RING,
	# A landscape's own grasses: the first, second and third of its
	# `BiomeDef.grasses` (GrassSpecies), laid through its own d.decor.
	GRASS_A, GRASS_B, GRASS_C,
}
## The enum above, counted. Adding a kind and forgetting this reads off the end
## of `_SPECK` on the first chunk built, so a test asserts the two agree.
const KINDS := 47
## Litter by kind of work (WorksMap channel): cut, scorch, quarry, bores.
const WORKS_LITTER: Array = [[SCRAP, BOLT, WIRE], [SCRAP, CINDER, CAN], [SPOIL, BOLT, STONE], [SPOIL, BOLT, SCRAP]]
## Share of a tile's items that are litter outside any work, and inside one.
const LITTER_STRAY := 0.04
const LITTER_WORKS := 0.45
const STAGES := 3
## Tiles from something standing within which a grass with a `lee` drifts.
const LEE_REACH := 2.5
## Triangles a plant carries per step of weight: under the lens a heavier plant
## thins sooner with distance (grass.gdshader).
const HEAVY_TRIS := 40

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")

var world: WorldData
## The machines' works (WorksMap), when a view has baked one: scrap gathers in
## them and the growing things thin.
var works: WorksMap
var _bloom: FastNoiseLite
## Where small life gathers: specks come in drifts and the ground between is
## left bare (docs/LOOK.md: masses stay flat, interest lives in rare places).
var _clump: FastNoiseLite
static var _SPECK := PackedByteArray()
## ground -> [kinds: PackedInt32Array, cumulative: PackedFloat32Array, items per tile]
var _tables: Dictionary = {}
static var _templates: Dictionary = {}
## Decor is built on a worker thread while the main thread may build too.
static var _lock := Mutex.new()


## Raw arrays of one decor model.
class Tpl:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	## Anything of it sways: it belongs on the grass surface.
	var sways := false
	## A species' GrassSpecies.motion_code, added to each plant's seed in UV2.y.
	var motion := 0
	## A species that casts (GrassSpecies.casts): laid on the casting grass surface.
	var casts := false


## One surface being laid.
class Out:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()

	## `seed` >= 0 lays a PLANT for grass.gdshader: every vertex's UV2.y becomes
	## the plant's seed and its UV the plant's root in world xz, so all its
	## corners decide together how far off it stands.
	func put(tpl: Tpl, xf: Transform3D, turn: Basis, seed: float = -1.0) -> void:
		v.append_array(xf * tpl.v)
		n.append_array(Transform3D(turn, Vector3.ZERO) * tpl.n)
		c.append_array(tpl.c)
		if seed < 0.0:
			uv.append_array(tpl.uv)
			uv2.append_array(tpl.uv2)
		else:
			var root := Vector2(xf.origin.x, xf.origin.z)
			for w: Vector2 in tpl.uv2:
				uv.append(root)
				uv2.append(Vector2(w.x, float(tpl.motion) + seed))

	func arrays() -> Array:
		if v.is_empty():
			return []
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = v
		a[Mesh.ARRAY_NORMAL] = n
		a[Mesh.ARRAY_COLOR] = c
		a[Mesh.ARRAY_TEX_UV] = uv
		a[Mesh.ARRAY_TEX_UV2] = uv2
		return a


func _init(w: WorldData) -> void:
	world = w
	_bloom = FastNoiseLite.new()
	_bloom.seed = Rng.hash_ints(w.seed_value, 0xB100) & 0x7FFFFFFF
	_bloom.frequency = 1.0 / 38.0
	_bloom.fractal_octaves = 2
	_clump = FastNoiseLite.new()
	_clump.seed = Rng.hash_ints(w.seed_value, 0xC1A) & 0x7FFFFFFF
	_clump.frequency = 1.0 / 9.0
	_clump.fractal_octaves = 2
	if _SPECK.is_empty():
		_SPECK.resize(KINDS)
		for kd: int in [EMBER, ASH_FLAKE, CINDER, GLASS, SHELL, BOG_COTTON, PEBBLES, SEA_GLASS, CROTTLE, LICHEN, FLOWER, THISTLE, MUSHROOM, BONE, TWIG, ICE_SHARD, WRACK_BIT, SPHAGNUM, CAN, SHELL_CASE, BOLT]:
			_SPECK[kd] = 1
	_table(Ground.GRASS, 1.1, [TUFT, 46, TUFT_TALL, 12, FLOWER, 12, STONE, 2, THISTLE, 3, MOLEHILL, 2])
	_table(Ground.HEATH, 1.2, [HEATHER, 50, TUFT, 14, STONE, 2, FLOWER, 4, BRACKEN, 7])
	_table(Ground.SAND, 0.3, [MARRAM, 26, SHELL, 16, PEBBLES, 10, TWIG, 5, WRACK_BIT, 6])
	_table(Ground.SHINGLE, 0.5, [PEBBLES, 40, SEA_GLASS, 5, SHELL, 10, WRACK_BIT, 8, STONE, 12])
	_table(Ground.GRAVEL, 0.3, [PEBBLES, 30, STONE, 10, TUFT, 6])
	_table(Ground.MOSS, 1.2, [SEDGE, 30, BOG_COTTON, 22, SPHAGNUM, 16, TUFT, 8, FLOWER, 4])
	_table(Ground.MUD, 0.4, [SEDGE, 20, TWIG, 8, PEBBLES, 6])
	_table(Ground.PEAT, 0.7, [HEATHER, 30, BOG_COTTON, 28, SEDGE, 18])
	_table(Ground.NEEDLES, 0.8, [CONE, 30, BRACKEN, 20, TWIG, 18, MUSHROOM, 6, FERN, 8])
	_table(Ground.SNOW, 0.28, [SNOW_TUFT, 40, CROTTLE, 5, STONE, 3, TWIG, 4])
	_table(Ground.ICE, 0.08, [ICE_SHARD, 10])
	# The bonelands was the emptiest landscape on the screen (art review 14) and
	# its spec is the densest in evidence: bones, drill-hole rows, cast stone
	# with rebar, and what the survey shed while it worked.
	_table(Ground.BONE, 0.9, [FERN, 14, STONE, 20, TUFT, 14, FLOWER, 5, BONE, 10, DRILL_CORE, 8, REBAR, 7, SPOIL, 8, BOLT, 6, SCRAP, 4, CROTTLE, 4])
	_table(Ground.LIMESTONE, 0.9, [FERN, 14, STONE, 20, TUFT, 14, FLOWER, 5, BONE, 10, DRILL_CORE, 8, REBAR, 7, SPOIL, 8, BOLT, 6, SCRAP, 4, CROTTLE, 4])
	_table(Ground.SCREE, 0.9, [STONE, 55, PEBBLES, 30, LICHEN, 8])
	_table(Ground.ASH, 0.6, [ASH_FLAKE, 30, CINDER, 30, EMBER, 6, TWIG, 8])
	_table(Ground.CLINKER, 0.45, [GLASS, 26, CINDER, 40])
	_table(Ground.ROCK, 0.35, [LICHEN, 30, STONE, 34, TUFT, 6])
	_table(Ground.ROAD, 0.08, [PEBBLES, 10, TUFT, 3])
	# A landscape's own version of a ground, keyed ground * SLOTS + type + 1000,
	# straight out of BiomeDef.decor: adding a landscape adds no code here, and
	# what a landscape sheds on its own ground is declared beside everything
	# else about it.
	for d: BiomeDef in BiomeRegistry.all():
		for g: int in d.decor:
			var row: Array = d.decor[g]
			# row[0] is the density, or Vector2(density, evenness): see `_table`.
			var head: Variant = row[0]
			var dens := (head as Vector2).x if head is Vector2 else float(head)
			var even := (head as Vector2).y if head is Vector2 else 0.0
			_table(g * BiomeRegistry.SLOTS + d.index + 1000, dens, row.slice(1), even)


## `even` 0..1: how far the drifts give way to an even cover. At 0 a tile carries
## density x (0.45 + clump), so the ground between drifts lies nearly bare, which
## is right for specks and stones; a sward wants the clumping as variation in
## how thick it stands, not as holes (1: density x (0.8 + 0.4 x clump)).
func _table(g: int, density: float, pairs: Array, even: float = 0.0) -> void:
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
	_tables[g] = [kinds, cum, density, even]


## Share of a tile's decor that is the neighbour's at blend b (0..0.5): ahead
## of TerrainMesher.eco_cover, so the small things cross first.
static func lead_share(b: float) -> float:
	return clampf(b * 2.0, 0.0, 1.0) * 0.55


## Items per tile of a ground (0 for grounds that carry none).
func density(g: int) -> float:
	if not _tables.has(g):
		return 0.0
	return _tables[g][2]


func build(ch: TerrainMesher.Chunk) -> ArrayMesh:
	return make_mesh(build_arrays(ch))


## The mesh of arrays from build_arrays() (main thread), or null.
static func make_mesh(arrays: Array) -> ArrayMesh:
	if arrays.is_empty():
		return null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Surface arrays of ALL a chunk's decor, both surfaces as one ([] for none).
func build_arrays(ch: TerrainMesher.Chunk) -> Array:
	var parts := build_parts(ch)
	var all := Out.new()
	for a: Array in parts:
		if a.is_empty():
			continue
		all.v.append_array(a[Mesh.ARRAY_VERTEX])
		all.n.append_array(a[Mesh.ARRAY_NORMAL])
		all.c.append_array(a[Mesh.ARRAY_COLOR])
		all.uv.append_array(a[Mesh.ARRAY_TEX_UV])
		all.uv2.append_array(a[Mesh.ARRAY_TEX_UV2])
	return all.arrays()


## A chunk's decor as [solid arrays, grass arrays, casting grass arrays], each []
## when empty. `props`: what stands in the chunk (WorldProp), which a grass with
## a `lee` drifts against. Safe on
## a worker thread.
func build_parts(ch: TerrainMesher.Chunk, props: Array = []) -> Array:
	var rng := Rng.make(world.seed_value, Rng.hash_ints(ch.cx, ch.cy, 0xDEC0))
	var solid := Out.new()
	var grass := Out.new()
	var cast := Out.new()
	var stands := PackedVector2Array()
	for q: WorldProp in props:
		if q.solid > 0.0:
			stands.append(q.pos)
	var np := ch.n + 1
	for ty in ch.h:
		for tx in ch.w:
			var k := turf(ch, tx, ty)
			if k < 0:
				continue
			var t := ch.t[ty * 2 * np + tx * 2 + np + 1]
			var g := k & 0xFF
			var table: Array = _tables.get(g * BiomeRegistry.SLOTS + ((k >> 8) & 0xFF) + 1000, _tables.get(g, []))
			if table.is_empty():
				continue
			var gather := _clump.get_noise_2d(ch.x0 + tx, ch.y0 + ty) * 0.5 + 0.5
			var even: float = table[3]
			var count := int(float(table[2]) * lerpf(0.45 + gather, 0.8 + 0.4 * gather, even) + rng.randf())
			if count <= 0:
				continue
			var country := (k >> 8) & 0xFF
			# The other side of the ecotone, and how much of its decor is here.
			var ti := ty * ch.w + tx
			var home := world.country_at(ch.x0 + tx, ch.y0 + ty)
			var other := int(ch.c2[ti]) if country == home else home
			var lead := lead_share(ch.blend[ti]) if other > 0 and other != country else 0.0
			var other_table: Array = _tables.get(g * BiomeRegistry.SLOTS + other + 1000, _tables.get(GroundColors.home_turf(other), [])) if lead > 0.0 else []
			var h := TerrainMesher.level_height(t) - 0.004
			var soft := g == Ground.MOSS or g == Ground.PEAT or g == Ground.SNOW or g == Ground.HEATH
			var shore := ch.shore[ty * ch.w + tx]
			var wx := ch.x0 + tx
			var wy := ch.y0 + ty
			# In the lee of something standing: the drift a species with a `lee`
			# lays against it, as extra plants of that species on this tile.
			var lee_kind := -1
			if not stands.is_empty():
				var near := LEE_REACH
				var mid := Vector2(wx + 0.5, wy + 0.5)
				for sp: Vector2 in stands:
					near = minf(near, mid.distance_to(sp))
				if near < LEE_REACH:
					var own_grasses := BiomeRegistry.by_index(country).grasses
					for gi in own_grasses.size():
						var gs: GrassSpecies = own_grasses[gi]
						if gs.lee > 0.0 and (table[0] as PackedInt32Array).has(GRASS_A + gi):
							lee_kind = GRASS_A + gi
							count += int(gs.lee * (1.0 - near / LEE_REACH) + rng.randf())
							break
			for i in count:
				var dress := country
				var kind: int
				if not other_table.is_empty() and rng.randf() < lead:
					kind = _pick(other_table, rng.randf())
					dress = other
				else:
					kind = _pick(table, rng.randf())
				if lee_kind >= 0 and i >= count - 3 and rng.randf() < 0.8:
					kind = lee_kind
				if _SPECK[kind] == 1 and gather < 0.56:
					# Out of a drift: the ground's own blades and stones only.
					kind = _pick(table, 0.0)
					if _SPECK[kind] == 1:
						continue
				if (kind == WRACK_BIT or kind == SHELL or kind == SEA_GLASS) and shore < -3.0:
					kind = PEBBLES if g == Ground.SHINGLE else (MARRAM if g == Ground.SAND else TUFT)
				var fx := 0.08 + rng.randf() * 0.84
				var fy := 0.08 + rng.randf() * 0.84
				# A grass that seeks the crust's cracks roots on the nearest lifted
				# rim, or not at all (SaltCrust, the ground's own plates).
				if g == Ground.SALT and kind >= GRASS_A and kind <= GRASS_C and species(kind, dress).rims:
					var on := SaltCrust.snap(Vector2(wx + fx, wy + fy))
					if on == Vector2.INF or floori(on.x) != wx or floori(on.y) != wy:
						continue
					fx = on.x - wx
					fy = on.y - wy
				# Litter: a stray piece anywhere, thick where the machines worked.
				var lr := rng.randf()
				if works != null:
					var strongest := -1
					var best := 0.3
					for wc in 4:
						var wv := works.at(wx, wy, wc)
						if wv > best:
							best = wv
							strongest = wc
					if strongest >= 0 and lr < LITTER_WORKS * best:
						var pool: Array = WORKS_LITTER[strongest]
						kind = pool[int(lr * 97.0) % pool.size()]
						dress = country
					elif lr < LITTER_STRAY and g != Ground.ICE:
						kind = [SCRAP, WIRE, CAN, SHELL_CASE][int(lr * 997.0) % 4]
						dress = country
				var stage := 0
				if kind == FLOWER:
					var bl := _bloom.get_noise_2d(wx + fx, wy + fy) * 0.5 + 0.5
					if bl < 0.4:
						kind = TUFT
					stage = clampi(int((bl - 0.4) / 0.6 * STAGES), 0, STAGES - 1)
				elif kind == HEATHER:
					# Heather flowers where the hill is in bloom, and is brown elsewhere.
					var hb := _bloom.get_noise_2d(wx + fx + 91.0, wy + fy) * 0.5 + 0.5
					stage = 0 if hb > 0.62 else 1 + rng.randi() % 2
				else:
					stage = rng.randi() % STAGES
				var tpl := template(kind, dress, stage)
				var s := 0.8 + rng.randf() * 0.45
				var basis := Basis(Vector3.UP, rng.randf() * TAU)
				var hy := ch.surface(wx + fx, wy + fy) - 0.004 if soft else h
				var xf := Transform3D(basis.scaled(Vector3(s, s, s)), Vector3(wx + fx, hy, wy + fy))
				if tpl.sways:
					# Each plant its own seed: its beat in the wind, and whether it
					# is one of those a far chunk leaves out (grass.gdshader).
					(cast if tpl.casts else grass).put(tpl, xf, basis, Rng.hash01(wx, wy, i, 0x5eed))
				else:
					solid.put(tpl, xf, basis)
	# Rubble fallen from cliff faces, more of it where the rock is hard.
	for fi in ch.feet.size():
		var foot := ch.feet[fi]
		var out := ch.feet_out[fi]
		var country := int(ch.feet_country[fi])
		# Rubble gathers under the stretches of face that are falling, and the
		# rest of the foot is clean: never a dotted line along every contour.
		var fall := _clump.get_noise_2d(foot.x * 1.7 + 400.0, foot.z * 1.7) * 0.5 + 0.5
		var chance := (0.5 if BiomeRegistry.by_index(country).hard_rock else 0.3) * clampf((fall - 0.45) * 3.0, 0.0, 1.0)
		if rng.randf() > chance:
			continue
		var p := foot + out * (0.05 + rng.randf() * 0.25)
		if not _flat_at(ch, p.x, p.z):
			continue
		var along := Vector3(-out.z, 0, out.x)
		var tpl := template(RUBBLE, country, rng.randi() % STAGES)
		var s := 0.7 + rng.randf() * 0.6
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		solid.put(tpl, Transform3D(basis.scaled(Vector3(s, s, s)), p + along * (rng.randf() - 0.5) * 0.4), basis)
	return [solid.arrays(), grass.arrays(), cast.arrays()]


## The drawn key of chunk tile (tx, ty) when it is turf decor may grow on, else
## -1. A tile's 3x3 lattice points must be one terrace and one GROUND, dry: a key
## that differs only in its country (an ecotone's blend) is the same turf, and
## refusing it left bare strips through the grass along every border. The one
## rule for where anything small stands, so the meadow ring grows exactly where
## the baked decor does and never hangs over a lip.
static func turf(ch: TerrainMesher.Chunk, tx: int, ty: int) -> int:
	var np := ch.n + 1
	var li := ty * 2 * np + tx * 2
	var k := ch.key[li + np + 1]
	var t := ch.t[li + np + 1]
	if t <= 0 or (k & 0x10000) != 0:
		return -1
	for o: int in [0, 1, 2, np, np + 2, np * 2, np * 2 + 1, np * 2 + 2]:
		if (ch.key[li + o] & 0x100FF) != (k & 0x100FF) or ch.t[li + o] != t:
			return -1
	return k


## THE MEADOW: what the meadow ring (MeadowView) stands on chunk tiles
## [tx0, tx0 + w) x [ty0, ty0 + h): the same plants the baked decor lays there,
## `thick` times as many of them and none of its stones or litter. Each tile is
## decided by its own world position (Decor.turf, and a generator seeded by the
## tile), so a plant stands where it stands whatever cell asked for it: the ring
## is pinned to the world and never swims as it follows the eye.
##
## {template key (template_of): PackedFloat32Array}, MEADOW_FLOATS per plant in
## MultiMesh order: its transform's three rows (basis columns' x, y, z with the
## origin last in each), its colour (white: the template's own is its vertices',
## and the Compatibility renderer, given no instance colour, dyed a blade with
## whatever lay there) and its custom data (x the plant's seed 0..1, which
## grass.gdshader reads in place of UV2.y's). Safe on a worker thread.
const MEADOW_FLOATS := 20
## Where a plant's custom data starts among them, past its colour.
const MEADOW_CUSTOM := 16
## How many more plants than the baked decor the meadow ring stands at full
## density (Quality `grass_density` 1.0).
const MEADOW_THICK := 5.0


func meadow(ch: TerrainMesher.Chunk, tx0: int, ty0: int, w: int, h: int, thick: float) -> Dictionary:
	var out := {}
	var np := ch.n + 1
	for ty in range(ty0, mini(ty0 + h, ch.h)):
		for tx in range(tx0, mini(tx0 + w, ch.w)):
			var k := turf(ch, tx, ty)
			if k < 0:
				continue
			var g := k & 0xFF
			# Salt grass roots only on the crust's rims (build_parts); the meadow
			# leaves that ground to the decor.
			if g == Ground.SALT:
				continue
			var country := (k >> 8) & 0xFF
			var tkey := g * BiomeRegistry.SLOTS + country + 1000
			if not _tables.has(tkey):
				tkey = g
				if not _tables.has(tkey):
					continue
			var sway := _sway_table(tkey, country)
			if sway.is_empty():
				continue
			var table: Array = _tables[tkey]
			var wx := ch.x0 + tx
			var wy := ch.y0 + ty
			var rng := Rng.make(world.seed_value, Rng.hash_ints(wx, wy, 0x3EAD))
			var gather := _clump.get_noise_2d(wx, wy) * 0.5 + 0.5
			var even: float = table[3]
			var n := float(table[2]) * float(sway[2]) * thick * lerpf(0.45 + gather, 0.8 + 0.4 * gather, even)
			if works != null:
				var best := 0.3
				for wc in 4:
					best = maxf(best, works.at(wx, wy, wc))
				if best > 0.3:
					n *= 1.0 - LITTER_WORKS * best
			var count := int(n + rng.randf())
			var t := ch.t[ty * 2 * np + tx * 2 + np + 1]
			var flat := TerrainMesher.level_height(t) - 0.004
			var soft := g == Ground.MOSS or g == Ground.PEAT or g == Ground.SNOW or g == Ground.HEATH
			for i in count:
				var kind := _pick(sway, rng.randf())
				var fx := 0.04 + rng.randf() * 0.92
				var fy := 0.04 + rng.randf() * 0.92
				var stage := rng.randi() % STAGES
				if kind == FLOWER:
					var bl := _bloom.get_noise_2d(wx + fx, wy + fy) * 0.5 + 0.5
					if bl < 0.4:
						kind = TUFT
					stage = clampi(int((bl - 0.4) / 0.6 * STAGES), 0, STAGES - 1)
				var sc := 0.8 + rng.randf() * 0.45
				var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc))
				var o := Vector3(wx + fx, ch.surface(wx + fx, wy + fy) - 0.004 if soft else flat, wy + fy)
				var key := (kind * BiomeRegistry.SLOTS + country) * 4 + stage
				var buf: PackedFloat32Array = out.get(key, PackedFloat32Array())
				buf.append_array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z,
					1.0, 1.0, 1.0, 1.0, Rng.hash01(wx, wy, i, 0x5eed), 0.0, 0.0, 0.0])
				out[key] = buf
	return out


## The template a meadow key names: (kind * SLOTS + country) * 4 + stage.
static func template_of(key: int) -> Tpl:
	var kd := key / 4
	return template(kd / BiomeRegistry.SLOTS, kd % BiomeRegistry.SLOTS, key % 4)


## Only the kinds of a decor table that sway, as [kinds, cumulative, share of the
## table's weight they carry]; [] when none do.
var _sway: Dictionary = {}
func _sway_table(tkey: int, country: int) -> Array:
	if _sway.has(tkey):
		return _sway[tkey]
	var table: Array = _tables[tkey]
	var kinds: PackedInt32Array = table[0]
	var cum: PackedFloat32Array = table[1]
	var picked := PackedInt32Array()
	var weights := PackedFloat32Array()
	var total := 0.0
	for i in kinds.size():
		var wgt := cum[i] - (cum[i - 1] if i > 0 else 0.0)
		if template(kinds[i], country, 0).sways:
			picked.append(kinds[i])
			weights.append(wgt)
			total += wgt
	var row: Array = []
	if total > 0.0:
		var acc := PackedFloat32Array()
		var run := 0.0
		for wgt in weights:
			run += wgt / total
			acc.append(run)
		row = [picked, acc, total]
	_sway[tkey] = row
	return row


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
	var key := (kind * BiomeRegistry.SLOTS + country) * 4 + stage
	_lock.lock()
	var t: Tpl = _templates.get(key)
	if t == null:
		var k := kit(kind, country, stage)
		t = Tpl.new()
		t.v = k.made.verts
		t.n = k.made.normals
		t.c = k.made.colors
		t.uv = k.made.uvs
		t.uv2 = k.made.uv2s
		for w: Vector2 in t.uv2:
			if w.x > 0.0:
				t.sways = true
				break
		if kind >= GRASS_A and kind <= GRASS_C:
			t.motion = species(kind, country).motion_code()
			t.casts = species(kind, country).casts
		if t.sways:
			t.motion += 100 * clampi(t.v.size() / 3 / HEAVY_TRIS, 0, 9)
		_templates[key] = t
	_lock.unlock()
	return t


## The landscape's grass that GRASS_A/B/C stands for, or the one grown from its
## grass colours when it declares none.
static func species(kind: int, c: int) -> GrassSpecies:
	var own := BiomeRegistry.by_index(c).grasses
	var i := kind - GRASS_A
	if i >= 0 and i < own.size():
		return own[i]
	return GrassSpecies.fallback(grass(c))


## A patch of one grass: blades rooted over a disc, each a thin one-sided sickle
## (grass.gdshader draws both faces and lights it as grass), laid toward one
## bearing by the stage so neighbouring patches do not comb alike. Fronds hang
## leaflets down each side of a blade; seed heads sit at its tip.
static func _grow(k: Kit, g: GrassSpecies, s: int, stage: int) -> void:
	var bearing := float(stage) * 2.1 + 0.6
	for i in g.blades:
		var r := sqrt(Rng.hash01(s, i, 11)) * g.spread
		var at := Rng.hash01(s, i, 13) * TAU
		var base := Vector3(cos(at) * r, 0.0, sin(at) * r)
		var a := lerp_angle(at, bearing, g.lay) + Kit.j(s, i, 0.9)
		var out := Vector3(cos(a), 0.0, sin(a))
		var hh := lerpf(g.height.x, g.height.y, Rng.hash01(s, i, 3))
		var reach := hh * lerpf(g.reach.x, g.reach.y, Rng.hash01(s, i, 7))
		var tint := Rng.hash01(s, i, 17) * 0.3
		var root := g.root.lerp(g.tip, tint * 0.5)
		var top := g.tip.lerp(g.root, tint)
		if g.other_share > 0.0 and Rng.hash01(s, i, 23) < g.other_share:
			root = root.lerp(g.other, 0.7)
			top = top.lerp(g.other, 0.5)
		if g.leaflets > 0:
			_frond(k, g, s, i, base, out, hh, reach, root, top)
			continue
		var tip := base + out * reach + Vector3(0.0, hh * 0.94, 0.0)
		k.sickle(base, tip, out * reach * g.curl + Vector3(0.0, hh * 0.08, 0.0), g.width, a + 1.57, root, top)
		if i < g.heads:
			# A soft head, not a flake: a small rounded tuft on the stem's tip.
			_head(k, tip + Vector3(0.0, g.head_size * 0.35, 0.0), g.head_size * 0.55, g.head_color)
	k.sway_by_height(0, 0.0, g.height.y, 1.0)


## A seed head: a small eight-faced puff, lit by grass.gdshader's sky-bent
## normal so it reads as a soft round tuft. Eight triangles where a clump was
## thirty: a bog is thick with them.
static func _head(k: Kit, c: Vector3, r: float, col: Color) -> void:
	var up := c + Vector3(0.0, r * 1.2, 0.0)
	var dn := c - Vector3(0.0, r * 0.9, 0.0)
	var ring: Array[Vector3] = [c + Vector3(r, 0, 0), c + Vector3(0, 0, r), c + Vector3(-r, 0, 0), c + Vector3(0, 0, -r)]
	for n in 4:
		var a := ring[n]
		var b := ring[(n + 1) % 4]
		k.made.tri(a, b, up, col)
		k.made.tri(b, a, dn, col)


## Where along a frond's arch its rachis is at `t` 0..1: up out of the crown,
## out along `out`, and arching over so the outer third hangs (`curl`).
static func _arch(base: Vector3, out: Vector3, hh: float, reach: float, curl: float, t: float) -> Vector3:
	# Peaks at hh a share 1 / (1 + curl) of the way out, then falls away.
	var rise := hh * sin(t * PI * 0.5 * (1.0 + curl))
	return base + out * reach * t + Vector3(0.0, rise, 0.0)


## A frond: a thin rachis arching out of the crown in FROND_SEGS segments, and
## down each side of it, leaflets that are themselves thin curved sickles, lying
## near flat so they face the sky, shortening toward the tip and paler there.
## The broad single blade under a fishbone of triangles read as a card.
const FROND_SEGS := 4
static func _frond(k: Kit, g: GrassSpecies, s: int, i: int, base: Vector3, out: Vector3, hh: float, reach: float, root: Color, top: Color) -> void:
	var side := Vector3(-out.z, 0.0, out.x)
	var prev := base
	for n in FROND_SEGS:
		var t1 := float(n + 1) / FROND_SEGS
		var p1 := _arch(base, out, hh, reach, g.curl, t1)
		var w := g.width * (1.0 - float(n) / FROND_SEGS * 0.7)
		k.made.tri(prev - side * w * 0.5, prev + side * w * 0.5, p1, root.lerp(top, t1))
		prev = p1
	for j in g.leaflets:
		var t := 0.22 + 0.74 * float(j) / float(g.leaflets)
		var p := _arch(base, out, hh, reach, g.curl, t)
		var along := (_arch(base, out, hh, reach, g.curl, minf(t + 0.05, 1.0)) - p).normalized()
		var ll := hh * g.leaflet * (1.0 - t * 0.7) * (0.85 + 0.3 * Rng.hash01(s, i * 37 + j, 29))
		var col := root.lerp(top, t)
		for sd: float in [-1.0, 1.0]:
			var droop := 0.12 + 0.2 * Rng.hash01(s, i * 31 + j, 19 + int(sd))
			var dir := (side * sd + along * 0.55).normalized()
			var leaf_tip := p + dir * ll - Vector3(0.0, ll * droop, 0.0)
			# Width across the leaflet, horizontal, so it lies to the sky.
			var across := Vector3(-dir.z, 0.0, dir.x)
			k.sickle(p, leaf_tip, along * ll * 0.12, ll * 0.34, atan2(across.z, across.x), col, top.lerp(g.tip_pale, 0.5))


## Grass colours of a landscape: [blade, tip].
static func grass(c: int) -> Array[Color]:
	var cols := BiomeRegistry.by_index(c).grass_colors
	if cols.size() >= 2:
		return cols
	return [P.MOSS[3], P.MOSS[4].lerp(P.SLATE[3], 0.2)]


static func rock_of(c: int) -> Color:
	return BiomeRegistry.by_index(c).rock_color


## A landscape's own colours for one kind of small life, or the shared ones.
static func _tint(c: int, key: StringName, fallback: Array[Color]) -> Array[Color]:
	var own: Variant = BiomeRegistry.by_index(c).decor_tints.get(key)
	if own is Array and not (own as Array).is_empty():
		var out: Array[Color] = []
		out.assign(own)
		return out
	return fallback


static func kit(kind: int, c: int, stage: int) -> Kit:
	var k := Kit.new()
	k.hand(BiomeRegistry.by_index(c).hatch)
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
			# One clump in three is in bloom; the rest are the brown of the hill.
			if stage == 0:
				for i in 4:
					var a := float(i) * 1.7
					var p := Vector3(cos(a) * 0.08, 0.1 + i * 0.012, sin(a) * 0.08)
					k.fleck(p, p + Vector3(0.035, 0.0, 0.01), p + Vector3(0.01, 0.035, 0.0), P.BLOOM[1] if i % 2 else P.BLOOM[2])
			k.sway_by_height(0, 0.0, 0.14, 0.25)
		FLOWER:
			var head: Color = _tint(c, &"bloom", [P.RUST[4], P.SAND[5], P.LINEN[4]])[stage]
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
			var fronds := _tint(c, &"fronds", [P.RUST[3], P.EARTH[3], P.RUST[2]])
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
			k.limb(Vector3(-0.12, 0.02, 0), Vector3(0.12, 0.02, 0.04), 0.013, 0.008, 3, _tint(c, &"twig", [P.EARTH[1]])[0])
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
		SCRAP:
			# A shard of plate or panel, bent, rust at its edge.
			var col: Color = [P.RUST[2], P.SLATE[3], P.RUST[3]][stage]
			k.made.quad(Vector3(-0.1, 0.012, -0.05), Vector3(0.09, 0.014, -0.07), Vector3(0.11, 0.04, 0.05), Vector3(-0.08, 0.02, 0.06), col)
			k.made.quad(Vector3(-0.08, 0.02, 0.06), Vector3(0.11, 0.04, 0.05), Vector3(0.1, 0.012, 0.09), Vector3(-0.09, 0.012, 0.1), GroundColors.down(col, 0.4))
		WIRE:
			k.sag(Vector3(-0.16, 0.015, -0.04), Vector3(0.05, 0.02, 0.08), -0.02, 3, 0.006, P.INK[2])
			k.sag(Vector3(0.05, 0.02, 0.08), Vector3(0.15, 0.015, -0.06), -0.015, 2, 0.006, P.COPPER[2] if stage == 0 else P.INK[2])
		CAN:
			k.made.push(Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, 0.03, 0.0)))
			k.made.prism(0, -0.04, 0, 0.028, 0.04, 0.028, 6, [P.RUST[3], P.SLATE[3], P.BRINE[2]][stage], P.STONE[3])
			k.made.pop()
		SHELL_CASE:
			k.made.push(Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.UP, stage), Vector3(0.0, 0.012, 0.0)))
			k.made.prism(0, -0.03, 0, 0.011, 0.03, 0.011, 5, P.COPPER[3], P.COPPER[2])
			k.made.pop()
		BOLT:
			k.made.prism(0, 0.0, 0, 0.022, 0.018, 0.022, 6, P.STONE[2], P.STONE[3])
			k.made.prism(0.03, 0.0, 0.01, 0.009, 0.012, 0.009, 4, P.RUST[2])
		SPOIL:
			k.stone(0, -0.02, 0, 0.09, 0.05, s, _tint(c, &"spoil", [P.STONE[3]])[0], 5, 0.2)
			k.stone(0.1, -0.02, 0.04, 0.05, 0.04, s + 1, P.LINEN[3], 4)
		DRILL_CORE:
			# A core, pulled and dropped: a stubby cylinder of pale rock lying on
			# its side with its banding across it, half sunk where it landed.
			k.made.push(Transform3D(Basis(Vector3.UP, float(stage) * 1.1) * Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, 0.035, 0.0)))
			k.made.prism(0, -0.11, 0, 0.035, 0.11, 0.035, 7, P.LINEN[4], P.LINEN[5])
			k.made.prism(0, -0.02, 0, 0.037, 0.01, 0.037, 7, P.LINEN[2])
			k.made.pop()
		GRASS_A, GRASS_B, GRASS_C:
			_grow(k, species(kind, c), s, stage)
		REBAR:
			# A lump of cast stone broken off something, its bars standing out of
			# the break, rusted to the colour of what is left of the old world.
			k.stone(0, -0.03, 0, 0.11, 0.09, s, P.STONE[3].lerp(P.LINEN[3], 0.4), 5, 0.15)
			for i in 3:
				var ra := float(i) * 2.1 + 0.4
				var rb := Vector3(cos(ra) * 0.03, 0.06, sin(ra) * 0.03)
				k.limb(rb, rb + Vector3(cos(ra) * 0.09, 0.13 + float(i) * 0.03, sin(ra) * 0.09), 0.012, 0.009, 3, P.RUST[2] if i % 2 else P.RUST[3])
		GLASS_SHARD:
			# A plate of the fused sheet, snapped and tipped up on edge: green-black
			# on its faces, a pale fracture along its broken top edge, and the face
			# turned to the sky glints. Leaning, never upright, never square.
			var lean := 0.35 + float(stage) * 0.2
			var w := 0.16 + float(stage) * 0.06
			var tall := 0.22 + float(stage) * 0.1
			var top := Vector3(0.02, tall, tall * lean)
			var a := Vector3(-w, 0.0, 0.0)
			var b := Vector3(w * 0.8, 0.0, 0.02)
			var face := P.SPRUCE[1].lerp(P.SLATE[1], 0.4)
			k.made.tri(a, b, top + Vector3(w * 0.3, 0.0, 0.0), GroundColors.glint(face))
			k.made.tri(a, top + Vector3(w * 0.3, 0.0, 0.0), top + Vector3(-w * 0.4, -tall * 0.2, 0.0), face)
			k.made.tri(b, a, top + Vector3(w * 0.3, 0.0, 0.0), GroundColors.down(face, 0.2))
			k.made.tri(top + Vector3(w * 0.3, 0.0, 0.0), a, top + Vector3(-w * 0.4, -tall * 0.2, 0.0), GroundColors.down(face, 0.2))
			# The broken edge, pale where the glass is thin enough to see through.
			k.fleck(top + Vector3(-w * 0.4, -tall * 0.2, 0.0), top + Vector3(w * 0.3, 0.0, 0.0), top + Vector3(0.0, -tall * 0.12, 0.012), P.SLATE[4])
			# Its own socket: a chip of the sheet it came out of, lying flat.
			k.fleck(Vector3(0.08, 0.006, -0.1), Vector3(0.24, 0.006, -0.05), Vector3(0.16, 0.008, -0.18), face)
			k.still()
		FULGURITE:
			# A strike's track in the sand, fused into a crusted tube and dug half
			# out by the wind: a trunk out of the ground, leaning, forking twice,
			# pale sand-glass with a scorched collar where it goes in.
			var col := P.SAND[3].lerp(P.LINEN[3], 0.35)
			var dk := P.SAND[2].lerp(P.INK[3], 0.3)
			var yaw := float(stage) * 1.9
			var dirv := Vector3(cos(yaw) * 0.25, 1.0, sin(yaw) * 0.25).normalized()
			var p0 := Vector3.ZERO
			var p1 := dirv * (0.3 + float(stage) * 0.1)
			k.limb(p0 + Vector3(0, -0.02, 0), p1, 0.04, 0.026, 5, col, Vector3(0.04, 0.0, -0.02))
			for bi in 2 + stage % 2:
				var ba := yaw + 1.3 + float(bi) * 2.2
				var from := p0.lerp(p1, 0.45 + float(bi) * 0.2)
				var to := from + Vector3(cos(ba) * 0.15, 0.1 + float(bi) * 0.04, sin(ba) * 0.15)
				k.limb(from, to, 0.02, 0.009, 4, col if bi % 2 == 0 else dk)
			k.limb(p1, p1 + Vector3(cos(yaw + 0.6) * 0.07, 0.09, sin(yaw + 0.6) * 0.07), 0.02, 0.008, 4, dk)
			# The scorch it stands in.
			k.fleck(Vector3(-0.13, 0.005, -0.05), Vector3(0.11, 0.005, -0.1), Vector3(0.03, 0.006, 0.14), P.INK[3])
			k.still()
		DROWNED_LITTER:
			# Not litter the machines shed: what PEOPLE lost when the water came in,
			# three things a flood leaves on a floor, faded to the silt's colours.
			var weed := P.SPRUCE[1].lerp(P.MOSS[2], 0.35)
			if stage == 0:
				# A shoe on its side: sole, upper, the open heel, weed in the lace.
				var sole := P.INK[3].lerp(P.EARTH[1], 0.4)
				var upper := P.EARTH[2].lerp(P.ASH[2], 0.35)
				k.made.push(Transform3D(Basis(Vector3.BACK, 1.35), Vector3(0.0, 0.035, 0.0)))
				k.made.prism(0, -0.11, 0, 0.035, 0.22, 0.012, 6, sole)
				k.made.prism(0, -0.08, 0.03, 0.03, 0.15, 0.045, 6, upper)
				k.made.pop()
				k.limb(Vector3(-0.05, 0.05, 0.02), Vector3(0.06, 0.012, 0.09), 0.006, 0.004, 3, weed)
			elif stage == 1:
				# A child's toy boat, keel up, its red faded almost to the floor's.
				var hull := P.RUST[3].lerp(P.ASH[3], 0.45)
				k.made.prism(0, 0.0, 0, 0.1, 0.035, 0.04, 5, hull, P.RUST[2].lerp(P.ASH[2], 0.4))
				k.made.prism(0.02, 0.035, 0, 0.012, 0.07, 0.012, 4, P.LINEN[3])
				k.fleck(Vector3(-0.1, 0.004, -0.05), Vector3(0.12, 0.004, -0.07), Vector3(0.0, 0.005, 0.1), P.EARTH[2].lerp(P.SPRUCE[2], 0.4))
			else:
				# A bottle lying where it rolled, silt banked on its downhill side.
				k.made.push(Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.UP, 0.7), Vector3(0.0, 0.03, 0.0)))
				k.made.prism(0, -0.09, 0, 0.028, 0.14, 0.028, 6, GroundColors.glint(P.SPRUCE[2].lerp(P.SLATE[3], 0.3)))
				k.made.prism(0, 0.05, 0, 0.012, 0.05, 0.012, 5, P.SPRUCE[2])
				k.made.pop()
				k.clump(0.03, -0.02, 0.05, 0.07, 0.03, s, P.EARTH[2].lerp(P.SPRUCE[2], 0.45), 5)
				k.limb(Vector3(0.1, 0.01, -0.02), Vector3(-0.02, 0.015, -0.06), 0.006, 0.003, 3, weed)
			k.still()
		CUP_RING:
			# A low slab, and on its top the carving: a cup in the middle and two
			# or three rings round it, pecked, with a channel running out through
			# them. Flat to the sky, so it reads from above and at a low sun.
			var slab := P.SLATE[3].lerp(P.STONE[3], 0.35)
			var cut := GroundColors.down(slab, 0.35)
			k.stone(0, -0.05, 0, 0.26, 0.09, s, slab, 7, 0.0, GroundColors.up(slab, 0.08))
			var top := 0.042
			var rings := 2 + stage % 2
			for ri in rings:
				var r := 0.05 + float(ri) * 0.05
				var segs := 14
				for si in segs:
					if ri == rings - 1 and si == 3:
						continue
					var a0 := float(si) / segs * TAU
					var a1 := float(si + 1) / segs * TAU
					var p0 := Vector3(cos(a0) * r, top, sin(a0) * r)
					var p1 := Vector3(cos(a1) * r, top, sin(a1) * r)
					var o := Vector3(cos(a0), 0, sin(a0)) * 0.01
					k.made.quad(p0 - o, p1 - o * 0.9, p1 + o * 0.9, p0 + o, cut)
			k.fleck(Vector3(-0.02, top + 0.001, -0.02), Vector3(0.02, top + 0.001, -0.02), Vector3(0.0, top + 0.001, 0.025), cut)
			k.made.quad(Vector3(0.0, top, -0.006), Vector3(0.0, top, 0.006), Vector3(0.22, top - 0.01, 0.01), Vector3(0.22, top - 0.01, -0.01), cut)
			k.fleck(Vector3(-0.15, top, 0.08), Vector3(-0.08, top, 0.16), Vector3(-0.18, top - 0.005, 0.15), P.LINEN[3].lerp(P.MOSS[3], 0.35))
			k.still()
		CROTTLE:
			k.stone(0, -0.02, 0, 0.1, 0.09, s, P.SLATE[2], 5)
			k.fleck(Vector3(-0.04, 0.075, -0.03), Vector3(-0.03, 0.08, 0.04), Vector3(0.04, 0.075, 0.03), P.LINEN[3])
		SALT_PLATE:
			# A shard of crust that dried, curled and tipped on its edge, with
			# the stained pan showing where it came away. Its face is the salt
			# flats' ceiling, never the page: at LINEN[5] the shards lit a
			# coast-salt border as flat white speckle (art review 1, and see
			# SALT_TOP in world.gdshader).
			var tilt := 0.5 + stage * 0.25
			var a := Vector3(-0.07, 0.0, -0.05)
			var b := Vector3(0.07, 0.0, -0.04)
			var lift := Vector3(0.01, 0.055 * tilt, 0.08)
			k.made.quad(a, b, b + lift, a + lift, P.LINEN[2].lerp(P.LINEN[3], 0.6))
			k.made.quad(a + lift, b + lift, b + lift + Vector3(0, -0.012, 0.02), a + lift + Vector3(0, -0.012, 0.02), P.LINEN[3])
			k.made.quad(a, a + lift, a + lift + Vector3(-0.02, -0.01, 0.0), a + Vector3(-0.02, 0, 0), P.LINEN[2])
			if stage == 2:
				k.fleck(Vector3(0.06, 0.005, 0.03), Vector3(0.1, 0.02, 0.05), Vector3(0.08, 0.025, 0.01), P.RUST[2])
		FILINGS:
			# A comb of filings standing on edge along a field line: never
			# scattered, and never a smudge in the dirt either. They are as tall
			# as grass and half of them are bright, because the whole point of
			# this wood is that the ground is being held up by something.
			var n := 9 + stage * 2
			for i in n:
				var t := (float(i) / n - 0.5) * 0.44
				var bend := t * t * 2.2
				var base := Vector3(t, 0.0, bend)
				var up := 0.11 + Rng.hash01(s, i) * 0.09
				k.blade(base, base + Vector3(0.012, up, 0.02), 0.02, 1.2,
					P.STONE[3] if i % 3 else P.RUST[2])
			# One shard on end, taller than the comb, so the arc has a stop.
			k.blade(Vector3(0.16, 0.0, 0.07), Vector3(0.175, 0.26 + Rng.hash01(s, 91) * 0.08, 0.09), 0.026, 1.2, P.PLATE[3])
			k.still()
	return k
