extends RefCounted
## THE ORCHARDS' SPRAYER: the machine that still does the job. A portal frame
## straddling one row on its own wheeled legs, running up and down the row on
## the schedule, a boom across its top hung with nozzles over the crowns, a
## tank on one leg and the hose from it to the boom. It is the plan's (Takes
## PLAN_WORKS: robbing it is theft), and what lays the orchards' evening mist
## (BiomeDef.mist_dusk). Variant 1 has stopped mid-row with a leg off its rail,
## its boom sagging; variant 2 is spraying now, a bead at every nozzle.
##
## A model faces +X and straddles the row that runs along +X: its legs stand
## either side of the tree line at z = +-HALF.
##
##   tools/shot.sh shots/sprayer.png --scene=gallery --filter="sprayer gantry"

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")

## Half the gap between the legs (a row is ROW_GAP 3.2 apart, a tree ~1.6 wide).
const HALF := 1.25
## Boom height over the ground: above a pollard's crown.
const BOOM := 2.55


static func build(k: Kit, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	var s := 9700 + v * 31 + c * 5
	# Plain colours on every FOUND piece (rods, chamfers, prisms on k.found): a
	# made mark there is read as a light built into the machine, and blinks.
	var frame := P.PLATE[2].lerp(P.LINEN[3], 0.2)
	var paint := P.COPPER[2].lerp(P.ASH[3], 0.45)
	var paint_made := GroundColors.made(paint, GroundColors.ENAMEL)
	var dark := P.INK[2]
	var tank_col := GroundColors.made(P.LINEN[3].lerp(P.SPRUCE[2], 0.25), GroundColors.ENAMEL)
	var stopped := v % 3 == 1
	var sag := 0.35 if stopped else 0.0
	# The rails it runs on, a pair of worn steel strips along the row either side.
	for side: float in [-1.0, 1.0]:
		k.slab(0.0, -0.03, side * HALF, 3.4, 0.05, 0.12, s + int(side + 2.0), P.PLATE[1], P.PLATE[3], 0.0)
	# Two legs each side, a bogie of two wheels under each pair.
	for side: float in [-1.0, 1.0]:
		var lift := 0.22 if stopped and side > 0.0 else 0.0
		for end: float in [-0.5, 0.5]:
			var foot := Vector3(end, 0.12 + lift, side * HALF)
			k.rod(foot, Vector3(end * 0.35, BOOM - (sag if side > 0.0 else 0.0), side * (HALF - 0.08)), 0.05, 5, frame)
			k.found.prism(foot.x, 0.0 + lift, foot.z, 0.13, 0.26 + lift, 0.13, 8, dark)
		# The bogie beam and its motor box.
		k.chamfer(0.0, 0.2 + lift, side * HALF, 1.2, 0.16, 0.18, 0.03, paint)
		k.chamfer(0.3, 0.36 + lift, side * HALF, 0.34, 0.22, 0.24, 0.03, paint, P.ASH[3])
	# The boom across the top, and the long spray bar along the row under it.
	var l := Vector3(0.0, BOOM, -HALF)
	var r := Vector3(0.0, BOOM - sag, HALF)
	k.slab(0.0, BOOM - 0.1, 0.0, 0.26, 0.16, HALF * 2.1, s + 5, paint_made, GroundColors.made(GroundColors.up(paint, 0.2), GroundColors.ENAMEL), 0.0, 0.0, 0.0)
	var bar_y := BOOM - 0.22 - sag * 0.5
	k.rod(Vector3(-1.3, bar_y, 0.0), Vector3(1.3, bar_y, 0.0), 0.025, 5, frame)
	k.rod(l + Vector3(0, -0.02, 0.06), Vector3(0.0, bar_y, 0.0), 0.02, 4, frame)
	k.rod(r + Vector3(0, -0.02, -0.06), Vector3(0.0, bar_y, 0.0), 0.02, 4, frame)
	# Nozzles down the bar, each a short drop with a cone, stained round the tip.
	for i in 7:
		var x := -1.2 + float(i) * 0.4
		var tip := Vector3(x, bar_y - 0.16, 0.0)
		k.rod(Vector3(x, bar_y, 0.0), tip, 0.012, 4, dark)
		k.found.prism(tip.x, tip.y - 0.05, tip.z, 0.035, tip.y, 0.012, 6, P.COPPER[2])
		if v % 3 == 2:
			# Spraying now: a bead of it hanging from every nozzle (the haze
			# itself is the evening's mist, BiomeDef.mist_dusk).
			var bead := tip + Vector3(0, -0.09, 0)
			k.fleck(bead, bead + Vector3(0.025, -0.03, 0.0), bead + Vector3(-0.02, -0.035, 0.01), P.LINEN[4].lerp(P.MOSS[4], 0.2))
	# The tank on the near leg, and the hose from it up to the boom.
	var tank := Vector3(-0.2, 1.05, -HALF - 0.32)
	k.made.prism(tank.x, tank.y - 0.35, tank.z, 0.24, tank.y + 0.35, 0.24, 8, tank_col, GroundColors.up(tank_col, 0.15))
	k.hoop(tank + Vector3(0, 0.2, 0), 0.25, 10, 0.012, P.PLATE[2])
	k.hoop(tank + Vector3(0, -0.2, 0), 0.25, 10, 0.012, P.PLATE[2])
	k.cable(tank + Vector3(0, 0.36, 0), l + Vector3(-0.1, 0.0, 0.08), 0.18, 7, 0.022, dark)
	# The residue: what it lays on the crowns lies on it too, a pale crust along
	# the top of the boom and down the legs.
	k.slab(0.0, BOOM + 0.06, 0.0, 0.2, 0.012, HALF * 1.9, s + 9, P.LINEN[4], P.LINEN[4], 0.01)
	# Its number, stencilled on the bogie.
	for side: float in [-1.0, 1.0]:
		var at := Vector3(-0.1, 0.34, side * (HALF + 0.095 * side))
		k.face(at + Vector3(-0.12, 0.0, 0.0), at + Vector3(0.12, 0.0, 0.0), at + Vector3(0.12, 0.08, 0.0), at + Vector3(-0.12, 0.08, 0.0), P.LINEN[3])
	if stopped:
		# Stopped with a leg off its rail: the bogie tipped, weed up round it.
		k.clump(0.0, -0.05, HALF + 0.2, 0.3, 0.18, s + 20, P.MOSS[2].lerp(P.ASH[2], 0.4), 6)
