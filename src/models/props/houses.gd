extends RefCounted
## Houses and ruins. Each house is one picture read in order: silhouette, then
## roof material, then walls (art-audio-extract §5). All are MADE (irregular
## footprints, leaning walls, sagging ridges, chimneys off true, turf banked at
## the foot) except what came off machines, which is FOUND: roof plate laid
## where the old roof failed, cable, cast discs, the lived-in machine housing of
## the "but", and the enamel plate on the wall. The plate is ruled; the line
## struck through it is drawn by hand.
##
## A house faces +X (its door), like every model.

const Kit := preload("res://src/models/props/kit.gd")
const Towers := preload("res://src/models/props/towers.gd")
const Crags := preload("res://src/models/props/crags.gd")
const Mesas := preload("res://src/models/props/mesas.gd")
const P := preload("res://src/render/palette.gd")


## What a building of this landscape's `v`th form is. The variant is an index
## into THE LANDSCAPE'S OWN STOCK (`BiomeForms`), not a global model number, so
## a landscape that builds towers and one that builds crofts both deal 0, 1, 2
## and get their own shapes — which is what makes the model cache's per-country
## key do the work and costs no extra variants at all.
##
## The match is on a FORM and never on a landscape. Naming a landscape in this
## directory is what dressed every new one as the coast, and `tests/biome` fails
## on it; a form id is the opposite — the landscape asked for it, by name.
static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.HAND)
	if kind == PropKind.RUIN:
		ruin(k, v, c)
		return
	form(k, BiomeForms.of(c).form(v), c)


## The named form, whichever stock names it: the one door from a form id to
## its geometry, so a test can raise any row of `BiomeForms.FORMS` without
## knowing which landscape's stock it sits in.
static func form(k: Kit, form_id: StringName, c: int) -> void:
	match form_id:
		&"washed": washed(k, c, 0)
		&"slated": slated(k, c, 0)
		&"long": long_house(k, c)
		&"but": but(k, c)
		&"cot": washed(k, c, 1)
		&"narrow": slated(k, c, 1)
		&"steading": washed(k, c, 2)
		&"half": half_house(k, c)
		# The crags' (props/crags.gd): what was standing before the machines,
		# lived in. Dry stone and turf, and nothing wired in.
		&"roundhouse": Crags.roundhouse(k, c)
		&"lean_to_broch": Crags.lean_to_broch(k, c)
		&"byre": Crags.byre(k, c)
		# The mesas' (props/mesas.gd): cut into the rock, raised in its mud,
		# and one hut over the drop with a stolen lamp.
		&"cut_room": Mesas.cut_room(k, c)
		&"adobe": Mesas.adobe(k, c)
		&"watch_hut": Mesas.watch_hut(k, c)
		# Everything else a landscape may name is built upward, and lives in its
		# own file: this one is the open country's and has no business knowing
		# how a tower is made.
		var other: Towers.build(k, other, c)


## Four leaning walls on an irregular footprint. Returns the corners as
## [b00, b10, b11, b01, t00, t10, t11, t01] (b bottom, t top; x then z).
static func walls(k: Kit, w: float, d: float, h: float, seed_value: int, front: Color, side: Color, lean: Vector3 = Vector3(0.05, 0.0, 0.03)) -> Array[Vector3]:
	var c: Array[Vector3] = []
	var sx: Array[float] = [-1.0, 1.0, 1.0, -1.0]
	var sz: Array[float] = [-1.0, -1.0, 1.0, 1.0]
	for i in 4:
		c.append(Vector3(sx[i] * w * 0.5 + Kit.j(seed_value, i, 0.14), 0.0, sz[i] * d * 0.5 + Kit.j(seed_value, i + 4, 0.14)))
	for i in 4:
		# Every corner leans its OWN way and stands its own height. One shared
		# lean vector is a shear: it tilts the prism and leaves it a rigid box,
		# which is what the art review saw.
		#
		# **THE PIXEL BUDGET HERE IS STALE BY THE FACTOR THE FLOOR MOVED.** It
		# said "24 px a world unit: 3-5 px of lean, about 3 px of height", which
		# was the 640x360 base. The play camera is 72 px to the unit now, and the
		# numbers below did not change — so this lean is about 17 px, not 4. The
		# geometry may well be right; what is certainly wrong is deriving a new
		# value from the old budget, which is why the arithmetic is written out
		# rather than the conclusion. See `kit.gd`'s stone rings for the same
		# error in the same package.
		var b := c[i]
		var own := Vector3(Kit.j(seed_value, i + 12, 0.115), 0.0, Kit.j(seed_value, i + 16, 0.115))
		c.append(Vector3(b.x * 0.94, h + Kit.j(seed_value, i + 8, 0.2), b.z * 0.955) + (lean + own) * h * 1.4)
	# Faces: +x front (door), +z, -x, -z. Order bottom-left, bottom-right, top-right, top-left seen from outside.
	k.made.quad(c[2], c[1], c[5], c[6], front)
	k.made.quad(c[3], c[2], c[6], c[7], side)
	k.made.quad(c[0], c[3], c[7], c[4], GroundColors.down(side, 0.2))
	k.made.quad(c[1], c[0], c[4], c[5], GroundColors.down(front, 0.15))
	return c


## A point on a wall face (bl, br, tr, tl), u along, v up, pushed out a hair.
static func on_wall(bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, u: float, v: float, out: float = 0.01) -> Vector3:
	# On the TRIANGLE the wall is actually made of, not on the bilinear surface
	# between its corners. `walls()` gives every corner its own lean and its own
	# height, so a wall face is never planar, and MeshKit draws it as
	# tri(bl, br, tr) + tri(bl, tr, tl): the bilinear point at the middle of a
	# face can sit a finger BEHIND those triangles — measured, twice the hair a
	# `wall_rect` stands proud by. That is why the enamel plate the machinery
	# counts a house by drew nothing at all on three of the eight houses
	# (tests/render/test_found_drawn.gd), and why anything else laid on a wall
	# could silently sink into it.
	if v <= u:
		return bl * (1.0 - u) + br * (u - v) + tr * v + (tr - br).cross(bl - br).normalized() * out
	return bl * (1.0 - v) + tr * u + tl * (v - u) + (tl - tr).cross(bl - tr).normalized() * out


## A rectangle on a wall face from (u0, v0) to (u1, v1).
static func wall_rect(pen: MeshKit, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, u0: float, v0: float, u1: float, v1: float, out: float, col: Color) -> void:
	pen.quad(on_wall(bl, br, tr, tl, u0, v0, out), on_wall(bl, br, tr, tl, u1, v0, out), on_wall(bl, br, tr, tl, u1, v1, out), on_wall(bl, br, tr, tl, u0, v1, out), col)


## The enamel plate the machinery still counts a house by, struck through by
## hand, a third of the way along the wall and a little under half height.
static func struck_plate(k: Kit, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, u: float, v: float) -> void:
	var wlen := bl.distance_to(br)
	# Every layer of it used to be covered by the one over it: the strike was a
	# BAR a fifth of the plate's height and five tallies crossed the middle of
	# the enamel, so between them nothing of the dark frame and nothing of the
	# enamel face was left — the plate drew NOTHING from any bearing, on every
	# house that carries one (tests/render/test_found_drawn.gd). A machine's
	# plate is a cast frame with an enamel face set in it, and a strike through
	# it is a SCORE, not a bar: the frame is wide enough to read, the tallies are
	# small and low, and the score crosses without eating what it crosses. It is
	# a SIZE and not a share of the wall, too: the plate a machine screwed to a
	# house is the same plate whatever house it is on, and as a share of the
	# height it came out two cells tall on the 1.0-high ones.
	var wh := maxf(bl.distance_to(tl), 0.5)
	var hu := 0.22 / wlen
	var hv := 0.22 / wh
	# Bolted on, so it stands clear of every other thing drawn on a wall (a rain
	# run is 0.011 out, a board 0.030) rather than sharing their thickness.
	wall_rect(k.found, bl, br, tr, tl, u - hu, v - hv, u + hu, v + hv, 0.036, P.INK[0])
	wall_rect(k.found, bl, br, tr, tl, u - hu * 0.7, v - hv * 0.66, u + hu * 0.7, v + hv * 0.66, 0.042, P.RIME[5])
	for t in 4:
		var tu := u - hu * 0.44 + t * hu * 0.28
		wall_rect(k.found, bl, br, tr, tl, tu - 0.005, v - hv * 0.56, tu + 0.005, v - hv * 0.2, 0.046, P.SLATE[2])
	# The strike: a score across it, a little off level, past both edges. In
	# world units too, so it stays a score and never becomes a bar.
	var lo := 0.02 / wh
	var hi := 0.055 / wh
	var tilt := 0.035 / wh
	k.made.quad(on_wall(bl, br, tr, tl, u - hu * 1.25, v + lo, 0.05), on_wall(bl, br, tr, tl, u + hu * 1.25, v + lo + tilt, 0.05), on_wall(bl, br, tr, tl, u + hu * 1.25, v + hi + tilt, 0.05), on_wall(bl, br, tr, tl, u - hu * 1.25, v + hi, 0.05), P.INK[0])


## A window: a copper frame over glass that is lit at night.
static func window(k: Kit, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, u: float, v: float, hw: float, hh: float) -> void:
	wall_rect(k.made, bl, br, tr, tl, u - hw, v - hh, u + hw, v + hh, 0.012, P.COPPER[1])
	wall_rect(k.made, bl, br, tr, tl, u - hw * 0.72, v - hh * 0.75, u + hw * 0.72, v + hh * 0.75, 0.016, GroundColors.lamp(P.COPPER[4], 0.9))
	wall_rect(k.made, bl, br, tr, tl, u - hw * 0.08, v - hh * 0.75, u + hw * 0.08, v + hh * 0.75, 0.02, P.COPPER[2])


## Ink & Neon: a tube of stolen neon fixed to a wall, lit at night: somebody
## wired a machine's light into their house. Its colour is the house's own.
static func neon_tube(k: Kit, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, u0: float, u1: float, v: float, col: Color) -> void:
	wall_rect(k.made, bl, br, tr, tl, u0 - 0.01, v - 0.02, u1 + 0.01, v + 0.02, 0.03, P.INK[1])
	wall_rect(k.made, bl, br, tr, tl, u0, v - 0.011, u1, v + 0.011, 0.04, GroundColors.neon(col))


const NEON_TUBES: Array[Color] = [Color(0.3, 0.95, 1.0), Color(1.0, 0.25, 0.8), Color(0.55, 1.0, 0.35)]


## The same stolen light run along the roof edge, a hand's width up the slope.
##
## A tube on the door wall alone could not be seen at all (art review 11, which
## found zero tube pixels in three canon frames). Two reasons, both the camera's:
## the door faces the village square, which is only the camera's way for half the
## houses in a village; and at v=0.85 the tube sat under the eave overhang, which
## at a 57-degree pitch hides everything within about 0.1 of the wall top. The
## roof is the one surface this camera always sees, so that is where the light
## goes — and a line of colour along a dark roofline is the better drawing.
static func neon_run(k: Kit, eave: PackedVector3Array, ridge: PackedVector3Array, v: float, col: Color) -> void:
	var lift := Vector3(0, 0.05, 0)
	var glow := GroundColors.neon(col)
	for i in eave.size() - 1:
		# The bracket it is clipped to, and the tube itself proud of it.
		var a0 := eave[i].lerp(ridge[i], v) + lift
		var b0 := eave[i + 1].lerp(ridge[i + 1], v) + lift
		var a1 := eave[i].lerp(ridge[i], v + 0.1) + lift
		var b1 := eave[i + 1].lerp(ridge[i + 1], v + 0.1) + lift
		k.made.quad(b0, a0, a1, b1, P.INK[1])
		var g := Vector3(0, 0.025, 0)
		var ta := a0.lerp(a1, 0.22) + g
		var tb := b0.lerp(b1, 0.22) + g
		var ua := a0.lerp(a1, 0.72) + g
		var ub := b0.lerp(b1, 0.72) + g
		k.made.quad(tb, ta, ua, ub, glow)


