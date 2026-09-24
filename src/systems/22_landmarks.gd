extends GameSystem
## The places worth the walk, in the running game (docs/VISION.md, §8).
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
## How near the mass of a landmark a body has to be to count as standing against
## it (a body's own radius, and a little for the slide along the face).
const WALL_TOUCH := 0.55

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
## Whether `use` was down last frame. The edge is worked out here rather than
## asked of `Input.is_action_just_pressed`, which is true only for the frame the
## press was RECORDED in: a system that runs early in the frame order (this one
## sorts before the tour that drives the key, and before the player) sees the
## press one frame late and reads it as already held. It cost a whole tour, and
## it would have cost a player every press that landed on the wrong half of a
## frame.
var _use_was := false


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
		_make(s)
	_set_walls()


## The mass of every landmark in this world, handed to the one thing that stops a
## body (`WorldQuery.set_blocks`). Derived like the siting itself, so it is never
## saved and never drifts, and replaced whole on a realm crossing.
##
## It is set for the WHOLE island and not only for what is drawn: a machine
## chasing the player round the far side of a tower is stopped by the tower
## whether or not the camera is looking at it, and a wall that came and went with
## the draw distance would let a body walk through what it had just walked round.
func _set_walls() -> void:
	if game.query == null:
		return
	var walls: Array[Vector3] = []
	for s in sites:
		for c: Vector3 in LandmarkModels.blocks(s.kind):
			var at := s.pos + Vector2(c.x, c.y).rotated(s.facing)
			walls.append(Vector3(at.x, at.y, c.z))
	game.query.set_blocks(&"landmarks", walls)


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
	if reachable != null and _settle <= 0.0 and _use_pressed() and _cache_wins():
		_open(reachable)


# --- drawing -------------------------------------------------------------------

## SHOWN by distance, never built by it: every model is made with the world
## (`_read_sites`). It used to be made on coming into reach and freed on leaving,
## and the reach is the whole island the moment the camera sees the horizon, so
## the first look over the shoulder built all two hundred in one frame (569 ms
## on seed 7, tests/landmarks/test_built_at_load.gd) and every walk past one
## built it twice. A site never moves and its model is a function of the site.
func _draw() -> void:
	var at := sim.hero.pos
	var reach := _draw_reach()
	for s in sites:
		var node: Node3D = _nodes.get(s.id, null)
		if node == null:
			continue
		var near := s.pos.distance_to(at) <= reach
		if node.visible != near:
			node.visible = near
	_stand()


## Made once per site when the world is made, hidden until `_draw` shows it.
## Costs the load about 2 ms a landmark (200 on seed 7 at 1024: 380 ms at load
## 36-55), which the first look up at the horizon used to pay in one frame.
func _make(s: LandmarkSite) -> void:
	var mat := game.view.world_material() if game.view != null else null
	var node := LandmarkModels.node(s.kind, maxi(0, s.region) * 29 + s.nth * 5, mat)
	node.rotation.y = -s.facing
	node.visible = false
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
		var reach := Landmarks.cache_of(s).distance_to(at)
		if reach <= Landmarks.OPEN_REACH and reach < best and not state.is_opened(s.id):
			best = reach
			reachable = s
		# Up against its mass and not inside it: the body walked in and was
		# STOPPED. Recorded rather than asked, because it is something that
		# HAPPENED — a tour awaits it, and a frame taken after does not have to
		# still be pressed against the wall to be a picture of being stopped by it.
		for c: Vector3 in LandmarkModels.blocks(s.kind):
			var wall := s.pos + Vector2(c.x, c.y).rotated(s.facing)
			var against := wall.distance_to(at)
			if against >= c.z - 0.05 and against <= c.z + WALL_TOUCH:
				_seen[&"landmark_wall"] = true


## `use` is one key and a cache is one more thing it can mean. A shaft takes the
## key by being NEARER than what is under the hand (20_realms), and that rule is
## wrong here: a cache is opened exactly once in a whole game, and a bush growing
## half a tile nearer than it was enough to send the key to the bush — every
## time, for good, because the player has no way to see which of the two won.
##
## So a cache that has never been opened takes the key whenever it is in reach.
## Nothing is lost by it: the instant it is open it stops being reachable, and
## the bush is under the hand again on the next press.
func _cache_wins() -> bool:
	return true


