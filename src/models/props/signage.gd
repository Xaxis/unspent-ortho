extends RefCounted
## The Slums' two kinds of picture, and the whole landscape is the argument
## between them.
##
## A MURAL is painted by hand, on a wall, by people, generations ago. It is MADE:
## matte pigment, no light of its own, lit by whatever happens to be around, and
## worn by the land like every other made thing (`matter_worn` reads world
## position, so one mural weathers differently at the two ends of a street).
##
## A BILLBOARD is projected. It is FOUND: a metal rig, and a face that is LIGHT
## rather than paint -- immense, in motion, and bright enough to lay the street
## and the standing water under it in its own colour.
##
## They are built in one file because the landscape's one image is the two of
## them TOUCHING: a mural half-covered by a billboard that is still cheerfully
## selling something. Nobody cleaned the mural off; nobody defended it either.
## MURAL variants 2 and 3 ARE that picture, so it cannot be lost by a placer
## putting the two kinds in different streets -- it is one prop, and the frame
## the landscape exists for can always be taken.
##
## WHY THE COLOURS ARE WHAT THEY ARE. The machines own the violet band (hue
## 240-336) and the amber LENS, and that contract is what lets a player pick the
## one machine out of the most crowded frame in the game at a glance. So the
## Slums is lit by what a real city is lit by and the machines are not: SODIUM
## orange on the street, MERCURY green on whatever stopped being maintained, and
## a dirty warm white on the advertising, which wants to look clean and does not
## quite manage it through the haze. Nothing here goes near the violet band, and
## the purple-to-teal gradient every other lit city in games is made of is
## absent on purpose.
##
## Models face +X, so a panel's face looks down +X and its light hangs in front
## of it. Props turn by `-rot`.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
const Remains := preload("res://src/models/props/remains.gd")
const Works := preload("res://src/models/props/works.gd")

## The Slums' own light, and the ONE place its colour is written: the emissive
## geometry, the pool it throws on the street, its streak in the standing water
## and its shaft in the smog all read these, so they cannot disagree about what
## colour a sign is. `props/works.gd` keeps the same rule for the machines'
## STRIP/BEACON/WORKING, for the same reason -- a light and the thing casting it
## written down twice drift apart, and the player only ever sees the light.
##
## The ALPHA is the FOUND light code (found.gdshader): 0.5..0.98 is a steady
## strip and BRIGHTER AS IT FALLS (`glow = (1 - a) * 5`); below 0.5 is a beacon
## blinking on the machines' beat. So a LOW number here is a loud sign.

## Street sodium vapour: the ground note, and what a real city at night is.
const SODIUM := Color(0.980, 0.576, 0.180, 0.70)
## The failing institutional light -- a stairwell, an underpass, a municipal sign
## nobody replaced. Hue 127, a true green kept clear of teal, and held DIM,
## because the point of it is that it is old and going out. A bright mercury lamp
## would only be a second billboard.
const MERCURY := Color(0.522, 0.878, 0.549, 0.88)
## The projector lamps themselves: a dirty warm white, because advertising wants
## to look clean and does not quite manage it through this air.
const DAYLIGHT := Color(0.949, 0.910, 0.824, 0.62)
## The advertising's dirty warm white, and the two loud shapes it prints on.
## All of it inside hue 10-50, so a billboard can never read as a machine.
##
## THE INK IS DIMMER THAN THE GROUND, and that ordering is the whole reason a
## billboard reads as a PICTURE rather than as a lamp. A backlit sign is lit
## from behind: the white field is the brightest thing on it and every printed
## shape BLOCKS some of that light. Drawn the other way round -- loud shapes
## brighter than the field -- the panel crushes to one white slab with faint
## marks on it, which is measured, not guessed: at a ground of 0.64 (glow 1.8)
## the first gallery frame came back as four white rectangles and the artwork
## was gone.
const AD_GROUND := Color(0.949, 0.910, 0.824, 0.78)
const AD_LOUD := Color(0.980, 0.576, 0.180, 0.86)
const AD_DEEP := Color(0.784, 0.353, 0.082, 0.93)
## The one element that MOVES. Below 0.5, found.gdshader blinks it on the
## machines' slow beat -- the only motion a baked mesh can have, and enough: a
## sign with one pulsing element reads as RUNNING, where a whole panel blinking
## would read as broken, which is the opposite of what this landscape says.
const AD_PULSE := Color(0.980, 0.576, 0.180, 0.34)

