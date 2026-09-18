extends TestCase
## A game played a little (walk, take, build, make, sleep, and the rest of what a
## body carries away from a day), saved to a slot through the save system, then
## booted again from that slot the way Continue boots one: every registered key
## reads back the same, the live world agrees, and it is all in place before a
## single frame has been drawn.

const Sx := preload("res://tests/save/save_fixture.gd")


## Keys that hold REAL elapsed time, and the field of each that does.
##
## `play` counts `play_seconds += delta` and `score` carries the conductor's own
## clock. Neither stops for the comparison: the save is collected, a game is torn
## down, a world is grown again and a second game is built, and by then both have
## moved on. Held to bit-equality they were a coin flip on how busy the machine
## was -- seen once at 0.0192 against 0.0021 with the laptop at load 30-50, green
## alone, red in a gate.
##
## A TOLERANCE WOULD BE THE SAME MISTAKE ONE STEP OUT: a number small enough to
## catch a reset today is a number a slower machine breaches tomorrow. What the
## round trip is actually for is that the value CAME BACK -- that the key was
## written, read and not silently reset to zero -- and a running clock can be
## asked that exactly: it may only have gone forward.
const RUNNING := {"play": "seconds", "score": "clock"}


## A clock that was saved and read back: it carries, and it only moves forward.
func _carried(key: String, was: Variant, now: Variant) -> void:
	check(now != null, "key %s came back at all" % key)
	if now == null:
		return
	var field: String = RUNNING[key]
	var a := SaveCodec.to_num((was as Dictionary).get(field), -1.0)
	var b := SaveCodec.to_num((now as Dictionary).get(field), -1.0)
	check(a >= 0.0 and b >= 0.0, "key %s: %s is a number on both sides" % [key, field])
	# The one thing that can be said about a clock that never stopped: it did not
	# go backwards, and it was not reset. A headless play runs no real seconds, so
	# both are usually 0.0 and the value of this line is the day somebody makes
	# `_load` drop the field -- b would come back below a, or not at all.
	check(b >= a, "key %s: %s came back as %.4f, under the %.4f that was saved" % [key, field, b, a])
	# Everything else under that key is ordinary state and is held exactly.
	for other: Variant in (was as Dictionary):
		if String(other) == field:
			continue
		eq(SaveCodec.canonical((now as Dictionary).get(other)),
			SaveCodec.canonical((was as Dictionary)[other]), "key %s.%s:" % [key, other])


func test_every_registered_key_reads_back_the_same_after_a_played_day() -> void:
	Sx.use_root("round-trip")
	var a := Sx.game(tree, ["--seed=1", "--size=64", "--hour=9", "--give=driftwood:7,stone:4,kit_rig:1,kit_lens:1,oil:2",
		"--held=axe_hand"])
	await _play(a)
	var saver := Sx.system(a, "05_save")
	check(saver != null, "the save system is loaded")
	var keys := SaveGame.keys()
	for k: StringName in [&"world", &"clock", &"player", &"body", &"inventory", &"survival", &"weather", &"play", &"ui"]:
		check(keys.has(k), "key %s registered" % k)
	eq(keys[0], &"world", "core state registers first, so it applies first")
	var why: String = saver.call("save_to", 2)
	eq(why, "", "saved to slot 2")
	var before := SaveGame.collect()
	var live := _live(a)
	Sx.end(a)
	eq(SaveGame.keys().size(), 0, "the registry ends with its game")

	var o := BootOptions.new()
	eq(SaveSlots.options_for(2, o), "", "slot 2 boots")
	eq(o.load_slot, 2)
	eq(o.seed_value, 1)
	eq(o.size, 64)
	var b := Sx.game(tree, [], o)
	# No frame has run: what follows is what the first frame draws.
	var after := SaveGame.collect()
	for k: String in before:
		if RUNNING.has(k):
			_carried(k, before[k], after.get(k))
			continue
		eq(SaveCodec.canonical(after.get(k)), SaveCodec.canonical(before[k]), "key %s:" % k)
	eq(after.keys().size(), before.keys().size(), "no key lost or gained")
	var now := _live(b)
	for k: String in live:
		if live[k] is float:
			# JSON's reader may land a float one representable step away.
			near(float(now[k]), float(live[k]), 1e-9 * maxf(1.0, absf(float(live[k]))), "live %s:" % k)
		else:
			eq(now[k], live[k], "live %s:" % k)
	# Typed back, not left as JSON floats.
	eq(typeof(b.inventory.count(&"timber")), TYPE_INT, "counts are ints again")
	check(b.inventory.held is StringName, "held is a StringName again")
	var fire: WorldProp = SurvivalState.of(b).built[0] if not SurvivalState.of(b).built.is_empty() else null
	check(fire != null and fire.kind == PropKind.FIRE, "the built fire is a fire")
	check(fire != null and b.query.nearest_prop(fire.pos, 0.5, [PropKind.FIRE] as Array[int]) == fire, "and it stands in collision")
	check(Survival.fire_near(b) != null, "the player wakes beside it")
	eq(Weather.forced_kind, &"rain", "the forced sky came back")
	# A frame later the loaded world is drawn: the built fire burns.
	for i in 6:
		await tree.process_frame
	check(fire != null and b.find_child("fire_%d" % fire.id, true, false) != null, "a flame burns on the loaded fire")
	Sx.end(b)
	eq(Weather.forced_kind, &"", "a sky forced by a save is let go with its game")
	Sx.finish()


