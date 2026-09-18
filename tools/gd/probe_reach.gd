extends SceneTree
## How far the spawn is from the nearest prop that can give each named item.
##
## Throwaway, for one question: `test_progression` pins seed 2 and asserts the
## whole first chain is reachable within 100 tiles. Adding a landscape moves
## every seed's island, so that test goes red whenever one lands -- and the
## decision "re-baseline or fix the content" needs a NUMBER, because 105 tiles
## and 400 tiles are different answers wearing the same red.
##
##   godot --headless --path . -s tools/gd/probe_reach.gd -- --seeds=1,2,3,4,42
##
## Distance is straight-line from the spawn to the nearest prop of a kind that
## `Takes` says can yield the item at all. It ignores whether the bot has the
## tool yet, which is the test's business -- this only answers "is it THERE".

const WANT: Array[StringName] = [&"deadwood", &"timber", &"iron_ore", &"stone", &"plate"]
const SIZE := 512


func _init() -> void:
	var seeds: Array[int] = [1, 2, 3, 4, 42]
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = []
			for s: String in a.trim_prefix("--seeds=").split(","):
				seeds.append(s.to_int())

	# Which prop kinds can give each item at all.
	var kinds_for: Dictionary = {}
	for item: StringName in WANT:
		var ks: Dictionary = {}
		for kind: int in Takes.table():
			for o: Dictionary in Takes.options(kind):
				if o.get("item", &"") == item:
					ks[kind] = true
		kinds_for[item] = ks

	print("nearest prop that can give each item, in tiles from the spawn")
	var head := "seed  "
	for item: StringName in WANT:
		head += "%14s" % item
	print(head)

	for sv: int in seeds:
		var w := BootWorld.world(sv, SIZE)
		var line := "%-6d" % sv
		for item: StringName in WANT:
			var ks: Dictionary = kinds_for[item]
			var best := INF
			for p: WorldProp in w.props:
				if not ks.has(p.kind):
					continue
				var d := w.spawn.distance_to(p.pos)
				if d < best:
					best = d
			line += "%14s" % ("none" if best == INF else "%.1f" % best)
		print(line)
	quit()