## How high the biggest billboard's face reaches. The play camera shows 26.7 x
## 17.9 tiles of ground, so anything over about ten units is CUT OFF by the top
## of the frame at play zoom, which is what "immense" has to mean here: you
## cannot see the whole of it at once and you look up at it.
const TALL := 12.4
## And why the panel is carried high rather than made wide: a glint's streak in
## wet ground is `max(lp.y - gp.y, 4) * 1.8 + 10` screen pixels
## (sky.gdshaderinc), i.e. bought ENTIRELY with the light's height above the
## ground. A sign at 9 units lays a reflection several times the length of a
## lamp post's, for nothing. The puddles are half the light in this landscape
## and this constant is what pays for them.
## Where the light that reaches the STREET comes from: the foot of the panel,
## not its middle. It is one number shared by every variant because
## `15_lights.SOURCES` states it a second time as its own height column, and the
## two are measured against each other by `tests/sky/test_lamp_pools.gd`.
##
## It was 9.0 — the middle of the biggest panel — and the pool came out with a
## radius of exactly ZERO, because an omni whose reach equals its own height
## lands nothing on the ground beneath it. The sign burned and the street stayed
## black. Raising it back buys a longer reflection and loses the light; this is
## the compromise, and the ground wins.
const LIGHT_AT := 6.5


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.BILLBOARD: billboard(k, v, c)
		PropKind.MURAL: mural(k, v, c)


## A flat mark painted or projected on a face that looks along +X (`out` 1) or
## -X (`out` -1), given in the face's OWN plane as (z, y) and fanned into
## triangles here.
##
## The winding is decided from the polygon's signed area rather than left to the
## order the corners happen to be written in. That is not tidiness: a quad's
## front is `(c - b) x (a - b)`, and every rust run in this game stood proud of
## its plate FACING INTO IT for the project's whole life because one corner
## order was wrong and a culled face raises no error (props/works.gd `run`,
## tests/render/test_found_drawn.gd). A mural is fifty such polygons, so getting
## it wrong once here would lose a whole painting silently.
static func _paint(pen: MeshKit, x: float, pts: PackedVector2Array, col: Color, out: float) -> void:
	if pts.size() < 3:
		return
	var area := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		area += a.x * b.y - b.x * a.y
	# Measured, not reasoned: corners (0,0), (1,0), (0,1) have positive area here
	# and come out facing -X. So a face that must look down +X wants negative
	# area, and one that must look down -X wants positive.
	var flip := (area * out) > 0.0
	var n := pts.size()
	for i in range(1, n - 1):
		var ia := 0
		var ib := i
		var ic := i + 1
		if flip:
			ib = i + 1
			ic = i
		pen.tri(Vector3(x, pts[ia].y, pts[ia].x), Vector3(x, pts[ib].y, pts[ib].x),
			Vector3(x, pts[ic].y, pts[ic].x), col)


## A rectangle in the same plane, by its two corners in (z, y).
static func _rect(pen: MeshKit, x: float, z0: float, y0: float, z1: float, y1: float, col: Color, out: float = 1.0) -> void:
	_paint(pen, x, PackedVector2Array([Vector2(z0, y0), Vector2(z1, y0), Vector2(z1, y1), Vector2(z0, y1)]), col, out)


## A disc in the same plane, centred on (cz, cy).
static func _disc(pen: MeshKit, x: float, cz: float, cy: float, r: float, n: int, col: Color, out: float = 1.0) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := float(i) / float(n) * TAU
		pts.append(Vector2(cz + cos(a) * r, cy + sin(a) * r))
	_paint(pen, x, pts, col, out)


# --- billboards ------------------------------------------------------------------

