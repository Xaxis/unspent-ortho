extends TestCase
## The boot's warm-up racks (01_warm_lights, MobFx.warm) stand at the player's
## feet for their frames. A shot fired at frame 8 and caught them (a white panel
## at the player), and the boot page lifted after two frames, over the rest. Both
## now wait for `done()`, so the claim is: the frame it says done, nothing of any
## rack is left at the player.


func _at_player(g: Game) -> int:
	var at := g.player.position
	var n := 0
	for c: Node in g.get_children():
		var gi := c as GeometryInstance3D
		if gi != null and gi.visible and not gi.is_queued_for_deletion() and gi.global_position.distance_to(at) < 2.0:
			n += 1
	return n


func test_when_the_warm_up_is_done_no_rack_stands_at_the_player() -> void:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0"])))
	var w := g.get_node("01_warm_lights")
	await frames(2)
	check(not bool(w.call("done")), "two frames in, the warm-up is still on")
	gt(_at_player(g), 0, "and its rack stands at the player's feet, where a shot or a lifted page would show it")
	var waited := 0
	while not bool(w.call("done")) and waited < 60:
		await frames(1)
		waited += 1
	check(bool(w.call("done")), "the warm-up ends")
	eq(_at_player(g), 0, "and on that frame nothing of any rack is left at the player")
	g.queue_free()
	await frames(1)
