extends TestCase
## A FOUND part of a prop that the play camera never draws is a part nobody
## has seen, and nothing about that raises an error.
##
## The scrap tree's plate proved it. The one thing meant to say "this tree grew
## through a machine" was built facing DOWN, so found.gdshader's back-face cull
## threw it away from every bearing the camera can take, for the whole life of
## the model -- through a playtest that asked for it to be made bigger, a review
## that asked again, and a rewrite of its comment explaining how bright it was.
## A missing thing is invisible to a green gate and to a person looking at the
## frame, because there is nothing in the frame to look at.
##
## So every model is rasterised here the way the play camera sees it: the
## CameraRig's pitch, orthographic, at eight bearings (a prop is turned any way
## the world deals it), with a depth buffer. MADE and FOUND faces are culled as
## their shaders cull them; leaf cards draw on both sides and are cut, so they
## hide what is behind them only in part (LEAF_COVER). Each FOUND piece -- a run
## of triangles joined at their corners: a rod, a panel's face, a housing -- that
## is big enough to be seen at play has to show at least VISIBLE_SHARE of itself
## from the bearing that shows it best.

## The play camera (src/render/camera_rig.gd): its pitch, and one pixel of the
## frame at its view height. Asked of the rig and the base rather than written
## out: this file had the right numbers, but written down they are a copy, and a
## copy is what let four other tests go on measuring a 360-row frame for two
## waves after LANTERN's floor moved (docs/LOOK.md).
const PITCH_DEG := CameraRig.PITCH_DEG
static var SCREEN_PX := CameraRig.VIEW_HEIGHT / float(UiBase.SIZE.y)
## A cell of the raster, in screen pixels. Four is enough to see a rod and cheap
## enough to run over every model in the game.
const CELL := 4.0
const BEARINGS := 8
## A piece is "meant to be seen" when it covers at least this many cells from
## its best bearing (a patch about 11 x 11 screen pixels): a rivet or a bolt head
## is not held to it, a panel or a rib is. It fails when it shows NOTHING from
## any bearing -- not when it shows little, which is a judgement (a part sunk in
## its own housing on purpose shows a sliver of rim and is right to).
const MIN_CELLS := 8
## How much of the view a leaf card takes where it lies: a sprig is cut out of
## its square by leaf.gdshader and about half the square is sprig.
const LEAF_COVER := 0.5

## NOTHING is hidden now, and nothing new may be. This list held 87 pieces
## across 26 models when the test was written and it is empty. Each row was a
## real fault and six of the eight causes were a WINDING, none of which raised
## an error:
##
##   - `works.gd run`, `rocks.gd _run` and `remains.gd streak` took their corners
##     in an order whose front came out at -`out`, so not one rust run in the
##     game had ever been drawn: on the stack, the archive, a standing stone, the
##     intake, the checkpoint, the pump house, the hull, the fire tower.
##   - the intake's louvres were flat quads wound INTO the housing. They are
##     blades that slope down and out now, which is the only way a thing on a
##     wall stays visible to a camera that is always above it.
##   - the wreck's visor slit, and the plate hanging over its torn end, faced
##     backwards; the dugout drew both faces of a roof nobody can get under;
##     the conveyor's rollers lay under a belt wider than they were long.
##   - the tip's scrap sat on an imagined cone well inside its own heaps, and the
##     stilt hut's roping cables ran through the middle of its thatch.
##   - `houses.gd on_wall` placed things on the BILINEAR surface between four
##     corners that never lie in a plane, so the enamel plate the machinery
##     counts a house by sat behind the triangles the wall is drawn from -- and
##     its own strike and tallies covered every pixel of what was left.
##   - every plate patch on a snowed roof was under the snow sheet.
##
## A model in this list may not hide more than its row; hiding fewer is a fix
## and passes, with a line asking for the row to come down, because a test that
## fails when somebody mends something teaches people to delete it.
const HIDDEN_ALREADY := {}