## The advertisement. Bold shapes and NO WRITING: at play zoom real lettering
## would be illegible anyway, and inventing a script -- katakana or an
## imagined-Asian alphabet -- is the single most copied move in this genre and
## says nothing about this world. A row of blocks of uneven length reads as a
## line of type at distance, which is honest about what the eye actually
## resolves, and invents no language.
##
## It is drawn in LAYERS at slightly different depths rather than flat on the
## backing, because a projection is not a painted board: the shapes sit in front
## of the field they are thrown on, and under a raking light that separation is
## the whole difference between a lit sign and a glowing sticker.
static func _advert(k: Kit, x: float, hz: float, y0: float, h: float, s: int) -> void:
	var z0 := -hz + 0.18
	var z1 := hz - 0.18
	var ya := y0 + 0.16
	var yb := y0 + h - 0.16
	# The field it is all thrown on.
	_rect(k.found, x, z0, ya, z1, yb, AD_GROUND)
	var pick := absi(s) % 3
	var mid := (ya + yb) * 0.5
	if pick == 0:
		# A sweep across the corner and a product held over it.
		_paint(k.found, x + 0.02, PackedVector2Array([
			Vector2(z0, ya + h * 0.12), Vector2(z1, ya + h * 0.44),
			Vector2(z1, ya + h * 0.66), Vector2(z0, ya + h * 0.30)]), AD_LOUD, 1.0)
		_disc(k.found, x + 0.04, lerpf(z0, z1, 0.30), mid + h * 0.10, h * 0.22, 16, AD_DEEP)
		_disc(k.found, x + 0.05, lerpf(z0, z1, 0.30), mid + h * 0.13, h * 0.10, 12, AD_GROUND)
	elif pick == 1:
		# A tall block of colour with the product standing clear of it.
		_rect(k.found, x + 0.02, z0, ya, lerpf(z0, z1, 0.46), yb, AD_DEEP)
		_disc(k.found, x + 0.04, lerpf(z0, z1, 0.68), mid + h * 0.08, h * 0.26, 16, AD_LOUD)
		_rect(k.found, x + 0.05, lerpf(z0, z1, 0.60), ya + h * 0.16, lerpf(z0, z1, 0.76), mid - h * 0.04, AD_GROUND)
	else:
		# Three bands and a mark, the oldest layout there is.
		for b in 3:
			var by := lerpf(ya, yb, 0.30 + b * 0.19)
			_rect(k.found, x + 0.02, z0, by, lerpf(z0, z1, 0.86 - b * 0.16), by + h * 0.10,
				AD_LOUD if b % 2 == 0 else AD_DEEP)
		_disc(k.found, x + 0.04, lerpf(z0, z1, 0.82), ya + h * 0.22, h * 0.15, 14, AD_DEEP)
	# The line of "type" along the foot: uneven blocks, never glyphs.
	var z := z0 + 0.1
	var i := 0
	while z < z1 - 0.3 and i < 14:
		var w := 0.18 + Rng.hash01(s, i) * 0.42
		w = minf(w, z1 - 0.2 - z)
		if w > 0.05:
			_rect(k.found, x + 0.03, z, ya + h * 0.045, z + w, ya + h * 0.105, AD_DEEP)
		z += w + 0.12
		i += 1
	# The one thing that moves: a bar at the head, blinking on the machines' beat.
	_rect(k.found, x + 0.03, lerpf(z0, z1, 0.06), yb - h * 0.11, lerpf(z0, z1, 0.30), yb - h * 0.035, AD_PULSE)


