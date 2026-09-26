extends GameSystem
## The machines' depots, in the running game (docs/VISION.md). Reachable as
## the system named `34_works`.
##
## A region the plan is working has a depot: a lit yard on the survey bearing
## with a mast over it, seen from across the land at night. It does five things,
## and nothing else may:
##   1. finds the depots (`Works.sites`, pure) and remembers what has been done
##      to each of them (`WorksState`, saved under `works`);
##   2. draws one when the player comes near and takes it off again when they go,
##      with its plan stage showing as bays and strips it did not have last week;
##   3. PUTS THE MACHINES OUT — the bodies in a region come out of its depot and
##      walk its round along the survey, so a busy land is busy because something
##      in it is working, not because a spawner was told to roll harder here;
##   4. lets a player break one: three working parts, each its own walk across an
##      open yard with a steel edge, each one filed as sabotage the moment it is
##      opened, so the third is taken with the region already coming;
##   5. when the last one goes, puts the region out FOR GOOD — the lights out,
##      the yard's own works spent (which is what starves the region's keeper,
##      `Sentinels.feeds`), nothing more put on the land from here, and the
##      ground slowly closing over it.
##
## It writes to the world in exactly two places, both of them permanent and both
## of them saved: the yard's works are marked spent when the depot falls, and a
## tuft goes in as the land takes the yard back.

## Tiles from the player a depot is drawn at. Generous, because the whole point
## of the mast is being seen before it is reached.
const DRAW := 64.0
## How often the depots near the player are looked at (seconds).
const LOOK_EVERY := 0.25
## Seconds of holding `use` on a part before the next tick of work lands, and how
## many ticks a part takes. Told in the world: the part's own lamp stutters while
## the work is on, and a knock is heard at every tick.
const TICK := Works.BREAK_SECONDS / 5.0
const TICKS := 5
## Tiles the player may drift off a part before the work is dropped.
const HOLD_SLACK := 0.9
## Machines this near a part being opened take it amiss.
const HEARD := 24.0
## What the depot says when a part goes and when the last one does (SoundNames).
const SND_TICK := &"works_prise"
const SND_PART := &"works_part"
const SND_DARK := &"works_dark"

var sites: Array[WorksSite] = []
var sim: FightSim
## Region id -> WorksState.
var _states: Dictionary = {}
## Region id -> the drawn yard, and "region:part" -> a drawn working part.
var _yards: Dictionary = {}
var _parts: Dictionary = {}
## Region id -> the stage its yard was built at, so a yard is rebuilt when the
## plan moves it on a stage (a day's business) and at no other time.
var _built_stage: Dictionary = {}
var _stood: Dictionary = {}
var _layer: Node3D
var _look := 0.0
## The part under the player's hands: {site, index, ticks, held}.
var _job: Dictionary = {}
var _held := 0.0
## Region id -> the world minute its own next body and next round are due.
var _own_at: Dictionary = {}
var _round_at: Dictionary = {}
## Region id -> the world minute the plan last filed a person in its yard.
var _filed_at: Dictionary = {}
## Told once per depot, the first time the player is inside its reach.
var _taught: Dictionary = {}
## Region id -> how many bodies this depot has put on the land this game. What
## "the region quiets" is measured by (tests/works/test_in_game.gd), counted
## where it happens rather than worked out from two constants.
var put_out: Dictionary = {}
## What a tour has been shown.
var _seen: Dictionary = {}


func setup(g: Game) -> void:
	super.setup(g)
	sim = g.player.sim
	_layer = Node3D.new()
	_layer.name = "works"
	g.add_child(_layer)
	_read_sites()
	# THE REGION'S MACHINES, and not only the yard's. Putting a body out of the
	# gate (`_put_out`) only ever reaches the thirty tiles the player is standing
	# in; a region whose depot had been dark for a week went on rolling exactly
	# as many machines as one whose yard was lit, which made "the region quiets"
	# a line in a comment. This is the whole of the other half: on ground a broken
	# depot's region covers, no machine of the plan comes out at all. What lives
	# there still does, so the land is quiet and not empty.
	var mobs := g.get_node_or_null(^"30_mobs")
	if mobs != null:
		var c: Coast = mobs.get(&"coast")
		if c != null:
			c.also_shut = _shut_for_region
	SaveGame.register(&"works", _save, _load)


