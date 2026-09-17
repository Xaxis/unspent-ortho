extends GameSystem
## The places the player built, and the register two packages meet on
## (docs/VISION.md §9). Reachable as the system named "46_settlements".
##
## This is the seam AND the game on top of it. It holds the settlements, saves
## them, says who is where — and it builds, staffs, produces, wears and repairs.
## The raids package reads `signature()` off these, writes `attention`, and calls
## `damage_structure`; it never has to know this file exists, and this file never
## names a raid.
##
## What it owns:
##   the register   every holding in the world, and the save of them (key `settlements`)
##   the key        `holding` (h): the slate's holding app, where a piece goes up
##   the catch-up   `settle_up()` runs SettlementRules from each holding's own
##                  timestamp, so six hours away is twelve half-hour steps and not
##                  twenty thousand frames. Nothing here ticks per frame.
##   the drawing    a StructureModel per piece, and a footprint in the collision
##                  grid so a wall is a wall
##   the people     residents, who are villagers that came over (35_folk's own
##                  rows, driven through the fields that system already keeps)
##   the events     settlement_founded, structure_built, structure_damaged,
##                  structure_destroyed — and none of the raids package's four
##
## Two decisions worth knowing before changing anything here:
##
## **A hearth is the game's own campfire.** Put up, it adds a `PropKind.FIRE` to
## the world, so it lights the yard, warms a body, can be slept beside and sounds
## like a fire — none of which a model of this package's own would do. The holding
## records that it has one, what it costs to keep, and that its smoke is what
## gives the place away.
##
## **A piece's footprint is a collision-only prop.** `WorldQuery.add_prop` takes a
## WorldProp that is NOT in `world.props`, so it blocks a body and a machine's
## line of sight (`Senses.BLOCKING_SOLID`) while the drawing stays this package's
## own. Its kind is one no table in the game reacts to and its id is negative, so
## it can never collide with a real prop's id or be taken, lit or heard. The one
## thing it does do is give `Cover.at` a little, which is honest: a wall you
## crouch behind hides you.
##
## Boot options: `--holding=KIND[,KIND]` stands a staffed holding in front of the
## player, free, for shots and tours.
##   tools/shot.sh shots/settlement/noon.png --holding=hearth,hut,plot,palisade --seed=1
##   tools/tour.sh tours/settlements.tour --seed=1 --hour=10 --weather=clear:0

## Real seconds between sweeps. A holding is settled in world-clock slices, so
## this only decides how soon the player SEES it, never what happened.
const SWEEP := 1.0
## The kind a footprint borrows (see the header): no verb, no take, no light, no
## sound, no roof.
const FOOTPRINT := PropKind.MEMORIAL
## The village index a resident carries. 35_folk streams villagers by village
## index and leaves anything negative alone, so a resident stays at the holding
## day and night instead of walking home to a village they left.
const RESIDENT := -3
## Tiles from a holding a villager ALREADY STANDING ON THE LAND will walk over
## from. This is 35_folk's own `NEAR` by necessity and not by choice: that system
## only builds villager bodies while the PLAYER is within 34 tiles of a village,
## so no body exists outside it to ask. It was never an independent design
## number — it was the streaming radius wearing a second name.
const RECRUIT_REACH := 34.0
## How far word travels for a bed, when there is nobody standing about to ask.
## Measured against worldgen rather than picked: the furthest standable tile from
## any village is 64, 71 and 77 on seeds 1, 4 and 7, so 80 means a holding
## ANYWHERE on the island can be staffed — and what decides whether it actually is
## stays the bed, which is the rule worth having.
const LODGE_REACH := 80.0
## Tiles from the player a holding is drawn and its people stood up within.
const DRAW_REACH := 90.0
## What one press of `mend` puts back, as a share of the piece's strength, and
## what it costs: one of whatever the piece is made of, and this much clock.
const MEND_SHARE := 0.34
const MEND_MINUTES := 12.0
## Under this share of its strength a piece is worth putting a hand to. Above it
## the holding's own people keep it (SettlementRules), and the key does something
## more useful with the press.
const MEND_BELOW := 0.95
## Clearing a wreck gives back this share of what it cost, and takes this long.
const SALVAGE_SHARE := 0.5
const CLEAR_MINUTES := 10.0
## Tiles within which the player is told what the holding got done while away.
const EARSHOT := 60.0

var places: Array[Settlement] = []
var screen: UiSettlementScreen
var _next_id := 1
var _ui: Node
var _folk_system: Node
## "sid:pid" -> the model standing in the world.
var _nodes: Dictionary = {}
## "sid:pid" -> the collision-only footprint in the query's grid.
var _ghosts: Dictionary = {}
## "sid:pid" -> health as of the last sweep, so damage from ANY outside hand is
## noticed and announced even when nobody called this system's own door.
var _health: Dictionary = {}
var _wrecked: Dictionary = {}
## "sid:person" -> the 35_folk row standing for that resident.
var _bodies: Dictionary = {}
var _sweep := 0.0
var _ghost_ids := 0
var _held: Dictionary = {}
## Set by the tour and the boot option, for `tour_seen`.
var _built_one := false
var _produced := false


func setup(g: Game) -> void:
	super.setup(g)
	SaveGame.register(&"settlements", _save, _load)


func started() -> void:
	# The slate is wired up here and not in setup, because the ui system is loaded
	# after this one (90 after 46) and does not exist yet while setup runs.
	if _slate() != null:
		screen = UiSettlementScreen.new()
		screen.holdings = self
		_ui.call("add_app", screen)
	# A loaded holding is put back on its feet: its pieces drawn, its footprints
	# in the grid, its people stood up, and the hours it was away settled.
	_from_options()
	settle_up()
	_sync_nodes()
	_sync_people()
	_note_health()