## The hoarding: what is projected on, the frame round it, the catwalk under it
## and the projectors on the catwalk throwing up at it.
##
## `dead` 0..1 is how much of the face has gone out, taken off the +z end. It is
## the landscape's thesis in one parameter: even the broken one is still
## selling, because nobody stopped paying for it and nobody came to switch it
## off. A wholly dark billboard would say the city had failed, which is the
## story every other landscape tells and the exact opposite of this one.
static func _hoarding(k: Kit, x: float, y0: float, hz: float, h: float, s: int, dead: float = 0.0) -> void:
	# The dark backing, seen from behind, and its bracing: a billboard from the
	# wrong side is a rusting steel hoarding and that is most of its silhouette
	# on the approach.
	# The back is a HOARDING, not a slab: dark horizontal strips with seams
	# between them, on bracing that stands proud of them. One flat back plate
	# would be another big ruled face for `found_panels` to draw a grid across,
	# and a billboard's back is the one part of it nobody paid to finish.
	var strips := 7
	for i in strips:
		var sy0 := lerpf(y0, y0 + h, float(i) / float(strips))
		var sy1 := lerpf(y0, y0 + h, float(i + 1) / float(strips)) - 0.05
		_rect(k.found, x - 0.06, -hz, sy0, hz, sy1, P.PLATE[0] if i % 2 == 0 else P.INK[2], -1.0)
	for i in 5:
		var bz := lerpf(-hz, hz, (i + 0.5) / 5.0)
		k.found.prism(x - 0.16, y0 + 0.1, bz, 0.05, y0 + h - 0.1, 0.05, 4, P.PLATE[2], P.PLATE[3], PI * 0.25)
	for r in 2:
		var ry := lerpf(y0, y0 + h, 0.3 + r * 0.4)
		k.rod(Vector3(x - 0.16, ry, -hz + 0.1), Vector3(x - 0.16, ry, hz - 0.1), 0.045, 4, P.PLATE[2])
	Works.run(k, Vector3(x - 0.07, y0 + h - 0.3, -hz * 0.55), 0.07, h * 0.5, Vector3(-1, 0, 0))
	# The frame: a chamfered surround, which is what stops a big flat rectangle
	# reading as a decal pasted on the sky.
	for sz: float in [-1.0, 1.0]:
		k.chamfer(x - 0.02, y0 - 0.1, (hz + 0.08) * sz, 0.24, h + 0.2, 0.2, 0.05, P.PLATE[2], P.PLATE[3])
	for sy: float in [0.0, 1.0]:
		k.chamfer(x - 0.02, y0 - 0.1 + sy * (h + 0.1), 0.0, 0.24, 0.16, hz * 2.0 + 0.36, 0.05, P.PLATE[2], P.PLATE[3])
	# The live face.
	var live := hz * (1.0 - dead * 2.0)
	if dead > 0.0:
		# What is left of the dead half: the backing, and the cracked glass over
		# it catching whatever light the live half throws sideways.
		_rect(k.found, x, live, y0 + 0.16, hz - 0.18, y0 + h - 0.16, P.INK[1])
		for i in 5:
			var cz := lerpf(live, hz - 0.2, Rng.hash01(s, i + 30))
			var cy := lerpf(y0 + 0.2, y0 + h - 0.2, Rng.hash01(s, i + 40))
			_paint(k.found, x + 0.012, PackedVector2Array([
				Vector2(cz, cy), Vector2(cz + 0.4, cy + 0.9), Vector2(cz + 0.46, cy + 0.86)]),
				Works.lit(SODIUM, 0.9), 1.0)
	if live > 0.4:
		_advert(k, x, live, y0, h, s)
	# The catwalk, and the projectors standing on it looking up at the face. The
	# lamps are what make this a PROJECTION: without something visibly throwing
	# the picture, a bright rectangle is a window.
	# `chamfer` takes EXTENTS; `prism` takes RADII. Written as a prism this was a
	# four-sided cone flaring from 0.3 to hz + 0.2, i.e. a flat plate four tiles
	# across lying through the whole model -- which is exactly what the first
	# in-world frame showed, and because found.gdshader rules its panel seams in
	# world space, that one big flat face came out as a grey GRID, the one thing
	# docs/ART.md forbids on screen. The gallery never caught it: at that
	# distance it read as part of the rig.
	k.chamfer(x + 0.5, y0 - 0.24, 0.0, 0.62, 0.09, hz * 2.0 + 0.36, 0.02, P.PLATE[3], P.PLATE[2])
	for i in 3:
		var pz := lerpf(-hz * 0.72, hz * 0.72, i / 2.0)
		k.rod(Vector3(x + 0.05, y0 - 0.2, pz), Vector3(x + 0.62, y0 - 0.18, pz), 0.035, 4, P.PLATE[2])
		var lit_up := i < 2 or dead <= 0.0
		k.chamfer(x + 0.52, y0 - 0.16, pz, 0.22, 0.2, 0.22, 0.04, P.PLATE[1], P.PLATE[2])
		# Its lens looks UP at the panel, which is the one face this camera sees.
		k.found.quad(Vector3(x + 0.45, y0 + 0.045, pz - 0.09), Vector3(x + 0.6, y0 + 0.045, pz - 0.09),
			Vector3(x + 0.6, y0 + 0.045, pz + 0.09), Vector3(x + 0.45, y0 + 0.045, pz + 0.09),
			Works.lit(DAYLIGHT, 0.56) if lit_up else P.PLATE[4])
	# A handrail nobody has used in years.
	k.rod(Vector3(x + 0.78, y0 - 0.14, -hz - 0.1), Vector3(x + 0.78, y0 - 0.14, hz + 0.1), 0.02, 4, P.RUST[2])
	for i in 4:
		var rz := lerpf(-hz, hz, i / 3.0)
		k.rod(Vector3(x + 0.78, y0 - 0.2, rz), Vector3(x + 0.78, y0 + 0.16, rz), 0.016, 4, P.RUST[2])


