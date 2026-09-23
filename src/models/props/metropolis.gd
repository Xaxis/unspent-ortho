extends RefCounted
## What the Ruined Metropolis left standing, and what the plan sorts it into
## (docs/LANDSCAPES.md §4). A dead megacity is poured concrete: a span of
## elevated road come down across a street, a lift core standing where its
## tower was, a shop with its shutter half down. Those are MADE, tagged
## CONCRETE (matter row 85), because cast concrete is a thing people poured and
## the lit shader has a row for exactly that. What the machines add is the
## ruler's: a straddle frame over the demolition face and the ruled bales it
## sorts the city into.
##
## THE SIGN-BOX IS THE FIRST CALLER OF ENAMEL (row 88), and where it is drawn
## decides whether it is one. The box itself is FOUND — a pressed steel case
## on brackets — but its FACE is drawn on the MADE pen, because the material
## mark rides in a colour's ALPHA and `found.gdshader` reads that same alpha as
## a lamp: an ENAMEL-tagged colour handed to `Kit.chamfer` or `Kit.plate` is
## not a painted sign, it is a beacon that blinks (CLAUDE.md, the tagging
## trap; `landmark_models.gd` has constants called ENAMEL on the found pen and
## the row was never reached by them). So the case is `rod`/`chamfer` stock and
## the enamel is a `k.made` quad a hair proud of it.
##
## Every model faces +X, like every prop. The deck span's ORIGIN IS ITS HIGH
## END: `PropKind.SOLID` answers one circle per prop, and the only end of a
## fallen span a body should be stopped by is the one standing three units up
## on its pier; the low end lies on the ground and a body walks over it.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
const Houses := preload("res://src/models/props/houses.gd")
const Towers := preload("res://src/models/props/towers.gd")
const Remains := preload("res://src/models/props/remains.gd")
const Rocks := preload("res://src/models/props/rocks.gd")
const Works := preload("res://src/models/props/works.gd")
## The machines' gallery helper, reached by path (it carries no class_name).
const MG := preload("res://src/models/machines/machine_gallery.gd")

## How far the deck span runs from its high end to where its low end lies, and
## how high the high end stands on its pier (docs/LANDSCAPES.md: 8 x 2.5, one
## end 3 high).
const SPAN := 7.6
const SPAN_HIGH := 3.0
const SPAN_WIDE := 2.5


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.DECK_SPAN: deck_span(k, v, c)
		PropKind.LIFT_SHAFT: lift_shaft(k, v, c)
		PropKind.SHOPFRONT: shopfront(k, v, c)
		PropKind.SORTED_BALE: sorted_bale(k, v, c)
		PropKind.DEMOLITION_GANTRY: demolition_gantry(k, v, c)


## The landscape's concrete, lit as concrete. `GroundColors.down`/`up` keep the
## mark; a `lerp` would lose it and fall back to the default.
static func concrete(c: int) -> Color:
	return GroundColors.made(BiomeDressing.of(c).concrete, GroundColors.CONCRETE)


## A rectangle on the plane x = `x` from (y0, z0) to (y1, z1), WOUND TO FACE +X.
## Every face here that looks up the street is on +X, and a quad handed its
## corners in the obvious order (low z first) comes out facing -X: the lift
## doors, the bale's seal and both strips on the gantry all drew from no
## bearing at all until tests/render/test_found_drawn.gd said so.
static func _xrect(pen: MeshKit, x: float, y0: float, y1: float, z0: float, z1: float, col: Color) -> void:
	pen.quad(Vector3(x, y0, z1), Vector3(x, y0, z0), Vector3(x, y1, z0), Vector3(x, y1, z1), col)


# --- what came down ---------------------------------------------------------------

