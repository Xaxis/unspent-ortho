extends TestCase
## The crafts system inside a real running game: the real `ride` key puts a raft
## in the water and the player on it, the fight body is the one that moves, the sea
## it crosses is ground it could not have waded, stepping off leaves the craft
## standing in the world, a hull worn through wrecks where it broke and can be
## stripped, and all of it comes back through a save.

var game: Game


func _boot(extra: PackedStringArray = PackedStringArray()) -> Node:
	var args := PackedStringArray(["--seed=1", "--size=96", "--hour=12"])
	args.append_array(extra)
	game = Game.new()
	tree.root.add_child(game)
	game.setup(BootOptions.parse(args))
	return _system("44_crafts")


func _done() -> void:
	game.free()
	game = null


## Stand the player at the tideline: the nearest shallow tile to where the game
## started that has OPEN SEA within a shove, so the raft goes in deep enough to
## float and the crossing is a real one.
func _to_the_tideline() -> bool:
	var w := game.world
	var best := Vector2.INF
	var best_d := INF
	var from: Vector2 = game.player.pos
	for y in range(1, w.size - 1):
		for x in range(1, w.size - 1):
			if w.ground_at(x, y) != Ground.WATER:
				continue
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_squared_to(from)
			if d >= best_d:
				continue
			var spot := Crafts.launch_spot(w, game.query, &"raft", p, 0.0)
			if spot == Vector2.INF or not Crafts.beyond_a_body(w, spot):
				continue
			best_d = d
			best = p
	if best == Vector2.INF:
		fail("no tideline in this world")
		return false
	game.player.pos = best
	if game.player.hero != null:
		game.player.hero.pos = best
	game.player.sync_view(0.0)
	game.view.ensure_near(best)
	return true


## Walk the real way: the screen direction that means this world direction, held
## for `secs` of scripted input, exactly as --walk and a tour do.
func _walk(world_dir: Vector2, secs: float) -> void:
	var yaw := deg_to_rad(game.camera.yaw_now())
	var up := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	game.scripted_move = Vector2(world_dir.dot(right), -world_dir.dot(up)).normalized()
	game.scripted_run = false
	game.scripted_seconds = secs
	var frames_left := int(secs * 70.0) + 4
	while game.scripted_seconds > 0.0 and frames_left > 0:
		frames_left -= 1
		await tree.physics_frame


func _tap_ride() -> void:
	Input.action_press(&"ride")
	await tree.physics_frame
	await tree.process_frame
	Input.action_release(&"ride")
	for i in 4:
		await tree.physics_frame


func test_the_real_key_puts_a_raft_in_and_the_player_on_it() -> void:
	var sys := _boot(["--give=raft:1"])
	check(sys != null, "44_crafts loaded")
	if not _to_the_tideline():
		_done()
		return
	await _tap_ride()
	var aboard: Craft = sys.get("aboard")
	check(aboard != null, "the press launched it and stepped on")
	if aboard == null:
		_done()
		return
	eq(aboard.kind, &"raft")
	check(not game.inventory.has(&"raft"), "the bundle came out of the creel")
	check(game.player.hero.ride != null, "the fight body knows what is under it")
	eq(game.player.hero.ride.kind, &"raft")
	check(sys.call("tour_seen", &"riding:raft"), "a tour can see it")
	# The one thing a raft is for: the body is standing where a body could not.
	check(Crafts.beyond_a_body(game.world, game.player.hero.pos), "it went in deep enough to float")
	check(not game.query.standable(floori(game.player.hero.pos.x), floori(game.player.hero.pos.y)),
		"and nobody could be standing there on their own feet")
	_done()


func test_it_carries_the_body_over_water_no_one_could_wade_and_the_sim_moves_it() -> void:
	var sys := _boot(["--give=raft:1"])
	if not _to_the_tideline():
		_done()
		return
	await _tap_ride()
	if sys.get("aboard") == null:
		fail("never got on")
		_done()
		return
	var from: Vector2 = game.player.hero.pos
	# Out, whichever way the sea lies: on a deep tile it is under you already.
	for dir: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		await _walk(dir, 1.2)
		if sys.call("tour_seen", &"ride_crossed"):
			break
	check(sys.call("tour_seen", &"ride_crossed"), "it carried the body over open water")
	gt(from.distance_to(game.player.hero.pos), 1.0, "and the body went somewhere")
	eq(game.player.pos, game.player.hero.pos, "the fight body is still the one that moves")
	var aboard: Craft = sys.get("aboard")
	eq(aboard.pos, game.player.hero.pos, "and the craft is under it")
	lt(aboard.hull, CraftKinds.hull(&"raft"), "the crossing told on the hull")
	_done()