## Where a billboard's light stands, in the model's own frame. Read by the
## builder AND by PropModels.glow_points, so the lamp on the street and the
## panel throwing it can never be in different places -- the mistake a house's
## stolen tube made for a whole wave (prop_models.gd `neon_point`).
static func light_point(v: int) -> Vector3:
	match v % 4:
		1: return Vector3(1.0, LIGHT_AT, 0.4)
		2: return Vector3(1.0, LIGHT_AT, 0.0)
		3: return Vector3(1.0, LIGHT_AT, -1.6)
	return Vector3(1.0, LIGHT_AT, 0.0)


## A monopole carrying the whole thing, tapering, with the street's rubbish
## banked at its foot. One pole and not two legs, because a prop stops a body
## with ONE circle (`PropKind.SOLID`): a trestle whose feet stand four tiles
## apart would be a wall the player walks through, and an honest footprint is
## worth more than a second leg.
static func _pole(k: Kit, top: float, r0: float, s: int, c: int) -> void:
	k.chamfer(0.0, -0.14, 0.0, 1.15, 0.34, 1.15, 0.12, P.STONE[2], P.STONE[3])
	k.found.prism(0, 0.1, 0, r0, top, r0 * 0.66, 8, P.PLATE[3], P.PLATE[2], PI / 8.0)
	for i in 4:
		var y := 0.6 + i * (top - 1.2) / 4.0
		k.found.prism(0, y, 0, r0 * 1.12, y + 0.1, r0 * 1.1, 8, P.PLATE[1], P.PLATE[1], PI / 8.0)
	Works.run(k, Vector3(r0 * 0.96, top * 0.82, 0.0), 0.09, top * 0.5, Vector3(1, 0, 0))
	Works.run(k, Vector3(-r0 * 0.5, top * 0.55, r0 * 0.8), 0.05, top * 0.3, Vector3(-0.5, 0, 0.8))
	# The grid it is spliced into: a bundle of feeds clipped up the pole and a
	# junction box at head height, because a billboard here is not salvage -- it
	# is maintained, connected and paid for, which is the whole thesis.
	k.chamfer(r0 * 0.9, 1.15, 0.0, 0.2, 0.5, 0.34, 0.04, P.PLATE[2], P.PLATE[1])
	k.found.quad(Vector3(r0 * 0.9 + 0.101, 1.3, -0.1), Vector3(r0 * 0.9 + 0.101, 1.3, 0.1),
		Vector3(r0 * 0.9 + 0.101, 1.44, 0.1), Vector3(r0 * 0.9 + 0.101, 1.44, -0.1), Works.lit(MERCURY, 0.9))
	for i in 3:
		k.cable(Vector3(r0 * 0.8, 1.6 + i * 0.1, -0.1 + i * 0.1), Vector3(r0 * 0.6, top * 0.7, 0.05), 0.12, 5, 0.018, P.INK[2])
	Remains.banks(k, [[0.9, 0.5, 0.5, 0.16], [-0.8, -0.6, 0.45, 0.13], [0.2, -0.95, 0.4, 0.1]], Remains.drift_of(c)[0], s)


## 0 the hero: one immense face carried high over the street, cut off by the top
## of the frame at play zoom. 1 a stack of two, the upper one newer than the
## lower. 2 a low wide face down at second-storey height, close enough to read
## the projectors. 3 one whose far half has gone out and which is still selling
## with the half that has not.
static func billboard(k: Kit, v: int, c: int) -> void:
	var s := 41000 + v * 7 + c
	match v % 4:
		1:
			_pole(k, 10.6, 0.36, s, c)
			_hoarding(k, 0.46, 6.0, 3.1, 3.4, s + 1)
			_hoarding(k, 0.46, 2.3, 3.1, 3.0, s + 2)
			k.rod(Vector3(0.2, 5.6, -3.1), Vector3(0.2, 5.6, 3.1), 0.05, 4, P.PLATE[2])
		2:
			_pole(k, 6.2, 0.34, s, c)
			_hoarding(k, 0.44, 3.0, 4.6, 4.2, s + 1)
		3:
			_pole(k, 11.4, 0.42, s, c)
			_hoarding(k, 0.48, 6.2, 4.2, 5.4, s + 1, 0.3)
		_:
			_pole(k, 11.6, 0.44, s, c)
			_hoarding(k, 0.48, 6.2, 4.2, 5.4, s + 1)


