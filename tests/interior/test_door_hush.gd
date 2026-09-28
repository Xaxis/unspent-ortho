extends TestCase
## A ROOM FALLS QUIET WHILE A MACHINE PASSES ITS DOOR (DoorHush, 21_doors). A
## sorter walks a round across the slot past a warren's door on seed 1; the
## player goes in. Nothing outside runs in a pocket, so the sorter is the one
## snapshot at the door and walked on along its round: far off the room is as
## it was; passing within its hearing the room's `quiet` rises and its lamps
## dip; past, both come back. Out again, the sorter stands where its round took
## it.

const Sx := preload("res://tests/save/save_fixture.gd")


func _lamp(d: Node) -> float:
	var lamps: Array = d.get(&"_lamps")
	return (lamps[0][0] as Light3D).light_energy if not lamps.is_empty() else -1.0


## Held at `t` on the room's clock for longer than the hush takes to ease
## (1 / QUIET_RATE), in real seconds: headless frames come fast.
func _settle(d: Node, t: float) -> void:
	var until := Time.get_ticks_msec() + 1600
	while Time.get_ticks_msec() < until:
		d.set(&"_heard_t", t)
		await tree.process_frame


func test_a_sorter_passing_the_door_hushes_the_room() -> void:
	var g := Sx.game(tree, ["--seed=1", "--hour=11", "--weather=clear:0"])
	var d := Sx.system(g, "21_doors")
	var t: Threshold = null
	for th: Threshold in Interiors.thresholds(g.world):
		if th.kind == &"container_warren":
			t = th
			break
	check(t != null, "seed 1 has a warren")
	if t == null:
		Sx.end(g)
		return
	# The player at the door, as a player going in is: the coast keeps bodies
	# only near them.
	g.player.hero.pos = t.door
	g.player.pos = t.door
	await frames(5)
	# Its round crosses the slot in front of the door, twelve tiles each side.
	var across := Vector2(-t.out.y, t.out.x)
	var a := t.door + t.out * 1.5 + across * 12.0
	var b := t.door + t.out * 1.5 - across * 12.0
	var m := g.player.sim.add_mob(&"sorter", a)
	m.line_a = a
	m.line_b = b
	m.line_to_b = true
	await d.call(&"go_in", t)
	var heard: Array = d.get(&"_heard")
	var found := false
	for h: Dictionary in heard:
		found = found or h.kind == &"sorter"
	check(found, "the sorter at the door was heard going in")
	# Twelve tiles off at the start, its hearing six: the room as it was.
	await _settle(d, 0.0)
	var q0 := float(d.get(&"quiet"))
	var lamp0 := _lamp(d)
	lt(q0, 0.05, "far off, the room is not hushed")
	gt(lamp0, 0.0, "the room has a lamp to dip")
	# At the door: twelve tiles at its round's pace.
	var speed := float(heard[0].speed)
	await _settle(d, 12.0 / speed)
	gt(float(d.get(&"quiet")), 0.95, "passing, the room holds its breath")
	lt(_lamp(d), lamp0 * 0.6, "and its lamps dip")
	# Past, beyond its hearing and the fade (twenty tiles on, at b's end and back).
	await _settle(d, 20.0 / speed)
	lt(float(d.get(&"quiet")), 0.05, "past, the room breathes again")
	near(_lamp(d), lamp0, lamp0 * 0.1, "and its lamps come back")
	var at := DoorHush.at(heard[0], 20.0 / speed)
	await d.call(&"go_out")
	var back := false
	for mm: MobState in g.player.sim.mobs:
		if mm.kind == &"sorter" and mm.pos.distance_to(at) < 1.5:
			back = true
	check(back, "out again, the sorter is where its round took it")
	eq(float(d.get(&"quiet")), 0.0, "and outside nothing is hushed")
	Sx.end(g)
