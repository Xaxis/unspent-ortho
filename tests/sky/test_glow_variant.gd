extends TestCase
## A light is read off the model that is actually on screen.
##
## World gen may DEAL a prop its model (`WorldProp.variant`) and a landscape has
## its own variants of a kind, so "where does this thing glow" has three inputs
## and not one. Asking `PropModels.glow_points(kind)` alone answers for coast
## variant 0 every time -- and on seed 7 that was 142 of the 884 lit props in the
## world: 74 houses, 47 shacks, 16 murals, lit where another model runs its tube.
##
## It is checked by READING THE SHIPPED SOURCE, the way `test_causes_are_live`
## does, because the bug is a caller passing too few arguments and the failure is
## silent -- the default is a real model, so nothing errors and nothing is
## missing. 15_lights states the rule in a comment and broke it twenty lines
## above, so a comment is not enough to hold it.


func test_no_light_is_read_off_the_default_model() -> void:
	var f := FileAccess.open("res://src/systems/15_lights.gd", FileAccess.READ)
	check(f != null, "15_lights.gd is readable")
	if f == null:
		return
	var n := 0
	for i: int in range(1, 100000):
		if f.eof_reached():
			break
		var line := f.get_line()
		var at := line.find("glow_points(")
		if at < 0 or line.strip_edges().begins_with("#") or line.strip_edges().begins_with("##"):
			continue
		# The declaration itself carries the defaults on purpose.
		if line.contains("static func glow_points("):
			continue
		var args := line.substr(at + len("glow_points(")).split(")")[0]
		n += 1
		check(args.split(",").size() >= 3,
			"line %d reads a light off the default model: `%s`. Pass the prop's own variant and country (see `_points_for`)." % [i, line.strip_edges()])
	gt(float(n), 0.0, "the calls were found at all")
