class_name TourPeople
## The characters package's tour commands (98_tour dispatches to these), kept
## out of 98_tour so its merges stay mechanical:
##
##   await folk | crowd | dog | gulls
##       folk   a villager dressed for their land and trade stands in view, not
##              behind a roof or a wall
##       crowd  at least CROWD of them at once
##       dog    a village dog in view
##       gulls  at least two gulls down on the ground working a tip or a wreck, in view
##   walkto folk SECS   steer the real walk to the nearest villager out of doors
##                      that the camera can see (another if a roof or a wall stands
##                      between them and the camera), stopping at arm's length to
##                      their right on screen, where neither hides the other
##   walkto refuse SECS steer the real walk to within sight of the nearest tip or
##                      wreck that has its flock, stopping short of scaring it
##   walkto dog SECS    steer the real walk to a few steps short of the nearest
##                      village dog, to its right on screen, so it stops to watch
##   perf folk N SECS DRAWS MS
##                      rendered cost of a crowd: N villagers in a ring round the
##                      player (as --folk=N), frames over SECS with them shown and
##                      hidden in turn; prints both, and fails past DRAWS draw calls
##                      or MS milliseconds of render CPU a person

## Screen down is world (1, 1) / sqrt 2: the camera stands off that way.
const TOWARD_CAMERA := Vector2(0.7071, 0.7071)
## Where a walk stops beside someone: to their right on screen and a touch
## toward the camera, so they stand to the player's left, neither hiding the
## other, and a close camera holds both whole.
const BESIDE := Vector2(0.9285, -0.3714)
## Screen right, for the refuse: the heap beside the player across the wide frame.
const SCREEN_RIGHT := Vector2(0.7071, -0.7071)
const CROWD := 3
## Props tall enough to hide a person from the camera.
const TALL: Array[int] = [PropKind.HOUSE, PropKind.RUIN, PropKind.WRECK, PropKind.PINE, PropKind.BROADLEAF, PropKind.SNOW_PINE]


static func sees(game: Game, what: String) -> bool:
	var cam := game.get_viewport().get_camera_3d()
	if cam == null:
		return false
	match what:
		"folk", "crowd":
			var folk := system(game, "folk")
			if folk == null:
				return false
			var n := 0
			for f: Dictionary in folk.get("folk"):
				if in_view(cam, f) and not hidden(game, f.pos):
					n += 1
			return n >= (CROWD if what == "crowd" else 1)
		"dog", "gulls":
			var fauna := system(game, "fauna")
			if fauna == null:
				return false
			var n := 0
			for b: Dictionary in fauna.get("beasts"):
				var m := b.model as Node3D
				if not m.visible or not cam.is_position_in_frustum(m.global_position + Vector3(0, 0.2, 0)):
					continue
				if what == "dog" and b.kind == &"dog":
					return true
				# Down on the ground and back at their own heap, not blown along the shore.
				if what == "gulls" and b.kind == &"gull" and int(b.village) <= int(fauna.get("REFUSE_KEY")) and b.state in [&"stand", &"walk"] and (b.pos as Vector2).distance_to(b.home) < 2.0:
					n += 1
			return n >= 2
	return false


static func in_view(cam: Camera3D, f: Dictionary) -> bool:
	var pm := f.model as PersonModel
	return f.state == &"out" and pm.visible and pm.look.trade != &"" and cam.is_position_in_frustum(pm.global_position + Vector3(0, 0.7, 0))


## Whether something tall stands between a spot and the camera.
static func hidden(game: Game, p: Vector2) -> bool:
	for t: float in [0.7, 1.4, 2.1, 2.8]:
		var q := p + TOWARD_CAMERA * t
		for prop in game.query.props_near(q, 2.5):
			if TALL.has(prop.kind) and not game.world.depleted.has(prop.id) and prop.pos.distance_to(q) < prop.solid + 0.25:
				return true
	return false


static func system(game: Game, n: String) -> GameSystem:
	for sys in game.systems:
		if sys.name == n:
			return sys
	return null


