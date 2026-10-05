extends TestCase
## Every bite and throw has a mark on the ground as its tell (FightRules.tell_box,
## drawn by 40_fight on the sim's `windup`): the body's own windup pose is small
## over the shoulder, and a mark on the ground reads from above and from behind
## alike. The mark is the blow's box grown by the player's radius, so it is
## exactly the ground a player standing there is hit on: a ring over the box hurt
## players up to a tile outside it (cb's hit audit), and drawn wider it marked
## ground no blow reached.


## Every bite the game throws at a player: the roster's, and each keeper phase's.
static func _bites() -> Array[Array]:
	var out: Array[Array] = []
	for kind: StringName in Roster.kinds():
		var b := Roster.bite(kind)
		if b != null:
			out.append([String(kind), b, float(Roster.row(kind).get("radius", 0.4))])
	for def: SentinelDef in Sentinels.all():
		for i in def.phases.size():
			var p := def.phase(i)
			out.append(["%s %s" % [def.id, p.id], Blow.from_dict(p.bite), float(Roster.row(def.kind).get("radius", 0.4))])
	return out


func test_the_mark_is_exactly_the_ground_a_blow_lands_on() -> void:
	var o := Vector2(10, 10)
	var trad := Tuning.PLAYER_RADIUS
	var asked := 0
	var wrong: Array[String] = []
	for row: Array in _bites():
		var b: Blow = row[1]
		if b.area:
			continue
		asked += 1
		var r: float = row[2]
		for facing: float in [0.0, 1.1, PI, -2.3]:
			var tb := FightRules.tell_box(o, facing, r, b, trad)
			for iy in range(-80, 81):
				for ix in range(-80, 81):
					var p := o + Vector2(ix, iy) * 0.1
					if FightRules.box_hits(o, facing, r, b, p, trad) != FightRules.in_tell_box(tb, facing, trad, p):
						wrong.append("%s at %s" % [row[0], p])
	gt(float(asked), 10.0, "every bite and throw was asked (%d)" % asked)
	eq(wrong.size(), 0, "marked ground is hit ground and nothing else: %s" % str(wrong.slice(0, 4)))


## The tells on the ground under the game (MobFx marks in TELL_BOX mode).
func _marks(game: Node) -> int:
	var k := 0
	for c in game.get_children():
		var mi := c as MeshInstance3D
		if mi == null or not (mi.material_override is ShaderMaterial):
			continue
		var mode: Variant = (mi.material_override as ShaderMaterial).get_shader_parameter(&"mode")
		if mode is int and mode == MobFx.TELL_BOX:
			k += 1
	return k


func test_a_bite_s_windup_draws_its_mark_in_the_running_game() -> void:
	var o := BootOptions.parse(PackedStringArray(["--seed=4", "--size=128", "--spawn=runner"]))
	var game := Game.new()
	tree.root.add_child(game)
	game.setup(o)
	await frames(3)
	var sim := game.player.sim
	eq(sim.living(), 1, "a runner beside the player")
	var m := sim.mobs[0]
	var before := _marks(game)
	Brains.bite(m, sim)
	await frames(3)
	check(_marks(game) - before >= 1, "its windup put its mark on the ground")
	game.queue_free()
	await frames(1)
