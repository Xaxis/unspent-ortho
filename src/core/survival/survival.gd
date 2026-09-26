class_name Survival
## Taking from the world, eating, sleeping, building, and the body's condition,
## for one running Game. The rules are in Takes, Condition, Crafting and Items;
## this file applies them to the game's world, clock, body and inventory and
## tells everyone else through Events.
##
## Public helpers (the UI, fight, bots and tests call these; all take the Game):
##   station_near(game) -> StringName        nearest station in reach: &"fire" &"bench" &"kiln"
##                                           &"wheel" &"loom", or &"" (hand recipes work anywhere)
##   stations_near(game) -> Array[StringName] every station in reach, nearest first, always ends with &"hand"
##   use_target(game) -> WorldProp           the prop `use` would work: nearest workable, not
##                                           taken, within reach in front of the player; or null
##   describe_target(game) -> String         what `use` would do now: "pine - fell",
##                                           "iron ore - too hard", "fire - sleep", "mussels - eat",
##                                           "campfire - build?" (a press asks), "campfire - build"
##                                           (a press builds), or ""
##   use(game) -> bool                       the `use` action: work the target; else eat (if hungry),
##                                           sleep, or build a fire, whichever fits first. A fire
##                                           takes two presses: the first asks (a ring is drawn
##                                           where it would go), a second within BUILD_ASK_SECONDS
##                                           on the same spot builds, so a walker tapping `use`
##                                           never burns their makings by accident
##   build_asked(game) -> Vector2            where an asked-for fire would go, or Vector2.INF
##   work(game, prop) -> bool                start working a prop (refusals go to Events.message)
##   can_work(game, prop) -> bool            work would start, with the held or a carried tool
##   finish_work(game) -> bool               complete the work in hand now (the system does this
##                                           when its real time is up; bots call it directly)
##   interrupt(game) -> bool                 drop the work in hand: nothing taken, no time charged
##                                           (the system calls it when a blow lands on the player)
##   eat(game, id) -> bool                   eat one food item from the creel
##   best_food(game) -> StringName           what eat would pick, or &""
##   sleep(game) -> bool / sleep_refusal(game) -> String ("" = can sleep)
##   build_fire(game) -> WorldProp           a campfire in front of the player from what is carried
##   build(game, station, free) -> WorldProp any station (fire bench kiln) per its recipe
##   hold(game, id) -> bool                  put a carried item in hand (&"" = bare hands)
##   hone(game) -> bool / reedge(game) -> bool   mend the held tool (see Crafting recipes sharpen/reedge)
##   lamp_oil(game) -> float                 world minutes of light left in the lamp and carried flasks
##   tick(game, delta)                       per frame: finish work, body condition, regrowth, lamp oil,
##                                           collect what a station finished, hunger's warnings
##   threat_near(game) -> bool               a hostile body close enough that nothing long may be
##                                           started (making, a long take, eating, sleeping, building)
##   drop(game, id, n) -> int                put down n of a carried thing (what the slate's drop
##                                           verb calls) on a heap in front of the player, which `use`
##                                           takes back; returns how many went (0 with a hostile close,
##                                           or nowhere to put it). Never drops the lamp lit.
##   leave_bag(game, at) -> WorldProp        a bad end (carried off): everything carried but what is
##                                           on the body -- the tool in the hand, the kit worn, the
##                                           gear fitted -- on a heap where they were taken, marked
##                                           (SurvivalState.bags); null when there was nothing to leave
##   take_back(game, heap) -> int            pick up everything on a heap the player left; how many
##   heap_near(game) -> WorldProp            the player's own heap in reach, or null
##   last_weapon(game, id) -> bool           id is the only carried thing that fights better than fists
##   set_going(game, recipe) -> WorldProp    a long station recipe put on the station to cook in
##                                           world time (Crafting.make_in calls it); the station prop
##   cooking(game) -> Array[Dictionary]      what stations are working on: {station, recipe, makes,
##                                           done (world minute), pos, prop}, soonest first
##   collect(game) -> int                    take what finished at stations in reach (tick does it)
##   at_rest(game) -> bool                   by a fire or in a village: where `use` on nothing eats or sleeps
##   in_the_dark(game) -> bool               night, no lamp lit, no fire or village light: reach shrinks
##
## Events emitted: took(item, n), made(item, n), time_skipped(minutes, reason:
## work eat sleep make build collapse), message(line), sfx(name, at) with names
## work_<verb> took refuse eat sleep ask_fire build_<station> make hone collapse
## regrow work_broken lamp_out.

## Real seconds a take plays for (the clock is charged its minutes after).
const WORK_SECONDS := 1.2
const EAT_SECONDS := 0.8
## A prop is in reach when its edge is this close and it is in front. (tiles)
const REACH := 1.3
## Stations work within this many tiles of their edge.
const STATION_REACH := 1.6
## Cosine of the half-angle of the facing cone.
const CONE := 0.42
## A sleeping place: a fire this close, or a village this close to its centre.
const FIRE_WARMTH := 3.0
## A village reaches as far as its own buildings do (`WorldData.village_reach`),
## which a settlement records when it is laid. This is the floor under that, for a
## village that never placed a building.
const VILLAGE_RADIUS := WorldData.VILLAGE_LEAST_REACH
const BUILD_DISTANCE := 1.25
## Real seconds a first press on open ground waits for the second that builds.
const BUILD_ASK_SECONDS := 2.0
## No instant jump of the clock from taking or making is longer than this: the
## day is lived in the world, not on a page. Longer station work is set going.
const MAX_JUMP_MINUTES := 30.0
## Setting a long recipe going at a station costs this much of the clock.
const SET_GOING_MINUTES := 5.0
## A take this long or longer is refused with a hostile close.
const LONG_TAKE_MINUTES := 10.0
## A hostile this close (Chebyshev tiles) stops anything long being started.
const THREAT_RADIUS := 8.0
const THREAT_LINE := "Not with that so close."
## In the dark without a light a prop must be this close (edge, tiles) to be found.
const DARK_REACH := 0.6
## Nightfall past which the dark hides what is not in reach of a hand.
const DARK_NIGHTFALL := 0.6
## A fire lights the ground this far round it.
const FIRE_LIGHT := 5.0
## **NO KEY IN A CORE LINE.** These two spelled "(f)" and "(i)". Core may not
## read a key -- `guide.gd` says so where it hands its lines over as templates --
## so a letter typed here is right only until somebody rebinds, and the settings
## page invites exactly that. The guide's `lamp` and `carry` lessons name both
## keys in the player's own keys, and both are offered at these same moments.
const DARK_LINE := "Too dark to find anything. Light the lamp."
## Real seconds between two of the same nudge on an empty press.
const NUDGE_SECONDS := 12.0
## Lamp oil, lamp and carried flasks, at or under which the player is told once.
const LAMP_LOW_MINUTES := 60.0
const LAMP_LOW_LINE := "The lamp is low on oil."
## Starving on your feet: this long after the warning, a body sits down.
const STARVING_GRACE_MINUTES := 60.0
const HUNGRY_LINE := "You are hungry. Eat something from what you carry."
const STARVING_LINE := "You are weak with hunger. Eat, or you will fall."