## walkto folk | refuse. Returns whether it got there.
static func walk(tour: Node, game: Game, what: String, secs: float) -> bool:
	var until := Time.get_ticks_msec() + int(secs * 1000.0)
	var stuck := 0.0
	var sidestep := 0.0
	var turn := 1.0
	var chosen: Dictionary = {}
	var reached := false
	while Time.get_ticks_msec() < until:
		var target := Vector2(-1, -1)
		var close := 0.4
		if what == "folk":
			chosen = _pick_villager(game, chosen)
			if chosen.is_empty():
				break
			target = (chosen.pos as Vector2) + BESIDE * 1.5
			var from: Vector2 = game.player.pos - (chosen.pos as Vector2)
			if from.length() < 2.0 and from.length() > 1.0 and from.normalized().dot(BESIDE) > 0.85:
				reached = true
				break
			if not game.query.standable(floori(target.x), floori(target.y)):
				target = chosen.pos
				close = 1.6
		elif what == "dog":
			var dog := _nearest_dog(game)
			if dog.x < 0.0:
				break
			target = dog + BESIDE * 2.3
			close = 0.6
			var from_dog: Vector2 = game.player.pos - dog
			if from_dog.length() < 2.9 and from_dog.normalized().dot(BESIDE) > 0.8:
				reached = true
				break
		elif what == "refuse":
			var site := _flocked_site(game)
			if site.x < 0.0:
				break
			if chosen.is_empty():
				chosen = {"site": site}
				print("tour walkto refuse: the heap at %.1f,%.1f (%.1f tiles off)" % [site.x, site.y, site.distance_to(game.player.pos)])
			# Just outside the four tiles that put a gull up, the heap to the
			# player's left across the wide frame.
			target = site + SCREEN_RIGHT * 4.8
			close = 0.8
			if not game.query.standable(floori(target.x), floori(target.y)):
				target = site
				close = 4.8
		else:
			return false
		var d: Vector2 = target - game.player.pos
		if d.length() <= close:
			reached = true
			break
		var dir := d.normalized()
		var step := tour.get_physics_process_delta_time()
		# Stuck on a wall: sidestep round it the way a player does, for a moment.
		stuck = stuck + step if game.player.speed < 0.3 and sidestep <= 0.0 else 0.0
		if stuck > 0.25:
			stuck = 0.0
			sidestep = 0.7
			turn = -turn
		if sidestep > 0.0:
			sidestep -= step
			dir = dir.rotated(turn * PI * 0.5)
		game.scripted_move = Vector2(dir.x - dir.y, dir.x + dir.y) * 0.7071
		game.scripted_run = d.length() > 6.0
		game.scripted_seconds = 0.05
		await tour.get_tree().physics_frame
	game.scripted_seconds = 0.0
	return reached


## The villager to walk to: the one already chosen while the camera can still see
## them, else the nearest out of doors that nothing hides.
static func _pick_villager(game: Game, chosen: Dictionary) -> Dictionary:
	var folk := system(game, "folk")
	if folk == null:
		return {}
	var list: Array[Dictionary] = folk.get("folk")
	if not chosen.is_empty() and list.has(chosen) and chosen.state == &"out" and not hidden(game, chosen.pos):
		return chosen
	var best: Dictionary = {}
	for f in list:
		if f.state != &"out" or hidden(game, f.pos):
			continue
		if best.is_empty() or (f.pos as Vector2).distance_to(game.player.pos) < (best.pos as Vector2).distance_to(game.player.pos):
			best = f
	return best


static func _nearest_dog(game: Game) -> Vector2:
	var fauna := system(game, "fauna")
	var best := Vector2(-1, -1)
	if fauna == null:
		return best
	for b: Dictionary in fauna.get("beasts"):
		if b.kind == &"dog" and (best.x < 0.0 or (b.pos as Vector2).distance_to(game.player.pos) < best.distance_to(game.player.pos)):
			best = b.pos
	return best