# --- murals ----------------------------------------------------------------------

## The wall face a mural is painted on, at +X.
const FACE := 0.33
## How tall a mural wall stands and how wide. A gable end, so it is read as the
## side of a building somebody pulled the rest of down.
const WALL_H := 6.2
const WALL_HZ := 3.4

## One painted figure: head, torso, two legs, two arms. Bold and simple, because
## a wall four tiles wide is a few hundred pixels at play zoom and anything
## finer than a silhouette is mud. `up` 0 hangs the arms, 1 raises them.
static func _figure(pen: MeshKit, x: float, cz: float, y0: float, h: float, col: Color, up: float) -> void:
	var w := h * 0.145
	_disc(pen, x, cz, y0 + 0.88 * h, h * 0.095, 10, col)
	_paint(pen, x, PackedVector2Array([
		Vector2(cz - w * 0.78, y0 + 0.36 * h), Vector2(cz + w * 0.78, y0 + 0.36 * h),
		Vector2(cz + w, y0 + 0.80 * h), Vector2(cz - w, y0 + 0.80 * h)]), col, 1.0)
	for sz: float in [-1.0, 1.0]:
		var hip := cz + sz * w * 0.42
		_paint(pen, x, PackedVector2Array([
			Vector2(hip - w * 0.30, y0), Vector2(hip + w * 0.30, y0),
			Vector2(hip + w * 0.34, y0 + 0.40 * h), Vector2(hip - w * 0.34, y0 + 0.40 * h)]), col, 1.0)
		var sh := Vector2(cz + sz * w * 0.9, y0 + 0.76 * h)
		var hand := Vector2(cz + sz * w * 1.55, y0 + 0.40 * h)
		if up > 0.0:
			hand = Vector2(cz + sz * w * 1.9, y0 + (0.76 + 0.34 * up) * h)
		var n := (hand - sh).orthogonal().normalized() * w * 0.24
		_paint(pen, x, PackedVector2Array([sh - n, sh + n, hand + n * 0.7, hand - n * 0.7]), col, 1.0)


## Pigment that has been on a wall for generations: pulled most of the way to
## the render under it, so it reads as SOAKED IN rather than painted on this
## morning. Nothing about the mural may be as saturated as the billboard over
## it -- that contrast is the landscape's whole argument, and if the paint
## competes, the picture stops being about anything.
## Measured on the first gallery frame: at 0.52 the pigment had gone the same
## brown as the render under it and all four murals read as one tan smudge. Old
## paint loses CHROMA to the wall, but a mural was bold to begin with and the
## picture has to survive being a few hundred pixels wide -- if it cannot be
## read, the billboard over it is covering nothing and the landscape's one image
## says nothing.
static func _faded(col: Color, wall: Color, age: float) -> Color:
	return col.lerp(wall, age)