func test_the_raster_culls_as_the_shaders_do() -> void:
	# Its own proof first, or a pass below means nothing: a panel built facing up
	# is drawn from above, the same panel wound the other way is not, and a rod
	# is drawn from every bearing.
	var k := Kit.new()
	k.plate(Vector3(-0.3, 0.5, -0.3), Vector3(-0.3, 0.5, 0.3), Vector3(0.3, 0.5, 0.3), Vector3(0.3, 0.5, -0.3), Palette.PLATE[3], Palette.PLATE[2], Palette.PLATE[4])
	var up := _best(_measure(k.made.verts, k.found.verts, k.leaf.verts))
	gt(up.size, MIN_CELLS, "a panel is big enough to be held to it")
	gt(up.shown, up.size * 0.9, "a panel facing the sky is drawn from above")
	var down := Kit.new()
	down.plate(Vector3(0.3, 0.5, -0.3), Vector3(0.3, 0.5, 0.3), Vector3(-0.3, 0.5, 0.3), Vector3(-0.3, 0.5, -0.3), Palette.PLATE[3], Palette.PLATE[2], Palette.PLATE[4])
	eq(_best(_measure(down.made.verts, down.found.verts, down.leaf.verts)).shown, 0, "the same panel facing the ground is never drawn")
	var rod := Kit.new()
	rod.rod(Vector3(0, 0, 0), Vector3(0, 1.2, 0), 0.04, 5, Palette.PLATE[3])
	for b in BEARINGS:
		var one := _measure(rod.made.verts, rod.found.verts, rod.leaf.verts, [b])
		gt(float(one[0].shown), one[0].size * 0.5, "a rod is drawn at bearing %d" % b)
	# ...and a panel inside a solid is hidden by it.
	var boxed := Kit.new()
	boxed.plate(Vector3(-0.2, 0.3, -0.2), Vector3(-0.2, 0.3, 0.2), Vector3(0.2, 0.3, 0.2), Vector3(0.2, 0.3, -0.2), Palette.PLATE[3], Palette.PLATE[2], Palette.PLATE[4])
	boxed.made.box(Vector3(-0.5, 0.0, -0.5), Vector3(0.5, 0.8, 0.5), Palette.EARTH[2])
	eq(_best(_measure(boxed.made.verts, boxed.found.verts, boxed.leaf.verts)).shown, 0, "a panel shut in a box is not drawn")


func test_every_found_part_of_every_prop_is_drawn_from_the_play_camera() -> void:
	var seen := {}
	var hidden := {}
	var where := {}
	for kind in PropKind.COUNT:
		for v in PropModels.variants(kind):
			for c: int in BiomeRegistry.land_indices():
				var t := PropModels.template(kind, v, c)
				if t.found_v.is_empty():
					continue
				# A kind most landscapes dress alike is measured once.
				var key := [t.found_v, t.made_v.size(), t.leaf_v.size()].hash()
				if seen.has(key):
					continue
				seen[key] = true
				var who := "%s %d in %s" % [PropKind.NAMES[kind], v, BiomeRegistry.name_of(c)]
				for piece: Dictionary in _pieces_hidden(t.made_v, t.found_v, t.leaf_v):
					hidden[who] = int(hidden.get(who, 0)) + 1
					where[who] = "a piece of %d cells around %s" % [piece.size, piece.at]
	for who: String in hidden:
		var known := int(HIDDEN_ALREADY.get(who, 0))
		if hidden[who] > known:
			fail(("%s draws %d FOUND pieces from no bearing the play camera can take (%s). "
				+ "Turn it to face out, move it clear of what covers it, or take it out: it is triangles nobody "
				+ "has ever seen. Known already: %d.") % [who, hidden[who], where[who], known])
	for who: String in HIDDEN_ALREADY:
		if int(hidden.get(who, 0)) < int(HIDDEN_ALREADY[who]):
			print("found parts: %s now hides %d, not %d -- take its row in HIDDEN_ALREADY down." % [who, int(hidden.get(who, 0)), HIDDEN_ALREADY[who]])
	check(seen.size() > 40, "measured %d distinct models" % seen.size())