func _shut_for_region(out: Dictionary, at: Vector2) -> void:
	if game == null or game.world == null:
		return
	var region := game.world.region_at(floori(at.x), floori(at.y))
	if region < 0 or not broken(region):
		return
	for k: StringName in Roster.DEFS:
		if Roster.row(k).get("machine", false):
			out[k] = true


## The depots of the world the game is in now. Called again on a realm crossing,
## because another realm's island has its own plan and its own depots.
func _read_sites() -> void:
	sites = Works.sites(game.world)
	for c: Variant in _yards.values():
		(c as Node3D).queue_free()
	for c: Variant in _parts.values():
		(c as Node3D).queue_free()
	_yards.clear()
	_parts.clear()
	_built_stage.clear()
	_stood.clear()
	_taught.clear()
	_own_at.clear()
	_round_at.clear()
	_filed_at.clear()
	_job = {}
	for s in sites:
		if not _states.has(s.region):
			var st := WorksState.new()
			st.region = s.region
			_states[s.region] = st
		_as_landmark(s)
		_make(s)
	_set_walls()


## The mass of every depot in this world, handed to the one thing that stops a
## body (`WorldQuery.set_blocks`): the deck is a wall to go round and each working
## part is a thing to take cover behind, which is what makes breaking one a set
## piece rather than three keypresses in an open field.
func _set_walls() -> void:
	if game.query == null:
		return
	var walls: Array[Vector3] = []
	for s in sites:
		var along := Vector2.from_angle(s.facing)
		var across := Vector2(-along.y, along.x)
		for c: Vector3 in WorksDepot.yard_blocks():
			var at := s.pos + along * c.x + across * c.y
			walls.append(Vector3(at.x, at.y, c.z))
		for i in Works.PART_NAMES.size():
			var base := s.part(i)
			for c: Vector3 in WorksDepot.part_blocks(i):
				var at := base + along * c.x + across * c.y
				walls.append(Vector3(at.x, at.y, c.z))
	game.query.set_blocks(&"works", walls)


## Through a door: the outside is kept as it stood (20_realms says why).
func indoors(inside: bool) -> void:
	sleep_indoors(inside, [_layer] as Array[Node3D])


func realm_changed(_from: StringName, _to: StringName) -> void:
	_read_sites()


## A depot is a place worth walking to, so it goes in the world's own list of
## them: the map draws it, the reads app names it, and a tour reaches it by name
## (`place works`) instead of by a coordinate that the next change to worldgen
## quietly invalidates. Added after generation, so no island moves.
## Recorded at its first working part rather than at the middle of its deck, for
## the same reason a landmark is recorded at its cache: arriving at a works means
## arriving where the hands go. Its other two housings are reached by name too
## (`works_breaker`, `works_coolant`), through `GenPlaces`, without being marks
## of their own on the map.
func _as_landmark(s: WorksSite) -> void:
	var at := s.part(0)
	for m: Dictionary in game.world.landmarks:
		if m.get("kind") == &"works" and (m.get("pos") as Vector2).distance_to(at) < 0.5:
			return
	game.world.landmarks.append({"kind": &"works", "pos": at,
		"country": game.world.country_at(floori(at.x), floori(at.y)),
		"dir": Vector2.from_angle(s.facing)})


func _process(delta: float) -> void:
	if game == null or game.world == null or sim == null:
		return
	_look -= delta
	if _look <= 0.0:
		_look = LOOK_EVERY
		_draw()
		_teach()
	_work(delta)


