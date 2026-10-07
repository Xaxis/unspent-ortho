extends RefCounted
## THE WALLS A PROP STOPS A BODY WITH, FITTED TO WHAT IT DRAWS (#75). One
## circle at a prop's middle (PropKind.SOLID) stood as an invisible wall round a
## mural's bare ends and let a body walk the length of a fallen tower. So each
## walled kind's model, in every land that lays it, is rasterised in the band a
## walking body meets and covered with circles that stay inside what is drawn
## (and at least RMIN across, so a plank still stops a body), until nothing drawn
## lies further than TOL from them (COVERS). The answer is baked into
## src/core/prop_walls_table.gd, so the headless sims and the played game read
## one table; tests/render/test_prop_footprint.gd fits again and fails when a
## model and the table disagree.
##
## Contract:
##   fit(kind, variant, land) -> PackedFloat32Array  (x, z, r) triples, model space
##   table_source() -> String  the generated table, every walled kind's every model
##   KINDS come from PropWalls.KINDS.
##
## Regenerate: tools/bake_walls.sh

const F := preload("res://tools/gd/footprint.gd")

## The band a walking body meets (as the footprint test measures it).
const LO := 0.12
const HI := 1.6
## The largest and the smallest circle a wall is fitted with, and how far past
## a circle's edge a drawn cell may lie and still count as covered: the widest
## first (fewest circles), narrower until the fit holds within TOL measured on
## the footprint's own raster.
const RMAX := 1.0
const RMIN := 0.12
const COVERS: Array[float] = [0.15, 0.1, 0.05, 0.0]


## The body-band polygons of one model.
static func drawn(kind: int, variant: int, land: int) -> Array:
	var t := PropModels.template(kind, variant, land)
	var out: Array = []
	F.polys(t.made_v, Transform3D.IDENTITY, out, LO, HI)
	F.polys(t.found_v, Transform3D.IDENTITY, out, LO, HI)
	return out


static func fit(kind: int, variant: int, land: int) -> PackedFloat32Array:
	return fit_held(drawn(kind, variant, land), waist(kind, variant, land))


## The fewest circles that hold `polys` (and its waist `mid`) within TOL.
static func fit_held(polys: Array, mid: Array) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	for cover in COVERS:
		s = fit_drawn(polys, cover)
		if holds(polys, mid, s):
			return s
	return s


