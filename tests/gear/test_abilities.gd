extends TestCase
## The one ability interface: what the five of them do, what they cost, what
## refuses them, and the moves they hand back. Everything here runs without a
## frame being drawn, which is the point of AbilityCtx.

const Fx := preload("res://tests/survival/fixture.gd")


## A ctx over a flat field, with a note of every mark an ability asked for.
class Seen:
	extends RefCounted
	var marks: Array[StringName] = []
	func fx(what: StringName, _args: Dictionary) -> void:
		marks.append(what)


func _ctx(g: Game, seen: Seen, now: float = 100.0) -> AbilityCtx:
	var c := AbilityCtx.new()
	c.game = g
	c.now = now
	c.fx = seen.fx
	return c


func test_every_ability_declares_what_the_one_interface_needs() -> void:
	for id in Abilities.IDS:
		var a := Abilities.make(id)
		check(a != null, "%s is built" % id)
		eq(a.id, id, "it knows its own name")
		check(a.name != "", "%s reads as something" % id)
		check(a.action != &"", "%s answers to an input action" % id)
		check(InputMap.has_action(a.action), "%s's action %s is bound in project.godot" % [id, a.action])
		gt(a.cooldown, 0.0, "%s cools down" % id)
		check(a.note != "", "%s says what it is on the gear page" % id)
	eq(Abilities.make(&"nothing_like_this"), null, "an unknown id builds nothing")
	# Every action is distinct: two abilities never fight over one key.
	var seen: Array[StringName] = []
	for act in Abilities.actions():
		check(not seen.has(act), "%s is bound to one ability" % act)
		seen.append(act)


func test_the_book_refuses_before_it_fires_and_says_why_in_order() -> void:
	var g := Fx.flat()
	var seen := Seen.new()
	var book := AbilityBook.new()
	eq(book.press(&"dash", _ctx(g, seen)), &"nothing", "an ability not fitted is not there")
	book.fit([&"dash"] as Array[StringName])
	eq(book.press(&"dash", _ctx(g, seen)), &"", "fitted, it fires")
	check(seen.marks.has(&"dash"), "and it is drawn")
	eq(book.press(&"dash", _ctx(g, seen)), &"cooling", "not twice in a breath")
	gt(book.cooldown_left(&"dash", 100.0), 0.0)
	eq(book.press(&"dash", _ctx(g, seen, 100.0 + AbilityDash.COOLDOWN + 0.1)), &"", "once it is cool, again")
	# A refusal has a line, every time.
	for why: StringName in Ability.REFUSALS:
		check(Ability.refusal_line(why) != "", "%s reads as a sentence" % why)
	check(Ability.refusal_line(&"something_new") != "", "and so does one nothing named")
	Fx.done(g)


func test_found_tech_spends_charges_and_a_burst_spends_breath() -> void:
	var g := Fx.flat()
	var seen := Seen.new()
	var book := AbilityBook.new()
	book.fit([&"spoof", &"dash"] as Array[StringName])
	eq(book.press(&"spoof", _ctx(g, seen)), &"no_charge", "the signet is dead without a charge")
	g.inventory.add(&"wick", 2)
	eq(book.press(&"spoof", _ctx(g, seen)), &"", "with one, it speaks")
	eq(g.inventory.count(&"wick"), 1, "and a charge is gone")
	# Wind: the hero owns it, so a dash costs breath when there is a fight body.
	var sim := FightSim.new(g.world, g.query)
	sim.hero.pos = g.player.pos
	g.player.hero = sim.hero
	g.player.sim = sim
	sim.hero.wind = AbilityDash.WIND - 1.0
	eq(book.press(&"dash", _ctx(g, seen, 500.0)), &"winded", "no breath, no burst")
	sim.hero.wind = AbilityDash.WIND * 2.0
	eq(book.press(&"dash", _ctx(g, seen, 500.0)), &"", "with breath, yes")
	near(sim.hero.wind, AbilityDash.WIND, 1e-3, "and it cost what it says")
	Fx.done(g)


func test_a_dash_is_a_burst_along_the_way_you_are_going() -> void:
	var g := Fx.flat()
	var seen := Seen.new()
	var book := AbilityBook.new()
	book.fit([&"dash"] as Array[StringName])
	g.player.facing = 0.0
	var ctx := _ctx(g, seen)
	eq(book.press(&"dash", ctx), &"")
	check(ctx.motion != null, "it hands back a move")
	eq(ctx.motion.kind, &"dash")
	var at := g.player.pos
	var p := at
	for i in 60:
		p = ctx.motion.step(1.0 / 60.0, p, g.world, g.query, Tuning.PLAYER_RADIUS)
		if ctx.motion.finished:
			break
	gt(p.distance_to(at), 1.5, "it covers ground")
	lt(p.distance_to(at), 4.0, "a burst, not a journey")
	near(ctx.motion.lift, 0.0, 1e-6, "with both feet on the ground")
	check(ctx.motion.finished, "and it ends by itself")
	Fx.done(g)