func _physics_process(_delta: float) -> void:
	if sim == null:
		return
	_put_out()
	_press()
	_green()


# --- what stands where --------------------------------------------------------

func state(region: int) -> WorksState:
	return _states.get(region, null)


## The depot whose ground the player is on, or null.
func here() -> WorksSite:
	return Works.at(sites, sim.hero.pos)


func broken(region: int) -> bool:
	var st: WorksState = _states.get(region, null)
	return st != null and st.broken()


## What the plan has got to here, which is what the yard draws.
func stage_of(s: WorksSite) -> int:
	var st: WorksState = _states.get(s.region, null)
	var day := float(game.clock.day())
	if st == null:
		return Works.stage(s, day, false)
	return Works.stage(s, day, st.broken(), st.dark_day)


# --- drawing ------------------------------------------------------------------

## SHOWN by distance, never built by it: every depot is made with the world
## (`_read_sites`), for the reason 22_landmarks' `_draw` gives -- the reach is the
## whole island once the camera sees the horizon, and the first look over the
## shoulder built every yard in one frame (97 ms on seed 7). A yard is rebuilt
## only when its STAGE moves, which is the one input of its model that can.
func _draw() -> void:
	var at := sim.hero.pos
	var reach := _draw_reach()
	for s in sites:
		if not _yards.has(s.region):
			continue
		if int(_built_stage.get(s.region, -1)) != stage_of(s):
			_drop(s)
			_make(s)
		var near := s.pos.distance_to(at) <= reach
		_show(s, near)
	_stand()


func _show(s: WorksSite, on: bool) -> void:
	var yard := _yards[s.region] as Node3D
	if yard.visible == on:
		return
	yard.visible = on
	for i in Works.PART_NAMES.size():
		var part: Node3D = _parts.get("%d:%d" % [s.region, i], null)
		if part != null:
			part.visible = on


## Made once per depot with the world, hidden until `_draw` shows it: about
## 5 ms a depot at load (17 on seed 7 at 1024: 85 ms at load 36-55).
func _make(s: WorksSite) -> void:
	var mat := game.view.world_material() if game.view != null else null
	var st: WorksState = _states.get(s.region, null)
	var stage := stage_of(s)
	var yard := WorksDepot.yard(s, stage, mat)
	yard.rotation.y = -s.facing
	yard.visible = false
	_layer.add_child(yard)
	_yards[s.region] = yard
	_built_stage[s.region] = stage
	if st != null and st.broken():
		WorksDepot.set_dark(yard, true)
	for i in Works.PART_NAMES.size():
		var node := WorksDepot.part(i, s.region * 17 + i, mat)
		node.rotation.y = -s.facing
		node.visible = false
		_layer.add_child(node)
		_parts["%d:%d" % [s.region, i]] = node
		if st != null and st.parts[i]:
			WorksDepot.set_broken(node, true)


func _drop(s: WorksSite) -> void:
	(_yards[s.region] as Node3D).queue_free()
	_yards.erase(s.region)
	_built_stage.erase(s.region)
	_stood.erase(s.region)
	for i in Works.PART_NAMES.size():
		var key := "%d:%d" % [s.region, i]
		if _parts.has(key):
			(_parts[key] as Node3D).queue_free()
			_parts.erase(key)
			_stood.erase(key)


## Put every drawn thing on the DRAWN ground once the chunk under it exists. The
## mesher's surface and a tile's own level are not the same number on a terrace
## lip, and a depot standing a finger above the rock is what a player sees first.
func _stand() -> void:
	if game.view == null:
		return
	for s in sites:
		if not _yards.has(s.region) or bool(_stood.get(s.region, false)):
			continue
		if game.view.chunk_at(s.pos) == null:
			continue
		(_yards[s.region] as Node3D).position = Vector3(s.pos.x, game.view.surface_height(s.pos), s.pos.y)
		_stood[s.region] = true
	for key: String in _parts:
		if bool(_stood.get(key, false)):
			continue
		var bits := key.split(":")
		var s := _by_region(bits[0].to_int())
		if s == null:
			continue
		var p := s.part(bits[1].to_int())
		if game.view.chunk_at(p) == null:
			continue
		(_parts[key] as Node3D).position = Vector3(p.x, game.view.surface_height(p), p.y)
		_stood[key] = true


