extends RefCounted
## A model as it is seen from far off: the SAME model, with what is smaller than a
## couple of pixels at that range left out.
##
## The far world used to stand one plain solid in for anything tall (a tapered
## block, a double cone), and from eye level that is exactly what it looked like:
## a city of grey prisms, a pylon as a thin solid post. What makes a tower read as
## a tower at 150 tiles is its setbacks, its balconies, the clutter on its roof and
## its lit windows, and what makes a pylon read as a pylon is the lattice. Every one
## of those is already in the near model. So a far model is the near template with
## its small faces dropped -- nothing is moved, re-coloured or re-lit, which means
## it cannot disagree with the near drawing about anything but what is too small to
## see, and a window keeps the mark that lights it at night.
##
## WHAT IS "TOO SMALL" IS A TRIANGLE'S LONGEST EDGE, NOT ITS AREA. A strut of a
## lattice mast is a long thin tube, all of its faces tiny in area, and ranking by
## area dropped the whole lattice and kept the insulators floating in the air. A
## long edge is what still draws a line at range, so a face is kept while its
## longest edge is at least `tol` of a level; a rivet, a bolt head and the far end
## of a chamfer strip go, a strut and a wall stay.
##
## Leaf cards are thinned instead, because every card in a crown is the same size:
## a share of them is kept, dealt by position so the crown thins evenly, and each
## kept card grows to cover what its dropped neighbours did, so the crown keeps its
## mass and its dapple and does not turn to lace with distance.
##
## By PATH, never a class_name: see world_far.gd's header.

## The far levels, by the distance each is drawn at (tiles, from eye level at the
## play fov): a MID chunk (world_view, 56-110), a far block close in (world_far,
## to ~260) and the far blocks past that. `tol` is about two pixels at the nearest
## distance each is drawn at: 2 px x distance x 2 tan(fov/2) / 1080.
##
## SHADE is not drawn at all: it is what a near chunk past thirty tiles CASTS its
## shadow with (world_view `_lod_apply`), measured by the sun's shadow texel there
## rather than by a screen pixel. The mid models were ten times its cost in the
## shadow passes for a difference those passes cannot resolve.
const MID := 0
const NEAR_FAR := 1
const FAR := 2
const SHADE := 3
const LEVELS := 4
const TOL: Array[float] = [0.08, 0.2, 0.45, 0.14]
## A lit face (a window, a lamp, stolen neon: GroundColors 17..34) is kept down to
## this share of the level's tolerance, because a city at night is the lights.
const LIT_KEEP := 0.45
## The share of leaf cards each level keeps.
const LEAF_KEEP: Array[float] = [0.5, 0.2, 0.1, 0.4]
## The most faces a level keeps of one model, longest first, so one ornate model
## cannot spend a block's whole budget; and under that, a far level spends in
## proportion to the model's own height SQUARED (`PER_AREA`), because that is how
## much of the screen it covers. A forest block holds fourteen hundred trees and a
## city block forty towers: a tree 150 tiles off is twenty pixels tall and gets a
## tree's share, a tower gets a tower's.
const MOST: Array[int] = [4000, 420, 160, 700]
const PER_AREA: Array[float] = [0.0, 4.0, 1.0, 30.0]
const LEAST := 8
const LEAF_SPEND := 0.7

static var _cache: Dictionary = {}
static var _lock := Mutex.new()


static func template(kind: int, variant: int, country: int, level: int) -> PropModels.Template:
	var key := ((kind * PropModels.MAX_VARIANTS + variant) * BiomeRegistry.SLOTS + country) * LEVELS + level
	_lock.lock()
	var got: PropModels.Template = _cache.get(key)
	_lock.unlock()
	if got != null:
		return got
	var out := reduce(PropModels.template(kind, variant, country), level)
	_lock.lock()
	_cache[key] = out
	_lock.unlock()
	return out


## Pure: `t` seen at `level`.
static func reduce(t: PropModels.Template, level: int) -> PropModels.Template:
	var tol: float = TOL[level]
	var most: int = MOST[level]
	if PER_AREA[level] > 0.0:
		var top := _top(t)
		most = clampi(roundi(top * top * PER_AREA[level]), LEAST, most)
	var out := PropModels.Template.new()
	# A crown is most of what a tree IS at range, so its cards may take up to
	# `LEAF_SPEND` of the model's budget; the trunk and boughs have the rest.
	_thin_leaves(t, out, LEAF_KEEP[level], roundi(most * LEAF_SPEND) / 2)
	most = maxi(most - out.leaf_v.size() / 3, most / 3)
	var crown := _top(t) * (1.0 - CROWN)
	var made := _keep(t.made_v, t.made_c, tol, most, true, crown)
	out.made_v = _pick3(t.made_v, made)
	out.made_n = _pick3(t.made_n, made)
	out.made_c = _pickc(t.made_c, made)
	out.made_uv = _pick2(t.made_uv, made)
	out.made_uv2 = _pick2(t.made_uv2, made)
	var found := _keep(t.found_v, t.found_c, tol, maxi(most / 4, most - made.size()), false, crown)
	out.found_v = _pick3(t.found_v, found)
	out.found_n = _pick3(t.found_n, found)
	out.found_c = _pickc(t.found_c, found)
	return out


static func _top(t: PropModels.Template) -> float:
	var top := 0.0
	for arr: PackedVector3Array in [t.made_v, t.found_v, t.leaf_v]:
		for v in arr:
			top = maxf(top, v.y)
	return top