## The realm the game is in now. A world is one realm's world, so this is the
## whole of what decides which holdings are under the player's feet.
func realm_here() -> StringName:
	return game.world.realm if game != null and game.world != null else Realm.SURFACE


## A crossing hands the game a new world AND a new WorldQuery, so every footprint
## this package put in the old one has gone with it and every drawing standing in
## it is standing in the wrong world. The holdings of the realm being entered are
## stood up again; the ones left behind go on working, because a place with
## people in it does not stop for being out of sight (`settle_up` settles every
## realm's).
func realm_changed(_from: StringName, _to: StringName) -> void:
	for key: String in _nodes:
		var node: StructureModel = _nodes[key]
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()
	# Nothing to remove them from: that query is gone.
	_ghosts.clear()
	_bodies.clear()
	for s in places:
		if s.realm != realm_here():
			continue
		for piece in s.pieces:
			_realise(s, piece)
	settle_up()
	_sync_nodes()
	_sync_people()


func _slate() -> Node:
	if _ui == null or not is_instance_valid(_ui):
		_ui = null
		for s in game.systems:
			if s.name == "90_ui":
				_ui = s
	return _ui


func _exit_tree() -> void:
	for key: String in _ghosts:
		if game != null and game.query != null:
			game.query.remove_prop(_ghosts[key])
	_ghosts.clear()


# --- the register ------------------------------------------------------------

## Start a place at `at` in `realm`. The founding is announced so the guide, the
## slate and the raids package all learn about it the same way.
func found(realm: StringName, at: Vector2, called: String = "") -> Settlement:
	var s := Settlement.new(_next_id, realm, at, called if called != "" else SettlementBuild.name_for(_next_id))
	_next_id += 1
	places.append(s)
	# Its clock starts now: nobody is owed the hours before it existed.
	if game != null and game.clock != null:
		s.worked_at = floorf(game.clock.minutes / SettlementRules.SLICE) * SettlementRules.SLICE
		s.night = SettlementRules.night_at(game.clock.minutes)
	Events.settlement_founded.emit(s.id)
	return s


func get_one(id: int) -> Settlement:
	for s in places:
		if s.id == id:
			return s
	return null


func all(realm: StringName = &"") -> Array[Settlement]:
	if realm == &"":
		return places.duplicate()
	var out: Array[Settlement] = []
	for s in places:
		if s.realm == realm:
			out.append(s)
	return out


## Every place whose centre is within `radius` of `pos`: what a machine passing
## through asks before it notices anything.
func at(realm: StringName, pos: Vector2, radius: float) -> Array[Settlement]:
	var out: Array[Settlement] = []
	for s in places:
		if s.realm == realm and s.centre.distance_to(pos) <= radius:
			out.append(s)
	return out


## The place nearest `pos` in `realm`, or null.
func nearest(realm: StringName, pos: Vector2) -> Settlement:
	var best: Settlement = null
	var best_d := INF
	for s in places:
		if s.realm != realm:
			continue
		var d := s.centre.distance_to(pos)
		if d < best_d:
			best_d = d
			best = s
	return best


## The holding the player is standing in or beside, or null. What the slate's
## holding app is about, and where a new piece joins rather than founding another.
func here() -> Settlement:
	if game == null or game.player == null:
		return null
	var s := nearest(realm_here(), game.player.pos)
	if s == null or s.centre.distance_to(game.player.pos) > SettlementBuild.JOIN:
		return null
	return s


# --- building ---------------------------------------------------------------

## "" when a piece of `kind` could go up where the player stands, else one plain
## line. It answers for the WORLD; what the creel is short of is SettlementBuild.
func why_not_here(kind: int) -> String:
	if game == null:
		return "Not here."
	if Survival.threat_near(game):
		return Survival.THREAT_LINE
	var spot := _spot_for(kind)
	if not is_finite(spot.x):
		return "No room for it here."
	if StructureKind.lure(kind) > 0.0:
		# A decoy stands FOR somewhere, and it is only elsewhere out past the yard.
		# Said before the creel is emptied, not discovered after.
		var s := here()
		if s == null:
			return "A decoy has to stand for somewhere. Build the place first."
		if spot.distance_to(s.centre) < Settlement.LURE_APART:
			return "In the yard a decoy is the yard. Walk it out past the last roof."
	return ""


## Put a piece of `kind` up in front of the player, out of what they are carrying.
## Returns the line to say; a leading "!" is a refusal (the slate's contract).
func build_here(kind: int) -> String:
	var why := SettlementBuild.why_not(game.inventory, kind)
	if why == "":
		why = why_not_here(kind)
	if why != "":
		return "!" + why
	var spot := _spot_for(kind)
	if not SettlementBuild.take_cost(game.inventory, kind):
		return "!" + SettlementBuild.why_not(game.inventory, kind)
	var s := here()
	if s == null:
		s = found(realm_here(), spot)
	var p := place_piece(s, kind, spot, game.player.facing)
	# The clock is charged what the work took, the way a station's building is.
	var minutes := StructureKind.minutes(kind)
	game.clock.skip(minutes)
	Events.time_skipped.emit(minutes, &"build")
	Events.sfx.emit(StringName("build_%s" % String(StructureKind.display_name(kind)).replace(" ", "_")), game.world.to_3d(spot))
	Events.made.emit(StringName(String(StructureKind.display_name(kind)).replace(" ", "_")), 1)
	if game.player.model != null:
		game.player.model.play_action(&"work_dig", 0.0)
	_built_one = true
	# A holding's centre is the middle of what it holds, so it creeps as it grows.
	_recentre(s)
	settle_up()
	return "Built a %s. %s" % [StructureKind.display_name(kind), s.name]