## HANDS ON A HOUSING HOLD THE KEY (the `use_spent` seam, CLAUDE.md's One use key
## row, which already noted this system "reads `use` too and does not ask yet").
##
## A depot stands at the busiest knot of the plan's works, and some of those knots
## are turf rows — which have SURVEY POSTS in them, and a survey post is readable
## (`StoryProps.READABLE`). So a player holding `use` on a feed housing with a post
## 2.7 tiles away opened the post's page instead, `Game.input_blocked()` went true,
## and `_work` dropped the job on the very next frame. Held down for four hundred
## frames it never opened once, and nothing errored: the yard simply could not be
## broken, in the one landscape whose depot is a field of rows.
##
## 34 runs before 49 in name order, so the housing gets the key first and says so.
func use_spent() -> bool:
	return not _job.is_empty()


func _by_region(region: int) -> WorksSite:
	for s in sites:
		if s.region == region:
			return s
	return null


# --- breaking one -------------------------------------------------------------

## The player's hands on a working part. `use` is one key and a works part is one
## more thing it can mean, so it takes the key only when it is nearer than
## whatever else is under the hand (the same rule a shaft goes by, 20_realms).
func _work(delta: float) -> void:
	if game.input_blocked() or not Input.is_action_pressed(&"use"):
		_drop_job()
		return
	var s := here()
	if s == null:
		_drop_job()
		return
	var i := Works.part_near(s, sim.hero.pos)
	var st: WorksState = _states.get(s.region, null)
	if i < 0 or st == null or st.parts[i] or not _part_wins(s, i):
		_drop_job()
		return
	if not Items.hard_enough(game.inventory.held, Works.BREAK_STUFF):
		if _job.is_empty():
			_job = {"refused": true}
			Events.message.emit("The housing rings, and nothing comes away. It wants a steel edge.")
			Events.sfx.emit(&"refused", game.world.to_3d(s.part(i)))
		return
	if _job.get("region", -1) != s.region or _job.get("index", -1) != i:
		_job = {"region": s.region, "index": i, "ticks": 0}
		_held = 0.0
		Events.message.emit("You get the %s housing open." % String(s.part_name(i)))
	_held += delta
	_flicker(s.region, i)
	if _held < TICK:
		return
	_held = 0.0
	_job.ticks = int(_job.ticks) + 1
	Events.sfx.emit(SND_TICK, game.world.to_3d(s.part(i)))
	if int(_job.ticks) >= TICKS:
		_break(s, i)
		_job = {}


## A part only takes the key while nothing the player could take from is nearer:
## standing at a part with a seam beside it, they mean the part.
func _part_wins(s: WorksSite, i: int) -> bool:
	var d := s.part(i).distance_to(sim.hero.pos)
	# A named person of the cast standing nearer than the housing is who the
	# key means: Sefa waits at the Tether's own works, and a player at her side
	# with a knife in hand was answered by the housing's ring every time.
	for sys in game.systems:
		var people: Variant = sys.get("people") if sys.name == "49_cast" else null
		if people is Array:
			for row: Dictionary in people:
				if row.get("model") != null and (row.pos as Vector2).distance_to(sim.hero.pos) < d:
					return false
	var t := Survival.use_target(game)
	if t == null:
		return true
	return d <= t.pos.distance_to(sim.hero.pos)


func _drop_job() -> void:
	if _job.is_empty():
		return
	var s := _by_region(int(_job.get("region", -1)))
	if s != null:
		_lamps(int(_job.region), int(_job.index), true)
	_job = {}
	_held = 0.0