## What the mural shows. It is wordless and it is about PEOPLE: a crowd holding
## together, a sun, hands raised. docs/STORY.md is binding and all fiction is
## being rewritten, so this invents no lore, no language and no symbol anybody
## has to be told the meaning of -- it only has to be legibly HUMAN and legibly
## OLD, so that what covers it reads as a loss.
static func _painting(k: Kit, v: int, wall: Color, s: int) -> void:
	var age := 0.26
	# The dark figures are a deep warm BROWN, not ink. At P.INK[2] they came out
	# as black silhouettes and the wall read as a stencil: a painted crowd has to
	# look mixed from earth, and the one thing a mural must not look like is a
	# machine's own hard-edged mark.
	var ink := _faded(P.EARTH[1], wall, age * 0.55)
	var ochre := _faded(P.RUST[3], wall, age)
	var cream := _faded(P.LINEN[4], wall, age)
	var blue := _faded(P.BRINE[3], wall, age)
	var leaf := _faded(P.MOSS[3], wall, age)
	match v % 4:
		1:
			# A sun over small figures: the oldest picture there is.
			_disc(k.made, FACE + 0.006, 0.0, 4.35, 1.45, 20, ochre)
			for i in 14:
				var a := float(i) / 14.0 * TAU
				var d := Vector2(cos(a), sin(a))
				var p0 := Vector2(d.x * 1.5, 4.35 + d.y * 1.5)
				var p1 := Vector2(d.x * 2.35, 4.35 + d.y * 2.35)
				var n := d.orthogonal() * 0.13
				_paint(k.made, FACE + 0.004, PackedVector2Array([p0 - n, p0 + n, p1 + n * 0.3, p1 - n * 0.3]), cream, 1.0)
			_disc(k.made, FACE + 0.01, 0.0, 4.35, 0.72, 16, cream)
			for i in 5:
				_figure(k.made, FACE + 0.008, lerpf(-2.7, 2.7, i / 4.0), 0.7, 2.3,
					ink if i % 2 == 0 else blue, 0.0)
		2, 3:
			# Hands raised. This is the one under the hoarding, so the part that
			# stays visible is chosen deliberately: the arms reach ABOVE the
			# panel's top edge and the feet stand BELOW its bottom, so what the
			# billboard takes is the faces and what it leaves is the gesture.
			# Five, not six, so each is big enough to read at play zoom, and
			# spaced so the two at the +z end fall clear of the hoarding that is
			# bolted over the other three.
			for i in 5:
				var cz := lerpf(-2.9, 2.9, i / 4.0)
				_figure(k.made, FACE + 0.006, cz, 0.7, 3.4 + Kit.j(s, i, 0.3),
					[ink, ochre, blue, leaf][i % 4], 1.0)
			_paint(k.made, FACE + 0.003, PackedVector2Array([
				Vector2(-3.1, 0.5), Vector2(3.1, 0.5), Vector2(3.1, 0.7), Vector2(-3.1, 0.7)]), ochre, 1.0)
		_:
			# A crowd holding together, linked at the shoulder.
			for i in 6:
				var cz := lerpf(-2.95, 2.95, i / 5.0)
				_figure(k.made, FACE + 0.006, cz, 0.7, 3.9 + Kit.j(s, i, 0.3),
					[ink, ochre, cream, blue, leaf][i % 5], 0.0)
			_paint(k.made, FACE + 0.004, PackedVector2Array([
				Vector2(-2.95, 3.68), Vector2(2.95, 3.68), Vector2(2.95, 3.9), Vector2(-2.95, 3.9)]), ochre, 1.0)
			_disc(k.made, FACE + 0.008, 0.0, 5.3, 0.66, 18, cream)
			_disc(k.made, FACE + 0.012, 0.0, 5.3, 0.36, 14, ochre)


## What the permanent drip leaves. It is NOT raining in the Slums and it never
## stops being wet: the smog dome condenses on everything above and comes down
## off every edge at every hour, in every weather. A baked mesh cannot show a
## falling drop, but it can show the twenty years of it -- streaks off the top
## edge, a dark soaked band at the foot, and the paint eaten away where the
## water actually runs. That is the half of "wet" that survives a still frame,
## and the moving half is the standing water the billboards lie down in.
static func _drips(k: Kit, x: float, hz: float, top: float, wall: Color, s: int, over: bool) -> void:
	var dark := wall.lerp(P.INK[1], 0.26 if over else 0.30)
	var n := 5 if over else 8
	for i in n:
		# Biased OUT to the ends of the wall, not spread evenly across it.
		# Sixteen evenly spaced runs came out as a comb -- a painted stripe
		# pattern, the one thing a water stain must never look like -- and they
		# veiled the whole painting. Water comes off the corners and the stepped
		# head, which is where a wall actually stains, and it leaves the middle
		# of the picture to the picture.
		var side := 1.0 if (i % 2) == 0 else -1.0
		var out_z := lerpf(hz * 0.40, hz - 0.06, Rng.hash01(s, i * 3))
		var z := side * out_z
		if i >= n - 2:
			z = lerpf(-hz * 0.5, hz * 0.5, Rng.hash01(s, i * 3 + 7))
		var w := 0.04 + Rng.hash01(s, i * 3 + 1) * (0.1 if over else 0.16)
		# The ones drawn OVER the paint are short: they are the last few years of
		# it, and a long one would cross the figures and read as a bar.
		var run := (0.18 + Rng.hash01(s, i * 3 + 2) * 0.22 if over else 0.5 + Rng.hash01(s, i * 3 + 2) * 0.5) * top
		# A run WIDENS as it falls and ends soft, which is what tells a water
		# stain from a painted stripe.
		_paint(k.made, x, PackedVector2Array([
			Vector2(z - w * 0.5, top), Vector2(z + w * 0.5, top),
			Vector2(z + w * 1.5, top - run), Vector2(z - w * 1.5, top - run)]), dark, 1.0)
	if not over:
		# Rising damp: the foot of every wall in this landscape is soaked and
		# stays soaked, so the bottom of the picture is always the darkest part.
		_paint(k.made, x, PackedVector2Array([
			Vector2(-hz, 0.0), Vector2(hz, 0.0), Vector2(hz, 1.05), Vector2(-hz, 0.72)]),
			wall.lerp(P.INK[0], 0.5), 1.0)


