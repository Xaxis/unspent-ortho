extends GameSystem
## Crafts: what a person builds to get where a body cannot go (docs/VISION.md).
## The raft crosses open water, the hover sled runs the bog and the shallows at
## speed, and the walker rig strides up a cliff a body would have to walk round.
##
## It owns four things and nothing else:
##   the crafts    every one made or left standing in this world, and the save of them
##   the key       `ride` (b): board what is in reach, launch what is in the pack,
##                 step off what you are on, or take a wreck back for its parts
##   Hero.ride     the one field the fight reads (src/core/craft/craft_ride.gd):
##                 what the ground under the body means, and how fast it goes
##   the drawing   a CraftModel per craft, MENDED, standing in the world when parked
##
## It is NOT a second movement system. The craft never moves the body: the
## simulation does, exactly as it does on foot, and a dodge, a grip, a shoulder
## and a blow all land on a deck the way they land on turf. All a ride changes is
## which tiles `WorldQuery.move_body` will let the body into and what pace
## `Hero.ground_speed` gives it. Anything that puts the body somewhere else (a
## machine hauling you off, a load, a teleport) wins: the ride ends and the craft
## is left where it was, adrift.
##
## Boot options: `--craft=KIND` parks one in reach, `--aboard=KIND` starts on it.
## Look at it:
##   tools/shot.sh shots/crafts/raft.png --aboard=raft --seed=1 --place=spawn
##   tools/tour.sh tours/crafts.tour --seed=1 --hour=11 --weather=clear:0 --give=raft:1

## Hull lost per point of damage a blow does to the body riding: machines break
## your ride, and eight or nine blows finish a raft.
const HULL_PER_DAMAGE := 3.0
## A body that moves further than this between two frames was put there by
## something else: the ride is over and the craft stays behind (see the header).
const JUMPED := 3.0
## Tiles from a craft or from water that the lesson is taught at, once per game.
const TEACH_REACH := 4.0

var crafts: Array[Craft] = []
## The craft carrying the player, or null on foot.
var aboard: Craft = null
var _ride: CraftRide = null
var _nodes: Dictionary = {}
var _next_id := 1
var _ride_down := false
## Tiles carried over ground a body could not cross, and whether a ride has
## stridden a cliff: a tour's `ride_crossed` and `ride_climbed`.
var _crossed := 0.0
var _climbed := false
var _wrecked_one := false
var _salvaged_one := false
var _last := Vector2.INF
var _last_level := 0
var _taught: Dictionary = {}


func setup(g: Game) -> void:
	super.setup(g)
	SaveGame.register(&"crafts", _save, _load)
	Events.hit.connect(_on_hit)
	_from_options()


func _exit_tree() -> void:
	if Events.hit.is_connected(_on_hit):
		Events.hit.disconnect(_on_hit)


# --- the world's crafts --------------------------------------------------------

## Put a craft in the world at `at`, facing `facing`. The one door: the boot
## options, making one, and a loaded game all come through here.
func add(kind: StringName, at: Vector2, facing: float = 0.0) -> Craft:
	if not CraftKinds.known(kind):
		push_warning("no such craft %s" % kind)
		return null
	var c := Craft.make(_next_id, kind, at, facing)
	_next_id += 1
	crafts.append(c)
	return c


func remove(c: Craft) -> void:
	if aboard == c:
		_step_off_state()
	crafts.erase(c)
	var node: Node = _nodes.get(c.id)
	if node != null:
		node.queue_free()
		_nodes.erase(c.id)


func parked(kind: StringName = &"") -> Array[Craft]:
	var out: Array[Craft] = []
	for c in crafts:
		if c != aboard and (kind == &"" or c.kind == kind):
			out.append(c)
	return out


# --- the key ------------------------------------------------------------------

## Read as the EDGE of the action's held state, not from input events, so a press
## made by a device, one made by a tour's `tap` and one made by a test all take
## the same path (50_survival's rule). Watched on one clock only, a tap that
## falls between two of its frames is never seen at all, so both clocks watch and
## `_ride_down` is what makes that one press and not two.
func _read_keys() -> void:
	if not InputMap.has_action(&"ride"):
		return
	var down := Input.is_action_pressed(&"ride")
	var pressed := down and not _ride_down
	_ride_down = down
	if not pressed or game.input_blocked():
		return
	press_ride()


## What `b` does, in the order a player means it: get off what you are on, board
## or salvage what is in reach, else launch what you are carrying.
func press_ride() -> StringName:
	if aboard != null:
		return leave()
	var near := Crafts.nearest(crafts, _at(), Crafts.BOARD_REACH)
	if near != null:
		return salvage(near) if near.wrecked else board(near)
	var carried := _carried_kind()
	if carried == &"":
		return _refuse(&"none", &"")
	return launch(carried)