const STATION_KINDS := {PropKind.FIRE: [&"fire"], PropKind.BENCH: [&"bench"], PropKind.KILN: [&"kiln"],
	PropKind.HOUSE: [&"bench", &"wheel", &"loom"]}
const BUILD_KINDS := {&"fire": PropKind.FIRE, &"bench": PropKind.BENCH, &"kiln": PropKind.KILN}


## Real seconds, unless a shot runs survival on fixed frames (BootOptions --hold):
## then the system advances `fixed_now` by `fixed_step` each frame and stops.
static var fixed_now := -1.0
static var fixed_step := 0.0


static func now_real() -> float:
	return fixed_now if fixed_now >= 0.0 else Time.get_ticks_msec() / 1000.0


# --- Stations -------------------------------------------------------------

static func stations_near(game: Game) -> Array[StringName]:
	var p := game.player.pos
	var found: Array = [] # [distance, StringName]
	for q in game.query.props_near(p, STATION_REACH + 2.0):
		if not STATION_KINDS.has(q.kind) or game.world.depleted.has(q.id):
			continue
		var d := q.pos.distance_to(p) - q.solid
		if d > STATION_REACH:
			continue
		for s: StringName in STATION_KINDS[q.kind]:
			found.append([d, s])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array[StringName] = []
	for f: Array in found:
		if not out.has(f[1]):
			out.append(f[1])
	out.append(&"hand")
	return out


static func station_near(game: Game) -> StringName:
	var s := stations_near(game)
	return s[0] if s[0] != &"hand" else &""


static func fire_near(game: Game, r: float = FIRE_WARMTH) -> WorldProp:
	var kinds: Array[int] = [PropKind.FIRE]
	return game.query.nearest_prop(game.player.pos, r + 1.0, kinds)


static func in_village(game: Game) -> bool:
	for v in game.world.villages:
		if (v.pos as Vector2).distance_to(game.player.pos) <= game.world.village_reach(v):
			return true
	return false


## Where a press of `use` on nothing may eat or sleep: by a fire or in a village.
## Anywhere else the body eats only when the player chooses it (the carrying page).
static func at_rest(game: Game) -> bool:
	return fire_near(game) != null or in_village(game)


## Night, no lamp lit, and no fire or village light about: a hand finds only
## what it touches (DARK_REACH).
static func in_the_dark(game: Game) -> bool:
	if game.body.lamp_lit or FightRules.nightfall(game.clock.hour()) < DARK_NIGHTFALL:
		return false
	return fire_near(game, FIRE_LIGHT) == null and not in_village(game)


## A hostile body close enough that nothing long may be started: a fight on, or
## anything roused, or any hunter, within THREAT_RADIUS. A worker going about its
## round is not a threat until it is disturbed.
static func threat_near(game: Game) -> bool:
	var sim := game.player.sim if game.player != null else null
	if sim == null:
		return false
	if sim.fight_on:
		return true
	for m in sim.mobs:
		if not m.alive or m.removed or not bool(m.row.get("hostile", true)):
			continue
		if m.indifferent() and not m.roused():
			continue
		if m.approach == &"dart" and not m.roused():
			continue
		if Senses.chebyshev(m.pos, sim.hero.pos) <= THREAT_RADIUS:
			return true
	return false


# --- Targets --------------------------------------------------------------

static func use_target(game: Game) -> WorldProp:
	var p := game.player.pos
	var ahead := Vector2.from_angle(game.player.facing)
	var best: WorldProp = null
	var best_score := INF
	var state := SurvivalState.of(game)
	var reach := DARK_REACH if in_the_dark(game) else REACH
	for q in game.query.props_near(p, REACH + 2.0):
		if not (Takes.workable(q.kind) or state.left.has(q.id)) or game.world.depleted.has(q.id):
			continue
		var to := q.pos - p
		var edge := to.length() - q.solid
		if edge > reach:
			continue
		var dot := ahead.dot(to.normalized()) if to.length() > 0.01 else 1.0
		# Something you are pressed against counts even a little to the side; your
		# own heap at your feet counts whichever way you face.
		var mine := state.left.has(q.id) and edge < HEAP_REACH
		if dot < CONE and not (edge < 0.35 and dot > -0.2) and not mine:
			continue
		var score := edge + (1.0 - dot) * 0.6
		if mine:
			# What the player left at their feet comes first: it is what they turned back for.
			score = edge - 1.0
		elif state.left.has(q.id):
			score -= 0.5
		elif not _choose(game, state, q).ok:
			score += 0.8
		if score < best_score:
			best_score = score
			best = q
	return best


static func _choose(game: Game, state: SurvivalState, prop: WorldProp, held: StringName = &"~") -> Dictionary:
	var h := game.inventory.held if held == &"~" else held
	var g := game.world.ground_at(floori(prop.pos.x), floori(prop.pos.y))
	var exhausted := func(i: int) -> bool: return state.spent.has(SurvivalState.key(prop.id, i))
	return Takes.choose(prop.kind, g, h, exhausted, game.clock.minutes)


