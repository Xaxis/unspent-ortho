## The THRESHOLD site, standing in the sea off the home coast (`BlackSite`,
## docs/STORY.md): where Elias died in 2029 and where the Seeker grew the body he
## wakes in. Three things, and each one has a job in that sentence.
##
##   PLATFORM     the deck it all stands on, on legs out of the water
##   GROWTH_TANK  the tank he was grown in, drained and standing open
##   CONSOLE      a screen that still has power and still has something to say
##
## ALL FOUND, all metal: nothing here was made by hand and nothing here has
## weathered like timber. It is the one place in the game the machines built FOR
## a person rather than round one, so it is better made than a survey post and
## worse kept than anything still on the plan -- the sea has had sixty-nine years
## at it.
##
## **A CONSOLE IS NOT A PLAN WORK ON PURPOSE.** The obvious kinds for a readable
## screen are `RELAY` and `SURVEY`, and both are `Takes.PLAN_WORKS`: a second
## `use` robs them and files the theft. The panel on the tank a man was grown in
## is not a thing you strip for a signet, so it is a kind of its own with no
## `Takes` row, and `StoryProps.READABLE` reads it as a TERMINAL.
extends RefCounted

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
const Works := preload("res://src/models/props/works.gd")

## The deck's half width in tiles. `BlackSite.blocks` hands the same figure to
## `WorldQuery.set_blocks` as one circle, because a prop's own `solid` is a
## circle and a deck is square: the two must agree or a body walks through a
## corner it can see.
const DECK := 2.8
## How high the deck stands over the water it is planted in.
const DECK_Y := 1.15


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.PLATFORM: platform(k, v, c)
		PropKind.GROWTH_TANK: tank(k, v, c)
		PropKind.CONSOLE: console(k, v, c)


## A steel deck on four legs, a handrail round three sides and the fourth open
## where a ladder goes down to the water. You arrive by raft, so the open side is
## how you get aboard and it must read as a way in from above.
static func platform(k: Kit, v: int, c: int) -> void:
	var s := 41100 + v + c
	var deck := P.PLATE[2]
	var edge := P.PLATE[3]
	# The legs, planted past the waterline and stained where the sea reaches.
	for i in 4:
		var sx := -1.0 if i < 2 else 1.0
		var sz := -1.0 if (i & 1) == 0 else 1.0
		var x := sx * (DECK - 0.5)
		var z := sz * (DECK - 0.5)
		k.rod(Vector3(x, -1.6, z), Vector3(x, DECK_Y, z), 0.22, 6, P.PLATE[1])
		# The tide mark: sixty-nine years of it, darkest at the waterline.
		k.rod(Vector3(x, -0.35, z), Vector3(x, 0.30, z), 0.245, 6, P.RUST[1])
		k.rod(Vector3(x, 0.30, z), Vector3(x, 0.62, z), 0.235, 6, P.RUST[2])
		# NO CROSS-BRACE UNDER THE DECK. There was one, running in to the middle,
		# and it is the right way to hold a platform up and the wrong thing to
		# model: the deck is solid and the play camera looks DOWN, so all four sat
		# in a shadow nobody can get a bearing on. The legs and their tide marks
		# carry the engineering read on their own.
	# The deck itself: plated, with the plates laid in strips that catch the light
	# differently, and a lip all round so the edge is not a cut line.
	for i in 5:
		var z0 := -DECK + i * (DECK * 2.0 / 5.0)
		var z1 := z0 + DECK * 2.0 / 5.0 - 0.04
		var tone := deck if i % 2 == 0 else P.PLATE[3]
		# WOUND TO FACE THE SKY. The obvious order (-X, +X, +X, -X) gives
		# cross(+X, +Z) = -Y and lays the whole deck face down at the seabed:
		# 1700 cells of it that no bearing of the play camera could ever see.
		k.found.quad(Vector3(-DECK, DECK_Y, z0), Vector3(-DECK, DECK_Y, z1),
			Vector3(DECK, DECK_Y, z1), Vector3(DECK, DECK_Y, z0), tone)
	k.chamfer(0.0, DECK_Y - 0.26, 0.0, DECK * 2.0, 0.26, DECK * 2.0, 0.08, P.PLATE[1], edge)
	# The handrail, on three sides. The gap faces +X, which is where the ladder is.
	for side in 3:
		var a := Vector3(DECK - 0.15, DECK_Y, -DECK + 0.15)
		var b := Vector3(-DECK + 0.15, DECK_Y, -DECK + 0.15)
		if side == 1:
			a = Vector3(-DECK + 0.15, DECK_Y, -DECK + 0.15)
			b = Vector3(-DECK + 0.15, DECK_Y, DECK - 0.15)
		elif side == 2:
			a = Vector3(-DECK + 0.15, DECK_Y, DECK - 0.15)
			b = Vector3(DECK - 0.15, DECK_Y, DECK - 0.15)
		var n := 5
		for i in n + 1:
			var p: Vector3 = a.lerp(b, float(i) / float(n))
			# One stanchion in each run is bent or gone: the sea took it.
			if i == (absi(s + side) % (n + 1)) and i != 0 and i != n:
				continue
			k.rod(p, p + Vector3(0, 0.92, 0), 0.05, 4, P.PLATE[1])
		var top := Vector3(0, 0.92, 0)
		k.rod(a + top, b + top, 0.045, 4, P.PLATE[2])
		k.rod(a + top * 0.55, b + top * 0.55, 0.035, 4, P.PLATE[1])
	# The ladder down into the water on the open side, hung OUTSIDE the deck edge.
	# Inside it (at DECK - 0.05) the deck's own lip overhangs it and the play
	# camera cannot see a rung from any bearing: ten FOUND pieces nobody would
	# ever have looked at (`tests/render/test_found_drawn.gd` caught it).
	var lx := DECK + 0.16
	for i in 7:
		var y := DECK_Y - 0.1 - i * 0.32
		k.rod(Vector3(lx, y, -0.32), Vector3(lx, y, 0.32), 0.035, 4, P.RUST[2] if i > 3 else P.PLATE[1])
	for sz2: float in [-0.32, 0.32]:
		k.rod(Vector3(lx, DECK_Y + 0.5, sz2), Vector3(lx, -1.0, sz2), 0.045, 4, P.PLATE[1])


