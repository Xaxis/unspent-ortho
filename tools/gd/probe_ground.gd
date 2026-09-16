extends SceneTree
## One-off probe (disposition package): where a ground and a prop kind are on a
## seed, so a tour can stand on real heath and beside a real machine work
## instead of on coordinates a new world moves.
##   godot --headless --path . -s tools/gd/probe_ground.gd -- --seed=1 --ground=heath --near=200,431


func _initialize() -> void:
	var seed_value := 1
	var ground_name := "heath"
	var near := Vector2(-1, -1)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = a.trim_prefix("--seed=").to_int()
		elif a.begins_with("--ground="):
			ground_name = a.trim_prefix("--ground=")
		elif a.begins_with("--near="):
			var p := a.trim_prefix("--near=").split(",")
			near = Vector2(p[0].to_float(), p[1].to_float())
	var world := BootWorld.world(seed_value, 512)
	if near.x < 0.0:
		near = world.spawn
	print("spawn %s" % world.spawn)
	var g := Ground.NAMES.find(ground_name)
	var best := Vector2.INF
	var best_d := INF
	var patches := 0
	for y in range(0, world.size, 2):
		for x in range(0, world.size, 2):
			if world.ground_at(x, y) != g:
				continue
			# A patch, not a stray tile: eight of its neighbours the same.
			var same := 0
			for dy: int in [-2, 0, 2]:
				for dx: int in [-2, 0, 2]:
					if world.ground_at(x + dx, y + dy) == g:
						same += 1
			if same < 8:
				continue
			patches += 1
			var d := Vector2(x, y).distance_to(near)
			if d < best_d:
				best_d = d
				best = Vector2(x + 0.5, y + 0.5)
	print("ground %s patches=%d nearest=%s d=%.1f" % [ground_name, patches, best, best_d])
	for kind_name: String in ["relay", "survey", "conveyor", "pipe", "intake", "checkpoint"]:
		var kind := PropKind.NAMES.find(kind_name)
		var np := Vector2.INF
		var nd := INF
		var n := 0
		for p: WorldProp in world.props:
			if p.kind != kind:
				continue
			n += 1
			var d2 := p.pos.distance_to(near)
			if d2 < nd:
				nd = d2
				np = p.pos
		print("prop %s count=%d nearest=%s d=%.1f" % [kind_name, n, np, nd])
	quit(0)