## The choice the use key would make on `prop` with what is in hand (Takes.choose's
## shape): the one answer the key, the line under it and the highlight all read.
static func choice_for(game: Game, prop: WorldProp) -> Dictionary:
	return _choose(game, SurvivalState.of(game), prop)


## The best carried tool that could work `prop` now, or &"".
static func tool_for(game: Game, prop: WorldProp) -> StringName:
	return _tool_for(game, SurvivalState.of(game), prop)


## Has this prop any work left in it for the player as they stand (tools and all)?
## Tours and tools use it to find something that is not already picked over.
## `in_hand` true asks only what the player could do with what they hold now.
static func work_left(game: Game, prop: WorldProp, in_hand: bool = true) -> bool:
	if game.world.depleted.has(prop.id):
		return false
	var state := SurvivalState.of(game)
	if not _choose(game, state, prop).is_empty():
		return true
	if in_hand:
		return false
	var tool := _tool_for(game, state, prop)
	return tool != &"" and not _choose(game, state, prop, tool).is_empty()


## The best carried tool that could work `prop` now, or &"".
static func _tool_for(game: Game, state: SurvivalState, prop: WorldProp) -> StringName:
	var best := &""
	var best_rank := -1.0
	for id: StringName in game.inventory.items:
		if Items.verb(id) == &"":
			continue
		var c := _choose(game, state, prop, id)
		if not c.ok or not Takes.TOOL_VERBS.has(c.option.verb):
			continue
		var rank: float = Items.STUFF_RANK.get(Items.stuff(id), 0) * 100000.0 - Items.work_minutes(100.0, id, game.inventory.edge(id))
		if rank > best_rank:
			best_rank = rank
			best = id
	return best


static func describe_target(game: Game) -> String:
	var t := use_target(game)
	if t != null and SurvivalState.of(game).left.has(t.id):
		return "your things - take back"
	if t != null:
		var c := _choose(game, SurvivalState.of(game), t)
		var name := PropKind.NAMES[t.kind]
		if c.ok:
			return "%s - %s" % [name, c.option.verb]
		var alt := _tool_for(game, SurvivalState.of(game), t)
		if alt != &"":
			return "%s - %s" % [name, Items.verb(alt)]
		match c.why:
			&"hard":
				return "%s - too hard" % name
			&"spent":
				return "%s - picked over" % name
			&"tide":
				return "%s - under water" % name
		return "%s - no tool" % name
	match _fallback(game):
		&"eat":
			return "%s - eat" % Items.display_name(best_food(game))
		&"sleep":
			return "%s - sleep" % ("fire" if fire_near(game) != null else "village")
		&"build":
			return "campfire - build" if build_asked(game).is_finite() else "campfire - build?"
	return ""


# --- The use action -------------------------------------------------------

static func use(game: Game) -> bool:
	# Something has hold of you: every hand is for pulling free.
	if busy(game) or game.body.grip > 0:
		return false
	var t := use_target(game)
	if t != null and SurvivalState.of(game).left.has(t.id):
		return take_back(game, t) > 0
	if t != null:
		return work(game, t)
	match _fallback(game):
		&"eat":
			return eat(game, best_food(game))
		&"sleep":
			return sleep(game)
		&"build":
			return _ask_or_build(game)
	# Nothing to do here: say so, so a press is never swallowed without a word.
	Events.sfx.emit(&"refuse", game.player.position)
	if in_the_dark(game):
		_nudge(game, DARK_LINE)
	return false


## A line said on an empty press, at most once in NUDGE_SECONDS.
static func _nudge(game: Game, line: String) -> void:
	var state := SurvivalState.of(game)
	var last: float = state.nudged.get(line, -INF)
	if now_real() - last < NUDGE_SECONDS:
		return
	state.nudged[line] = now_real()
	Events.message.emit(line)


## The first press asks and marks the spot; a second press in time on the same spot builds.
static func _ask_or_build(game: Game) -> bool:
	var state := SurvivalState.of(game)
	var spot := _build_spot(game, PropKind.FIRE)
	var asked := build_asked(game)
	if asked.is_finite() and asked.distance_to(spot) < 0.6:
		state.build_ask = {}
		return build_fire(game) != null
	state.build_ask = {"at": spot, "until": now_real() + BUILD_ASK_SECONDS}
	Events.message.emit("Again, and a fire is laid here.")
	Events.sfx.emit(&"ask_fire", game.world.to_3d(spot))
	return true


static func build_asked(game: Game) -> Vector2:
	var ask := SurvivalState.of(game).build_ask
	if ask.is_empty() or now_real() >= float(ask.until):
		return Vector2.INF
	return ask.at


## Eating comes before sleep: a body that lies down hungry wakes starving. Both
## only by a fire or in a village (at_rest): out on the land a press of `use`
## beside nothing never eats the food or loses the night by accident.
static func _fallback(game: Game) -> StringName:
	var resting := at_rest(game)
	if resting and game.body.hunger_level(game.clock.minutes) >= 1 and best_food(game) != &"":
		return &"eat"
	if resting and sleep_refusal(game) == "":
		return &"sleep"
	if fire_near(game, 5.0) == null and _makeable_build(game, &"fire").size() > 0 and _build_spot(game, PropKind.FIRE).x > -1e8:
		return &"build"
	return &""


static func busy(game: Game) -> bool:
	return not SurvivalState.of(game).job.is_empty() or now_real() < game.body.busy_until


static func can_work(game: Game, prop: WorldProp) -> bool:
	if prop == null or game.world.depleted.has(prop.id):
		return false
	var state := SurvivalState.of(game)
	return _choose(game, state, prop).ok or _tool_for(game, state, prop) != &""


