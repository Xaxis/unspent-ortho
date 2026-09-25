extends TestCase
## Every bite has a ground ring as its tell (FightRules.tell_ring, drawn by
## 40_fight on the sim's `windup`): the body's own windup pose is small over the
## shoulder, and a ring on the ground reads from above and from behind alike.
## The ring stands over the box the bite will test, so what it promises and what
## hurts agree.


func test_the_ring_stands_over_every_bite_s_box() -> void:
	var o := Vector2(10, 10)
	var n := 0
	for kind: StringName in Roster.kinds():
		var b := Roster.bite(kind)
		if b == null:
			continue
		n += 1
		var r: float = Roster.row(kind).get("radius", 0.4)
		for facing: float in [0.0, 1.1, PI, -2.3]:
			var ring := FightRules.tell_ring(o, facing, r, b)
			var at := Vector2(ring.x, ring.y)
			check(FightRules.box_hits(o, facing, r, b, at, 0.01), "%s: the ring's middle is in its box" % kind)
			var far := o + Vector2.from_angle(facing) * (r + b.reach)
			check(at.distance_to(far) <= ring.z + 0.01, "%s: the ring reaches the end of the bite" % kind)
			check(ring.z >= b.width * 0.5 - 0.001, "%s: and is as wide as it" % kind)
	check(n > 10, "the roster's bites were all asked (%d)" % n)


## The bite tells on the ground under the game (MobFx marks in TELL_RING mode).
func _rings(game: Node) -> int:
	var k := 0
	for c in game.get_children():
		var mi := c as MeshInstance3D
		if mi == null or not (mi.material_override is ShaderMaterial):
			continue
		var mode: Variant = (mi.material_override as ShaderMaterial).get_shader_parameter(&"mode")
		if mode is int and mode == MobFx.TELL_RING:
			k += 1
	return k


func test_a_bite_s_windup_draws_its_ring_in_the_running_game() -> void:
	var o := BootOptions.parse(PackedStringArray(["--seed=4", "--size=128", "--spawn=runner"]))
	var game := Game.new()
	tree.root.add_child(game)
	game.setup(o)
	await frames(3)
	var sim := game.player.sim
	eq(sim.living(), 1, "a runner beside the player")
	var m := sim.mobs[0]
	var before := _rings(game)
	Brains.bite(m, sim)
	await frames(3)
	check(_rings(game) - before >= 1, "its windup put a ring on the ground")
	game.queue_free()
	await frames(1)