## A wall somebody pulled the rest of the building away from, with a painting on
## it. 0 a crowd holding together; 1 a sun over small figures; 2 and 3 the same
## wall with a hoarding bolted across it -- the landscape's one image.
static func mural(k: Kit, v: int, c: int) -> void:
	var s := 42000 + v * 11 + c
	var dress := BiomeDressing.of(c)
	var wall: Color = dress.concrete if dress.concrete.a > 0.0 else P.STONE[2]
	var top_col := wall.lerp(P.INK[1], 0.3)
	k.slab(0.0, 0.0, 0.0, 0.5, WALL_H, WALL_HZ * 2.0, s, wall, top_col, 0.03)
	# The ghost of what stood against it, on the BACK where it cannot fight the
	# painting: the chimney breast and the stepped scars of three floors. This is
	# what a real party wall shows, and it is the whole reason the wall is
	# standing alone with room for a mural on it.
	k.slab(-0.34, 0.0, -1.5, 0.3, WALL_H * 0.86, 1.1, s + 1, wall.lerp(P.INK[2], 0.18), top_col, 0.03)
	for i in 3:
		var fy := 1.35 + i * 1.5
		_paint(k.made, -0.26, PackedVector2Array([
			Vector2(-WALL_HZ + 0.1, fy), Vector2(WALL_HZ - 0.1, fy),
			Vector2(WALL_HZ - 0.1, fy + 0.16), Vector2(-WALL_HZ + 0.1, fy + 0.16)]),
			wall.lerp(P.EARTH[1], 0.45), -1.0)
	# A stepped head, so the silhouette says "a building was taken off this".
	k.slab(0.0, WALL_H, 1.15, 0.5, 0.75, 2.1, s + 2, wall, top_col, 0.03)
	k.slab(0.0, WALL_H + 0.75, 2.2, 0.5, 0.6, 1.0, s + 3, wall, top_col, 0.03)
	_drips(k, FACE - 0.004, WALL_HZ, WALL_H, wall, s + 4, false)
	_painting(k, v, wall, s + 5)
	_drips(k, FACE + 0.02, WALL_HZ, WALL_H, wall, s + 6, true)
	if v % 4 >= 2:
		_bolted_over(k, v, s + 7)
	Remains.banks(k, [[0.9, 2.4, 0.6, 0.18], [1.0, -2.2, 0.55, 0.15], [-0.9, 0.4, 0.5, 0.14]],
		Remains.drift_of(c)[0], s + 8)


## The hoarding bolted across the painting. Nobody aligned it and nobody took
## the mural off first: it stands on six brackets a hand's width off the render,
## crooked, and the paint goes on behind it.
##
## WHAT IT COVERS IS CHOSEN. It is set off-centre, so one end of the mural is
## left whole -- you can read two of the figures with their arms up, and infer
## the four the advertisement is standing in front of. A panel centred on the
## wall would have read as a tidy band and said nothing; this reads as
## indifference, which is the point. The projection is not malicious and not
## even aware. It is simply brighter, and somebody with the right to put it
## there put it there.
static func _bolted_over(k: Kit, v: int, s: int) -> void:
	var hz := 2.0 if v % 4 == 2 else 1.55
	var h := 2.6 if v % 4 == 2 else 2.4
	var y0 := 1.4 if v % 4 == 2 else 2.2
	var cz := -1.4 if v % 4 == 2 else 0.5
	var tilt := 0.035 if v % 4 == 2 else -0.055
	for i in 6:
		var bz := cz + lerpf(-hz * 0.8, hz * 0.8, (i % 3) / 2.0)
		var by := y0 + (0.25 if i < 3 else 0.75) * h
		k.rod(Vector3(FACE - 0.05, by, bz), Vector3(FACE + 0.3, by + bz * tilt, bz), 0.045, 4, P.PLATE[2])
	k.found.push(Transform3D(Basis(Vector3.RIGHT, tilt), Vector3(0.0, 0.0, cz)))
	_hoarding(k, FACE + 0.42, y0, hz, h, s)
	k.found.pop()