static func work(game: Game, prop: WorldProp) -> bool:
	var state := SurvivalState.of(game)
	if not state.job.is_empty() or prop == null or game.world.depleted.has(prop.id):
		return false
	var c := _choose(game, state, prop)
	if not c.ok and c.why != &"spent" and c.why != &"tide":
		var alt := _tool_for(game, state, prop)
		if alt != &"":
			hold(game, alt)
			c = _choose(game, state, prop)
	var at := game.world.to_3d(prop.pos)
	if not c.ok:
		Events.message.emit(Takes.refusal(c.why, game.inventory.held))
		Events.sfx.emit(&"refuse", at)
		return false
	var o: Dictionary = c.option
	var tool := &""
	var minutes: float = o.min
	if Takes.TOOL_VERBS.has(o.verb):
		tool = game.inventory.held
		minutes = Items.work_minutes(o.min, tool, game.inventory.edge(tool))
	minutes = minf(minutes, MAX_JUMP_MINUTES)
	if minutes >= LONG_TAKE_MINUTES and threat_near(game):
		# A long take is hours of the clock with your back turned: refused, not just remarked on.
		Events.message.emit(THREAT_LINE)
		Events.sfx.emit(&"refuse", at)
		return false
	state.job = {"prop": prop, "index": c.index, "option": o, "tool": tool, "minutes": minutes,
		"done_at": now_real() + WORK_SECONDS}
	game.body.busy_until = now_real() + WORK_SECONDS
	var to := prop.pos - game.player.pos
	if to.length() > 0.01:
		face(game, to.angle())
	_act(game, &"work", WORK_SECONDS)
	Events.sfx.emit(StringName("work_%s" % o.verb), at)
	return true


static func finish_work(game: Game) -> bool:
	var state := SurvivalState.of(game)
	if state.job.is_empty():
		return false
	var job := state.job
	state.job = {}
	game.body.busy_until = 0.0
	var prop: WorldProp = job.prop
	if game.world.depleted.has(prop.id):
		return false
	var o: Dictionary = job.option
	var minutes: float = job.minutes
	_skip(game, minutes, &"work")
	var inv := game.inventory
	var k := SurvivalState.key(prop.id, job.index)
	var takes: int = state.taken.get(k, 0)
	inv.add(o.item, o.n)
	Events.took.emit(o.item, o.n)
	var bonus: Array = o.bonus
	if not bonus.is_empty() and Rng.hash01(game.world.seed_value, prop.id, takes, floori(game.clock.minutes / 60.0), 0xB0) < float(bonus[1]):
		inv.add(bonus[0], 1)
		Events.took.emit(bonus[0], 1)
	var tool: StringName = job.tool
	if tool != &"" and inv.wear(tool, 1):
		Events.message.emit(Inventory.DULL_LINE)
	takes += 1
	state.taken[k] = takes
	var now := game.clock.minutes
	if takes >= int(o.uses):
		var back := INF if float(o.regrow) < 0.0 else now + float(o.regrow) * 60.0
		if o.keep:
			state.spent[k] = back
		else:
			game.world.depleted[prop.id] = back
			if game.view != null:
				game.view.refresh_props(prop)
	elif not o.keep and Harvest.apply_shown(game, prop) and game.view != null:
		# Taken from but not taken away: it stands with that much of it off it.
		game.view.refresh_props(prop)
	Events.sfx.emit(&"took", game.world.to_3d(prop.pos))
	return true


## A blow knocks the work out of your hands: nothing comes away, no time is
## charged, the tool keeps its edge, and you can move at once.
static func interrupt(game: Game) -> bool:
	var state := SurvivalState.of(game)
	if state.job.is_empty():
		return false
	var prop: WorldProp = state.job.prop
	state.job = {}
	game.body.busy_until = 0.0
	Events.sfx.emit(&"work_broken", game.world.to_3d(prop.pos))
	return true


# --- Eating and sleeping ---------------------------------------------------

static func best_food(game: Game) -> StringName:
	var need := Condition.hours_to_full(game.body.fed_until, game.clock.minutes)
	return Condition.best_food(game.inventory.ids_in(&"food"), need)


static func eat(game: Game, id: StringName) -> bool:
	if id == &"" or Items.feeds(id) <= 0.0 or not game.inventory.has(id) or busy(game):
		if id != &"" and not game.inventory.has(id):
			Events.message.emit("There is nothing like that to eat.")
		return false
	if threat_near(game):
		Events.message.emit(THREAT_LINE)
		return false
	game.inventory.remove(id, 1)
	var now := game.clock.minutes
	game.body.fed_until = Condition.fed_after_eating(game.body.fed_until, now, Items.feeds(id))
	game.body.busy_until = now_real() + EAT_SECONDS
	_act(game, &"eat", EAT_SECONDS)
	_skip(game, Condition.EAT_MINUTES, &"eat")
	Events.sfx.emit(&"eat", game.player.position)
	return true


static func sleep_refusal(game: Game) -> String:
	if threat_near(game):
		return THREAT_LINE
	var sheltered := fire_near(game) != null or in_village(game)
	return Condition.sleep_line(Condition.sleep_refusal(game.clock.minutes, SurvivalState.of(game).woke_at, sheltered))


static func sleep(game: Game) -> bool:
	var why := sleep_refusal(game)
	if why != "":
		Events.message.emit(why)
		return false
	var state := SurvivalState.of(game)
	var roof := in_village(game)
	var now := game.clock.minutes
	var wake := Condition.wake_minute(now, roof)
	# Nobody sleeps with the lamp burning: it is put out, and the oil kept.
	burn_lamp(game)
	game.body.lamp_lit = false
	_skip(game, wake - now, &"sleep")
	state.lamp_at = game.clock.minutes
	state.woke_at = wake
	game.body.tired = 0.0
	if not roof and not game.inventory.has(&"oilcloth") and _weather_wets(game, wake):
		state.wet_until = wake + Condition.WET_MINUTES
	else:
		state.wet_until = -INF
	Events.sfx.emit(&"sleep", game.player.position)
	return true


# --- Building --------------------------------------------------------------

static func build_fire(game: Game) -> WorldProp:
	return build(game, &"fire")


