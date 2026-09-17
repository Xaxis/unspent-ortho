class_name WorksDepot
## The drawn depot of the plan (docs/VISION.md §2), and the three working parts
## a player has to get through to put one out.
##
##   WorksDepot.yard(site, stage, made_material) -> Node3D
##   WorksDepot.part(kind_index, seed_value, made_material) -> Node3D
##   WorksDepot.set_dark(node, dark)        every light on it, out for good
##   WorksDepot.set_broken(part_node, done)  that part, opened and spilling
##
## Everything structural is FOUND: ruled plate, square ends, no jitter, straight
## through whatever chaotic ground it was dropped on (docs/ART.md §2, VISION §8
## "ordered chaos"). The only MADE thing here is what people did to it
## afterwards — a ladder lashed to a leg, sacking over a rail — because a depot
## the machines still run is a depot people only get near at night.
##
## It is drawn to be READ FROM FAR OFF AT NIGHT, which is its whole job in the
## world: the mast stands twice the height of anything else the plan builds, its
## beacon blinks on the machines' beat, and a lit strip runs the length of every
## bay. Put that out and the silhouette is still there in the morning, cold.
##
## The lights are one MeshInstance3D of their own (`lamps`), so going dark is
## hiding a node and never rebuilding a mesh: a works goes out the instant its
## last part does, and stays out for the rest of the game.

const P := preload("res://src/render/palette.gd")
const W := preload("res://src/models/props/works.gd")

## The deck, in tiles. Long along the survey bearing, because everything the
## machines built in a world lies on it.
const DECK_LONG := 6.6
const DECK_WIDE := 3.4
const DECK_HIGH := 1.15
## The mast over it: the thing seen from twenty tiles out. The tallest thing the
## plan builds outside a stack — half again the height of a fire tower (4.2), so
## a depot is a silhouette on the horizon and not a shed in a field.
const MAST_HIGH := 7.4
const MAST_R := 0.46
## A bay added per plan stage, along the deck.
const BAY_LONG := 1.25
const BAY_HIGH := 1.8

## The plate a depot is cut from, and its lit top face.
const PLATE := Color(0.2536, 0.2892, 0.3655)
const PLATE_TOP := Color(0.3511, 0.3906, 0.4811)
const PLATE_DARK := Color(0.1687, 0.1962, 0.2518)
const SHADOW := Color(0.0892, 0.1064, 0.1412)
## The drum and tank enamel: the machines' own violet, dirtier than their bodies.
const ENAMEL := Color(0.2290, 0.1981, 0.3137)
const ENAMEL_TOP := Color(0.3176, 0.2695, 0.4413)
## What people lashed on afterwards.
const TIMBER := Color(0.3098, 0.2118, 0.1529)
const SACKING := Color(0.4353, 0.3961, 0.3490)
const CORD := Color(0.5882, 0.5412, 0.4627)
## Spoil and rust round the footings.
const SPOIL := Color(0.2314, 0.1961, 0.2196)