## Walk, take, build, make, sleep; wear the knife, wet the body, see the land.
func _play(g: Game) -> void:
	var p := g.player
	# Walk: a few steps of the real body on land, the map remembering them.
	var ui := Sx.system(g, "90_ui")
	var from := p.pos
	for step in 12:
		var next := from + Vector2(0.5 * step, 0.25 * step)
		if g.query.standable(floori(next.x), floori(next.y)):
			_teleport(g, next)
			(ui.get("explored") as UiExplored).visit(next)
	Survival.face(g, 0.3)
	# Take: a pine felled and mussels picked, both put down in play (runtime props).
	var pine := Survival.add_prop(g, PropKind.PINE, p.pos + Vector2.from_angle(p.facing) * 1.1)
	check(Survival.use(g), "felling")
	Survival.finish_work(g)
	check(g.world.depleted.has(pine.id), "the pine is down")
	var rock := Survival.add_prop(g, PropKind.MUSSEL_ROCK, p.pos + Vector2.from_angle(p.facing + PI * 0.5) * 1.0)
	Survival.face(g, (rock.pos - p.pos).angle())
	check(Survival.use(g), "at the mussels")
	Survival.finish_work(g)
	check(g.inventory.count(&"mussels") > 0, "mussels taken")
	# A generated prop taken for good, somewhere else on the map.
	for q in g.world.props:
		if q.id < SaveCore.props_base(g) and Takes.workable(q.kind) and not g.world.depleted.has(q.id):
			g.world.depleted[q.id] = INF
			break
	# Build a fire, and make a haft by hand.
	var fire: WorldProp = null
	for turn in 8:
		Survival.face(g, turn * TAU / 8.0)
		fire = Survival.build_fire(g)
		if fire != null:
			break
	check(fire != null, "a fire is built at %s (busy %s)" % [p.pos, Survival.busy(g)])
	check(Crafting.make_in(g, Crafting.recipe(&"haft")), "a haft is whittled")
	check(g.inventory.has(&"haft"), "the haft is carried")
	# The rest of a day: a worn edge, a wound, wet clothes, kit on, the lamp lit, a sky.
	g.inventory.wear(&"axe_hand", 40)
	g.inventory.wear_kit(&"kit_lens")
	g.body.health = 7
	g.body.arrests = 1
	g.body.resist[&"cold"] = 0.25
	g.body.lamp_lit = true
	SurvivalState.of(g).wet_until = g.clock.minutes + 90.0
	Weather.force(&"rain", 0.6)
	# Sleep by the fire at night.
	var day := floorf(g.clock.minutes / 1440.0)
	g.clock.minutes = day * 1440.0 + 22.5 * 60.0
	SurvivalState.of(g).woke_at = g.clock.minutes - 16.0 * 60.0
	check(Survival.sleep(g), "slept by the fire: %s" % Survival.sleep_refusal(g))
	Survival.update_body(g)
	await tree.process_frame