## Put a station in front of the player. It costs the first recipe that builds
## it and can be made from what is carried; `free` skips the cost (shots, tests);
## `charge` false leaves the minutes to the caller (Crafting.make's contract).
static func build(game: Game, station: StringName, free: bool = false, charge: bool = true) -> WorldProp:
	if not BUILD_KINDS.has(station) or busy(game):
		return null
	if not free and threat_near(game):
		Events.message.emit(THREAT_LINE)
		return null
	var kind: int = BUILD_KINDS[station]
	var recipes := _makeable_build(game, station)
	if recipes.is_empty() and not free:
		Events.message.emit("Not without what it needs.")
		return null
	var spot := _build_spot(game, kind)
	if spot.x < -1e8:
		Events.message.emit("Not here.")
		return null
	var minutes := 0.0
	if not free:
		var r: Dictionary = recipes[0]
		for id: StringName in r.needs:
			game.inventory.remove(id, r.needs[id])
		minutes = r.minutes
	var prop := add_prop(game, kind, spot)
	SurvivalState.of(game).built.append(prop)
	if not free:
		_act(game, &"work", WORK_SECONDS)
		if charge:
			_skip(game, minutes, &"build")
	Events.sfx.emit(StringName("build_%s" % station), game.world.to_3d(spot))
	# A station built is a thing made: the notebook and the tours hear of it.
	Events.made.emit(station, 1)
	return prop


## A new prop in the world: data, collision and view. `rot` NAN = turned by its id.
## `variant` is given here, not set after: the world keeps a prop as its row, and
## a field changed on the returned object afterwards is not on the row.
static func add_prop(game: Game, kind: int, pos: Vector2, rot: float = NAN, scale: float = 1.0, variant: int = -1) -> WorldProp:
	var w := game.world
	var id := w.next_id()
	var prop := WorldProp.new(id, kind, pos, Rng.hash01(w.seed_value, id, 77) * TAU if is_nan(rot) else rot, scale)
	prop.variant = variant
	w.add_prop(prop)
	game.query.add_prop(prop)
	if game.view != null:
		game.view.refresh_props(prop)
	return prop