## MADE IS WHERE THE BUG KEPT COMING BACK, and this file could not see it.
##
## The winding trap has been fallen into four times by four builders chasing four
## unrelated tasks, and only the first was FOUND: the scrap tree's plate. After
## it came `works.gd run`, `rocks.gd _run` and `remains.gd streak` — not one rust
## run in the game had ever been drawn — and then the bunk and the solar array,
## both of which first drew with no faces at all and cost three renders to
## diagnose. `MeshKit.tri` takes its normal from `(c - b).cross(a - b)`, so a face
## meant to be seen from above runs round the OPPOSITE way to the one that reads
## naturally when you write it out. That is not a mistake somebody makes once; it
## is a trap in the API, and vigilance has now failed four times.
##
## The tell, from the builder who burned two renders on it: the geometry is
## ABSENT, not dark, so it looks exactly like something in front hiding it.
## Anyone reshaping the occluder first is chasing the wrong thing.
##
## IT ASKS A DIFFERENT QUESTION OF MADE THAN OF FOUND, on purpose. FOUND is
## machine parts — a rod, a panel, a housing, each put there to be seen — so
## "nothing of it reaches the screen" is a fault however it came about, and the
## test above raster's it against everything in front of it.
##
## MADE is trunks, thatch, mud and stone, and being inside something else is
## ORDINARY there: a ring of pine trunk under its own crown is hidden and is
## perfectly correct. Measured, the occlusion question asked of MADE reports
## dozens of those and would have to be silenced with a list of dozens of rows,
## which teaches the reader to ignore it.
##
## So MADE is asked the question the four bugs actually failed: is this surface
## TURNED AWAY from every bearing the camera can take — not "is it covered", but
## "does it face outward at all". A trunk swallowed by a canopy passes, because
## it faces out and something is in front of it. A panel wound the wrong way
## fails from every bearing at once, because there is no bearing it faces. That
## is the trap exactly, with no judgement in it and nothing to baseline.
##
## THE FIRST RUN FOUND THE FIFTH INSTANCE OF THE TRAP and it is fixed: the ochre
## stain fanned on the ground under the IRON ORE, two triangles, both wound to
## face the ground, never drawn once in the model's life (`rocks.gd iron_ore`).
## It also found both of the houses' eave planes — the hipped roof's and the flat
## one's — each written as "the dark overhang under the eaves" and each culled
## from every bearing, so the overhang was absent rather than dark and a sagging
## ridge left a hole through the house to the ground (`houses.gd`).
##
## These are what is left, and they are a DEBT rather than a decision. Each wants
## a look at a frame before it is turned, because turning a surface that is meant
## to be an underside puts a dark plane where nothing was:
##
##   - house 7 is the tower form; the two planes are up under its top storey.
##   - the two vehicles fail in the BURNING alone, which is the tell that it is
##     the landscape's dressing and not the model: elsewhere something lies over
##     the chassis and the question never arises.
##   - wreckage 2 is five or six faces in every landscape, so it is one builder's
##     habit rather than a slip, and it should be read as a whole.
##
## Take a row DOWN when you mend one; the run says so. Do not add one to make
## this pass — the fifth instance was found in ninety seconds by a test nobody
## had written, and the sixth will be too.
const BACKWARDS_ALREADY := {
	"house 7 in coast": 1,
	"house 7 in snowfield": 2,
	"vehicle 0 in burning": 3,
	"vehicle 1 in burning": 3,
}


func test_no_made_surface_faces_away_from_every_bearing_at_once() -> void:
	var seen := {}
	var bad := {}
	var where := {}
	for kind in PropKind.COUNT:
		for v in PropModels.variants(kind):
			for c: int in BiomeRegistry.land_indices():
				var t := PropModels.template(kind, v, c)
				if t.made_v.is_empty():
					continue
				var key: int = [t.made_v].hash()
				if seen.has(key):
					continue
				seen[key] = true
				var who := "%s %d in %s" % [PropKind.NAMES[kind], v, BiomeRegistry.name_of(c)]
				for piece: Dictionary in _pieces_backwards(t.made_v, t.found_v, t.leaf_v):
					bad[who] = int(bad.get(who, 0)) + 1
					where[who] = "%d triangles around %s" % [piece.tris, piece.at]
	for who: String in bad:
		var known := int(BACKWARDS_ALREADY.get(who, 0))
		if bad[who] > known:
			fail(("%s has %d MADE surfaces facing away from every bearing the play camera can take (%s). "
				+ "That is the WINDING: MeshKit.tri takes its normal from (c - b) x (a - b), so a face meant to "
				+ "be seen from above is written the opposite way round to the one that reads naturally. It will "
				+ "be ABSENT rather than dark, which looks exactly like something in front of it — do not reshape "
				+ "the occluder. Known already: %d.") % [who, bad[who], where[who], known])
	for who: String in BACKWARDS_ALREADY:
		if int(bad.get(who, 0)) < int(BACKWARDS_ALREADY[who]):
			print("made parts: %s now turns %d away, not %d -- take its row in BACKWARDS_ALREADY down." % [who, int(bad.get(who, 0)), BACKWARDS_ALREADY[who]])
	check(seen.size() > 40, "measured %d distinct models" % seen.size())


