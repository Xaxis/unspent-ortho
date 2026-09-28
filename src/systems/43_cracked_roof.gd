extends GameSystem
## THE CRACKED ROOF, IN PLAY (CrackedRoof, FightSim.hangings): the stones round
## a cave's tears hung in the fight near the player, drawn, and brought down.
## Every READ_EVERY seconds the stones within READ_R tiles are hung in the sim
## (the grapple's line takes them, AbilityGrapple) and those left behind are let
## go; each is drawn hanging from the lid, shakes and sheds grit while it is being
## pulled, and falls: drops, breaks on the floor and lies there. A stone down is
## down for good, remembered by its tile per realm and saved.

const CrackedStone := preload("res://src/models/props/cracked_stone.gd")
const READ_R := 22
const READ_EVERY := 0.4
## Seconds a stone takes to come down once it lets go.
const DROP := 0.22

var sim: FightSim
var _read_at := 0.0
var _world: WorldData = null
## Tile key -> {id, node, at, y, pulled}.
var _hung := {}
## Realm key -> {tile key string: true}: stones brought down.
var _down := {}
## Stones on their way down: {node, from, to, t}.
var _dropping: Array[Dictionary] = []


func setup(g: Game) -> void:
	super.setup(g)
	sim = g.player.sim
	SaveGame.register(&"cracked_roof", _save, _load)


func _process(delta: float) -> void:
	if sim == null or game.world == null:
		return
	if game.world != _world:
		_let_all_go()
		_world = game.world
	_drop(delta)
	_watch()
	_read_at -= delta
	if _read_at > 0.0:
		return
	_read_at = READ_EVERY
	_read()


func _realm() -> String:
	for sys in game.systems:
		if sys.has_method(&"realm_here"):
			return str(sys.call(&"realm_here"))
	return "surface"


func _down_here() -> Dictionary:
	var k := _realm()
	if not _down.has(k):
		_down[k] = {}
	return _down[k]


static func _key(t: Vector2i) -> String:
	return "%d,%d" % [t.x, t.y]


## Hang what is near, let go what is not.
func _read() -> void:
	if not game.world.has_overhead():
		if not _hung.is_empty():
			_let_all_go()
		return
	var down := _down_here()
	var want := {}
	for s: Dictionary in CrackedRoof.stones_near(game.world, sim.hero.pos, READ_R):
		var key := _key(s.key)
		if down.has(key):
			continue
		want[key] = true
		if _hung.has(key):
			continue
		var id := sim.hang(s.at, float(s.y))
		var node := MeshInstance3D.new()
		node.mesh = CrackedStone.mesh(int(s.key.x) * 73 + int(s.key.y) * 31, float(s.top) - float(s.y))
		node.material_override = game.view.world_material()
		node.position = Vector3((s.at as Vector2).x, float(s.top), (s.at as Vector2).y)
		game.add_child(node)
		_hung[key] = {"id": id, "node": node, "at": s.at, "y": float(s.y), "top": float(s.top), "pulled": false}
	for key: String in _hung.keys():
		if want.has(key):
			continue
		var h: Dictionary = _hung[key]
		if sim.unhang(int(h.id)):
			(h.node as Node).queue_free()
			_hung.erase(key)


## A stone being pulled shakes and sheds; one the sim has let fall comes down.
func _watch() -> void:
	var live := {}
	for h: Dictionary in sim.hangings:
		live[int(h.id)] = h
	for key: String in _hung.keys():
		var h: Dictionary = _hung[key]
		var node: MeshInstance3D = h.node
		var s: Variant = live.get(int(h.id))
		if s != null:
			if float((s as Dictionary).falls_at) >= 0.0:
				if not bool(h.pulled):
					h.pulled = true
					MobFx.puffs(game, node.position, Vector2.ZERO, Palette.LINEN[3], 4, 0.5, int(h.id))
					Events.sfx.emit(&"break", node.position)
				var t := Time.get_ticks_msec() * 0.06
				var rest := Vector3((h.at as Vector2).x, float(h.top), (h.at as Vector2).y)
				node.position = rest + Vector3(sin(t * 1.7), 0.0, cos(t * 1.3)) * 0.04
			continue
		# Fell: gone from the sim. Down it comes, and it stays down.
		_down_here()[key] = true
		_hung.erase(key)
		var floor_at := game.world.to_3d(h.at)
		# Down by its whole length and a little more: the tip strikes the floor.
		_dropping.append({"node": node, "from": node.position, "to": floor_at + Vector3(0, (float(h.top) - float(h.y)) * 0.8, 0), "t": 0.0, "at": h.at, "id": int(h.id)})