static func _makeable_build(game: Game, station: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in Crafting.recipes_at(&"hand"):
		if r.get("builds", &"") == station and Crafting.can_make(game.inventory, r):
			out.append(r)
	return out


## Where a station of `kind` would go: in front of the player if flat and clear,
## else the nearest clear spot around them. Vector2(-INF) if none.
static func _build_spot(game: Game, kind: int) -> Vector2:
	var p := game.player.pos
	var here := game.world.level_at(floori(p.x), floori(p.y))
	var radius: float = PropKind.SOLID[kind]
	for turn: float in [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6, PI]:
		var s := p + Vector2.from_angle(game.player.facing + turn) * (BUILD_DISTANCE + radius)
		if _clear(game, s, radius, here):
			return s
	return Vector2(-INF, -INF)


static func _clear(game: Game, s: Vector2, radius: float, level: int) -> bool:
	var w := game.world
	for c: Vector2 in [s, s + Vector2(radius, 0), s - Vector2(radius, 0), s + Vector2(0, radius), s - Vector2(0, radius)]:
		var tx := floori(c.x)
		var ty := floori(c.y)
		if not game.query.standable(tx, ty) or Ground.is_water(w.ground_at(tx, ty)) or w.level_at(tx, ty) != level:
			return false
	for q in game.query.props_near(s, 4.0):
		if w.depleted.has(q.id):
			continue
		# Not under a crown: a tree's canopy is wider than its trunk.
		var body := maxf(q.solid, 0.25)
		if q.kind == PropKind.PINE or q.kind == PropKind.SNOW_PINE or q.kind == PropKind.BROADLEAF:
			body = maxf(body, 0.7 * q.scale)
		elif q.kind == PropKind.HOUSE:
			# Nor under the eaves: a roof reaches past the walls it stands on.
			body = maxf(body, 2.1 * q.scale)
		var gap := body + radius + 0.2
		if q.pos.distance_squared_to(s) < gap * gap:
			return false
	return true


# --- The held tool ----------------------------------------------------------

static func hold(game: Game, id: StringName) -> bool:
	if id != &"" and not game.inventory.has(id):
		return false
	game.inventory.set_held(id)
	if game.player != null and game.player.model != null:
		game.player.model.set_held(id)
	return true


static func hone(game: Game) -> bool:
	return Crafting.make_in(game, Crafting.recipe(&"sharpen"))


static func reedge(game: Game) -> bool:
	return Crafting.make_in(game, Crafting.recipe(&"reedge"))


# --- Per frame -------------------------------------------------------------

static func tick(game: Game, delta: float) -> void:
	var state := SurvivalState.of(game)
	if not state.job.is_empty() and now_real() >= float(state.job.done_at):
		finish_work(game)
	state.sweep_in -= delta
	if state.sweep_in <= 0.0:
		state.sweep_in = 1.0
		sweep(game, delta)
	update_body(game)
	if not state.cooking.is_empty():
		collect(game)
	_hunger(game)
	_lamp_low(game)


## Hungry and starving read differently: each is said once as it begins, the
## body is slower at each (Condition.step_extra), and a starving body only sits
## down STARVING_GRACE_MINUTES after it was warned, never on the step it begins.
static func _hunger(game: Game) -> void:
	var state := SurvivalState.of(game)
	var now := game.clock.minutes
	var level := game.body.hunger_level(now)
	if level < 2:
		state.hunger_said = level
		state.starving_since = INF
		return
	if level > state.hunger_said:
		state.hunger_said = level
		Events.message.emit(STARVING_LINE if level == 3 else HUNGRY_LINE)
	if level < 3:
		state.starving_since = INF
		return
	state.starving_since = minf(state.starving_since, now)
	if now - state.starving_since >= STARVING_GRACE_MINUTES and game.player.speed > 0.1 and state.job.is_empty():
		state.starving_since = INF
		state.hunger_said = 0
		collapse(game)


## A lit lamp with little oil left says so once, and again once more oil was poured.
static func _lamp_low(game: Game) -> void:
	var state := SurvivalState.of(game)
	var oil := lamp_oil(game)
	if not game.body.lamp_lit or oil > LAMP_LOW_MINUTES:
		if oil > LAMP_LOW_MINUTES:
			state.lamp_low_said = false
		return
	if not state.lamp_low_said:
		state.lamp_low_said = true
		Events.message.emit(LAMP_LOW_LINE)


# --- Putting down -------------------------------------------------------------

## Put down `n` of a carried thing (the slate's drop verb) on a heap in front of
## the player: the one already in reach, or a new cairn. `use` on it takes it all
## back. Refused with a hostile close (a knife is not put down in a fight), or
## where there is no ground for a heap. The held tool goes to bare hands, worn
## kit comes off. Returns how many were put down.
static func drop(game: Game, id: StringName, n: int = 1) -> int:
	var inv := game.inventory
	var have := inv.count(id)
	var k := mini(n, have)
	if k <= 0:
		return 0
	if threat_near(game):
		Events.message.emit(THREAT_LINE)
		Events.sfx.emit(&"refuse", game.player.position)
		return 0
	var state := SurvivalState.of(game)
	var heap := heap_near(game)
	if heap == null:
		var spot := _heap_spot(game)
		if spot.x < -1e8:
			Events.message.emit("Not here.")
			return 0
		heap = add_prop(game, PropKind.CAIRN, spot, NAN, HEAP_SCALE)
		state.left[heap.id] = {}
	if id == &"lamp" and game.body.lamp_lit and k >= have:
		game.body.lamp_lit = false
	var edge := inv.edge(id)
	inv.remove(id, k)
	var goods: Dictionary = state.left[heap.id]
	goods[id] = int(goods.get(id, 0)) + k
	if Items.has_edge(id):
		# The edge stays with the tool: a knife taken back is as worn as it was left.
		goods["edge:%s" % id] = edge
	if inv.held == &"" and game.player != null and game.player.model != null:
		game.player.model.set_held(&"")
	update_body(game)
	Events.sfx.emit(&"took", game.world.to_3d(heap.pos))
	Events.message.emit("Left %s." % _count_words(id, k))
	return k


## CARRIED OFF COSTS PLACE AS WELL AS TIME (mechanics improvement 4a). What the
## player carried stays where they were taken, on a heap of their own with their
## own rag tied on a stick over it (PropModels BAG_CAIRN), marked on the survey,
## and said once in so many words. Nothing takes it and nothing spoils it: the
## cost is the walk back, which the player can see and plan, never a loss they
## cannot. What is on the body stays on it: the tool in the hand, the kit worn,
## the gear fitted (a module socketed in it included).
const BAG_LINE := "Your things are where it took you. The survey marks the place."
const BAG_SCALE := 0.8


static func leave_bag(game: Game, at: Vector2) -> WorldProp:
	var inv := game.inventory
	if inv == null:
		return null
	var keep := {}
	if inv.held != &"":
		keep[inv.held] = 1
	if inv.worn != &"":
		keep[inv.worn] = maxi(int(keep.get(inv.worn, 0)), 1)
	var fitted := _loadout(game)
	if fitted != null:
		for id: StringName in fitted.all_ids():
			keep[id] = maxi(int(keep.get(id, 0)), fitted.fitted_count(id))
	var goods := {}
	for id: StringName in inv.items.keys():
		var n := inv.count(id) - int(keep.get(id, 0))
		if n <= 0:
			continue
		if id == &"lamp" and game.body != null:
			game.body.lamp_lit = false
		if Items.has_edge(id):
			goods["edge:%s" % id] = inv.edge(id)
		goods[id] = n
		inv.remove(id, n)
	if goods.is_empty():
		return null
	var spot := _heap_spot_at(game, at, game.player.facing if game.player != null else 0.0, BAG_SCALE)
	if spot.x < -1e8:
		# Nowhere clear round it: the heap goes where they were, whatever is there.
		spot = at
	var heap := add_prop(game, PropKind.CAIRN, spot, NAN, BAG_SCALE, PropModels.BAG_CAIRN)
	var state := SurvivalState.of(game)
	state.left[heap.id] = goods
	state.bags[heap.id] = game.clock.minutes if game.clock != null else 0.0
	update_body(game)
	return heap


## The gear system's loadout, found by the field rather than the name; null without one.
static func _loadout(game: Game) -> Loadout:
	for sys in game.systems:
		var l: Variant = sys.get("loadout")
		if l is Loadout:
			return l
	return null


## A heap is a small cairn: a few stones over what was left.
const HEAP_SCALE := 0.6
## A heap this close (edge, tiles) is found by `use` whichever way the player faces.
const HEAP_REACH := 0.8


## Where a heap goes: just in front of the player, else anywhere round them, on
## their own level, dry, and clear of trunks and rocks (a heap may lie under a
## crown, unlike a fire). Vector2(-INF) if nowhere.
static func _heap_spot(game: Game) -> Vector2:
	return _heap_spot_at(game, game.player.pos, game.player.facing, HEAP_SCALE)


## The same round any point, for a heap of `scale`.
static func _heap_spot_at(game: Game, p: Vector2, facing: float, scale: float) -> Vector2:
	var w := game.world
	var here := w.level_at(floori(p.x), floori(p.y))
	var radius: float = PropKind.SOLID[PropKind.CAIRN] * scale
	for turn: float in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8, 2.5, -2.5, PI]:
		var at := p + Vector2.from_angle(facing + turn) * (Tuning.PLAYER_RADIUS + radius + 0.15)
		var t := Vector2i(floori(at.x), floori(at.y))
		if not game.query.standable(t.x, t.y) or Ground.is_water(w.ground_at(t.x, t.y)) or w.level_at(t.x, t.y) != here:
			continue
		var clear := true
		for q in game.query.props_near(at, 2.0):
			if w.depleted.has(q.id) or q.solid <= 0.0:
				continue
			if q.pos.distance_to(at) < q.solid + radius + 0.05:
				clear = false
				break
		if clear:
			return at
	return Vector2(-INF, -INF)


