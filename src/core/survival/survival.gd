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
##                                           "campfire - build", or ""
##   use(game) -> bool                       the `use` action: work the target; else sleep, eat or
##                                           build a fire, whichever fits
##   work(game, prop) -> bool                start working a prop (refusals go to Events.message)
##   finish_work(game) -> bool               complete the work in hand now (the system does this
##                                           when its real time is up; bots call it directly)
##   eat(game, id) -> bool                   eat one food item from the creel
##   best_food(game) -> StringName           what eat would pick, or &""
##   sleep(game) -> bool / sleep_refusal(game) -> String ("" = can sleep)
##   build_fire(game) -> WorldProp           a campfire in front of the player from what is carried
##   build(game, station, free) -> WorldProp any station (fire bench kiln) per its recipe
##   hold(game, id) -> bool                  put a carried item in hand (&"" = bare hands)
##   hone(game) -> bool / reedge(game) -> bool   mend the held tool (see Crafting recipes sharpen/reedge)
##   tick(game, delta)                       per frame: finish work, body condition, regrowth
##
## Events emitted: took(item, n), made(item, n), time_skipped(minutes, reason:
## work eat sleep make build collapse), message(line), sfx(name, at) with names
## work_<verb> took refuse eat sleep build_<station> make hone collapse regrow.

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
const VILLAGE_RADIUS := 11.0
const BUILD_DISTANCE := 1.25

const STATION_KINDS := {PropKind.FIRE: [&"fire"], PropKind.BENCH: [&"bench"], PropKind.KILN: [&"kiln"],
	PropKind.HOUSE: [&"bench", &"wheel", &"loom"]}
const BUILD_KINDS := {&"fire": PropKind.FIRE, &"bench": PropKind.BENCH, &"kiln": PropKind.KILN}


static func now_real() -> float:
	return Time.get_ticks_msec() / 1000.0


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
		if (v.pos as Vector2).distance_to(game.player.pos) <= VILLAGE_RADIUS:
			return true
	return false


# --- Targets --------------------------------------------------------------

static func use_target(game: Game) -> WorldProp:
	var p := game.player.pos
	var ahead := Vector2.from_angle(game.player.facing)
	var best: WorldProp = null
	var best_score := INF
	var state := SurvivalState.of(game)
	for q in game.query.props_near(p, REACH + 2.0):
		if not Takes.workable(q.kind) or game.world.depleted.has(q.id):
			continue
		var to := q.pos - p
		var edge := to.length() - q.solid
		if edge > REACH:
			continue
		var dot := ahead.dot(to.normalized()) if to.length() > 0.01 else 1.0
		# Something you are pressed against counts even a little to the side.
		if dot < CONE and not (edge < 0.35 and dot > -0.2):
			continue
		var score := edge + (1.0 - dot) * 0.6
		if not _choose(game, state, q).ok:
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
		&"sleep":
			return "%s - sleep" % ("fire" if fire_near(game) != null else "village")
		&"eat":
			return "%s - eat" % Items.display_name(best_food(game))
		&"build":
			return "campfire - build"
	return ""


# --- The use action -------------------------------------------------------

static func use(game: Game) -> bool:
	if busy(game):
		return false
	var t := use_target(game)
	if t != null:
		return work(game, t)
	match _fallback(game):
		&"sleep":
			return sleep(game)
		&"eat":
			return eat(game, best_food(game))
		&"build":
			return build_fire(game) != null
	return false


static func _fallback(game: Game) -> StringName:
	if sleep_refusal(game) == "":
		return &"sleep"
	if game.body.hunger_level(game.clock.minutes) >= 1 and best_food(game) != &"":
		return &"eat"
	if fire_near(game, 5.0) == null and _makeable_build(game, &"fire").size() > 0 and _build_spot(game, PropKind.FIRE).x > -1e8:
		return &"build"
	return &""


static func busy(game: Game) -> bool:
	return not SurvivalState.of(game).job.is_empty() or now_real() < game.body.busy_until


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
	state.job = {"prop": prop, "index": c.index, "option": o, "tool": tool, "minutes": minutes,
		"done_at": now_real() + WORK_SECONDS}
	game.body.busy_until = now_real() + WORK_SECONDS
	var to := prop.pos - game.player.pos
	if to.length() > 0.01:
		game.player.facing = to.angle()
		game.player.drive(Vector2.ZERO, false, 0.0)
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
	Events.sfx.emit(&"took", game.world.to_3d(prop.pos))
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
	game.inventory.remove(id, 1)
	var now := game.clock.minutes
	game.body.fed_until = Condition.fed_after_eating(game.body.fed_until, now, Items.feeds(id))
	game.body.busy_until = now_real() + EAT_SECONDS
	_act(game, &"eat", EAT_SECONDS)
	_skip(game, Condition.EAT_MINUTES, &"eat")
	Events.sfx.emit(&"eat", game.player.position)
	return true


