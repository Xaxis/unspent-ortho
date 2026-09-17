extends GameSystem
## The realms of one game, and the crossing between them (docs/VISION.md §4, §7.1).
##
## A game holds ONE active realm. Its world, its view and the body in it are the
## game's own fields, so a crossing does not make a new game: it points the game
## at another world. That is the whole reason the crossing is done here and not by
## opening a new scene — the score, the sound, the clock, the body, what is
## carried and what the plan has on file all live in this game, and a portal that
## took the game down would take them with it. The score then handles a crossing
## with the machinery it already has for a player moving faster than the bake
## (75_music: readiness caps the crossfade, so the landscape that was playing
## holds until the cave's own stems arrive, and nothing falls silent).
##
## What a crossing does, in order:
##   the far world       RealmWorlds, raised while the player was still walking
##                       toward the shaft, so pressing `use` costs no frames
##   the world           game.world and game.query: every system that reads them
##                       live is in the new realm from the next frame
##   the body            Player and its FightSim are pointed at the new world and
##                       put down beside the paired shaft; nothing follows anybody
##                       down a shaft, so every body near the player is retired
##   the view            WorldView.rebind — chunks and props dropped and grown
##                       again, MATERIALS kept, because the player's figure, the
##                       crowns and the swing arc were handed them at the start
##   everyone else       every system with `realm_changed(from, to)` is told
##
## Saved under key `realms`: which realm the game is in, where the player stood in
## each one, and every realm's own world edits (what was taken out of a cave stays
## taken). A save made in another realm crosses in `started()`, which is why this
## system sorts before every system that reads the world.
##
## Answers a tour: `portal`, `portal:N` (that shaft is in reach), `realm:KIND`,
## `crossed` (the player has come through a shaft at least once).

## Tiles from a shaft at which the realm behind it starts being raised. A run at
## Tuning.RUN_SPEED covers it in about nine seconds; a world takes about one.
const WARM := 44.0
## How often the shafts near the player are looked at (seconds).
const LOOK_EVERY := 0.2
## Seconds after arriving in which `use` does nothing, so the key that brought a
## player through a shaft cannot also take them straight back out of it — and,
## through `use_spent()`, cannot be answered a second time by anything else.
const SETTLE := 0.6

## This game's shafts, in the realm it is in now.
var here: Array[Portal] = []
## The shaft within reach of the player, or null.
var reachable: Portal = null
## How many times the player has crossed.
var crossings := 0

## How many realm systems are alive. The last one out lets go of the worlds: a
## game handing over to a loaded one has both alive at once, and forgetting on the
## way out of the first would throw away the second's.
static var _live := 0

var _realm: StringName = Realm.SURFACE
## The realm a loaded save says the game is in, or &"" (nothing was loaded).
var _saved_realm: StringName = &""
var _look := 0.0
var _settle := 0.0
var _gates: Node3D
## Gate nodes by shaft id, and whether each is standing on the drawn ground yet.
var _nodes: Dictionary = {}
var _placed: Dictionary = {}
## Realm id (String) -> where the player stood in it, so coming back is coming
## back to where they were and not to the shaft they arrived by.
var _stood: Dictionary = {}
## Realm id (String) -> that realm's world edits (WorldData.depleted).
var _edits: Dictionary = {}
## Told once per shaft, the first time the player is in reach of it.
var _taught: Dictionary = {}


func setup(g: Game) -> void:
	super.setup(g)
	_live += 1
	_realm = g.world.realm
	RealmWorlds.keep(g.world)
	_gates = Node3D.new()
	_gates.name = "gates"
	g.add_child(_gates)
	_read_portals()
	SaveGame.register(&"realms", _save, _load)


func started() -> void:
	if _saved_realm == &"":
		# --realm=KIND: a shot or a tour that wants to open in another realm, with
		# --at read as a tile of THAT realm's world.
		var want := game.options.realm
		if want != _realm and Realm.KINDS.has(want):
			_go(want, game.options.at if game.options.at.x >= 0.0 else Vector2.ZERO, 0, true)
		return
	# A save carries a seed and a size, and SaveSlots knows nothing of realms, so
	# the world this game opened in is always the surface's. Everything the save
	# says each realm carries goes back on here, and the crossing happens before
	# the first frame is drawn.
	if _edits.has(String(_realm)):
		game.world.depleted = (_edits[String(_realm)] as Dictionary).duplicate()
	if _saved_realm != _realm:
		_go(_saved_realm, _stood.get(String(_saved_realm), Vector2.ZERO), -1, false)
	_saved_realm = &""