## The part's own lamp stutters while a player has it open: what says the work is
## going on is the thing being worked on, never a bar drawn over the world.
func _flicker(region: int, i: int) -> void:
	_lamps(region, i, fmod(_held, TICK * 0.5) < TICK * 0.25)


func _lamps(region: int, i: int, on: bool) -> void:
	var node: Node3D = _parts.get("%d:%d" % [region, i], null)
	if node == null:
		return
	var lamps := node.get_node_or_null(^"lamps")
	if lamps != null:
		(lamps as Node3D).visible = on


## One part, opened. The plan hears about it at once — this is not a theft the
## machines find out about later, it is a hole in what feeds them — so every
## machine within earshot turns, and the network files sabotage.
func _break(s: WorksSite, i: int) -> void:
	var st: WorksState = _states.get(s.region, null)
	if st == null or st.parts[i]:
		return
	st.parts[i] = true
	st.stirred_at = game.clock.minutes
	var node: Node3D = _parts.get("%d:%d" % [s.region, i], null)
	WorksDepot.set_broken(node, true)
	var at := s.part(i)
	Events.sfx.emit(SND_PART, game.world.to_3d(at))
	_file(Works.BREAK_CAUSE, at)
	_rouse(at)
	_seen[&"works_part"] = true
	if st.broken():
		_fell(s, st)
	else:
		var left := Works.PART_NAMES.size() - st.broken_count()
		var tail := "Two more hold this yard up." if left > 1 else "One more."
		Events.message.emit("The %s is out. %s" % [String(s.part_name(i)), tail])


## The last part goes, and the region changes for good (VISION §2). The lights go
## out and stay out; the works in the yard are spent, which is what leaves this
## region's keeper standing dark (`Sentinels.feeds`); nothing else is put on the
## land from here; and the ground begins to close over it.
func _fell(s: WorksSite, st: WorksState) -> void:
	st.dark_at = game.clock.minutes
	st.dark_day = float(game.clock.day())
	var yard: Node3D = _yards.get(s.region, null)
	if yard != null:
		WorksDepot.set_dark(yard, true)
	_strip(s, st)
	Events.sfx.emit(SND_DARK, game.world.to_3d(s.pos))
	Events.message.emit("The yard goes dark. Nothing here answers the plan now.")
	Events.works_broken.emit(s.region, s.land)


## The plan's own works standing in the yard, spent for good. This is the one
## thing a broken depot does to the world that another package reads: a keeper
## fed by these is fed by nothing now (src/core/sentinel), and the map's marks
## and the reads app stop finding a live work here.
## Tiles round a depot's work that its stripping still reaches.
const STRIP_MARGIN := 1.5


func _strip(s: WorksSite, st: WorksState) -> void:
	if st.stripped:
		return
	st.stripped = true
	# The yard, and the work it was founded on: the plan's machinery there is
	# the depot's too, and a keeper that eats it goes hungry when it is taken.
	var reach := maxf(Works.YARD, s.work_half.length() + STRIP_MARGIN) + s.work_pos.distance_to(s.pos) if s.work_pos.is_finite() else Works.YARD
	for q in game.query.props_near(s.pos, reach):
		if not Takes.is_plan_work(q.kind) or game.world.depleted.has(q.id):
			continue
		if q.pos.distance_to(s.pos) > Works.YARD and not s.on_work(q.pos, STRIP_MARGIN):
			continue
		game.world.depleted[q.id] = INF
		if game.view != null:
			game.view.refresh_props(q)


## Every machine within earshot takes it amiss, wired or not: a work of the plan
## is wired to whatever serves it, and opening one tells them.
func _rouse(at: Vector2) -> void:
	for m in sim.mobs:
		if not m.alive or m.removed or not m.machine:
			continue
		if Senses.chebyshev(m.pos, at) > HEARD:
			continue
		sim.disturb(m, &"sabotage")
		m.last_seen = sim.hero.pos
		m.heard_at = sim.hero.pos
	Events.sfx.emit(&"alert", game.world.to_3d(at))