static func sleep_refusal(game: Game) -> String:
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
	_skip(game, wake - now, &"sleep")
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
## it and can be made from what is carried; `free` skips the cost (shots, tests).
static func build(game: Game, station: StringName, free: bool = false) -> WorldProp:
	if not BUILD_KINDS.has(station) or busy(game):
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
	if minutes > 0.0:
		_act(game, &"work", WORK_SECONDS)
		_skip(game, minutes, &"build")
	Events.sfx.emit(StringName("build_%s" % station), game.world.to_3d(spot))
	return prop


## A new prop in the world: data, collision and view.
static func add_prop(game: Game, kind: int, pos: Vector2) -> WorldProp:
	var w := game.world
	var id := w.props.size()
	var prop := WorldProp.new(id, kind, pos, Rng.hash01(w.seed_value, id, 77) * TAU, 1.0)
	w.props.append(prop)
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
	for q in game.query.props_near(s, 3.0):
		if w.depleted.has(q.id):
			continue
		var gap := maxf(q.solid, 0.25) + radius + 0.2
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
	if game.body.hunger_level(game.clock.minutes) == 3 and game.player.speed > 0.1 and state.job.is_empty():
		collapse(game)


## Once a second: things grow back, weather and water wet you, fires dry you.
static func sweep(game: Game, _delta: float) -> void:
	var state := SurvivalState.of(game)
	var now := game.clock.minutes
	var w := game.world
	for id: int in w.depleted.keys():
		if float(w.depleted[id]) > now or id < 0 or id >= w.props.size():
			continue
		var prop := w.props[id]
		# Nothing grows back through a body standing in it.
		if prop.solid > 0.0 and prop.pos.distance_to(game.player.pos) < prop.solid + Tuning.PLAYER_RADIUS:
			w.depleted[id] = now + 30.0
			continue
		w.depleted.erase(id)
		for k: String in state.taken.keys():
			if k.begins_with("%d:" % id):
				state.taken.erase(k)
		if game.view != null:
			game.view.refresh_props(prop)
		Events.sfx.emit(&"regrow", w.to_3d(prop.pos))
	for k: String in state.spent.keys():
		if float(state.spent[k]) <= now:
			state.spent.erase(k)
			state.taken.erase(k)
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
	var extra := Condition.step_extra(body.load, inv.creel(), body.hunger_level(now), tired, body.wet > 0.0, body.health < body.max_health)
	body.move_factor = Condition.move_factor(extra)


## Starving on your feet: sit down for a shift; wake as if you ate 7 h ago.
static func collapse(game: Game) -> void:
	_act(game, &"downed", 2.0)
	_skip(game, Condition.COLLAPSE_MINUTES, &"collapse")
	var now := game.clock.minutes
	game.body.fed_until = now - Condition.COLLAPSE_ATE_AGO_H * 60.0 + Condition.FED_HOURS * 60.0
	Events.message.emit("You sit down, and it is a long time before you get up.")
	Events.sfx.emit(&"collapse", game.player.position)


# --- Plumbing ----------------------------------------------------------------

static func _skip(game: Game, minutes: float, reason: StringName) -> void:
	if minutes <= 0.0:
		return
	game.clock.skip(minutes)
	Events.time_skipped.emit(minutes, reason)


static func _act(game: Game, action: StringName, seconds: float) -> void:
	if game.player != null and game.player.model != null:
		game.player.model.play_action(action, seconds)


static var _weather: GDScript = null
static var _weather_checked := false


## Is the sky wetting a body at `minutes`? False until src/core/weather.gd exists.
static func _weather_wets(game: Game, minutes: float) -> bool:
	if not _weather_checked:
		_weather_checked = true
		if ResourceLoader.exists("res://src/core/weather.gd"):
			_weather = load("res://src/core/weather.gd")
	if _weather == null:
		return false
	var wx: Variant = _weather.call("at", game.world.seed_value, minutes)
	if not wx is Dictionary:
		return false
	var d: Dictionary = wx
	return Condition.wets(String(d.get("kind", "")), float(d.get("strength", 0.0)))