func test_a_glide_needs_a_height_and_carries_you_off_it() -> void:
	# A field with a cliff down its middle: level 6 to the west, level 1 east.
	var w := WorldData.new(11, 40)
	for y in 40:
		for x in 40:
			var i := y * 40 + x
			var rim := x == 0 or y == 0 or x == 39 or y == 39
			w.level[i] = -1 if rim else (6 if x < 20 else 1)
			w.ground[i] = Ground.DEEP_WATER if rim else Ground.GRASS
			w.country[i] = Country.SEA if rim else Country.COAST
	w.spawn = Vector2(18.5, 20.5)
	var g := Fx.from_world(w)
	var seen := Seen.new()
	var book := AbilityBook.new()
	book.fit([&"glide"] as Array[StringName])
	g.player.facing = PI  # west, into the high ground
	eq(book.press(&"glide", _ctx(g, seen)), &"no_drop", "there is nothing to step off behind you")
	g.player.facing = 0.0  # east, over the edge
	check(AbilityGlide.launch(w, g.query, g.player.pos, Vector2.RIGHT) != Vector2.ZERO, "the drop is found")
	var ctx := _ctx(g, seen)
	eq(book.press(&"glide", ctx), &"")
	eq(ctx.motion.kind, &"glide")
	var at := g.player.pos
	var p := at
	var highest := 0.0
	for i in 600:
		p = ctx.motion.step(1.0 / 60.0, p, w, g.query, Tuning.PLAYER_RADIUS)
		highest = maxf(highest, ctx.motion.lift)
		if ctx.motion.finished:
			break
	check(ctx.motion.finished, "it lands")
	gt(highest, 0.5, "it was off the ground on the way")
	near(ctx.motion.lift, 0.0, 1e-6, "and on it again at the end")
	gt(p.x - at.x, 3.0, "it carried the body out over ground a walk could not get down")
	eq(w.level_at(floori(p.x), floori(p.y)), 1, "onto the low side")
	Fx.done(g)


## A wing over the sea is the obvious way to drown a player, so it may not end a
## flight anywhere a body cannot stand: it skims until there is ground, and when
## everything has run out it is set down ashore.
func test_a_glide_never_sets_a_body_down_in_the_water() -> void:
	# Land to the west at level 6, then open water from x = 20 out.
	var w := WorldData.new(12, 60)
	for y in 60:
		for x in 60:
			var i := y * 60 + x
			var land := x < 20 and x > 0 and y > 0 and y < 59
			w.level[i] = 6 if land else -1
			w.ground[i] = Ground.GRASS if land else Ground.DEEP_WATER
			w.country[i] = Country.COAST if land else Country.SEA
	w.spawn = Vector2(18.5, 30.5)
	var g := Fx.from_world(w)
	var m := AbilityMotion.glide(g.player.pos, Vector2.RIGHT, AbilityGlide.SPEED, AbilityGlide.FALL,
		AbilityGlide.SECONDS, w.height_at(g.player.pos))
	var p := g.player.pos
	var out_over_water := false
	for i in 4000:
		p = m.step(1.0 / 60.0, p, w, g.query, Tuning.PLAYER_RADIUS)
		out_over_water = out_over_water or not g.query.standable(floori(p.x), floori(p.y))
		if m.finished:
			break
	check(m.finished, "the flight ends: it never runs on for ever")
	check(out_over_water, "it did carry the body out over the water")
	check(g.query.standable(floori(p.x), floori(p.y)), "and set it down on ground it can stand on")
	near(m.lift, 0.0, 1e-6, "on the ground, not hanging over it")
	lt(m.t, AbilityGlide.SECONDS + AbilityMotion.OVERRUN + 1.0, "and the overrun is bounded")
	Fx.done(g)


func test_a_grapple_takes_hold_of_what_is_there_and_pulls() -> void:
	var g := Fx.flat(48)
	var seen := Seen.new()
	var book := AbilityBook.new()
	book.fit([&"grapple"] as Array[StringName])
	g.player.facing = 0.0
	eq(book.press(&"grapple", _ctx(g, seen)), &"no_anchor", "an empty field offers nothing")
	var post := Fx.put(g, PropKind.POLE, Vector2(5.0, 0.0))
	var a := AbilityGrapple.anchor(g.world, g.query, g.player.pos, Vector2.RIGHT)
	check(not a.is_empty(), "a post ahead is a hold")
	eq(a.what, &"prop")
	check(AbilityGrapple.anchor(g.world, g.query, g.player.pos, Vector2.LEFT).is_empty(), "one behind you is not")
	var ctx := _ctx(g, seen)
	eq(book.press(&"grapple", ctx), &"")
	var p := g.player.pos
	for i in 600:
		p = ctx.motion.step(1.0 / 60.0, p, g.world, g.query, Tuning.PLAYER_RADIUS)
		if ctx.motion.finished:
			break
	check(ctx.motion.finished, "the pull ends")
	lt(p.distance_to(post.pos), 1.4, "at the thing it took hold of")
	gt(p.distance_to(post.pos), 0.3, "and short of standing inside it")
	Fx.done(g)