## The four wall faces of a `walls()` result, each as (bl, br, tr, tl) seen from
## outside: front (+x, the door), +z, -x, -z.
static func faces(t: Array[Vector3]) -> Array:
	return [[t[2], t[1], t[5], t[6]], [t[3], t[2], t[6], t[7]], [t[0], t[3], t[7], t[4]], [t[1], t[0], t[4], t[5]]]


## What the years do to a wall nobody can paint again: the wash comes off in
## patches and the rubble under it shows, rain draws dark runs down from the
## eaves, and the foot goes green where it never dries. Laid on EVERY face; a
## village where only the door wall is worn reads as a village before the end.
static func weathered(k: Kit, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, s: int, rubble: Color, green: Color) -> void:
	for i in 2:
		var u0 := fmod(0.04 + i * 0.44 + Rng.hash01(s, i, 5) * 0.3, 0.62)
		var v0 := fmod(0.05 + i * 0.49 + Rng.hash01(s, i, 6) * 0.3, 0.58)
		wall_rect(k.made, bl, br, tr, tl, u0, v0, u0 + 0.22 + Rng.hash01(s, i, 8) * 0.14, v0 + 0.16 + Rng.hash01(s, i, 9) * 0.14,
			0.007, rubble if i % 2 == 0 else GroundColors.down(rubble, 0.25))
	# Rain off the eaves: thin runs, hanging from the top and each its own length.
	for i in 5:
		var u := 0.1 + i * 0.19 + Kit.j(s, i + 2, 0.04)
		var drop := 0.2 + Rng.hash01(s, i, 7) * 0.55
		wall_rect(k.made, bl, br, tr, tl, u - 0.008, 1.0 - drop, u + 0.008, 0.995, 0.011, GroundColors.down(rubble, 0.6))
	wall_rect(k.made, bl, br, tr, tl, 0.0, 0.0, 1.0, 0.075 + Rng.hash01(s, 4, 3) * 0.04, 0.006, green)


## The outward normal of a wall face (bl, br, tr, tl).
static func wall_out(bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3) -> Vector3:
	return (tr - br).cross(bl - br).normalized()


## A window that lost its glass and was boarded from inside: the dark of the
## room behind, three planks across it at slightly different angles, nails at
## their ends. People live in this ruin; they did not move out (docs/VISION.md
## section 8, "the patched, wired, scavenged places where people still live").
static func boarded(k: Kit, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, u: float, v: float, hw: float, hh: float, s: int) -> void:
	wall_rect(k.made, bl, br, tr, tl, u - hw, v - hh, u + hw, v + hh, 0.012, P.COPPER[1])
	wall_rect(k.made, bl, br, tr, tl, u - hw * 0.8, v - hh * 0.82, u + hw * 0.8, v + hh * 0.82, 0.016, P.INK[2])
	for i in 3:
		var vv := v - hh * 0.55 + i * hh * 0.55
		var tilt := Kit.j(s, i, 0.022)
		var half := hw * 1.35
		k.made.quad(on_wall(bl, br, tr, tl, u - half, vv - hh * 0.2 + tilt, 0.024),
			on_wall(bl, br, tr, tl, u + half, vv - hh * 0.2 - tilt, 0.024),
			on_wall(bl, br, tr, tl, u + half, vv + hh * 0.18 - tilt, 0.024),
			on_wall(bl, br, tr, tl, u - half, vv + hh * 0.18 + tilt, 0.024),
			P.EARTH[2] if i != 1 else P.EARTH[1])
		for side: float in [-1.0, 1.0]:
			wall_rect(k.made, bl, br, tr, tl, u + side * hw * 1.05 - 0.006, vv - 0.012, u + side * hw * 1.05 + 0.006, vv + 0.012, 0.03, P.RUST[2])


## A lean-to of salvage built against a wall: two crooked poles, a sheet of
## machine plate for a roof (FOUND: it is not theirs, and it does not match),
## and what is kept dry under it. One silhouette break that is also a life.
static func lean_to(k: Kit, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, u: float, s: int) -> void:
	var out := wall_out(bl, br, tr, tl)
	var wa := on_wall(bl, br, tr, tl, u - 0.17, 0.52, 0.0)
	var wb := on_wall(bl, br, tr, tl, u + 0.17, 0.48, 0.0)
	var fa := on_wall(bl, br, tr, tl, u - 0.17, 0.0, 0.0) + out * (0.78 + Kit.j(s, 1, 0.06))
	var fb := on_wall(bl, br, tr, tl, u + 0.17, 0.0, 0.0) + out * (0.72 + Kit.j(s, 2, 0.06))
	var ta := fa + Vector3(0, 0.66 + Kit.j(s, 3, 0.07), 0)
	var tb := fb + Vector3(0, 0.6 + Kit.j(s, 4, 0.07), 0)
	k.limb(fa, ta, 0.04, 0.032, 4, P.EARTH[2])
	k.limb(fb, tb, 0.04, 0.032, 4, P.EARTH[1])
	k.plate(ta, tb, wb, wa, P.PLATE[2], P.PLATE[1], P.PLATE[4])
	# Rust weeping off the plate down the wall under it.
	k.made.quad(on_wall(bl, br, tr, tl, u + 0.1, 0.1, 0.018), on_wall(bl, br, tr, tl, u + 0.14, 0.1, 0.018),
		on_wall(bl, br, tr, tl, u + 0.145, 0.5, 0.018), on_wall(bl, br, tr, tl, u + 0.105, 0.5, 0.018), P.RUST[2])
	# What is kept under it: split wood on end and a drum with no lid.
	var mid := fa.lerp(fb, 0.42) - out * 0.22
	for i in 4:
		var p := mid + (fb - fa).normalized() * (i - 1.5) * 0.09
		k.limb(p, p + Vector3(Kit.j(s, i + 9, 0.05), 0.34 + Kit.j(s, i, 0.08), Kit.j(s, i + 5, 0.05)), 0.035, 0.03, 4, P.EARTH[1] if i % 2 else P.EARTH[2])
	var drum := fb.lerp(fa, -0.35) - out * 0.16
	k.found.prism(drum.x, 0.0, drum.z, 0.15, 0.36, 0.15, 9, P.RUST[2], P.PLATE[1])


## Salvage stacked against a wall: sheets of plate leaned up on edge, a bundle
## of poles, a crate. The land leaves this everywhere; a village is where it is
## gathered and used.
static func salvage(k: Kit, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, u: float, s: int) -> void:
	var out := wall_out(bl, br, tr, tl)
	var along := (br - bl).normalized()
	var foot := on_wall(bl, br, tr, tl, u, 0.0, 0.0)
	for i in 3:
		var base := foot + along * ((i - 1) * 0.19 + Kit.j(s, i, 0.04)) + out * (0.28 + Kit.j(s, i + 3, 0.06))
		var top := base - out * 0.2 + Vector3(0, 0.46 + Kit.j(s, i + 6, 0.1), 0)
		var wide := along * (0.14 + Kit.j(s, i + 9, 0.03))
		k.plate(base - wide, base + wide, top + wide, top - wide,
			P.PLATE[2] if i != 1 else P.SLATE[3], P.PLATE[1], P.PLATE[4])
	var crate := foot + along * (0.34 + Kit.j(s, 12, 0.05)) + out * 0.3
	k.slab(crate.x, 0.0, crate.z, 0.36, 0.26, 0.3, s + 20, P.EARTH[2], P.EARTH[3], 0.02, 0.08, Kit.j(s, 13, 0.06))
	for i in 3:
		var p := crate + along * 0.3 + out * (0.05 * i)
		k.limb(p + Vector3(0, 0.03 + 0.05 * i, 0), p + along * 0.02 + out * -0.62 + Vector3(0, 0.02 + 0.05 * i, 0), 0.028, 0.024, 4, P.EARTH[1] if i % 2 else P.EARTH[2])


## A room added on against one wall (ART §4: irregular footprints). The house's
## own wall is one of its four, its other three are shorter and out of square,
## and its roof is a single patched fall from the house wall to its own eave.
## This is the change that stops a plan being a rectangle, so it is the change
## that stops the outline pass drawing four long straight runs (art review 5).
## `side` indexes `faces()`; keep it off the door wall.
static func outshot(k: Kit, t: Array[Vector3], side: int, s: int, c: int) -> void:
	var f: Array = faces(t)[side]
	var bl: Vector3 = f[0]
	var br: Vector3 = f[1]
	var tr: Vector3 = f[2]
	var tl: Vector3 = f[3]
	var out := wall_out(bl, br, tr, tl)
	var u0 := 0.12 + Rng.hash01(s, 0, 51) * 0.12
	var u1 := u0 + 0.46 + Rng.hash01(s, 1, 52) * 0.16
	# Against the wall: the two points it is built off, and the lean of the wall
	# carried up with it so the join is the drawing, not a hidden seam.
	var wa := on_wall(bl, br, tr, tl, u0, 0.0, 0.0)
	var wb := on_wall(bl, br, tr, tl, u1, 0.0, 0.0)
	var hw := 0.78 + Kit.j(s, 2, 0.07)
	var wat := on_wall(bl, br, tr, tl, u0, hw / maxf(0.4, (tl - bl).y), 0.0)
	var wbt := on_wall(bl, br, tr, tl, u1, hw / maxf(0.4, (tr - br).y), 0.0)
	# Out of square on purpose: the two ends are not the same depth or height.
	#
	# Shallow on purpose too. A house's collision is ONE radius (PropKind.SOLID
	# 1.6 tiles) round its middle, and a room reaching 0.86 past a wall face that
	# already stood at 1.375 put half a tile of room inside the circle a player
	# can walk through — in the middle of a wall, where they walk. At 0.46 the
	# added face stands 0.235 inside it: less than the corner of the house itself.
	var fa := wa + out * (0.36 + Kit.j(s, 3, 0.06))
	var fb := wb + out * (0.40 + Kit.j(s, 4, 0.06))
	var ha := 0.52 + Kit.j(s, 5, 0.07)
	var hb := 0.46 + Kit.j(s, 6, 0.07)
	var fat := fa + Vector3(Kit.j(s, 7, 0.06), ha, Kit.j(s, 8, 0.06))
	var fbt := fb + Vector3(Kit.j(s, 9, 0.06), hb, Kit.j(s, 10, 0.06))
	# Sawn board, which is brought in and kept under a roof, so it is the same
	# everywhere; the wall it is built off is the land's own building stone.
	var boards := P.EARTH[2]
	var stone := BiomeDressing.of(c).walling[0]
	k.made.quad(fa, fb, fbt, fat, boards)
	k.made.quad(wa, fa, fat, wat, GroundColors.down(stone, 0.2))
	k.made.quad(fb, wb, wbt, fbt, stone)
	# Board ends and a strap where the wall takes the rafter: never hide a join.
	for i in 3:
		var g := float(i + 1) / 4.0
		k.made.quad(fa.lerp(fb, g) + out * 0.012, fa.lerp(fb, g + 0.03) + out * 0.012,
			fat.lerp(fbt, g + 0.03) + out * 0.012, fat.lerp(fbt, g) + out * 0.012, GroundColors.down(boards, 0.35))
	# The fall of the roof: from the house wall down to its own wavering eave.
	const N := 3
	var eave := PackedVector3Array()
	var high := PackedVector3Array()
	for i in N + 1:
		var g := float(N - i) / N
		eave.append(fat.lerp(fbt, g) + out * (0.09 + Kit.j(s, i + 20, 0.03)) + Vector3(0, -0.02 - Kit.j(s, i + 25, 0.03), 0))
		high.append(wat.lerp(wbt, g) + Vector3(0, Kit.j(s, i + 30, 0.035), 0))
	patch_slope(k, eave, high, 2, s + 40, SLATE_ROOF, 0.30)
	k.made.quad(wat, wbt, fbt, fat, P.INK[2])
	# A drum and a stack of split wood in the lee of it: the room is used.
	var drum := fa.lerp(fb, 1.16) + out * 0.12
	k.found.prism(drum.x, 0.0, drum.z, 0.15, 0.34, 0.15, 9, P.RUST[2], P.PLATE[1])