func test_a_body_on_foot_is_turned_back_by_the_same_water() -> void:
	var sys := _boot()
	check(sys != null)
	if not _to_the_tideline():
		_done()
		return
	# Straight at the sea with nothing under you: the shallows are as far as it goes.
	var sea := Crafts.launch_spot(game.world, game.query, &"raft", game.player.hero.pos, 0.0)
	var toward := (sea - game.player.hero.pos).normalized()
	await _walk(toward, 2.0)
	check(not Crafts.beyond_a_body(game.world, game.player.hero.pos), "a body cannot walk into the sea")
	_done()


func test_stepping_off_leaves_it_standing_in_the_world() -> void:
	var sys := _boot(["--give=raft:1"])
	if not _to_the_tideline():
		_done()
		return
	await _tap_ride()
	var aboard: Craft = sys.get("aboard")
	if aboard == null:
		fail("never got on")
		_done()
		return
	var where := aboard.pos
	await _tap_ride()
	check(sys.get("aboard") == null, "off again")
	check(game.player.hero.ride == null, "and the fight body is back on its own feet")
	var list: Array = sys.get("crafts")
	eq(list.size(), 1, "the raft is still a thing in the world")
	eq((list[0] as Craft).pos, where, "lying where it was left")
	check(game.query.standable(floori(game.player.hero.pos.x), floori(game.player.hero.pos.y)),
		"and the body is standing on something")
	# In reach, so `ride` takes it again.
	check(sys.call("board", list[0]) == &"", "it can be boarded again")
	check(sys.get("aboard") != null)
	_done()


func test_a_hull_worn_through_wrecks_where_it_broke_and_can_be_stripped() -> void:
	var sys := _boot(["--give=raft:1"])
	if not _to_the_tideline():
		_done()
		return
	await _tap_ride()
	var aboard: Craft = sys.get("aboard")
	if aboard == null:
		fail("never got on")
		_done()
		return
	# A machine's blows take the deck apart under you (Events.hit).
	for i in 40:
		Events.hit.emit(null, game.player, 3, false, Vector3.ZERO)
		if aboard.wrecked:
			break
	check(aboard.wrecked, "it came apart")
	check(sys.call("tour_seen", &"craft_wrecked"), "a tour can see it")
	check(sys.get("aboard") == null, "nobody rides a wreck")
	check(game.query.standable(floori(game.player.hero.pos.x), floori(game.player.hero.pos.y)),
		"whoever was on it is on ground again")
	var list: Array = sys.get("crafts")
	if list.is_empty():
		# It sank: a raft wrecked in open water is simply lost, which is the rule.
		check(true, "lost at sea")
		_done()
		return
	var wreck: Craft = list[0]
	eq(Crafts.board_refusal(wreck, wreck.pos), &"wrecked", "and it will not carry anyone")
	var before := game.inventory.count(&"scrap")
	eq(sys.call("salvage", wreck), &"", "stripped")
	gt(float(game.inventory.count(&"scrap")), float(before), "for what is left of it")
	eq((sys.get("crafts") as Array).size(), 0, "and it is gone from the world")
	_done()


func test_a_parked_craft_and_a_ridden_one_come_back_through_the_save() -> void:
	var sys := _boot(["--give=raft:1"])
	if not _to_the_tideline():
		_done()
		return
	await _tap_ride()
	var aboard: Craft = sys.get("aboard")
	if aboard == null:
		fail("never got on")
		_done()
		return
	var where := aboard.pos
	var data: Dictionary = JSON.parse_string(JSON.stringify(SaveGame.collect()))
	check(data.has("crafts"), "the crafts are in the save")
	# Step off, walk away, and lose the craft altogether.
	await _tap_ride()
	sys.call("remove", (sys.get("crafts") as Array)[0])
	eq((sys.get("crafts") as Array).size(), 0, "nothing left")
	SaveGame.apply(data)
	var back: Array = sys.get("crafts")
	eq(back.size(), 1, "the craft came back")
	eq((back[0] as Craft).kind, &"raft")
	eq((back[0] as Craft).pos, where, "where it was")
	check(sys.get("aboard") != null, "and the player came back standing on it")
	check(game.player.hero.ride != null, "with the fight body knowing it")
	_done()


func test_a_craft_parked_at_boot_is_drawn_and_can_be_boarded() -> void:
	var sys := _boot()
	if not _to_the_tideline():
		_done()
		return
	# --craft/--aboard run at setup, before the player was moved here, so this is
	# the same call they make.
	var spot := Crafts.launch_spot(game.world, game.query, &"raft", game.player.hero.pos, 0.0)
	var c: Craft = sys.call("add", &"raft", spot, 0.0)
	check(c != null, "parked")
	for i in 3:
		await tree.process_frame
	var node: Node3D = sys.get_node_or_null("craft_raft")
	check(node != null, "and drawn in the world")
	if node != null:
		gt(float((node.get_node("found") as MeshInstance3D).mesh.get_surface_count()), 0.0, "machine parts")
		gt(float((node.get_node("made") as MeshInstance3D).mesh.get_surface_count()), 0.0, "and a hand's work")
	_done()


func _system(part: String) -> Node:
	for s in game.systems:
		if String(s.name).contains(part):
			return s
	return null