## The press, on its rising edge, whoever else is polling the same key.
func _use_pressed() -> bool:
	var down := Input.is_action_pressed(&"use") and not game.input_blocked()
	var edge := down and not _use_was
	_use_was = down
	return edge


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
##   landmark_wall       a landmark's own mass stopped the body walking into it
##   landmark_found      one has been found: it is on the player's map
##   landmark_opened     one has been opened, and its cache is spent
##   landmark_guard      what was left on watch at one has come
##   found:ID            that site (lighthouse#1) is on the player's map
##
## Finding and opening are both SAVED, so both can be asked of the world rather
## than remembered here — which is what `found:ID` always did, one site at a
## time. As latches they read true for the rest of the run after the first site,
## so a tour that walked to a second landmark and awaited `landmark_opened`
## proved only that it had opened the first one.
func tour_seen(what: String) -> bool:
	if _seen.has(StringName(what)):
		return true
	match what:
		"landmark":
			for s in sites:
				if _in_frame(s):
					return true
			return false
		"landmark_cache":
			return reachable != null
		"landmark_found":
			for s in sites:
				if state.is_found(s.id):
					return true
			return false
		"landmark_opened":
			for s in sites:
				if state.is_opened(s.id):
					return true
			return false
		"landmark_near":
			for s in sites:
				if s.pos.distance_to(sim.hero.pos) <= Landmarks.FOUND_AT:
					return true
			return false
	if what.begins_with("landmark:"):
		var want := StringName(what.substr(9))
		for s in sites:
			if s.kind == want and _in_frame(s):
				return true
		return false
	if what.begins_with("found:"):
		return state.is_found(StringName(what.substr(6)))
	return false


## An await is spent by the tour that asked it (98_tour `_forget`).
func tour_forget(what: StringName) -> void:
	_seen.erase(what)


## IS IT REALLY IN THE PICTURE? A frame that claims a silhouette has to hold it,
## and the first version of `landmark:KIND` answered "there is one of those
## within sixty tiles" — which is how every far frame in tours/landmarks.tour
## passed while being shot at twice the play camera's zoom with the tower out of
## shot at play zoom.
##
## So this asks the LIVE camera. Across the screen there is no height to spend;
## up the screen the base has to be in frame; down the screen the head carries
## it, which is the whole rule `Landmarks.read_reach` is written from.
func _in_frame(s: LandmarkSite) -> bool:
	if not _nodes.has(s.id) or game.camera == null:
		return false
	# ASKED OF THE CAMERA, never derived. This was a half-extent off `cam.size`, a
	# spelled 16:9 and `pitch_deg` -- three orthographic numbers, and under the
	# lens all three keep answering for a camera that is not drawing (`size` is
	# ignored by a perspective projection and `_apply_lens` writes neither it nor
	# `pitch_deg`). The rule it was built on is unchanged and is still the point:
	# up the screen the BASE has to be in frame, down the screen the HEAD carries
	# it, so both are asked for and either one being on the glass is enough.
	var cam := game.camera
	var node := _nodes[s.id] as Node3D
	if node == null or not node.visible or not cam.is_inside_tree():
		return false
	var foot := node.global_position
	var head := foot + Vector3(0.0, LandmarkModels.high_of(s.kind), 0.0)
	if (cam.global_transform.affine_inverse() * foot).z > -0.5:
		return false
	var rect: Vector2 = cam.get_viewport().get_visible_rect().size
	var a := cam.unproject_position(foot)
	var b := cam.unproject_position(head)
	if minf(a.x, b.x) > rect.x or maxf(a.x, b.x) < 0.0:
		return false
	return minf(a.y, b.y) <= rect.y and maxf(a.y, b.y) >= 0.0


## The sites, for a test, for dev mode and for whoever wants the list.
func all() -> Array[LandmarkSite]:
	return sites


## WHAT A PLACE READS AS when the player puts the slate on it (42_target). The
## order a landmark is experienced in is a shape, then a name, then hands on it —
## so the slate only has something to say about one the player has already FOUND.
## Reading an unfound silhouette off the horizon would hand over the whole of the
## walk that the place exists to be worth.
func target_rows(from: Vector2, reach: float) -> Array:
	var out: Array = []
	for s in sites:
		if s.pos.distance_to(from) > reach or not state.is_found(s.id):
			continue
		var def := s.def()
		if def == null:
			continue
		var opened := state.is_opened(s.id)
		var stats: Array = [
			["land", String(s.land).replace("_", " ")],
			["cache", "emptied" if opened else "not opened"],
		]
		if def.guarded:
			stats.append(["watch", "something of the plan is still on it"])
		out.append({
			"id": hash(s.id) & 0xFFFF,
			"kind": s.kind,
			"name": def.display_name.capitalize(),
			"pos": s.pos,
			"height": LandmarkModels.high_of(s.kind),
			"radius": 1.8,
			"role": "a place worth the walk",
			"machine": false,
			"notices": "it has stood here a long time",
			"stats": stats,
			"thinking": def.near,
		})
	return out


## How far off one is drawn: DRAW, or as far as the eye sees while the camera can
## see the horizon (SkyLight.sees_horizon). From above nothing past DRAW is in the
## frame; at eye level a thing that appears sixty tiles out is the one thing on
## the skyline that moved, and the whole point of it is being seen from afar.
func _draw_reach() -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return SkyLight.SEE if SkyLight.sees_horizon(cam) else DRAW