## The yard: deck, mast, bays for `stage`, and the ladder somebody left on it.
static func yard(site: WorksSite, stage: int, made_material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "works_%d" % maxi(0, site.region)
	var found := MeshKit.new()
	found.style = Ink.NONE
	found.style2 = Ink.NONE
	var lamps := MeshKit.new()
	lamps.style = Ink.NONE
	lamps.style2 = Ink.NONE
	var made := MeshKit.new()
	made.style = Ink.HAND
	made.style2 = Ink.HAND
	var s := maxi(0, site.region) * 31 + 7
	_deck(found, made, lamps, s)
	_mast(found, lamps)
	for i in clampi(stage + 1, 1, Works.STAGES):
		_bay(found, lamps, i)
	_leavings(made, s)
	root.add_child(_mesh("found", found, PropModels.found_material()))
	root.add_child(_mesh("lamps", lamps, PropModels.found_material()))
	root.add_child(_mesh("made", made, made_material))
	return root


## One working part. `i` is its index in `Works.PART_NAMES`: the feed drums, the
## breaker cabinet, the coolant stack. Three silhouettes, so a player coming back
## to finish a job knows at a glance which one they already had open.
static func part(i: int, seed_value: int, made_material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "part_%d" % i
	var whole := MeshKit.new()
	whole.style = Ink.NONE
	whole.style2 = Ink.NONE
	var lamps := MeshKit.new()
	lamps.style = Ink.NONE
	lamps.style2 = Ink.NONE
	var broke := MeshKit.new()
	broke.style = Ink.NONE
	broke.style2 = Ink.NONE
	var made := MeshKit.new()
	made.style = Ink.HAND
	made.style2 = Ink.HAND
	match i:
		0: _feed(whole, lamps, broke, seed_value)
		1: _breaker(whole, lamps, broke, seed_value)
		_: _coolant(whole, lamps, broke, seed_value)
	_spoil(made, seed_value + i * 13)
	root.add_child(_mesh("found", whole, PropModels.found_material()))
	root.add_child(_mesh("lamps", lamps, PropModels.found_material()))
	var b := _mesh("broken", broke, PropModels.found_material())
	b.visible = false
	root.add_child(b)
	root.add_child(_mesh("made", made, made_material))
	return root


## Every light on a node out, for good. A works that has been broken is dark in
## the morning and dark next week: this is what the region reads as quiet.
static func set_dark(node: Node3D, dark: bool) -> void:
	if node == null:
		return
	var lamps := node.get_node_or_null(^"lamps")
	if lamps != null:
		(lamps as Node3D).visible = not dark


## A working part, opened: its own light out, its whole body hidden and its torn
## one shown. Nothing animates — a machine part does not sag, it is simply open,
## and what is inside it is showing.
static func set_broken(node: Node3D, done: bool) -> void:
	if node == null:
		return
	set_dark(node, done)
	var whole := node.get_node_or_null(^"found")
	if whole != null:
		(whole as Node3D).visible = not done
	var broke := node.get_node_or_null(^"broken")
	if broke != null:
		(broke as Node3D).visible = done


static func _mesh(node_name: String, k: MeshKit, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = node_name
	m.mesh = k.build()
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


# --- the yard ------------------------------------------------------------------

## The deck: a plate floor on six legs with a ruled rail, spoil banked at the
## footings. Raised, because everything the plan lays on the ground is laid in a
## line and the one thing it lifts is where it keeps its own.
static func _deck(k: MeshKit, made: MeshKit, lamps: MeshKit, seed_value: int) -> void:
	var hl := DECK_LONG * 0.5
	var hw := DECK_WIDE * 0.5
	for i in 3:
		var x := -hl + 0.55 + i * (DECK_LONG - 1.1) * 0.5
		for side: float in [-1.0, 1.0]:
			var z := side * (hw - 0.35)
			k.box(Vector3(x - 0.18, 0.0, z - 0.18), Vector3(x + 0.18, DECK_HIGH, z + 0.18), PLATE_DARK, PLATE)
			# A cross-brace each side, so the legs read as a frame and not as posts.
			k.strut(Vector3(x - 0.16, 0.12, z), Vector3(x + 0.7, DECK_HIGH - 0.1, z), 0.05, 4, SHADOW)
	k.box(Vector3(-hl, DECK_HIGH, -hw), Vector3(hl, DECK_HIGH + 0.16, hw), PLATE_DARK, PLATE_TOP)
	# THE DECK IS NOT ONE PLATE. Six were laid across it and welded, and the seam
	# between each pair is a shadowed line: a floor six tiles across drawn as one
	# quad is the flat slab ART §2 forbids, and at this camera the top face is
	# most of what a player sees of the whole building.
	for i in 6:
		var x := -hl + (i + 1) * DECK_LONG / 7.0
		k.box(Vector3(x - 0.035, DECK_HIGH + 0.16, -hw), Vector3(x + 0.035, DECK_HIGH + 0.185, hw), PLATE_DARK, PLATE_DARK)
	k.box(Vector3(-hl, DECK_HIGH + 0.16, -0.05), Vector3(hl, DECK_HIGH + 0.185, 0.05), PLATE_DARK, PLATE_DARK)
	# A hatch let into it, open, with the dark under the deck showing through.
	k.box(Vector3(hl - 1.5, DECK_HIGH + 0.1, -hw + 0.55), Vector3(hl - 0.8, DECK_HIGH + 0.17, -hw + 1.2), SHADOW, SHADOW)
	k.box(Vector3(hl - 0.76, DECK_HIGH + 0.16, -hw + 0.5), Vector3(hl - 0.06, DECK_HIGH + 0.2, -hw + 1.25), PLATE, PLATE_TOP)
	# Drums stacked where the ramp comes up: the stock the yard runs on.
	for i in 3:
		var dz := -hw + 0.55 + i * 0.6
		k.prism(hl - 0.62, DECK_HIGH + 0.16, dz, 0.24, DECK_HIGH + 0.74, 0.24, 8, ENAMEL, ENAMEL_TOP)
	k.prism(hl - 0.62, DECK_HIGH + 0.74, -hw + 1.15, 0.24, DECK_HIGH + 1.32, 0.24, 8, ENAMEL, ENAMEL_TOP)
	# The rail: uprights and two runs, on both long sides. The ends are open.
	for side: float in [-1.0, 1.0]:
		var z := side * (hw - 0.08)
		k.box(Vector3(-hl, DECK_HIGH + 0.2, z - 0.04), Vector3(hl, DECK_HIGH + 0.28, z + 0.04), PLATE, PLATE_TOP)
		k.box(Vector3(-hl, DECK_HIGH + 0.64, z - 0.04), Vector3(hl, DECK_HIGH + 0.72, z + 0.04), PLATE, PLATE_TOP)
		for i in 7:
			var x := -hl + 0.3 + i * (DECK_LONG - 0.6) / 6.0
			k.block(x, DECK_HIGH + 0.2, z, 0.07, 0.56, 0.07, PLATE_DARK)
	# The ramp down off the near end, ruled, with its own kerbs.
	k.box(Vector3(hl, 0.02, -hw + 0.4), Vector3(hl + 1.7, 0.1, hw - 0.4), PLATE_DARK, PLATE)
	k.strut(Vector3(hl, DECK_HIGH + 0.14, -hw + 0.5), Vector3(hl + 1.65, 0.08, -hw + 0.5), 0.08, 4, PLATE)
	k.strut(Vector3(hl, DECK_HIGH + 0.14, hw - 0.5), Vector3(hl + 1.65, 0.08, hw - 0.5), 0.08, 4, PLATE)
	# Strips under the deck lip and along the rail: the light that says the thing
	# is live, and the whole of what lights the ground a player comes up to it
	# over. STEADY, all of them — a depot whose only light blinks is a depot that
	# is dark in four frames out of five.
	for side: float in [-1.0, 1.0]:
		var z := side * hw
		lamps.box(Vector3(-hl + 0.2, DECK_HIGH - 0.16, z - 0.05), Vector3(hl - 0.2, DECK_HIGH - 0.02, z + 0.05), W.STRIP)
		lamps.box(Vector3(-hl + 0.6, DECK_HIGH + 0.66, z - 0.04), Vector3(hl - 0.6, DECK_HIGH + 0.72, z + 0.04), W.STRIP)
	# Spoil the diggers left when they cut the footing in. MADE: the ground's own
	# hand, hatched, so the yard reads as cut INTO the land and not set on it.
	for i in 6:
		var a := Rng.hash01(seed_value, i, 0x0C) * TAU
		var r := hl * 0.5 + Rng.hash01(seed_value, i, 0x0D) * 1.6
		made.rock(cos(a) * r, 0.0, sin(a) * r * 0.7, 0.22 + Rng.hash01(seed_value, i, 0x0E) * 0.2, 0.15, seed_value + i, SPOIL, 5)


## The mast: a lattice twice the height of anything else the plan builds, guyed
## off the deck, with a blinking beacon on its head. This is the silhouette.
static func _mast(k: MeshKit, lamps: MeshKit) -> void:
	var base := DECK_HIGH + 0.16
	var x := -DECK_LONG * 0.5 + 1.0
	# FOUR LEGS AND NOT A POLE. A tapered prism with diagonals laid over it reads
	# at close range and is a grey stick at the distance this thing exists to be
	# seen from; four separate legs with rings and diagonals between them keep a
	# lattice's gaps, and the gaps are what say "mast" in one silhouette.
	var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var top := base + MAST_HIGH
	for c in corners:
		k.strut(Vector3(x + c.x * MAST_R, base, c.y * MAST_R),
			Vector3(x + c.x * MAST_R * 0.34, top, c.y * MAST_R * 0.34), 0.075, 4, PLATE)
	for i in 7:
		var t0 := i / 7.0
		var t1 := (i + 1) / 7.0
		var y0 := lerpf(base, top, t0)
		var y1 := lerpf(base, top, t1)
		var r0 := lerpf(MAST_R, MAST_R * 0.34, t0)
		var r1 := lerpf(MAST_R, MAST_R * 0.34, t1)
		for j in 4:
			var a := corners[j]
			var b := corners[(j + 1) % 4]
			# A ring at each level, and one diagonal a face, alternating, which is
			# how a real lattice is braced and how the gaps stay open.
			k.strut(Vector3(x + a.x * r1, y1, a.y * r1), Vector3(x + b.x * r1, y1, b.y * r1), 0.038, 4, PLATE_DARK)
			if (i + j) % 2 == 0:
				k.strut(Vector3(x + a.x * r0, y0, a.y * r0), Vector3(x + b.x * r1, y1, b.y * r1), 0.032, 4, SHADOW)
	# The caged ladder up the back of it, in one ruled run.
	for i in 16:
		var y := base + 0.3 + i * MAST_HIGH / 17.0
		var r := lerpf(MAST_R, MAST_R * 0.34, (y - base) / MAST_HIGH)
		k.block(x - r - 0.1, y, 0.0, 0.05, 0.05, 0.36, PLATE_DARK)
	# Guys down to the deck corners: two, so the mast is held and the frame reads.
	for side: float in [-1.0, 1.0]:
		k.strut(Vector3(x, base + MAST_HIGH * 0.72, 0.0), Vector3(x + 2.1, base, side * (DECK_WIDE * 0.5 - 0.3)), 0.028, 3, PLATE_DARK)
	# The head: a platform, a dish TIPPED off the horizon (a dish looking straight
	# up is a bowl and reads as a blob), and the beacon over it.
	k.box(Vector3(x - MAST_R * 0.62, top, -MAST_R * 0.62), Vector3(x + MAST_R * 0.62, top + 0.12, MAST_R * 0.62), PLATE_DARK, PLATE)
	k.push(Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3.BACK, 1.15), Vector3(x + 0.1, top + 0.36, 0.0)))
	k.prism(0.0, 0.0, 0.0, 0.07, 0.46, 0.46, 7, PLATE, PLATE_TOP)
	k.pop()
	k.strut(Vector3(x, top + 0.12, 0.0), Vector3(x + 0.1, top + 0.36, 0.0), 0.06, 4, PLATE_DARK)
	# The head light is TWO things: a collar that burns steady, so the mast is
	# alive in every frame, and a beacon over it that blinks on the machines'
	# beat, so it reads as a warning. One without the other is either a lamp
	# post or a thing that is dark most of the time.
	lamps.prism(x, base + MAST_HIGH + 0.12, 0.0, 0.22, base + MAST_HIGH + 0.24, 0.19, 6, W.STRIP, W.STRIP)
	lamps.prism(x, base + MAST_HIGH + 0.62, 0.0, 0.17, base + MAST_HIGH + 0.96, 0.1, 6, W.BEACON, W.BEACON)
	# Three strips down the mast, so it reads as a live thing from across the land.
	for i in 3:
		var y := base + MAST_HIGH * (0.24 + i * 0.26)
		var r := lerpf(MAST_R, MAST_R * 0.34, 0.24 + i * 0.26)
		lamps.box(Vector3(x - r - 0.05, y, -r - 0.05), Vector3(x + r + 0.05, y + 0.12, -r + 0.02), W.STRIP)


## One plan bay, added along the deck as the plan advances here: a ruled shed
## with a lit strip along its eave and a stack of the plan's own stock beside it.
static func _bay(k: MeshKit, lamps: MeshKit, i: int) -> void:
	var base := DECK_HIGH + 0.16
	var x := -DECK_LONG * 0.5 + 1.6 + i * BAY_LONG
	var hw := DECK_WIDE * 0.5 - 0.22
	k.box(Vector3(x, base, -hw), Vector3(x + BAY_LONG - 0.2, base + BAY_HIGH, hw), ENAMEL, ENAMEL_TOP)
	# A pitched cap, ruled: two quads, square-ended, nothing hand about it.
	k.box(Vector3(x - 0.08, base + BAY_HIGH, -hw - 0.1), Vector3(x + BAY_LONG - 0.12, base + BAY_HIGH + 0.12, hw + 0.1), PLATE_DARK, PLATE)
	# The door: a recessed well, which is what makes a box a thing with a front.
	k.box(Vector3(x + 0.1, base, hw - 0.03), Vector3(x + BAY_LONG - 0.36, base + BAY_HIGH * 0.72, hw + 0.02), SHADOW, SHADOW)
	_rivets(k, Vector3(x + 0.06, base + 0.18, hw + 0.03), Vector3(x + BAY_LONG - 0.26, base + 0.18, hw + 0.03), 4)
	lamps.box(Vector3(x, base + BAY_HIGH - 0.02, hw + 0.02), Vector3(x + BAY_LONG - 0.2, base + BAY_HIGH + 0.05, hw + 0.08), W.STRIP)


## What people did to it when nothing was looking: a ladder lashed to the near
## leg, and a sheet of sacking weighted over the rail. MADE, hatched, crooked.
static func _leavings(k: MeshKit, seed_value: int) -> void:
	var hl := DECK_LONG * 0.5
	var z := DECK_WIDE * 0.5 - 0.35
	for side: float in [-1.0, 1.0]:
		k.prism(hl - 0.55, 0.0, z * side + 0.22 * side, 0.05, DECK_HIGH + 0.2, 0.045, 5, TIMBER)
	for i in 4:
		k.block(hl - 0.55, 0.22 + i * 0.28, z * 1.0 + 0.11, 0.05, 0.05, 0.45, _tone(TIMBER, 1.0 + Rng.hash01(seed_value, i, 0x1A) * 0.2))
	k.box(Vector3(-hl + 0.4, DECK_HIGH + 0.2, -z - 0.28), Vector3(-hl + 1.5, DECK_HIGH + 0.66, -z - 0.14), SACKING, SACKING)
	k.prism(-hl + 0.95, DECK_HIGH + 0.66, -z - 0.2, 0.05, DECK_HIGH + 0.72, 0.05, 5, CORD)


# --- the three working parts ---------------------------------------------------

## The feed: three drums on a cradle with a pipe run into the deck, a lens on the
## gauge. Low and wide, so it is the one a player sees first coming up the ramp.
static func _feed(k: MeshKit, lamps: MeshKit, broke: MeshKit, seed_value: int) -> void:
	for i in 3:
		var z := -0.62 + i * 0.62
		k.push(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.0, 0.52, z)))
		k.prism(0.0, -0.52, 0.0, 0.3, 0.52, 0.3, 8, ENAMEL, ENAMEL_TOP)
		k.pop()
		broke.push(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.0, 0.52, z)))
		broke.prism(0.0, -0.52, 0.0, 0.3, 0.1, 0.28, 8, ENAMEL, ENAMEL_TOP)
		broke.pop()
		# What is inside a drum, once it is open: a dark well and a split lip.
		broke.box(Vector3(-0.3, 0.2, z - 0.28), Vector3(0.3, 0.3, z + 0.28), SHADOW, SHADOW)
	# The cradle under them, and the pipe out of the end one.
	for m: MeshKit in [k, broke]:
		m.box(Vector3(-0.36, 0.0, -0.95), Vector3(0.36, 0.22, 0.95), PLATE_DARK, PLATE)
		m.box(Vector3(-0.09, 0.4, 0.9), Vector3(0.09, 0.58, 2.1), PLATE, PLATE_TOP)
	# The gauge face and its lens: the light that says the feed is running.
	k.box(Vector3(0.28, 0.5, -0.2), Vector3(0.4, 0.86, 0.2), PLATE_DARK, PLATE)
	lamps.box(Vector3(0.4, 0.58, -0.12), Vector3(0.44, 0.78, 0.12), W.WORKING)
	broke.box(Vector3(0.28, 0.5, -0.2), Vector3(0.4, 0.62, 0.2), SHADOW, PLATE_DARK)
	broke.rock(0.6, 0.0, 0.4, 0.2, 0.14, seed_value, SPOIL, 5)