## The tank, drained and open. It is the whole reason the place is in the game, so
## it is read from any bearing: a tall glass cylinder in a steel cradle, its door
## swung wide and never shut again, and the stain of what drained out of it.
static func tank(k: Kit, v: int, c: int) -> void:
	var s := 41200 + v + c
	# A MAN'S HEIGHT AND A MAN'S WIDTH, because that is the whole point of it:
	# the first version was as wide as it was tall and read as a squat vat, which
	# says nothing about what was grown in it.
	var glass := Color(0.62, 0.78, 0.80, 1.0)
	var rad := 0.5
	var high := 2.55
	# The cradle: a foot ring, a head ring and four uprights.
	# The foot ring sits ON the base plate, not inside it: at 0.06 it was buried
	# in its own 0.18-deep plinth.
	for y: float in [0.25, high - 0.1]:
		k.hoop(Vector3(0, y, 0), rad + 0.1, 12, 0.07, P.PLATE[2])
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		var p := Vector3(cos(a) * (rad + 0.1), 0.0, sin(a) * (rad + 0.1))
		k.rod(p, p + Vector3(0, high, 0), 0.075, 5, P.PLATE[1])
	k.chamfer(0.0, 0.0, 0.0, 1.4, 0.18, 1.4, 0.05, P.PLATE[1], P.PLATE[2])
	# The cylinder: eleven facets rather than a smooth tube, so the light breaks
	# across it the way it does on every other FOUND thing here.
	var n := 11
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		# The door is the two facets that are missing.
		if i == 0 or i == 1:
			continue
		var p0 := Vector3(cos(a0) * rad, 0.16, sin(a0) * rad)
		var p1 := Vector3(cos(a1) * rad, 0.16, sin(a1) * rad)
		var up := Vector3(0, high - 0.3, 0)
		k.found.quad(p0, p1, p1 + up, p0 + up, glass)
	# INSIDE IT: the rail a body was held on, and the line the fluid stood at
	# until somebody opened the door. Seen through the glass, they are what says
	# a person was in here rather than a chemical.
	k.rod(Vector3(0, 0.3, 0), Vector3(0, high - 0.5, 0), 0.055, 5, P.PLATE[0])
	# Two, low enough to be seen through the glass from a camera that looks down:
	# a third at 1.79 sat behind the head and was never drawn.
	for i in 2:
		var y := 0.6 + float(i) * 0.55
		k.hoop(Vector3(0, y, 0), 0.21, 7, 0.035, P.PLATE[1])
	k.hoop(Vector3(0, high - 0.72, 0), rad - 0.02, 11, 0.02, P.EARTH[2])
	# The door itself, hinged open and hanging: a steel frame with the glass in it.
	# Swung wide and never shut again: a door standing at 66 degrees off its own
	# frame is the one thing in this model that has to read from across the water.
	k.found.push(Transform3D(Basis(Vector3.UP, -1.15), Vector3(rad * 0.95, 0.16, rad * 0.5)))
	k.chamfer(0.3, 1.1, 0.0, 0.64, high - 0.42, 0.09, 0.03, P.PLATE[2], P.PLATE[3])
	k.found.quad(Vector3(0.04, 0.16, 0.042), Vector3(0.56, 0.16, 0.042),
		Vector3(0.56, high - 0.5, 0.042), Vector3(0.04, high - 0.5, 0.042), glass)
	# Its handle, on the outside, where a hand that was not his own turned it.
	k.rod(Vector3(0.5, 0.9, -0.05), Vector3(0.5, 1.35, -0.05), 0.035, 4, P.PLATE[4])
	k.found.pop()
	# The head: pipework that fed it, cut and capped.
	k.chamfer(0.0, high - 0.02, 0.0, 1.15, 0.3, 1.15, 0.07, P.PLATE[3], P.PLATE[4])
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.9
		var p := Vector3(cos(a) * 0.38, high + 0.28, sin(a) * 0.38)
		k.rod(p, p + Vector3(Kit.j(s, i, 0.3), 0.55 + Kit.j(s, i + 4, 0.25), Kit.j(s, i + 8, 0.3)), 0.09, 5, P.PLATE[1])
	# One strip still lit across the head: the site has power and nobody living.
	k.found.quad(Vector3(-0.48, high + 0.29, 0.26), Vector3(0.48, high + 0.29, 0.26),
		Vector3(0.48, high + 0.29, 0.14), Vector3(-0.48, high + 0.29, 0.14), Works.STRIP)
	# What drained out of it, dried on the deck under the open door.
	for i in 5:
		# Clear of the tank's own base plate (1.4 across), or half of them lie
		# under it where no bearing reaches them.
		var p := Vector3(1.05 + Kit.j(s, i, 0.5), 0.012, Kit.j(s, i + 20, 1.1))
		k.found.quad(p + Vector3(-0.3, 0, -0.26), p + Vector3(-0.26, 0, 0.24),
			p + Vector3(0.28, 0, 0.3), p + Vector3(0.34, 0, -0.2), P.RUST[1] if i % 2 else P.EARTH[1])