func test_a_scan_runs_for_a_few_seconds_and_marks_on_a_beat() -> void:
	var g := Fx.flat()
	var seen := Seen.new()
	var book := AbilityBook.new()
	book.fit([&"scan"] as Array[StringName])
	var scan := book.ability(&"scan") as AbilityScan
	check(not scan.active(100.0), "nothing until it is asked for")
	eq(book.press(&"scan", _ctx(g, seen)), &"")
	check(scan.active(100.0), "then it stands")
	eq(book.press(&"scan", _ctx(g, seen, 101.0)), &"cooling", "the cooldown is the first reason it refuses")
	eq(scan.refusal(_ctx(g, seen, 101.0)), &"already", "and it would refuse to start twice anyway")
	var beats := 0
	var t := 100.0
	while t < 100.0 + AbilityScan.SECONDS:
		scan.passive(_ctx(g, seen, t), 0.1)
		t += 0.1
	for m in seen.marks:
		beats += 1 if m == &"scan_beat" else 0
	gt(float(beats), 3.0, "it is laid down again on its beat")
	lt(float(beats), AbilityScan.SECONDS / AbilityScan.BEAT + 2.0, "and no faster than its beat")
	check(not scan.active(100.0 + AbilityScan.SECONDS + 0.1), "then it runs out")
	Fx.done(g)


func test_a_spoof_makes_the_machines_read_you_as_one_of_theirs() -> void:
	var g := Fx.flat()
	var seen := Seen.new()
	var book := AbilityBook.new()
	book.fit([&"spoof"] as Array[StringName])
	g.inventory.add(&"wick", 1)
	check(not AbilitySpoof.spoofed(g.body, g.clock.minutes), "not yet")
	eq(book.press(&"spoof", _ctx(g, seen)), &"")
	check(AbilitySpoof.spoofed(g.body, g.clock.minutes), "the body carries their signature")
	near(g.body.spoof_until, g.clock.minutes + AbilitySpoof.MINUTES, 1e-4)
	# And the senses answer to it: a machine walks past, a dog does not.
	var m := Moment.new()
	m.spoofed = true
	var machine := {"machine": true, "sees": 20.0, "hears": 20.0}
	var dog := {"machine": false, "sees": 20.0, "hears": 20.0}
	var here := Vector2(4, 4)
	var there := Vector2(6, 4)
	check(not Senses.notices(machine, here, there, m, g.world, g.query), "a machine files nothing")
	check(Senses.notices(dog, here, there, m, g.world, g.query), "a dog is not fooled by a stolen signet")
	m.spoofed = false
	check(Senses.notices(machine, here, there, m, g.world, g.query), "and when it runs out they see you again")
	# It ends by itself, once, with a mark.
	var spoof := book.ability(&"spoof") as AbilitySpoof
	g.body.spoof_until = g.clock.minutes - 1.0
	spoof.passive(_ctx(g, seen), 0.1)
	check(seen.marks.has(&"spoof_ended"), "the player is told they can be read again")
	seen.marks.clear()
	spoof.passive(_ctx(g, seen), 0.1)
	check(not seen.marks.has(&"spoof_ended"), "and told once")
	Fx.done(g)


func test_cooldowns_survive_a_save_as_time_left_not_as_a_stopwatch() -> void:
	var g := Fx.flat()
	var seen := Seen.new()
	var book := AbilityBook.new()
	book.fit([&"dash"] as Array[StringName])
	book.press(&"dash", _ctx(g, seen, 1000.0))
	var saved: Variant = JSON.parse_string(JSON.stringify(book.save(1000.5)))
	var back := AbilityBook.new()
	back.fit([&"dash"] as Array[StringName])
	# A new run: the clock started again at nothing.
	back.load_from(saved, 5.0)
	near(back.cooldown_left(&"dash", 5.0), AbilityDash.COOLDOWN - 0.5, 1e-3, "what was left is still left")
	check(back.ready(&"dash", 5.0 + AbilityDash.COOLDOWN), "and it comes ready on time")
	Fx.done(g)


func test_the_gear_page_reads_the_book() -> void:
	var g := Fx.flat()
	var seen := Seen.new()
	var book := AbilityBook.new()
	book.fit([&"dash", &"scan"] as Array[StringName])
	var rows := book.rows(100.0)
	eq(rows.size(), 2)
	check(bool(rows[0].ready), "a cool ability reads as ready")
	book.press(&"dash", _ctx(g, seen))
	var warm := book.rows(100.0)
	check(not bool(warm[0].ready), "a warm one does not")
	check(String(warm[0].note).ends_with("s"), "and says how long")
	Fx.done(g)


## A dart is not there to be fought (tests/fight/test_matchups.gd leaves it
## out): a scan that reads one says what its answer is. Nothing else is read.
func test_a_scan_says_what_answers_a_dart() -> void:
	eq(AbilityScan.advice(Roster.row(&"warden")), "It takes and goes. Break its sight.", "a warden's read")
	eq(AbilityScan.advice(Roster.row(&"cutter")), "", "a machine that fights gets no advice")
