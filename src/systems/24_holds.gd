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

## **PRELOADED, NOT THE GLOBAL CLASS NAME.** `RoadHold` carries a `class_name`,
## and a `class_name` resolves out of Godot's global class cache -- which is
## refreshed by the tools and NOT by a player double-clicking the game. So every
## test passed while `godot --path .` could not parse this file at all, and the
## whole boot came down with it: no world, no query, no view. A preloaded const
## is resolved by path and cannot go stale, which is why the model files have
## always used one.
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
## What the work and the breaking SOUND like. Named for the event and mapped in
## `SoundNames`, the way the depot's own prise and part are: a bare literal here
## resolved to nothing and `tests/audio/test_names.gd` had been failing on it.
const SND_CUT := &"hold_cut"
const SND_BROKEN := &"hold_broken"
const BREAK_STUFF := &"steel"
const BREAK_CAUSE := &"sabotage"

var sites: Array = []
## Holds taken apart, keyed by the tile they stand on, so the key survives a
## world growing new regions around it.
var _broken: Dictionary = {}
var _layer: Node3D = null
var _nodes: Dictionary = {}
## Answered, per region that keeps a hold. See `closed`.
var _answered: Dictionary = {}
var _job: Dictionary = {}
var _held := 0.0
var _seen: Dictionary = {}
var sim: FightSim = null
## The four announcements that can move a chapter's answer. A FUNCTION and not an
## `@onready var`: `setup()` is called by the loader and does not wait for
## `_ready`, so an onready list would still be empty when the connecting happens
## and every signal would be silently unconnected -- a refresh that never fires,
## with nothing to see but a barrier that stays up. Held in one place so a fifth
## cause is one line here rather than a timer somebody puts back.
func _watched() -> Array[Signal]:
	return [Events.landmark_found, Events.took, Events.sentinel_fell, Events.works_broken]


func setup(g: Game) -> void:
	super.setup(g)
	sim = g.player.sim
	_layer = Node3D.new()
	_layer.name = "holds"
	g.add_child(_layer)
	_read_sites()
	SaveGame.register(&"holds", _save, _load)
	for sig: Signal in _watched():
		sig.connect(_chapters_moved)


func started() -> void:
	_refresh_chapters()
	_set_walls()


func realm_changed(_from: StringName, _to: StringName) -> void:
	# A crossing is per world: another realm's island has its own roads and its
	# own plan standing on them.
	_read_sites()
	_answered.clear()
	_refresh_chapters()
	_clear_nodes()
	_set_walls()


func _read_sites() -> void:
	sites = Hold.sites(game.world) if game != null and game.world != null else []


## The tile a hold stands on, which is its name for as long as the world lasts.
static func key_of(h: Hold.HoldSite) -> String:
	return "%d,%d" % [floori(h.pos.x), floori(h.pos.y)]


## Whether the plan still holds this road. Broken is broken for good and is read
## straight; ANSWERED comes off a cache refreshed once a second.
##
## **READING THE CHAPTER LIVE COST 86 MILLISECONDS A FRAME.** `Chapter.read`
## walks `world.props` to count a region's standing ore -- 62,826 props at the
## full world -- and its own header says so: "cheap enough to ask whenever
## something is taken rather than every frame". This asked it for every hold on
## every frame, eleven times over, and measured 86.74 ms in `_stand` alone
## against a main thread doing 88. It was the whole of the stutter and I shipped
## it tonight.
##
## Once a second is still live in every sense that matters: a keeper falling in
## the next valley lifts this boom without anything here being told, and nobody
## can walk a road in the second it takes to notice.
func closed(h: Hold.HoldSite) -> bool:
	if bool(_broken.get(key_of(h), false)):
		return false
	return not bool(_answered.get(h.region, false))


## Ask the chapters again -- once a second, and only for regions that keep a
## hold, so the cost is the handful of places the plan is actually standing on.
func _refresh_chapters() -> void:
	if game == null:
		return
	var seen := {}
	var want: Array = []
	for h: Hold.HoldSite in sites:
		if seen.has(h.region):
			continue
		seen[h.region] = true
		want.append(h.region)
	# ONE set of system sweeps for every region rather than three per region.
	# `Chapters.of` walks `game.systems` three times asking for properties by
	# name, so asking it in a loop paid that per region for collections that are
	# the same every time; this refresh is the largest `_process` cost in the
	# game and it is the only caller that asks about many regions at once.
	var chapters := Chapters.for_regions(game, want)
	for rid: int in want:
		# Read, not `get(..., false)`. `Chapter.read` sets `answered` on both its
		# return paths, so a default here could only ever hide a real breakage by
		# reporting an unfinished chapter as finished -- the exact shape CLAUDE.md
		# names, where the caller supplies the evidence and then believes it.
		_answered[rid] = bool((chapters[rid] as Dictionary)["answered"])


## Whether the plan is standing on a road within `within` tiles, still closed.
## Asked by the GUIDE so a haven can teach what the road out of it will ask for
## (docs/DESIGN.md §Safe havens). Exposed as a METHOD rather than leaving the
## guide to walk `RoadHold.sites` itself: this system already keeps the list, and
## re-deriving it per frame is the mistake that cost 224 ms a tick here once
## already.
func held_road_near(p: Vector2, within: float) -> bool:
	for h: Hold.HoldSite in sites:
		if h.pos.distance_to(p) <= within and closed(h):
			return true
	return false


