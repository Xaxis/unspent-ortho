extends TestCase
## THE TETHER (src/core/orbit/tether.gd, drawn by orbit_sky.gdshaderinc): a line
## off the far shore's horizon up to the Foundry, fixed in the sky. It stands on
## the bearing from the spawn to the far shore's works, the Foundry at an
## elevation in its range, the same every time for a world.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_it_rises_off_the_far_shore_to_a_fixed_foundry() -> void:
	var g := Sx.game(tree, ["--seed=1", "--hour=12", "--weather=clear:0"])
	var w := g.world
	var placed := StoryPlan.cast(w)
	check(placed.has(&"the_far_works"), "the far shore's works are placed in this world")
	if placed.has(&"the_far_works"):
		var to: Vector2 = (placed[&"the_far_works"].pos as Vector2) - w.spawn
		near(angle_difference(Tether.bearing(w), atan2(to.y, to.x)), 0.0, 1e-4, "on the bearing from the spawn to the far works")
	var e := Tether.top(w)
	check(e >= Tether.TOP_LEAST and e <= Tether.TOP_MOST, "the Foundry stands between %.0f and %.0f degrees up" % [rad_to_deg(Tether.TOP_LEAST), rad_to_deg(Tether.TOP_MOST)])
	var f := Tether.foundry(w)
	near(f.length(), 1.0, 1e-5, "a direction")
	near(asin(f.y), e, 1e-5, "at that elevation")
	near(Vector2(f.x, f.z).angle(), Tether.bearing(w), 1e-4, "over the foot")
	eq(Tether.foundry(w), f, "and fixed: the same answer every time")
	# The ring's system hands the sky that same plane.
	var orbit := Sx.system(g, "19_orbit")
	eq(orbit.get("_tether_flat"), Tether.flat(w), "19_orbit draws it where Tether says")
	near(float(orbit.get("_tether_top")), e, 1e-6)
	Sx.end(g)
