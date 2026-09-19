extends GameSystem
## The plan standing on the road out of an unanswered chapter (VISION §10.3).
##
## `RoadHold` says WHERE and this stands the thing there. Three ways through and
## all three are real, which is the design and not a concession:
##
##   ANSWER IT   `Chapters.of` says the region is explored, mined and defended,
##               the plan has lost the place, and the machines holding its road
##               have nothing behind them. The barrier comes down on its own.
##   BREAK IT    a held `use` with a steel edge, the same hands a works housing
##               takes, and it is filed as sabotage because it is.
##   GO ROUND    it is on the carriageway and nowhere else. Leaving the road
##               costs what leaving a road costs and nothing stops you.
##
## **THE THIRD ONE IS WHY THIS IS NOT A LOCK.** A gate with no way past it is the
## message saying no that §10.3 forbids, wearing a model. What this buys is that
## crossing an unanswered border is an ACT -- you fight it, you break it, or you
## take the long way -- and never that it is impossible.
##
## What is DONE to a hold is saved (`holds`); where a hold IS never is, because
## `RoadHold` derives it from the world.

const Hold := preload("res://src/core/chapter/road_hold.gd")

## How far apart the three panels stand, across the road. A barricade is about a
## tile and a half wide, so this is what makes them a LINE with its ends touching
## rather than a heap: at 1.0 apart they overlapped into a clump in the middle of
## the carriageway and read as fly-tipping. Wide enough to span the road and its
## verges, and no wider, so the way round is the country and not the ditch.
const ACROSS := 3.2
## What each block stops a body at. Matched to the barricade it draws.
const BLOCK := 0.6

## Tiles from the player a barrier is drawn at. The same generosity the depots
## take: a thing this big appearing at ten paces is worse than the draw cost.
const DRAW_WITHIN := 46.0
## How near the player stands to get hands on it.
const REACH := 2.8

## Seconds of holding `use` before the next tick of work lands, and how many
## ticks take a barrier apart. Six, because it is one barrier and not a depot's
## housing: this is a gate, not a set piece.
const TICK := 0.45
const TICKS := 6
## What it takes to cut. The same edge a works housing wants, because it is the
## same plate.
const BREAK_STUFF := &"steel"
const BREAK_CAUSE := &"sabotage"

var sites: Array[RoadHold.HoldSite] = []
## Holds taken apart, keyed by the tile they stand on, so the key survives a
## world growing new regions around it.
var _broken: Dictionary = {}
var _layer: Node3D = null
var _nodes: Dictionary = {}
var _job: Dictionary = {}
var _held := 0.0
var _seen: Dictionary = {}
var sim: FightSim = null


func setup(g: Game) -> void:
	super.setup(g)
	sim = g.player.sim
	_layer = Node3D.new()
	_layer.name = "holds"
	g.add_child(_layer)
	_read_sites()
	SaveGame.register(&"holds", _save, _load)


func started() -> void:
	_set_walls()


func realm_changed(_from: StringName, _to: StringName) -> void:
	# A crossing is per world: another realm's island has its own roads and its
	# own plan standing on them.
	_read_sites()
	_clear_nodes()
	_set_walls()


func _read_sites() -> void:
	sites = Hold.sites(game.world) if game != null and game.world != null else ([] as Array[RoadHold.HoldSite])


## The tile a hold stands on, which is its name for as long as the world lasts.
static func key_of(h: RoadHold.HoldSite) -> String:
	return "%d,%d" % [floori(h.pos.x), floori(h.pos.y)]


## Whether the plan still holds this road. Broken is broken for good; answered is
## read LIVE off the chapter, so a keeper falling in the next valley lifts the
## boom without anything here being told.
func closed(h: RoadHold.HoldSite) -> bool:
	if bool(_broken.get(key_of(h), false)):
		return false
	return not bool(Chapters.of(game, h.region).get("answered", false))


func open_count() -> int:
	var n := 0
	for h: RoadHold.HoldSite in sites:
		if not closed(h):
			n += 1
	return n


## The mass of every closed barrier, handed to the one thing that stops a body.
## Rebuilt whenever a chapter could have turned over, which is cheap: a world
## holds tens of these, not thousands.
func _set_walls() -> void:
	if game == null or game.query == null:
		return
	var walls: Array[Vector3] = []
	for h: RoadHold.HoldSite in sites:
		if not closed(h):
			continue
		var across := Vector2(-h.along.y, h.along.x)
		for k: float in [-1.0, 0.0, 1.0]:
			var at: Vector2 = h.pos + across * (ACROSS * 0.5 * float(k))
			walls.append(Vector3(at.x, at.y, BLOCK))
	game.query.set_blocks(&"holds", walls)


func _clear_nodes() -> void:
	for n: Node3D in _nodes.values():
		n.queue_free()
	_nodes.clear()


