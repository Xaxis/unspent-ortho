extends TestCase
## A put farther than GenWorks.VILLAGE_FAR from a village is never refused by it,
## so `_put` may pass that village without working out its lobe: the same world,
## without asking every village's lobe on every put.


func test_no_lobe_reaches_past_the_far_bound() -> void:
	var most := 0.0
	for s: int in [1, 7, 42, 90210]:
		for k in 200:
			var v := {"pos": Vector2(37.0 + k * 9.3, 1840.0 - k * 7.1)}
			for a in 720:
				var ang := a * TAU / 720.0
				var reach := GenSettle.village_core(s, v, ang) + GenWorks.VILLAGE_KEEP
				most = maxf(most, reach)
				if reach >= GenWorks.VILLAGE_FAR:
					fail("seed %d village %s refuses a put %.4f out at %.3f rad, past the bound %.4f" % [s, v.pos, reach, ang, GenWorks.VILLAGE_FAR])
					return
	# And the bound is the lobe's real top, not a loose one that skips nothing.
	gt(most, GenWorks.VILLAGE_FAR - 0.05, "the widest lobe seen (%.4f) comes within 0.05 of the bound" % most)
