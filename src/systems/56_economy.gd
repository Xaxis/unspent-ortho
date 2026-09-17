extends GameSystem
## The gear economy inside a running game (docs/VISION.md §6.1). It owns three
## things and nothing else:
##
##   the declaration  `GearEconomy.declare()` pours the content tables into
##                    `Materials` and `Drops` before anything reads them
##   what a kill gives up  the elite part a machine is carrying, rolled off the
##                    world seed and a count this system keeps, so a player cannot
##                    reload to reroll a keeper's lens
##   what a hard pour costs  a kiln or jig recipe for an elite piece can come out
##                    flawed or ruined (`CraftTiers`), which is the other half of
##                    difficulty: a prime piece is a risk, not only a price
##
## It never touches the fight, the loadout or the slate. The plate a machine drops
## is still the roster's (`drops`, spent by 40_fight); this adds only what the
## economy declares on top, so neither package has to know about the other.
##
## Look at it:
##   tools/tour.sh tours/gear-economy.tour --seed=1 --hour=11 --weather=clear:0

## A body that goes down further away than this was not your fight, and its parts
## are not in your hands.
const REACH := 24.0


## Kills this game has seen, and risky pours it has made: the two counts the
## deterministic rolls are indexed by. Saved, so a reload cannot reroll either.
var _kills := 0
var _pours := 0
## What the economy has handed over this game, for the tour's awaits.
var _given: Dictionary = {}
var _spoiled := 0


func setup(g: Game) -> void:
	super.setup(g)
	GearEconomy.declare()
	Events.killed.connect(_on_killed)
	Events.made.connect(_on_made)
	SaveGame.register(&"economy", _save, _load)


func _exit_tree() -> void:
	if Events.killed.is_connected(_on_killed):
		Events.killed.disconnect(_on_killed)
	if Events.made.is_connected(_on_made):
		Events.made.disconnect(_on_made)


# --- what a kill gives up ------------------------------------------------------

func _on_killed(kind: StringName, at: Vector3) -> void:
	if game == null or game.player == null:
		return
	if Drops.table(kind).is_empty():
		return
	if game.world.to_3d(game.player.pos).distance_to(at) > REACH:
		return
	_kills += 1
	var land := BiomeRegistry.at(game.world, game.player.pos).id
	var said := PackedStringArray()
	for row: Dictionary in GearEconomy.spoils(kind, game.world.seed_value, _kills, land):
		var id := StringName(row.get("item", &""))
		var n := int(row.get("count", 1))
		if id == &"" or n <= 0 or Items.def(id).is_empty():
			continue
		game.inventory.add(id, n)
		_given[id] = int(_given.get(id, 0)) + n
		Events.took.emit(id, n)
		if EliteStock.is_elite(id):
			said.append(Items.display_name(id))
	if said.is_empty():
		return
	# An elite part is the reason the fight was worth having: it is said out loud,
	# once, in the words of the thing itself.
	Events.sfx.emit(&"took", at)
	Events.message.emit("Out of it: %s." % ", ".join(said))


# --- what a hard pour costs ----------------------------------------------------

func _on_made(item: StringName, count: int) -> void:
	if game == null or count <= 0 or Items.def(item).is_empty():
		return
	var r := _risky_recipe(item)
	if r.is_empty():
		return
	_pours += 1
	var twin := _flawed_twin(item)
	var how := CraftTiers.outcome(CraftTiers.of_recipe(r), twin != &"",
		game.world.seed_value, _pours)
	if how == &"made":
		return
	if game.inventory.count(item) <= 0:
		return
	game.inventory.remove(item)
	if how == &"flawed":
		game.inventory.add(twin)
		_given[twin] = int(_given.get(twin, 0)) + 1
	else:
		_spoiled += 1
		game.inventory.add(CraftTiers.SPOIL_ITEM, 1)
	Events.sfx.emit(&"work_broken", game.player.position if game.player != null else Vector3.ZERO)
	Events.message.emit(CraftTiers.said(how, Items.display_name(item)))


## The recipe that made `item`, if making it can go wrong. Only the economy's own
## hard work is risky: a cemented knife is the same afternoon at a kiln it always
## was, and nothing this package added may quietly change that.
func _risky_recipe(item: StringName) -> Dictionary:
	if not (EliteStock.is_elite(item) or GearTree.grade(item) >= Rarity.RARE):
		return {}
	for r: Dictionary in Sources.recipes_making(item):
		if CraftTiers.risky(CraftTiers.of_recipe(r)):
			return r
	return {}


## The piece this one comes out as when a pour is flawed but usable: one socket
## fewer and no name on it, declared by the tree, never invented here.
func _flawed_twin(item: StringName) -> StringName:
	var twin := StringName(GearTree.row(item).get("flawed", &""))
	return twin if Items.def(twin).is_empty() == false else &""


# --- tours ---------------------------------------------------------------------

## Subjects a frame of this package can claim, and awaits it can wait on.
func tour_seen(what: StringName) -> bool:
	var s := String(what)
	if s.begins_with("elite:"):
		return game.inventory.count(StringName(s.substr(6))) > 0
	if s.begins_with("grade:"):
		return _carries_grade(Rarity.of_name(StringName(s.substr(6))))
	if s.begins_with("modifier:"):
		return _fitted().has(StringName(s.substr(9)))
	match what:
		&"spoils": return not _given.is_empty()
		&"spoiled": return _spoiled > 0
		&"modifier": return not _modifiers_fitted().is_empty()
		&"decision": return not _modifiers_fitted().is_empty()
		&"conflict": return not Modifiers.conflicts(_fitted()).is_empty()
		&"combo": return not Modifiers.combos(_fitted()).is_empty()
		&"mended": return _mended_fitted()
	return false


## Everything fitted on the body right now, asked of the gear system rather than
## held here: 54_gear owns the loadout and this package never writes to it.
func _fitted() -> Array[StringName]:
	for sys in game.systems:
		if not String(sys.name).contains("54_gear"):
			continue
		var l: Loadout = sys.get("loadout")
		if l != null:
			return l.all_ids()
	return [] as Array[StringName]


func _modifiers_fitted() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in _fitted():
		if ModifierTable.has(id):
			out.append(id)
	return out


func _mended_fitted() -> bool:
	for id in _fitted():
		if Gear.is_mended(id):
			return true
	return false


func _carries_grade(grade: int) -> bool:
	for id: StringName in GearTree.at_grade(grade):
		if game.inventory.count(id) > 0:
			return true
	return false


# --- saving --------------------------------------------------------------------

func _save() -> Variant:
	return {"kills": _kills, "pours": _pours, "spoiled": _spoiled}


func _load(v: Variant) -> void:
	if not (v is Dictionary):
		return
	var d := v as Dictionary
	_kills = SaveCodec.to_int(d.get("kills", 0))
	_pours = SaveCodec.to_int(d.get("pours", 0))
	_spoiled = SaveCodec.to_int(d.get("spoiled", 0))