static func fit_drawn(polys: Array, cover_by: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: PackedVector2Array in polys:
		for v in p:
			lo = lo.min(v)
			hi = hi.max(v)
	if not lo.is_finite():
		return out
	lo -= Vector2(0.5, 0.5)
	hi += Vector2(0.5, 0.5)
	var c := F.CELL
	var nx := ceili((hi.x - lo.x) / c)
	var nz := ceili((hi.y - lo.y) / c)
	var n := nx * nz
	var mask := PackedByteArray()
	mask.resize(n)
	for p: PackedVector2Array in polys:
		F._mark(p, mask, lo, nx, nz)
	# How far inside the drawing each drawn cell lies: the radius a circle
	# centred there can take without standing past it.
	var empty := PackedByteArray()
	empty.resize(n)
	for i in n:
		empty[i] = 1 - mask[i]
	var inside := F.dt(empty, nx, nz)
	var covered := PackedByteArray()
	covered.resize(n)
	var reach := ceili((RMAX + cover_by) / c)
	for i in n:
		if mask[i] == 0 or covered[i] == 1:
			continue
		var ux := i % nx
		var uz := i / nx
		# The widest circle that still reaches this cell, nearest first on a tie.
		var best := i
		var best_r := -1.0
		var best_d := INF
		for z in range(maxi(0, uz - reach), mini(nz - 1, uz + reach) + 1):
			for x in range(maxi(0, ux - reach), mini(nx - 1, ux + reach) + 1):
				var j := z * nx + x
				if mask[j] == 0:
					continue
				var r := minf((inside[j] - 0.5) * c, RMAX)
				var d := Vector2(x - ux, z - uz).length() * c
				if d > maxf(r, RMIN) + cover_by:
					continue
				if r > best_r + 1e-6 or (absf(r - best_r) <= 1e-6 and d < best_d):
					best = j
					best_r = r
					best_d = d
		var rad := maxf(best_r, RMIN)
		var bx := best % nx
		var bz := best / nx
		var cover := ceili((rad + cover_by) / c)
		for z in range(maxi(0, bz - cover), mini(nz - 1, bz + cover) + 1):
			for x in range(maxi(0, bx - cover), mini(nx - 1, bx + cover) + 1):
				if Vector2(x - bx, z - bz).length() * c <= rad + cover_by:
					covered[z * nx + x] = 1
		var at := lo + Vector2((bx + 0.5) * c, (bz + 0.5) * c)
		out.append_array([snappedf(at.x, 0.01), snappedf(at.y, 0.01), snappedf(rad, 0.01)])
	return out


## Every land a walled kind can be drawn in, and its variants there.
static func cases() -> Array:
	var out: Array = []
	var lands := PackedInt32Array()
	for d: BiomeDef in BiomeRegistry.land():
		lands.append(d.index)
	if not lands.has(Country.COAST):
		lands.append(Country.COAST)
	lands.sort()
	for kind: int in PropWalls.KINDS:
		for land in lands:
			for v in PropModels.variants(kind, land):
				out.append([kind, v, land])
	return out


## The walls of a case as circles the footprint measure reads.
static func circles(s: PackedFloat32Array) -> Array:
	var out: Array = []
	for i in range(0, s.size(), 3):
		out.append(Vector3(s[i], s[i + 1], s[i + 2]))
	return out


## Whether `s` stops a body where `polys` is drawn, within PropWalls.TOL both
## ways: no wall edge further than that from anything drawn, nothing drawn at
## the waist further than that from a wall.
static func holds(polys: Array, waist: Array, s: PackedFloat32Array) -> bool:
	var c := circles(s)
	var b := F.measure(polys, c)
	var w := F.measure(waist, c)
	return float(b.get("gap", 0.0)) <= PropWalls.TOL and float(w.get("walk", 0.0)) <= PropWalls.TOL


static func waist(kind: int, variant: int, land: int) -> Array:
	var t := PropModels.template(kind, variant, land)
	var out: Array = []
	F.polys(t.made_v, Transform3D.IDENTITY, out, PropWalls.WAIST, HI)
	F.polys(t.found_v, Transform3D.IDENTITY, out, PropWalls.WAIST, HI)
	return out


static func table_source() -> String:
	var shapes: Array[PackedFloat32Array] = []
	var of: Array = []
	# One shape serves every land whose drawing it holds within TOL: the lands
	# dress a model differently in its details, not in where its walls stand.
	var tried: Dictionary = {}  # kind * 64 + variant -> shape indices
	var same: Dictionary = {}  # a drawing's own hash -> shape index
	for c: Array in cases():
		var polys := drawn(c[0], c[1], c[2])
		var sig := str(polys).hash()
		if same.has(sig):
			of.append([PropWalls.key(c[0], c[1], c[2]), same[sig]])
			continue
		var mid := waist(c[0], c[1], c[2])
		var kv: int = c[0] * 64 + c[1]
		var found := -1
		for i: int in tried.get(kv, []):
			if holds(polys, mid, shapes[i]):
				found = i
				break
		if found < 0:
			found = shapes.size()
			shapes.append(fit_held(polys, mid))
			tried[kv] = (tried.get(kv, []) as Array) + [found]
		same[sig] = found
		of.append([PropWalls.key(c[0], c[1], c[2]), found])
	var lines := PackedStringArray()
	lines.append("class_name PropWallsTable")
	lines.append("extends RefCounted")
	lines.append("## GENERATED by tools/bake_walls.sh (tools/gd/prop_walls_bake.gd) from the")
	lines.append("## models: every walled kind's walls, fitted to what it draws. Do not edit;")
	lines.append("## tests/render/test_prop_footprint.gd fails when a model and this disagree.")
	lines.append("")
	lines.append("## (x, z, r) triples in model space, one entry per distinct shape.")
	lines.append("const SHAPES := [")
	for s in shapes:
		var nums := PackedStringArray()
		for f in s:
			nums.append(String.num(f, 2))
		lines.append("\t[%s]," % ", ".join(nums))
	lines.append("]")
	lines.append("## PropWalls.key(kind, variant, land) -> index into SHAPES.")
	lines.append("const OF := {")
	for row: Array in of:
		lines.append("\t%d: %d," % [row[0], row[1]])
	lines.append("}")
	return "\n".join(lines) + "\n"