## A piece big enough to be worth saying so about. Two triangles is one quad, and
## one quad is what the ochre stain under the iron ore was.
const BACKWARDS_TRIS := 2


## MADE pieces that are wound the wrong way: {tris, at}.
##
## FACING AWAY IS NOT ENOUGH ON ITS OWN, and measuring taught me so. Plenty of
## MADE geometry faces down because it SHOULD: a vehicle's belly, the ceiling
## under a house's roof. Asking only "does it face out" reported seventeen
## surfaces and most were undersides doing their job.
##
## So the question is the one that has an answer: **would it be seen if it were
## wound the other way round?** Flip the piece, put everything else in front of
## it, and raster. The ochre stain fanned on open ground beside the iron ore
## draws the moment it is flipped, because nothing is over it — it was meant to
## be seen and never was. A car's belly draws nothing either way, because the car
## is on top of it. That separates the bug from the honest underside with no
## judgement in it and nothing to baseline.
static func _pieces_backwards(made: PackedVector3Array, found: PackedVector3Array, leaf: PackedVector3Array) -> Array[Dictionary]:
	var piece_of := _join(made)
	var count := 0
	for pid in piece_of:
		count = maxi(count, pid + 1)
	var faces := PackedByteArray()
	faces.resize(count)
	var tris := PackedInt32Array()
	tris.resize(count)
	var centre := PackedVector3Array()
	centre.resize(count)
	var bz: Array[Vector3] = []
	for b in BEARINGS:
		bz.append(Basis.from_euler(Vector3(deg_to_rad(-PITCH_DEG), TAU * b / BEARINGS, 0.0)).z)
	for t in range(0, made.size() - 2, 3):
		var pid := piece_of[t / 3]
		tris[pid] += 1
		centre[pid] += made[t] + made[t + 1] + made[t + 2]
		if faces[pid] != 0:
			continue
		# The same test `_raster` culls by, so the two can never disagree.
		var n := (made[t + 2] - made[t]).cross(made[t + 1] - made[t])
		for z: Vector3 in bz:
			if n.dot(z) > 0.0:
				faces[pid] = 1
				break
	var out: Array[Dictionary] = []
	for pid in count:
		if faces[pid] != 0 or tris[pid] < BACKWARDS_TRIS:
			continue
		var flipped := PackedVector3Array()
		var rest := PackedVector3Array()
		for t in range(0, made.size() - 2, 3):
			if piece_of[t / 3] == pid:
				flipped.append_array([made[t], made[t + 2], made[t + 1]])
			else:
				rest.append_array([made[t], made[t + 1], made[t + 2]])
		if _would_show(flipped, rest, found, leaf) >= MIN_CELLS:
			out.append({"tris": tris[pid], "at": (centre[pid] / maxf(tris[pid] * 3, 1)).snappedf(0.01)})
	return out


## Cells `subject` shows from its best bearing with everything else in front of it.
static func _would_show(subject: PackedVector3Array, rest: PackedVector3Array,
		found: PackedVector3Array, leaf: PackedVector3Array) -> int:
	var reach := 0.0
	for set: PackedVector3Array in [subject, rest, found, leaf]:
		for p in set:
			reach = maxf(reach, p.length())
	var cell := SCREEN_PX * CELL
	var side := int(ceil(reach * 2.0 / cell)) + 4
	var ids := PackedInt32Array()
	ids.resize(subject.size() / 3)
	var best := 0
	for b in BEARINGS:
		var basis := Basis.from_euler(Vector3(deg_to_rad(-PITCH_DEG), TAU * b / BEARINGS, 0.0))
		var depth := PackedFloat32Array()
		depth.resize(side * side)
		depth.fill(-INF)
		var owner := PackedInt32Array()
		owner.resize(side * side)
		owner.fill(-1)
		var size := PackedInt32Array()
		size.resize(1)
		var stamp := PackedInt32Array()
		stamp.resize(side * side)
		stamp.fill(-1)
		_raster(rest, basis, cell, side, depth, owner, -1, PackedInt32Array(), false, 0.0, size, stamp)
		_raster(found, basis, cell, side, depth, owner, -1, PackedInt32Array(), false, 0.0, size, stamp)
		_raster(leaf, basis, cell, side, depth, owner, -1, PackedInt32Array(), true, LEAF_COVER, size, stamp)
		_raster(subject, basis, cell, side, depth, owner, 0, ids, false, 0.0, size, stamp)
		var shown := 0
		for o in owner:
			if o >= 0:
				shown += 1
		best = maxi(best, shown)
	return best


