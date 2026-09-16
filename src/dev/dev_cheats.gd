class_name DevCheats
## What dev mode does to a running game, as plain calls a page, a key, a test
## or a tour can make. Every one goes through the doors the game's own packages
## use (the fight body for a place, the sky system for weather, the mob system
## for a body, the gear system for a fit), so nothing here can leave the game in
## a state play could not.
##
## Each marks the game as touched (DevMode.touched): a save made after it says so.


static func system(game: Game, n: String) -> Node:
	if game == null:
		return null
	for s in game.systems:
		if s.name == n:
			return s
	return null


# --- going places -----------------------------------------------------------------

## Where dev mode can go in this world: [{id, label, pos, note}], the strand
## first, then every landscape, every village, the river and the cliff, and the
## first of each kind of landmark.
static func places(game: Game) -> Array[Dictionary]:
	var w := game.world
	var out: Array[Dictionary] = [{"id": &"spawn", "label": "the strand", "pos": w.spawn, "note": "where a new game wakes"}]
	for b in BiomeRegistry.land():
		var p := GenPlaces.find(w, String(b.id))
		if p.x >= 0.0:
			out.append({"id": StringName("land_" + String(b.id)), "label": b.display_name.to_lower(), "pos": p, "note": "deep in the landscape"})
	for i in w.villages.size():
		var v: Dictionary = w.villages[i]
		var vp: Vector2 = (v.pos as Vector2) + Vector2(3, 3)
		out.append({"id": StringName("village_%d" % i), "label": "village %d" % i, "pos": vp,
			"note": "in %s" % BiomeRegistry.at(w, vp).display_name.to_lower()})
	for pair: Array in [["river", "the river"], ["cliff", "the cliff"]]:
		var p := GenPlaces.find(w, pair[0])
		if p.x >= 0.0:
			out.append({"id": StringName(pair[0]), "label": pair[1], "pos": p, "note": ""})
	var kinds := {}
	for m: Dictionary in w.landmarks:
		var k := String(m.kind)
		if kinds.has(k):
			continue
		kinds[k] = true
		var p := GenPlaces.find(w, k)
		if p.x >= 0.0:
			out.append({"id": StringName("mark_" + k), "label": k.replace("_", " "), "pos": p, "note": "the first of its kind"})
	return out


## Put the player at `p` as the fight body, the view, the camera and the sky
## expect (the tour's `at` does the same).
static func teleport(game: Game, p: Vector2) -> void:
	p = standable_near(game, p)
	if game.player.hero != null:
		game.player.hero.pos = p
		game.player.hero.move = Vector2.ZERO
	game.player.pos = p
	game.player.position = game.world.to_3d(p)
	game.view.ensure_near(p)
	game.camera.snap_to(game.player.position)
	var sky := system(game, "10_sky")
	if sky != null:
		sky.call("_update", 0.0, true)
	DevMode.touched = true


## The nearest tile a body may stand on, in rings out from `p`.
static func standable_near(game: Game, p: Vector2) -> Vector2:
	var cx := floori(p.x)
	var cy := floori(p.y)
	if game.query.standable(cx, cy):
		return p
	for r in range(1, 40):
		for i in range(-r, r + 1):
			for q: Vector2i in [Vector2i(cx + i, cy - r), Vector2i(cx + i, cy + r), Vector2i(cx - r, cy + i), Vector2i(cx + r, cy + i)]:
				if game.query.standable(q.x, q.y):
					return Vector2(q.x + 0.5, q.y + 0.5)
	return p


# --- time and sky -------------------------------------------------------------------

## Set the hour of the same day (as a tour's `hour` does).
static func set_hour(game: Game, hour: float) -> void:
	var day := floorf(game.clock.minutes / 1440.0)
	game.clock.minutes = day * 1440.0 + fposmod(hour, 24.0) * 60.0
	_sky_now(game)
	DevMode.touched = true


static func add_minutes(game: Game, minutes: float) -> void:
	game.clock.minutes = maxf(0.0, game.clock.minutes + minutes)
	_sky_now(game)
	DevMode.touched = true


## "kind:strength[:bolt]", or "rules" to hand the sky back. True when taken.
static func set_weather(game: Game, spec: String) -> bool:
	var sky := system(game, "10_sky")
	if sky == null or not bool(sky.call("apply_weather", spec)):
		return false
	sky.call("_update", 0.0, true)
	DevMode.touched = true
	return true


## The weather where the player stands: {kind, strength, forced}.
static func weather_here(game: Game) -> Dictionary:
	var type_id := BiomeRegistry.at(game.world, game.player.pos).id
	var w := Weather.at_type(game.world.seed_value, game.clock.minutes, type_id)
	return {"kind": StringName(w.get("kind", &"clear")), "strength": float(w.get("strength", 0.0)), "forced": Weather.forced_kind != &""}