## The one door a piece comes into the world through: the data, the footprint in
## the collision grid, the drawing, and the event. Loading and the boot option
## both come through here too, so nothing can exist half-placed.
func place_piece(s: Settlement, kind: int, at_pos: Vector2, facing: float = 0.0) -> Structure:
	var p := s.add(kind, at_pos)
	p.facing = facing
	_realise(s, p)
	Events.structure_built.emit(s.id, p.id)
	return p


## Give a piece everything it needs outside its own data: a footprint, a drawing,
## and — for a hearth — the game's own fire.
func _realise(s: Settlement, p: Structure) -> void:
	if game == null:
		return
	var key := _key(s, p)
	if p.kind == StructureKind.HEARTH:
		if _fire_at(p.pos) == null:
			@warning_ignore("return_value_discarded")
			Survival.add_prop(game, PropKind.FIRE, p.pos)
		return
	var solid := StructureKind.solid(p.kind)
	if solid > 0.0 and not _ghosts.has(key):
		_ghost_ids += 1
		# Negative, so it can never be a real prop's id: `depleted`, `taken` and
		# every option key in the world are keyed by those.
		var ghost := WorldProp.new(-_ghost_ids, FOOTPRINT, p.pos, p.facing, 1.0)
		ghost.solid = solid
		game.query.add_prop(ghost)
		_ghosts[key] = ghost
	_node_for(s, p)


func _recentre(s: Settlement) -> void:
	# A decoy is out in a field on purpose. Counted in, it would drag the centre —
	# where a machine reads the place and a party marches to — toward itself, and
	# then stand inside the very yard it was built to be away from.
	var sum := Vector2.ZERO
	var n := 0
	for p in s.pieces:
		if StructureKind.lure(p.kind) > 0.0:
			continue
		sum += p.pos
		n += 1
	if n > 0:
		s.centre = sum / float(n)


## Where a piece of `kind` would go: in front of the player if the ground is
## level and clear, else the nearest clear way round them. Vector2(INF) if none.
func _spot_for(kind: int) -> Vector2:
	var p := game.player.pos
	var level := game.world.level_at(floori(p.x), floori(p.y))
	var r := maxf(StructureKind.solid(kind), 0.5)
	# In front first, then round, then a step further out. A holding is built in
	# a village's gaps and among what the ruin left, so a search that gives up
	# after one ring refuses half the places a player would call open ground.
	for step: float in [0.0, 0.8, 1.6, 2.4]:
		for turn: float in [0.0, 0.4, -0.4, 0.8, -0.8, 1.2, -1.2, 1.6, -1.6, 2.2, -2.2, PI]:
			var spot := p + Vector2.from_angle(game.player.facing + turn) * (SettlementBuild.AHEAD + r + step)
			if _clear(spot, r, level):
				return spot
	return Vector2(INF, INF)


func _clear(spot: Vector2, r: float, level: int) -> bool:
	var w := game.world
	for c: Vector2 in [spot, spot + Vector2(r, 0), spot - Vector2(r, 0), spot + Vector2(0, r), spot - Vector2(0, r)]:
		var tx := floori(c.x)
		var ty := floori(c.y)
		if not game.query.standable(tx, ty) or Ground.is_water(w.ground_at(tx, ty)) or w.level_at(tx, ty) != level:
			return false
	for q in game.query.props_near(spot, 4.0):
		if w.depleted.has(q.id):
			continue
		var body := maxf(q.solid, 0.2)
		if q.kind == PropKind.PINE or q.kind == PropKind.SNOW_PINE or q.kind == PropKind.BROADLEAF:
			body = maxf(body, 0.7 * q.scale)
		elif q.kind == PropKind.HOUSE:
			body = maxf(body, 2.1 * q.scale)
		var gap := body + r + SettlementBuild.CLEARANCE
		if q.pos.distance_squared_to(spot) < gap * gap:
			return false
	return true


# --- tending -----------------------------------------------------------------

## The one thing `E` does to a piece, and the row says which before it is pressed:
## clear a wreck, mend what is coming apart, put somebody on it, or take them off.
func tend(piece_id: int) -> String:
	var s := here()
	if s == null:
		return "!Nothing of yours here."
	var p := s.piece(piece_id)
	if p == null:
		return "!That is gone."
	if p.ruined:
		return _clear_wreck(s, p)
	# A piece switched by hand: a live one is switched off first — nobody puts
	# their hands in a running gun — and one standing down is mended before it is
	# switched on again.
	if StructureKind.switched(p.kind):
		if not p.off:
			return _switch(s, p, false)
		if p.condition() < MEND_BELOW:
			return _mend(s, p)
		return _switch(s, p, true)
	# Hands before repairs. Everything standing is a shade less than whole within
	# an hour of going up, and a plot that demanded to be tidied before anybody
	# could be put on it would never be worked at all.
	if StructureKind.needs_staff(p.kind) and p.staffed_by < 0:
		var full := s.people.size() >= s.beds()
		var who := _staff(s, p)
		if who < 0:
			# Which of the two walls it is, or the lesson is unlearnable: one is
			# answered by building a bed and the other by founding somewhere else.
			if full:
				return "!Nowhere for anybody else to sleep here."
			return "!Nobody near enough to come and work it."
		return "Somebody is on the %s now." % StructureKind.display_name(p.kind)
	if p.condition() < MEND_BELOW:
		return _mend(s, p)
	if p.staffed_by >= 0:
		p.staffed_by = -1
		return "Taken off the %s." % StructureKind.display_name(p.kind)
	return "!It wants nothing."