## File a cause against the plan network the depot serves. The disposition
## package owns interference; this asks it, and says nothing if it is not there
## (a headless test builds one system at a time).
func _file(cause: StringName, at: Vector2) -> void:
	for sys in game.systems:
		if sys.name == "32_disposition" and sys.has_method(&"raise"):
			@warning_ignore("return_value_discarded")
			sys.call(&"raise", cause, at)
			return


# --- the bodies a depot puts on the land ---------------------------------------

## The depot's own, out of the yard, and one on its round along the survey. Both
## stop for good when it goes dark, which is the region quieting.
func _put_out() -> void:
	var minutes := game.clock.minutes
	# How busy a depot is, live from the master configuration (docs/DESIGN.md): a
	# playtest that wants to walk into a yard and look at it turns this to none,
	# and one that wants the yard defended turns it up. Nothing else about the
	# depot changes with it — it is lit, it can be broken, and it still quiets.
	var busy := float(GameConfig.value("rules.works"))
	for s in sites:
		var st: WorksState = _states.get(s.region, null)
		var dead: bool = busy <= 0.0 or (st != null and st.broken())
		if s.pos.distance_to(sim.hero.pos) > Works.REACH or sim.living() >= Spawner.MAX_LIVING:
			continue
		var kind := _worker_for(s)
		if kind == &"":
			continue
		# THE CLOCK STARTS WHEN THE YARD IS REACHED, not at the beginning of time.
		# Left at -INF both timers were due on the first tick, so a worker and a
		# round popped into being the instant the player crossed the thirty-tile
		# line — the one moment a depot is being looked at from outside.
		if not _own_at.has(s.region):
			_own_at[s.region] = minutes
			_round_at[s.region] = minutes
			continue
		var rate := maxf(busy, 0.001)
		if minutes >= float(_own_at[s.region]) + Works.own_every(dead) / rate:
			_own_at[s.region] = minutes
			_own(s, kind)
		if minutes >= float(_round_at[s.region]) + Works.patrol_every(dead) / rate:
			_round_at[s.region] = minutes
			_patrol(s, kind)


## A body out of the yard, walking away from the deck on its own errand.
func _own(s: WorksSite, kind: StringName) -> void:
	if _own_out(s) > 0:
		return
	var along := Vector2.from_angle(s.facing)
	var at := Works.stand_near(game.world, s.pos - along * (Works.YARD + 2.0))
	if not at.is_finite():
		return
	var m := sim.add_mob(kind, at)
	m.home = s.pos
	m.line_a = at
	m.line_b = s.pos
	m.facing = (s.pos - at).angle()
	m.aim = m.facing
	put_out[s.region] = int(put_out.get(s.region, 0)) + 1
	_seen[&"works_body"] = true


func _own_out(s: WorksSite) -> int:
	var n := 0
	for m in sim.mobs:
		if m.alive and not m.removed and m.machine and m.home.distance_to(s.pos) < 1.0:
			n += 1
	return n


## A round along the survey bearing, which is the line every ruled thing the
## machines built in this world lies on. The Coast keeps one patrol out at a
## time and this is one, so a depot's round takes the place of the land's rather
## than doubling it.
func _patrol(s: WorksSite, kind: StringName) -> void:
	for m in sim.mobs:
		if m.patrol and m.alive and not m.removed:
			return
	var line := Works.route(s)
	var from: Vector2 = line[0]
	var to: Vector2 = line[1]
	if from.distance_to(sim.hero.pos) > Spawner.PATROL_CULL:
		var swap := from
		from = to
		to = swap
	if from.distance_to(sim.hero.pos) > Spawner.PATROL_CULL:
		return
	if not game.query.standable(floori(from.x), floori(from.y)):
		return
	var m := sim.add_mob(kind, from)
	m.line_a = from
	m.line_b = to
	m.line_to_b = true
	m.patrol = true
	m.put_out_at = sim.now
	m.facing = (to - from).angle()
	m.aim = m.facing
	put_out[s.region] = int(put_out.get(s.region, 0)) + 1
	_seen[&"works_patrol"] = true


