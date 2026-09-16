extends GameSystem
## The places the player built, and the register two packages meet on
## (docs/VISION.md §9). Reachable as `game.settlements`.
##
## This is the seam, not the game: it holds the settlements, saves them, and
## says who is where. The settlement package builds, staffs and produces on top
## of it; the raids package reads `signature()` off these and writes `attention`.
## Neither has to know the other exists.
##
## Other systems reach it the usual way, by name:
##   for sys in game.systems: if sys.name == "46_settlements": ...

var places: Array[Settlement] = []
var _next_id := 1


func setup(g: Game) -> void:
	super.setup(g)
	SaveGame.register(&"settlements", _save, _load)


## Start a place at `at` in `realm`. The founding is announced so the guide, the
## slate and the raids package all learn about it the same way.
func found(realm: int, at: Vector2, called: String = "") -> Settlement:
	var s := Settlement.new(_next_id, realm, at, called)
	_next_id += 1
	places.append(s)
	Events.settlement_founded.emit(s.id)
	return s


func get_one(id: int) -> Settlement:
	for s in places:
		if s.id == id:
			return s
	return null


func all(realm: int = -1) -> Array[Settlement]:
	if realm < 0:
		return places.duplicate()
	var out: Array[Settlement] = []
	for s in places:
		if s.realm == realm:
			out.append(s)
	return out


## Every place whose centre is within `radius` of `pos`: what a machine passing
## through asks before it notices anything.
func at(realm: int, pos: Vector2, radius: float) -> Array[Settlement]:
	var out: Array[Settlement] = []
	for s in places:
		if s.realm == realm and s.centre.distance_to(pos) <= radius:
			out.append(s)
	return out


## The place nearest `pos` in `realm`, or null.
func nearest(realm: int, pos: Vector2) -> Settlement:
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


func _save() -> Variant:
	var out := []
	for s in places:
		out.append(s.as_dict())
	return {"places": out, "next_id": _next_id}


func _load(v: Variant) -> void:
	var d := v as Dictionary
	if d == null:
		return
	places.clear()
	for p: Variant in d.get("places", []):
		places.append(Settlement.from_dict(p as Dictionary))
	_next_id = SaveCodec.to_int(d.get("next_id", places.size() + 1), places.size() + 1)
