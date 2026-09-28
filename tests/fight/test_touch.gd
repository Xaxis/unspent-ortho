extends TestCase
## CONTACT (FightSim._touching, roster `touch` and `touch_arc`): a body that
## hurts by touch hurts only where the thing that hurts is. The sweeper's brush
## is at its front, and its working part is on its back: a player at its back is
## where the land asks them to strike, and a short blade has to stand inside the
## body's reach to strike it there. Bodies without an arc (a watcher's shock
## skin) hurt all round.

const F := preload("res://tests/fight/fixture.gd")


## Contact hurt over two seconds with the player `off` from a body facing east
## (+x is in front of it).
func _hurt_at(kind: StringName, off: Vector2) -> int:
	MobState._next_id = 4000
	var sim := F.make_sim(F.flat_world(48), Vector2(20.5, 20.5))
	var m := F.still(sim, kind, sim.hero.pos - off, 0.0)
	var hurt := 0
	for i in 125:
		# Held where it stands, so only contact is measured.
		m.pos = sim.hero.pos - off
		m.facing = 0.0
		m.want = Vector2.ZERO
		F.ms(sim, 16)
		for e in sim.drain():
			if e.type == &"hurt":
				hurt += int(e.damage)
	return hurt


func test_a_sweeper_brushes_with_its_front_and_not_its_back() -> void:
	# The player 0.6 tiles off: inside its body's reach on every side.
	var front := _hurt_at(&"sweeper", Vector2(0.6, 0.0))
	var back := _hurt_at(&"sweeper", Vector2(-0.6, 0.0))
	print("  info a sweeper's contact over 2 s: %d at its front, %d at its back" % [front, back])
	gt(float(front), 0.0, "its brush hurts at its front")
	eq(back, 0, "its back, where its part is, does not hurt to stand at")


func test_a_body_without_an_arc_hurts_all_round() -> void:
	var front := _hurt_at(&"watcher", Vector2(-0.5, 0.0))
	var back := _hurt_at(&"watcher", Vector2(0.5, 0.0))
	gt(float(front), 0.0, "a watcher's skin hurts in front")
	gt(float(back), 0.0, "and behind")