func _exit_tree() -> void:
	_live = maxi(0, _live - 1)
	if _live == 0:
		# Two 512-tile worlds are a dozen megabytes, and the next game's realms
		# are not these ones.
		RealmWorlds.forget()


func _process(delta: float) -> void:
	if game == null or game.world == null or game.player == null:
		return
	_settle = maxf(0.0, _settle - delta)
	# How far this place is from the sky, which is the one thing about a realm's
	# LIGHT that no landscape file can say (SkyLight.closed, and its header for
	# why): night everywhere under a roof, whatever the clock reads, so the floor,
	# the hatch, the ink and the lamp's pool all come on down there.
	if game.sky != null:
		game.sky.closed = 1.0 if Realm.roofed(_realm) else 0.0
	_stand_gates()
	_look -= delta
	if _look <= 0.0:
		_look = LOOK_EVERY
		_watch()
	if reachable != null and _settle <= 0.0 and not game.input_blocked() \
			and Input.is_action_just_pressed(&"use") and _shaft_wins():
		cross(reachable)


## `use` is one key and a shaft is one more thing it can mean, so it takes the
## key only when it is NEARER than whatever is under the hand. Standing over a
## mouth with a seam beside it, a player means the mouth; standing at a seam with
## a mouth two tiles off, they mean the seam.
func _shaft_wins() -> bool:
	var t := Survival.use_target(game)
	if t == null:
		return true
	return reachable.pos.distance_to(game.player.pos) <= t.pos.distance_to(game.player.pos)


## THE PRESS THAT CROSSED IS SPENT. A crossing MOVES the player, so the same
## press that took them down the ladder was then answered again where they
## landed: `tours/realms.tour` came up underground with a clerk's screen already
## open over the cave, which held every key and the lamp never lit. Any system
## that reads `use` after this one asks here first, the way a place answers
## targeting with `target_rows`.
func use_spent() -> bool:
	return _settle > 0.0


## Which shaft is near, which is worth raising a world for, and what to say.
func _watch() -> void:
	var at: Vector2 = game.player.pos
	var near := Portals.nearest(game.world, at)
	reachable = null
	if near == null:
		return
	var d := near.pos.distance_to(at)
	if d <= WARM:
		RealmWorlds.begin(game.options.seed_value, game.world.size, near.to_realm)
	if d <= Portal.REACH and near.open:
		reachable = near
		if not _taught.has(near.id):
			_taught[near.id] = true
			Events.hint.emit("A shaft, and a ladder still in it. E to go down.", "use")


## Put each gate on the drawn ground once the chunk under it exists: the mesher's
## surface and the tile's own level are not the same number on a terrace lip, and
## a gate standing a finger above the rock is the thing a player notices first.
func _stand_gates() -> void:
	if game.view == null:
		return
	for id: int in _nodes:
		if bool(_placed.get(id, false)):
			continue
		var p := _by_id(id)
		if p == null or game.view.chunk_at(p.pos) == null:
			continue
		(_nodes[id] as Node3D).position = Vector3(p.pos.x, game.view.surface_height(p.pos), p.pos.y)
		_placed[id] = true


## Go through a shaft.
func cross(p: Portal) -> void:
	if p == null or not p.open:
		return
	var to := p.to_realm
	Events.sfx.emit(&"door", game.player.position)
	_go(to, Vector2.ZERO, p.id, true)
	crossings += 1
	var land := BiomeRegistry.at(game.world, game.player.pos).display_name
	if Realm.roofed(to):
		Events.message.emit("Down the shaft, and the daylight goes: %s." % land)
	else:
		Events.message.emit("Up the shaft, and the sky comes back: %s." % land)