func open_count() -> int:
	var n := 0
	for h: Hold.HoldSite in sites:
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
	for h: Hold.HoldSite in sites:
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
	for h: Hold.HoldSite in sites:
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


func _exit_tree() -> void:
	for sig: Signal in _watched():
		if sig.is_connected(_chapters_moved):
			sig.disconnect(_chapters_moved)


## What each part of this tick costs, under `--stats` only and read by
## 12_landscape the way a tour's `tour_seen` is.
##
## This system is the largest `_process` cost in the game (19.9 ms worst in
## steady play) and the tick is four calls, so the total names no culprit. It
## also already cost one wrong fix: the chapter refresh LOOKED expensive —
## `Chapters.of` swept every system three times per region — so it was made
## cheap first and measured second, and the whole refresh turns out to be
## 0.44 ms. Right change, wrong reason, and the spike stayed. Hence this.
const TICK_PARTS: Array[String] = ["refresh_chapters", "set_walls", "stand", "work"]
var tick_worst := PackedFloat32Array()


## A `perf stats` window starts the worst again (12_landscape.stats_begin).
func stats_reset() -> void:
	tick_worst.fill(0.0)


func _process(delta: float) -> void:
	if game == null or game.world == null:
		return
	if not game.options.stats:
		if _dirty:
			_dirty = false
			_refresh_chapters()
			_set_walls()
		_stand()
		_work(delta)
		return
	if tick_worst.size() != TICK_PARTS.size():
		tick_worst.resize(TICK_PARTS.size())
	var t := Time.get_ticks_usec()
	if _dirty:
		_dirty = false
		_refresh_chapters()
		t = _mark(0, t)
		_set_walls()
		t = _mark(1, t)
	_stand()
	t = _mark(2, t)
	_work(delta)
	@warning_ignore("return_value_discarded")
	_mark(3, t)


func _mark(i: int, since: int) -> int:
	var now := Time.get_ticks_usec()
	var took := float(now - since) / 1000.0
	if took > tick_worst[i]:
		tick_worst[i] = took
	return now


## Empty until something has been timed, so a run that never reached this system
## prints nothing rather than a row of zeroes — LOOK.md method 3, which this
## repository already owns and which a 0.00 would quietly break.
func stats_line() -> String:
	if tick_worst.size() != TICK_PARTS.size():
		return ""
	var out := PackedStringArray()
	for i in TICK_PARTS.size():
		out.append("%s %.1f" % [TICK_PARTS[i], tick_worst[i]])
	return "\nworld holds tick worst per part (ms): " + ", ".join(out)


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
	Events.sfx.emit(SND_CUT, game.world.to_3d(h.pos))
	if int(_job.ticks) >= TICKS:
		_break(h)
		_job = {}


func _near() -> Hold.HoldSite:
	if sim == null:
		return null
	var best: Hold.HoldSite = null
	var near := REACH
	for h: Hold.HoldSite in sites:
		var d: float = h.pos.distance_to(sim.hero.pos)
		if d < near:
			near = d
			best = h
	return best


func _hold_wins(h: Hold.HoldSite) -> bool:
	var t := Survival.use_target(game)
	if t == null:
		return true
	return h.pos.distance_to(sim.hero.pos) <= t.pos.distance_to(sim.hero.pos)


func _break(h: Hold.HoldSite) -> void:
	_broken[key_of(h)] = true
	_seen[&"hold_broken"] = true
	Events.message.emit("The barrier comes off the road. Whatever is down there, the way is open.")
	Events.sfx.emit(SND_BROKEN, game.world.to_3d(h.pos))
	var dis := game.get_node_or_null(^"32_disposition")
	if dis != null and dis.has_method(&"raise"):
		dis.call(&"raise", BREAK_CAUSE, h.pos)
	_set_walls()


## **ASKED WHEN AN ANSWER COULD HAVE CHANGED, NEVER ON A TIMER.**
##
## This read the chapters live, every frame, for every hold: `Chapter.read` walks
## `world.props` to count a region's standing ore, so eleven holds at sixty frames
## measured 86.74 ms in `_stand` alone. I moved it to once a second and called it
## fixed. It was not fixed, it was RESCHEDULED -- and that trade is worse than it
## looks, because it turns a low frame rate, which reads as "slow", into a hitch,
## which reads as "broken". Measured afterwards at 224.6 ms in a single physics
## tick, once a second, while the median frame was a healthy 8.3 ms. The owner's
## word for the result was "jumpy".
##
## **Work too expensive to do every frame is usually too expensive to do at all.**
## The question was never how OFTEN to pay it; it was why it was being recomputed
## when its inputs cannot have moved. A chapter's answer changes on exactly four
## things happening, and each one already announces itself:
##
##   a landmark found   `Events.landmark_found`   -> EXPLORED
##   ore taken          `Events.took`             -> MINED
##   a keeper down      `Events.sentinel_fell`    -> DEFENDED
##   a yard put dark    `Events.works_broken`     -> DEFENDED
##
## So this asks then, and at no other time. An idle frame costs nothing at all,
## which a timer can never manage. It is the file's own rule from CLAUDE.md read
## the right way round: the act that answers a question is the act that should
## stop it being asked.
##
## Coalesced to the next frame rather than run inside the signal, so four things
## landing together cost one refresh and nothing re-enters worldgen from inside
## somebody else's emit.
func _chapters_moved(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_dirty = true

var _dirty := false


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