## The nearest tip or wreck with its gulls about it, or (-1, -1).
static func _flocked_site(game: Game) -> Vector2:
	var fauna := system(game, "fauna")
	if fauna == null:
		return Vector2(-1, -1)
	var best := Vector2(-1, -1)
	var spawned: Dictionary = fauna.get("_spawned")
	for site: Dictionary in fauna.get("sites"):
		if not spawned.has(int(site.key)):
			continue
		var p: Vector2 = site.pos
		if best.x < 0.0 or p.distance_to(game.player.pos) < best.distance_to(game.player.pos):
			best = p
	return best


## perf folk N SECS DRAWS MS (see the header).
static func perf(tour: Node, game: Game, parts: PackedStringArray) -> bool:
	if parts.size() < 6 or parts[1] != "folk":
		return false
	var n := parts[2].to_int()
	var secs := parts[3].to_float()
	var max_draws := parts[4].to_float()
	var max_ms := parts[5].to_float()
	var folk := system(game, "folk")
	if folk == null or n <= 0:
		return false
	var had: int = (folk.get("folk") as Array).size()
	folk.call("_ring", n)
	var cam := game.get_viewport().get_camera_3d()
	var list: Array = folk.get("folk")
	var ring: Array[PersonModel] = []
	var seen := 0
	for i in range(had, list.size()):
		ring.append(list[i].model as PersonModel)
		if cam != null and in_view(cam, list[i]):
			seen += 1
	# Let the new figures settle into the pose cache and their stepped clocks.
	for i in 30:
		await tour.get_tree().process_frame
	# The same frames with the crowd shown and hidden in turn (a hidden figure
	# neither draws nor poses), so a machine busy with something else shifts
	# both sides alike; the middle of the three differences decides. What is
	# judged is the render CPU (culling, skinning, draw submission): a whole
	# frame's process time swings by more than a crowd costs whenever anything
	# else runs, and the script's own share is timed headless in
	# tests/models/test_people_crowd.gd.
	var with: Vector3
	var without: Vector3
	var diffs: Array[float] = []
	for k in 3:
		for m in ring:
			m.visible = false
		without = await _measure(tour, secs / 6.0)
		for m in ring:
			m.visible = true
		with = await _measure(tour, secs / 6.0)
		diffs.append(with.z - without.z)
	var draws := (with.y - without.y) / n
	var ms := _median(diffs) / n
	print("tour perf: %d villagers (%d in view): render cpu %.2f ms hidden, %.2f ms shown (whole frame %.1f -> %.1f ms), draw calls %.0f -> %.0f; %.3f ms of render cpu and %.1f draw calls a person" % [n, seen, without.z, with.z, without.x, with.x, without.y, with.y, ms, draws])
	if seen < n:
		printerr("tour perf: only %d of %d villagers in view" % [seen, n])
		return false
	if draws > max_draws:
		printerr("tour perf: %.1f draw calls a person, budget %.1f" % [draws, max_draws])
		return false
	if ms > max_ms:
		printerr("tour perf: %.3f ms a person, budget %.3f" % [ms, max_ms])
		return false
	return true


## Median over SECS of frames (a hitch never decides it): x ms of process and
## render CPU, y draw calls, z render CPU ms alone.
static func _measure(tour: Node, secs: float) -> Vector3:
	var vp := tour.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await RenderingServer.frame_post_draw
	var until := Time.get_ticks_msec() + int(secs * 1000.0)
	var ms: Array[float] = []
	var cpu: Array[float] = []
	var draws: Array[float] = []
	while Time.get_ticks_msec() < until:
		await RenderingServer.frame_post_draw
		var r := RenderingServer.viewport_get_measured_render_time_cpu(vp)
		ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0 + r)
		cpu.append(r)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	return Vector3(_median(ms), _median(draws), _median(cpu))


static func _median(list: Array[float]) -> float:
	if list.is_empty():
		return 0.0
	list.sort()
	return list[list.size() / 2]
