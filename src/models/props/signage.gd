extends RefCounted
## The Slums' two kinds of picture, and the whole landscape is the argument
## between them.
##
## A MURAL is painted by hand, on a wall, by people, generations ago. It is MADE:
## matte pigment, no light of its own, lit by whatever happens to be around, and
## worn by the land like every other made thing (`matter_worn` reads world
## position, so one mural weathers differently at the two ends of a street).
##
## A HOARDING is projected, and it is the CITY's, not this file's:
## `Towers.billboard` draws every lit sign in the Slums and this wall is just
## another wall to hang one on.
##
## The landscape's one image is the two of them TOUCHING -- a mural half covered
## by a sign that is still cheerfully selling something. Nobody cleaned the mural
## off; nobody defended it either. MURAL variants 2 and 3 ARE that picture, and
## it is ONE PROP on purpose: a placer cannot put the halves in different streets
## and lose the only frame the landscape exists to take.
##
## WHY THE COLOURS ARE WHAT THEY ARE. The machines own the violet band (hue
## 240-336) and the amber LENS, and that contract is what lets a player pick the
## one machine out of the most crowded frame in the game at a glance. So the city
## is lit by what a real city is lit by and the machines are not: sodium orange,
## and the mercury green of whatever stopped being maintained. Those live in
## `Towers.SIGN_COLOURS` -- one list, not this file's own -- and the violet and
## the teal that used to be in it are gone. `tests/render/test_signage.gd` fails
## if either comes back.
##
## Models face +X, so a panel's face looks down +X and its light hangs in front
## of it. Props turn by `-rot`.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
const Remains := preload("res://src/models/props/remains.gd")
const Works := preload("res://src/models/props/works.gd")
const Towers := preload("res://src/models/props/towers.gd")

## THE HOARDING IS NOT DRAWN HERE. `Towers.billboard` already draws the city's
## lit sign -- a gantry of brackets off a wall and a NEON-coded face inside it --
## and a second implementation would be two things that disagree about what a
## sign is the first time either is touched. This file gives it a WALL and asks.
##
## What that buys beyond not repeating the work: the face is a `GroundColors.NEON`
## mark on MADE geometry, so `PropModels.neon_point` reads its middle and its
## colour off the geometry itself. The mural's glow point is therefore not a
## coordinate anybody typed -- it is measured from the thing that is glowing, and
## the light and its cause cannot part company. A bare mural has no NEON in it at
## all, so the same call returns nothing and `15_lights.PLACED_SOURCES` drops it.
## Paint emits nothing, a projection lights the street, and neither fact is
## written down twice.
##
## The colours come from `Towers.SIGN_COLOURS` for the same reason: one list.

## Where the hoarding sits on the wall, as a share of its height. Chosen against
## the painting rather than for its own sake: the figures stand from 0.7 to about
## 4.5, so a sign from 1.4 to 4.0 takes their heads and bodies and leaves their
## RAISED HANDS above it and their feet below. What a billboard covers is the
## whole point of this landscape, so it is picked, not centred.
const SIGN_FOOT := 0.23
const SIGN_HEAD := 0.65
## How far the gantry stands off the wall, so the sign clears the paint under it.
const SIGN_WALL := 0.30
## How far in luminance a pigment must stand from the wall under it. Small enough
## that the paint still reads as soaked into the render rather than fresh, large
## enough to survive a landscape whose ambient is a third of an open noon.
const APART := 0.13


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
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
	var out := col.lerp(wall, age)
	# AND THEN FORCED BACK APART FROM THE WALL, which is the half that matters.
	#
	# Fading toward the render was right on the coast's pale grey concrete and
	# invisible on the Slums' dark brown: every pigment landed within a few
	# values of the wall, and under an ambient a third of an open noon the whole
	# painting went to one flat slab. Measured in the Slums at BOTH noon and
	# midnight (they differ by 0.0881 there, so there is no brighter hour to be
	# saved by) the figures could not be made out at all, while the drip stains
	# -- which are the wall's own colour pushed DARKER -- read perfectly.
	#
	# That is the whole diagnosis: what survives is VALUE separation, not hue. So
	# the pigment keeps its hue and chroma and is scaled until it stands clear of
	# whatever it was painted on, away from the wall in the direction it already
	# leaned. A mural is bold paint on somebody's wall; it cannot be defined
	# relative to the wall and then expected to be seen against it.
	var lw := wall.get_luminance()
	var lo := maxf(out.get_luminance(), 0.002)
	var want := clampf(lw - APART if lo <= lw else lw + APART, 0.04, 0.90)
	var k := want / lo
	return Color(minf(out.r * k, 1.0), minf(out.g * k, 1.0), minf(out.b * k, 1.0), out.a)


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
	# The wall handed over as the four corners `Towers.billboard` expects, wound
	# so `Houses.wall_out` gives +X: bl and br run along the foot from +z to -z.
	# Getting that order backwards would point the whole sign INTO the wall and
	# cull every triangle of it without a word.
	var x := SIGN_WALL
	var face: Array = [
		Vector3(x, 0.0, WALL_HZ), Vector3(x, 0.0, -WALL_HZ),
		Vector3(x, WALL_H, -WALL_HZ), Vector3(x, WALL_H, WALL_HZ)]
	# `billboard` spans u 0.14..0.80 of the wall it is given, so it is already
	# narrower than the wall and already off-centre. That is the picture for
	# free: the figures at each end of the painting stand clear of it, and a
	# player reads two of them whole and infers the three behind the sign.
	var col: Color = Towers.SIGN_COLOURS[absi(s) % Towers.SIGN_COLOURS.size()]
	if v % 4 == 2:
		Towers.billboard(k, face, SIGN_FOOT, SIGN_HEAD, col, s)
	else:
		# Hung higher and shallower, so the two walls are not the same wall
		# twice: this one takes the heads and leaves the bodies, where the first
		# takes the bodies and leaves the raised hands.
		Towers.billboard(k, face, 0.44, 0.74, col, s + 3)

