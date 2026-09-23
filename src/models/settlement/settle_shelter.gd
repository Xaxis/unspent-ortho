extends RefCounted
## Somewhere to sleep and somewhere to keep things (docs/VISION.md, docs/LOOK.md
## §10). A first shelter is all MADE: driftwood, lashings, a skin of rag and
## thatch, hand-cut edges that do not meet. A hut is what the same people build
## once they have salvaged well: the same crooked frame with machine plate over
## the gaps, and both idioms in one silhouette.
##
## Every piece faces +X (the convention: a model faces +X at rotation.y = 0), so
## a lean-to opens toward the way it was set down and a hut's door is on that side.

const Parts := preload("res://src/models/settlement/settle_parts.gd")
const P := preload("res://src/render/palette.gd")


# --- lean-to ----------------------------------------------------------------

## Open to the front, low at the back, and the back is where the weather comes
## from: the one piece a player can put up on the first evening.
static func lean_to(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.hand(k)
	# Tall at the front and down to the ground at the back. Shallow and wide it
	# reads as a table at 640x360; the wedge has to be steep to be a shelter.
	var half := 0.44 + Parts.wob(v, 1) * 0.08
	var high := 1.28 + Parts.wob(v, 2) * 0.2
	var back := -0.72 - Parts.wob(v, 3) * 0.12
	var fallen := 0.0
	for side: int in [-1, 1]:
		var z := side * half
		var head := Vector3(0.52 + Parts.lean(v, 10 + side, 0.08), high, z + Parts.lean(v, 12 + side, 0.07))
		if ruined and side < 0:
			# One post gone and that corner of the roof on the ground.
			head = Vector3(0.3, 0.26, z - 0.18)
			fallen = high - 0.26
		Parts.post(k, Vector3(0.5, 0.0, z), head, 0.055, Parts.pick(Parts.TIMBER, v, 20 + side))
		Parts.stone(k, Vector3(0.5, 0.0, z), 0.11, v, 30 + side)
		# A rafter from the head down to the ground at the back.
		k.strut(head, Vector3(back, 0.1, z + Parts.lean(v, 14 + side, 0.05)), 0.042, 4, Parts.pick(Parts.TIMBER, v, 22 + side))
		Parts.lash(k, head + Vector3(0, -0.04, 0), head + Vector3(-0.1, -0.1, 0), v, 40 + side)
	# The ridge pole across the two heads, and the skin over everything. It runs
	# from the BACK on the ground UP to the ridge, so its face is turned to the
	# sky and not to the earth (the winding rule, Parts.wall).
	var l := Vector3(0.52, high - fallen, -half)
	var r := Vector3(0.52, high, half)
	if ruined:
		l = Vector3(0.3, 0.26, -half - 0.18)
	k.strut(l, r, 0.038, 4, Parts.pick(Parts.TIMBER, v, 24))
	var cloth := Parts.pick(Parts.THATCH, v, 5) if Parts.wob(v, 6) < 0.6 else Parts.pick(Parts.CLOTH, v, 7)
	var b0 := Vector3(back, 0.12, -half)
	var b1 := Vector3(back, 0.12, half)
	Parts.skin(k, b0, b1, r, l, cloth, v, 2)
	# Both ends closed in. An open wedge is a frame, and a frame keeps the rain
	# off nobody: this is what makes it read as somewhere to sleep.
	var ends := Parts.pick(Parts.CLOTH, v, 9)
	k.tri(b0, l, Vector3(0.5, 0.0, -half), ends)
	k.tri(b1, Vector3(0.5, 0.0, half), r, ends)
	# A middle rafter over the skin, holding it down, and two battens across it,
	# so the slope is read by its lines and not only by its edges.
	k.strut(Vector3(0.5, high * 0.96, 0.0), Vector3(back + 0.04, 0.16, 0.02), 0.03, 4, Parts.CORD_DARK)
	for i in 2:
		var t := 0.32 + 0.34 * float(i)
		Parts.lash(k, b0.lerp(l, t) + Vector3(0.02, 0.03, 0.0), b1.lerp(r, t) + Vector3(0.02, 0.03, 0.0), v, 8 + i, 0.024)
	if ruined:
		return
	# Bracken and a blanket inside: the reason to come back to it.
	k.sway = 0.2
	for i in 5:
		var t := (float(i) + 0.5) / 5.0
		var x := lerpf(back + 0.1, 0.36, t)
		k.rock(x, 0.0, lerpf(-half + 0.1, half - 0.1, Parts.wob(v, 50 + i)), 0.16, 0.07, v * 13 + i, P.MOSS[2], 5)
	k.sway = 0.0


# --- hut --------------------------------------------------------------------

## A holding that has salvaged well (docs/LOOK.md): a crooked frame of posts
## and boards with machine plate lashed over the gaps, a sagging ridge, turf
## banked at the foot, and a door cut out of a hull.
static func hut_made(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.hand(k)
	var feet := _hut_posts(v)
	var tops := _hut_tops(v, ruined)
	var n := feet.size()
	# The walls, as walls: a face between each pair of corners, every corner
	# leaning its own way and standing its own height. Thin boards read as a
	# handful of sticks under a roof at 640x360 — a wall has to be a surface.
	for i in n:
		var j := (i + 1) % n
		var col := Parts.pick(Parts.TIMBER, v, 80 + i)
		if ruined and Parts.wob(v, 90 + i) < 0.35:
			# Pulled apart: the studs are all that is left of that side.
			_studs(k, feet[i], feet[j], tops[i], tops[j], v, i)
			continue
		if _is_doorway(feet, i):
			_door_wall(k, feet[i], feet[j], tops[i], tops[j], col, v, i)
			continue
		k.quad(feet[j], feet[i], tops[i], tops[j], col)
		# Two boards stood proud of the face, so the wall is not one flat wash.
		for b in 2:
			var t := 0.28 + 0.4 * float(b) + Parts.lean(v, 100 + i * 2 + b, 0.08)
			var low: Vector3 = feet[i].lerp(feet[j], t)
			var high: Vector3 = tops[i].lerp(tops[j], t)
			k.strut(low * 1.03, low.lerp(high, 0.92) * 1.03, 0.05, 4, Parts.pick(Parts.TIMBER, v, 110 + i * 2 + b))
	# The corner posts, proud of the walls they hold up.
	for i in n:
		Parts.post(k, feet[i] * 1.05, tops[i] * 1.05, 0.062, Parts.pick(Parts.TIMBER, v, 120 + i))
	_hut_roof(k, v, ruined, tops)
	Parts.bank(k, Vector3(0.0, 0.0, -1.02), 0.8, 0.2, v, 6)
	Parts.bank(k, Vector3(0.0, 0.0, 1.02), 0.8, 0.2, v, 7)


## A hipped roof over an irregular footprint: a sagging ridge down the middle and
## one panel out to every eave. Its pitch is steep and its overhang short, so the
## silhouette is a house and not a table.
static func _hut_roof(k: MeshKit, v: int, ruined: bool, tops: Array) -> void:
	var ridge_y := (2.02 if not ruined else 1.5) + Parts.wob(v, 130) * 0.1
	var a := Vector3(Parts.lean(v, 131, 0.05), ridge_y, -0.5)
	var b := Vector3(Parts.lean(v, 132, 0.05), ridge_y - 0.12, 0.5)
	var n := tops.size()
	var eaves: Array[Vector3] = []
	for i in n:
		var t: Vector3 = tops[i]
		eaves.append(Vector3(t.x * 1.16, t.y + 0.04, t.z * 1.16))
	for i in n:
		var j := (i + 1) % n
		if ruined and Parts.wob(v, 140 + i) < 0.4:
			# The skin off that panel: bare rafters against the sky.
			k.strut(eaves[i], _nearest(eaves[i], a, b), 0.035, 4, Parts.pick(Parts.TIMBER, v, 150 + i))
			continue
		var ra := _nearest(eaves[i], a, b)
		var rb := _nearest(eaves[j], a, b)
		var col := Parts.pick(Parts.THATCH, v, 160 + i)
		if ra.is_equal_approx(rb):
			k.tri(eaves[j], eaves[i], ra, col)
		else:
			k.quad(eaves[j], eaves[i], ra, rb, col)
		# A batten laid across the panel, holding the thatch down.
		var mid_e: Vector3 = eaves[i].lerp(eaves[j], 0.5)
		var mid_r: Vector3 = ra.lerp(rb, 0.5)
		k.strut(mid_e.lerp(mid_r, 0.25), mid_e.lerp(mid_r, 0.8), 0.033, 4, Parts.pick(Parts.TIMBER, v, 170 + i))
	# The ridge itself: the darkest line in the silhouette, and the one that says
	# which way the hut faces.
	k.strut(a + Vector3(0, 0.03, 0), b + Vector3(0, 0.03, 0), 0.055, 5, Parts.TIMBER[0])
	for i in 3:
		var t := (float(i) + 0.5) / 3.0
		Parts.lash(k, a.lerp(b, t) + Vector3(0, 0.06, 0), a.lerp(b, t) + Vector3(0.2, -0.1, 0), v, 180 + i, 0.022)


static func _nearest(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	return a if absf(p.z - a.z) <= absf(p.z - b.z) else b


## The bay that faces +X: two narrow returns with the doorway between them.
static func _door_wall(k: MeshKit, f0: Vector3, f1: Vector3, t0: Vector3, t1: Vector3, col: Color, v: int, slot: int) -> void:
	var w := 0.3 + Parts.wob(v, 190 + slot) * 0.08
	k.quad(f0.lerp(f1, w), f0, t0, t0.lerp(t1, w), col)
	k.quad(f1, f0.lerp(f1, 1.0 - w), t0.lerp(t1, 1.0 - w), t1, col)
	# The lintel over the gap: a hut's door is a hole somebody framed.
	var head := 0.72
	k.strut(f0.lerp(f1, w) + Vector3(0, head, 0), f1.lerp(f0, w) + Vector3(0, head + 0.03, 0), 0.055, 4, Parts.TIMBER[0])
	k.quad(f1.lerp(f0, w), f0.lerp(f1, w), f0.lerp(f1, w) + Vector3(0, head, 0), f1.lerp(f0, w) + Vector3(0, head, 0), Parts.ASH)


## What is left of a wall somebody pulled the boards off.
static func _studs(k: MeshKit, f0: Vector3, f1: Vector3, t0: Vector3, t1: Vector3, v: int, slot: int) -> void:
	for i in 3:
		var t := (float(i) + 0.5) / 3.0
		var low: Vector3 = f0.lerp(f1, t)
		var high: Vector3 = t0.lerp(t1, t)
		k.strut(low, low.lerp(high, 0.5 + Parts.wob(v, 200 + slot * 3 + i) * 0.5), 0.05, 4, Parts.pick(Parts.TIMBER, v, 210 + i))


## The machine's half of a hut: plate over the gaps in the boards, a patch on the
## roof where the thatch gave out, and a door leaf cut out of a hull.
static func hut_found(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.ruled(k)
	var feet := _hut_posts(v)
	var n := feet.size()
	# Two or three walls patched, never all of them: a hut shows what it has been
	# through, and a place that patched everything would read as issued.
	var patches := 2 + int(Parts.wob(v, 120) * 2.0)
	for p in patches:
		var i := (int(Parts.wob(v, 121 + p) * float(n)) + p) % n
		if _is_doorway(feet, i):
			i = (i + 1) % n
		var mid: Vector3 = ((feet[i] as Vector3) + (feet[(i + 1) % n] as Vector3)) * 0.5
		var along: Vector3 = (feet[(i + 1) % n] as Vector3) - (feet[i] as Vector3)
		Parts.panel_facing(k, mid * 1.08 + Vector3(0.0, 0.16 + Parts.wob(v, 130 + p) * 0.44, 0.0), mid)
		Parts.plate(k, minf(0.3, along.length() * 0.38), 0.34 + Parts.wob(v, 131 + p) * 0.2, v, 132 + p)
		k.pop()
	if ruined:
		# What is left of it: one panel down in the grass where the wall was.
		Parts.panel(k, Vector3(1.2, 0.02, 0.1), PI * 0.44)
		Parts.plate(k, 0.26, 0.5, v, 144)
		k.pop()
		return
	# A patch laid ON the roof where the thatch gave out: it lies along the slope
	# with its own face to the sky, which is the only way it reads as a patch
	# rather than a panel standing on a roof.
	var side := -1 if Parts.wob(v, 140) < 0.5 else 1
	Parts.panel(k, Vector3(side * 1.0, 1.32, Parts.lean(v, 141, 0.45)), atan2(1.0, 0.72), side)
	Parts.plate(k, 0.26, 0.5, v, 142)
	k.pop()
	# The door: a leaf cut out of a hull, hung in the gap and standing ajar.
	var door: Vector3 = _doorway_at(feet)
	Parts.panel_facing(k, door * 1.04, door + Vector3(0.0, 0.0, 0.5))
	Parts.plate(k, 0.2, 0.78, v, 143)
	k.pop()
	# One strip light off a machine's flank, wired in over the door.
	if Parts.wob(v, 150) < 0.5:
		Parts.strip(k, door * 1.02 + Vector3(0.0, 0.88, -0.1), door * 1.02 + Vector3(0.0, 0.88, 0.12), 0.018)


## Five corners on an irregular ring: a footprint nobody squared up (law 1). The
## first is pushed toward +X so there is always a bay across the front for a door.
static func _hut_posts(v: int) -> Array:
	var out: Array = []
	for i in 5:
		var a := TAU * (float(i) + 0.5) / 5.0 + Parts.lean(v, 220 + i, 0.16)
		var r := 0.85 + Parts.wob(v, 230 + i) * 0.26
		out.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	return out


## The top of each corner. Every one leans its OWN way and stands its own
## height: one shared lean is a shear, and a sheared prism is still a prism.
static func _hut_tops(v: int, ruined: bool) -> Array:
	var out: Array = []
	var feet := _hut_posts(v)
	for i in feet.size():
		var f: Vector3 = feet[i]
		var h := (1.3 + Parts.wob(v, 240 + i) * 0.16) * (0.66 if ruined else 1.0)
		out.append(Vector3(f.x * 0.95 + Parts.lean(v, 250 + i, 0.1), h, f.z * 0.95 + Parts.lean(v, 260 + i, 0.1)))
	return out


## The bay whose middle lies furthest toward +X is the doorway: a hut is set down
## facing the way in, and every footprint has exactly one such bay.
static func _is_doorway(posts: Array, i: int) -> bool:
	return i == _doorway_bay(posts)


static func _doorway_bay(posts: Array) -> int:
	var best := 0
	var best_x := -INF
	for i in posts.size():
		var mid: Vector3 = ((posts[i] as Vector3) + (posts[(i + 1) % posts.size()] as Vector3)) * 0.5
		if mid.x > best_x:
			best_x = mid.x
			best = i
	return best


## The middle of the doorway bay, on the ground.
static func _doorway_at(posts: Array) -> Vector3:
	var i := _doorway_bay(posts)
	return ((posts[i] as Vector3) + (posts[(i + 1) % posts.size()] as Vector3)) * 0.5


# --- store ------------------------------------------------------------------

## What a holding lays by, kept up off the wet: a crib of boards on four legs,
## with a peaked lid over it and a basket standing by. Raised is the whole point
## — a store on the ground is a store the weather and the rats have already had.
static func store(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.hand(k)
	var w := 0.4 + Parts.wob(v, 1) * 0.06
	var d := 0.32 + Parts.wob(v, 2) * 0.05
	var deck := 0.34 + Parts.wob(v, 3) * 0.08
	var high := deck + 0.46
	# The corners, anticlockwise in x-z, so every face below looks outward.
	var ring: Array[Vector3] = [Vector3(w, 0.0, -d), Vector3(w, 0.0, d), Vector3(-w, 0.0, d), Vector3(-w, 0.0, -d)]
	for i in ring.size():
		var foot: Vector3 = ring[i]
		Parts.post(k, foot, foot + Vector3(Parts.lean(v, 10 + i, 0.05), deck + 0.06, Parts.lean(v, 14 + i, 0.05)), 0.055,
			Parts.pick(Parts.TIMBER, v, 20 + i))
		Parts.stone(k, foot, 0.1, v, 30 + i)
	if ruined:
		# Turned over and gone through: the legs snapped and the boards scattered.
		for i in 4:
			var a := TAU * float(i) / 4.0 + Parts.wob(v, 40 + i)
			k.strut(Vector3(cos(a) * 0.1, 0.05, sin(a) * 0.1), Vector3(cos(a) * (0.5 + Parts.wob(v, 44 + i) * 0.3), 0.04, sin(a) * 0.55),
				0.05, 4, Parts.pick(Parts.TIMBER, v, 50 + i))
		Parts.stone(k, Vector3(0.12, 0.0, -0.06), 0.15, v, 60)
		return
	# The crib itself: four board walls, each a different wash, sitting on the legs.
	for i in ring.size():
		var j := (i + 1) % ring.size()
		var f0: Vector3 = (ring[i] as Vector3) * 0.94 + Vector3(0, deck, 0)
		var f1: Vector3 = (ring[j] as Vector3) * 0.94 + Vector3(0, deck, 0)
		Parts.wall(k, f0, f1, f0 + Vector3(0, high - deck, 0), f1 + Vector3(0, high - deck, 0), Parts.pick(Parts.TIMBER, v, 70 + i))
		# One board stood proud, and the gap under it where the light gets in.
		k.strut(f0.lerp(f1, 0.3) * 1.04, f0.lerp(f1, 0.3) * 1.04 + Vector3(0, high - deck - 0.06, 0), 0.04, 4,
			Parts.pick(Parts.TIMBER, v, 80 + i))
	# The lid: two planks meeting off centre, overhanging all round.
	var peak := high + 0.2
	var l0 := Vector3(Parts.lean(v, 90, 0.06), peak, -d - 0.1)
	var l1 := Vector3(Parts.lean(v, 91, 0.06), peak - 0.04, d + 0.1)
	for side: int in [-1, 1]:
		var e0 := Vector3(side * (w + 0.12), high, -d - 0.12)
		var e1 := Vector3(side * (w + 0.12), high - 0.02, d + 0.12)
		if side > 0:
			k.quad(e1, e0, l0, l1, Parts.pick(Parts.THATCH, v, 100))
		else:
			k.quad(e0, e1, l1, l0, Parts.pick(Parts.THATCH, v, 101))
	k.strut(l0, l1, 0.045, 4, Parts.TIMBER[0])
	# A basket stood beside it, because a store is never quite big enough.
	k.prism(-w - 0.26, 0.0, d * 0.2, 0.17, 0.3, 0.14, 7, P.SAND[2], P.SAND[1])
	Parts.lash(k, Vector3(-w - 0.26, 0.22, d * 0.2 - 0.17), Vector3(-w - 0.26, 0.2, d * 0.2 + 0.17), v, 110, 0.022)


# --- bunk -------------------------------------------------------------------

## Beds for people who are not the player (docs/VISION.md). A lean-to is one
## night's roof and a hut is a household; a bunk is what a holding puts up when
## what it needs is HANDS, and it has to read as that from a hillside — not as
## another hut, and not as a store up on legs.
##
## THE BERTHS STICK OUT PAST THE ROOF. Drawn as an ordinary shed — four posts and
## a roof over everything — the play camera looks down at 57 degrees onto a plank
## roof and the piece is a market stall, with the one thing that tells a bunk from
## a shed hidden underneath it. So the roof is a CANOPY over the head end only and
## the sleeping shelves cantilever out from the back wall into open sky, propped at
## their outer corners, blankets face up. It reads from any bearing rather than
## from one, and it is honest carpentry: roof the end where the heads are and let
## the feet take the weather.
##
## A WARNING, because it cost three renders: a shelf is a horizontal quad, and a
## horizontal quad wound the wrong way round is not dim or dark, it is GONE.
## `MeshKit.tri` authors CCW and takes its normal from `(c - b).cross(a - b)`, so
## a face meant to be seen from above must run round the other way than feels
## natural writing it. Both berth quads and the blanket on them were face down at
## first, which looks exactly like the roof hiding them — the props under the
## shelves drew, the shelves did not, and the piece read as an empty carport.
static func bunk(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.hand(k)
	var half := 0.88 + Parts.wob(v, 1) * 0.1   # along z, the long axis
	var deep := 0.46 + Parts.wob(v, 2) * 0.04  # along x, back wall to berth ends
	var back := -deep
	var front := deep
	var wall_h := 0.94 + Parts.wob(v, 3) * 0.08
	# Where the canopy stops. Everything in front of this line is open to the sky.
	var eave := -0.04
	var eave_h := wall_h + 0.2
	# The back posts, and the pair that carry the canopy's outer edge.
	for sz: int in [-1, 1]:
		var z := sz * half
		Parts.post(k, Vector3(back, 0.0, z), Vector3(back + Parts.lean(v, 10 + sz, 0.04), wall_h, z), 0.052,
			Parts.pick(Parts.TIMBER, v, 20 + sz))
		Parts.stone(k, Vector3(back, 0.0, z), 0.1, v, 30 + sz)
		var head := eave_h if not (ruined and sz < 0) else 0.34
		Parts.post(k, Vector3(eave, 0.0, z), Vector3(eave + Parts.lean(v, 12 + sz, 0.05), head, z), 0.05,
			Parts.pick(Parts.TIMBER, v, 24 + sz))
		Parts.stone(k, Vector3(eave, 0.0, z), 0.1, v, 34 + sz)
	# The plates the canopy sits on, running the long way.
	k.strut(Vector3(back, wall_h, -half), Vector3(back, wall_h - 0.02, half), 0.04, 4, Parts.pick(Parts.TIMBER, v, 40))
	var drop := eave_h - 0.34 if ruined else 0.0
	k.strut(Vector3(eave, eave_h - drop, -half), Vector3(eave, eave_h, half), 0.042, 4,
		Parts.pick(Parts.TIMBER, v, 41))
	# The berths: two tiers, cantilevered out from the back wall past the eave, so
	# their outer halves and the blankets on them are under open sky.
	if not ruined:
		for tier in 2:
			var y := 0.30 + 0.36 * float(tier)
			for berth in 2:
				var z0 := lerpf(-half + 0.08, 0.03, float(berth))
				var z1 := z0 + (half - 0.15)
				var out_x := front - 0.04
				# The shelf, wound so its face is turned to the sky and not the earth.
				k.quad(Vector3(back + 0.05, y, z1), Vector3(out_x, y - 0.02, z1),
					Vector3(out_x, y - 0.02, z0), Vector3(back + 0.05, y, z0),
					Parts.pick(Parts.TIMBER, v, 50 + tier * 2 + berth))
				# The blanket, lying on the OUTER half where it can be seen from above.
				var cloth := Parts.pick(Parts.CLOTH, v, 60 + tier * 2 + berth)
				var b0 := lerpf(eave, out_x, 0.12)
				k.quad(Vector3(b0, y + 0.02, z1 - 0.04), Vector3(out_x - 0.05, y + 0.005, z1 - 0.04),
					Vector3(out_x - 0.05, y + 0.005, z0 + 0.04), Vector3(b0, y + 0.02, z0 + 0.04), cloth)
				# The bedroll at the head of it, in under the canopy.
				k.prism(back + 0.16, y + 0.02, (z0 + z1) * 0.5 - 0.22, 0.09, y + 0.16, 0.08, 6, cloth, cloth)
				# The prop under the outer corner: nobody trusted the shelf that far out.
				k.strut(Vector3(out_x - 0.03, y - 0.02, z0 + 0.04), Vector3(out_x - 0.03, 0.03, z0 + 0.04),
					0.026, 4, Parts.CORD_DARK)
				k.strut(Vector3(out_x - 0.03, y - 0.02, z1 - 0.04), Vector3(out_x - 0.03, 0.03, z1 - 0.04),
					0.026, 4, Parts.CORD_DARK)
	# The canopy over the head end, shedding back over the wall.
	var rb_l := Vector3(back - 0.14, wall_h + 0.03 - drop, -half - 0.1)
	var rb_r := Vector3(back - 0.14, wall_h + 0.03, half + 0.1)
	var rf_l := Vector3(eave + 0.06, eave_h + 0.03 - drop, -half - 0.1)
	var rf_r := Vector3(eave + 0.06, eave_h + 0.03, half + 0.1)
	k.quad(rf_l, rb_l, rb_r, rf_r, Parts.pick(Parts.THATCH, v, 4))
	# Battens across it, so it is read by its lines and not only by its edge.
	for i in 2:
		var t := 0.34 + 0.32 * float(i)
		k.strut(rb_l.lerp(rf_l, t), rb_r.lerp(rf_r, t), 0.026, 4, Parts.CORD_DARK)
	if ruined:
		# Gone through: the shelves down and the bedding out in the mud.
		for i in 3:
			var a := TAU * float(i) / 3.0 + Parts.wob(v, 70 + i)
			k.prism(cos(a) * 0.7, 0.0, sin(a) * 0.8, 0.11, 0.14, 0.1, 6,
				Parts.pick(Parts.CLOTH, v, 74 + i), Parts.ASH)
		k.strut(Vector3(0.2, 0.06, -half + 0.2), Vector3(0.9, 0.05, -half - 0.1), 0.045, 4,
			Parts.pick(Parts.TIMBER, v, 80))
		return
	# The back wall boarded in, and the two ends as far as the eave, so the wind is
	# off the heads. In front of the eave nothing is walled: that is the point.
	Parts.wall(k, Vector3(back, 0.0, half), Vector3(back, 0.0, -half),
		Vector3(back, wall_h, half), Vector3(back, wall_h, -half), Parts.pick(Parts.TIMBER, v, 89))
	for sz: int in [-1, 1]:
		var z := sz * half
		var b := Vector3(back, 0.0, z)
		var f := Vector3(eave, 0.0, z)
		var bt := Vector3(back, wall_h, z)
		var ft := Vector3(eave, eave_h, z)
		var end := Parts.pick(Parts.TIMBER, v, 90 + sz)
		if sz > 0:
			Parts.wall(k, b, f, bt, ft, end)
		else:
			Parts.wall(k, f, b, ft, bt, end)
