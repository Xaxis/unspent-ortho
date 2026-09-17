extends GameSystem
## The places worth the walk, in the running game (docs/VISION.md §3, §8).
## Reachable as the system named `22_landmarks`.
##
## The machines' depots are why a landscape is dangerous (34_works); these are
## why it is worth being in anyway. This system does four things:
##   1. works out where every landmark stands (`Landmarks.sites`, pure) and puts
##      each in `WorldData.landmarks`, so the map draws it, the reads app names
##      it and a tour walks to it by name (`place lighthouse`) rather than by a
##      coordinate the next change to worldgen quietly invalidates;
##   2. draws one when the player is near enough to see it, and takes it off
##      again when they are not — at a distance that lets it be READ before it
##      can be reached, because that is the whole of what a landmark is for;
##   3. FINDS it: come within `Landmarks.FOUND_AT` and it is on the map for the
##      rest of the game, whether or not it is ever opened, and the slate says
##      what it is in a line about the place and never about the reward;
##   4. OPENS it: one cache, one roll off the one economy (`src/core/loot`),
##      deterministic per seed and site, taken once and for good — and at some of
##      them, something of the plan is still here and comes when it is touched.

## Tiles from the player a landmark is drawn at. Well past the furthest a kind
## claims to be readable from, so nothing ever pops in while being looked at.
const DRAW := 62.0
## How often the landmarks near the player are looked at (seconds).
const LOOK_EVERY := 0.25
## Seconds after arriving in a game before `use` can open anything, so the key
## that loaded a save cannot also empty the cache the player is standing on.
const SETTLE := 0.4

var sites: Array[LandmarkSite] = []
var state := LandmarkState.new()
var sim: FightSim
## The landmark whose cache is within reach of the player, or null.
var reachable: LandmarkSite = null
var _layer: Node3D
var _nodes: Dictionary = {}
var _stood: Dictionary = {}
var _look := 0.0
var _settle := SETTLE
## Site id -> true, once its far line has been said.
var _sighted: Dictionary = {}
var _seen: Dictionary = {}


func setup(g: Game) -> void:
	super.setup(g)
	Landmarks.declare_loot()
	_layer = Node3D.new()
	_layer.name = "landmarks"
	g.add_child(_layer)
	_read_sites()
	SaveGame.register(&"landmarks", _save, _load)


## The landmarks of the world the game is in now. Called again on a realm
## crossing: another realm's island has its own places worth the walk.
func _read_sites() -> void:
	sites = Landmarks.sites(game.world)
	for c: Variant in _nodes.values():
		(c as Node3D).queue_free()
	_nodes.clear()
	_stood.clear()
	_sighted.clear()
	reachable = null
	for s in sites:
		_as_landmark(s)


func realm_changed(_from: StringName, _to: StringName) -> void:
	_read_sites()


## In the world's own list of places, under the kind's own name, so the map, the
## reads app and `place NAME` all find it without being taught what a landmark
## is. No `mark`: a mark means the machines cut the ground here, and half of
## these were standing long before they did.
##
## Recorded at its CACHE and not at its own middle, two tiles in front of it:
## `place lighthouse` means "take me to the lighthouse", and arriving inside the
## tower with the cache behind you is not that. On a map the difference is a
## pixel; on arrival it is the difference between a place and a wall.
func _as_landmark(s: LandmarkSite) -> void:
	var at := Landmarks.cache_of(s)
	for m: Dictionary in game.world.landmarks:
		if m.get("kind") == s.kind and (m.get("pos") as Vector2).distance_to(at) < 0.5:
			return
	game.world.landmarks.append({"kind": s.kind, "pos": at,
		"country": game.world.country_at(floori(at.x), floori(at.y)),
		"dir": Vector2.from_angle(s.facing)})