func test_a_scrap_tree_shows_its_salvage_through_its_crown() -> void:
	# The tree the rule was written for: every variant shows plate THROUGH its
	# leaves from above, and not only the ribs it has always shown.
	var land := BiomeRegistry.index_of(&"scrapwood")
	for v in PropModels.variants(PropKind.SCRAP_TREE):
		var t := PropModels.template(PropKind.SCRAP_TREE, v, land)
		var sheet := 0
		for p: Dictionary in _measure(t.made_v, t.found_v, t.leaf_v):
			# A sheet, not a rod: a piece whose cells are many for its length.
			if p.flat and p.shown > sheet:
				sheet = p.shown
		gt(sheet, MIN_CELLS, "scrap tree %d shows a sheet of plate from above (%d cells)" % [v, sheet])


# --- The raster ---------------------------------------------------------------

const Kit := preload("res://src/models/props/kit.gd")


static func _pieces_hidden(made: PackedVector3Array, found: PackedVector3Array, leaf: PackedVector3Array, want: int = FOUND) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in _measure(made, found, leaf, [], want):
		if p.size >= MIN_CELLS and p.shown == 0:
			out.append(p)
	return out


## The piece of a model that shows the most of itself.
static func _best(pieces: Array[Dictionary]) -> Dictionary:
	var best := {"size": 0, "shown": 0}
	for p in pieces:
		if p.shown > best.shown or (p.shown == best.shown and p.size > best.size):
			best = p
	return best


## Which of a model's three surfaces is being measured; the other two are
## rasterised as occluders, culled the way their own shaders cull them.
const FOUND := 0
const MADE := 1


## Every piece of one surface of a model, measured at `bearings`: {size, shown,
## at, flat}, each the piece's best bearing -- the one where the most of it is
## shown.
static func _measure(made: PackedVector3Array, found: PackedVector3Array, leaf: PackedVector3Array,
		bearings: Array = [], want: int = FOUND) -> Array[Dictionary]:
	var subject := made if want == MADE else found
	var piece_of := _join(subject)
	var count := 0
	for pid in piece_of:
		count = maxi(count, pid + 1)
	var best_size := PackedInt32Array()
	var best_shown := PackedInt32Array()
	best_size.resize(count)
	best_shown.resize(count)
	var reach := 0.0
	for p in made:
		reach = maxf(reach, p.length())
	for p in found:
		reach = maxf(reach, p.length())
	for p in leaf:
		reach = maxf(reach, p.length())
	var cell := SCREEN_PX * CELL
	var side := int(ceil(reach * 2.0 / cell)) + 4
	var turns := bearings.duplicate()
	if turns.is_empty():
		for b in BEARINGS:
			turns.append(b)
	for b: int in turns:
		var basis := Basis.from_euler(Vector3(deg_to_rad(-PITCH_DEG), TAU * b / BEARINGS, 0.0))
		var depth := PackedFloat32Array()
		depth.resize(side * side)
		depth.fill(-INF)
		var owner := PackedInt32Array()
		owner.resize(side * side)
		owner.fill(-1)
		# Each piece's own footprint whatever faces it, for its size.
		var size := PackedInt32Array()
		size.resize(count)
		var stamp := PackedInt32Array()
		stamp.resize(side * side)
		stamp.fill(-1)
		# The two that are not the subject go down first as plain occluders, then
		# the subject with its piece ids, so a pixel it wins is a pixel it shows.
		var other := found if want == MADE else made
		_raster(other, basis, cell, side, depth, owner, -1, PackedInt32Array(), false, 0.0, size, stamp)
		_raster(leaf, basis, cell, side, depth, owner, -1, PackedInt32Array(), true, LEAF_COVER, size, stamp)
		_raster(subject, basis, cell, side, depth, owner, 0, piece_of, false, 0.0, size, stamp)
		var shown := PackedInt32Array()
		shown.resize(count)
		for o in owner:
			if o >= 0:
				shown[o] += 1
		for pid in count:
			if shown[pid] > best_shown[pid] or (shown[pid] == best_shown[pid] and size[pid] > best_size[pid]):
				best_shown[pid] = shown[pid]
				best_size[pid] = size[pid]
	var out: Array[Dictionary] = []
	for pid in count:
		var centre := Vector3.ZERO
		var n := 0
		var lo := Vector3.INF
		var hi := -Vector3.INF
		for i in piece_of.size():
			if piece_of[i] == pid:
				for j in 3:
					centre += subject[i * 3 + j]
					lo = lo.min(subject[i * 3 + j])
					hi = hi.max(subject[i * 3 + j])
				n += 3
		var ext := hi - lo
		var dims := [ext.x, ext.y, ext.z]
		dims.sort()
		out.append({"size": best_size[pid], "shown": best_shown[pid], "at": (centre / maxf(n, 1)).snappedf(0.01),
			"flat": float(dims[1]) > 0.12 and float(dims[2]) > 0.12})
	return out


