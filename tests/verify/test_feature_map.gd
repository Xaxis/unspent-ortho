extends TestCase

## EVERY SYSTEM IS ON THE FEATURE MAP. `featuremap check` compares the map with
## what its own config lists, and this project lists its systems by hand
## (`manual` in .claude/skills/verify/featuremap.config.json): the tool cannot see
## `src/systems/NN_*.gd`, so a system nobody listed is invisible to it, and the
## check passes. 19_orbit and 58_guide were both missing with the check green,
## and a feature with no entry is one `featuremap affected` never asks anyone to
## re-check. So the list is held against the directory here.
func test_every_system_has_a_feature_map_entry() -> void:
	var text := FileAccess.get_file_as_string("res://.claude/skills/verify/featuremap.config.json")
	check(text != "", "the feature map's config is readable")
	var parsed: Variant = JSON.parse_string(text)
	check(parsed is Dictionary, "and is JSON")
	if not parsed is Dictionary:
		return
	var listed := {}
	for m: Variant in (parsed as Dictionary).get("manual", []):
		if m is Dictionary and str((m as Dictionary).get("kind", "")) == "system":
			listed[str((m as Dictionary).get("entry", ""))] = true
	var dir := DirAccess.open("res://src/systems")
	check(dir != null, "src/systems is readable")
	if dir == null:
		return
	var seen := 0
	for f: String in dir.get_files():
		# The base class every system extends is not a system of its own.
		if not f.ends_with(".gd") or f == "game_system.gd":
			continue
		seen += 1
		check(listed.has("src/systems/" + f),
			"src/systems/%s is on the feature map (add it to featuremap.config.json's `manual`, then `featuremap generate --write`)" % f)
	gt(float(seen), 40.0, "the systems were found (%d)" % seen)