## What kind of machine this depot works with: a worker on the landscape's own
## roster, else anything of the plan's that belongs here.
func _worker_for(s: WorksSite) -> StringName:
	var def := BiomeRegistry.get_def(s.land)
	if def == null:
		return &""
	var fallback: StringName = &""
	for kind: StringName in def.roster:
		var row := Roster.row(kind)
		if not row.get("machine", false):
			continue
		if Roles.of(kind) == Roles.WORKER:
			return kind
		if fallback == &"":
			fallback = kind
	return fallback


# --- what a standing works presses on the player -------------------------------

## Stand in a working yard and the plan files you for it, over and over, for as
## long as you are in it. Nothing is said: the horn over the land and the
## watchers turning are the disposition package's answer to a rising file.
func _press() -> void:
	var s := here()
	if s == null or broken(s.region) or not s.in_yard(sim.hero.pos):
		return
	var minutes := game.clock.minutes
	if minutes - float(_filed_at.get(s.region, -INF)) < Works.TRESPASS_EVERY:
		return
	_filed_at[s.region] = minutes
	_file(&"trespass", sim.hero.pos)
	_seen[&"works_pressed"] = true


# --- the land taking a dark yard back ------------------------------------------

## Grass over the yard. A tuft at a time, laid as a real prop so it is there
## tomorrow and in every save after (SaveCore keeps props added in play), and
## never laid twice.
func _green() -> void:
	for s in sites:
		var st: WorksState = _states.get(s.region, null)
		if st == null or not st.broken():
			continue
		if s.pos.distance_to(sim.hero.pos) > DRAW:
			continue
		var want := Works.green_tufts(st.dark_hours(game.clock.minutes))
		if st.tufts >= want:
			continue
		var i := st.tufts
		st.tufts += 1
		var a := Rng.hash01(game.world.seed_value, s.region, i, 0x67) * TAU
		var r := Works.YARD * (0.35 + Rng.hash01(game.world.seed_value, s.region, i, 0x68) * 0.6)
		var at := s.pos + Vector2.from_angle(a) * r
		var tx := floori(at.x)
		var ty := floori(at.y)
		if not game.query.standable(tx, ty) or Ground.is_water(game.world.ground_at(tx, ty)):
			continue
		var def := BiomeRegistry.at(game.world, at)
		var kind := PropKind.BUSH if def == null or not def.scorched else PropKind.BONES
		@warning_ignore("return_value_discarded")
		Survival.add_prop(game, kind, at, Rng.hash01(game.world.seed_value, s.region, i, 0x69) * TAU, 0.7)
		_seen[&"works_greening"] = true
		return


# --- what a player is told once ------------------------------------------------

func _teach() -> void:
	var s := here()
	if s == null or _taught.has(s.region):
		return
	_taught[s.region] = true
	if broken(s.region):
		Events.message.emit("A dark yard. The mast has nothing on it.")
		return
	Events.message.emit(Works.says(s))
	# The key is asked for, never spelled: the cap used to read USE, because the
	# ACTION's name was handed to a drawer that letters what it is given.
	Events.hint.emit(PlayerSettings.spell(
		"Three housings hold this yard up. A steel edge, and hold %s on each.", [&"use"]),
		PlayerSettings.cap_of(&"use"))


# --- saving -------------------------------------------------------------------

func _save() -> Variant:
	var out: Array = []
	for region: int in _states:
		var st: WorksState = _states[region]
		if st.broken_count() > 0 or st.tufts > 0:
			out.append(st.save())
	return out