## Board a craft standing in the world. &"" or why not.
func board(c: Craft) -> StringName:
	var why := Crafts.board_refusal(c, _at())
	if why != &"":
		return _refuse(why, c.kind)
	_put_body(c.pos)
	_aboard_state(c)
	Events.sfx.emit(&"craft_board", game.player.position)
	Events.message.emit("You take the %s." % c.display_name())
	return &""


## Set a carried craft down and step onto it: a raft is shoved out past the
## shallows, anything else set down where there is room. &"" or why not.
func launch(kind: StringName) -> StringName:
	var spot := Crafts.launch_spot(game.world, game.query, kind, _at(), game.player.facing)
	if spot == Vector2.INF:
		return _refuse(&"afloat" if CraftKinds.afloat(kind) else &"room", kind)
	game.inventory.remove(kind, 1)
	var c := add(kind, spot, game.player.facing)
	if c == null:
		return _refuse(&"room", kind)
	_put_body(spot)
	_aboard_state(c)
	Events.sfx.emit(&"craft_board", game.player.position)
	# A float goes IN; anything with feet or a skirt is set DOWN.
	Events.message.emit(("You put the %s in and step on." if CraftKinds.afloat(kind)
		else "You set the %s down and step on.") % c.display_name())
	return &""


## Step off onto ground a body could have reached anyway, leaving the craft where
## it lies. &"" or why not.
func leave() -> StringName:
	if aboard == null:
		return &"none"
	var c := aboard
	var spot := Crafts.step_off_spot(game.world, game.query, c.kind, _at())
	if spot == Vector2.INF:
		return _refuse(&"ashore", c.kind)
	_step_off_state()
	_put_body(spot)
	Events.sfx.emit(&"craft_off", game.player.position)
	Events.message.emit("You step off. The %s stays where you left it." % c.display_name())
	return &""


## Take a wreck back for its parts: nothing a person built is dead loot.
func salvage(c: Craft) -> StringName:
	if not c.wrecked:
		return &"whole"
	var got := CraftKinds.salvage(c.kind)
	for id: StringName in got:
		game.inventory.add(id, int(got[id]))
		Events.took.emit(id, int(got[id]))
	remove(c)
	_salvaged_one = true
	Events.sfx.emit(&"craft_salvage", game.player.position)
	Events.message.emit("You strip the wrecked %s for what is left of it." % CraftKinds.display_name(c.kind))
	return &""


func _refuse(why: StringName, kind: StringName) -> StringName:
	Events.sfx.emit(&"craft_refused", game.player.position)
	Events.message.emit(Crafts.refusal_line(why, kind))
	return why


# --- riding -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if game == null or game.player == null:
		return
	_read_keys()
	_carry(delta)


## While a craft carries the body, it goes where the body goes, wears against
## what it is crossing, and counts what it has carried the body over. It never
## moves the body: the simulation did that, before this ran.
func _carry(_delta: float) -> void:
	if aboard == null:
		_last = Vector2.INF
		return
	var at := _at()
	var c := aboard
	if _last != Vector2.INF:
		var step := at.distance_to(_last)
		if step > JUMPED:
			# Something else put the body there. The craft is left adrift.
			_adrift(c)
			return
		if step > 0.0:
			c.hull -= step * Crafts.wear_for(c.kind, _ground_at(at))
			if Crafts.beyond_a_body(game.world, at):
				_crossed += step
		var level := game.world.level_at(floori(at.x), floori(at.y))
		if absi(level - _last_level) >= 2:
			_climbed = true
			c.hull -= Crafts.wear_per_step(c.kind)
		_last_level = level
	else:
		_last_level = game.world.level_at(floori(at.x), floori(at.y))
	c.pos = at
	c.facing = game.player.facing
	game.player.lift = CraftKinds.stand(c.kind)
	_last = at
	if c.hull <= 0.0 and not c.wrecked:
		_wreck(c)


## The hull is gone. Whoever was on it is put ashore, and what is left of it is
## a thing in the world to come back for — unless it sank, which is what a raft
## does in deep water: some things are simply lost.
func _wreck(c: Craft) -> void:
	c.damage(maxf(1.0, c.hull))
	_wrecked_one = true
	Events.sfx.emit(&"craft_wreck", game.player.position)
	var sank := CraftKinds.afloat(c.kind) and Crafts.beyond_a_body(game.world, c.pos)
	var ashore := Crafts.step_off_spot(game.world, game.query, c.kind, c.pos)
	if ashore == Vector2.INF:
		ashore = _swim_ashore(c.pos)
	if aboard == c:
		_step_off_state()
		_put_body(ashore)
	if sank:
		Events.message.emit("The %s comes apart under you and goes down. You get ashore." % c.display_name())
		remove(c)
		return
	Events.message.emit("The %s is finished. It lies where it broke." % c.display_name())
	_sync_node(c)