func _teleport(g: Game, at: Vector2) -> void:
	g.player.pos = at
	if g.player.hero != null:
		g.player.hero.pos = at
	g.player.drive(Vector2.ZERO, false, 0.0)


## What the running game holds, in plain values, beyond what the keys say.
func _live(g: Game) -> Dictionary:
	var e := SaveCore.explored_of(g)
	var built: Array = []
	for q: WorldProp in SurvivalState.of(g).built:
		built.append([q.id, q.kind, q.pos])
	var depleted := {}
	for id: int in g.world.depleted:
		depleted[id] = [g.world.depleted[id], g.world.props[id].kind]
	return {
		"props": g.world.props.size(),
		"depleted": depleted,
		"built": built,
		"minutes": g.clock.minutes,
		"pos": g.player.pos,
		"hero": g.player.hero.pos if g.player.hero != null else Vector2.INF,
		"facing": g.player.facing,
		"items": g.inventory.items.duplicate(),
		"edges": g.inventory.edges.duplicate(),
		"held": g.inventory.held,
		"worn": g.inventory.worn,
		"health": g.body.health,
		"lamp": g.body.lamp_lit,
		"fed": g.body.fed_until,
		"lamp_oil": SurvivalState.of(g).lamp_oil,
		"spent": SurvivalState.of(g).spent.duplicate(),
		"seen": e.fraction() if e != null else -1.0,
		"trail": e.trail.size() if e != null else -1,
	}


func test_world_edits_follow_their_props_and_stay_off_other_worlds() -> void:
	var Fx := preload("res://tests/survival/fixture.gd")
	var g: Game = Fx.flat()
	SaveCore.mark_base(g)
	var fire := Survival.add_prop(g, PropKind.FIRE, g.player.pos + Vector2(2, 0))
	SurvivalState.of(g).built.append(fire)
	g.world.depleted[fire.id] = 500.0
	SurvivalState.of(g).spent[SurvivalState.key(fire.id, 0)] = INF
	SurvivalState.of(g).taken[SurvivalState.key(fire.id, 0)] = 2
	var saved: Variant = JSON.parse_string(JSON.stringify(SaveCore.save_world(g), "", false, true))
	Fx.done(g)

	# A newer build lays one more prop at setup: the saved fire lands one id on.
	var h: Game = Fx.flat()
	Survival.add_prop(h, PropKind.BOULDER, h.player.pos + Vector2(-3, 0))
	SaveCore.mark_base(h)
	SaveCore.load_world(h, saved)
	eq(h.world.props.size(), SaveCore.props_base(h) + 1, "the fire is put back")
	var moved := h.world.props[SaveCore.props_base(h)]
	eq(moved.kind, PropKind.FIRE)
	eq(moved.pos, fire.pos, "where it stood")
	near(float(h.world.depleted.get(moved.id, -1.0)), 500.0, 1e-6, "its depletion follows it")
	check(is_inf(float(SurvivalState.of(h).spent.get(SurvivalState.key(moved.id, 0), 0.0))), "so does its spent option")
	eq(SurvivalState.of(h).taken.get(SurvivalState.key(moved.id, 0)), 2, "and its takes")
	check(SurvivalState.of(h).built.size() == 1 and SurvivalState.of(h).built[0] == moved, "it is still the one built")
	Fx.done(h)

	# A save of another world changes nothing here.
	var other: Game = Fx.flat()
	# Another GAME, which is what "another world" means now that a game holds
	# several: each realm's world is grown from the game's seed with the realm's
	# own salt, so a save's edits are keyed on the GAME's seed (SaveCore).
	other.options.seed_value = 99
	other.world.seed_value = 99
	SaveCore.mark_base(other)
	var count := other.world.props.size()
	SaveCore.load_world(other, saved)
	eq(other.world.props.size(), count, "no props from another world")
	check(other.world.depleted.is_empty(), "no edits from another world")
	Fx.done(other)
