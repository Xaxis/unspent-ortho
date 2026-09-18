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

## Where dev mode can go in this world: [{id, label, pos, note}], in the order
## the GO page groups them — the strand, every REGION of every landscape, every
## border two landscapes actually share, every village, the river and the cliff,
## the plan's depots, the keepers' lairs, the shafts down, and the first of each
## kind of landmark.
##
## "Anywhere in the world so I can inspect and debug" (owner, 2026-09-18). Three
## of these groups were missing and each hid a whole class of thing:
##   - a landscape got ONE row, so the second and third RUN of a type — which the
##     world lays routinely, and which sentinels, depots and interference all key
##     on separately — could not be reached by any name at all.
##   - a BORDER could be reached by typing "coast-slums" into a tool and by no
##     other door, and the border is where the ground, the blend and the score
##     are hardest and where most of what breaks, breaks.
##   - a depot, a lair and a shaft are the three things the plan puts on the land,
##     and none of them had a row.
##
## It is built in ONE sweep of the island, because the page is opened in a running
## game. Asking `GenPlaces.find` per row measured 2645 ms on a 512-tile world —
## nine whole-world sweeps for the landscapes, forty-five more for the landmark
## kinds, and `solid_mask` rebuilt inside every one of them. That freeze was there
## before this list grew; a menu for inspecting the world cannot stop the world to
## draw itself. A row whose exact spot still costs a sweep (the river, the cliff)
## is handed back with `later` set and `pos` INF, for the page to settle a frame
## after it is on the glass.
static func places(game: Game) -> Array[Dictionary]:
	var w := game.world
	var survey := _survey(w)
	var out: Array[Dictionary] = [{"id": &"spawn", "label": "the strand", "pos": w.spawn, "note": "where a new game wakes"}]
	out.append_array(_lands(w, survey))
	out.append_array(_borders(survey))
	for i in w.villages.size():
		var v: Dictionary = w.villages[i]
		var vp: Vector2 = (v.pos as Vector2) + Vector2(3, 3)
		out.append({"id": StringName("village_%d" % i), "label": "village %d" % i, "pos": vp,
			"note": "in %s" % BiomeRegistry.at(w, vp).display_name.to_lower()})
	for pair: Array in [["river", "the river"], ["cliff", "the cliff"]]:
		out.append({"id": StringName(pair[0]), "label": pair[1], "pos": Vector2.INF, "note": "", "later": pair[0]})
	out.append_array(_plan(w))
	out.append_array(_marks(w, survey))
	return out


## Settle one row `places` handed back unresolved: the answer costs a sweep, so it
## is taken a frame after the list is up rather than before it appears. Returns
## the position, or INF where this world has no such place (the row is dropped).
static func settle(w: WorldData, name: String) -> Vector2:
	var p := GenPlaces.find(w, name)
	return p if p.x >= 0.0 else Vector2.INF


## One pass over the island for everything a warp row needs to know about the
## ground: the most characteristic standing tile of each LANDSCAPE, the same for
## each REGION, and the most evenly mixed tile of each BORDER.
##
## The landscape half is `GenPlaces.country_sample` exactly — same range, stride,
## guard, score and tie-break — so the row and the tools' own `--place=coast`
## land on the same tile. Doing it once for every landscape at once is the whole
## saving: the score is 32 lookups a cell and the cell walk is what costs, not
## the landscape being asked about.
static func _survey(w: WorldData) -> Dictionary:
	const RINGS: Array[int] = [6, 12, 20, 30]
	const WAYS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	var solid := GenPlaces.solid_mask(w)
	var land := {}
	var region := {}
	var border := {}
	for y in range(6, w.size - 6, 4):
		for x in range(6, w.size - 6, 4):
			var i := y * w.size + x
			var c1: int = w.country[i]
			var c2: int = w.country2[i]
			var blend: float = w.blend[i]
			# country2 carries the tile's OWN type where no second one meets it
			# (GenCountries), so equal is how "no border here" reads in a byte.
			if c1 != c2 and blend >= 0.35 and not Ground.is_water(w.ground[i]):
				var key := mini(c1, c2) * BiomeRegistry.SLOTS + maxi(c1, c2)
				# The most even tile of a border reads as both landscapes at once.
				var even := 0.5 - absf(blend - 0.5)
				if even > float(border.get(key, {}).get("even", -1.0)):
					border[key] = {"even": even, "pos": Vector2(x + 0.5, y + 0.5)}
			if blend > 0.0 or not GenPlaces.standable(w, solid, x, y):
				continue
			var score := 0.0
			for r: int in RINGS:
				for d: Vector2i in WAYS:
					if w.country_at(x + d.x * r, y + d.y * r) == c1:
						score += 1.0
			score += Rng.hash01(w.seed_value, x, y, 7) * 0.5
			var here := Vector2(x + 0.5, y + 0.5)
			if score > float(land.get(c1, {}).get("score", -1.0)):
				land[c1] = {"score": score, "pos": here}
			var rid := w.region_at(x, y)
			if rid >= 0 and score > float(region.get(rid, {}).get("score", -1.0)):
				region[rid] = {"score": score, "pos": here}
	return {"land": land, "region": region, "border": border}