## The simulation is made by 30_mobs, which sorts AFTER this system, so it cannot
## be taken in setup: a landmark package that read `player.sim` there held null
## for the whole game and drew nothing, on every seed, silently.
func _process(delta: float) -> void:
	if game == null or game.world == null:
		return
	if sim == null:
		sim = game.player.sim
		if sim == null:
			return
	_settle = maxf(0.0, _settle - delta)
	_look -= delta
	if _look <= 0.0:
		_look = LOOK_EVERY
		_draw()
		_watch()
	if reachable != null and _settle <= 0.0 and not game.input_blocked() \
			and Input.is_action_just_pressed(&"use") and _cache_wins():
		_open(reachable)


# --- drawing -------------------------------------------------------------------

func _draw() -> void:
	var at := sim.hero.pos
	for s in sites:
		var near := s.pos.distance_to(at) <= DRAW
		if near and not _nodes.has(s.id):
			_make(s)
		elif not near and _nodes.has(s.id):
			(_nodes[s.id] as Node3D).queue_free()
			_nodes.erase(s.id)
			_stood.erase(s.id)
	_stand()


func _make(s: LandmarkSite) -> void:
	var mat := game.view.world_material() if game.view != null else null
	var node := LandmarkModels.node(s.kind, maxi(0, s.region) * 29 + s.nth * 5, mat)
	node.rotation.y = -s.facing
	_layer.add_child(node)
	_nodes[s.id] = node
	if state.is_opened(s.id):
		LandmarkModels.set_opened(node, true)


## Put each landmark on the DRAWN ground once its chunk exists. A tower standing
## a finger above the rock is the thing a player notices first.
func _stand() -> void:
	if game.view == null:
		return
	for s in sites:
		if not _nodes.has(s.id) or bool(_stood.get(s.id, false)):
			continue
		if game.view.chunk_at(s.pos) == null:
			continue
		(_nodes[s.id] as Node3D).position = Vector3(s.pos.x, game.view.surface_height(s.pos), s.pos.y)
		_stood[s.id] = true


# --- finding one ---------------------------------------------------------------

## What is in sight, what is in reach, and what has just been found. A landmark
## is SEEN first — its own line, at its own distance, about the place — and
## FOUND when the player is close enough to be sure of it.
func _watch() -> void:
	var at := sim.hero.pos
	reachable = null
	var best := INF
	for s in sites:
		var d := s.pos.distance_to(at)
		var def := s.def()
		if def == null:
			continue
		if d <= def.sees and not _sighted.has(s.id) and not state.is_found(s.id):
			_sighted[s.id] = true
			Events.hint.emit(def.far, "")
		if d <= Landmarks.FOUND_AT and state.find(s.id):
			Events.message.emit("%s. %s" % [def.display_name.capitalize(), def.near])
			Events.sfx.emit(&"landmark_found", game.world.to_3d(s.pos))
			Events.landmark_found.emit(s.id, s.land, s.pos)
			_seen[&"landmark_found"] = true
		var reach := Landmarks.cache_of(s).distance_to(at)
		if reach <= Landmarks.OPEN_REACH and reach < best and not state.is_opened(s.id):
			best = reach
			reachable = s


## `use` is one key and a cache is one more thing it can mean, so it takes the
## key only when it is nearer than whatever else is under the hand.
func _cache_wins() -> bool:
	var t := Survival.use_target(game)
	if t == null:
		return true
	return Landmarks.cache_of(reachable).distance_to(sim.hero.pos) <= t.pos.distance_to(sim.hero.pos)


## Open it: one roll, once and for good. What comes out is the one economy's, and
## an item the economy has declared but nobody has written a row for yet is
## skipped rather than forced into the bag (the gear package owns items.gd).
func _open(s: LandmarkSite) -> void:
	if not state.open(s.id):
		return
	LandmarkModels.set_opened(_nodes.get(s.id, null), true)
	Events.sfx.emit(&"landmark_open", game.world.to_3d(Landmarks.cache_of(s)))
	var got: Array[String] = []
	for row: Dictionary in Landmarks.loot(s, game.world.seed_value):
		var id: StringName = row.get("item", &"")
		var n := int(row.get("count", 1))
		if id == &"" or n <= 0 or Items.def(id).is_empty():
			continue
		game.inventory.add(id, n)
		Events.took.emit(id, n)
		got.append(Items.display_name(id) if n <= 1 else "%s x%d" % [Items.display_name(id), n])
	_seen[&"landmark_opened"] = true
	Events.message.emit("Nothing in it but the lining." if got.is_empty() else ", ".join(got) + ".")
	var def := s.def()
	if def != null and def.guarded:
		_guard(s)


