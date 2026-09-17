extends TestCase
## The web path's floor (docs/LOOK.md, "Web is the graceful degradation path").
##
## The failure this guards is the one the first side-by-side found: every web
## frame lifted and flattened, a mean distance of 44 from the desktop's, with a
## green gate. Nothing about it was loud. So what is held here is the plumbing that
## keeps the web's light counted back (CompatTrim) and the tools that can prove it
## again (RenderProbe, the fit tour), because the numbers themselves can only be
## judged by rendering and the frames are where that happens.


func test_every_trim_row_says_every_key_and_nothing_wild() -> void:
	var rows := {"SHADOWED_DAY": CompatTrim.SHADOWED_DAY, "SHADOWED_NIGHT": CompatTrim.SHADOWED_NIGHT,
		"OPEN_DAY": CompatTrim.OPEN_DAY, "OPEN_NIGHT": CompatTrim.OPEN_NIGHT}
	for name: String in rows:
		var r: Dictionary = rows[name]
		for k: String in CompatTrim.KEYS:
			check(r.has(k), "%s says %s" % [name, k])
			var v := float(r.get(k, -1.0))
			# A multiplier of zero turns a light off, and over two is a fit that
			# ran away; neither is a count-back.
			check(v > 0.0 and v <= 2.0, "%s.%s is a count-back (%.2f)" % [name, k, v])
		eq(r.size(), CompatTrim.KEYS.size(), "%s says nothing else" % name)
	eq(CompatTrim.IDENTITY.size(), CompatTrim.KEYS.size(), "the identity names every key")
	for k: String in CompatTrim.KEYS:
		eq(float(CompatTrim.IDENTITY[k]), 1.0, "the identity is ones (%s)" % k)


func test_the_row_blends_by_night_and_steps_aside_for_a_fit() -> void:
	if Quality.forward_plus():
		eq(CompatTrim.row(true, 0.0), CompatTrim.IDENTITY, "Forward+ counts nothing back")
		return
	for k: String in CompatTrim.KEYS:
		eq(float(CompatTrim.row(true, 0.0)[k]), float(CompatTrim.SHADOWED_DAY[k]), "noon under a casting sun is the day row (%s)" % k)
		eq(float(CompatTrim.row(true, 1.0)[k]), float(CompatTrim.SHADOWED_NIGHT[k]), "midnight is the night row (%s)" % k)
		eq(float(CompatTrim.row(false, 0.0)[k]), float(CompatTrim.OPEN_DAY[k]), "an overcast noon is the open row (%s)" % k)
	var half := CompatTrim.row(true, 0.5)
	near(float(half.sun), lerpf(float(CompatTrim.SHADOWED_DAY.sun), float(CompatTrim.SHADOWED_NIGHT.sun), 0.5), 0.0001, "dusk is between")
	CompatTrim.override = {"sun": 0.5}
	eq(CompatTrim.row(true, 0.0), {"sun": 0.5}, "a fit in progress is what is in force")
	CompatTrim.override = {}


## The places the trim has to reach, by reading them: a multiplier nothing applies
## is a table that looks like a fix.
func test_the_light_is_counted_back_where_it_is_composed() -> void:
	var sky := FileAccess.get_file_as_string("res://src/render/sky_light.gd")
	check(sky.contains("CompatTrim.row("), "SkyLight picks the row")
	check(sky.contains("CompatTrim.remember("), "and hands it to the lamps")
	for key: String in ["trim.sun", "trim.ambient", "trim.fog", "trim.glow", "trim.exposure", "trim.emission"]:
		check(sky.contains(key), "SkyLight spends %s" % key)
	var lights := FileAccess.get_file_as_string("res://src/systems/15_lights.gd")
	check(lights.contains("CompatTrim.lamp_gain()"), "a lamp's energy is counted back")
	var matter := FileAccess.get_file_as_string("res://src/render/matter.gdshaderinc")
	check(matter.contains("return matter_albedo(srgb) * sky_emission;"), "emission goes through the one door with its count-back")
	var proj := FileAccess.get_file_as_string("res://project.godot")
	var at := proj.find("sky_emission={")
	check(at >= 0, "project.godot registers sky_emission")
	# Unregistered or defaulted to 0, every emissive thing in the game goes dark
	# before SkyLight's first frame, and on any scene that has no SkyLight at all.
	check(proj.substr(at, 60).contains("\"value\": 1.0"), "and it starts at 1")


func test_only_a_tier_without_volumetrics_stands_in_for_them() -> void:
	for r: Dictionary in Quality.ROWS:
		if bool(r.volumetric):
			eq(float(r.air_stand_in), 0.0, "%s has real air and no stand-in" % r.id)
	gt(float(Quality.row(&"web").air_stand_in), 0.0, "the web's depth fog stands in for the bank")
	var sky := FileAccess.get_file_as_string("res://src/render/sky_light.gd")
	check(sky.contains('Quality.current().get("air_stand_in"'), "SkyLight reads it off the row")


## tours/degrade_fit.tour is tours/canon.tour with every shot replaced by a fit,
## so the desktop frames it reads are the canon's own. If the canon moves and the
## fit does not, it fits against a different moment than it stages.
func test_the_fit_stages_what_the_canon_shoots() -> void:
	var canon := _commands("res://tours/canon.tour")
	var fit := _commands("res://tours/degrade_fit.tour")
	var i := 0
	for line: String in canon:
		if i >= fit.size():
			check(false, "the fit ends before the canon does, at '%s'" % line)
			return
		if line.begins_with("shot "):
			var name := line.split(" ")[1]
			check(fit[i] == "perf match shots/degrade/desktop/%s.png" % name,
				"the canon's %s is fitted at the same line (the fit has '%s')" % [name, fit[i]])
		else:
			eq(fit[i], line, "the fit stages the canon's '%s'" % line)
		i += 1
	for t: String in ["res://tours/degrade.tour", "res://tours/degrade_cost.tour", "res://tours/degrade_grey.tour"]:
		check(FileAccess.file_exists(t), "%s is there to run again" % t)


func test_every_measurement_the_tours_ask_for_exists() -> void:
	for t: String in ["res://tours/degrade.tour", "res://tours/degrade_cost.tour", "res://tours/degrade_fit.tour"]:
		for line: String in _commands(t):
			if line.begins_with("perf ") and line.split(" ")[1] != "fore" and line.split(" ")[1] != "folk":
				check(RenderProbe.KINDS.has(line.split(" ")[1]), "%s: perf %s is a RenderProbe measurement" % [t, line.split(" ")[1]])


func _commands(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	for raw: String in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		out.append(line)
	return out