## Point the game at realm `to`. `at` is where to put the body; Vector2.ZERO means
## out of shaft `shaft`, or where the player last stood in `to`. `carry` is false
## only for a loaded game, where the save is the authority on what every realm
## holds and the realm being left must not be re-recorded from it.
func _go(to: StringName, at: Vector2, shaft: int, carry: bool) -> void:
	var from := _realm
	var size: int = game.world.size
	if carry:
		_stood[String(from)] = game.player.pos
		_edits[String(from)] = game.world.depleted.duplicate()
	var w := RealmWorlds.take(game.options.seed_value, size, to)
	if w == null:
		return
	if _edits.has(String(to)):
		w.depleted = (_edits[String(to)] as Dictionary).duplicate()
	var land := at
	if land == Vector2.ZERO:
		if shaft >= 0 and Portals.count(w) > 0:
			land = Portals.landing(w, shaft)
		else:
			land = _stood.get(String(to), w.spawn)
	# The world, and everything that reads it through the game's own fields.
	game.world = w
	game.query = WorldQuery.new(w)
	_realm = to
	# The body: the fight owns its position, so the hero is moved with it.
	var pl := game.player
	pl.world = w
	pl.query = game.query
	pl.pos = land
	if pl.hero != null:
		pl.hero.pos = land
	var sim := pl.sim
	if sim != null:
		sim.world = w
		sim.query = game.query
		sim.nav = null
		# Nothing follows a person down a shaft: what was after them is left on
		# the far side, and the bodies here are this realm's own.
		sim.clear_mobs()
	# The view keeps its materials and grows the new land.
	if game.view != null:
		game.view.rebind(w)
		game.view.focus = land
		game.view.ensure_near(land)
	pl.sync_view(0.0)
	if game.camera != null:
		game.camera.snap_to(pl.position)
	# What the land can hold — snow, ash, wet, fog — is a texture of the world.
	if game.sky != null:
		game.sky.set_ground(SkyGround.texture(w), w.size)
	_read_portals()
	_settle = SETTLE
	for sys in game.systems:
		if sys != self and sys.has_method(&"realm_changed"):
			sys.call(&"realm_changed", from, to)


## The shafts of the world the game is in now, and a drawn gate for each.
func _read_portals() -> void:
	here = Portals.in_world(game.world)
	reachable = null
	_taught.clear()
	_placed.clear()
	for c: Variant in _nodes.values():
		(c as Node3D).queue_free()
	_nodes.clear()
	if game.view == null or _gates == null:
		return
	var mat := game.view.world_material()
	for p in here:
		_as_landmark(p)
		var n := RealmGate.node(p, mat)
		n.position = Vector3(p.pos.x, game.world.height_at(p.pos), p.pos.y)
		n.rotation.y = -p.facing
		_gates.add_child(n)
		_nodes[p.id] = n


## A shaft is a place worth walking to, so it goes in the world's own list of
## them: the map draws it, a tour reaches it by name (`place shaft`) rather than
## by a coordinate, and nothing else has to be taught what a portal is. Added
## after generation, so no worldgen stage sees it and no island moves.
func _as_landmark(p: Portal) -> void:
	for m: Dictionary in game.world.landmarks:
		if m.get("kind") == &"shaft" and (m.get("pos") as Vector2).distance_to(p.pos) < 0.5:
			return
	game.world.landmarks.append({"kind": &"shaft", "pos": p.pos,
		"country": game.world.country_at(floori(p.pos.x), floori(p.pos.y))})


func _by_id(id: int) -> Portal:
	for p in here:
		if p.id == id:
			return p
	return null


# --- what a tour may await ---------------------------------------------------

func tour_seen(what: String) -> bool:
	if what == "portal":
		return reachable != null
	if what.begins_with("portal:"):
		return reachable != null and reachable.id == what.substr(7).to_int()
	if what == "crossed":
		return crossings > 0
	if what.begins_with("realm:"):
		return String(_realm) == what.substr(6)
	return false


# --- saving -----------------------------------------------------------------

func _save() -> Variant:
	var stood := {}
	for k: Variant in _stood:
		stood[str(k)] = SaveCodec.vec2(_stood[k])
	# Including the realm being stood in now: SaveCore keeps the player's tile but
	# not which realm's tile it is, and this is the only thing that knows.
	stood[String(_realm)] = SaveCodec.vec2(game.player.pos)
	var edits := {}
	for k: Variant in _edits:
		edits[str(k)] = _spell_edits(_edits[k])
	edits[String(_realm)] = _spell_edits(game.world.depleted)
	return {"realm": String(_realm), "stood": stood, "edits": edits, "crossings": crossings}


static func _spell_edits(d: Dictionary) -> Dictionary:
	var out := {}
	for id: Variant in d:
		out[str(id)] = SaveCodec.num(float(d[id]))
	return out


func _load(v: Variant) -> void:
	if not (v is Dictionary):
		return
	var d := v as Dictionary
	crossings = SaveCodec.to_int(d.get("crossings", 0))
	_stood.clear()
	var stood: Dictionary = d.get("stood", {})
	for k: Variant in stood:
		_stood[str(k)] = SaveCodec.to_vec2(stood[k])
	_edits.clear()
	var edits: Dictionary = d.get("edits", {})
	for k: Variant in edits:
		var per := {}
		var rows: Dictionary = edits[k]
		for id: Variant in rows:
			per[str(id).to_int()] = SaveCodec.to_num(rows[id])
		_edits[str(k)] = per
	var want := StringName(str(d.get("realm", String(Realm.SURFACE))))
	_saved_realm = want if Realm.KINDS.has(want) else &""