## The player's own heap within STATION_REACH, or null.
static func heap_near(game: Game) -> WorldProp:
	var state := SurvivalState.of(game)
	var best: WorldProp = null
	var best_d := INF
	for q in game.query.props_near(game.player.pos, STATION_REACH + 2.0):
		if not state.left.has(q.id) or game.world.depleted.has(q.id):
			continue
		var d := q.pos.distance_to(game.player.pos) - q.solid
		if d <= STATION_REACH and d < best_d:
			best_d = d
			best = q
	return best


## Everything on a heap the player left comes back into the creel, and the
## heap is gone. No time passes. Returns how many things came back.
static func take_back(game: Game, heap: WorldProp) -> int:
	var state := SurvivalState.of(game)
	if heap == null or not state.left.has(heap.id):
		return 0
	var goods: Dictionary = state.left[heap.id]
	state.left.erase(heap.id)
	state.bags.erase(heap.id)
	var inv := game.inventory
	var got := 0
	var parts: PackedStringArray = []
	for key: Variant in goods:
		if String(key).begins_with("edge:"):
			continue
		var id := StringName(key)
		var n := int(goods[key])
		var had := inv.has(id)
		var kept := inv.edge(id)
		inv.add(id, n)
		if goods.has("edge:%s" % id):
			# Edges are per id, the best copy's (Inventory).
			var left := int(goods["edge:%s" % id])
			inv.set_edge(id, maxi(kept, left) if had else left)
		Events.took.emit(id, n)
		parts.append(_count_words(id, n))
		got += n
		if inv.held == &"" and _fights(id):
			# Empty hands take the blade back into them.
			hold(game, id)
	game.world.depleted[heap.id] = INF
	if game.view != null:
		game.view.refresh_props(heap)
	update_body(game)
	Events.sfx.emit(&"took", game.world.to_3d(heap.pos))
	if not parts.is_empty():
		Events.message.emit("Took back %s." % ", ".join(parts))
	return got


## The only thing carried that fights better than bare hands: the hold-to-drop
## key puts it away instead of leaving it on the ground.
static func last_weapon(game: Game, id: StringName) -> bool:
	if id == &"" or not _fights(id) or game.inventory.count(id) > 1:
		return false
	for other: StringName in game.inventory.items:
		if other != id and _fights(other):
			return false
	return true


static func _fights(id: StringName) -> bool:
	var d := Items.def(id)
	return bool(d.get("tool", false)) and int(d.get("dmg", 1)) > int(Items.FISTS.dmg)


static func _count_words(id: StringName, n: int) -> String:
	const WORDS := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
	var name := Items.display_name(id)
	return "%s %s" % [WORDS[n] if n < WORDS.size() else str(n), name]


# --- Work left at a station -------------------------------------------------

## The station prop in reach that makes recipes `at` (nearest), or null.
static func station_prop(game: Game, at: StringName) -> WorldProp:
	var p := game.player.pos
	var best: WorldProp = null
	var best_d := INF
	for q in game.query.props_near(p, STATION_REACH + 2.0):
		if not STATION_KINDS.has(q.kind) or game.world.depleted.has(q.id) or not (STATION_KINDS[q.kind] as Array).has(at):
			continue
		var d := q.pos.distance_to(p) - q.solid
		if d <= STATION_REACH and d < best_d:
			best_d = d
			best = q
	return best


## The job a station prop is working, or {}.
static func job_at(game: Game, prop: WorldProp) -> Dictionary:
	if prop == null:
		return {}
	return SurvivalState.of(game).cooking.get(prop.id, {})


## A long recipe put on the station in reach to work in world time: the goods
## go in now, the makings come out at `done`, collected by walking back to it.
## The clock is charged SET_GOING_MINUTES. Returns the station, or null.
static func set_going(game: Game, r: Dictionary) -> WorldProp:
	var prop := station_prop(game, r.at)
	if prop == null or not job_at(game, prop).is_empty():
		return null
	var inv := game.inventory
	for id: StringName in r.needs:
		inv.remove(id, r.needs[id])
	var done := game.clock.minutes + SET_GOING_MINUTES + float(r.minutes)
	SurvivalState.of(game).cooking[prop.id] = {"prop": prop, "station": r.at, "recipe": r.id,
		"makes": (r.makes as Dictionary).duplicate(), "done": done, "pos": prop.pos}
	_act(game, &"work", WORK_SECONDS)
	_skip(game, SET_GOING_MINUTES, &"make")
	Events.sfx.emit(&"make", game.world.to_3d(prop.pos))
	var what := _makes_words(r.makes)
	Events.message.emit("%s%s on the %s, ready at %s." % [what.substr(0, 1).to_upper(), what.substr(1), r.at, _clock(done)])
	return prop


## Every station's work, soonest done first.
static func cooking(game: Game) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: int in SurvivalState.of(game).cooking:
		out.append(SurvivalState.of(game).cooking[id])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.done) < float(b.done))
	return out


## Take what finished at every station in reach. Returns how many jobs came out.
static func collect(game: Game) -> int:
	var state := SurvivalState.of(game)
	var now := game.clock.minutes
	var got := 0
	for id: int in state.cooking.keys():
		var job: Dictionary = state.cooking[id]
		var prop: WorldProp = job.prop
		if game.world.depleted.has(prop.id):
			# The station is gone, and what was on it with it.
			state.cooking.erase(id)
			continue
		if float(job.done) > now or prop.pos.distance_to(game.player.pos) - prop.solid > STATION_REACH:
			continue
		state.cooking.erase(id)
		Crafting.receive(game.inventory, job.makes)
		if game.player.model != null:
			game.player.model.set_held(game.inventory.held)
		Events.sfx.emit(&"took", game.world.to_3d(prop.pos))
		Events.message.emit("Took %s from the %s." % [_makes_words(job.makes), job.station])
		got += 1
	return got