## A plank door, its latch.
static func door(k: Kit, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, u: float, hw: float, hv: float) -> void:
	wall_rect(k.made, bl, br, tr, tl, u - hw * 1.2, 0.0, u + hw * 1.2, hv + 0.05, 0.012, P.EARTH[1])
	for p in 3:
		var pu := u - hw + (p + 0.5) * (2.0 * hw / 3.0)
		wall_rect(k.made, bl, br, tr, tl, pu - hw / 3.0 + 0.012, 0.01, pu + hw / 3.0 - 0.012, hv - 0.02 * p, 0.018, P.EARTH[2] if p != 1 else P.EARTH[3])
	wall_rect(k.made, bl, br, tr, tl, u - hw * 0.7, hv * 0.45, u - hw * 0.5, hv * 0.52, 0.026, P.COPPER[3])


## Turf banked against the foot of the walls (ART §4). Banked, not sprinkled: the
## old version sat 0.04 INSIDE the wall line, where the eaves hide it at the play
## camera, so the one thing that softens a house's foot never reached the screen.
## The bank runs out past the drip line as a skirt of sods, uneven along its
## length, with a few laid up the wall where the wind takes the corner.
static func turf_bank(k: Kit, corners: Array[Vector3], seed_value: int, c: int) -> void:
	# Sods cut from the ground the house stands on (BiomeDressing.turf): coast
	# moss banked against a house on the Bonelands read as a stripe of paint.
	var cols := BiomeDressing.of(c).turf
	for side in 4:
		var a := corners[side]
		var b := corners[(side + 1) % 4]
		var out := Vector3(b.z - a.z, 0, a.x - b.x).normalized()
		if out.dot(a + b) < 0.0:
			out = -out
		for i in 8:
			var f := (i + 0.5) / 8.0
			var reach := 0.12 + Rng.hash01(seed_value, side * 10 + i, 31) * 0.26
			var p := a.lerp(b, f) + out * reach
			# Low and wide, and overlapping along the run: a bank, not a row of
			# boulders round the house.
			k.clump(p.x, -0.07, p.z, 0.24 + Kit.j(seed_value, side * 10 + i, 0.07),
				0.17 + Kit.j(seed_value, side * 20 + i, 0.07), seed_value + side * 7 + i, cols[(i + side) % 3], 6)
		# One corner of each side has the bank built higher, in cut sods.
		var q := a.lerp(b, 0.22 + Rng.hash01(seed_value, side, 33) * 0.5) + out * 0.1
		k.slab(q.x, -0.04, q.z, 0.34, 0.2, 0.26, seed_value + side * 13, cols[2], cols[side % 2], 0.04, 0.16, Kit.j(seed_value, side, 0.12))


## What a roof is made of, as a weighted bag: mostly slate that held, in four
## tones, then the tar somebody painted over the worst of it and a board across a
## hole. A roof carries value even where no plate landed — but slate is the
## ground of it, so the odd materials stay odd. THE LAST ENTRY IS THE DAMP, and
## `patch_slope` only lets it lie at the foot of a slope, where it never dries.
## **WHAT THE ROOF IS MADE OF, told to the renderer and not only to the eye.**
## Every colour here used to reach the shader at alpha 1.0, which is mark 255 and
## falls to `matter_of`'s default — so slate and thatch came back with the same
## roughness, the same specular and the same relief, and only the mesh normal
## told them apart. Under one sun that is two roofs made of one substance.
## `GroundColors.made` puts the material in the alpha the shader already reads.
## **SLATE HAS THE ROW IT ASKED FOR** (`GroundColors.SLATE`, 92). The refusal
## that stood here was right to refuse and wrong in its arithmetic, and both
## halves are worth keeping. It said CUTSTONE is (0.84, 0.36), inside the 0.05
## that `matter_worn` erases in a week — but that was the SPEC value, and the
## same commit that wrote this shipped the row at (0.80, 0.42, 0.022) for
## exactly that reason. So the number this refusal rested on was corrected in
## another file by the very change that prompted it, and the sentence citing it
## went on reading true. A measurement goes stale the moment the thing it
## measured is altered, and it never announces that it has.
##
## What DID earn the row is the second argument, which never depended on a
## number: slate is not dressed stone. A block is sawn and a slate is CLEAVED,
## the smoothest face any stone takes, so it goes the other way from dressed
## block and should catch MORE light than a sawn board, not less. That is why
## 92 is (0.62, 0.54) — under CUTSTONE on roughness, over it on specular.
##
## It is also the surface with the most to gain in the game, which only a frame
## says: a village at the play camera is ROOFS, and the wall beneath them is a
## sliver in the shadow of the eaves. All of this was the default until now.
static var SLATE_ROOF: Array[Color] = _made(GroundColors.SLATE, [
	P.SLATE[2], P.SLATE[3], P.SLATE[2], P.SLATE[4], P.SLATE[3], P.SLATE[1],
	P.SLATE[3], P.SLATE[2], P.SLATE[1].lerp(P.EARTH[1], 0.45), P.EARTH[2], P.MOSS[2].lerp(P.SLATE[2], 0.5)])
static var THATCH_ROOF: Array[Color] = _made(GroundColors.THATCH, [
	P.EARTH[2], P.EARTH[3], P.SAND[3], P.EARTH[2], P.EARTH[3], P.SAND[2],
	P.EARTH[3], P.SAND[3], P.EARTH[1], P.EARTH[2], P.MOSS[3].lerp(P.EARTH[2], 0.5)])


static func _made(kind: int, bag: Array[Color]) -> Array[Color]:
	var out: Array[Color] = []
	for c in bag:
		out.append(GroundColors.made(c, kind))
	return out


