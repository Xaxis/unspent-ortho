extends TestCase
## Targeting inside a real (small) game: holding the key locks the nearest
## threat and leans the camera, the keys cycle and sweep, letting go puts
## everything back — and none of it touches the fight. The last test is the
## rule the owner's ruling turned round: words on the glass only when the
## player asks for them by holding the key.

var _game: Game


## A game and its target system, begun on a FRESH input frame. The engine reads a
## key pressed and released inside one frame as just pressed for the whole of that
## frame, so a test that starts in the frame the last one ended in inherits its
## taps — and a lock test that inherits a scan key sweeps instead.
func _make(extra: PackedStringArray = []) -> Node:
	await tree.process_frame
	var args := PackedStringArray(["--size=64", "--seed=4", "--hour=11", "--weather=clear:0"])
	args.append_array(extra)
	_game = Game.new()
	tree.root.add_child(_game)
	_game.setup(BootOptions.parse(args))
	for s in _game.systems:
		if s.name == "42_target":
			return s
	return null


func _done() -> void:
	for a: StringName in [&"target", &"ability_scan", &"move_left", &"move_right", &"target_next", &"target_prev"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	_game.free()


func test_holding_the_key_locks_the_nearest_threat_and_leans_the_camera() -> void:
	var sys := await _make(PackedStringArray(["--spawn=runner", "--target"]))
	check(sys != null, "42_target is loaded from src/systems")
	sys.call("_process", 0.1)
	var locked: TargetSubject = sys.get("locked")
	check(locked != null, "a body is locked")
	eq(locked.kind, &"runner")
	check(locked.body != null and not locked.person)
	var cam := _game.camera
	check(not is_equal_approx(cam.lean_zoom, 1.0), "the camera is asked to zoom")
	check(absf(cam.lean_pitch) > 0.1, "and to lean its pitch")
	check(cam.lean_bias.length() > 0.01, "and to bias the frame toward what is read")
	var read: Dictionary = sys.get("read")
	check(not read.is_empty(), "the slate has a read of it")
	eq(str(read.name), "runner")
	check(str(read.thinking) != "", "and says what it is thinking")
	_done()


func test_letting_go_puts_the_camera_back_and_the_reads_away() -> void:
	var sys := await _make(PackedStringArray(["--spawn=runner", "--target"]))
	sys.call("_process", 0.1)
	check(sys.get("locked") != null)
	sys.set("_forced", false)
	sys.call("_process", 0.1)
	eq(sys.get("locked"), null, "nothing is locked")
	check((sys.get("read") as Dictionary).is_empty(), "and nothing is read")
	var cam := _game.camera
	eq(cam.lean_zoom, 1.0, "the camera is asked for no zoom")
	eq(cam.lean_pitch, 0.0)
	eq(cam.lean_yaw, 0.0)
	eq(cam.lean_bias, Vector3.ZERO)
	for i in 30:
		cam._process(0.05)
	check(not cam.leaning(), "and it eases back square")
	_done()


func test_the_keys_cycle_the_lock_and_sweep_the_field() -> void:
	var sys := await _make(PackedStringArray(["--spawn=runner,cutter,watcher", "--target"]))
	sys.call("_process", 0.1)
	var first: TargetSubject = sys.get("locked")
	check(first != null)
	Input.action_press(&"target_next")
	sys.call("_process", 0.1)
	Input.action_release(&"target_next")
	var second: TargetSubject = sys.get("locked")
	check(second != null and second.id != first.id, "the next key cycles to another body")
	# A frame between the two keys: inside one frame the engine still reads the
	# cycle key as just pressed, and a cycle key pressed into a sweep pages it.
	await tree.process_frame
	Input.action_press(&"ability_scan")
	sys.call("_process", 0.1)
	Input.action_release(&"ability_scan")
	check(bool(sys.get("sweeping")), "the scan key sweeps the field")
	eq(sys.get("locked"), null, "a sweep locks nothing")
	var field: Array = sys.get("field")
	check(field.size() >= 2, "and reads the field: %d" % field.size())
	var rows: Array = sys.get("rows")
	eq(rows.size(), field.size(), "one row a body")
	check(_game.camera.lean_zoom > 1.0, "the camera stands back for a field")
	_done()


## A machine that steps behind a house for half a second is the same machine: the
## lock waits for it rather than flicking onto its neighbour, and lets go once the
## grace is spent. (The fight's own clock stands still here, because only the
## target system is stepped — so the wait is set by hand for the second half.)
func test_a_lock_waits_for_a_body_that_steps_out_of_reach() -> void:
	var sys := await _make(PackedStringArray(["--spawn=runner,cutter", "--target"]))
	sys.call("_process", 0.1)
	var first: TargetSubject = sys.get("locked")
	check(first != null)
	var body: MobState = first.body
	var kept := body.pos
	body.pos = kept + Vector2(Targeting.LENS_REACH * 2.0, 0.0)
	sys.call("_process", 0.1)
	var still: TargetSubject = sys.get("locked")
	check(still != null and still.id == first.id, "the lock waits for what left the list")
	sys.set("_lost_at", _game.player.sim.now - Targeting.LOST_GRACE - 0.5)
	sys.call("_process", 0.1)
	var after: TargetSubject = sys.get("locked")
	check(after != null and after.id != first.id, "past the grace it takes what is there")
	body.pos = kept
	_done()


## A villager can be locked and read, and the words are a person's words: no
## health, no signature, no notice glyph — what they are and what they are doing.
func test_a_villager_can_be_read_as_a_person() -> void:
	var sys := await _make(PackedStringArray(["--folk=6", "--target"]))
	sys.call("_process", 0.1)
	# A person sorts below everything in the fight, so one step left from a fresh
	# lock lands on one whatever else the coast has sent out.
	Input.action_press(&"move_left")
	sys.call("_process", 0.1)
	Input.action_release(&"move_left")
	var locked: TargetSubject = sys.get("locked")
	check(locked != null and locked.person, "one of the last people is locked")
	var read: Dictionary = sys.get("read")
	eq(str(read.role), "one of the last people")
	check((read.pips as Array).is_empty(), "no pips for a life nothing measures")
	check(str(read.thinking) != "")
	var view: UiTargetView = sys.get("view")
	await tree.process_frame
	UiDraw.tape.clear()
	UiDraw.taping = true
	view._canvas.queue_redraw()
	await tree.process_frame
	var said := PackedStringArray()
	for d: Dictionary in UiDraw.tape:
		if d.ci == view._canvas and d.kind == &"text":
			said.append(str(d.text))
	UiDraw.taping = false
	check(" ".join(said).contains("one of the last people"), "the slate says who they are: %s" % said)
	_done()


## Nothing within reach may be unreachable: a field bigger than one page says so,
## and the cycle keys page through it.
func test_a_sweep_pages_through_a_big_field() -> void:
	# The sweep is held from boot (--target=sweep) rather than pressed here: inside
	# one frame the engine still reads a released key as just pressed, so a second
	# read of the scan key in the same frame would toggle the sweep straight off.
	var sys := await _make(PackedStringArray(["--folk=12", "--target=sweep"]))
	sys.call("_process", 0.1)
	check(bool(sys.get("sweeping")))
	gt(int(sys.get("pages")), 1, "twelve within reach is more than one page")
	eq(int(sys.get("page")), 1)
	var first: Array = (sys.get("field") as Array).duplicate()
	eq(first.size(), Targeting.SWEEP_MOST, "a page, not a census")
	Input.action_press(&"target_next")
	sys.call("_process", 0.1)
	Input.action_release(&"target_next")
	eq(int(sys.get("page")), 2, "the cycle keys page a sweep")
	var second: Array = sys.get("field")
	check(not second.is_empty())
	var ids := PackedInt64Array()
	for s: TargetSubject in first:
		ids.append(s.id)
	for s: TargetSubject in second:
		check(not ids.has(s.id), "the second page holds who the first could not")
	check(bool(sys.get("sweeping")), "and paging never lets the sweep go")
	_done()


## C3 (docs/CONTROLS.md): a strafe round a locked body must never change which
## body it is. The move keys used to cycle the lock, so every side-step moved it.
func test_strafing_never_cycles_the_lock() -> void:
	var sys := await _make(PackedStringArray(["--spawn=runner,cutter,watcher", "--target"]))
	sys.call("_process", 0.1)
	var first: TargetSubject = sys.get("locked")
	check(first != null)
	for a: StringName in [&"move_right", &"move_left", &"move_right"]:
		await tree.process_frame
		Input.action_press(a)
		sys.call("_process", 0.1)
		Input.action_release(a)
	var still: TargetSubject = sys.get("locked")
	check(still != null and still.id == first.id, "the same body is locked after three side-steps")
	_done()


## While the key is held the scroll cycles the lock and the zoom is off (owner's
## ruling); let go, the scroll is the zoom's again.
func test_the_scroll_cycles_a_held_lock_and_takes_the_zoom() -> void:
	var sys := await _make(PackedStringArray(["--spawn=runner,cutter,watcher", "--target"]))
	sys.call("_process", 0.1)
	var first: TargetSubject = sys.get("locked")
	check(bool(sys.call("owns_zoom")), "a held lock has the zoom keys")
	check(bool(sys.call("take_scroll", Vector2(0.0, 1.0))), "and takes a notch of scroll")
	sys.call("_process", 0.1)
	var second: TargetSubject = sys.get("locked")
	check(second != null and second.id != first.id, "one notch moved the lock on")
	# A trackpad's swipe arrives in fractions: gathered, it moves once, not four times.
	for i in 4:
		sys.call("take_scroll", Vector2(0.3, 0.0))
	sys.call("_process", 0.1)
	var third: TargetSubject = sys.get("locked")
	check(third != null and third.id != second.id, "a swipe's fractions made one step")
	sys.set("_forced", false)
	sys.call("_process", 0.1)
	check(not bool(sys.call("owns_zoom")), "let go, the zoom is the camera's again")
	check(not bool(sys.call("take_scroll", Vector2(0.0, 1.0))), "and so is the scroll")
	_done()


## The one write to the fight: where the lock is, handed to the body, and taken
## back the moment the key is let go.
func test_the_lock_is_handed_to_the_body_and_taken_back() -> void:
	var sys := await _make(PackedStringArray(["--spawn=runner", "--target"]))
	var hero := _game.player.hero
	sys.call("_process", 0.1)
	var locked: TargetSubject = sys.get("locked")
	eq(hero.lock, locked.here(), "the body holds the point the lock is on")
	sys.set("_forced", false)
	sys.call("_process", 0.1)
	check(not hero.lock.is_finite(), "let go, the body holds nothing")
	check(is_finite(hero.unlocked_at), "and knows when it was let go, to turn back smoothly")
	_done()


func test_targeting_changes_nothing_in_the_fight() -> void:
	var sys := await _make(PackedStringArray(["--spawn=runner", "--target"]))
	var sim := _game.player.sim
	var body: MobState = sim.mobs[0]
	var before := {"health": body.health, "pos": body.pos, "mood": body.mood, "facing": body.facing,
		"hero_health": sim.hero.health, "hero_pos": sim.hero.pos, "hero_facing": sim.hero.facing}
	sim.out.clear()
	for i in 10:
		sys.call("_process", 0.05)
	eq(body.health, before.health, "the body is not touched")
	eq(body.pos, before.pos)
	eq(body.mood, before.mood)
	eq(body.facing, before.facing)
	eq(sim.hero.health, before.hero_health, "and neither is the player")
	eq(sim.hero.pos, before.hero_pos)
	# The facing turns in the fight's OWN step (LockOn), never here: this system
	# hands over a point and the simulation decides what a body does with it.
	eq(sim.hero.facing, before.hero_facing, "targeting itself turns nobody")
	eq(sim.out.size(), 0, "and the fight hears nothing from it")
	_done()


## The owner's ruling, drawn: every body carries a wordless tag at all times, and
## words appear only while the key is held (docs/DESIGN.md §Targeting).
func test_words_only_when_the_player_asks_for_them() -> void:
	var sys := await _make(PackedStringArray(["--spawn=runner"]))
	var view: UiTargetView = sys.get("view")
	await tree.process_frame
	UiDraw.tape.clear()
	UiDraw.taping = true
	view._canvas.queue_redraw()
	await tree.process_frame
	var words := 0
	var marks := 0
	for d: Dictionary in UiDraw.tape:
		# Only what targeting drew: the slate's own edge readouts are the HUD's.
		if d.ci != view._canvas:
			continue
		if d.kind == &"text":
			words += 1
		else:
			marks += 1
	UiDraw.taping = false
	eq(words, 0, "nothing is written over a fight nobody asked about")
	check(marks > 0, "but the body still carries its tag: %d marks" % marks)
	sys.set("_forced", true)
	sys.call("_process", 0.1)
	UiDraw.tape.clear()
	UiDraw.taping = true
	view._canvas.queue_redraw()
	await tree.process_frame
	var said := PackedStringArray()
	for d: Dictionary in UiDraw.tape:
		if d.ci == view._canvas and d.kind == &"text":
			said.append(str(d.text))
	UiDraw.taping = false
	check(said.size() > 4, "held, the slate says what it is: %s" % said)
	check(said.has("RUNNER  hunter") or said.has("RUNNER hunter"), "its name and its place in the plan: %s" % said)
	var lines := " ".join(said)
	check(lines.contains("blow"), "what it hits with")
	check(lines.contains("sees"), "what it can sense")
	_done()


## The tag is the QUIETEST layer (docs/LOOK.md; A2 art finding 2). What was
## here was an opaque UiTheme.RIM lozenge over every body, whose darkest pixels
## sat at luminance 7.3 when nothing else in frame went below 12 — a small black
## HUD sprite standing in the world, which is the charge the scan ring was
## convicted on. Nothing the tag lays over the world may be opaque, and nothing
## it lays may be darker than the slate's own glass.
func test_the_tag_never_lays_an_opaque_hole_in_the_world() -> void:
	var sys := await _make(PackedStringArray(["--spawn=runner"]))
	var view: UiTargetView = sys.get("view")
	await tree.process_frame
	UiDraw.tape.clear()
	UiDraw.taping = true
	view._canvas.queue_redraw()
	await tree.process_frame
	# The darkest ground the tag is ever laid over, as the frames actually measure:
	# nothing in a daylight frame goes below this, so this is where the tag is
	# tested. Composited over it, the tag must still not go under it.
	const DARKEST_GROUND := 12.0
	var glass := _lum(UiTheme.GLASS) * 255.0
	var backings := 0
	var worst := 255.0
	for d: Dictionary in UiDraw.tape:
		if d.ci != view._canvas:
			continue
		var col: Color = d.col
		var lum := _lum(col) * 255.0
		if lum > glass:
			continue
		# Anything at or under the slate's own glass is a backing, and a backing
		# that is opaque is a hole cut in the frame.
		backings += 1
		worst = minf(worst, lum * col.a + DARKEST_GROUND * (1.0 - col.a))
		lt(col.a, 0.999, "the tag lays %s opaque over the world" % col.to_html(false))
	check(backings > 0, "the tag does put something quiet behind its pips")
	gt(worst, DARKEST_GROUND,
		"over the darkest ground in a frame the tag still lands at %.1f, under its %.0f"
			% [worst, DARKEST_GROUND])
	UiDraw.taping = false
	_done()


static func _lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


## A FRESH LOCK NEEDS THE BODY IN SIGHT (teammate1, 2026-09-24): locking through
## a wall read whatever stood behind it, a free scan in a game about not being
## seen. A runner on the far side of a house is not picked; stepped out into the
## open, it is. A lock already held keeps its grace behind cover, as before.
func test_a_fresh_lock_needs_the_body_in_sight() -> void:
	var sys := await _make(PackedStringArray(["--spawn=runner"]))
	var g := _game
	var sim := g.player.sim
	var runner: MobState = null
	for m: MobState in sim.mobs:
		if m.kind == &"runner":
			runner = m
	check(runner != null, "a runner to hide")
	var house: WorldProp = null
	var best := INF
	for p: WorldProp in g.world.each_prop():
		if p.kind == PropKind.HOUSE and p.pos.distance_to(g.player.pos) < best:
			best = p.pos.distance_to(g.player.pos)
			house = p
	check(house != null, "a house to hide it behind")
	var dir := Vector2.RIGHT.rotated(0.3)
	var near := house.solid + 1.4
	_stand(g, house.pos + dir * near)
	runner.pos = house.pos - dir * near
	runner.calm_until = INF
	sys.set("_forced", true)
	sys.set("_sight_next", 0.0)
	sys.call("_process", 0.1)
	var locked: TargetSubject = sys.get("locked")
	check(locked == null or locked.kind != &"runner", "not through the house: %s" % (locked.kind if locked != null else &"nothing"))
	runner.pos = house.pos + dir * (near + 2.5)
	sys.set("_sight_next", 0.0)
	sys.set("locked", null)
	sys.call("_process", 0.1)
	locked = sys.get("locked")
	check(locked != null and locked.kind == &"runner", "in the open it is locked: %s" % (locked.kind if locked != null else &"nothing"))
	# Held, then hidden: it keeps the lock, as a held lock always has.
	runner.pos = house.pos - dir * near
	sys.call("_process", 0.1)
	locked = sys.get("locked")
	check(locked != null and locked.kind == &"runner", "a lock already held is kept behind cover")
	_done()


func _stand(g: Game, at: Vector2) -> void:
	g.player.hero.pos = at
	g.player.sync_view(0.0)


## THE SWEEP IS HELD TO SIGHT TOO (teammate1, 2026-09-24): otherwise it is the
## free scan the fresh-pick rule closes. A calm runner on the far side of a house
## is not in the field; one that has come for the player is, wall or no wall --
## it is on its way and would be heard.
func test_a_sweep_reads_only_what_is_seen_or_coming() -> void:
	var sys := await _make(PackedStringArray(["--spawn=runner", "--target=sweep"]))
	var g := _game
	var runner: MobState = null
	for m: MobState in g.player.sim.mobs:
		if m.kind == &"runner":
			runner = m
	var house: WorldProp = null
	var best := INF
	for p: WorldProp in g.world.each_prop():
		if p.kind == PropKind.HOUSE and p.pos.distance_to(g.player.pos) < best:
			best = p.pos.distance_to(g.player.pos)
			house = p
	var dir := Vector2.RIGHT.rotated(0.3)
	var near := house.solid + 1.4
	_stand(g, house.pos + dir * near)
	runner.pos = house.pos - dir * near
	runner.calm_until = INF
	runner.mood = MobState.IDLE
	sys.call("_process", 0.1)
	check(bool(sys.get("sweeping")), "sweeping")
	check(not _in_field(sys, &"runner"), "a calm runner behind the house is not read")
	runner.mood = MobState.CHASING
	sys.set("_sweep_next", 0.0)
	sys.call("_process", 0.1)
	check(_in_field(sys, &"runner"), "one coming for you is read, wall or no wall")
	runner.mood = MobState.IDLE
	runner.pos = house.pos + dir * (near + 2.5)
	sys.set("_sweep_next", 0.0)
	sys.call("_process", 0.1)
	check(_in_field(sys, &"runner"), "and a calm one in the open is read")
	_done()


func _in_field(sys: Node, kind: StringName) -> bool:
	for s: TargetSubject in sys.get("field"):
		if s.kind == kind:
			return true
	return false