## A span of elevated highway lying across a street at a tilt: its high end on
## the stub of its pier, its low end on the ground, reinforcement trailing out
## of the break, and the lamp standard that stood on it still bolted down. 0: the
## standard still up; 1: the standard snapped and hanging over the edge.
static func deck_span(k: Kit, v: int, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 30100 + v * 23 + c
	var con := concrete(c)
	var deck := GroundColors.down(con, 0.12)
	var tilt := -atan2(SPAN_HIGH - 0.3, SPAN)
	# The deck, tilted: built level in a frame pitched down toward its low end,
	# on BOTH pens, so the standard and the reinforcement on it lie with it.
	var frame := Transform3D(Basis(Vector3.BACK, tilt), Vector3(0.0, SPAN_HIGH, 0.0))
	k.made.push(frame)
	k.found.push(frame)
	var length := sqrt(SPAN * SPAN + (SPAN_HIGH - 0.3) * (SPAN_HIGH - 0.3))
	k.slab(length * 0.5, -0.42, 0.0, length, 0.42, SPAN_WIDE, s, deck, con, 0.04)
	# The kerbs along both edges, standing proud, with a length gone from one.
	for sz: float in [-1.0, 1.0]:
		var gone := int(Rng.hash01(s, int(sz) + 3, 5) * 4.0)
		for i in 4:
			if i == gone:
				continue
			var x0 := 0.3 + i * (length - 0.6) / 4.0
			k.slab(x0 + (length - 0.6) / 8.0, 0.0, sz * (SPAN_WIDE * 0.5 - 0.14), (length - 0.6) / 4.0 - 0.1, 0.22, 0.24, s + 10 + i, GroundColors.down(con, 0.06), GroundColors.up(con, 0.15), 0.03)
	# A centre line of paint, dashed, faded: ENAMEL, because that is what road
	# paint is, and it is MADE — paint is a thing somebody laid on.
	var paint := GroundColors.made(P.LINEN[3].lerp(dress.concrete, 0.45), GroundColors.ENAMEL)
	for i in 7:
		var x0 := 0.6 + i * 1.0
		k.made.quad(Vector3(x0, 0.004, 0.08), Vector3(x0 + 0.55, 0.004, 0.08), Vector3(x0 + 0.55, 0.004, -0.08), Vector3(x0, 0.004, -0.08), paint)
	# The lamp standard: a steel post with a bent-over head, dead. Bolted near
	# the high end, where it is read against the sky.
	var foot := Vector3(1.4, 0.0, -SPAN_WIDE * 0.5 + 0.34)
	if v == 0:
		k.rod(foot, foot + Vector3(0.04, 2.4, 0.0), 0.05, 6, P.PLATE[2])
		k.rod(foot + Vector3(0.04, 2.4, 0.0), foot + Vector3(0.34, 2.75, 0.5), 0.038, 5, P.PLATE[2])
		k.chamfer(foot.x + 0.4, 2.62, foot.z + 0.58, 0.34, 0.16, 0.22, 0.04, P.PLATE[1], P.INK[1])
	else:
		# Snapped a metre up, the head hanging over the edge on its own conduit.
		k.rod(foot, foot + Vector3(0.02, 1.1, 0.0), 0.05, 6, P.PLATE[2])
		k.rod(foot + Vector3(0.02, 1.1, 0.0), foot + Vector3(-0.2, 0.5, -0.9), 0.045, 6, P.PLATE[1])
		k.cable(foot + Vector3(0.02, 1.08, 0.0), foot + Vector3(-0.3, -0.6, -1.1), 0.1, 3, 0.01, P.INK[2])
		k.chamfer(foot.x - 0.24, 0.16, foot.z - 0.95, 0.3, 0.14, 0.2, 0.04, P.PLATE[1], P.INK[1])
	k.rod(foot + Vector3(0.0, 0.0, 0.0), foot + Vector3(0.0, 0.06, 0.0), 0.11, 6, P.PLATE[1])
	# The stains where the deck drains: down its side faces.
	for i in 3:
		Remains.streak(k, Vector3(1.2 + i * 2.1, -0.02, SPAN_WIDE * 0.5 + 0.002), 0.12, 0.3, Vector3.BACK, P.RUST[2])
	k.made.pop()
	k.found.pop()
	# The pier the high end rests on, cast stone broken at the top, and the
	# reinforcement out of both breaks: the pier's, and the deck's own torn end.
	var tops: Array[float] = []
	for i in 8:
		tops.append(2.3 + Rng.hash01(s, i, 41) * 0.5)
	Rocks.cast_leg(k, 0.9, 1.4, 0.12, 0.0, tops, 2.75, P.STONE[2].lerp(dress.concrete, 0.5), dress.pale[1])
	var roots: Array = []
	var ends: Array = []
	for i in 5:
		var z := -SPAN_WIDE * 0.45 + i * SPAN_WIDE * 0.22
		roots.append(Vector3(-0.05, SPAN_HIGH - 0.2 + Kit.j(s, i, 0.1), z))
		ends.append(Vector3(-0.5 - Rng.hash01(s, i, 43) * 0.4, SPAN_HIGH - 0.6 - Rng.hash01(s, i, 44) * 0.5, z + Kit.j(s, i + 8, 0.2)))
	Rocks._rebar(k, roots, ends)
	# What broke off it, at the pier's foot and under the span: concrete in
	# lumps, the land's own rubble, and the land's growth in the shelter it makes.
	for i in 7:
		var x := -0.6 + Rng.hash01(s, i, 45) * 2.4
		var z := Kit.j(s, i + 20, SPAN_WIDE * 0.7)
		k.stone(x, -0.04, z, 0.14 + Rng.hash01(s, i, 46) * 0.16, 0.12 + Rng.hash01(s, i, 47) * 0.14, s + 50 + i,
			GroundColors.down(dress.concrete, 0.1) if i % 2 == 0 else P.STONE[3], 5)
	if not dress.cold():
		k.clump(1.6, -0.05, 0.4, 0.22, 0.14, s + 60, dress.growth, 6)
		k.clump(2.4, -0.05, -0.7, 0.16, 0.1, s + 61, GroundColors.down(dress.growth, 0.15), 6)
	elif not dress.snow.is_empty():
		k.clump(4.0, SPAN_HIGH - 4.0 * 0.355 + 0.04, 0.2, 0.7, 0.12, s + 62, dress.snow[0], 7)


## A lift core standing where its tower was: the two-by-two shaft that survives
## every fall, its doors hanging at two landings, floor slabs stubbed off its
## flanks with the bars out of them, and the cable dangling from the head.
## 0: the cable hangs inside the doorway; 1: it hangs out of the front with the
## counterweight's sheave still on it.
static func lift_shaft(k: Kit, v: int, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 30200 + v * 29 + c
	var con := concrete(c)
	var wall := GroundColors.down(con, 0.2)
	var high := 6.6 + Rng.hash01(s, 0, 3) * 0.5
	# Four walls, each its own height and lean, the front one in two pieces
	# either side of the doorways.
	k.slab(0.0, 0.0, -1.0, 2.0, high - 0.4 + Kit.j(s, 1, 0.3), 0.22, s + 1, wall, GroundColors.up(con, 0.1), 0.05, 0.0, Kit.j(s, 2, 0.02))
	k.slab(0.0, 0.0, 1.0, 2.0, high + Kit.j(s, 3, 0.3), 0.22, s + 2, wall, GroundColors.up(con, 0.1), 0.05, 0.0, Kit.j(s, 4, 0.02))
	k.slab(-1.0, 0.0, 0.0, 0.22, high - 0.2 + Kit.j(s, 5, 0.3), 2.0, s + 3, GroundColors.down(wall, 0.12), GroundColors.up(con, 0.1), 0.05, 0.0, Kit.j(s, 6, 0.02))
	for sz: float in [-1.0, 1.0]:
		k.slab(1.0, 0.0, sz * 0.7, 0.22, high - 0.6 + Kit.j(s, 7 + int(sz), 0.3), 0.6, s + 4 + int(sz), con, GroundColors.up(con, 0.1), 0.04)
	# The lintels over the two doorways, and the dark of the shaft behind them.
	for y: float in [2.3, 5.8]:
		k.slab(1.0, y, 0.0, 0.24, 0.3, 0.9, s + 8 + int(y), con, GroundColors.up(con, 0.14), 0.03)
	_xrect(k.made, 0.86, 0.0, high - 0.8, -0.4, 0.4, P.INK[0])
	# The doors: pressed steel, hanging off one runner at the ground landing and
	# the pair still shut at the upper one, dented in.
	k.plate(Vector3(1.13, 0.05, 0.02), Vector3(1.13, 0.05, -0.36), Vector3(1.02, 2.1, -0.3), Vector3(1.02, 2.1, 0.12), P.PLATE[2], P.PLATE[1], P.PLATE[4])
	k.plate(Vector3(1.12, 3.5, -0.02), Vector3(1.12, 3.5, -0.36), Vector3(1.12, 5.7, -0.36), Vector3(1.12, 5.7, -0.02), P.PLATE[3], P.PLATE[1], P.PLATE[4])
	k.plate(Vector3(1.12, 3.5, 0.36), Vector3(1.12, 3.5, 0.02), Vector3(1.12, 5.7, 0.02), Vector3(1.12, 5.7, 0.36), P.PLATE[2], P.PLATE[1], P.PLATE[4])
	# The floor slabs of the tower that is gone, stubbed off both flanks with
	# the bars out of them: this is what says a building stood round it.
	for level in 2:
		var y := 2.6 + level * 2.7
		for sz: float in [-1.0, 1.0]:
			var reach := 0.5 + Rng.hash01(s, level * 2 + int(sz), 51) * 0.5
			k.slab(0.0, y, sz * (1.11 + reach * 0.5), 1.6, 0.24, reach, s + 20 + level * 3 + int(sz), GroundColors.down(con, 0.08), con, 0.05, 0.0, 0.0)
			var roots: Array = []
			var ends: Array = []
			for i in 3:
				var x := -0.5 + i * 0.5
				roots.append(Vector3(x, y + 0.12, sz * (1.11 + reach)))
				ends.append(Vector3(x + Kit.j(s, i + level, 0.3), y - 0.2 - Rng.hash01(s, i, 52 + level) * 0.4, sz * (1.11 + reach + 0.3 + Rng.hash01(s, i, 53) * 0.3)))
			Rocks._rebar(k, roots, ends)
	# The head: the sheave beam across the top, and the cable off it.
	k.rod(Vector3(-0.8, high - 0.1, 0.0), Vector3(0.8, high - 0.1, 0.0), 0.06, 6, P.PLATE[2])
	k.hoop(Vector3(0.0, high - 0.1, 0.0), 0.2, 8, 0.02, P.PLATE[3], Vector3.BACK)
	if v == 0:
		k.rod(Vector3(0.0, high - 0.3, 0.0), Vector3(0.05, 0.8, -0.1), 0.014, 3, P.INK[2])
		k.rod(Vector3(0.05, 0.8, -0.1), Vector3(0.4, 0.2, 0.3), 0.012, 3, P.INK[2])
	else:
		k.cable(Vector3(0.0, high - 0.3, 0.0), Vector3(1.4, high - 1.2, 0.3), 0.1, 3, 0.014, P.INK[2])
		k.rod(Vector3(1.4, high - 1.2, 0.3), Vector3(1.5, 1.6, 0.4), 0.014, 3, P.INK[2])
		k.hoop(Vector3(1.5, 1.5, 0.4), 0.16, 8, 0.02, P.PLATE[3], Vector3.BACK)
		k.chamfer(1.52, 0.4, 0.42, 0.3, 1.0, 0.2, 0.04, P.PLATE[1], P.PLATE[2])
	# What runs down a core: the rain in through the open head.
	Remains.streak(k, Vector3(-0.4, high - 0.6, 1.113), 0.16, 2.2, Vector3.BACK, GroundColors.down(wall, 0.3))
	Remains.streak(k, Vector3(0.3, high - 0.3, 1.113), 0.1, 1.4, Vector3.BACK, GroundColors.down(wall, 0.4))
	# The rubble of the tower at its foot, and what grows in it.
	for i in 6:
		var a := Rng.hash01(s, i, 61) * TAU
		var r := 1.3 + Rng.hash01(s, i, 62) * 0.5
		k.stone(cos(a) * r, -0.04, sin(a) * r, 0.14 + Rng.hash01(s, i, 63) * 0.14, 0.1 + Rng.hash01(s, i, 64) * 0.12, s + 70 + i,
			GroundColors.down(dress.concrete, 0.1) if i % 2 else P.STONE[2], 5)
	if not dress.cold():
		k.clump(1.5, -0.05, -0.9, 0.18, 0.12, s + 80, dress.growth, 6)
	elif not dress.snow.is_empty():
		k.clump(0.0, high - 0.02, 0.0, 0.5, 0.1, s + 81, dress.snow[0], 6)


## A gutted ground-floor shop front: party walls and a fascia of concrete, the
## roller shutter half down over the dark, a dead sign-box on the fascia, and
## the glass that came out of it in a drift on the pavement. 0, 1, 2: the
## shutter a third, two thirds and all the way down, and the third's sign-box
## hanging off one bracket.
static func shopfront(k: Kit, v: int, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 30300 + v * 31 + c
	var con := concrete(c)
	var wall := GroundColors.down(con, 0.18)
	# Party walls either side, the fascia across, the back wall behind the dark.
	for sz: float in [-1.0, 1.0]:
		k.slab(0.0, 0.0, sz * 1.42, 1.2, 3.0 + Kit.j(s, int(sz) + 2, 0.12), 0.24, s + 1 + int(sz), wall, GroundColors.up(con, 0.1), 0.05, 0.0, Kit.j(s, int(sz) + 4, 0.02))
	k.slab(0.0, 2.4, 0.0, 1.2, 0.6, 3.1, s + 5, con, GroundColors.up(con, 0.14), 0.04)
	k.slab(-0.5, 0.0, 0.0, 0.2, 2.5, 2.7, s + 6, GroundColors.down(wall, 0.15), con, 0.05)
	# The opening: the dark of the room, the shutter box under the fascia, and
	# the shutter itself, corrugated, down as far as it got.
	_xrect(k.made, -0.38, 0.0, 2.4, -1.3, 1.3, P.INK[0])
	k.chamfer(0.5, 2.05, 0.0, 0.3, 0.34, 2.72, 0.05, P.PLATE[2], P.PLATE[3])
	var down: float = [0.75, 1.5, 2.2][v]
	Remains.corrugated(k.found, Vector3(0.6, 2.05, -1.32), Vector3(0.0, 0.0, 2.64), Vector3(0.0, -down, 0.0), 22, P.PLATE[2])
	k.rod(Vector3(0.62, 2.05 - down, -1.32), Vector3(0.62, 2.05 - down, 1.32), 0.03, 4, P.PLATE[1])
	# The guides the shutter runs in.
	for sz: float in [-1.0, 1.0]:
		k.rod(Vector3(0.6, 0.0, sz * 1.32), Vector3(0.6, 2.1, sz * 1.32), 0.025, 4, P.PLATE[1])
	# THE SIGN-BOX: a pressed case on two brackets off the fascia (FOUND), and
	# its face on the MADE pen tagged ENAMEL — see the header for why the pen
	# decides whether this is a painted sign or a blinking lamp.
	var hung := v == 2
	var box_y := 2.55 if not hung else 2.2
	k.found.push(Transform3D(Basis(Vector3.RIGHT, -0.35 if hung else 0.0), Vector3(0.0, 0.0, 0.0)))
	for sz: float in [-1.0, 1.0]:
		if hung and sz < 0.0:
			continue
		k.rod(Vector3(0.6, box_y + 0.2, sz * 0.9), Vector3(0.86, box_y + 0.2, sz * 0.9), 0.03, 4, P.PLATE[1])
	k.chamfer(0.78, box_y, 0.0, 0.2, 0.46, 2.2, 0.04, P.PLATE[1], P.PLATE[2])
	k.found.pop()
	# The face: the landscape's own sign enamel, faded, a corner of it peeled to
	# the case underneath, and the dead blocks of what it said.
	var enamel := GroundColors.made(dress.sign[0], GroundColors.ENAMEL)
	var faded := GroundColors.made(GroundColors.down(dress.sign[0], 0.2), GroundColors.ENAMEL)
	var fb := Transform3D(Basis(Vector3.RIGHT, -0.35 if hung else 0.0), Vector3.ZERO)
	k.made.push(fb)
	var fx := 0.883
	_xrect(k.made, fx, box_y + 0.02, box_y + 0.44, -1.04, 1.04, enamel)
	k.made.quad(Vector3(fx + 0.003, box_y + 0.02, 1.04), Vector3(fx + 0.003, box_y + 0.02, 0.5), Vector3(fx + 0.003, box_y + 0.16, 0.5), Vector3(fx + 0.003, box_y + 0.3, 1.04), faded)
	k.made.tri(Vector3(fx + 0.004, box_y + 0.44, 1.04), Vector3(fx + 0.004, box_y + 0.3, 1.04), Vector3(fx + 0.004, box_y + 0.44, 0.7), P.PLATE[1])
	for i in 4:
		var z0 := -0.9 + i * 0.44 + Rng.hash01(s, i, 71) * 0.06
		var wdt := 0.22 + Rng.hash01(s, i, 72) * 0.12
		_xrect(k.made, fx + 0.006, box_y + 0.12, box_y + 0.34, z0, z0 + wdt, P.INK[1] if i != 2 else GroundColors.made(dress.sign[1], GroundColors.ENAMEL))
	k.made.pop()
	# The glass that came out of the front: a drift of it on the pavement, each
	# shard a fleck that catches the light, and the frame it fell out of.
	for i in 14:
		var p := Vector3(0.8 + Rng.hash01(s, i, 81) * 0.9, 0.006, Kit.j(s, i + 30, 1.3))
		var a := Rng.hash01(s, i, 82) * TAU
		var e1 := Vector3(cos(a), 0, sin(a)) * (0.06 + Rng.hash01(s, i, 83) * 0.1)
		var e2 := Vector3(-sin(a), 0.01, cos(a)) * (0.05 + Rng.hash01(s, i, 84) * 0.08)
		k.fleck(p, p + e1, p + e2, GroundColors.glint(P.SLATE[4] if i % 3 else P.RIME[4]))
	k.rod(Vector3(0.66, 0.0, -1.2), Vector3(0.66, 0.4, -1.1), 0.02, 4, P.PLATE[1])
	# What the street leaves against a front, and what the years did to the fascia.
	Houses.weathered(k, Vector3(0.61, 2.4, 1.55), Vector3(0.61, 2.4, -1.55), Vector3(0.61, 3.0, -1.55), Vector3(0.61, 3.0, 1.55), s + 90, GroundColors.down(con, 0.35), dress.growth)
	for i in 3:
		var p := Vector3(0.75 + Kit.j(s, i + 40, 0.15), -0.06, -1.1 + i * 1.1 + Kit.j(s, i + 44, 0.2))
		k.clump(p.x, p.y, p.z, 0.2 + Kit.j(s, i, 0.06), 0.11, s + 100 + i, Towers.solid(dress.drift[i % 2]), 6)
	if dress.cold() and not dress.snow.is_empty():
		k.clump(0.0, 3.0, 0.4, 0.8, 0.12, s + 110, dress.snow[0], 7)


## A ruled cube of what the plan sorted the city into, strapped: 0 crushed
## rebar, 1 copper, 2 glass cullet. FOUND, all of it — the machines made this
## shape, and nothing in a dead city is this square.
static func sorted_bale(k: Kit, v: int, c: int) -> void:
	var s := 30400 + v * 37 + c
	var body: Color = [P.RUST[2], P.COPPER[2], P.SLATE[3]][v]
	var top: Color = [P.RUST[3], P.COPPER[3], P.SLATE[4]][v]
	k.chamfer(0.0, 0.0, 0.0, 1.2, 1.2, 1.2, 0.1, body, top)
	# Two straps round it, each four rods, and the seal plate on the front.
	for z: float in [-0.32, 0.32]:
		k.rod(Vector3(-0.62, 0.0, z), Vector3(-0.62, 1.22, z), 0.02, 4, P.INK[2])
		k.rod(Vector3(0.62, 0.0, z), Vector3(0.62, 1.22, z), 0.02, 4, P.INK[2])
		k.rod(Vector3(-0.62, 1.22, z), Vector3(0.62, 1.22, z), 0.02, 4, P.INK[2])
	k.plate(Vector3(0.62, 0.42, 0.16), Vector3(0.62, 0.42, -0.16), Vector3(0.62, 0.74, -0.16), Vector3(0.62, 0.74, 0.16), P.PLATE[3], P.PLATE[1], P.PLATE[4])
	match v:
		0:
			# The bars, crushed in and poking out of the top and one flank.
			for i in 7:
				var p := Vector3(Kit.j(s, i, 0.45), 1.2, Kit.j(s, i + 10, 0.45))
				k.rod(p, p + Vector3(Kit.j(s, i + 20, 0.2), 0.12 + Rng.hash01(s, i, 21) * 0.2, Kit.j(s, i + 30, 0.2)), 0.014, 3, P.RUST[3] if i % 2 else P.RUST[1])
			for i in 3:
				var p := Vector3(0.2 + i * 0.16, 0.2 + Rng.hash01(s, i, 22) * 0.7, 0.6)
				k.rod(p, p + Vector3(Kit.j(s, i + 40, 0.15), Kit.j(s, i + 44, 0.1), 0.14 + Rng.hash01(s, i, 23) * 0.1), 0.012, 3, P.RUST[2])
		1:
			# Wire wound flat into the block, and a loose coil of it on top.
			for i in 5:
				k.hoop(Vector3(0.0, 0.2 + i * 0.2, 0.0), 0.63, 8, 0.01, P.COPPER[4] if i % 2 else P.COPPER[3], Vector3.UP)
			k.hoop(Vector3(0.2, 1.24, -0.1), 0.18, 8, 0.012, P.COPPER[4], Vector3(0.2, 1.0, 0.1))
		_:
			# Cullet: the block glitters where a shard faces the light.
			for i in 12:
				var p := Vector3(0.61, 0.1 + Rng.hash01(s, i, 31) * 1.0, Kit.j(s, i + 50, 0.5))
				var e1 := Vector3(0.0, 0.05 + Rng.hash01(s, i, 32) * 0.05, 0.03)
				var e2 := Vector3(0.0, 0.01, 0.06 + Rng.hash01(s, i, 33) * 0.05)
				k.fleck(p, p + e1, p + e2, GroundColors.glint(P.RIME[4] if i % 2 else P.SLATE[5]))
			for i in 8:
				var p := Vector3(Kit.j(s, i + 60, 0.5), 1.21, Kit.j(s, i + 70, 0.5))
				k.fleck(p, p + Vector3(0.08, 0.005, 0.02), p + Vector3(0.02, 0.01, 0.07), GroundColors.glint(P.RIME[4]))


## The straddle frame over the demolition face: two A-frames, a beam across
## them with the plan's strip along it, and the hook that lifts what the
## demolishers break out. FOUND, ruled, six wide, and open to walk through:
## its mass is the two legs, which one circle cannot say (PropKind.SOLID).
static func demolition_gantry(k: Kit, _v: int, _c: int) -> void:
	var top := 3.4
	for sz: float in [-1.0, 1.0]:
		var z := sz * 3.0
		k.rod(Vector3(-0.7, 0.0, z), Vector3(-0.12, top, z * 0.94), 0.07, 6, P.PLATE[2])
		k.rod(Vector3(0.7, 0.0, z), Vector3(0.12, top, z * 0.94), 0.07, 6, P.PLATE[2])
		k.rod(Vector3(-0.42, top * 0.5, z * 0.97), Vector3(0.42, top * 0.5, z * 0.97), 0.035, 4, P.PLATE[3])
		k.rod(Vector3(-0.7, 0.0, z), Vector3(-0.3, 0.06, z), 0.1, 6, P.PLATE[1])
		k.rod(Vector3(0.7, 0.0, z), Vector3(0.3, 0.06, z), 0.1, 6, P.PLATE[1])
	# The beam, and the strip along its underside that is the plan's own light:
	# alpha 0.88 is a steady strip to found.gdshader, and the colour is the one
	# every installation in the game shares (Works.STRIP).
	k.rod(Vector3(0.0, top + 0.1, -3.1), Vector3(0.0, top + 0.1, 3.1), 0.11, 6, P.PLATE[3])
	k.rod(Vector3(0.0, top - 0.1, -2.9), Vector3(0.0, top - 0.1, 2.9), 0.03, 4, P.PLATE[1])
	_xrect(k.found, 0.18, top, top + 0.12, -2.6, 2.6, Works.STRIP)
	# The trolley and the hook off it, hanging over the cut.
	k.chamfer(0.0, top + 0.16, 0.6, 0.5, 0.26, 0.5, 0.05, P.PLATE[2], P.PLATE[3])
	k.rod(Vector3(0.0, top + 0.16, 0.6), Vector3(0.0, 1.5, 0.6), 0.016, 3, P.INK[2])
	k.chamfer(0.0, 1.2, 0.6, 0.22, 0.32, 0.22, 0.04, P.PLATE[1], P.PLATE[2])
	k.rod(Vector3(0.0, 1.2, 0.6), Vector3(0.0, 0.8, 0.72), 0.03, 5, P.PLATE[3])
	k.rod(Vector3(0.0, 0.8, 0.72), Vector3(0.0, 0.95, 0.95), 0.028, 5, P.PLATE[3])
	# The control box on one leg, with its own cold light in it.
	k.chamfer(-0.5, 1.1, -2.7, 0.3, 0.4, 0.26, 0.04, P.PLATE[2], P.PLATE[3])
	_xrect(k.found, -0.34, 1.2, 1.32, -2.78, -2.62, Works.STRIP)


# --- what people build inside what fell (BiomeForms.FORMS) -------------------------

## The one door for the city's four built forms, reached from `Towers.build`
## by form id, never by landscape. A form this file does not know draws
## nothing, and `tests/biome/test_forms.gd` fails on it.
static func form(k: Kit, which: StringName, c: int) -> void:
	match which:
		&"infill": infill(k, c)
		&"deck_house": deck_house(k, c)
		&"shaft_loft": shaft_loft(k, c)
		&"stall_row": stall_row(k, c)


## A rectangle on the plane z = `z` from (y0, x0) to (y1, x1): it faces +Z when
## x1 > x0 and -Z when x1 < x0, the same rule `_xrect` keeps for X.
static func _zrect(pen: MeshKit, z: float, y0: float, y1: float, x0: float, x1: float, col: Color) -> void:
	pen.quad(Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z), col)


## A tube of stolen neon on a wall from a to b standing out along `out`: the
## dark mount and the tube, NEON-marked so `PropModels.neon_point` finds it and
## the light it throws stands where the tube is (Houses.neon_tube's rule).
static func _tube(k: Kit, a: Vector3, b: Vector3, out: Vector3, col: Color) -> void:
	var o := out.normalized()
	Remains._facing_quad(k.made, a + o * 0.01 + Vector3(0, -0.04, 0), b + o * 0.01 + Vector3(0, -0.04, 0), Vector3(0, 0.08, 0), o, P.INK[1])
	Remains._facing_quad(k.made, a + o * 0.02 + Vector3(0, -0.024, 0), b + o * 0.02 + Vector3(0, -0.024, 0), Vector3(0, 0.048, 0), o, GroundColors.neon(col))


## A salvaged door stood on its edge as a wall, from a to b, `h` tall, facing
## `out`, leaning its own way: a panel line and a handle, so it reads as a door
## somebody carried here and not as a board.
static func _door(k: Kit, a: Vector3, b: Vector3, h: float, out: Vector3, col: Color, s: int, i: int) -> void:
	var o := out.normalized()
	var lean := o * Kit.j(s, i + 60, 0.05)
	var top := Vector3(0, h + Kit.j(s, i + 70, 0.08), 0) + lean
	Remains._facing_quad(k.made, a, b, top, o, col)
	var inset := (b - a) * 0.14
	Remains._facing_quad(k.made, a + inset + o * 0.012 + Vector3(0, h * 0.24, 0), b - inset + o * 0.012 + Vector3(0, h * 0.24, 0), Vector3(0, h * 0.5, 0) + lean * 0.5, o, GroundColors.down(col, 0.22))
	var knob := a.lerp(b, 0.82) + o * 0.02 + Vector3(0, h * 0.48, 0) + lean * 0.48
	k.made.strut(knob, knob + Vector3(0, 0.07, 0), 0.016, 4, P.COPPER[3])


## "infill": a dead tower's ground floor walled in with salvaged doors inside
## its frame. Four cast columns and the first-floor slab they still hold up,
## the column stubs and reinforcement going on up from it, and under the slab
## a bay closed with doors of every colour, one gap hung with a curtain, plate
## across the back and a tube along the lintel. Lit: it faces the square.
static func infill(k: Kit, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 30500 + c * 7
	var con := concrete(c)
	var col_h := 3.3
	# The frame: columns, the slab, the stubs, the bars.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.slab(sx * 1.75, 0.0, sz * 1.75, 0.42, col_h + Kit.j(s, int(sx * 2.0 + sz), 0.06), 0.42, s + int(sx * 3.0 + sz), GroundColors.down(con, 0.14), con, 0.03, 0.0, Kit.j(s, int(sx + sz * 2.0) + 9, 0.015))
			k.slab(sx * 1.75, col_h + 0.3, sz * 1.75, 0.4, 0.25 + Rng.hash01(s, int(sx * 2.0 + sz), 11) * 0.3, 0.4, s + 20 + int(sx * 3.0 + sz), GroundColors.down(con, 0.1), dress.pale[1], 0.05, 0.12)
	k.slab(0.0, col_h, 0.0, 4.3, 0.3, 4.3, s + 5, GroundColors.down(con, 0.06), con, 0.06)
	var roots: Array = []
	var ends: Array = []
	for i in 4:
		var sx := 1.0 if i % 2 == 0 else -1.0
		var sz := 1.0 if i < 2 else -1.0
		roots.append(Vector3(sx * 1.75, col_h + 0.8, sz * 1.75))
		ends.append(Vector3(sx * (1.75 + Rng.hash01(s, i, 31) * 0.3), col_h + 0.85 + Rng.hash01(s, i, 32) * 0.15, sz * 1.75 + Kit.j(s, i + 40, 0.3)))
	Rocks._rebar(k, roots, ends)
	# The bay walled in: the doors along the front, the gap and its curtain.
	var doors: Array[Color] = [GroundColors.made(P.EARTH[2], GroundColors.TIMBER), GroundColors.made(dress.timber[0], GroundColors.TIMBER),
		GroundColors.made(P.SLATE[2].lerp(P.EARTH[1], 0.4), GroundColors.TIMBER), GroundColors.made(P.LINEN[2].lerp(P.EARTH[2], 0.5), GroundColors.TIMBER),
		GroundColors.made(dress.timber[1], GroundColors.TIMBER)]
	_xrect(k.made, 1.62, 0.0, col_h, -1.56, 1.56, P.INK[0])
	var z := 1.54
	var n := 0
	while z > -1.5:
		var w := 0.66 if n != 2 else 0.52
		if n == 2:
			# The way in: a curtain of what cloth there was, drawn half across.
			var cloth := GroundColors.made(dress.pale[0].lerp(P.EARTH[2], 0.3), GroundColors.CLOTH)
			Remains._facing_quad(k.made, Vector3(1.66, 0.05, z - 0.06), Vector3(1.66, 0.05, z - w + 0.14), Vector3(0.02, 1.85, 0), Vector3(1, 0, 0), cloth)
			k.rod(Vector3(1.7, 1.95, z + 0.02), Vector3(1.7, 1.95, z - w - 0.02), 0.014, 4, P.PLATE[2])
		else:
			_door(k, Vector3(1.7, 0.0, z), Vector3(1.7, 0.0, z - w), 2.0, Vector3(1, 0, 0), doors[n % doors.size()], s, n)
		z -= w + 0.04
		n += 1
	# The boards over the doors up to the slab, and the tube along the lintel.
	_xrect(k.made, 1.68, 2.1, col_h - 0.02, -1.56, 1.56, GroundColors.made(GroundColors.down(dress.timber[0], 0.2), GroundColors.TIMBER))
	for i in 3:
		_xrect(k.made, 1.69, 2.14 + i * 0.36, 2.44 + i * 0.36, -1.5, 1.5, GroundColors.made(doors[(i + 1) % doors.size()], GroundColors.TIMBER) if i != 1 else P.INK[1])
	_tube(k, Vector3(1.7, 2.76, 1.2), Vector3(1.7, 2.76, -1.2), Vector3(1, 0, 0), Towers.SIGN_COLOURS[1])
	# The flanks: doors again on one side, plate on the other, and the back is
	# corrugated sheet nailed across the columns.
	var xi := 1.5
	var m := 0
	while xi > -1.5:
		_zrect(k.made, 1.72, 0.0, 2.0 + Kit.j(s, m + 80, 0.1), xi - 0.62, xi, doors[(m + 3) % doors.size()])
		xi -= 0.66
		m += 1
	_zrect(k.made, 1.72, 2.0, col_h, -1.5, 1.5, GroundColors.made(GroundColors.down(dress.timber[1], 0.25), GroundColors.TIMBER))
	Remains.patch(k, Vector3(1.5, 0.0, -1.74), Vector3(-1.5, 0.0, -1.74), Vector3(-1.5, 2.2, -1.74), Vector3(1.5, 2.2, -1.74), 2)
	Remains.patch(k, Vector3(1.4, 2.2, -1.75), Vector3(-1.4, 2.2, -1.75), Vector3(-1.4, col_h - 0.05, -1.75), Vector3(1.4, col_h - 0.05, -1.75), 3)
	Remains.corrugated(k.found, Vector3(-1.72, 0.0, -1.5), Vector3(0.0, 0.0, 3.0), Vector3(0.0, col_h - 0.1, 0.0), 14, P.PLATE[2])
	# A stovepipe out through the slab, a drum, and what is kept against a column.
	k.limb(Vector3(-1.0, 2.6, 0.8), Vector3(-0.98, col_h + 0.9, 0.82), 0.05, 0.05, 6, P.RUST[1])
	k.made.prism(-0.98, col_h + 0.9, 0.82, 0.055, col_h + 0.92, 0.055, 6, P.INK[0], GroundColors.glow(P.EMBER[3], 0.6))
	k.made.prism(2.05, 0.0, 1.9, 0.2, 0.56, 0.18, 9, P.RUST[2], P.INK[1])
	Houses.salvage(k, Vector3(-1.75, 0.0, 1.96), Vector3(1.75, 0.0, 1.96), Vector3(1.75, 2.0, 1.96), Vector3(-1.75, 2.0, 1.96), 0.25, s + 9)
	# What the years did to the concrete, and what the street leaves at the foot.
	Houses.weathered(k, Vector3(1.96, 0.0, 1.96), Vector3(1.96, 0.0, 1.54), Vector3(1.96, col_h, 1.54), Vector3(1.96, col_h, 1.96), s + 90, GroundColors.down(con, 0.35), dress.growth)
	for i in 3:
		var p := Vector3(2.0 + Kit.j(s, i + 40, 0.12), -0.06, -1.6 + i * 1.4 + Kit.j(s, i + 44, 0.2))
		k.clump(p.x, p.y, p.z, 0.2 + Kit.j(s, i, 0.05), 0.11, s + 100 + i, Towers.solid(dress.drift[i % 2]), 6)
	if dress.cold() and not dress.snow.is_empty():
		k.clump(0.0, col_h + 0.3, 0.3, 1.6, 0.14, s + 110, dress.snow[0], 7)


## "deck_house": a shack built on a piece of fallen deck, at the high end of
## it where the slab stands on its own rubble, its front wall on posts down to
## the slope, a plate roof, a door looking down the deck at the street.
static func deck_house(k: Kit, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 30600 + c * 11
	var con := concrete(c)
	var deck := GroundColors.down(con, 0.12)
	var rise := 1.3
	var tilt := -atan2(rise - 0.2, 4.0)
	var frame := Transform3D(Basis(Vector3.BACK, tilt), Vector3(-2.0, rise, 0.0))
	k.made.push(frame)
	k.found.push(frame)
	var length := sqrt(16.0 + (rise - 0.2) * (rise - 0.2))
	k.slab(length * 0.5, -0.36, 0.0, length, 0.36, 2.4, s, deck, con, 0.04)
	for sz: float in [-1.0, 1.0]:
		k.slab(length * 0.62, 0.0, sz * 1.08, length * 0.7, 0.2, 0.22, s + 3 + int(sz), GroundColors.down(con, 0.06), GroundColors.up(con, 0.15), 0.03)
	# A rail of poles along the edge the door looks out over, roped.
	for i in 4:
		var x := 1.9 + i * 0.5
		k.limb(Vector3(x, 0.0, -1.1), Vector3(x + 0.02, 0.9, -1.12), 0.035, 0.028, 4, GroundColors.made(dress.timber[0], GroundColors.TIMBER))
	k.sag(Vector3(1.9, 0.85, -1.1), Vector3(3.4, 0.85, -1.1), 0.05, 4, 0.012, GroundColors.made(P.EARTH[3], GroundColors.ROPE))
	Remains.streak(k, Vector3(2.2, -0.02, 1.202), 0.1, 0.24, Vector3.BACK, P.RUST[2])
	k.made.pop()
	k.found.pop()
	# The shack, level: its back wall on the deck, its front on posts.
	var plank := GroundColors.made(dress.timber[0], GroundColors.TIMBER)
	var plank2 := GroundColors.made(dress.timber[1], GroundColors.TIMBER)
	var floor_y := rise + 0.02
	k.slab(-1.05, floor_y - 0.1, 0.0, 1.7, 0.1, 2.0, s + 10, plank2, plank, 0.02)
	for sz: float in [-1.0, 1.0]:
		k.limb(Vector3(-0.3, floor_y - 0.6, sz * 0.9), Vector3(-0.3, floor_y - 0.08, sz * 0.9), 0.05, 0.04, 4, plank2)
	# `Houses.walls` draws as it goes and answers corners in its own frame, so
	# the shack is built under one transform: the walls and everything hung on
	# them land on the deck together.
	var stand := Transform3D(Basis.IDENTITY, Vector3(-1.05, floor_y, 0.0))
	k.made.push(stand)
	k.found.push(stand)
	var t := Houses.walls(k, 1.5, 1.9, 1.75, s + 11, plank, plank2, Vector3(0.02, 0.0, 0.02))
	var faces := Houses.faces(t)
	var fb: Array = faces[0]
	Houses.door(k, fb[0], fb[1], fb[2], fb[3], 0.4, 0.14, 0.8)
	Houses.boarded(k, faces[1][0], faces[1][1], faces[1][2], faces[1][3], 0.5, 0.55, 0.16, 0.14, s + 12)
	for fi in 4:
		var wf: Array = faces[fi]
		Houses.weathered(k, wf[0], wf[1], wf[2], wf[3], s + 20 + fi * 7, GroundColors.down(plank, 0.3), dress.growth)
	k.made.pop()
	k.found.pop()
	# The roof: one sheet of machine plate, a fall to the back, weighted.
	Remains.patch(k, Vector3(-0.1, floor_y + 1.95, 1.1), Vector3(-0.1, floor_y + 1.95, -1.1), Vector3(-2.05, floor_y + 1.7, -1.1), Vector3(-2.05, floor_y + 1.7, 1.1), 2)
	for i in 3:
		k.stone(-0.6 - i * 0.5, floor_y + 1.93 - i * 0.07, -0.5 + (i % 2) * 0.9, 0.11, 0.09, s + 30 + i, GroundColors.down(dress.concrete, 0.12), 5)
	k.limb(Vector3(-1.6, floor_y + 1.6, 0.6), Vector3(-1.58, floor_y + 2.25, 0.62), 0.05, 0.05, 6, P.RUST[1])
	k.made.prism(-1.58, floor_y + 2.25, 0.62, 0.055, floor_y + 2.27, 0.055, 6, P.INK[0], GroundColors.glow(P.EMBER[3], 0.6))
	# What the high end stands on: the rubble of whatever the deck came down
	# on, and the bars out of the deck's own broken end.
	for i in 7:
		var x := -2.3 + Rng.hash01(s, i, 45) * 1.6
		var z := Kit.j(s, i + 20, 1.6)
		k.stone(x, -0.04, z, 0.16 + Rng.hash01(s, i, 46) * 0.18, 0.2 + Rng.hash01(s, i, 47) * 0.4, s + 50 + i,
			GroundColors.down(dress.concrete, 0.1) if i % 2 == 0 else P.STONE[3], 5)
	Rocks._rebar(k, [Vector3(-2.05, rise - 0.2, -0.6), Vector3(-2.05, rise - 0.15, 0.3), Vector3(-2.05, rise - 0.25, 0.9)],
		[Vector3(-2.5, rise - 0.6, -0.7), Vector3(-2.45, rise - 0.55, 0.25), Vector3(-2.4, rise - 0.7, 1.0)])
	if not dress.cold():
		k.clump(1.2, -0.05, 0.9, 0.2, 0.12, s + 60, dress.growth, 6)
	elif not dress.snow.is_empty():
		k.clump(-1.0, floor_y + 1.9, 0.0, 0.8, 0.12, s + 61, dress.snow[0], 7)


## "shaft_loft": rooms hung inside a lift core with its tower gone, one to a
## landing, reached by a rope ladder up the face; a plank floor pokes out of
## each doorway as a landing, a tarp over the head, a tube at the middle door.
static func shaft_loft(k: Kit, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 30700 + c * 13
	var con := concrete(c)
	var wall := GroundColors.down(con, 0.2)
	var high := 6.3
	var plank := GroundColors.made(dress.timber[0], GroundColors.TIMBER)
	var plank2 := GroundColors.made(dress.timber[1], GroundColors.TIMBER)
	# The core: three walls whole, the front in two piers with the doorways
	# between them and the strips of wall between the doorways.
	k.slab(0.0, 0.0, -1.0, 2.0, high - 0.3 + Kit.j(s, 1, 0.2), 0.22, s + 1, wall, GroundColors.up(con, 0.1), 0.05, 0.0, Kit.j(s, 2, 0.02))
	k.slab(0.0, 0.0, 1.0, 2.0, high + Kit.j(s, 3, 0.2), 0.22, s + 2, wall, GroundColors.up(con, 0.1), 0.05, 0.0, Kit.j(s, 4, 0.02))
	k.slab(-1.0, 0.0, 0.0, 0.22, high - 0.15 + Kit.j(s, 5, 0.2), 2.0, s + 3, GroundColors.down(wall, 0.12), GroundColors.up(con, 0.1), 0.05, 0.0, Kit.j(s, 6, 0.02))
	for sz: float in [-1.0, 1.0]:
		k.slab(1.0, 0.0, sz * 0.7, 0.22, high - 0.5 + Kit.j(s, 7 + int(sz), 0.2), 0.6, s + 4 + int(sz), con, GroundColors.up(con, 0.1), 0.04)
	var landings: Array[float] = [0.0, 2.3, 4.5]
	for i in landings.size():
		var y0: float = landings[i]
		k.slab(1.0, y0 + 1.9, 0.0, 0.24, 0.4, 0.9, s + 8 + i, con, GroundColors.up(con, 0.14), 0.03)
		_xrect(k.made, 0.86, y0, y0 + 1.9, -0.4, 0.4, P.INK[0])
		# The landing: a plank floor out of the doorway, and its rail.
		k.slab(1.2, y0 + 0.02, 0.0, 0.6, 0.08, 0.9, s + 20 + i, plank2, plank, 0.02)
		k.rod(Vector3(1.48, y0 + 0.06, -0.42), Vector3(1.48, y0 + 0.7, -0.42), 0.014, 4, P.PLATE[2])
		k.rod(Vector3(1.48, y0 + 0.06, 0.42), Vector3(1.48, y0 + 0.7, 0.42), 0.014, 4, P.PLATE[2])
		k.rod(Vector3(1.48, y0 + 0.7, -0.42), Vector3(1.48, y0 + 0.7, 0.42), 0.014, 4, P.PLATE[3])
		# What is hung in the doorway: a curtain on the middle one, boards on
		# the top, and the ground one is the way in.
		if i == 1:
			var cloth := GroundColors.made(dress.pale[0].lerp(P.EARTH[2], 0.3), GroundColors.CLOTH)
			Remains._facing_quad(k.made, Vector3(1.05, y0 + 0.1, 0.36), Vector3(1.05, y0 + 0.1, -0.12), Vector3(0.01, 1.7, 0), Vector3(1, 0, 0), cloth)
		elif i == 2:
			for j in 3:
				_xrect(k.made, 1.06, y0 + 0.2 + j * 0.55, y0 + 0.62 + j * 0.55, -0.38, 0.38, plank if j % 2 == 0 else plank2)
	# The rope ladder up the face, from the ground to the top landing.
	var rope := GroundColors.made(P.EARTH[3], GroundColors.ROPE)
	for sz: float in [-1.0, 1.0]:
		k.made.strut(Vector3(1.15, 0.1, sz * 0.24 - 0.55), Vector3(1.15, landings[2] + 0.4, sz * 0.24 - 0.55), 0.014, 3, rope)
	var rungs := int((landings[2] + 0.2) / 0.38)
	for i in rungs:
		var y := 0.3 + i * 0.38
		k.limb(Vector3(1.15, y, -0.82), Vector3(1.15, y + Kit.j(s, i + 30, 0.03), -0.28), 0.02, 0.018, 4, plank if i % 3 else plank2)
	k.rod(Vector3(1.0, landings[2] + 0.5, -0.55), Vector3(1.28, landings[2] + 0.42, -0.55), 0.02, 4, P.PLATE[2])
	# The tube beside the middle door, where the ladder arrives.
	_tube(k, Vector3(1.12, landings[1] + 1.6, 0.9), Vector3(1.12, landings[1] + 1.6, 0.5), Vector3(1, 0, 0), Towers.SIGN_COLOURS[2])
	# The head: the sheave beam still across it, a tarp over the top room on
	# poles, washing on the beam, and a pipe breathing out of it.
	k.rod(Vector3(-0.8, high - 0.1, 0.0), Vector3(0.8, high - 0.1, 0.0), 0.06, 6, P.PLATE[2])
	var tarp := GroundColors.made(dress.pale[1].lerp(P.EARTH[1], 0.35), GroundColors.CLOTH)
	for sz: float in [-1.0, 1.0]:
		k.limb(Vector3(0.6, high - 0.4, sz * 0.8), Vector3(0.62, high + 0.15, sz * 0.82), 0.03, 0.025, 4, plank2)
	k.made.quad(Vector3(0.7, high + 0.16, 0.9), Vector3(0.7, high + 0.16, -0.9), Vector3(-0.9, high - 0.25, -0.9), Vector3(-0.9, high - 0.25, 0.9), tarp)
	k.made.quad(Vector3(-0.9, high - 0.25, 0.9), Vector3(-0.9, high - 0.25, -0.9), Vector3(0.7, high + 0.16, -0.9), Vector3(0.7, high + 0.16, 0.9), GroundColors.down(tarp, 0.2))
	k.sag(Vector3(0.6, high - 0.5, 1.0), Vector3(-0.6, high - 0.5, 1.0), 0.05, 4, 0.01, rope)
	for i in 3:
		var x := 0.35 - i * 0.4
		var cloth := GroundColors.made([dress.pale[0], P.LINEN[2], dress.pale[2]][i], GroundColors.CLOTH)
		Remains._facing_quad(k.made, Vector3(x + 0.12, high - 0.9, 1.02), Vector3(x - 0.12, high - 0.9, 1.02), Vector3(0.0, 0.4, 0.0), Vector3(0, 0, 1), cloth)
	k.limb(Vector3(-0.5, high - 0.6, 0.4), Vector3(-0.48, high + 0.3, 0.42), 0.05, 0.05, 6, P.RUST[1])
	k.made.prism(-0.48, high + 0.3, 0.42, 0.055, high + 0.32, 0.055, 6, P.INK[0], GroundColors.glow(P.EMBER[3], 0.6))
	# The stubs of the tower's floors off the flanks, and the rain down the core.
	for level in 2:
		var y := 2.4 + level * 2.5
		var sz := 1.0 if level == 0 else -1.0
		k.slab(0.0, y, sz * 1.31, 1.6, 0.24, 0.4, s + 40 + level, GroundColors.down(con, 0.08), con, 0.05)
		Rocks._rebar(k, [Vector3(-0.3, y + 0.12, sz * 1.5), Vector3(0.4, y + 0.12, sz * 1.5)],
			[Vector3(-0.4, y - 0.3, sz * 1.55), Vector3(0.5, y - 0.2, sz * 1.58)])
	Remains.streak(k, Vector3(-0.3, high - 0.5, 1.113), 0.14, 2.0, Vector3.BACK, GroundColors.down(wall, 0.3))
	Remains.streak(k, Vector3(0.5, high - 0.7, -1.113), 0.1, 1.5, Vector3.FORWARD, GroundColors.down(wall, 0.4))
	for i in 4:
		var a := 0.6 + Rng.hash01(s, i, 61) * 4.0
		var r := 1.25 + Rng.hash01(s, i, 62) * 0.3
		k.stone(cos(a) * r, -0.04, sin(a) * r, 0.12 + Rng.hash01(s, i, 63) * 0.12, 0.1 + Rng.hash01(s, i, 64) * 0.1, s + 70 + i,
			GroundColors.down(dress.concrete, 0.1) if i % 2 else P.STONE[2], 5)


## "stall_row": three shop fronts under one fascia, re-shuttered as homes: a
## shutter down with a door cut through it, one with a window and a curtain,
## and one rolled up under an awning of cloth with the household's things out
## on the pavement. Wide and low, the frontage a street is made of.
static func stall_row(k: Kit, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 30800 + c * 17
	var con := concrete(c)
	var wall := GroundColors.down(con, 0.18)
	var plank := GroundColors.made(dress.timber[0], GroundColors.TIMBER)
	var plank2 := GroundColors.made(dress.timber[1], GroundColors.TIMBER)
	var cloth := GroundColors.made(dress.pale[0].lerp(P.EARTH[2], 0.3), GroundColors.CLOTH)
	# The party walls, the fascia and the back.
	for z: float in [-2.3, -0.75, 0.75, 2.3]:
		k.slab(0.0, 0.0, z, 1.2, 2.7 + Kit.j(s, int(z * 2.0) + 5, 0.1), 0.22, s + int(z * 3.0) + 9, wall, GroundColors.up(con, 0.1), 0.04, 0.0, Kit.j(s, int(z) + 20, 0.015))
	k.slab(0.1, 2.4, 0.0, 1.0, 0.55, 4.9, s + 5, con, GroundColors.up(con, 0.14), 0.04)
	k.slab(-0.5, 0.0, 0.0, 0.2, 2.5, 4.7, s + 6, GroundColors.down(wall, 0.15), con, 0.05)
	_xrect(k.made, -0.38, 0.0, 2.4, -2.2, 2.2, P.INK[0])
	# The shutter box under the fascia, the whole width.
	k.chamfer(0.5, 2.05, 0.0, 0.3, 0.34, 4.5, 0.05, P.PLATE[2], P.PLATE[3])
	# Bay one: the shutter down and a door cut through it.
	Remains.corrugated(k.found, Vector3(0.6, 2.05, -2.2), Vector3(0.0, 0.0, 1.4), Vector3(0.0, -2.05, 0.0), 12, P.PLATE[2])
	_door(k, Vector3(0.64, 0.0, -1.1), Vector3(0.64, 0.0, -1.7), 1.85, Vector3(1, 0, 0), plank, s, 1)
	k.slab(0.8, 0.0, -1.4, 0.34, 0.03, 0.5, s + 30, GroundColors.made(P.EARTH[2], GroundColors.CLOTH), Color(0, 0, 0, 0), 0.01)
	# Bay two: the shutter down with a window cut, the curtain drawn.
	Remains.corrugated(k.found, Vector3(0.6, 2.05, -0.65), Vector3(0.0, 0.0, 1.3), Vector3(0.0, -2.05, 0.0), 11, P.PLATE[3])
	_xrect(k.made, 0.63, 1.0, 1.7, -0.45, 0.45, P.INK[0])
	Remains._facing_quad(k.made, Vector3(0.65, 1.02, 0.44), Vector3(0.65, 1.02, 0.02), Vector3(0.0, 0.66, 0.0), Vector3(1, 0, 0), cloth)
	k.rod(Vector3(0.66, 1.72, -0.48), Vector3(0.66, 1.72, 0.48), 0.012, 4, P.PLATE[1])
	k.rod(Vector3(0.62, 0.98, -0.5), Vector3(0.62, 0.98, 0.5), 0.02, 4, P.PLATE[1])
	# Bay three: rolled up, an awning on two poles, the household outside.
	# The shutter is up in its box: no stub of it shows under the awning, which
	# covers that foot of frontage from every bearing the camera can take.
	_xrect(k.made, 0.6, 0.0, 2.0, 0.85, 2.2, P.INK[0])
	for z: float in [0.95, 2.1]:
		k.limb(Vector3(1.9, 0.0, z), Vector3(1.88, 1.95, z + 0.02), 0.035, 0.028, 4, plank2)
	k.made.quad(Vector3(0.7, 2.3, 0.85), Vector3(0.7, 2.3, 2.2), Vector3(1.95, 1.95, 2.15), Vector3(1.95, 1.95, 0.9), cloth)
	k.made.quad(Vector3(1.95, 1.95, 0.9), Vector3(1.95, 1.95, 2.15), Vector3(0.7, 2.3, 2.2), Vector3(0.7, 2.3, 0.85), GroundColors.down(cloth, 0.2))
	k.sag(Vector3(1.88, 1.9, 0.95), Vector3(1.88, 1.9, 2.1), 0.04, 3, 0.01, GroundColors.made(P.EARTH[3], GroundColors.ROPE))
	Remains._facing_quad(k.made, Vector3(1.86, 1.55, 1.7), Vector3(1.86, 1.55, 1.4), Vector3(0.0, 0.34, 0.0), Vector3(0, 0, 1), GroundColors.made(P.LINEN[2], GroundColors.CLOTH))
	k.slab(1.2, 0.0, 1.5, 0.7, 0.28, 0.34, s + 40, plank, plank2, 0.02, 0.06, Kit.j(s, 41, 0.05))
	k.made.prism(1.5, 0.0, 0.95, 0.2, 0.56, 0.18, 9, P.RUST[2], P.INK[1])
	for i in 3:
		k.stone(1.0 + i * 0.22, 0.0, 2.0 + Kit.j(s, i + 50, 0.1), 0.09, 0.08, s + 50 + i, P.STONE[3] if i % 2 else P.SAND[3], 5)
	# The stovepipe out through the fascia, the years on it, the street's drift.
	k.limb(Vector3(0.2, 2.9, -1.5), Vector3(0.22, 3.55, -1.48), 0.05, 0.05, 6, P.RUST[1])
	k.made.prism(0.22, 3.55, -1.48, 0.055, 3.57, 0.055, 6, P.INK[0], GroundColors.glow(P.EMBER[3], 0.6))
	Houses.weathered(k, Vector3(0.61, 2.4, 2.45), Vector3(0.61, 2.4, -2.45), Vector3(0.61, 2.95, -2.45), Vector3(0.61, 2.95, 2.45), s + 90, GroundColors.down(con, 0.35), dress.growth)
	for i in 3:
		var p := Vector3(0.75 + Kit.j(s, i + 60, 0.15), -0.06, -2.0 + i * 1.4 + Kit.j(s, i + 64, 0.2))
		k.clump(p.x, p.y, p.z, 0.2 + Kit.j(s, i, 0.06), 0.11, s + 100 + i, Towers.solid(dress.drift[i % 2]), 6)
	if dress.cold() and not dress.snow.is_empty():
		k.clump(0.1, 2.95, 0.4, 1.6, 0.12, s + 110, dress.snow[0], 7)


# --- the review surface -------------------------------------------------------------

## Everything this landscape brought, on one plinth each: the five props in the
## city's own dressing, and its two bodies in the poses that change their shape.
##   tools/shot.sh shots/x.png --scene=gallery --filter=metropolis
static func gallery() -> Array:
	var out: Array = []
	# The city is found by what its people BUILD and never by name: nothing under
	# src/models/props/ may name a landscape (tests/biome/test_dressing.gd), and
	# the one whose shelter is an infilled tower frame is the one these dress for.
	var c := 0
	for d: BiomeDef in BiomeRegistry.land():
		if BiomeDressing.of(d.index).shelter == &"infill":
			c = d.index
	for kind: int in [PropKind.DECK_SPAN, PropKind.LIFT_SHAFT, PropKind.SHOPFRONT, PropKind.SORTED_BALE, PropKind.DEMOLITION_GANTRY]:
		for v in PropModels.variants(kind, c):
			out.append({"name": "metropolis %s %d" % [PropKind.NAMES[kind], v], "node": PropModels.node(kind, v, c)})
	for kid: StringName in [&"demolisher", &"sentinel_unbuilder"]:
		for p: StringName in [&"stand", &"alert", &"windup", &"dead"]:
			var item: FigureModel = MG.make(kid, p, 0.3)
			var holder := Node3D.new()
			holder.add_child(item)
			out.append({"name": "metropolis %s %s" % [String(kid).trim_prefix("sentinel_"), p], "node": holder})
	return out