static func _sky_now(game: Game) -> void:
	var sky := system(game, "10_sky")
	if sky != null:
		sky.call("_update", 0.0, true)


# --- the body ---------------------------------------------------------------------------

static func mend(game: Game) -> void:
	var b := game.body
	b.health = b.max_health
	b.wind = b.max_wind
	b.grip = 0
	b.hurt_until = 0.0
	b.stun_until = 0.0
	if game.player.hero != null:
		game.player.hero.health = b.max_health
		game.player.hero.wind = game.player.hero.max_wind
	DevMode.touched = true


## Fed for the next fourteen hours (as a full meal leaves the body).
static func feed(game: Game) -> void:
	game.body.fed_until = maxf(game.body.fed_until, game.clock.minutes + 14.0 * 60.0)
	DevMode.touched = true


static func dry(game: Game) -> void:
	game.body.wet = 0.0
	DevMode.touched = true


static func fill_lamp(game: Game) -> void:
	SurvivalState.of(game).lamp_oil = Condition.LAMP_FLASK_MINUTES
	DevMode.touched = true


## Machines read the player as one of their own for the next world hour.
static func unseen(game: Game) -> void:
	game.body.spoof_until = maxf(game.body.spoof_until, game.clock.minutes + 60.0)
	DevMode.touched = true


## Every pressure kept off (re-asserted while the toggle is on: gear writes
## Body.resist whenever what is worn changes).
static func shelter(game: Game) -> void:
	for id: StringName in Hazards.IDS:
		game.body.resist[id] = 1.0


# --- things ----------------------------------------------------------------------------

## Put `n` of `id` in the creel; a wearable is fitted as --fit fits it.
static func give(game: Game, id: StringName, n: int = 1) -> String:
	if Items.def(id).is_empty():
		return "!There is no %s." % id
	var gear := system(game, "54_gear")
	if Gear.slot_of(id) != &"" or Gear.is_module(id):
		game.inventory.add(id, maxi(1, n))
		if gear != null:
			var was: PackedStringArray = game.options.fit
			game.options.fit = PackedStringArray([String(id)])
			gear.call("_fit_from_options")
			gear.call("_refit")
			game.options.fit = was
		DevMode.touched = true
		return "Wearing %s." % Items.display_name(id)
	game.inventory.add(id, maxi(1, n))
	DevMode.touched = true
	return "Gave %d %s." % [maxi(1, n), Items.display_name(id)]


## Everything carried put away but the knife in hand.
static func empty_creel(game: Game) -> void:
	for id: StringName in game.inventory.items.keys():
		if id != &"knife":
			game.inventory.remove(id, game.inventory.count(id))
	if game.inventory.count(&"knife") == 0:
		game.inventory.add(&"knife")
	game.inventory.set_held(&"knife")
	DevMode.touched = true


# --- bodies and the plan -----------------------------------------------------------------

## The roster, machines first, each group in the order the roster declares it.
static func kinds() -> Array[StringName]:
	var machines: Array[StringName] = []
	var creatures: Array[StringName] = []
	for k in Roster.kinds():
		if bool(Roster.row(k).get("machine", false)):
			machines.append(k)
		else:
			creatures.append(k)
	machines.append_array(creatures)
	return machines


static func spawn(game: Game, kind: StringName) -> bool:
	var mobs := system(game, "30_mobs")
	if mobs == null:
		return false
	DevMode.touched = true
	return mobs.call("place_near_player", kind) != null


## Take every body off the land round the player.
static func clear_bodies(game: Game) -> void:
	if game.player.sim != null:
		game.player.sim.clear_mobs()
	DevMode.touched = true


## Whether the spawner puts bodies on the land (a live rule, rules.machines).
static func set_spawning(game: Game, on: bool) -> void:
	var mobs := system(game, "30_mobs")
	if mobs == null:
		return
	var coast: Variant = mobs.get("coast")
	if coast is Object:
		(coast as Object).set("spawning", on)


## The plan network the player stands in: {net, value, level: StringName}.
static func file_here(game: Game) -> Dictionary:
	var disp := system(game, "32_disposition")
	var net := Interference.network(game.world, game.player.pos)
	if disp == null:
		return {"net": net, "value": 0.0, "level": &"calm"}
	var i: Interference = disp.get("interference")
	return {"net": net, "value": i.value(net), "level": i.level_name(net)}


## Set the file the network where the player stands keeps, to the floor of a level.
static func set_file(game: Game, level: int) -> void:
	var disp := system(game, "32_disposition")
	if disp == null:
		return
	var i: Interference = disp.get("interference")
	var net := Interference.network(game.world, game.player.pos)
	i.levels[net] = Interference.THRESHOLDS[clampi(level, 0, Interference.THRESHOLDS.size() - 1)] + (0.02 if level > 0 else 0.0)
	i.scenes[net] = game.player.pos
	DevMode.touched = true