func _drop(delta: float) -> void:
	for i in range(_dropping.size() - 1, -1, -1):
		var d := _dropping[i]
		var node: MeshInstance3D = d.node
		d.t = float(d.t) + delta / DROP
		var t := minf(1.0, float(d.t))
		if is_instance_valid(node):
			node.position = (d.from as Vector3).lerp(d.to, t * t)
		if t < 1.0:
			continue
		_dropping.remove_at(i)
		var at3 := game.world.to_3d(d.at)
		if is_instance_valid(node):
			node.queue_free()
		var rubble := MeshInstance3D.new()
		rubble.mesh = CrackedStone.fallen(int(d.id) * 13 + 5)
		rubble.material_override = game.view.world_material()
		rubble.position = at3
		game.add_child(rubble)
		MobFx.puffs(game, at3 + Vector3(0, 0.3, 0), Vector2.ZERO, Palette.LINEN[3], 8, 1.1, int(d.id) + 3)
		Events.sfx.emit(&"fall_boom", at3)
		_fell_at = Time.get_ticks_msec() / 1000.0


func _let_all_go() -> void:
	for key: String in _hung.keys():
		var h: Dictionary = _hung[key]
		if sim != null:
			sim.unhang(int(h.id))
		if is_instance_valid(h.node):
			(h.node as Node).queue_free()
	_hung.clear()


func _save() -> Variant:
	var out := {}
	for k: String in _down:
		out[k] = (_down[k] as Dictionary).keys()
	return out


func _load(v: Variant) -> void:
	_down.clear()
	if not v is Dictionary:
		return
	for k: Variant in v:
		var kept := {}
		var keys: Variant = v[k]
		if keys is Array:
			for key: Variant in keys:
				kept[str(key)] = true
		_down[str(k)] = kept
	_let_all_go()


## Tour: `near cracked_stone` stands the player a grapple's throw off the nearest
## stone hanging, facing it; `tour_seen` answers `stone_fell` for a moment after
## one lands.
const TOUR_PLACES: Array[String] = ["cracked_stone"]
## Off it by this much: within the line's reach, and far enough that a stone up
## under the lid is in the frame over the shoulder.
const STAND_OFF := 6.5
var _face := NAN


func tour_place(what: String) -> Vector2:
	if what != "cracked_stone" or game.world == null:
		return Vector2.INF
	var best: Dictionary = {}
	for s: Dictionary in CrackedRoof.stones_near(game.world, game.player.pos, 60):
		if _down_here().has(_key(s.key)):
			continue
		if best.is_empty() or (s.at as Vector2).distance_to(game.player.pos) < (best.at as Vector2).distance_to(game.player.pos):
			best = s
	if best.is_empty():
		return Vector2.INF
	for i in 16:
		var off := Vector2.from_angle(TAU * i / 16.0) * STAND_OFF
		var p: Vector2 = (best.at as Vector2) + off
		# On ground a walk leads from to the stone's own, so nothing stands between.
		if game.query.body_fits(p, Tuning.PLAYER_RADIUS, null, true, FightSim.HERO_TALL) \
				and NavField.line_walkable(game.world, p, best.at, 0.3):
			_face = (-off).angle()
			return p
	return Vector2.INF


func tour_face(what: String) -> float:
	return _face if what == "cracked_stone" else NAN


var _fell_at := -INF


func tour_seen(what: StringName) -> bool:
	return what == &"stone_fell" and Time.get_ticks_msec() / 1000.0 - _fell_at < 1.5