## The breaker: a tall narrow cabinet on a plinth, its door on the bearing, a row
## of pips down the jamb. The one part that reads as a DOOR, so a player knows
## which of the three is the one that is opened rather than emptied.
static func _breaker(k: MeshKit, lamps: MeshKit, broke: MeshKit, seed_value: int) -> void:
	for m: MeshKit in [k, broke]:
		m.box(Vector3(-0.55, 0.0, -0.62), Vector3(0.55, 0.16, 0.62), PLATE_DARK, PLATE)
		m.box(Vector3(-0.34, 0.16, -0.46), Vector3(0.34, 1.86, 0.46), PLATE, PLATE_TOP)
		m.box(Vector3(-0.42, 1.86, -0.54), Vector3(0.42, 2.0, 0.54), PLATE_DARK, PLATE_TOP)
	# The door: a shallow recess with a handle bar, closed.
	k.box(Vector3(0.3, 0.3, -0.34), Vector3(0.36, 1.7, 0.34), PLATE_DARK, PLATE)
	k.block(0.38, 0.9, 0.22, 0.04, 0.3, 0.05, SHADOW)
	_rivets(k, Vector3(0.37, 0.36, -0.3), Vector3(0.37, 1.64, -0.3), 6)
	# Opened: the door swung back on its hinge and the racks inside showing, with
	# one board prised out and hanging on its loom.
	broke.push(Transform3D(Basis(Vector3.UP, 1.15), Vector3(0.32, 0.0, -0.32)))
	broke.box(Vector3(0.0, 0.3, -0.04), Vector3(1.36, 1.7, 0.04), PLATE_DARK, PLATE)
	broke.pop()
	broke.box(Vector3(0.0, 0.3, -0.32), Vector3(0.32, 1.7, 0.32), SHADOW, SHADOW)
	for i in 5:
		broke.box(Vector3(0.04, 0.42 + i * 0.26, -0.28), Vector3(0.3, 0.48 + i * 0.26, 0.28), PLATE_DARK, PLATE_DARK)
	broke.strut(Vector3(0.3, 1.0, 0.0), Vector3(0.86, 0.12, 0.3), 0.05, 4, ENAMEL)
	broke.rock(-0.7, 0.0, -0.5, 0.18, 0.12, seed_value + 3, SPOIL, 5)
	# Pips down the jamb: a lit column a player can count from across the yard.
	for i in 5:
		lamps.box(Vector3(0.35, 0.44 + i * 0.26, -0.42), Vector3(0.39, 0.54 + i * 0.26, -0.36), W.STRIP)


