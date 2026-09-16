extends TestCase
## The twelve per-kind ramps against the Palette contract (CLAUDE.md) and
## docs/ART.md §4, §5. They had drifted into one mid-value lavender: at the body
## fill the largest per-channel gap between ANY two of the twelve was 19/255, and
## every machine stood lighter than the turf it was standing on, so by day a
## machine was a pale slab and no player could tell a harvester from a warden.
##
## Measured, not eyeballed:
##   no two kinds meet at the step that fills their faces
##   the day-lit fill is darker than the coast turf a machine walks on
##   the top of each ramp is compressed and desaturated, so the amber LENS stays
##   the one saturated thing on a machine
##   the arc is cold: nothing on a body is a warm hue

const KINDS: Array[StringName] = [&"watcher", &"longlegs", &"harvester", &"cutter", &"hauler", &"warden", &"sweeper", &"dredger", &"lineman", &"flock", &"runner", &"clerk"]
## The step FoundKit paints every up-facing body panel with: what a player sees
## most of from a camera pitched 57 degrees down.
const FILL := 3
## How far apart two kinds must sit at that step. Value differences read first, so
## luma is weighted double; 0.06 is a gap a player can see in a lineup, and the
## wave-N ramps managed 0.02.
const MIN_APART := 0.06


static func luma(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


## Luma-weighted distance: how far apart two body fills look.
static func apart(a: Color, b: Color) -> float:
	var dl := luma(a) - luma(b)
	return sqrt(dl * dl * 2.0 + (a.r - b.r) * (a.r - b.r) + (a.g - b.g) * (a.g - b.g) + (a.b - b.b) * (a.b - b.b))


func test_every_kind_has_a_ramp() -> void:
	for kid in KINDS:
		var r: Array = Palette.MACHINE.get(String(kid), [])
		eq(r.size(), 6, "%s ramp length" % kid)
	eq(Palette.MACHINE.size(), KINDS.size(), "one ramp per kind and no strays")


func test_no_two_kinds_meet_at_the_step_that_fills_their_faces() -> void:
	var worst := INF
	var pair := ""
	for i in KINDS.size():
		for j in range(i + 1, KINDS.size()):
			var a: Color = Palette.MACHINE[String(KINDS[i])][FILL]
			var b: Color = Palette.MACHINE[String(KINDS[j])][FILL]
			var d := apart(a, b)
			if d < worst:
				worst = d
				pair = "%s vs %s" % [KINDS[i], KINDS[j]]
	gt(worst, MIN_APART, "closest pair %s is %.4f apart" % [pair, worst])


func test_the_day_lit_fill_is_darker_than_the_ground_it_stands_on() -> void:
	# Coast turf, the ground the game opens on and the ground the review lineup
	# uses. A machine lighter than this reads as plastic in daylight.
	var turf := luma(Palette.MOSS[3])
	for kid in KINDS:
		var fill: Color = Palette.MACHINE[String(kid)][FILL]
		lt(luma(fill), turf, "%s fill luma %.3f vs turf %.3f" % [kid, luma(fill), turf])
		# And not so dark that it cannot hold an inked silhouette against night.
		gt(luma(fill), 0.16, "%s fill luma %.3f" % [kid, luma(fill)])


func test_the_ramps_climb_and_their_tops_are_compressed() -> void:
	for kid in KINDS:
		var r: Array = Palette.MACHINE[String(kid)]
		for i in 5:
			gt(luma(r[i + 1]), luma(r[i]), "%s step %d is lighter than %d" % [kid, i + 1, i])
		# The climb 3 -> 5 (fill to rivets) is a fraction of the climb 0 -> 3.
		var low := luma(r[FILL]) - luma(r[0])
		var top := luma(r[5]) - luma(r[FILL])
		lt(top, low * 0.75, "%s top is compressed (%.3f over %.3f)" % [kid, top, low])


func test_the_arc_is_cold_and_low_chroma() -> void:
	for kid in KINDS:
		var r: Array = Palette.MACHINE[String(kid)]
		for i in r.size():
			var c: Color = r[i]
			# Violet: blue leads, green never does. A warm body would put the amber
			# working part in competition with the machine it is set into.
			gt(c.b, c.g - 0.004, "%s step %d is not warm" % [kid, i])
			lt(c.s, 0.42, "%s step %d chroma %.2f" % [kid, i, c.s])
		# Every ramp is duller than the amber it carries.
		lt(float(r[FILL].s), Palette.LENS[2].s * 0.62, "%s fill is duller than the lens" % kid)


func test_a_machine_is_built_in_its_own_ramp_and_kinds_do_not_share_one() -> void:
	var seen := {}
	for kid in KINDS:
		var key := "%s" % Palette.MACHINE[String(kid)][FILL]
		check(not seen.has(key), "%s and %s share a body fill" % [kid, seen.get(key, "")])
		seen[key] = kid