static func _makes_words(makes: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id: StringName in makes:
		parts.append(_count_words(id, int(makes[id])))
	return ", ".join(parts)


static func _clock(minutes: float) -> String:
	return "%02d:%02d" % [floori(fposmod(minutes, 1440.0) / 60.0), floori(fposmod(minutes, 60.0))]


## Once a second: things grow back, weather and water wet you, fires dry you.
static func sweep(game: Game, _delta: float) -> void:
	var state := SurvivalState.of(game)
	var now := game.clock.minutes
	var w := game.world
	for id: int in w.depleted.keys():
		var prop := w.prop(id)
		if float(w.depleted[id]) > now or prop == null:
			continue
		# Nothing grows back through a body standing in it.
		if prop.solid > 0.0 and prop.pos.distance_to(game.player.pos) < prop.solid + Tuning.PLAYER_RADIUS:
			w.depleted[id] = now + 30.0
			continue
		w.depleted.erase(id)
		for k: String in state.taken.keys():
			if k.begins_with("%d:" % id):
				state.taken.erase(k)
		# Grown back whole: the size it had before anybody took from it.
		Harvest.apply_shown(game, prop)
		if game.view != null:
			game.view.refresh_props(prop)
		Events.sfx.emit(&"regrow", w.to_3d(prop.pos))
	for k: String in state.spent.keys():
		if float(state.spent[k]) <= now:
			state.spent.erase(k)
			state.taken.erase(k)
	burn_lamp(game)
	var p := game.player.pos
	var g := w.ground_at(floori(p.x), floori(p.y))
	if Ground.is_water(g) or (not in_village(game) and _weather_wets(game, now)):
		state.wet_until = now + Condition.WET_MINUTES
	elif fire_near(game) != null and state.wet_until > now:
		# A fire dries you six times as fast as the air does.
		state.wet_until -= 5.0 * Tuning.MINUTES_PER_SECOND


static func update_body(game: Game) -> void:
	var state := SurvivalState.of(game)
	var body := game.body
	var inv := game.inventory
	var now := game.clock.minutes
	body.load = inv.bulk()
	body.wet = clampf((state.wet_until - now) / Condition.WET_MINUTES, 0.0, 1.0)
	var tired := Condition.is_tired(now, state.woke_at)
	body.tired = 1.0 if tired else 0.0
	var extra := Condition.step_extra(body.load, inv.creel(), body.hunger_level(now), tired, body.wet > 0.0, is_hurt(game))
	# What the place is pressing on the body slows it too (the hazards package
	# writes Body.pressure; a pressure is felt in the legs before it draws blood).
	body.move_factor = Condition.move_factor(extra) * Hazards.move_factor(body.pressure)


## Hurt: short of health, or still carrying a wound the fight left (Body.hurt_until,
## the fight package's field, read by name so this loads before it lands).
static func is_hurt(game: Game) -> bool:
	var body := game.body
	if body.health < body.max_health:
		return true
	var until: Variant = body.get("hurt_until")
	return (until is float or until is int) and float(until) > game.clock.minutes


# --- The lamp ------------------------------------------------------------------

## Burn the lit lamp's oil up to now: the flask in the lamp first, then a carried
## `oil` is poured in, one at a time. Dry, it goes out with a line. With no lamp
## carried there is nothing to light. The sky package toggles Body.lamp_lit;
## this only puts it out.
static func burn_lamp(game: Game) -> void:
	var state := SurvivalState.of(game)
	var now := game.clock.minutes
	var minutes := maxf(0.0, now - state.lamp_at) if state.lamp_at > -INF else 0.0
	state.lamp_at = now
	var body := game.body
	if not body.lamp_lit:
		return
	var inv := game.inventory
	if not inv.has(&"lamp"):
		body.lamp_lit = false
		Events.message.emit("You have no lamp.")
		return
	var r := Condition.burn_lamp(state.lamp_oil, minutes, inv.count(&"oil"))
	if int(r.flasks) > 0:
		inv.remove(&"oil", int(r.flasks))
	state.lamp_oil = r.left
	if r.out:
		body.lamp_lit = false
		Events.message.emit("The lamp gutters, and goes out.")
		Events.sfx.emit(&"lamp_out", game.player.position)


static func lamp_oil(game: Game) -> float:
	return SurvivalState.of(game).lamp_oil + game.inventory.count(&"oil") * Condition.LAMP_FLASK_MINUTES


## Starving on your feet: sit down for a shift; wake as if you ate 7 h ago.
static func collapse(game: Game) -> void:
	_act(game, &"downed", 2.0)
	_skip(game, Condition.COLLAPSE_MINUTES, &"collapse")
	var now := game.clock.minutes
	game.body.fed_until = now - Condition.COLLAPSE_ATE_AGO_H * 60.0 + Condition.FED_HOURS * 60.0
	Events.message.emit("You sit down, and it is a long time before you get up.")
	Events.sfx.emit(&"collapse", game.player.position)


# --- Plumbing ----------------------------------------------------------------

## Turn the player to `angle` (radians, 0 = east). The fight body that stands
## in for the player is turned too, or it would turn the player straight back.
static func face(game: Game, angle: float) -> void:
	game.player.facing = angle
	if game.player.hero != null:
		game.player.hero.facing = angle
	game.player.drive(Vector2.ZERO, false, 0.0)


static func _skip(game: Game, minutes: float, reason: StringName) -> void:
	if minutes <= 0.0:
		return
	game.clock.skip(minutes)
	Events.time_skipped.emit(minutes, reason)


static func _act(game: Game, action: StringName, seconds: float) -> void:
	if game.player != null and game.player.model != null:
		game.player.model.play_action(action, seconds)


## Is the sky wetting a body at `minutes`, where it stands (the weather of
## the country underfoot, so a front that rains on the coast snows up north)?
static func _weather_wets(game: Game, minutes: float) -> bool:
	# Under a roof nothing falls (Realm.roofed): a room's tiles carry the land
	# its house stands in, and that land's rain does not come through the ceiling.
	if Realm.roofed(game.world.realm):
		return false
	var p := game.player.pos
	var d := Weather.at_place(game.world.seed_value, minutes, game.world.country_at(floori(p.x), floori(p.y)))
	return Condition.wets(String(d.get("kind", "")), float(d.get("strength", 0.0)))