## The coolant: a finned stack under a vent hood, a collar strip round its waist.
## Tall and thin with a hood on top, so it is told from the breaker at a glance.
static func _coolant(k: MeshKit, lamps: MeshKit, broke: MeshKit, seed_value: int) -> void:
	for m: MeshKit in [k, broke]:
		m.box(Vector3(-0.5, 0.0, -0.5), Vector3(0.5, 0.14, 0.5), PLATE_DARK, PLATE)
		m.prism(0.0, 0.14, 0.0, 0.34, 1.7, 0.3, 6, ENAMEL, ENAMEL_TOP)
	# Fins: the silhouette, ruled and even.
	for i in 6:
		var y := 0.3 + i * 0.22
		k.prism(0.0, y, 0.0, 0.46, y + 0.05, 0.46, 6, PLATE_DARK, PLATE)
		if i < 3:
			broke.prism(0.0, y, 0.0, 0.46, y + 0.05, 0.46, 6, PLATE_DARK, PLATE)
	# The hood over the head, and its throat.
	k.prism(0.0, 1.7, 0.0, 0.3, 2.06, 0.5, 6, PLATE, PLATE_TOP)
	k.prism(0.0, 2.06, 0.0, 0.5, 2.16, 0.46, 6, PLATE_DARK, PLATE)
	lamps.prism(0.0, 1.06, 0.0, 0.36, 1.18, 0.36, 6, W.STRIP, W.STRIP)
	# Broken: the hood off and lying, the throat torn open, the stack stubbed.
	broke.push(Transform3D(Basis(Vector3.FORWARD, 1.35), Vector3(0.95, 0.24, -0.35)))
	broke.prism(0.0, 0.0, 0.0, 0.3, 0.36, 0.5, 6, PLATE, PLATE_TOP)
	broke.pop()
	broke.prism(0.0, 1.06, 0.0, 0.3, 1.2, 0.28, 6, SHADOW, SHADOW)
	broke.strut(Vector3(0.1, 1.1, 0.06), Vector3(0.62, 0.1, -0.44), 0.04, 4, ENAMEL)
	broke.rock(-0.5, 0.0, 0.6, 0.19, 0.12, seed_value + 9, SPOIL, 5)


