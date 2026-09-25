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
## catch a reset today is a number a slower machine breaches tomorrow.
##
## AND SO WOULD "IT ONLY EVER MOVES FORWARD", which is what stood here first and
## was wrong for a reason worth keeping written down. It compared the reloaded
## clock against `SaveGame.collect()` taken AFTER `save_to` — the live game a
## moment past the instant the file was written — so the reloaded value is
## correctly OLDER than it, and on a busy machine, where a headless play burns
## real seconds, that shows up as a clock that "came back as 0.0242, under the
## 0.0242 that was saved". Both halves of that sentence were false: it had not
## gone backwards, and the thing it was held against was not what was saved.
##
## THE FIX IS NOT TO RELAX THE COMPARISON BUT TO COMPARE THE RIGHT TWO THINGS.
## The round trip is about the FILE, so a running clock is held to the file's own
## bytes — where neither side is still ticking and equality can be exact. That is
## stronger than what it replaces, not weaker: it fails on a `_load` that drops
## the field, on one that resets it, and now also on one that rounds it.
const RUNNING := {"play": "seconds", "score": "clock"}


## A clock that was saved and read back, held to what the file actually holds.
func _carried(key: String, wrote: Variant, now: Variant) -> void:
	check(now != null, "key %s came back at all" % key)
	if now == null:
		return
	check(wrote != null, "key %s reached the file" % key)
	if wrote == null:
		return
	var field: String = RUNNING[key]
	var a := SaveCodec.to_num((wrote as Dictionary).get(field), -1.0)
	var b := SaveCodec.to_num((now as Dictionary).get(field), -1.0)
	check(a >= 0.0 and b >= 0.0, "key %s: %s is a number on both sides" % [key, field])
	eq(b, a, "key %s: %s came back as %.6f, and the file holds %.6f" % [key, field, b, a])
	# Everything else under that key is ordinary state and is held exactly.
	for other: Variant in (wrote as Dictionary):
		if String(other) == field:
			continue
		eq(SaveCodec.canonical((now as Dictionary).get(other)),
			SaveCodec.canonical((wrote as Dictionary)[other]), "key %s.%s:" % [key, other])


## Wind both running clocks on to a value nothing could arrive at by accident.
## Written through the systems that own them, so if either stops keeping its clock
## where this reaches, the test says so instead of quietly going vacuous again.
const PLAYED := 1837.406219482
const SCORED := 942.718360901

func _wind_clocks(g: Game, saver: Object) -> void:
	saver.set("play_seconds", PLAYED)
	eq(float(saver.get("play_seconds")), PLAYED, "05_save still keeps play_seconds")
	var music := Sx.system(g, "75_music")
	check(music != null, "the score system is loaded")
	if music == null:
		return
	var conductor: Variant = music.get("conductor")
	check(conductor != null, "the conductor is where the score's clock lives")
	if conductor == null:
		return
	conductor.set("time", SCORED)


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
	# PUT A NUMBER IN BOTH CLOCKS BEFORE SAVING, or neither of them proves anything
	# on a quiet machine. A headless play burns almost no real seconds, so both sit
	# at 0.0, and 0.0 survives being dropped, reset, rounded or truncated — every
	# way this could break comes back 0.0 and passes. The values are deliberately
	# awkward: enough decimals that a snap or a float32 would show, and different
	# from each other so one cannot stand in for the other.
	_wind_clocks(a, saver)
	var why: String = saver.call("save_to", 2)
	eq(why, "", "saved to slot 2")
	var before := SaveGame.collect()
	# What actually went to disk, which for a clock that never stopped is NOT the
	# same as what the game holds a moment after writing it. Read here, while the
	# slot is known, and used only for the keys that are still ticking.
	var wrote: Dictionary = SaveFile.read(SaveSlots.path(2)).get("data", {})
	check(not wrote.is_empty(), "the file that was just written reads back")
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
			_carried(k, wrote.get(k), after.get(k))
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


## The prop `_take_from` last put down, so a caller's check can name it.
static var _planted := -1


## Plant `kind` on a bearing with nothing of the world's own nearer, face it, and
## work it. Tries eight bearings before giving up, and says which prop the key
## took instead if it still lost the race -- a silent "it did not happen" is the
## thing that made this hard to read.
func _take_from(g: Game, kind: int, said: String, done: Callable) -> void:
	var p := g.player
	for i in 8:
		var ang := 0.3 + TAU * float(i) / 8.0
		var at: Vector2 = p.pos + Vector2.from_angle(ang) * 1.1
		if not g.query.standable(floori(at.x), floori(at.y)):
			continue
		# No "is this spot clear" precheck: in a real world something is almost
		# always within a tile or two, and the question is not whether the spot is
		# empty -- it is whether the KEY would choose what was planted. So plant
		# and ask `use_target`, which is the same question the key asks.
		var prop := Survival.add_prop(g, kind, at)
		_planted = prop.id
		Survival.face(g, (prop.pos - p.pos).angle())
		var target := Survival.use_target(g)
		if target == null or target.id != prop.id:
			continue
		check(Survival.use(g), "the key works %s" % PropKind.NAMES[kind])
		Survival.finish_work(g)
		check(done.call(), said)
		return
	fail("nowhere clear to stand a %s: every bearing had something of the world's own nearer"
		% PropKind.NAMES[kind])


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
	# Take: a pine felled and mussels picked, both put down in play (runtime props).
	#
	# **PLANTED WHERE NOTHING ELSE IS NEARER.** These were dropped 1.1 tiles ahead
	# on a fixed bearing, and `use` answers whatever is NEAREST and in front -- so
	# in a REAL world, which has props everywhere, the key would sometimes take a
	# generated prop standing closer and the planted pine was never touched. The
	# failure then read "the pine is down" going unmet, which sounds like felling
	# is broken; measured in a clean fixture, felling a pine with a hand axe works
	# exactly as it should. The test was staging its subject on top of the world.
	_take_from(g, PropKind.PINE, "the pine is down", func() -> bool:
		return g.world.depleted.has(_planted))
	_take_from(g, PropKind.MUSSEL_ROCK, "mussels taken", func() -> bool:
		return g.inventory.count(&"mussels") > 0)
	# A generated prop taken for good, somewhere else on the map.
	for q in g.world.props:
		if q.id < SaveCore.props_base(g) and Takes.workable(q.kind) and not g.world.depleted.has(q.id):
			g.world.depleted[q.id] = INF
			break
	# Build a fire, and make a haft by hand. STOOD WHERE ONE FITS, found rather
	# than assumed: a fire wants level, clear ground in front of the body, and the
	# walk above ends wherever the land it crossed happens to put it -- on a
	# coast that climbs in terraces, that can be a step's edge (GEN 28).
	_to_where_it_fits(g, PropKind.FIRE)
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


## Stand on the nearest tile, outward from here, where a `kind` can be built in
## front of the body at some facing.
func _to_where_it_fits(g: Game, kind: int) -> void:
	var from := g.player.pos
	for r in range(0, 16):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var at := Vector2(floori(from.x) + dx + 0.5, floori(from.y) + dy + 0.5)
				if not g.query.standable(floori(at.x), floori(at.y)):
					continue
				_teleport(g, at)
				for turn in 8:
					Survival.face(g, turn * TAU / 8.0)
					if Survival._build_spot(g, kind).x > -1e8:
						return
	_teleport(g, from)


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
