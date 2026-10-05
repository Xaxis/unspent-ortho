class_name PropWalls
extends RefCounted
## WHAT STOPS A BODY AT A WALLED PROP IS WHAT IT DRAWS (#75). For the kinds in
## KINDS, a prop's own circle (PropKind.SOLID, the row's `solid`) is worldgen's
## placement footprint and nothing else: what stops a body is the walls fitted
## to its model (tools/gd/prop_walls_bake.gd, baked into PropWallsTable), in the
## prop's own turn and scale, so a ruin's doorway and a fallen tower's length
## read as they are drawn. WorldQuery files these props by their walls' bounds
## and hands their circles out with the other blocks; it leaves them out of its
## solid rows.
##
## Contract:
##   KINDS                          the walled kinds
##   key(kind, variant, land) -> int
##   shape(kind, variant, land) -> PackedFloat32Array  (x, z, r) model space
##   reach(kind, variant, land) -> float  the farthest wall edge from the origin
##   kind_reach(kind) -> float   the farthest any model of the kind reaches, cast
##   of_row(world, row) -> Array[Vector3]  (x, y, r) tile space, [] if taken
##   ids_of(world) -> PackedInt32Array      every walled prop's id

## The kinds whose collision is their walls. A kind joins when one disc misses
## its drawing by more than the footprint test's TOL and it is not drawn as a
## disc by nature (tests/render/test_prop_footprint.gd says why for the rest).
const KINDS: Array[int] = [
	PropKind.RUIN, PropKind.DROWNED_SHELL, PropKind.DROWNED_ROOF,
	PropKind.FALLEN_TOWER, PropKind.DECK_SPAN, PropKind.CHECKPOINT,
	PropKind.DEMOLITION_GANTRY, PropKind.ARCH_RIB, PropKind.HOLLOW_WAY,
	PropKind.HULL, PropKind.LOCK_GATE, PropKind.MURAL, PropKind.DROWNED_TRAM,
]

## How far a prop's collision may miss its drawing, both ways, in tiles: the
## same tolerance the machines' bodies are held to (tests/models/test_hit_shapes).
const TOL := 0.2
## The waist of a walking body: drawn mass from here up must stand inside the
## collision (the footprint test's walk-through measure).
const WAIST := 0.5

static var _reach: Dictionary = {}
static var _kind_reach: Dictionary = {}
## The most a cast stretches a model (PropModels.cast, x and z).
const CAST_MOST := 1.11
static var _walled := PackedByteArray()
## The table's shapes as packed arrays, made on first use.
static var _shapes: Dictionary = {}


static func key(kind: int, variant: int, land: int) -> int:
	return (kind * 64 + variant) * 256 + land


static func shape(kind: int, variant: int, land: int) -> PackedFloat32Array:
	var i: int = PropWallsTable.OF.get(key(kind, variant, land), -1)
	if i < 0:
		i = PropWallsTable.OF.get(key(kind, variant, Country.COAST), -1)
	if i < 0:
		return PackedFloat32Array()
	if not _shapes.has(i):
		_shapes[i] = PackedFloat32Array(PropWallsTable.SHAPES[i])
	return _shapes[i]


static func reach(kind: int, variant: int, land: int) -> float:
	var k := key(kind, variant, land)
	if _reach.has(k):
		return _reach[k]
	var s := shape(kind, variant, land)
	var r := 0.0
	for i in range(0, s.size(), 3):
		r = maxf(r, Vector2(s[i], s[i + 1]).length() + s[i + 2])
	_reach[k] = r
	return r


## Whether `kind` is walled, a lookup a body's every step can afford.
static func walled(kind: int) -> bool:
	if _walled.is_empty():
		_walled.resize(PropKind.COUNT)
		for k in KINDS:
			_walled[k] = 1
	return _walled[kind] == 1


## The farthest any model of `kind` reaches from its origin at scale 1, cast at
## its widest: what a prop's walls can touch is filed by this.
static func kind_reach(kind: int) -> float:
	if _kind_reach.has(kind):
		return _kind_reach[kind]
	var most := 0.0
	for k: int in PropWallsTable.OF:
		if k / 256 / 64 == kind:
			var s: PackedFloat32Array = shape(kind, (k / 256) % 64, k % 256)
			for i in range(0, s.size(), 3):
				most = maxf(most, Vector2(s[i], s[i + 1]).length() + s[i + 2])
	_kind_reach[kind] = most * CAST_MOST
	return _kind_reach[kind]


## The walls of the prop at `row`, in tile space, as it is drawn there: its
## land's model, turned, scaled and cast (WorldView.prop_xform); none for a
## taken one.
static func of_row(w: WorldData, row: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var t := w.table
	var id := int(t.id[row])
	if w.depleted.has(id):
		return out
	var p := w.prop_at(row)
	var land := w.built_country(p)
	var v := PropModels.variant_of(p, w.seed_value, land)
	var s := shape(int(t.kind[row]), v, land)
	var pos: Vector2 = t.pos[row]
	var rot := float(t.rot[row])
	var sc := float(t.scale[row])
	var g := PropModels.cast(w.seed_value, id)
	var rs := minf(g.x, g.z) * sc
	for i in range(0, s.size(), 3):
		var at := pos + Vector2(s[i] * g.x, s[i + 1] * g.z).rotated(rot) * sc
		out.append(Vector3(at.x, at.y, s[i + 2] * rs))
	return out


static func ids_of(w: WorldData) -> PackedInt32Array:
	var out := PackedInt32Array()
	w.sync_table()
	var t := w.table
	for row in t.size():
		if walled(int(t.kind[row])):
			out.append(t.id[row])
	return out