## The spoil and hoses round a part's footing: MADE, low, and what makes a
## machine cabinet look stood in the ground rather than dropped on it.
static func _spoil(k: MeshKit, seed_value: int) -> void:
	for i in 4:
		var a := Rng.hash01(seed_value, i, 0x2A) * TAU
		var r := 0.7 + Rng.hash01(seed_value, i, 0x2B) * 0.5
		k.rock(cos(a) * r, 0.0, sin(a) * r, 0.16 + Rng.hash01(seed_value, i, 0x2C) * 0.12, 0.09, seed_value + i, SPOIL, 5)


## A row of small blocks along a line: the rivets that keep a ruled plate from
## reading as a painted rectangle at 640x360 (docs/ART.md §2).
static func _rivets(k: MeshKit, a: Vector3, b: Vector3, n: int) -> void:
	for i in n:
		var p := a.lerp(b, (i + 0.5) / float(n))
		k.block(p.x, p.y, p.z, 0.026, 0.026, 0.026, P.PLATE[5])


static func _tone(col: Color, k: float) -> Color:
	return Color(clampf(col.r * k, 0.0, 1.0), clampf(col.g * k, 0.0, 1.0), clampf(col.b * k, 0.0, 1.0), col.a)


## The gallery: the yard at both ends of its life, and its three parts whole and
## opened, so a review can judge the silhouette and the read without a world.
static func gallery() -> Array:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/render/world.gdshader")
	var site := WorksSite.new()
	site.region = 0
	site.trade = &"intake"
	var out: Array = []
	var lit := yard(site, 0, mat)
	out.append({"name": "works_yard", "node": lit})
	var grown := yard(site, Works.STAGES - 1, mat)
	out.append({"name": "works_yard_stage3", "node": grown})
	var dark := yard(site, Works.STAGES - 1, mat)
	set_dark(dark, true)
	out.append({"name": "works_yard_dark", "node": dark})
	for i in Works.PART_NAMES.size():
		var whole := part(i, 5, mat)
		out.append({"name": "works_part_%s" % Works.PART_NAMES[i], "node": whole})
		var done := part(i, 5, mat)
		set_broken(done, true)
		out.append({"name": "works_part_%s_broken" % Works.PART_NAMES[i], "node": done})
	return out