## Points along a line from a to b, `n + 1` of them, each pushed off the line by
## its own hand. A roof edge drawn this way is never a ruled segment, which is
## what an outline pass turns into a straight black run (art review 5).
static func wavered(a: Vector3, b: Vector3, n: int, s: int, out: Vector3, amount: float, droop: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(b, t)
		p += out * (Kit.j(s, i + 3, amount))
		p.y -= droop * sin(t * PI) + Kit.j(s, i + 41, amount * 0.7)
		pts.append(p)
	return pts


## How wide a patch is laid, in world units: about ten screen pixels at the play
## camera, which is a piece of slate a person could carry.
const CELL := 0.3
## How far a course stands proud of the one under it. A slate is thin, but the
## face it leaves standing to the sky is what rules the line across the slope,
## and that face reads by turning AWAY from the sky rather than by the shadow it
## throws — so it works at noon, when nothing casts anything.
const LAP := 0.035
## How far a course reaches UP the slope. A course is a SIZE, not a count: a
## slate is the size a slate is, so a long slope carries more courses than a
## lean-to without anybody choosing a number per roof. The `rows` a caller passes
## is the floor under that.
const COURSE := 0.26
## No slope gets more than this, whatever its length: the ceiling is here so a
## roof nobody anticipated cannot quietly cost a thousand triangles.
const COURSES_MOST := 9
## The most of a slope that may be machine plate, as a share of its cells. A
## plated cell costs about 1.75 times its own area in FOUND triangles — a rim, an
## inner plate and four rivets — so a fifth of the cells is about a third of the
## roof by AREA, which is where "a patch on its roof, not the roof" is drawn.
## Stated in cells because that is what is dealt, and checked in area because
## that is what a player sees.
const PLATE_CELLS_MOST := 0.2
## How far up a slope, as a share of its courses, a plate cell may be laid. A
## roof fails at the eave and the valley — that is where somebody puts a sheet
## over the hole — and it is also the part of a roof the snow slides off, which
## is what makes the patch read in the Snowfield. Dealt over the whole slope,
## EVERY plate cell on a snowed house lay under the snow sheet and not one of
## them was drawn from any bearing (tests/render/test_found_drawn.gd, 31 pieces
## across four houses). The per-cell odds are raised by the same factor, so a
## roof carries about as much plate as before, gathered where it is seen.
const PLATE_ROWS := 0.5


## Cumulative length along a polyline, one entry per point.
static func _arc(line: PackedVector3Array) -> PackedFloat32Array:
	var cum := PackedFloat32Array()
	cum.resize(line.size())
	cum[0] = 0.0
	for i in range(1, line.size()):
		cum[i] = cum[i - 1] + line[i].distance_to(line[i - 1])
	return cum


## The point `at` units along a polyline, clamped to its ends.
static func _along(line: PackedVector3Array, cum: PackedFloat32Array, at: float) -> Vector3:
	var total := cum[cum.size() - 1]
	if at <= 0.0 or total <= 0.0:
		return line[0]
	if at >= total:
		return line[line.size() - 1]
	for i in range(1, cum.size()):
		if at <= cum[i]:
			var span := cum[i] - cum[i - 1]
			return line[i - 1].lerp(line[i], 0.0 if span <= 0.0 else (at - cum[i - 1]) / span)
	return line[line.size() - 1]


## A roof slope as a PATCHWORK, never one ruled corrugation (art review 5). The
## slope is given as two matched polylines — the eave and the ridge above it —
## and filled cell by cell. Its stations are already irregular (the polylines
## are); each course stops at its own height per station, so no cut runs the
## width of the roof; every cell takes its own material from what the house could
## get, and the ones that are machine plate are FOUND, ruled, and laid proud of
## the hand-made roof they patch. Interior corners lift a little, so the plane
## itself is lumpy under the ink instead of flat.
##
## The courses are laid PARALLEL TO THE EAVE and stationed by length from the
## middle of each course, never by matching index. On a hipped slope — a long
## eave under a short ridge — matching index converges every cell boundary on the
## ridge ends, so the patches nearest the apex came out as tapering slivers
## radiating from a point, and a plate one there was a ruled FOUND ray. Stationed
## by length, a patch is a piece of slate about `CELL` across wherever it lies,
## and a course that runs past the end of the one above it simply dies into the
## hip, which is what a hip end IS.
## Order the `eave` polyline so that the slope's outward face comes out right:
## reversing it flips the slope over, which is how two opposite slopes are drawn
## by one routine.
static func patch_slope(k: Kit, eave: PackedVector3Array, ridge: PackedVector3Array, rows: int, s: int, mats: Array[Color], plate_share: float) -> void:
	if eave.size() < 2 or ridge.size() != eave.size() or rows < 1:
		return
	var mid := eave.size() / 2
	rows = clampi(roundi((ridge[mid] - eave[mid]).length() / COURSE), rows, COURSES_MOST)
	var grid: Array[PackedVector3Array] = []
	for r in rows + 1:
		var line := PackedVector3Array()
		for i in eave.size():
			var v := float(r) / rows
			# The wander has to stay INSIDE a course's own spacing. At a fixed
			# 0.1 it was tuned for three courses; once a long slope carries seven
			# the rows cross each other, which scrambles the courses into crazy
			# paving and cuts slivers where a slate should be.
			if r > 0 and r < rows:
				v = clampf(v + Kit.j(s, r * 31 + i, 0.25 / rows), 0.05, 0.95)
			var p := eave[i].lerp(ridge[i], v)
			# The old lift was dealt per grid corner, which under a real sun made
			# every cell's flat normal disagree with its neighbours' and turned the
			# roof into shattered glass. A roof does sag, but it sags ALONG the
			# eave in one wave, not corner by corner.
			if r > 0 and r < rows and i > 0 and i < eave.size() - 1:
				p.y += sin(float(i) / float(eave.size() - 1) * PI) * Kit.j(s, r + 7, 0.03) + Kit.j(s, r * 53 + i + 7, 0.012)
			line.append(p)
		grid.append(line)
	# "A patch, not the roof" is a GUARANTEE here and not a hope. A per-cell
	# probability alone drifts with whatever grid is under it — finer courses
	# redraw every die — and a slope that comes out 0.36 machine plate on one
	# seed IS a plated roof, whatever the intended share was. So the plated cells
	# are counted against a ceiling taken from the slope's own size.
	var total := 0
	for r in rows:
		var lcr := _arc(grid[r])
		total += maxi(2, roundi(lcr[lcr.size() - 1] / CELL))
	var plate_left := ceili(float(total) * minf(plate_share, PLATE_CELLS_MOST))
	for r in rows:
		var low := grid[r]
		var high := grid[r + 1]
		var lc := _arc(low)
		var hc := _arc(high)
		var run: float = lc[lc.size() - 1]
		var up: float = hc[hc.size() - 1]
		if run <= 0.0:
			continue
		var cells := maxi(2, roundi(run / CELL))
		for i in cells:
			# Each cell keeps its own width along the course, and the course above
			# is cut at the same distance from the middle: boundaries run UP the
			# slope, and only the outermost cell of a course narrows into the hip.
			var l0 := run * float(i) / cells
			var l1 := run * float(i + 1) / cells
			var a := _along(low, lc, l0)
			var b := _along(low, lc, l1)
			var c := _along(high, hc, clampf(up * 0.5 + l1 - run * 0.5, 0.0, up))
			var d := _along(high, hc, clampf(up * 0.5 + l0 - run * 0.5, 0.0, up))
			var h := Rng.hash01(s, r * 41 + i, 61)
			if h < plate_share / PLATE_ROWS and plate_left > 0 and float(r) < float(rows) * PLATE_ROWS:
				plate_left -= 1
				var lift := Vector3(0, 0.03, 0)
				k.plate(b + lift, a + lift, d + lift, c + lift,
					P.PLATE[2] if h < plate_share * 0.55 else P.PLATE[3], P.PLATE[1], P.PLATE[4])
				continue
			# A COURSE IS LAID AT ONE TIME out of one heap of slate, so the material
			# runs ALONG the course and only a repair breaks it. Dealing every cell
			# its own material made a roof of crazy paving — noise standing exactly
			# where the courses should be — and a slate's own life belongs in its
			# TONE, which is what weather does to slates off one heap anyway.
			var pick := int(Rng.hash01(s, r, 71) * mats.size()) % mats.size()
			if Rng.hash01(s, r * 47 + i, 62) < 0.2:
				pick = int(Rng.hash01(s, r * 47 + i, 72) * mats.size()) % mats.size()
			# Damp only sits at the foot of the slope, where it never dries.
			if pick == mats.size() - 1 and r > 0:
				pick = 1
			var slate := Kit.tone(mats[pick], 0.93 + 0.14 * Rng.hash01(s, r * 29 + i, 73))
			# A COURSE LIES OVER THE ONE BELOW IT, and that overlap is the whole
			# drawing of a roof: the exposed edge of each course turns away from
			# the sky and rules a shadow line across the slope. Flat cells butted
			# edge to edge gave the light nothing to catch, so a roof came out as
			# one crystalline plane whatever was painted on it (docs/LOOK.md law 2).
			var face_n := (b - a).cross(d - a)
			var lay := face_n.normalized() * LAP if face_n.length_squared() > 1e-12 else Vector3(0, LAP, 0)
			k.made.quad(b + lay, a + lay, d + lay, c + lay, slate)
			k.made.quad(a, b, b + lay, a + lay, Kit.tone(slate, 0.8))
			# A course that slipped: the dark batten shows through the gap.
			if Rng.hash01(s, r * 53 + i, 63) < 0.08:
				var gap := lay * 1.5
				var bm := a.lerp(b, 0.45)
				k.made.quad(bm + gap, a + gap, a.lerp(d, 0.34) + gap, bm.lerp(c, 0.34) + gap, P.INK[2])


## The ridge end repeated, as the top of a hip: a "ridge" of no length, so
## `patch_slope` lays courses that shorten into the apex.
static func _apex(at: Vector3, n: int) -> PackedVector3Array:
	var line := PackedVector3Array()
	for i in n:
		line.append(at)
	return line


## A hipped roof over the wall tops: eaves out by `over`, a ridge along z of half
## length `rz` that sags in the middle. Both are drawn as wavering polylines and
## the slopes are filled by `patch_slope`, so nothing about the shape is ruled.
## Returns [e00, e10, e11, e01, r0, rm, r1].
## `drop_at` (0-3) sags that eave corner by `drop`, so the roofline has one
## break in it and the house is not a prism with a lid.
static func hipped(k: Kit, t: Array[Vector3], over: float, rise: float, rz: float, sag: float, s: int, mats: Array[Color], plate_share: float, ends: Color, drop_at: int = -1, drop: float = 0.0, neon: Color = Color(0, 0, 0, 0)) -> Array[Vector3]:
	# Over the WALL TOPS (t[4..7]), not the footings. This read the bottom four
	# corners, so the eaves sat at y = -0.1 and the roof was a tent pitched from
	# the ground that the walls stood up through: a hipped house had no wall/roof
	# junction to draw at all, which is a good part of why it read as one mass.
	var centre := (t[4] + t[5] + t[6] + t[7]) * 0.25
	var e: Array[Vector3] = []
	for i in 4:
		var dir := (t[i + 4] - centre)
		dir.y = 0.0
		# Each corner its own overhang and its own height: four corners cut to one
		# measure is the rectangle the outline pass found (art review 5).
		e.append(t[i + 4] + dir.normalized() * (over + Kit.j(s, i + 90, 0.15) + (0.09 if i == drop_at else 0.0))
			+ Vector3(0, -0.06 - Kit.j(s, i + 95, 0.07) - (drop if i == drop_at else 0.0), 0))
	var yr := centre.y + rise
	var r0 := Vector3(centre.x, yr, centre.z - rz)
	var r1 := Vector3(centre.x, yr, centre.z + rz)
	var rm := Vector3(centre.x, yr - sag, centre.z)
	# Eight stations, not five: the outline pass inks whatever run of edge is
	# straight, and a five-station eave across a 2.7-unit house leaves 11-pixel
	# ruled segments between its stations — long enough to read as a ruled line.
	const N := 8
	# The ridge: sagging, and wandering across the house as well, so it is not one
	# straight run of pen however far the eye follows it.
	var ridge := PackedVector3Array()
	for i in N + 1:
		var f := float(i) / N
		ridge.append(Vector3(centre.x + Kit.j(s, i + 60, 0.075), yr - sag * sin(f * PI) - Kit.j(s, i + 70, 0.05), lerpf(r0.z, r1.z, f)))
	var out_f := (e[2] - centre)
	out_f.y = 0.0
	out_f = out_f.normalized()
	var front := wavered(e[1], e[2], N, s + 5, out_f, 0.13, 0.075)
	# The back slope is the same routine with its eave walked the other way, so
	# the two halves of the roof face apart.
	var back := wavered(e[3], e[0], N, s + 9, -out_f, 0.13, 0.075)
	var ridge_back := PackedVector3Array()
	for i in N + 1:
		ridge_back.append(ridge[N - i])
	patch_slope(k, front, ridge, 3, s + 11, mats, plate_share)
	patch_slope(k, back, ridge_back, 3, s + 17, mats, plate_share * 0.6)
	if neon.a > 0.0:
		neon_run(k, front, ridge, 0.1, neon)
	# The hip ends are laid in courses too, cut at the hip. Five triangles fanned
	# from the ridge end in ONE colour is a plain sheet with a fan drawn on it —
	# the very thing this roof is not, and it was the biggest ruled shape left on
	# a hipped house. `patch_slope` against a collapsed ridge gives courses
	# parallel to the eave, and only the last one at the apex is triangular.
	var out_e := (e[3] - centre)
	out_e.y = 0.0
	out_e = out_e.normalized()
	var end_p := wavered(e[2], e[3], 5, s + 23, out_e, 0.11, 0.06)
	var end_m := wavered(e[0], e[1], 5, s + 29, -out_e, 0.11, 0.06)
	# The ends of a hipped roof are the SAME ROOF as its slopes, so whatever the
	# slopes were tagged the ends are too — and this builder is handed SLATE_ROOF
	# by one caller and THATCH_ROOF by another, so it must not know which. It
	# reads the mark off the bag it was given. Until it did, half of every hip
	# end was tagged (the `mats` entries) and half was the default (the ones
	# derived from `ends`), which is two materials on one roof face; the thatched
	# form has been drawn that way since THATCH became the first tagged array.
	var end: Color = GroundColors.same_matter(ends, mats[0])
	var end_mats: Array[Color] = [end, GroundColors.down(end, 0.18), mats[0], GroundColors.up(end, 0.12), mats[1], end, mats[3], mats[mats.size() - 1]]
	patch_slope(k, end_p, _apex(ridge[N], end_p.size()), 3, s + 23, end_mats, plate_share * 0.5)
	patch_slope(k, end_m, _apex(ridge[0], end_m.size()), 3, s + 29, end_mats, plate_share * 0.35)
	# The dark overhang under the eaves — wound to face UP, which is the only way
	# it is ever seen. The play camera is always above (pitch 57), so a plane
	# wound downward here is culled from every bearing and the "dark overhang" was
	# absent rather than dark. Where the sagging ridge or a dropped corner leaves
	# the slopes short of the eave line, this is what the eye meets instead of a
	# hole through the house to the ground.
	k.made.quad(e[3], e[2], e[1], e[0], P.INK[2])
	return [e[0], e[1], e[2], e[3], r0, rm, r1]


## "washed": lime-washed rubble walls under a hipped roof re-laid in plate,
## a few old slates left where they held. `form` varies the proportions, where
## the wash has come off, where the roof failed and was plated, and the chimney,
## so no two in a village are the same drawing.
static func washed(k: Kit, c: int, form: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 1400 + form * 37
	# Three houses of plainly different size, so a village does not read as one
	# house drawn three ways: the middle one is a third the footprint of the big.
	var w: float = [2.45, 1.8, 2.7][form]
	var d: float = [2.75, 2.35, 3.3][form]
	var h: float = [1.45, 1.05, 1.5][form]
	# CLAY (84), which this refused for want of a frame — and the reason given was
	# false. It said `--scene=gallery --filter=house` matches only the city's
	# TOWER forms. That filter matches 58 items and the tower forms are among
	# them, so reading the first names printed and stopping gives exactly that
	# answer; `PropModels.gallery()` also emits `house 0`..`house 7` in the
	# coast's dressing, and those ARE this stock. One readable plinth of this
	# very house is `tools/shot.sh --scene=gallery --filter=house_0`. The rule
	# invoked was the right rule. The fact underneath it was never checked, and a
	# refusal that names the right rule reads as proof the rule was obeyed.
	#
	# The frame, once taken, also corrected the claim above it: the wall is NOT
	# the largest surface this camera sees. At play pitch this form is a slate
	# roof with a wall in its shadow, which is why SLATE got a row first.
	#
	# Tagged at the source colour only. `walls()` darkens it for the other three
	# faces with `GroundColors.down`, which preserves alpha, so one tag dresses
	# the whole house; the rubble showing through the wash stays untagged,
	# because what shows there is broken stone and not the render over it.
	var wash: Color = GroundColors.made(
		[P.LINEN[4], P.LINEN[5].lerp(P.LINEN[4], 0.5), P.LINEN[4].lerp(P.SAND[4], 0.35)][form],
		GroundColors.CLAY)
	var t := walls(k, w, d, h, s, wash, GroundColors.down(wash, 0.35))
	var moss := dress.growth
	for fi in faces(t).size():
		var wf: Array = faces(t)[fi]
		weathered(k, wf[0], wf[1], wf[2], wf[3], s + fi * 13, P.STONE[2] if fi % 2 == 0 else P.STONE[3], moss)
	var fb := [t[2], t[1], t[5], t[6]]
	# Wash off in patches where the roof drips and boots scuff: rubble shows.
	for i in 2 + form:
		var u0 := fmod(0.13 + i * 0.41 + form * 0.23, 0.8)
		var v0 := fmod(0.05 + i * 0.57 + form * 0.31, 0.75)
		wall_rect(k.made, fb[0], fb[1], fb[2], fb[3], u0, v0, u0 + 0.12 + fmod(i * 0.13, 0.12), v0 + 0.1 + fmod(i * 0.07, 0.12), 0.008, P.STONE[2] if i % 2 == 0 else P.STONE[3])
	wall_rect(k.made, fb[0], fb[1], fb[2], fb[3], 0.0, 0.0, 1.0, 0.07, 0.006, P.LINEN[2])
	var door_u: float = [0.34, 0.66, 0.46][form]
	door(k, fb[0], fb[1], fb[2], fb[3], door_u, 0.1, 0.95)
	if form == 1:
		# One house in three wired a machine's light over its door.
		neon_tube(k, fb[0], fb[1], fb[2], fb[3], door_u - 0.14, door_u + 0.14, 0.64, NEON_TUBES[2])
	window(k, fb[0], fb[1], fb[2], fb[3], 0.8 if door_u < 0.5 else 0.22, 0.6, 0.08, 0.13)
	if form == 2:
		# The glass went and never came back; the room behind it is boarded.
		boarded(k, fb[0], fb[1], fb[2], fb[3], 0.18, 0.58, 0.07, 0.12, s + 31)
	struck_plate(k, fb[0], fb[1], fb[2], fb[3], [0.58, 0.36, 0.72][form], [0.44, 0.5, 0.4][form])
	var sb := [t[3], t[2], t[6], t[7]]
	if form == 1:
		boarded(k, sb[0], sb[1], sb[2], sb[3], 0.62, 0.58, 0.08, 0.13, s + 33)
	else:
		window(k, sb[0], sb[1], sb[2], sb[3], [0.4, 0.62, 0.3][form], 0.58, 0.08, 0.13)
	# What they live with against the walls: a lean-to of salvage on one house,
	# plate and firewood stacked on the next.
	if form == 0:
		lean_to(k, sb[0], sb[1], sb[2], sb[3], 0.28, s + 40)
	else:
		salvage(k, sb[0], sb[1], sb[2], sb[3], 0.8 if form == 1 else 0.2, s + 41)
	# The roof: a patchwork of what could be got, with plate off a machine where
	# the slate failed. One eave corner has given way, so the roofline is broken.
	var r := hipped(k, t, 0.24, [1.05, 0.9, 1.2][form], d * 0.2, [0.22, 0.28, 0.18][form], s + 60,
		SLATE_ROOF, [0.2, 0.3, 0.14][form], P.SLATE[2].lerp(P.SLATE[1], 0.5), [1, 3, 2][form], [0.18, 0.15, 0.2][form],
		NEON_TUBES[2] if form == 1 else Color(0, 0, 0, 0))
	# One patch hangs past the eave: the plate was cut to the hole, not the roof.
	_patch(k, r[1], r[2], r[6], r[4], [0.7, 0.58, 0.08][form], -0.14, [0.95, 0.84, 0.32][form], 0.16)
	# The ridge is laid in three, and the middle length of it is gone.
	k.made.strut(r[4] + Vector3(0, 0.02, 0), r[4].lerp(r[5], 0.7) + Vector3(0, 0.02, 0), 0.035, 4, P.SLATE[3])
	k.made.strut(r[5].lerp(r[6], 0.45) + Vector3(0, 0.02, 0), r[6] + Vector3(0, 0.02, 0), 0.035, 4, P.SLATE[3])
	_chimney(k, [-0.45, 0.35, -0.3][form], h - 0.2, [-d * 0.3, d * 0.32, -d * 0.05][form], [1.45, 1.3, 1.6][form], s + 10)
	# A room added on, one wall of it somebody else's, so the plan is never a
	# rectangle and no two houses keep the same footprint (art review 5).
	if form != 1:
		# On the SHORT wall of the two, so the added room stays inside the circle
		# the house is solid within: form 2 is 3.3 deep and only 2.7 across.
		outshot(k, t, 3 if form == 0 else 2, s + 70, c)
	turf_bank(k, t, s + 20, c)
	if dress.cold():
		_snow_on(k, r, dress.snow)


## "slated": a gable house of rubble; half its slates, the other half replaced
## in plate course by course.
static func slated(k: Kit, c: int, form: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 1500 + form * 41
	var w := 2.3 if form == 0 else 1.7
	var d := 3.2 if form == 0 else 3.55
	var h := 1.4 if form == 0 else 1.0
	# Warm grey rubble, a clear step lighter than the slate over it.
	var rubble: Color = P.STONE[3].lerp(P.SAND[3], 0.4) if form == 0 else P.STONE[3].lerp(P.LINEN[3], 0.35)
	var t := walls(k, w, d, h, s, rubble, GroundColors.down(rubble, 0.3), Vector3(-0.04, 0, 0.02) if form == 0 else Vector3(0.03, 0, -0.03))
	var moss := dress.growth
	for fi in faces(t).size():
		var wf: Array = faces(t)[fi]
		weathered(k, wf[0], wf[1], wf[2], wf[3], s + fi * 17, GroundColors.down(rubble, 0.4), moss)
	var fb := [t[2], t[1], t[5], t[6]]
	# Quoins lighter at the corners, a few dark stones in the courses.
	for i in 5:
		wall_rect(k.made, fb[0], fb[1], fb[2], fb[3], 0.0, i * 0.2, 0.08 + (i % 2) * 0.04, i * 0.2 + 0.16, 0.008, GroundColors.up(rubble, 0.35))
		wall_rect(k.made, fb[0], fb[1], fb[2], fb[3], 0.9 - (i % 2) * 0.04, i * 0.2 + 0.04, 1.0, i * 0.2 + 0.18, 0.008, GroundColors.up(rubble, 0.35))
	for i in 8:
		var u := 0.15 + fmod(i * 0.37, 0.7)
		var vv := 0.1 + fmod(i * 0.41, 0.8)
		wall_rect(k.made, fb[0], fb[1], fb[2], fb[3], u, vv, u + 0.06, vv + 0.07, 0.008, P.SLATE[2] if i % 2 else P.STONE[1])
	door(k, fb[0], fb[1], fb[2], fb[3], 0.64 if form == 0 else 0.3, 0.1, 0.95)
	if form == 0:
		neon_tube(k, fb[0], fb[1], fb[2], fb[3], 0.48, 0.8, 0.62, NEON_TUBES[1])
	window(k, fb[0], fb[1], fb[2], fb[3], 0.24 if form == 0 else 0.74, 0.6, 0.08, 0.13)
	struck_plate(k, fb[0], fb[1], fb[2], fb[3], 0.4 if form == 0 else 0.52, 0.42)
	var gb := [t[3], t[2], t[6], t[7]]
	boarded(k, gb[0], gb[1], gb[2], gb[3], 0.7 if form == 0 else 0.26, 0.56, 0.075, 0.12, s + 35)
	salvage(k, gb[0], gb[1], gb[2], gb[3], 0.26 if form == 0 else 0.72, s + 42)
	# Gable roof: every edge of it a wavering polyline and both slopes a
	# patchwork, because the roof is most of what a house IS on screen at the
	# play camera and one ruled corrugation across it put the house in the
	# machines' idiom (art review 5).
	var over := 0.2
	var yr := h + 1.05
	var cx := (t[4].x + t[5].x + t[6].x + t[7].x) * 0.25
	var ez := d * 0.5 + 0.14
	var ex := w * 0.5 + over
	# A ridge sags in screen pixels, not in world units: 0.07 was two pixels at
	# the play camera, under the inked ridge line that hides it.
	var sag := 0.19
	const N := 9
	var ridge := PackedVector3Array()
	for i in N + 1:
		var f := float(i) / N
		# It wanders across the house as well as sagging, so no length of it is
		# a ruled segment for the outline pass to find.
		ridge.append(Vector3(cx + Kit.j(s, i + 60, 0.085), yr - sag * sin(f * PI) - Kit.j(s, i + 70, 0.05), lerpf(-ez, ez, f)))
	# One bay of the front eave has given way; the rest is uneven anyway.
	var gave := 3 + int(Rng.hash01(s, 0, 77) * 4.0)
	var front := PackedVector3Array()
	var back := PackedVector3Array()
	for i in N + 1:
		var f := float(i) / N
		front.append(Vector3(cx + ex + Kit.j(s, i + 28, 0.1) + (0.08 if i == gave else 0.0),
			h - 0.05 - Kit.j(s, i + 18, 0.06) - (0.19 if i == gave else 0.0), lerpf(-ez, ez, f) + Kit.j(s, i + 8, 0.08)))
		back.append(Vector3(cx - ex - Kit.j(s, i + 48, 0.1),
			h - 0.05 - Kit.j(s, i + 38, 0.06), lerpf(-ez, ez, f) + Kit.j(s, i + 58, 0.08)))
	var back_rev := PackedVector3Array()
	var ridge_rev := PackedVector3Array()
	for i in N + 1:
		back_rev.append(back[N - i])
		ridge_rev.append(ridge[N - i])
	patch_slope(k, front, ridge, 4, s + 11, SLATE_ROOF, 0.13 if form == 0 else 0.15)
	if form == 0:
		neon_run(k, front, ridge, 0.09, NEON_TUBES[1])
	patch_slope(k, back_rev, ridge_rev, 4, s + 17, SLATE_ROOF, 0.10)
	# Wound to face UP: the camera is always above, so this plane read downward
	# was culled from every bearing and the shadow under the eaves was absent
	# rather than dark. See the hipped roof's own eave plane for the same fix.
	k.made.quad(Vector3(cx - ex, h - 0.05, ez), Vector3(cx + ex, h - 0.05, ez), Vector3(cx + ex, h - 0.05, -ez), Vector3(cx - ex, h - 0.05, -ez), P.INK[2])
	# Gable ends in stone, up to the ridge where it actually lands.
	k.made.tri(t[7] + Vector3(0, 0, 0.004), t[6] + Vector3(0, 0, 0.004), ridge[N] - Vector3(0, 0.06, 0.1), GroundColors.down(rubble, 0.3))
	k.made.tri(t[5] + Vector3(0, 0, -0.004), t[4] + Vector3(0, 0, -0.004), ridge[0] - Vector3(0, 0.06, -0.1), GroundColors.down(rubble, 0.5))
	# The ridge, lighter than the eaves, and gone for a length in the middle
	# where the capping blew off: the roofline is never one straight run.
	for i in N:
		if i == 4 or i == 5:
			continue
		k.made.strut(ridge[i] + Vector3(0, 0.03, 0), ridge[i + 1] + Vector3(0, 0.03, 0), 0.04, 4, P.SLATE[4])
	# One silhouette break: a sheet of plate laid over a hole at the eave, cut to
	# the hole and not to the roof, so it hangs past the line (art review 5).
	#
	# DOWN past the eave, not a third of the way up the roof. Reaching to 0.58 of
	# the slope it lay flat over the eave courses, which are exactly where the
	# roof's own plate patches are laid now (PLATE_ROWS), so on two of these
	# houses the big sheet and a patch under it hid each other from every bearing
	# (tests/render/test_found_drawn.gd). Bent down over the eave it breaks the
	# roofline downward — the line this camera reads a house by — and it cannot
	# cover the roof at all.
	var oz := ez * (0.2 if form == 0 else -0.2)
	var eave := Vector3(cx + ex, h - 0.05, oz)
	var over_a := eave + Vector3(0.30, -0.44, -0.34)
	var over_b := eave + Vector3(0.26, -0.40, 0.36)
	var up_a := eave + Vector3(-0.04, 0.07, -0.3)
	var up_b := eave + Vector3(-0.06, 0.09, 0.32)
	k.plate(over_b, over_a, up_a, up_b, P.PLATE[3], P.PLATE[1], P.PLATE[4])
	_chimney(k, cx + 0.05, yr - 0.55, (d * 0.5 - 0.24) * (1.0 if form == 0 else -1.0), 1.0, s + 10)
	if form == 1:
		# Under the eave, never on the door wall: at 1.7 wide this house's room
		# spanned the door it was supposed to be reached through.
		outshot(k, t, 2, s + 70, c)
	turf_bank(k, t, s + 20, c)
	if dress.cold():
		# Snow over the upper half of both slopes, the eave courses left dark: it
		# reached 0.85 of the way down to the eave, which put it over every plate
		# patch on the roof (see PLATE_ROWS).
		var sl := Vector3(0, 0.05, 0)
		var sf := 1.0 - PLATE_ROWS - 0.06
		var sy := lerpf(h, yr, 1.0 - sf - 0.02)
		k.made.quad(Vector3(cx + ex * sf, sy, ez) + sl, Vector3(cx + ex * sf, sy, -ez) + sl, Vector3(cx, yr - sag, -ez * 0.2) + sl, Vector3(cx, yr - sag, ez * 0.2) + sl, dress.snow[0])
		k.made.tri(Vector3(cx + ex * sf, sy, ez) + sl, Vector3(cx, yr - sag, ez * 0.2) + sl, Vector3(cx, yr, ez) + sl, dress.snow[0])
		k.made.tri(Vector3(cx, yr - sag, -ez * 0.2) + sl, Vector3(cx + ex * sf, sy, -ez) + sl, Vector3(cx, yr, -ez) + sl, dress.snow[0])
		k.made.quad(Vector3(cx - ex * sf, sy, -ez) + sl, Vector3(cx - ex * sf, sy, ez) + sl, Vector3(cx, yr - sag, ez * 0.2) + sl, Vector3(cx, yr - sag, -ez * 0.2) + sl, dress.snow[1])


## "long": a low stone house under deep thatch roped down with cable and
## weighted with cast discs, built against the foot of a lattice pylon.
static func long_house(k: Kit, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 1600
	var w := 2.0
	var d := 3.4
	var h := 0.95
	k.made.push(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.2)))
	var t := walls(k, w, d, h, s, P.STONE[2], GroundColors.down(P.STONE[2], 0.25), Vector3(0.03, 0, 0.0))
	k.made.pop()
	for i in t.size():
		t[i] += Vector3(0, 0, 0.2)
	var fb := [t[2], t[1], t[5], t[6]]
	door(k, fb[0], fb[1], fb[2], fb[3], 0.26, 0.1, 0.82)
	window(k, fb[0], fb[1], fb[2], fb[3], 0.68, 0.55, 0.07, 0.12)
	struck_plate(k, fb[0], fb[1], fb[2], fb[3], 0.48, 0.45)
	var lb := [t[3], t[2], t[6], t[7]]
	salvage(k, lb[0], lb[1], lb[2], lb[3], 0.3, s + 43)
	# Thatch: a deep, soft hip with a ragged eave. No plate on it — this roof was
	# re-laid by hand and roped down, which is why the cables are the drawing.
	var r := hipped(k, t, 0.36, 1.25, d * 0.3, 0.26, s + 60, THATCH_ROOF, 0.0, P.EARTH[3].lerp(P.SAND[3], 0.4), 2, 0.17)
	for i in 10:
		var f := (i + 0.5) / 10.0
		var a := r[1].lerp(r[2], f)
		var drop := 0.06 + fmod(i * 0.37, 0.09)
		k.made.tri(a + Vector3(0.02, -drop * 0.3, 0.17), a + Vector3(0.02, -drop, -0.17), a + Vector3(-0.14, 0.16, 0.0), P.EARTH[2] if i % 2 else P.SAND[3])
	for f: float in [0.35, 0.62]:
		var a := r[1].lerp(r[4], f) + Vector3(0.02, 0.02, 0)
		var b := r[2].lerp(r[6], f) + Vector3(0.02, 0.02, 0)
		k.made.quad(b, a, a + Vector3(-0.08, 0.06, 0), b + Vector3(-0.08, 0.06, 0), P.EARTH[2])
	# Cables over the ridge, a cast disc hanging at each end (FOUND).
	for i in 4:
		var f := 0.15 + i * 0.23
		var eave_f := r[1].lerp(r[2], f)
		var eave_b := r[0].lerp(r[3], f)
		var ridge := r[4].lerp(r[6], f) + Vector3(0, 0.04, 0)
		k.cable(eave_f + Vector3(0.05, 0.05, 0), ridge, -0.04, 3, 0.011, P.INK[2])
		k.cable(ridge, eave_b + Vector3(-0.05, 0.05, 0), -0.04, 3, 0.011, P.INK[2])
		for side: Vector3 in [eave_f + Vector3(0.06, 0.0, 0), eave_b + Vector3(-0.06, 0.0, 0)]:
			k.rod(side, side + Vector3(0, -0.3, 0), 0.01, 3, P.INK[2])
			k.found.push(Transform3D(Basis(Vector3.BACK, PI * 0.5), side + Vector3(0, -0.36, 0)))
			k.found.prism(0, -0.025, 0, 0.1, 0.025, 0.1, 10, P.STONE[3], P.STONE[4])
			k.found.pop()
	# The pylon foot it leans on: exact lattice, cut off above the roof.
	var pz := -d * 0.5 - 0.3
	var legs: Array[Vector2] = [Vector2(-0.46, pz - 0.46), Vector2(0.46, pz - 0.46), Vector2(0.46, pz + 0.46), Vector2(-0.46, pz + 0.46)]
	for i in 4:
		var l := legs[i]
		var n := legs[(i + 1) % 4]
		var lt := Vector3(l.x * 0.72, 2.7, pz + (l.y - pz) * 0.72)
		k.rod(Vector3(l.x, 0, l.y), lt, 0.04, 4, P.PLATE[3])
		for yy: float in [0.9, 1.8, 2.7]:
			var f := 1.0 - yy / 2.7 * 0.28
			k.rod(Vector3(l.x * f, yy, pz + (l.y - pz) * f), Vector3(n.x * f, yy, pz + (n.y - pz) * f), 0.022, 4, P.PLATE[2])
		k.rod(Vector3(l.x, 0.05, l.y), Vector3(n.x * 0.9, 0.9, pz + (n.y - pz) * 0.9), 0.016, 4, P.PLATE[2])
		k.chamfer(l.x, -0.04, l.y, 0.2, 0.14, 0.2, 0.04, P.STONE[2], P.STONE[3])
	turf_bank(k, t, s + 20, c)
	if dress.cold():
		_snow_on(k, r, dress.snow)


## "half": a house whose far end came down and was never rebuilt. What is left
## is lived in: the break is closed with boards and plate, the fallen end is a
## spill of its own stone with grass in it, and the roof over the standing half
## falls one way only. A shape no other house in a village can be mistaken for.
static func half_house(k: Kit, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 1800
	var w := 2.0
	var d := 2.2
	var h := 1.25
	var rubble := P.STONE[3].lerp(P.SAND[3], 0.25)
	var t := walls(k, w, d, h, s, rubble, GroundColors.down(rubble, 0.3), Vector3(0.06, 0.0, -0.05))
	var moss := dress.growth
	for fi in faces(t).size():
		var wf: Array = faces(t)[fi]
		weathered(k, wf[0], wf[1], wf[2], wf[3], s + fi * 19, GroundColors.down(rubble, 0.4), moss)
	var fb := [t[2], t[1], t[5], t[6]]
	door(k, fb[0], fb[1], fb[2], fb[3], 0.6, 0.1, 0.9)
	window(k, fb[0], fb[1], fb[2], fb[3], 0.22, 0.58, 0.075, 0.12)
	struck_plate(k, fb[0], fb[1], fb[2], fb[3], 0.86, 0.4)
	var sb := [t[3], t[2], t[6], t[7]]
	salvage(k, sb[0], sb[1], sb[2], sb[3], 0.6, s + 41)
	# The end wall the house lost, closed with whatever was to hand: boards up to
	# head height, plate over the gable, a strut holding the whole thing off the
	# ground. The join IS the drawing (ART §12).
	var xb: Array[Vector3] = [t[1], t[0], t[4], t[5]]
	for i in 5:
		var v0 := i * 0.19
		wall_rect(k.made, xb[0], xb[1], xb[2], xb[3], Kit.j(s, i, 0.05), v0, 1.0 + Kit.j(s, i + 9, 0.05), v0 + 0.19,
			0.02 + 0.004 * i, P.EARTH[2] if i % 2 else P.EARTH[1])
	var gap := on_wall(xb[0], xb[1], xb[2], xb[3], 0.5, 0.0, 0.0)
	var gout := wall_out(xb[0], xb[1], xb[2], xb[3])
	var along := (xb[1] - xb[0]).normalized()
	k.plate(gap + along * 0.5 + gout * 0.05, gap - along * 0.5 + gout * 0.05,
		gap - along * 0.42 + gout * 0.05 + Vector3(0, h + 0.5, 0), gap + along * 0.46 + gout * 0.05 + Vector3(0, h + 0.42, 0),
		P.PLATE[2], P.PLATE[1], P.PLATE[4])
	k.limb(gap + along * 0.3 + gout * 0.7, gap + along * 0.22 + gout * 0.08 + Vector3(0, h * 0.8, 0), 0.05, 0.035, 4, P.EARTH[1])
	k.limb(gap - along * 0.34 + gout * 0.66, gap - along * 0.26 + gout * 0.08 + Vector3(0, h * 0.72, 0), 0.05, 0.035, 4, P.EARTH[2])
	# One fall of roof, from a high eave on the standing side to a low one.
	const N := 7
	var high := PackedVector3Array()
	var low := PackedVector3Array()
	for i in N + 1:
		var f := float(i) / N
		var z := lerpf(-d * 0.5 - 0.16, d * 0.5 + 0.16, f)
		high.append(Vector3(-w * 0.5 - 0.22 + Kit.j(s, i + 20, 0.08), h + 0.86 - Kit.j(s, i + 30, 0.07) - 0.16 * sin(f * PI), z + Kit.j(s, i + 40, 0.07)))
		low.append(Vector3(w * 0.5 + 0.26 + Kit.j(s, i + 50, 0.1), h - 0.02 - Kit.j(s, i + 60, 0.07) - (0.2 if i == 3 else 0.0), z + Kit.j(s, i + 70, 0.07)))
	patch_slope(k, low, high, 4, s + 11, SLATE_ROOF, 0.26)
	# The dark under the low eave: a hand's width of soffit, not a second roof
	# plane hanging below the first.
	k.made.quad(Vector3(w * 0.5 + 0.26, h - 0.06, -d * 0.5 - 0.16), Vector3(w * 0.5 + 0.26, h - 0.06, d * 0.5 + 0.16),
		Vector3(w * 0.5 - 0.06, h + 0.04, d * 0.5 + 0.16), Vector3(w * 0.5 - 0.06, h + 0.04, -d * 0.5 - 0.16), P.INK[2])
	# The gable the fall stands on, and the wall under the high side.
	for zz: float in [-d * 0.5, d * 0.5]:
		var sgn := signf(zz)
		k.made.tri(Vector3(-w * 0.5, h - 0.1, zz), Vector3(w * 0.5, h - 0.1, zz), Vector3(-w * 0.5 - 0.06, h + 0.74, zz),
			GroundColors.down(rubble, 0.25 + 0.2 * maxf(0.0, sgn)))
	_chimney(k, -w * 0.5 + 0.18, h + 0.45, -d * 0.22, 0.95, s + 10)
	# What came down, lying where it fell with grass through it.
	var gs := k.made.vertex_count()
	_spill(k, Vector2(-1.55, 0.2), Vector2(1.1, 1.5), 9, s + 80, [rubble, P.SLATE[2], P.STONE[2], P.SLATE[3]])
	for i in 5:
		var p := Vector2(-1.5 + Kit.j(s, i + 90, 0.5), Kit.j(s, i + 95, 0.8))
		k.clump(p.x, -0.05, p.y, 0.16, 0.2, s + 100 + i, moss if i % 2 else P.MOSS[3], 6)
	k.sway_by_height(gs, 0.0, 0.2, 0.2)
	turf_bank(k, t, s + 20, c)
	if dress.cold():
		k.made.quad(Vector3(-w * 0.5 - 0.2, h + 0.78, -d * 0.5), Vector3(0.1, h + 0.4, -d * 0.5),
			Vector3(0.1, h + 0.4, d * 0.5), Vector3(-w * 0.5 - 0.2, h + 0.78, d * 0.5), dress.snow[0])


## "but": a machine housing lived in. The housing is FOUND and exact: rounded
## shoulders, riveted ribs, a bullnose lid, the original hatch. Everything the
## people did to it is MADE: sods along the lid, a stone chimney through it, a
## plank door in the burnt-through hole, bars across the hatch.
static func but(k: Kit, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var w := 2.1
	var d := 2.6
	var h := 1.15
	# Weathered: a housing that has stood in the rain for years, not a live machine.
	var plate := P.PLATE[2]
	var lit := P.PLATE[3]
	var dark := P.PLATE[1]
	k.chamfer(0, 0, 0, w, h, d, 0.24, plate, lit)
	# The bullnose lid.
	k.chamfer(0, h - 0.02, 0, w - 0.3, 0.28, d - 0.3, 0.3, plate, lit)
	# Ribs and rivet rows, exact, on both seen faces.
	for rz: float in [-0.46, 0.46]:
		k.chamfer(w * 0.5 + 0.02, 0.0, rz, 0.05, h - 0.1, 0.09, 0.015, dark, plate)
		for i in 5:
			k.found.quad(Vector3(w * 0.5 + 0.048, 0.12 + i * 0.2, rz + 0.016), Vector3(w * 0.5 + 0.048, 0.12 + i * 0.2, rz - 0.016), Vector3(w * 0.5 + 0.048, 0.15 + i * 0.2, rz - 0.016), Vector3(w * 0.5 + 0.048, 0.15 + i * 0.2, rz + 0.016), P.PLATE[5])
	for rx: float in [-0.36, 0.36]:
		k.chamfer(rx, 0.0, d * 0.5 + 0.02, 0.09, h - 0.1, 0.05, 0.015, dark, plate)
	# Rust bleeding down from a rib.
	k.made.quad(Vector3(w * 0.5 + 0.05, 0.05, 0.52), Vector3(w * 0.5 + 0.05, 0.05, 0.4), Vector3(w * 0.5 + 0.05, 0.9, 0.44), Vector3(w * 0.5 + 0.05, 0.9, 0.48), P.RUST[3])
	var fx := w * 0.5 + 0.004
	# The door burnt through, a plank door hung in the hole (MADE).
	var hole: Array[Vector3] = [Vector3(fx, 0.02, -0.04), Vector3(fx, 0.02, -0.54), Vector3(fx, 0.5, -0.58), Vector3(fx, 0.92, -0.52), Vector3(fx, 1.0, -0.3), Vector3(fx, 0.95, -0.06), Vector3(fx, 0.55, 0.0)]
	var centre := Vector3(fx, 0.5, -0.28)
	for i in hole.size():
		k.made.tri(centre, hole[i], hole[(i + 1) % hole.size()], P.RUST[1])
	var fbl := Vector3(fx + 0.004, 0.0, 0.2)
	var fbr := Vector3(fx + 0.004, 0.0, -0.8)
	door(k, fbl, fbr, fbr + Vector3(0, 1.0, 0), fbl + Vector3(0, 1.0, 0), 0.48, 0.09, 0.86)
	window(k, Vector3(fx, 0, 1.2), Vector3(fx, 0, 0.3), Vector3(fx, 1, 0.3), Vector3(fx, 1, 1.2), 0.5, 0.62, 0.1, 0.14)
	# The original hatch, barred from outside.
	var fz := d * 0.5 + 0.004
	k.found.quad(Vector3(0.28, 0.28, fz), Vector3(0.9, 0.28, fz), Vector3(0.9, 0.9, fz), Vector3(0.28, 0.9, fz), P.PLATE[1])
	k.found.quad(Vector3(0.32, 0.32, fz + 0.004), Vector3(0.86, 0.32, fz + 0.004), Vector3(0.86, 0.86, fz + 0.004), Vector3(0.32, 0.86, fz + 0.004), dark)
	k.slab(0.6, 0.58, fz + 0.04, 0.86, 0.08, 0.04, 1330, P.EARTH[2], P.EARTH[3], 0.01, 0.0, 0.0)
	k.slab(0.58, 0.42, fz + 0.045, 0.8, 0.07, 0.04, 1331, P.EARTH[1], P.EARTH[2], 0.01)
	# A louvred vent and a junction box.
	for i in 4:
		k.chamfer(-0.55, 0.44 + i * 0.09, fz + 0.02, 0.4, 0.03, 0.04, 0.008, dark, lit)
	k.chamfer(-0.2, 0.72, fz + 0.04, 0.16, 0.2, 0.08, 0.02, dark, plate)
	var sb := [Vector3(fx, 0, d * 0.5), Vector3(fx, 0, -d * 0.5), Vector3(fx, 1, -d * 0.5), Vector3(fx, 1, d * 0.5)]
	struck_plate(k, sb[0], sb[1], sb[2], sb[3], 0.25, 0.3)
	# Even a machine's housing gets what the people who live in it drag home.
	var xb: Array[Vector3] = [Vector3(-w * 0.5 - 0.004, 0, -d * 0.5), Vector3(-w * 0.5 - 0.004, 0, d * 0.5),
		Vector3(-w * 0.5 - 0.004, 1, d * 0.5), Vector3(-w * 0.5 - 0.004, 1, -d * 0.5)]
	salvage(k, xb[0], xb[1], xb[2], xb[3], 0.62, 1340)
	# Sods laid along the lid, uneven, and cut from the ground they stand on:
	# coast moss on the Bonelands read as a stripe of paint on a grey landscape.
	var sods: Array[Color] = [dress.turf[0], dress.turf[3]]
	var top := h + 0.26
	for i in 5:
		var z := -d * 0.5 + 0.42 + i * 0.44
		k.slab(Kit.j(1301, i, 0.08), top, z, w - 0.7, 0.1, 0.42, 1300 + i, P.EARTH[2], sods[i % 2], 0.03)
	# A stone chimney built by hand through the lid.
	_chimney(k, -0.55, top - 0.2, -0.8, 0.95, 1310)
	var foot: Array[Vector3] = [Vector3(-w * 0.5, 0, -d * 0.5), Vector3(w * 0.5, 0, -d * 0.5), Vector3(w * 0.5, 0, d * 0.5), Vector3(-w * 0.5, 0, d * 0.5)]
	turf_bank(k, foot, 1320, c)
	if dress.cold():
		# Snow lying on each sod and drifted against the chimney, the lid's
		# ruled edge left showing where the wind cleared it.
		for i in 5:
			var z := -d * 0.5 + 0.42 + i * 0.44
			var x := Kit.j(1301, i, 0.08)
			k.clump(x - 0.1 + fmod(i * 0.37, 0.2), top + 0.05, z, (w - 0.8) * 0.5, 0.12 + fmod(i * 0.13, 0.05), 1350 + i, dress.snow[0], 7)
			k.clump(x + 0.35 - fmod(i * 0.23, 0.2), top + 0.05, z + 0.08, 0.2, 0.1, 1370 + i, dress.snow[1], 6)
		k.clump(-0.4, top + 0.05, -0.62, 0.26, 0.2, 1360, dress.snow[0], 7)
		k.clump(w * 0.5 - 0.1, -0.04, -0.9, 0.34, 0.3, 1361, dress.snow[0], 7)


## A plate taken off a machine, laid on a front roof slope (e10, e11, r1, r0)
## between slope coordinates (u along the eave, v up the slope).
static func _patch(k: Kit, e10: Vector3, e11: Vector3, r1: Vector3, r0: Vector3, u0: float, v0: float, u1: float, v1: float) -> void:
	var lift := Vector3(0.012, 0.02, 0)
	var a := e10.lerp(e11, u0).lerp(r0.lerp(r1, u0), v0) + lift
	var b := e10.lerp(e11, u1).lerp(r0.lerp(r1, u1), v0) + lift
	var c := e10.lerp(e11, u1).lerp(r0.lerp(r1, u1), v1) + lift
	var d := e10.lerp(e11, u0).lerp(r0.lerp(r1, u0), v1) + lift
	k.plate(b, a, d, c, P.PLATE[2], P.PLATE[1], P.PLATE[4])


## A chimney built by hand: battered, off true, a cap stone on it.
static func _chimney(k: Kit, x: float, y0: float, z: float, h: float, seed_value: int) -> void:
	k.slab(x, y0, z, 0.36, h, 0.38, seed_value, P.STONE[2], P.STONE[1], 0.035, 0.2, Kit.j(seed_value, 1, 0.07))
	var lean := Kit.j(seed_value, 1, 0.07) * h
	k.slab(x + lean, y0 + h - 0.01, z, 0.36, 0.07, 0.38, seed_value + 1, P.STONE[3], P.STONE[3], 0.02)


## Snow lying on the upper slopes of a hipped roof. It starts where `PLATE_ROWS`
## stops, so the courses that carry plate are the courses the snow slid off.
static func _snow_on(k: Kit, r: Array[Vector3], snow: Array[Color]) -> void:
	var lift := Vector3(0, 0.05, 0)
	var f := PLATE_ROWS + 0.06
	k.made.tri(r[2].lerp(r[6], f) + lift, r[1].lerp(r[4], f) + lift, r[5] + lift, snow[0])
	k.made.tri(r[6] + lift, r[2].lerp(r[6], f) + lift, r[5] + lift, snow[0])
	k.made.tri(r[5] + lift, r[1].lerp(r[4], f) + lift, r[4] + lift, snow[0])
	k.made.tri(r[0].lerp(r[4], f) + lift, r[3].lerp(r[6], f) + lift, r[5] + lift, snow[1])
	k.made.tri(r[4] + lift, r[0].lerp(r[4], f) + lift, r[5] + lift, snow[1])
	k.made.tri(r[5] + lift, r[3].lerp(r[6], f) + lift, r[6] + lift, snow[1])


## A ruin: drystone walls fallen to uneven heights, never a stack of blocks.
## Each wall is one battered mass with a broken top, faced in courses of
## uneven stones, coping lumps along what is left of the top, and the stones
## that fell lying in a spill at its foot, grassed over.
static func ruin(k: Kit, v: int, c: int) -> void:
	# The stone people build a wall out of here (BiomeDressing.walling).
	var stone := BiomeDressing.of(c).walling
	var s := 1700 + v * 31
	match v % 3:
		0:
			# The corner of a house: two walls highest where they meet.
			rubble_wall(k, Vector2(-1.0, -0.6), Vector2(1.1, -0.7), _broken([1.35, 1.2, 0.8, 0.9, 0.35, 0.2], s, 0.1), 0.34, s, stone)
			rubble_wall(k, Vector2(-1.0, -0.43), Vector2(-0.9, 0.95), _broken([1.3, 1.0, 0.55, 0.25, 0.3], s + 1, 0.08), 0.34, s + 1, stone)
			_spill(k, Vector2(0.2, -0.2), Vector2(0.9, 0.35), 9, s + 2, stone)
			_spill(k, Vector2(-0.55, 0.4), Vector2(0.3, 0.3), 5, s + 3, stone)
		1:
			# A gable end standing alone, its window open to the sky.
			var tops := _broken([0.55, 0.9, 1.5, 1.95, 1.5, 1.0, 0.8], s, 0.06)
			tops[1] = 0.5
			rubble_wall(k, Vector2(-1.0, 0.0), Vector2(1.0, 0.05), tops, 0.36, s, stone)
			var hole := [Vector2(-0.12, 0.72), Vector2(0.18, 0.72), Vector2(0.2, 1.08), Vector2(0.04, 1.2), Vector2(-0.12, 1.08)]
			for side: float in [1.0, -1.0]:
				var ring := PackedVector3Array()
				for q: Vector2 in hole:
					ring.append(Vector3(q.x, q.y, 0.025 + side * 0.19 - q.y * 0.04 * side))
				for i in range(1, ring.size() - 1):
					if side > 0.0:
						k.made.tri(ring[0], ring[i], ring[i + 1], P.INK[1])
					else:
						k.made.tri(ring[0], ring[i + 1], ring[i], P.INK[1])
			# The lintel fell and lies across the spill.
			k.slab(0.35, 0.02, 0.62, 0.62, 0.12, 0.16, s + 7, stone[2], GroundColors.up(stone[2], 0.2), 0.02, 0.1, 0.0)
			_spill(k, Vector2(-0.3, 0.5), Vector2(1.0, 0.4), 10, s + 2, stone)
			_spill(k, Vector2(0.2, -0.55), Vector2(0.8, 0.3), 5, s + 3, stone)
		_:
			# Footings of a long house, knee high, a doorway gap, the chimney
			# stack still standing at the gable.
			rubble_wall(k, Vector2(-1.2, -0.75), Vector2(1.1, -0.8), _broken([0.55, 0.4, 0.5, 0.3, 0.45], s, 0.08), 0.3, s, stone)
			rubble_wall(k, Vector2(1.1, -0.8), Vector2(1.15, 0.85), _broken([0.45, 0.3, 0.15, 0.35], s + 1, 0.06), 0.3, s + 1, stone)
			rubble_wall(k, Vector2(1.15, 0.85), Vector2(0.15, 0.8), _broken([0.4, 0.5, 0.25], s + 2, 0.06), 0.3, s + 2, stone)
			rubble_wall(k, Vector2(-0.45, 0.8), Vector2(-1.2, 0.78), _broken([0.3, 0.55], s + 3, 0.05), 0.3, s + 3, stone)
			rubble_wall(k, Vector2(-1.2, 0.95), Vector2(-1.2, -0.9), _broken([1.6, 1.7, 1.05, 0.5, 0.45], s + 4, 0.05), 0.36, s + 4, stone)
			_spill(k, Vector2(-0.6, 0.0), Vector2(0.5, 0.5), 7, s + 5, stone)
			_spill(k, Vector2(0.4, 1.1), Vector2(0.6, 0.2), 4, s + 6, stone)
	# Grass took the floor and the foot of every wall.
	var gs := k.made.vertex_count()
	for i in 7:
		var p := Vector2(-0.9 + i * 0.3 + Kit.j(s, 900 + i, 0.1), Kit.j(s, 920 + i, 0.6))
		k.clump(p.x, -0.04, p.y, 0.14 + Kit.j(s, 940 + i, 0.04), 0.16, s + 900 + i, P.MOSS[2] if i % 2 else P.MOSS[3], 6)
	k.sway_by_height(gs, 0.0, 0.18, 0.2)


## Heights at even steps along a wall from a few control heights: jagged by
## `jag`, with a gap bitten out of the top here and there.
static func _broken(ctrl: Array, seed_value: int, jag: float) -> PackedFloat32Array:
	var n := (ctrl.size() - 1) * 3
	var out := PackedFloat32Array()
	for i in n + 1:
		var f := float(i) / 3.0
		var a := mini(floori(f), ctrl.size() - 2)
		var h := lerpf(float(ctrl[a]), float(ctrl[a + 1]), f - a)
		h += Kit.j(seed_value, i + 300, jag)
		if Rng.hash01(seed_value, i, 301) < 0.18:
			h *= 0.7
		out.append(maxf(0.12, h))
	return out


## A drystone wall from a to b (plan x, z), its top at `tops` (even steps
## along it). Battered: its faces lean in as they rise. Faced in courses of
## uneven stones, each drawn a hair proud of a darker mass, and lumpy coping
## stones along the broken top.
static func rubble_wall(k: Kit, a: Vector2, b: Vector2, tops: PackedFloat32Array, thick: float, seed_value: int, stones: Array[Color]) -> void:
	var n := tops.size() - 1
	var run := b - a
	var length := run.length()
	var dir := run / length
	var nrm := Vector2(-dir.y, dir.x)
	var d3 := Vector3(dir.x, 0, dir.y)
	var n3 := Vector3(nrm.x, 0, nrm.y)
	var mass := GroundColors.down(stones[0], 0.4)
	const BATTER := 0.07
	var pen := k.made
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var p0 := a.lerp(b, t0)
		var p1 := a.lerp(b, t1)
		var h0 := tops[i]
		var h1 := tops[i + 1]
		var base := Vector3(0, -0.04, 0)
		var q0 := Vector3(p0.x, 0, p0.y)
		var q1 := Vector3(p1.x, 0, p1.y)
		var o0 := thick * 0.5 - BATTER * h0
		var o1 := thick * 0.5 - BATTER * h1
		var ab0 := q0 + n3 * thick * 0.5 + base
		var ab1 := q1 + n3 * thick * 0.5 + base
		var bb0 := q0 - n3 * thick * 0.5 + base
		var bb1 := q1 - n3 * thick * 0.5 + base
		var at0 := q0 + n3 * o0 + Vector3(0, h0, 0)
		var at1 := q1 + n3 * o1 + Vector3(0, h1, 0)
		var bt0 := q0 - n3 * o0 + Vector3(0, h0, 0)
		var bt1 := q1 - n3 * o1 + Vector3(0, h1, 0)
		pen.quad(ab0, ab1, at1, at0, mass)
		pen.quad(bb1, bb0, bt0, bt1, GroundColors.down(mass, 0.1))
		pen.quad(at0, at1, bt1, bt0, GroundColors.down(stones[1], 0.3))
		if i == 0:
			pen.quad(bb0, ab0, at0, bt0, GroundColors.down(mass, 0.05))
		if i == n - 1:
			pen.quad(ab1, bb1, bt1, at1, mass)
	# Courses of stone on both faces.
	var idx := 0
	for side: float in [1.0, -1.0]:
		var y := 0.0
		var course := 0
		while y < 2.2:
			var ch := 0.1 + Rng.hash01(seed_value, course, 11) * 0.12
			var u := -Rng.hash01(seed_value, course, 12) * 0.2
			while u < length:
				var sl := 0.12 + Rng.hash01(seed_value, idx, 13) * 0.3
				var u0 := maxf(u, 0.0) + 0.012
				var u1 := minf(u + sl, length) - 0.012
				u += sl
				idx += 1
				if u1 - u0 < 0.06:
					continue
				var top_here := minf(_top_at(tops, u0 / length), _top_at(tops, u1 / length)) - 0.025
				var y0 := y + 0.012
				var y1 := minf(y + ch - 0.012, top_here)
				if y1 - y0 < 0.05:
					continue
				var col := stones[int(Rng.hash01(seed_value, idx, 14) * 4.0) % 4].lerp(stones[0], 0.35)
				col = Kit.tone(col, 0.86 + Rng.hash01(seed_value, idx, 15) * 0.18)
				# A stone is a rough hexagon: corners knocked off, sides not true.
				var jx := Kit.j(seed_value, idx + 40, 0.02)
				var jy := Kit.j(seed_value, idx + 60, 0.015)
				var ym := (y0 + y1) * 0.5 + jy
				var ring: Array[Vector2] = [Vector2(u0 + 0.03, y0), Vector2(u1 - 0.02 + jx, y0 + 0.01), Vector2(u1, ym),
					Vector2(u1 - 0.03, y1), Vector2(u0 + 0.02 - jx, y1 - 0.01), Vector2(u0, ym - jy * 2.0)]
				var pts := PackedVector3Array()
				for r: Vector2 in ring:
					var off := thick * 0.5 - BATTER * r.y + 0.012
					var plan := a + dir * r.x + nrm * off * side
					pts.append(Vector3(plan.x, r.y - 0.04, plan.y))
				for e in range(1, 5):
					if side > 0.0:
						pen.tri(pts[0], pts[e], pts[e + 1], col)
					else:
						pen.tri(pts[0], pts[e + 1], pts[e], GroundColors.down(col, 0.08))
			y += ch
			course += 1
	# Coping: loose lumps along what is left of the top.
	var steps := int(length / 0.24)
	for i in steps:
		var t := (i + 0.5) / steps
		var h := _top_at(tops, t)
		if h < 0.22 or Rng.hash01(seed_value, i, 16) < 0.25:
			continue
		var p := a.lerp(b, t) + nrm * Kit.j(seed_value, i + 80, 0.05)
		k.stone(p.x, h - 0.05, p.y, thick * 0.42, 0.1 + Rng.hash01(seed_value, i, 17) * 0.06, seed_value + 200 + i, stones[(i + 2) % 4].lerp(stones[0], 0.4), 5, Kit.j(seed_value, i + 90, 0.3))


static func _top_at(tops: PackedFloat32Array, t: float) -> float:
	var f := clampf(t, 0.0, 1.0) * (tops.size() - 1)
	var i := mini(floori(f), tops.size() - 2)
	return lerpf(tops[i], tops[i + 1], f - i)


## Stones that fell, lying where they landed in a spill round `centre`
## (spread `size`), tipped and half sunk, a few big ones and many small.
static func _spill(k: Kit, centre: Vector2, size: Vector2, count: int, seed_value: int, stones: Array[Color]) -> void:
	for i in count:
		var p := centre + Vector2(Kit.j(seed_value, i, size.x * 0.5), Kit.j(seed_value, i + 20, size.y * 0.5))
		var big := Rng.hash01(seed_value, i, 3) < 0.35
		var r := (0.13 if big else 0.07) + Rng.hash01(seed_value, i, 4) * 0.05
		var col := stones[i % 4]
		if big and i % 3 == 0:
			k.made.push(Transform3D(Basis(Vector3.UP, Rng.hash01(seed_value, i, 5) * TAU) * Basis(Vector3.BACK, Kit.j(seed_value, i + 40, 0.35)), Vector3(p.x, -0.03, p.y)))
			k.slab(0, 0, 0, r * 2.6, r * 0.9, r * 1.5, seed_value + i, col, GroundColors.up(col, 0.15), 0.02, 0.15, 0.0)
			k.made.pop()
		else:
			k.stone(p.x, -0.05, p.y, r, r * (0.9 + Rng.hash01(seed_value, i, 6) * 0.6), seed_value + i * 3, col, 5, Kit.j(seed_value, i + 60, 0.4))