## Barriers near the player, and only near: three props each, so the whole
## world's worth standing at once is not worth the draw calls.
func _stand() -> void:
	if game == null or game.player == null:
		return
	var at: Vector2 = game.player.pos
	for h: RoadHold.HoldSite in sites:
		var k := key_of(h)
		var want: bool = closed(h) and h.pos.distance_to(at) < DRAW_WITHIN
		var have: bool = _nodes.has(k)
		if want == have:
			continue
		if not want:
			(_nodes[k] as Node3D).queue_free()
			_nodes.erase(k)
			continue
		var root := Node3D.new()
		root.name = "hold_%s" % k
		var across := Vector2(-h.along.y, h.along.x)
		var country := maxi(Country.COAST, game.world.country_at(floori(h.pos.x), floori(h.pos.y)))
		for j in 3:
			var p: Vector2 = h.pos + across * (ACROSS * 0.5 * float(j - 1))
			# `variants` can answer 1, and a modulo by it is fine -- but a kind
			# that ever answers 0 would divide by zero on a frame, in a system
			# nothing else is watching. Ask for at least one.
			var kinds := maxi(1, PropModels.variants(PropKind.BARRICADE, country))
			var node := PropModels.node(PropKind.BARRICADE, j % kinds, country)
			if node == null:
				continue
			node.position = game.world.to_3d(p)
			# **ACROSS THE ROAD, NOT ALONG IT.** A model faces +X at rotation 0 and
			# turns by -rot, so facing a panel down the road's own heading laid it
			# lengthwise IN the carriageway -- three planks pointing the way you
			# were going, which is the one thing a barrier must not do.
			node.rotation.y = -across.angle()
			root.add_child(node)
		_layer.add_child(root)
		_nodes[k] = root


func _process(delta: float) -> void:
	if game == null or game.world == null:
		return
	_stand()
	_work(delta)


## The player's hands on a barrier. `use` is one key and this is one more thing
## it can mean, so it takes the key only while nothing the player could take
## from is nearer -- the rule a shaft and a works housing both go by.
func _work(delta: float) -> void:
	if game.input_blocked() or not Input.is_action_pressed(&"use"):
		_job = {}
		return
	var h := _near()
	if h == null or not closed(h) or not _hold_wins(h):
		_job = {}
		return
	if not Items.hard_enough(game.inventory.held, BREAK_STUFF):
		if _job.is_empty():
			_job = {"refused": true}
			Events.message.emit("Plate and pins, and nothing in your hands will cut it.")
			Events.sfx.emit(&"refused", game.world.to_3d(h.pos))
		return
	var k := key_of(h)
	if String(_job.get("key", "")) != k:
		_job = {"key": k, "ticks": 0}
		_held = 0.0
		Events.message.emit("You start cutting the barrier off the road.")
	_held += delta
	if _held < TICK:
		return
	_held = 0.0
	_job.ticks = int(_job.ticks) + 1
	Events.sfx.emit(&"work_metal", game.world.to_3d(h.pos))
	if int(_job.ticks) >= TICKS:
		_break(h)
		_job = {}


func _near() -> RoadHold.HoldSite:
	if sim == null:
		return null
	var best: RoadHold.HoldSite = null
	var near := REACH
	for h: RoadHold.HoldSite in sites:
		var d: float = h.pos.distance_to(sim.hero.pos)
		if d < near:
			near = d
			best = h
	return best


func _hold_wins(h: RoadHold.HoldSite) -> bool:
	var t := Survival.use_target(game)
	if t == null:
		return true
	return h.pos.distance_to(sim.hero.pos) <= t.pos.distance_to(sim.hero.pos)


func _break(h: RoadHold.HoldSite) -> void:
	_broken[key_of(h)] = true
	_seen[&"hold_broken"] = true
	Events.message.emit("The barrier comes off the road. Whatever is down there, the way is open.")
	Events.sfx.emit(&"break_metal", game.world.to_3d(h.pos))
	var dis := game.get_node_or_null(^"32_disposition")
	if dis != null and dis.has_method(&"raise"):
		dis.call(&"raise", BREAK_CAUSE, h.pos)
	_set_walls()


## A chapter answered lifts its own booms, so this is asked once a second rather
## than every frame: nothing here is worth a per-frame sweep of every region.
func _physics_process(_delta: float) -> void:
	_tick += 1
	if _tick % 60 != 0:
		return
	_set_walls()

var _tick := 0


func tour_seen(what: StringName) -> bool:
	match what:
		&"hold": return _near() != null
		&"hold_closed":
			var h := _near()
			return h != null and closed(h)
		&"hold_open":
			var h := _near()
			return h != null and not closed(h)
		&"hold_broken": return bool(_seen.get(&"hold_broken", false))
	return false


func tour_forget(what: StringName) -> void:
	_seen.erase(what)


func _save() -> Dictionary:
	return {"broken": _broken.keys()}


func _load(d: Dictionary) -> void:
	_broken.clear()
	for k: Variant in d.get("broken", []):
		_broken[str(k)] = true
	_set_walls()