## Every region of every landscape. ONE run of each type keeps the plain name and
## the tile the tools' own `--place=<land>` resolves to — the run that tile stands
## in, which is not always the biggest — and the others are numbered by size.
##
## A type's runs are kept TOGETHER: `WorldData.regions` is sorted biggest-first
## across the whole world, so listed as they come, "salt flats 2" lands six rows
## below "salt flats" among other landscapes entirely.
static func _lands(w: WorldData, survey: Dictionary) -> Array[Dictionary]:
	var land: Dictionary = survey.land
	var region: Dictionary = survey.region
	var order: Array[StringName] = []
	var runs := {}
	for r: Dictionary in w.regions:
		var id := StringName(str(r.get("type", &"")))
		if BiomeRegistry.get_def(id) == null:
			continue
		if not runs.has(id):
			runs[id] = []
			order.append(id)
		(runs[id] as Array).append(r)
	var out: Array[Dictionary] = []
	var listed := {}
	for id: StringName in order:
		var name := BiomeRegistry.get_def(id).display_name.to_lower()
		var ci := BiomeRegistry.index_of(id)
		listed[ci] = true
		var head: Vector2 = land.get(ci, {}).get("pos", Vector2.INF)
		var plain := -1
		if head.is_finite():
			plain = w.region_at(floori(head.x), floori(head.y))
		var mine: Array = runs[id]
		var has_plain := false
		for r: Dictionary in mine:
			if int(r.get("id", -2)) == plain:
				has_plain = true
		if not has_plain:
			# The characteristic tile fell in a run too small to be a region (or
			# this landscape has none): the biggest run takes the plain name, and
			# its own best tile with it.
			plain = int((mine[0] as Dictionary).get("id", -1))
			head = region.get(plain, {}).get("pos", (mine[0] as Dictionary).get("centre", Vector2.ZERO))
		var rank := 0
		for r: Dictionary in mine:
			rank += 1
			var rid := int(r.get("id", -1))
			var tiles := int(r.get("tiles", 0))
			if rid == plain:
				out.append({"id": StringName("land_" + String(id)), "label": name, "pos": head,
					"note": "deep in the landscape, which covers %d tiles here" % tiles})
				continue
			out.append({"id": StringName("region_%d" % rid), "label": "%s %d" % [name, rank],
				"pos": region.get(rid, {}).get("pos", r.get("centre", Vector2.ZERO)) as Vector2,
				"note": "the %s run of this landscape, covering %d tiles" % [_ordinal(rank), tiles]})
	# A landscape whose every run is under GenCountries.REGION_TILES belongs to no
	# region at all, and had a row before regions were listed. It keeps one.
	for ci: int in land:
		if listed.has(ci):
			continue
		var b := BiomeRegistry.by_index(ci)
		if b == null:
			continue
		out.append({"id": StringName("land_" + String(b.id)), "label": b.display_name.to_lower(),
			"pos": land[ci].pos as Vector2, "note": "a run too small to be a region of its own"})
	return out


