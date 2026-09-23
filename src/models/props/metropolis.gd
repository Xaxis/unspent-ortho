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


# --- the review surface -------------------------------------------------------------

## Everything this landscape brought, on one plinth each: the five props in the
## city's own dressing, and its two bodies in the poses that change their shape.
##   tools/shot.sh shots/x.png --scene=gallery --filter=metropolis
static func gallery() -> Array:
	var out: Array = []
	var d := BiomeRegistry.get_def(&"ruined_metropolis")
	var c := d.index if d != null else Country.COAST
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
