extends TestCase
## A MACHINE HAS MASS AT PLAY DISTANCE (art finding 3).
##
## `test_machines_silhouette.gd` holds the other end of this: no machine may be a
## filled box, and its ratchet only ever comes down. The watcher showed what a
## bar with one end does — at 0.25 it is the emptiest thing in the roster, and
## close up it is a beautiful surveyor's instrument, but the one a player sees
## from a hill away is "a thin mast and three splayed legs of scattered violet
## pixels", with nothing in it wide enough to carry a chamfer, a rivet row or a
## visor slit. Its own file said so: "its members are two screen pixels wide".
##
## So this file measures the other thing: how much of what a machine draws is
## BODY rather than edge. A member two pixels wide is all edge and has no
## interior at all; a hull has a middle. The share of a silhouette's pixels that
## are surrounded on all four sides is what separates the two, and it is the
## number that says whether the machine reads as a mass or as a scribble.

const S := preload("res://tests/models/test_machines_silhouette.gd")


## Share of the drawn pixels that have drawn pixels on all four sides.
static func body_share(mask: PackedByteArray) -> float:
	var on := 0
	var inside := 0
	for y in range(1, S.H - 1):
		for x in range(1, S.W - 1):
			if mask[y * S.W + x] == 0:
				continue
			on += 1
			if mask[y * S.W + x - 1] != 0 and mask[y * S.W + x + 1] != 0 \
					and mask[(y - 1) * S.W + x] != 0 and mask[(y + 1) * S.W + x] != 0:
				inside += 1
	return float(inside) / maxf(1.0, float(on))


## The floor, per kind, pinned two hundredths BELOW where each stands today — the
## mirror of the silhouette file's ratchet, and for the same reason: one number
## for the whole roster would be a rubber stamp. A kind may only gain mass.
const BODY := {
	&"harvester": 0.60, &"hauler": 0.58, &"dredger": 0.50, &"sweeper": 0.48,
	&"warden": 0.45, &"clerk": 0.42, &"runner": 0.40, &"cutter": 0.34,
	&"lineman": 0.30, &"longlegs": 0.24, &"watcher": 0.50, &"flock": 0.05,
}
## What a kind nobody has pinned yet must carry: the floor for the thirteenth machine.
const LEAST_BODY := 0.22


func test_every_machine_is_a_mass_and_not_a_scribble() -> void:
	var lines: PackedStringArray = []
	for kid: StringName in S.KINDS:
		var bar: float = float(BODY.get(kid, LEAST_BODY))
		var worst := 1.0
		for yaw: float in [0.6, 2.3]:
			var m := S.posed(kid, &"stand")
			var b := body_share(S.silhouette(m, yaw))
			m.free()
			worst = minf(worst, b)
		lines.append("  %-10s %.2f (floor %.2f)" % [kid, worst, bar])
		gt(worst, bar, "%s is %.2f body: a member two pixels wide carries no chamfer, "
			% [kid, worst] + "no rivet row and no slit (floor %.2f)" % bar)
	print("what share of each machine is body, not edge:\n", "\n".join(lines))