## A craft left behind because the body was taken off it.
func _adrift(c: Craft) -> void:
	_step_off_state()
	Events.message.emit("The %s is left where it was." % c.display_name())
	_sync_node(c)


func _aboard_state(c: Craft) -> void:
	aboard = c
	_ride = c.ride()
	_last = Vector2.INF
	game.player.ride = _ride
	# The body stands ON the deck. `lift` is the gear package's field and it
	# writes it every frame a motion runs; this writes it only while a craft
	# carries the body, and 54_gear runs after this one, so an ability that
	# throws the body off a deck wins for as long as it runs and puts it back to
	# the ground itself.
	game.player.lift = CraftKinds.stand(c.kind)
	if game.player.hero != null:
		game.player.hero.ride = _ride


func _step_off_state() -> void:
	aboard = null
	_ride = null
	_last = Vector2.INF
	game.player.ride = null
	game.player.lift = 0.0
	if game.player.hero != null:
		game.player.hero.ride = null


## Move the body, the fight body with it (the contract: in a running game the
## fight body owns position), and the land about it.
func _put_body(to: Vector2) -> void:
	var hero := game.player.hero
	if hero != null:
		hero.pos = to
		hero.move = Vector2.ZERO
	game.player.pos = to
	game.player.sync_view(0.0)
	if game.view != null:
		game.view.ensure_near(to)
	if game.camera != null:
		game.camera.snap_to(game.player.position)


func _at() -> Vector2:
	var hero := game.player.hero
	return hero.pos if hero != null else game.player.pos


func _ground_at(p: Vector2) -> int:
	return game.world.ground_at(floori(p.x), floori(p.y))


## Far out and wrecked: the nearest ground there is, however far. Waking up on a
## shore is an ending a player can live with; standing on the open sea is not.
func _swim_ashore(from: Vector2) -> Vector2:
	var cx := floori(from.x)
	var cy := floori(from.y)
	for r in range(1, 40):
		var best := Vector2.INF
		var best_d := INF
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r or not game.query.standable(cx + dx, cy + dy):
					continue
				var p := Vector2(cx + dx + 0.5, cy + dy + 0.5)
				var d := p.distance_squared_to(from)
				if d < best_d:
					best_d = d
					best = p
		if best != Vector2.INF:
			return best
	return from


# --- what a blow does to what you are standing on -----------------------------

func _on_hit(_attacker: Object, target: Object, damage: int, _plate: bool, _at3: Vector3) -> void:
	if aboard == null or damage <= 0 or target == null:
		return
	if target != game.player and target != game.player.hero:
		return
	if aboard.damage(float(damage) * HULL_PER_DAMAGE):
		_wreck(aboard)


# --- the drawing --------------------------------------------------------------

func _process(_delta: float) -> void:
	if game == null or game.player == null:
		return
	_read_keys()
	_teach()
	for c in crafts:
		_sync_node(c)


func _sync_node(c: Craft) -> void:
	var node: CraftModel = _nodes.get(c.id)
	if node == null:
		node = CraftModel.create(c.kind)
		node.build(game.view.world_material() if game.view != null else null)
		add_child(node)
		_nodes[c.id] = node
	node.set_wrecked(c.wrecked)
	var sit := CraftKinds.sit(c.kind)
	if c == aboard:
		# Under the body, taking the player node's own eased height (less the lift
		# that is standing it on this very deck), so a deck never swims against
		# the figure on it.
		node.position = game.player.position + Vector3(0.0, sit - game.player.lift, 0.0)
		node.rotation.y = -game.player.facing
	else:
		node.position = game.world.to_3d(c.pos) + Vector3(0.0, sit, 0.0)
		node.rotation.y = -c.facing


# --- teaching -----------------------------------------------------------------

## Said once, in its moment, on the channel that is dropped rather than queued:
## standing at a craft, and carrying one where it could go in.
func _teach() -> void:
	if game.hud == null or not game.hud.can_teach():
		return
	if aboard == null and not _taught.has(&"board"):
		var near := Crafts.nearest(crafts, _at(), TEACH_REACH)
		if near != null:
			_taught[&"board"] = true
			var line := "Strip it for its parts" if near.wrecked else "Stand on it"
			Events.hint.emit(PlayerSettings.spell("%s: %%s." %% line, [&"ride"]), PlayerSettings.cap_of(&"ride"))
			return
	if aboard == null and not _taught.has(&"launch") and _carried_kind() != &"":
		var kind := _carried_kind()
		if Crafts.launch_spot(game.world, game.query, kind, _at(), game.player.facing) != Vector2.INF:
			_taught[&"launch"] = true
			Events.hint.emit(PlayerSettings.spell(
				"Put the %s in here: %%s." %% CraftKinds.display_name(kind), [&"ride"]),
				PlayerSettings.cap_of(&"ride"))
			return
	if aboard != null and not _taught.has(&"leave"):
		_taught[&"leave"] = true
		Events.hint.emit(PlayerSettings.spell("Step off again: %s.", [&"ride"]), PlayerSettings.cap_of(&"ride"))