## Every pair of landscapes this world actually puts against each other.
static func _borders(survey: Dictionary) -> Array[Dictionary]:
	var best: Dictionary = survey.border
	var out: Array[Dictionary] = []
	var keys: Array = best.keys()
	keys.sort()
	for key: int in keys:
		var a := BiomeRegistry.by_index(key / BiomeRegistry.SLOTS)
		var b := BiomeRegistry.by_index(key % BiomeRegistry.SLOTS)
		if a == null or b == null:
			continue
		out.append({"id": StringName("border_%d" % key), "label": "%s / %s" % [a.display_name.to_lower(), b.display_name.to_lower()],
			"pos": best[key].pos as Vector2, "note": "where the two are most evenly mixed"})
	return out


## The first of each kind of landmark the survey left, read off the world's own
## list rather than asked for by name: `GenPlaces.find` would rebuild the solid
## mask once per kind, and there are forty-five kinds.
##
## It keeps GenPlaces' rule that a kind's NAME goes to an instance in the open
## where there is one, because a depot goes up at the busiest marked landmark of
## its region and the name would otherwise be a lie about the picture.
static func _marks(w: WorldData, _survey: Dictionary) -> Array[Dictionary]:
	var yards: Array[Vector2] = []
	for s in Works.sites(w):
		yards.append(s.pos)
	var first := {}
	var order: Array[String] = []
	for m: Dictionary in w.landmarks:
		var k := String(m.kind)
		var p: Vector2 = m.pos
		var shut := false
		for y in yards:
			if y.distance_to(p) < Works.YARD:
				shut = true
				break
		if not first.has(k):
			first[k] = {"pos": p, "open": not shut}
			order.append(k)
		elif shut == false and not bool((first[k] as Dictionary).open):
			first[k] = {"pos": p, "open": true}
	var out: Array[Dictionary] = []
	for k: String in order:
		out.append({"id": StringName("mark_" + k), "label": k.replace("_", " "), "pos": first[k].pos as Vector2,
			"note": "the first of its kind" if bool(first[k].open) else "the first of its kind, under a depot's yard"})
	return out


## What the plan put on the land: a depot per region it is working, the keeper of
## each region that has one, and the shafts to the realm below.
static func _plan(w: WorldData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in Works.sites(w):
		out.append({"id": StringName("works_%d" % s.region), "label": "depot in %s" % _land_name(s.land),
			"pos": s.pos, "note": "the yard the region's machines come out of"})
	for s in Sentinels.states(w):
		out.append({"id": StringName("lair_%d" % s.region), "label": "keeper of %s" % _land_name(s.land),
			"pos": s.lair, "note": "where %s stands" % String(s.design).replace("_", " ")})
	for p in Portals.in_world(w):
		out.append({"id": StringName("shaft_%d" % p.id), "label": "shaft %d" % p.id,
			"pos": p.pos, "note": "down into the %s" % String(p.to_realm)})
	return out


## A place typed by hand: "342, 362" (or "342.5 362.5"), or any name GenPlaces
## answers to — which is every name the tools' --place= and a tour's `place` take,
## so what can be staged for a picture can be walked to in a running game by the
## same word. Vector2.INF when the world has no such place.
##
## The coordinate is tried FIRST and only accepts two numbers, so a landmark kind
## that ends in digits ("wreck2") still reaches GenPlaces.
static func find_place(w: WorldData, text: String) -> Vector2:
	var t := text.strip_edges().to_lower()
	if t == "":
		return Vector2.INF
	var parts := t.replace(",", " ").split(" ", false)
	if parts.size() == 2 and parts[0].is_valid_float() and parts[1].is_valid_float():
		var p := Vector2(parts[0].to_float(), parts[1].to_float())
		if p.x < 0.0 or p.y < 0.0 or p.x >= w.size or p.y >= w.size:
			return Vector2.INF
		return p
	var at := GenPlaces.find(w, t)
	return at if at.x >= 0.0 else Vector2.INF


static func _land_name(id: StringName) -> String:
	var b := BiomeRegistry.get_def(id)
	return b.display_name.to_lower() if b != null else String(id)


static func _ordinal(n: int) -> String:
	const WORDS := ["", "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth"]
	return WORDS[n] if n < WORDS.size() else "%dth" % n


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
