extends TestCase
## A landscape may move a machine's working part (mechanics 3a, part sides;
## MachineModel._move_part, BiomeDef.roster `over` part). The model then builds
## the part on the side it was asked for, on the outside of the body there; the
## fight reads the same side; and the cave hauler's is at its back where the
## bonelands one's is on its left.

const F := preload("res://tests/fight/fixture.gd")
const MG := preload("res://src/models/machines/machine_gallery.gd")
const SIDES: Array[StringName] = [&"front", &"back", &"left", &"right"]


## Where the part's anchor is, in the model's own space.
func _anchor(m: MachineModel) -> Vector3:
	var xf := Transform3D.IDENTITY
	var at: Node = m.part_anchor
	while at != null and at != m:
		xf = (at as Node3D).transform * xf
		at = at.get_parent()
	return xf.origin


func test_every_machine_builds_its_part_on_any_side_asked_on_the_outside() -> void:
	for kid: StringName in MG.KINDS:
		var base := FigureModel.create(kid) as MachineModel
		if base == null or base.part_side == &"none" or base.part_anchor == null:
			if base != null:
				base.free()
			continue
		var calls := base.draw_calls()
		base.free()
		for side in SIDES:
			var m := FigureModel.create(kid, null, side) as MachineModel
			eq(m.part_side, side, "%s asked for its part on the %s" % [kid, side])
			var n := MachineModel.side_normal(side)
			var out := _anchor(m).dot(n)
			gt(out, 0.05, "%s's part is out on its %s (%.2f along it)" % [kid, side, out])
			eq(m.draw_calls(), calls, "%s: moving the part draws nothing more" % kid)
			m.free()


func test_the_cave_hauler_works_with_its_back_and_the_bonelands_one_with_its_left() -> void:
	var caves := BiomeRegistry.get_def(&"limestone_caves")
	for pair: Array in [[Country.BONELANDS, &"left"], [caves.index, &"back"]]:
		var sim := F.make_sim(F.flat_world(64, Ground.LIMESTONE, pair[0]), Vector2(20.5, 20.5))
		var m := sim.add_mob(&"hauler", Vector2(24.5, 20.5))
		eq(m.part, pair[1], "the hauler in %s works with its %s" % [BiomeRegistry.name_of(pair[0]), pair[1]])
		m.facing = PI
		var behind := m.pos + Vector2.from_angle(m.facing + PI) * (m.radius + 0.6)
		var left := m.pos + Vector2.from_angle(m.facing - PI * 0.5) * (m.radius + 0.6)
		m.set_mood(MobState.ATTACKING, sim.now)
		# Spent after a bite, so a guarded part would be open anyway.
		eq(sim.reaches_part(m, behind), pair[1] == &"back", "a blow from behind reaches it: %s" % (pair[1] == &"back"))
		eq(sim.reaches_part(m, left), pair[1] == &"left", "a blow from its left reaches it: %s" % (pair[1] == &"left"))
	var model := FigureModel.create(&"hauler", null, &"back") as MachineModel
	lt(_anchor(model).x, -0.2, "and its model builds the drive at its back")
	model.free()