## What E will do to a piece, in the page's own words, so the key strip and the
## press never disagree (UiSettlementScreen reads this).
func verb_for(p: Structure) -> String:
	if p == null:
		return "-"
	if p.ruined:
		return "clear"
	if StructureKind.switched(p.kind):
		if not p.off:
			return "stand down" if p.kind == StructureKind.TURRET else "switch off"
		if p.condition() < MEND_BELOW:
			return "mend"
		return "arm" if p.kind == StructureKind.TURRET else "switch on"
	if StructureKind.needs_staff(p.kind) and p.staffed_by < 0:
		return "work it"
	if p.condition() < MEND_BELOW:
		return "mend"
	return "leave" if p.staffed_by >= 0 else "-"


func _switch(s: Settlement, p: Structure, on: bool) -> String:
	p.off = not on
	Events.sfx.emit(&"piece_switch", game.world.to_3d(p.pos))
	settle_up()
	_sync_nodes()
	var name := StructureKind.display_name(p.kind)
	if p.kind == StructureKind.TURRET:
		if not on:
			return "Stood the turret down."
		return "The turret is armed." if p.powered else "Armed, but there is no power to run it."
	if not on:
		return "Switched the %s off." % name
	return "Switched the %s on." % name if p.powered else "Switched on, but there is no power to run it."


## The drawing of a piece, for a system that moves part of it (a turret's head).
func model_of(s: Settlement, p: Structure) -> StructureModel:
	var node: StructureModel = _nodes.get(_key(s, p))
	return node if node != null and is_instance_valid(node) else null


func _mend(s: Settlement, p: Structure) -> String:
	var cost := StructureKind.cost(p.kind)
	var stuff := &""
	for id: StringName in cost:
		if game.inventory.count(id) > 0:
			stuff = id
			break
	if stuff == &"":
		return "!Nothing to mend it with."
	@warning_ignore("return_value_discarded")
	game.inventory.remove(stuff, 1)
	p.repair(p.max_health * MEND_SHARE)
	game.clock.skip(MEND_MINUTES)
	Events.time_skipped.emit(MEND_MINUTES, &"build")
	Events.sfx.emit(&"work_tap", game.world.to_3d(p.pos))
	_note_health()
	_sync_nodes()
	return "Mended the %s." % StructureKind.display_name(p.kind)


## A wreck cleared gives back half of what the piece cost: nothing a holding
## built is ever dead loot (docs/VISION.md §6.1).
func _clear_wreck(s: Settlement, p: Structure) -> String:
	var back := PackedStringArray()
	for id: StringName in StructureKind.cost(p.kind):
		var n := floori(float(StructureKind.cost(p.kind)[id]) * SALVAGE_SHARE)
		if n > 0:
			game.inventory.add(id, n)
			back.append(SettlementBuild.count_words(id, n))
	_forget(s, p)
	s.pieces.erase(p)
	game.clock.skip(CLEAR_MINUTES)
	Events.time_skipped.emit(CLEAR_MINUTES, &"build")
	Events.sfx.emit(&"break", game.world.to_3d(p.pos))
	_recentre(s)
	if back.is_empty():
		return "Cleared the wreck."
	return "Cleared it, and took back %s." % SettlementBuild.join_words(back)


## Somebody already living here takes the work on, or somebody from the nearest
## village moves in to do it. Returns the resident's id, or -1 when nobody can.
##
## `free` is for staging only (`--holding`, which is documented as free and
## staffed): it skips the bed, because a shot or a tour asking for one plot must
## get a working plot and not a lesson about roofs.
func _staff(s: Settlement, p: Structure, free: bool = false) -> int:
	for id: int in s.people:
		var busy := false
		for q in s.pieces:
			if q.staffed_by == id:
				busy = true
				break
		if not busy:
			p.staffed_by = id
			_put_to_work(s, id, p)
			return id
	# Nobody spare, so somebody has to move in — and moving in wants a bed.
	if not free and s.people.size() >= s.beds():
		return -1
	var who := _recruit(s)
	if who < 0:
		return -1
	p.staffed_by = who
	_put_to_work(s, who, p)
	return who


## Everything the holding has laid by, into the creel.
func collect_stores() -> String:
	var s := here()
	if s == null:
		return "!Nothing of yours here."
	var took := PackedStringArray()
	for id: Variant in s.stores.keys():
		var n := int(s.stores[id])
		if n <= 0:
			continue
		game.inventory.add(StringName(id), n)
		took.append(SettlementBuild.count_words(StringName(id), n))
		s.stores.erase(id)
	if took.is_empty():
		return "!Nothing laid by yet."
	Events.sfx.emit(&"took", game.world.to_3d(s.centre))
	Events.took.emit(&"stores", took.size())
	return "Took %s." % SettlementBuild.join_words(took)


# --- damage from outside ------------------------------------------------------

## The door the raids package may use instead of touching a Settlement directly.
## Either way the events, the drawing and the footprint follow, because the sweep
## reconciles what it finds (see `_reconcile`).
func damage(settlement_id: int, piece_id: int, amount: float) -> bool:
	var s := get_one(settlement_id)
	if s == null:
		return false
	var ruined := s.damage_structure(piece_id, amount)
	_reconcile()
	return ruined