## A screen on a stalk, tilted to be read standing. Two of these are what the
## site has to say (`StoryProps.READABLE`), so the GLASS has to be the thing the
## eye lands on: everything else is a bracket holding it at reading height.
static func console(k: Kit, v: int, c: int) -> void:
	var s := 41300 + v + c
	k.chamfer(0.0, 0.0, 0.0, 0.62, 0.14, 0.5, 0.04, P.PLATE[1], P.PLATE[2])
	k.rod(Vector3(0, 0.1, 0), Vector3(0, 0.82, 0), 0.09, 6, P.PLATE[2])
	# The head, leaned back so a standing body reads it and the camera sees it.
	k.found.push(Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0.0, 0.86, 0.0)))
	k.chamfer(0.0, 0.0, 0.0, 0.72, 0.5, 0.14, 0.03, P.PLATE[2], P.PLATE[3])
	# The glass, and the one line still running on it.
	k.found.quad(Vector3(-0.29, 0.06, 0.076), Vector3(0.29, 0.06, 0.076),
		Vector3(0.29, 0.44, 0.076), Vector3(-0.29, 0.44, 0.076), Color(0.10, 0.16, 0.19, 1.0))
	for i in 4:
		var y := 0.12 + i * 0.08
		var w := 0.10 + fmod(float(i) * 0.37 + float(absi(s) % 5) * 0.11, 0.34)
		k.found.quad(Vector3(-0.24, y, 0.078), Vector3(-0.24 + w, y, 0.078),
			Vector3(-0.24 + w, y + 0.035, 0.078), Vector3(-0.24, y + 0.035, 0.078),
			Works.lit(Works.STRIP, 0.6 if i != 1 else 0.88))
	k.found.pop()
	# A cable off the back, run to the deck and left there.
	k.cable(Vector3(0.0, 0.8, -0.1), Vector3(Kit.j(s, 1, 0.7), 0.03, -0.55 - absf(Kit.j(s, 2, 0.4))), 0.12, 5, 0.03, P.INK[2])