## WHAT STANDS ON THE SKYLINE OUTRANKS WHAT IS ON THE WALL. When a model is over
## its budget the longest faces are kept, and a wall's trim band is longer than a
## water tank or a mast -- so the first cut of a tower kept every stripe down its
## face and took the clutter off its roof, which is most of what says "tower" from
## a street away. A face in the top `CROWN` of the model's height counts
## `CROWN_WEIGHT` times its length, both against the level's tolerance and
## against the budget, because against the sky a thing a third of a pixel's
## worth of tolerance still draws a line.
const CROWN := 0.15
const CROWN_WEIGHT := 3.0


## The triangles of a soup worth keeping at `tol`, as their first vertex index,
## in the order they were built (so a model's own draw order, and with it any
## coplanar decal laid after its wall, is kept). `crown` is the height above
## which a face is on the skyline.
static func _keep(v: PackedVector3Array, c: PackedColorArray, tol: float, most: int, marks: bool, crown: float) -> PackedInt32Array:
	var n := v.size() / 3
	var keep := PackedInt32Array()
	var edge := PackedFloat32Array()
	var tol2 := tol * tol
	var lit2 := tol2 * LIT_KEEP * LIT_KEEP
	for i in n:
		var a := v[i * 3]
		var b := v[i * 3 + 1]
		var d := v[i * 3 + 2]
		var e := maxf(a.distance_squared_to(b), maxf(b.distance_squared_to(d), d.distance_squared_to(a)))
		var bar := tol2
		if marks:
			var m := int(c[i * 3].a * 255.0 + 0.5)
			if m >= 17 and m <= 34:
				bar = lit2
		var sky := CROWN_WEIGHT * CROWN_WEIGHT if maxf(a.y, maxf(b.y, d.y)) > crown else 1.0
		if e * sky >= bar:
			keep.append(i * 3)
			edge.append(e * sky)
	if keep.size() <= most:
		return keep
	# Over budget: the longest faces win, then back into build order.
	var order: Array = range(keep.size())
	order.sort_custom(func(x: int, y: int) -> bool: return edge[x] > edge[y])
	var chosen: Array = order.slice(0, most)
	chosen.sort()
	var out := PackedInt32Array()
	out.resize(chosen.size())
	for j in chosen.size():
		out[j] = keep[chosen[j]]
	return out


static func _pick3(a: PackedVector3Array, at: PackedInt32Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	if a.is_empty():
		return out
	out.resize(at.size() * 3)
	for j in at.size():
		var i := at[j]
		out[j * 3] = a[i]
		out[j * 3 + 1] = a[i + 1]
		out[j * 3 + 2] = a[i + 2]
	return out


static func _pick2(a: PackedVector2Array, at: PackedInt32Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if a.is_empty():
		return out
	out.resize(at.size() * 3)
	for j in at.size():
		var i := at[j]
		out[j * 3] = a[i]
		out[j * 3 + 1] = a[i + 1]
		out[j * 3 + 2] = a[i + 2]
	return out


static func _pickc(a: PackedColorArray, at: PackedInt32Array) -> PackedColorArray:
	var out := PackedColorArray()
	if a.is_empty():
		return out
	out.resize(at.size() * 3)
	for j in at.size():
		var i := at[j]
		out[j * 3] = a[i]
		out[j * 3 + 1] = a[i + 1]
		out[j * 3 + 2] = a[i + 2]
	return out


## Keep `share` of the cards (six vertices each, Kit._card), and never more than
## `most`, grown about their own middles so the crown covers what it covered
## (by the square root of how many were dropped, capped at `GROW_MOST` so a card
## never becomes a sheet). The cards kept are the ones whose POSITION hashes
## lowest, not every n-th, so which go does not follow the order the boughs were
## built in and a crown thins evenly all over.
const GROW_MOST := 3.4


static func _thin_leaves(t: PropModels.Template, out: PropModels.Template, share: float, most: int) -> void:
	var cards := t.leaf_v.size() / 6
	if cards == 0:
		return
	# Never so few that growing them by GROW_MOST cannot cover the crown: a far
	# tree that lost its mass reads as a bare trunk with a leaf on it, and a
	# forest of them as a clearing.
	var least := ceili(cards / (GROW_MOST * GROW_MOST))
	var kept := clampi(roundi(cards * share), least, maxi(least, most))
	var rank: Array = []
	for i in cards:
		var o := i * 6
		var mid := (t.leaf_v[o] + t.leaf_v[o + 2]) * 0.5
		rank.append([Rng.hash01(floori(mid.x * 97.0), floori(mid.y * 97.0), floori(mid.z * 97.0)), i])
	rank.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var take: Array = []
	for j in kept:
		take.append(rank[j][1])
	take.sort()
	var grow := minf(sqrt(float(cards) / kept), GROW_MOST)
	var lv := PackedVector3Array()
	var ln := PackedVector3Array()
	var lc := PackedColorArray()
	var luv := PackedVector2Array()
	var luv2 := PackedVector2Array()
	for i: int in take:
		var o := i * 6
		var mid := (t.leaf_v[o] + t.leaf_v[o + 2]) * 0.5
		for k in 6:
			lv.append(mid + (t.leaf_v[o + k] - mid) * grow)
			ln.append(t.leaf_n[o + k])
			lc.append(t.leaf_c[o + k])
			luv.append(t.leaf_uv[o + k])
			luv2.append(t.leaf_uv2[o + k])
	out.leaf_v = lv
	out.leaf_n = ln
	out.leaf_c = lc
	out.leaf_uv = luv
	out.leaf_uv2 = luv2