## Notice every change to a piece's health since the last sweep, whoever made it,
## and say so once. Wear is absorbed by `_note_health` at the end of the
## catch-up, so what reaches `structure_damaged` is a BLOW and not the weather.
func _reconcile() -> void:
	for s in places:
		for p in s.pieces:
			var key := _key(s, p)
			var was := float(_health.get(key, p.health))
			if p.health < was - 1e-4:
				Events.structure_damaged.emit(s.id, p.id, was - p.health)
				# The blow is seen landing, not only read off a wreck later: a party
				# working at a mast is a mast that shudders.
				var node: StructureModel = _nodes.get(key)
				if node != null and is_instance_valid(node):
					node.struck(clampf((was - p.health) / maxf(p.max_health, 0.01), 0.0, 1.0))
			_health[key] = p.health
			if p.ruined and not _wrecked.has(key):
				_wrecked[key] = true
				Events.structure_destroyed.emit(s.id, p.id)
				_on_wrecked(s, p)
			elif not p.ruined and _wrecked.has(key):
				_wrecked.erase(key)
				_realise(s, p)


func _note_health() -> void:
	for s in places:
		for p in s.pieces:
			_health[_key(s, p)] = p.health
			if p.ruined:
				_wrecked[_key(s, p)] = true


## A piece broken past mending: its drawing goes to wreckage, its footprint
## shrinks to what is left lying there, and a hearth goes cold.
func _on_wrecked(s: Settlement, p: Structure) -> void:
	if p.kind == StructureKind.HEARTH:
		_douse(p.pos)
		return
	# The one wreck that changes what happens next without changing the yard: the
	# readings it was taking go back to the place itself, at full strength, and
	# nothing else on the screen would say so.
	if StructureKind.lure(p.kind) > 0.0 and game.player != null and s.realm == realm_here() \
			and p.pos.distance_to(game.player.pos) <= EARSHOT:
		Events.message.emit("The decoy is down. Whatever reads %s now reads the place itself." % s.name)
	if StructureKind.masks(p.kind) and StructureKind.draw_power(p.kind) > 0.0 and game.player != null \
			and s.realm == realm_here() and s.centre.distance_to(game.player.pos) <= EARSHOT:
		Events.message.emit("The spoofer is broken. %s answers for itself again." % _said(s.name))
	var ghost: WorldProp = _ghosts.get(_key(s, p))
	if ghost != null:
		ghost.solid = StructureKind.solid(p.kind) * 0.5
	var node: StructureModel = _nodes.get(_key(s, p))
	if node != null:
		node.set_ruined(true)


# --- the world's own fire ----------------------------------------------------

func _fire_at(pos: Vector2) -> WorldProp:
	for q in game.query.props_near(pos, 1.0):
		if q.kind == PropKind.FIRE and not game.world.depleted.has(q.id) and q.pos.distance_to(pos) < 0.7:
			return q
	return null


## A hearth's fire is found by where it stands rather than by an id: prop ids are
## renumbered when a save is loaded, and a number that shifted would put out
## somebody else's fire.
func _douse(pos: Vector2) -> void:
	var fire := _fire_at(pos)
	if fire == null:
		return
	game.world.depleted[fire.id] = INF
	if game.view != null:
		game.view.refresh_props(fire)


# --- the catch-up ------------------------------------------------------------

## Settle every holding up to the world clock now. Cheap and idempotent: it runs
## whole slices from each holding's own timestamp, so calling it every sweep, once
## an hour or once after six hours away all give the same holding.
func settle_up() -> void:
	if game == null or game.clock == null:
		return
	var now := game.clock.minutes
	for s in places:
		# A holding out of this realm is settled by its own clock all the same,
		# under the weather of the landscape it was built in, which only the world
		# it stands in can be asked for.
		var land := &""
		if s.realm == realm_here() and game.world != null:
			land = BiomeRegistry.at(game.world, s.centre).id
		var ctx := {"seed": game.world.seed_value if game.world != null else 0, "land": land}
		var report := SettlementRules.catch_up(s, now, ctx)
		SettlementRules.wire_now(s, now, ctx)
		_announce(s, report)
	_note_health()


## A holding's name at the head of a sentence. String.capitalize() puts a capital
## on every word, and "The Holding" is a proper noun this game has not written.
static func _said(name: String) -> String:
	return name.substr(0, 1).to_upper() + name.substr(1) if name != "" else name


func _announce(s: Settlement, report: Dictionary) -> void:
	var ruined: Array = report.get("ruined", [])
	for id: int in ruined:
		var p := s.piece(id)
		if p != null and not _wrecked.has(_key(s, p)):
			Events.structure_destroyed.emit(s.id, p.id)
			_wrecked[_key(s, p)] = true
			_on_wrecked(s, p)
	var made: Dictionary = report.get("made", {})
	if not made.is_empty():
		_produced = true
	# Whoever has gone is let go of whether or not anybody was there to see it:
	# the books are kept even when the player is a day's walk away.
	var left: Array = report.get("left", [])
	for who: int in left:
		_send_away(s, who)
	var near := game.player != null and s.realm == realm_here() and s.centre.distance_to(game.player.pos) <= EARSHOT
	if not near:
		return
	if not made.is_empty():
		var parts := PackedStringArray()
		for id: StringName in made:
			parts.append(SettlementBuild.count_words(id, int(made[id])))
		Events.message.emit("%s laid by %s." % [_said(s.name), SettlementBuild.join_words(parts)])
	if not left.is_empty():
		Events.message.emit("Somebody has walked away from %s." % s.name)
	if bool(report.get("hungry", false)) and not s.people.is_empty():
		Events.hint.emit("%s has nothing to eat." % _said(s.name), "h")