## Triangles joined at a shared corner are one piece. Per triangle, its piece id.
static func _join(verts: PackedVector3Array) -> PackedInt32Array:
	var tris := verts.size() / 3
	var parent := PackedInt32Array()
	parent.resize(tris)
	for i in tris:
		parent[i] = i
	var first := {}
	for i in tris:
		for j in 3:
			var q := verts[i * 3 + j].snappedf(0.0005)
			if first.has(q):
				_union(parent, i, first[q])
			else:
				first[q] = i
	var ids := {}
	var out := PackedInt32Array()
	out.resize(tris)
	for i in tris:
		var r := _root(parent, i)
		if not ids.has(r):
			ids[r] = ids.size()
		out[i] = ids[r]
	return out


static func _root(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _root(parent, a)
	var rb := _root(parent, b)
	if ra != rb:
		parent[maxi(ra, rb)] = mini(ra, rb)


## Rasterise one surface into the depth buffer. `pieces` non-empty marks a FOUND
## surface: its cells are owned by the piece, and its footprint is stamped into
## `size`. `both` draws back faces (a leaf); `cover` < 1 lets that share through.
static func _raster(verts: PackedVector3Array, basis: Basis, cell: float, side: int, depth: PackedFloat32Array,
		owner: PackedInt32Array, _unused: int, pieces: PackedInt32Array, both: bool, cover: float,
		size: PackedInt32Array, stamp: PackedInt32Array) -> void:
	var rx := basis.x
	var uy := basis.y
	var bz := basis.z
	var half := side * 0.5
	var found := not pieces.is_empty()
	for t in range(0, verts.size() - 2, 3):
		var p0 := verts[t]
		var p1 := verts[t + 1]
		var p2 := verts[t + 2]
		var ax := p0.dot(rx) / cell + half
		var ay := half - p0.dot(uy) / cell
		var bx := p1.dot(rx) / cell + half
		var by := half - p1.dot(uy) / cell
		var cx := p2.dot(rx) / cell + half
		var cy := half - p2.dot(uy) / cell
		# Front faces as MeshKit writes them (it emits a, c, b for an authored
		# a, b, c whose normal is (c - b) x (a - b)): turned to the camera.
		var facing := (p2 - p0).cross(p1 - p0).dot(bz)
		var front := facing > 0.0
		var area := (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
		if absf(area) < 1e-9:
			continue
		var pid := pieces[t / 3] if found else -1
		var x0 := maxi(0, floori(minf(ax, minf(bx, cx))))
		var x1 := mini(side - 1, ceili(maxf(ax, maxf(bx, cx))))
		var y0 := maxi(0, floori(minf(ay, minf(by, cy))))
		var y1 := mini(side - 1, ceili(maxf(ay, maxf(by, cy))))
		var az := p0.dot(bz)
		var bzz := p1.dot(bz)
		var cz := p2.dot(bz)
		for y in range(y0, y1 + 1):
			var py := y + 0.5
			for x in range(x0, x1 + 1):
				var px := x + 0.5
				var w0 := ((bx - px) * (cy - py) - (by - py) * (cx - px)) / area
				var w1 := ((cx - px) * (ay - py) - (cy - py) * (ax - px)) / area
				var w2 := 1.0 - w0 - w1
				if w0 < 0.0 or w1 < 0.0 or w2 < 0.0:
					continue
				var idx := y * side + x
				if found and stamp[idx] != pid:
					stamp[idx] = pid
					size[pid] += 1
				if not front and not both:
					continue
				if cover > 0.0 and Rng.hash01(t, idx, 0x1eaf) >= cover:
					continue
				var z := w0 * az + w1 * bzz + w2 * cz
				if z > depth[idx] + 0.002:
					depth[idx] = z
					owner[idx] = pid