## Something of the plan was still here. It comes out behind the player, because
## a cache opened with a machine already in the frame is a fight the player chose
## and this one is not — and the network is told, because opening a locker the
## machines left is taking from them.
func _guard(s: LandmarkSite) -> void:
	_file(&"theft", Landmarks.cache_of(s))
	var kind := _guard_kind(s)
	if kind == &"" or sim.living() >= Spawner.MAX_LIVING:
		return
	var away := (sim.hero.pos - s.pos).normalized()
	if away.length_squared() < 0.01:
		away = Vector2.RIGHT
	for i in 8:
		var a := away.angle() + (i - 4) * 0.5
		var at := s.pos + Vector2.from_angle(a) * Landmarks.GUARD_RING
		if not game.query.standable(floori(at.x), floori(at.y)):
			continue
		var m := sim.add_mob(kind, at)
		m.last_seen = sim.hero.pos
		m.suspicion = 1.0
		sim.disturb(m, &"theft")
		_seen[&"landmark_guard"] = true
		Events.sfx.emit(&"alert", game.world.to_3d(at))
		return


## What the plan left on watch here: a keeper of this landscape if it has one,
## else any machine on its roster. Never a hunter picked out of the whole game —
## what comes is what belongs to this land.
func _guard_kind(s: LandmarkSite) -> StringName:
	var def := BiomeRegistry.get_def(s.land)
	if def == null:
		return &""
	var fallback: StringName = &""
	for kind: StringName in def.roster:
		var row := Roster.row(kind)
		if not row.get("machine", false) or Roster.sentinel_of(kind) != &"":
			continue
		if Roles.of(kind) == Roles.KEEPER or Roles.of(kind) == Roles.WATCHER:
			return kind
		if fallback == &"":
			fallback = kind
	return fallback


func _file(cause: StringName, at: Vector2) -> void:
	for sys in game.systems:
		if sys.name == "32_disposition" and sys.has_method(&"raise"):
			@warning_ignore("return_value_discarded")
			sys.call(&"raise", cause, at)
			return


# --- saving -------------------------------------------------------------------

func _save() -> Variant:
	return state.save()


func _load(v: Variant) -> void:
	if v is Dictionary:
		state.load_from(v)
	for s in sites:
		if _nodes.has(s.id):
			LandmarkModels.set_opened(_nodes[s.id], state.is_opened(s.id))


# --- what a tour may await ----------------------------------------------------

## Answers a tour's `await WHAT` and a frame's `with WHAT`:
##   landmark            one is drawn near enough to be in frame
##   landmark:KIND       that kind is
##   landmark_near       the player is inside the distance one is found at
##   landmark_cache      a cache is in reach of the player
##   landmark_found      one has been found since the last action
##   landmark_opened     one has been opened since the last action
##   landmark_guard      what was left on watch at one has come
##   found:ID            that site (lighthouse#1) is on the player's map
func tour_seen(what: String) -> bool:
	if _seen.has(StringName(what)):
		return true
	match what:
		"landmark":
			return not _nodes.is_empty()
		"landmark_cache":
			return reachable != null
		"landmark_near":
			for s in sites:
				if s.pos.distance_to(sim.hero.pos) <= Landmarks.FOUND_AT:
					return true
			return false
	if what.begins_with("landmark:"):
		var want := StringName(what.substr(9))
		for s in sites:
			if s.kind == want and _nodes.has(s.id):
				return true
		return false
	if what.begins_with("found:"):
		return state.is_found(StringName(what.substr(6)))
	return false


## The sites, for a test, for dev mode and for whoever wants the list.
func all() -> Array[LandmarkSite]:
	return sites