# --- people ------------------------------------------------------------------

func _folk() -> Node:
	if _folk_system == null or not is_instance_valid(_folk_system):
		_folk_system = null
		for s in game.systems:
			if s.name == "folk" or s.name == "35_folk":
				_folk_system = s
	return _folk_system


## Somebody comes to live at the holding. A BED is what brings them (`_staff`
## refuses before this is ever called), and there are two ways they arrive.
##
## Near a village it is the SAME body that was already walking about: 35_folk's
## own row, moved onto the holding's books by the fields that system already
## keeps (`village`, `role`, `work`, `job_pos`), so the village visibly loses
## somebody and nothing here reaches into how a person walks, dresses or is drawn.
##
## **When there is no body to ask, the holding sends word instead**, and that is
## the path that makes a remote holding possible at all. 35_folk only builds
## villagers within 34 tiles of the PLAYER, so asking live bodies could only ever
## staff a holding founded next door to a village: everywhere else the answer was
## no, whatever the player built, and a fifth of the island could never be lived
## on. `world.villages` is data and is there whether a village is loaded or half
## an island away, so the nearest one within LODGE_REACH sends somebody out.
## Nothing is lost by their having no body yet: a resident's look is a number on
## the holding's own books and `_sync_people` stands them up from it, which is the
## same path a holding loaded from a save takes.
func _recruit(s: Settlement) -> int:
	var best := _villager_near(s)
	if best.is_empty() and _village_within(s, LODGE_REACH) < 0:
		return -1
	var who := s.take_person_id()
	s.people.append(who)
	# What they look like, kept as a number: a holding loaded from a save stands
	# its people up again from its own seed rather than from a body that is gone.
	s.looks[who] = s.id * 1013 + who
	if not best.is_empty():
		best["village"] = RESIDENT
		_bodies["%d:%d" % [s.id, who]] = best
	return who


## A villager already standing on the land and free to be asked, or {}.
func _villager_near(s: Settlement) -> Dictionary:
	var folk := _folk()
	if folk == null:
		return {}
	var rows: Array = folk.get("folk")
	if rows == null:
		return {}
	var best: Dictionary = {}
	var best_d := RECRUIT_REACH * RECRUIT_REACH
	for row: Dictionary in rows:
		if int(row.get("village", -1)) < 0 or row.get("state", &"out") != &"out":
			continue
		var d := (row.pos as Vector2).distance_squared_to(s.centre)
		if d < best_d:
			best_d = d
			best = row
	return best


## The nearest village that would send somebody, or -1. Read off the WORLD and
## never off live bodies, so it answers the same whether that village is loaded,
## asleep, or has never been near the player at all.
func _village_within(s: Settlement, reach: float) -> int:
	if game == null or game.world == null:
		return -1
	var best := -1
	var best_d := reach * reach
	for i in game.world.villages.size():
		var v: Dictionary = game.world.villages[i]
		var d := (v.get("pos", Vector2(-9999.0, -9999.0)) as Vector2).distance_squared_to(s.centre)
		if d < best_d:
			best_d = d
			best = i
	return best


## Put a resident on a piece: they walk to it and work there, through 35_folk's
## own behaviour for a villager with a job.
func _put_to_work(s: Settlement, who: int, p: Structure) -> void:
	var row: Dictionary = _bodies.get("%d:%d" % [s.id, who], {})
	if row.is_empty():
		return
	var from := p.pos + Vector2.from_angle(float(p.id) * 1.7) * maxf(StructureKind.solid(p.kind) + 0.6, 0.9)
	row["role"] = &"work"
	row["work"] = _work_for(p.kind)
	row["tool"] = _tool_for(p.kind)
	row["job_pos"] = from
	row["job_facing"] = (p.pos - from).angle()
	row["wait"] = 0.0


static func _work_for(kind: int) -> StringName:
	match StructureKind.family(kind):
		StructureKind.Family.FOOD: return &"work_dig"
		StructureKind.Family.WORK: return &"work_break"
	return &"work_cut"


static func _tool_for(kind: int) -> StringName:
	match StructureKind.family(kind):
		StructureKind.Family.FOOD: return &"mattock"
		StructureKind.Family.WORK: return &"pick"
	return &"billhook"


## Somebody taken off the holding by an outside hand — a snatcher, a raid settled
## on paper. The books and the body both, in one door, so nothing outside this
## package reaches into who staffs what: off whatever they were working, out of
## the people and their look forgotten, and the body let go of.
func lose_person(s: Settlement, who: int) -> void:
	if s == null:
		return
	for piece in s.pieces:
		if piece.staffed_by == who:
			piece.staffed_by = -1
	s.people.erase(who)
	@warning_ignore("return_value_discarded")
	s.looks.erase(who)
	_send_away(s, who)


## Somebody who has gone: their body goes back to being nobody's, and the holding
## forgets them.
func _send_away(s: Settlement, who: int) -> void:
	var key := "%d:%d" % [s.id, who]
	var row: Dictionary = _bodies.get(key, {})
	if not row.is_empty():
		row["role"] = &"walk"
		row["work"] = &""
	_bodies.erase(key)