## The first craft in the creel that has a place to go in, else the first at all.
func _carried_kind() -> StringName:
	var first: StringName = &""
	for kind: StringName in CraftKinds.ids():
		if not game.inventory.has(kind):
			continue
		if first == &"":
			first = kind
		if Crafts.launch_spot(game.world, game.query, kind, _at(), game.player.facing) != Vector2.INF:
			return kind
	return first


# --- boot options -------------------------------------------------------------

func _from_options() -> void:
	var o := game.options
	if o == null:
		return
	for kind: StringName in [StringName(o.craft), StringName(o.aboard)]:
		if kind == &"":
			continue
		if not CraftKinds.known(kind):
			push_warning("--craft/--aboard: no such craft %s" % kind)
			continue
		var spot := Crafts.launch_spot(game.world, game.query, kind, _at(), game.player.facing)
		if spot == Vector2.INF:
			push_warning("--craft %s: nowhere here it could go (a raft wants water)" % kind)
			continue
		var c := add(kind, spot, game.player.facing)
		if kind == StringName(o.aboard) and c != null:
			_put_body(spot)
			_aboard_state(c)


# --- a tour's eyes ------------------------------------------------------------

## Answers for `await` and for a frame's `with` (98_tour.gd):
##   riding, riding:KIND      the player is on one
##   afloat                   being carried over ground a body could not cross
##   ride_crossed             it has carried them across such ground, and how far
##   ride_climbed             it has stridden a step no body could
##   craft:KIND, parked:KIND   one of those stands in the frame
##   ride_ready               a craft in reach, or one in the pack with room for it
##   step_off_ready           there is ground to step off onto from here
##   craft_wrecked, craft_salvaged
func tour_seen(what: StringName) -> bool:
	var s := String(what)
	if s == "riding" or s == "aboard":
		return aboard != null
	if s.begins_with("riding:"):
		return aboard != null and String(aboard.kind) == s.substr(7)
	if s == "afloat":
		return aboard != null and Crafts.beyond_a_body(game.world, _at())
	if s == "ride_crossed":
		return _crossed >= Crafts.CROSSED_TILES
	if s == "ride_climbed":
		return _climbed
	if s == "craft_wrecked":
		return _wrecked_one
	if s == "craft_salvaged":
		return _salvaged_one
	if s == "ride_ready":
		return Crafts.nearest(crafts, _at(), Crafts.BOARD_REACH) != null or _carried_kind() != &""
	if s == "step_off_ready":
		return aboard != null and Crafts.step_off_spot(game.world, game.query, aboard.kind, _at()) != Vector2.INF
	if s == "craft" or s.begins_with("craft:"):
		return _in_frame(StringName(s.substr(6)) if s.length() > 6 else &"", false)
	if s == "parked" or s.begins_with("parked:"):
		return _in_frame(StringName(s.substr(7)) if s.length() > 7 else &"", true)
	return false


## A craft the camera is actually showing: a frame that claims one holds one.
func _in_frame(kind: StringName, must_be_parked: bool) -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	for c in crafts:
		if kind != &"" and c.kind != kind:
			continue
		if must_be_parked and c == aboard:
			continue
		var node: Node3D = _nodes.get(c.id)
		if node != null and cam.is_position_in_frustum(node.global_position + Vector3(0.0, 0.3, 0.0)):
			return true
	return false


# --- saving -------------------------------------------------------------------

func _save() -> Variant:
	var list: Array = []
	for c in crafts:
		list.append(c.to_save())
	return {"next": _next_id, "list": list, "aboard": aboard.id if aboard != null else -1}


func _load(v: Variant) -> void:
	var d: Dictionary = v if v is Dictionary else {}
	for node: Node in _nodes.values():
		node.queue_free()
	_nodes.clear()
	crafts.clear()
	_step_off_state()
	for row: Variant in (d.get("list", []) as Array):
		var c := Craft.from_save(row as Dictionary)
		if c != null:
			crafts.append(c)
	_next_id = maxi(1, SaveCodec.to_int(d.get("next", 1), 1))
	var on := SaveCodec.to_int(d.get("aboard", -1), -1)
	if on < 0:
		return
	for c in crafts:
		if c.id == on:
			# Back on the deck without moving: the body was saved standing on it,
			# and on water there is nowhere else it could be.
			_aboard_state(c)
			return
