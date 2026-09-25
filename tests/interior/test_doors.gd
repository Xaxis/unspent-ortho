extends TestCase
## Walking into a coast cottage and out again, in a running game (docs/interiors,
## S1). The door only swaps: the pocket's view is grown while the player stands
## at the door, the outside view is set aside whole and put back, and nothing is
## rebuilt on the way out.

const Sx := preload("res://tests/save/save_fixture.gd")


func _doors(g: Game) -> Node:
	return Sx.system(g, "21_doors")


func _frames(n: int) -> void:
	var until := Time.get_ticks_msec() + 15000
	for i in n:
		await tree.process_frame
		if Time.get_ticks_msec() > until:
			return


## Nodes under a view, the vertices its meshes hold, and the bytes of its world's
## per-tile arrays.
static func _kept_set(view: Node, w: WorldData) -> Vector3i:
	var nodes := 0
	var verts := 0
	var todo: Array[Node] = [view]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		nodes += 1
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			for si in mi.mesh.get_surface_count():
				verts += (mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		todo.append_array(n.get_children())
	var tiles := w.size * w.size
	return Vector3i(nodes, verts, w.level.size() + w.ground.size() + w.country.size() + tiles * 8)


func _at_door(g: Game, d: Node) -> Threshold:
	var p: Vector2 = d.call(&"tour_place", "door:house")
	g.player.hero.pos = p
	g.player.sync_view(0.0)
	var best: Threshold = null
	for t: Threshold in d.get("doors"):
		if best == null or t.door.distance_to(p) < best.door.distance_to(p):
			best = t
	return best


func test_in_through_a_cottage_door_and_out_onto_the_same_coast() -> void:
	Sx.use_root("doors-in-out")
	var g := Sx.game(tree, ["--seed=4", "--village=0", "--hour=11", "--weather=clear:0"])
	var d := _doors(g)
	check(d != null, "21_doors is loaded from src/systems")
	gt(float((d.get("doors") as Array).size()), 0.0, "the coast's houses have doors")
	var outside := g.world
	var outside_view := g.view
	var depleted := outside.depleted.duplicate()
	var t := _at_door(g, d)
	await _frames(90)
	check(d.get("_grown") != null, "the pocket was grown while the player stood at the door")
	await d.call(&"go_in", t)
	check(bool(d.call(&"tour_seen", &"inside:cottage")), "inside a cottage")
	eq(g.world.realm, Realm.INTERIOR, "in a pocket world under a roof")
	eq(g.view.world, g.world, "drawn by the pocket's own view")
	check(outside_view.get_parent() == null, "the outside view set aside, not freed")
	await _frames(10)
	var kept := _kept_set(g.view, g.world)
	# What a room costs to keep beside the coast set aside, counted off the room
	# itself: a process-wide counter reads the coast's own streaming, not this.
	# Printed, not held to a bar: the owner sets that budget.
	print("S1 kept set: %d nodes, %d mesh vertices (~%.2f MB of vertex data), world arrays %.2f MB" % [
		kept.x, kept.y, kept.y * 48.0 / 1048576.0, kept.z / 1048576.0])
	# What keeps the outside sleeps through the door rather than re-reading it.
	var sleepers: Array[Node] = []
	for sys: Node in g.systems:
		# A system that keeps its own `_indoors` flag stays awake in a room on
		# purpose (30_mobs draws the room's residents; only its spawner stops).
		if sys.has_method(&"indoors") and sys.get(&"_indoors") == null:
			sleepers.append(sys)
	gt(float(sleepers.size()), 0.0, "some systems keep the outside")
	for sys: Node in sleepers:
		check(not sys.is_processing() and not sys.is_physics_processing(), "%s sleeps indoors" % sys.name)
	var start := g.player.pos
	await _frames(20)
	# Walk at a wall: the room stops the body.
	g.scripted_move = Vector2(0.0, -1.0)
	g.scripted_seconds = 3.0
	await _frames(200)
	var pocket: InteriorGen.Pocket = d.get("pocket")
	check(pocket.layout.is_floor(floori(g.player.pos.x), floori(g.player.pos.y)), "walked into a wall and still on the floor (%s)" % str(g.player.pos))
	check(g.player.pos.distance_to(start) > 0.5, "and it did walk")
	# Back to the door, and out.
	g.player.hero.pos = pocket.layout.door - pocket.layout.door_out * 0.4
	g.player.sync_view(0.0)
	await _frames(5)
	await d.call(&"go_out")
	await _frames(30)
	check(g.world == outside, "out onto the SAME coast, not a new one")
	check(g.view == outside_view, "drawn by the view that drew it before")
	eq(g.world.depleted, depleted, "with what was taken from it intact")
	check(bool(d.call(&"tour_seen", &"outside")), "outside")
	for sys: Node in sleepers:
		check(sys.is_processing() or sys.is_physics_processing(), "%s wakes outside" % sys.name)
	eq(int(d.get("built_after_out")), 0, "and the way out rebuilt nothing")
	# The door's own cost, the swap under the cover, stated as the best of three
	# trips (load only ever adds time), and the worst beside it so an outlier is
	# seen rather than averaged away.
	var ins: Array[float] = [float(d.get("swap_in_ms"))]
	var outs: Array[float] = [float(d.get("swap_out_ms"))]
	for trip in 2:
		await _frames(30)
		await d.call(&"go_in", t)
		check(bool(d.call(&"tour_seen", &"inside:cottage")), "in again, trip %d" % (trip + 2))
		await _frames(10)
		await d.call(&"go_out")
		check(g.world == outside and g.view == outside_view, "and out onto the same coast, trip %d" % (trip + 2))
		ins.append(float(d.get("swap_in_ms")))
		outs.append(float(d.get("swap_out_ms")))
	print("S1 swap in best %.1f worst %.1f ms, swap out best %.1f worst %.1f ms" % [
		ins.min(), ins.max(), outs.min(), outs.max()])
	lt(float(ins.min()), 50.0, "the way in swaps under 50 ms")
	lt(float(outs.min()), 50.0, "the way out swaps under 50 ms")
	# And no trip STALLS: the bar above is a cost, this is the door a player felt
	# stand for 4.6 s when the view waited on its far rings to leave the tree.
	lt(float(ins.max()), 250.0, "no way in stalls")
	lt(float(outs.max()), 250.0, "no way out stalls")
	Sx.end(g)
	Sx.finish()


## A save made in a room opens in that room: the coast is grown, the same house's
## pocket is grown behind the same door, and the player stands where they saved.
func test_a_save_made_inside_opens_inside() -> void:
	Sx.use_root("doors-save")
	var a := Sx.game(tree, ["--seed=4", "--village=0", "--hour=11", "--weather=clear:0"])
	var d := _doors(a)
	var t := _at_door(a, d)
	# Something built outside before going in: a save made in the room must keep
	# it, because the room is grown again and the coast is what the save carries.
	var fire_at := t.door + t.out * 2.5
	var built := Survival.add_prop(a, PropKind.FIRE, fire_at)
	await _frames(30)
	await d.call(&"go_in", t)
	check(bool(d.call(&"tour_seen", &"inside:cottage")), "inside before the save")
	var pocket: InteriorGen.Pocket = d.get("pocket")
	var stood := pocket.layout.inside() + Vector2(0.0, -1.5).rotated(pocket.layout.door_out.angle() - PI * 0.5)
	a.player.hero.pos = stood
	a.player.pos = stood
	await _frames(5)
	stood = a.player.pos
	var key := String(pocket.threshold.key)
	eq(Sx.system(a, "05_save").call("save_to", 2), "", "saved to slot 2 inside")
	Sx.end(a)
	var o := BootOptions.new()
	eq(SaveSlots.options_for(2, o), "", "slot 2 boots")
	var b := Sx.game(tree, [], o)
	await _frames(10)
	var db := _doors(b)
	check(bool(db.call(&"tour_seen", &"inside:cottage")), "the save opens inside the cottage")
	eq(b.world.realm, Realm.INTERIOR, "in a pocket world")
	var back: InteriorGen.Pocket = db.get("pocket")
	check(back != null and String(back.threshold.key) == key, "behind the same door (%s)" % key)
	near(b.player.pos.distance_to(stood), 0.0, 0.3, "where the player stood when they saved")
	# And the way out leads onto the coast, at that door.
	await db.call(&"go_out")
	await _frames(10)
	check(bool(db.call(&"tour_seen", &"outside")), "and the door leads out")
	eq(b.world.realm, Realm.SURFACE, "onto the surface")
	near(b.player.pos.distance_to(back.threshold.door), 0.0, 1.6, "at the house's door")
	var kept := false
	for q: WorldProp in b.world.props:
		if q.kind == PropKind.FIRE and q.pos.distance_to(built.pos) < 0.01:
			kept = true
	check(kept, "and the fire built outside before going in is still there")
	Sx.end(b)
	Sx.finish()


## Visible local lights (not the sun or moon) under these nodes, and how many
## cast. The lights system's reach light is its own exception, older than the row.
static func _lights_on(roots: Array) -> Vector2i:
	var on := Vector2i.ZERO
	var todo: Array[Node] = []
	for r: Variant in roots:
		todo.append(r as Node)
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		todo.append_array(n.get_children())
		var l := n as Light3D
		if l == null or l is DirectionalLight3D or not l.is_visible_in_tree() or n.name == &"reach_light":
			continue
		on.x += 1
		if l.shadow_enabled:
			on.y += 1
	return on


## A ROOM NEVER LIGHTS PAST THE TIER'S ROW. Its window suns, sky fills and lamps
## are lent to 15_lights, which holds them with its own pool to `Quality`'s
## `lamps` and `shadow_lights`. Asked on the tightest rows, at noon when the
## window suns ask to cast and at night when the lamps are up.
func test_a_room_never_lights_past_the_tiers_row() -> void:
	for tier: String in ["web", "low"]:
		Sx.use_root("doors-lights-" + tier)
		# `--quality` reaches the engine through main.gd, which a test does not
		# run: the tier is put in force here, before the lights size their pool.
		SettingsApply.quality_asked = StringName(tier)
		SettingsApply.quality()
		eq(Quality.current_id(), StringName(tier), "the %s row is in force" % tier)
		var g := Sx.game(tree, ["--seed=4", "--village=0", "--hour=11", "--weather=clear:0"])
		var d := _doors(g)
		var lights: Node = Sx.system(g, "15_lights")
		var t := _at_door(g, d)
		await _frames(20)
		await d.call(&"go_in", t)
		check(bool(d.call(&"tour_seen", &"inside:cottage")), "%s: inside" % tier)
		var row := Quality.row(StringName(tier))
		for hour: float in [11.0, 22.0]:
			g.clock.minutes = floorf(g.clock.minutes / 1440.0) * 1440.0 + hour * 60.0
			await _frames(20)
			# Counted off the scene, not off the lights system's own books: a light
			# nobody lent is exactly the one those books cannot see.
			var on := _lights_on([g.view, lights])
			check(on.x <= int(row.lamps), "%s at %d: %d lights on, the row allows %d" % [tier, int(hour), on.x, int(row.lamps)])
			check(on.y <= int(row.shadow_lights), "%s at %d: %d casting, the row allows %d" % [tier, int(hour), on.y, int(row.shadow_lights)])
			gt(float(on.x), 0.0, "%s at %d: and the room is lit at all" % [tier, int(hour)])
		Sx.end(g)
	SettingsApply.quality_asked = &""
	SettingsApply.quality()
	Sx.finish()


## A HALL'S RESIDENTS ARE IN THE FIGHT, and they know somebody has come in: the
## warden where the recipe stood it and whatever walks the hall, as the one
## FightSim's bodies, still there after the room has run a while.
func test_a_halls_residents_are_in_the_fight() -> void:
	Sx.use_root("doors-hall")
	var g := Sx.game(tree, ["--seed=4", "--hour=11", "--weather=clear:0"])
	var d := _doors(g)
	var p: Vector2 = d.call(&"tour_place", "door:weapons_hall")
	check(p.is_finite(), "seed 4 has a hall door")
	g.player.hero.pos = p
	g.player.hero.facing = float(d.call(&"tour_face", "door:weapons_hall"))
	g.player.sync_view(0.0)
	await _frames(20)
	var t: Threshold = d.get("door_near")
	check(t != null and t.kind == &"weapons_hall", "standing at the hall's hatch")
	await d.call(&"go_in", t)
	check(bool(d.call(&"tour_seen", &"inside:weapons_hall")), "inside the hall")
	var pocket: InteriorGen.Pocket = d.get("pocket")
	var sim: FightSim = g.player.sim
	eq(sim.mobs.size(), pocket.layout.residents.size(), "every resident is a body in the fight, as it comes in")
	await _frames(60)
	var kinds: Array[StringName] = []
	for m: MobState in sim.mobs:
		if m.alive:
			kinds.append(m.kind)
	check(kinds.has(&"warden"), "the warden is still there a second later (%s)" % [kinds])
	eq(kinds.size(), pocket.layout.residents.size(), "and so is everything else that walks the hall")
	# And they are DRAWN: a body the fight holds and nobody draws is a fight with
	# the invisible (30_mobs makes a node for each, in group `mobs`).
	eq(tree.get_nodes_in_group(&"mobs").size(), kinds.size(), "each is drawn")
	Sx.end(g)
	Sx.finish()


## What a hall keeps: a resident broken stays broken (out through the hatch and
## back in, it is not there again), and a warden's arrest stands the player
## outside its door rather than in the hall it emptied.
func test_a_hall_remembers_its_dead_and_puts_the_arrested_out() -> void:
	Sx.use_root("doors-hall-dead")
	var g := Sx.game(tree, ["--seed=4", "--hour=11", "--weather=clear:0"])
	var d := _doors(g)
	var sim: FightSim = g.player.sim
	g.player.hero.pos = d.call(&"tour_place", "door:weapons_hall")
	g.player.hero.facing = float(d.call(&"tour_face", "door:weapons_hall"))
	g.player.sync_view(0.0)
	await _frames(20)
	var t: Threshold = d.get("door_near")
	await d.call(&"go_in", t)
	var before := sim.mobs.size()
	gt(float(before), 1.0, "the hall has its residents")
	# Break the warden through the one door anything but the player's swing uses.
	var warden: MobState = null
	for m: MobState in sim.mobs:
		if m.kind == &"warden":
			warden = m
	check(warden != null, "a warden keeps the hall")
	var b := TurretRules.blow()
	b.dmg = 999
	for i in 6:
		if warden.alive:
			sim.strike(warden, b, warden.pos + Vector2(0.5, 0.0))
		await _frames(3)
	check(not warden.alive, "the warden is broken")
	await d.call(&"go_out")
	await _frames(40)
	g.player.hero.pos = d.call(&"tour_place", "door:weapons_hall")
	g.player.hero.facing = float(d.call(&"tour_face", "door:weapons_hall"))
	g.player.sync_view(0.0)
	await _frames(20)
	await d.call(&"go_in", d.get("door_near"))
	var kinds: Array[StringName] = []
	for m: MobState in sim.mobs:
		kinds.append(m.kind)
	check(not kinds.has(&"warden"), "back in, the broken warden is not there again (%s)" % [kinds])
	eq(kinds.size(), before - 1, "and the rest of the hall still is")
	# An arrest in the hall: out of its door.
	Events.time_skipped.emit(60.0, &"arrested")
	# The door's cover takes real time to close and open, so wait on the clock.
	var until := Time.get_ticks_msec() + 3000 * TestCase.machine_slack()
	while not bool(d.call(&"tour_seen", &"outside")) and Time.get_ticks_msec() < until:
		await _frames(1)
	check(bool(d.call(&"tour_seen", &"outside")), "arrested in the hall, the player is put outside")
	near(g.player.pos.distance_to(t.door), 0.0, 1.6, "at the hatch")
	Sx.end(g)
	Sx.finish()


## THE WARDEN HOLDS THE HALL: while it stands a turret hurts a player in its line
## and the strongboxes refuse the key; broken, a box gives up the kind's table
## (the one economy) once, and the turrets stand down.
func test_the_warden_holds_the_turrets_and_the_boxes() -> void:
	Sx.use_root("doors-hall-guard")
	var g := Sx.game(tree, ["--seed=4", "--hour=11", "--weather=clear:0"])
	var d := _doors(g)
	var sim: FightSim = g.player.sim
	g.player.hero.pos = d.call(&"tour_place", "door:weapons_hall")
	g.player.hero.facing = float(d.call(&"tour_face", "door:weapons_hall"))
	g.player.sync_view(0.0)
	await _frames(20)
	await d.call(&"go_in", d.get("door_near"))
	var pocket: InteriorGen.Pocket = d.get("pocket")
	# The residents would settle this before the turrets could: stand them off,
	# so what is measured is the turrets alone.
	var warden: MobState = null
	for m: MobState in sim.mobs:
		if m.kind == &"warden":
			warden = m
		# Stunned and rooted for the length of the test (the fight's own fields).
		m.stun_until = INF
		m.pace = 0.0
		m.dash = 0.0
	# In a turret's line: the hall's middle, where every corner can see.
	var mid := Vector2(pocket.layout.hearth.x, pocket.layout.hearth.y + 1.2)
	g.player.hero.pos = mid
	g.player.sync_view(0.0)
	# Hurts are counted as the fight reports them (40_fight turns every one into
	# Events.hit with the player as the target), not off the health number, which
	# the body and the hazards also write.
	var hurts := [0]
	var on_hit := func(_by: Variant, target: Variant, _dmg: int, _crit: bool, _at: Vector3) -> void:
		if target == g.player:
			hurts[0] += 1
	Events.hit.connect(on_hit)
	var until := Time.get_ticks_msec() + 6000 * TestCase.machine_slack()
	while not bool(d.call(&"tour_seen", &"turret_shot")) and Time.get_ticks_msec() < until:
		g.player.hero.pos = mid
		await _frames(1)
	# The fight's events are drained on its physics step, which a headless frame
	# can outrun: wait on the clock for the report.
	var report := Time.get_ticks_msec() + 1000 * TestCase.machine_slack()
	while hurts[0] == 0 and Time.get_ticks_msec() < report:
		await _frames(1)
	check(bool(d.call(&"tour_seen", &"turret_shot")), "a turret fired on the player in its line")
	gt(float(hurts[0]), 0.0, "and it hurt")
	# A strongbox refuses while the warden stands.
	var box := Vector2.INF
	for t: Dictionary in pocket.layout.things:
		if t.kind == &"strongbox":
			box = (t.at as Vector2) + (t.face as Vector2) * 0.8
			break
	check(box.is_finite(), "the hall has a strongbox")
	g.player.hero.pos = box
	g.player.sync_view(0.0)
	await _frames(5)
	d.call(&"_open_box", int(d.get("box_near")))
	check(bool(d.call(&"tour_seen", &"box_refused")), "shut while the warden stands")
	# Break the warden; the box opens, once, and pays out the table.
	var b := TurretRules.blow()
	b.dmg = 999
	for i in 6:
		if warden.alive:
			sim.strike(warden, b, warden.pos + Vector2(0.5, 0.0))
		await _frames(3)
	check(not warden.alive, "the warden is broken")
	var scrap := g.inventory.count(&"scrap")
	d.call(&"_open_box", int(d.get("box_near")))
	check(bool(d.call(&"tour_seen", &"box_opened")), "the box opens once the warden is broken")
	gt(float(g.inventory.count(&"scrap")), float(scrap), "and pays out the hall's table")
	var after := g.inventory.count(&"scrap")
	d.call(&"_open_box", int(d.get("box_near")))
	eq(g.inventory.count(&"scrap"), after, "and only once")
	# The turrets stand down: nothing more lands.
	d.call(&"tour_forget", &"turret_shot")
	var h2: int = hurts[0]
	until = Time.get_ticks_msec() + 3500 * TestCase.machine_slack()
	while Time.get_ticks_msec() < until:
		g.player.hero.pos = mid
		await _frames(1)
	check(not bool(d.call(&"tour_seen", &"turret_shot")), "with the warden broken the turrets stand down")
	eq(hurts[0], h2, "and nothing more lands")
	Events.hit.disconnect(on_hit)
	Sx.end(g)
	Sx.finish()


## THE EYE STAYS OUT OF THE HATCH. Put out at a hatch (an arrest does it), the
## player faces away from it and the shoulder camera stands behind them -- toward
## the housing. The eye is never let nearer the head than Shoulder.LEAST_BACK, so
## no probe can hold it out of a housing the player stands too close to: the door
## puts them out far enough (21_doors EXIT_OUT), and the housing's own box
## (`sight_boxes`) holds the eye off its corners from there.
func test_the_shoulder_eye_stays_out_of_a_hatch() -> void:
	Sx.use_root("doors-hatch-eye")
	var g := Sx.game(tree, ["--seed=4", "--hour=11", "--weather=clear:0"])
	var d := _doors(g)
	var shoulder: Node = Sx.system(g, "41_shoulder")
	var t: Threshold = null
	for th: Threshold in d.get("doors"):
		if th.kind == &"weapons_hall":
			t = th
	check(t != null, "seed 4 has a hatch")
	# Where an arrest leaves the player, and a line back past them into the housing,
	# a little off its middle so it runs toward a corner.
	var stand := t.door + t.out * float(d.get_script().get_script_constant_map()["EXIT_OUT"])
	var y := g.world.height_at(stand)
	# A level line at the height the eye stands over the shoulder, aimed at a
	# CORNER of the housing, where the body's circle does not reach.
	var head := Vector3(stand.x, y + 1.25, stand.y)
	var corner := t.host + Vector2(0.75, 0.75).rotated(t.rot)
	var back := (corner - stand).normalized()
	var eye := head + Vector3(back.x, 0.0, back.y) * 3.0
	var share: float = shoulder.call(&"room", head, eye)
	var at := head.lerp(eye, share)
	# The housing's face toward the doorstep, in the hatch's own frame.
	var local := (Vector2(at.x, at.z) - t.host).rotated(-t.rot)
	var inside := local.x > -1.0 and local.x < 0.82 and absf(local.y) < 0.8
	check(not inside, "put out, the eye stands outside the housing (%s in its frame, share %.2f)" % [local, share])
	Sx.end(g)
	Sx.finish()