## Stand up a body for every resident of every holding near the player, so a
## place that produced while nobody watched has somebody in it when they arrive.
func _sync_people() -> void:
	var folk := _folk()
	if folk == null or game.player == null:
		return
	for s in places:
		if s.realm != realm_here() or s.centre.distance_to(game.player.pos) > DRAW_REACH:
			continue
		for who: int in s.people:
			var key := "%d:%d" % [s.id, who]
			var row: Dictionary = _bodies.get(key, {})
			if not row.is_empty() and is_instance_valid(row.get("model") as Node):
				continue
			var seed_value := int(s.looks.get(who, s.id * 1013 + who))
			var spot := s.centre + Vector2.from_angle(float(who) * 2.39) * 1.6
			var queue: Array = folk.get("queue")
			if queue == null:
				return
			queue.append({"look": PersonLook.random(seed_value), "home": spot, "door": spot,
				"role": &"idle", "village": RESIDENT, "h": Rng.hash01(seed_value, 3)})
			if not bool(folk.call("pump")):
				continue
			var rows: Array = folk.get("folk")
			_bodies[key] = rows[rows.size() - 1]
			for p in s.pieces:
				if p.staffed_by == who:
					_put_to_work(s, who, p)


# --- drawing -----------------------------------------------------------------

func _node_for(s: Settlement, p: Structure) -> StructureModel:
	var key := _key(s, p)
	var node: StructureModel = _nodes.get(key)
	if node != null and is_instance_valid(node):
		return node
	if not StructureModel.drawn(p.kind):
		return null
	node = StructureModel.create(p.kind, p.variant)
	node.lit = false
	node.build(game.view.world_material() if game.view != null else null)
	node.position = game.world.to_3d(p.pos)
	node.rotation.y = -p.facing
	node.set_ruined(p.ruined)
	add_child(node)
	_nodes[key] = node
	return node


func _sync_nodes() -> void:
	if game == null or game.world == null or game.player == null:
		return
	var weather := Weather.at_type(game.world.seed_value, game.clock.minutes,
		BiomeRegistry.at(game.world, game.player.pos).id)
	var hour := game.clock.hour()
	var want: Dictionary = {}
	for s in places:
		if s.realm != realm_here() or s.centre.distance_to(game.player.pos) > DRAW_REACH:
			continue
		for p in s.pieces:
			var key := _key(s, p)
			want[key] = true
			var node := _node_for(s, p)
			if node == null:
				continue
			node.set_ruined(p.ruined)
			node.set_lit(_lit(s, p, weather, hour))
			if p.kind == StructureKind.WIND_SPINNER:
				var share := 0.0 if p.ruined else SettlementRules.source(p.kind, weather, hour) * p.condition()
				node.set_spin(share)
	for key: String in _nodes.keys():
		if want.has(key):
			continue
		var node: StructureModel = _nodes[key]
		if is_instance_valid(node):
			node.queue_free()
		_nodes.erase(key)


## Whether a machine's own light is still burning on this piece. It is the
## holding saying out loud that it has power, which is the thing a player should
## be able to read from a hillside (docs/ART.md §10).
func _lit(s: Settlement, p: Structure, weather: Dictionary, hour: float) -> bool:
	if p.ruined:
		return false
	match p.kind:
		StructureKind.BATTERY_STACK:
			return s.charge > 0.05
		StructureKind.SOLAR_ARRAY:
			# An array's lamp says it is MAKING power, not that the holding has
			# some — which is the one thing about it a player has to learn, and
			# the reason the mast is up at noon and down at midnight. Same rule
			# the power itself runs on, so the lamp cannot disagree with the wire.
			return SettlementRules.source(p.kind, weather, hour) > 0.05 and p.condition() >= Structure.WORKS_ABOVE
		StructureKind.RADIO_MAST, StructureKind.SPOOFER, StructureKind.TURRET:
			return p.powered and not p.off
	return false


func _forget(s: Settlement, p: Structure) -> void:
	var key := _key(s, p)
	var ghost: WorldProp = _ghosts.get(key)
	if ghost != null and game.query != null:
		game.query.remove_prop(ghost)
		_ghosts.erase(key)
	var node: StructureModel = _nodes.get(key)
	if node != null and is_instance_valid(node):
		node.queue_free()
	_nodes.erase(key)
	_health.erase(key)
	_wrecked.erase(key)
	if p.kind == StructureKind.HEARTH:
		_douse(p.pos)


func _key(s: Settlement, p: Structure) -> String:
	return "%d:%d" % [s.id, p.id]


# --- the frame ---------------------------------------------------------------

func _process(delta: float) -> void:
	if game == null or game.world == null:
		return
	_read_keys()
	_sweep -= delta
	if _sweep > 0.0:
		return
	_sweep = SWEEP
	for s in places:
		s.night = SettlementRules.night_at(game.clock.minutes)
	settle_up()
	_sync_nodes()
	_sync_people()


## A blow from any hand at all has to be felt at once: the raids package holds a
## Settlement and not this system, and a wall that went on standing for a second
## after it fell would be a lie in the picture. It is on the fixed step rather
## than the frame because after a slow frame — a world being generated, a chunk
## coming in — several physics steps run with no frame between them, and a blow
## struck in one of those must not wait for the drawing to catch up.
func _physics_process(_delta: float) -> void:
	if game != null and game.world != null:
		_reconcile()


func _read_keys() -> void:
	if not _went_down(&"holding"):
		return
	if screen == null or _slate() == null:
		return
	if screen.is_open:
		@warning_ignore("return_value_discarded")
		screen.handle(&"holding")
		return
	@warning_ignore("return_value_discarded")
	_ui.call("open_screen", &"holding")


func _went_down(action: StringName) -> bool:
	var now := InputMap.has_action(action) and Input.is_action_pressed(action)
	var was: bool = _held.get(action, false)
	_held[action] = now
	return (now and not was) or (InputMap.has_action(action) and Input.is_action_just_pressed(action))