func _load(v: Variant) -> void:
	if not v is Array:
		return
	for row: Variant in v:
		if not row is Dictionary:
			continue
		var was := WorksState.from_save(row)
		if not _states.has(was.region):
			continue
		_states[was.region] = was
	# What was done to a yard is part of its model: build it again as loaded.
	for s in sites:
		if _yards.has(s.region):
			_drop(s)
			_make(s)


# --- what a tour may await ----------------------------------------------------

## Answers a tour's `await WHAT` and a frame's `with WHAT`:
##   works             the player is on a depot's ground
##   works:LAND        that landscape's depot is the one they are on
##   works_yard        a depot is drawn near enough to be in frame
##   works_lit         the depot the player is on still has its lights
##   works_part        a working part has been opened since the last action
##   works_open:N      that many parts of the depot they are on are open
##   works_broken      a depot has been put out (asked of the world, not latched:
##                     a yard that is dark stays dark, and `_states` says so)
##   works_dark        the depot the player is on is dark
##   works_body        the depot has put one of its own on the land
##   works_patrol      one of its own is on its round
##   works_pressed     the plan has filed the player for standing in a yard
##   works_greening    the land has begun to take a dark yard back
func tour_seen(what: String) -> bool:
	if _seen.has(StringName(what)):
		return true
	var s := here()
	match what:
		"works":
			return s != null
		"works_yard":
			for region: int in _yards:
				var site := _by_region(region)
				if site != null and site.pos.distance_to(sim.hero.pos) <= DRAW:
					return true
			return false
		"works_lit":
			return s != null and not broken(s.region)
		"works_dark":
			return s != null and broken(s.region)
		"works_broken":
			for region: int in _states:
				if (_states[region] as WorksState).broken():
					return true
			return false
	if what.begins_with("works:"):
		return s != null and String(s.land) == what.substr(6)
	if what.begins_with("works_open:"):
		var st: WorksState = _states.get(s.region, null) if s != null else null
		return st != null and st.broken_count() >= what.substr(11).to_int()
	return false


## An await is spent by the tour that asked it (98_tour `_forget`).
func tour_forget(what: StringName) -> void:
	_seen.erase(what)


## WHAT A DEPOT READS AS when the player puts the slate on it (42_target). A
## works could be walked to, cased and broken and the slate had nothing to say
## about it — every other thing a player can look at in this game says what it
## is. What it says is what a player casing one wants: what trade it was founded
## on, how far the plan has got here, and how many of its three housings are
## still shut.
func target_rows(from: Vector2, reach: float) -> Array:
	var out: Array = []
	for s in sites:
		if s.pos.distance_to(from) > reach:
			continue
		var st: WorksState = _states.get(s.region, null)
		var shut := Works.PART_NAMES.size() - (0 if st == null else st.broken_count())
		var dark := st != null and st.broken()
		var stats: Array = [
			["trade", String(s.trade).capitalize()],
			["stage", "%d of %d" % [stage_of(s) + 1, Works.STAGES]],
			["housings", "out" if dark else "%d still shut" % shut],
		]
		var thinking := "The yard is dark. Nothing here answers the plan."
		if not dark:
			thinking = "The plan is working here. %s" % ("Three housings hold it up."
				if shut == 3 else "%d of its housings still hold it up." % shut)
		out.append({
			"id": s.region,
			"kind": &"works",
			"name": Works.says(s),
			"pos": s.pos,
			"height": 3.0,
			"radius": Works.YARD * 0.5,
			"role": "the plan's own depot",
			"machine": true,
			"notices": "the yard is watching" if not dark else "nothing here is awake",
			"stats": stats,
			"thinking": thinking,
		})
	return out


## How far off one is drawn: DRAW, or as far as the eye sees while the camera can
## see the horizon (SkyLight.sees_horizon). From above nothing past DRAW is in the
## frame; at eye level a thing that appears sixty tiles out is the one thing on
## the skyline that moved, and the whole point of it is being seen from afar.
func _draw_reach() -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return SkyLight.SEE if SkyLight.sees_horizon(cam) else DRAW