# --- staging ------------------------------------------------------------------

## `--holding=KIND[,KIND]`: a holding in an arc in front of the player, free and
## staffed, so a shot or a tour can begin at a place that already exists. Its
## store is seeded too, because a page showing what is laid by has to have
## something on it (staging, like --ui-demo, and never a normal start).
func _from_options() -> void:
	if game.options == null or game.options.holding.is_empty():
		return
	var kinds: Array[int] = []
	for word: String in game.options.holding:
		var kind := _kind_named(word)
		if kind < 0:
			push_warning("--holding: no piece called %s" % word)
			continue
		kinds.append(kind)
	if kinds.is_empty():
		return
	var s := found(realm_here(), game.player.pos)
	var placed := 0
	for i in kinds.size():
		var kind: int = kinds[i]
		# Set down the way a player would: each one a step further round, on
		# ground the piece would have been allowed on.
		var turn := -0.9 + 1.8 * (float(i) + 0.5) / float(kinds.size())
		var spot := _room_near(kind, game.player.facing + turn, 2.2 + 0.7 * float(i % 3))
		if not is_finite(spot.x):
			push_warning("--holding: no room for a %s anywhere near the player" % StructureKind.display_name(kind))
			continue
		var p := place_piece(s, kind, spot, game.player.facing + turn + PI)
		placed += 1
		if StructureKind.needs_staff(kind):
			@warning_ignore("return_value_discarded")
			_staff(s, p, true)
	if placed == 0:
		return
	_recentre(s)
	s.stores[&"berries"] = 3
	# Its cells full, as a place somebody has lived in for a while would have them.
	s.charge = maxf(2.0, s.charge_room())
	_sync_people()


## A clear patch for a staged piece: the way it was asked for first, then round
## and outward from there. A shot staged at a village spawn has houses, fences
## and a tip in every direction, and a holding that quietly puts up two of its
## five pieces is a picture that lies about what was asked for.
func _room_near(kind: int, want_angle: float, want_far: float) -> Vector2:
	var from := game.player.pos
	var level := game.world.level_at(floori(from.x), floori(from.y))
	var r := maxf(StructureKind.solid(kind), 0.5)
	for ring in 6:
		var far := want_far + r + float(ring) * 1.3
		for step in 12:
			var turn := (float((step + 1) / 2) * (1 if step % 2 == 0 else -1)) * 0.42
			var spot := from + Vector2.from_angle(want_angle + turn) * far
			if _clear(spot, r, level):
				return spot
	return Vector2(INF, INF)


static func _kind_named(word: String) -> int:
	var want := word.strip_edges().to_lower().replace("_", " ")
	for kind: int in StructureKind.BUILDABLE:
		if StructureKind.display_name(kind) == want:
			return kind
	return -1


# --- tours -------------------------------------------------------------------

## What a tour may await or claim a frame holds.
func tour_seen(what: StringName) -> bool:
	var s := here()
	match what:
		&"holding":
			return s != null and not s.pieces.is_empty()
		&"built":
			return _built_one
		&"staffed":
			if s == null:
				return false
			for p in s.pieces:
				if p.staffed_by >= 0:
					return true
			return false
		&"produced":
			return _produced
		&"stores":
			return s != null and s.stored() > 0.0
		&"worn":
			if s == null:
				return false
			for p in s.pieces:
				if p.condition() < 0.999:
					return true
			return false
		&"holding_people":
			return s != null and not s.people.is_empty()
		&"powered":
			if s == null:
				return false
			for p in s.pieces:
				if p.powered:
					return true
			return false
		&"app:holding":
			return screen != null and screen.is_open
		&"lure":
			# A decoy standing out past the yard, where it is somewhere else.
			return s != null and not s.lures().is_empty()
		&"spoofing":
			if s == null:
				return false
			for p in s.pieces:
				if p.standing() and StructureKind.masks(p.kind) and StructureKind.draw_power(p.kind) > 0.0 and p.powered:
					return true
			return false
	# A frame that says "out on its own" has to prove it: further from every
	# village than 35_folk will ever build a body, which is exactly the wall that
	# used to make such a holding unstaffable.
	if what == &"holding_remote":
		return s != null and _village_within(s, RECRUIT_REACH) < 0
	if String(what).begins_with("piece:"):
		var kind := _kind_named(String(what).substr(6))
		if kind < 0 or s == null:
			return false
		for p in s.pieces:
			if p.kind == kind and p.standing():
				return true
	return false


# --- saving ------------------------------------------------------------------

func _save() -> Variant:
	var out := []
	for s in places:
		out.append(s.as_dict())
	return {"places": out, "next_id": _next_id}


func _load(v: Variant) -> void:
	var d := v as Dictionary
	if d == null:
		return
	for key: String in _nodes:
		var node: StructureModel = _nodes[key]
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()
	for key: String in _ghosts:
		if game != null and game.query != null:
			game.query.remove_prop(_ghosts[key])
	_ghosts.clear()
	_health.clear()
	_wrecked.clear()
	_bodies.clear()
	places.clear()
	for p: Variant in d.get("places", []):
		places.append(Settlement.from_dict(p as Dictionary))
	_next_id = SaveCodec.to_int(d.get("next_id", places.size() + 1), places.size() + 1)
	# A loaded holding is stood back up: footprints, drawings and the fire in the
	# hearth. `started()` settles the hours it was away after every system's load.
	for s in places:
		for piece in s.pieces:
			_realise(s, piece)
