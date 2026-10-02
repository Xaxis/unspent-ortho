extends TestCase
## A ruin's walls stop a body (RuinWalls, 23_ruins): walking straight at a wall
## of a croft ruin, or at a tower stump in the city, ends short of it.

static var _w: WorldData = null


static func _world() -> WorldData:
	if _w == null:
		_w = WorldGen.generate(7, 512)
	return _w


## The first ruin of the kind asked (a tower stump or a croft).
static func _ruin(w: WorldData, tower: bool) -> WorldProp:
	for p in w.each_prop():
		if p.kind != PropKind.RUIN:
			continue
		var c := maxi(Country.COAST, w.country_at(floori(p.pos.x), floori(p.pos.y)))
		if (BiomeDressing.of(c).ruin_form == &"tower") == tower:
			return p
	return null


## Walk from `from` straight at `to` in small steps, as a body does.
static func _walk(q: WorldQuery, from: Vector2, to: Vector2) -> Vector2:
	var p := from
	for i in 120:
		var d := to - p
		if d.length() < 0.01:
			break
		p = q.move_body(p, d.limit_length(0.05), Tuning.PLAYER_RADIUS)
	return p


func _check(tower: bool) -> void:
	var w := _world()
	var r := _ruin(w, tower)
	var name := "tower" if tower else "croft"
	check(r != null, "seed 7 has a %s ruin" % name)
	if r == null:
		return
	var q := WorldQuery.new(w)
	q.set_blocks(&"ruins", RuinWalls.of_world(w))
	var c := maxi(Country.COAST, w.country_at(floori(r.pos.x), floori(r.pos.y)))
	var walls := RuinWalls.model(PropModels.variant_of(r, w.seed_value, c), tower)
	# A point on the model's walls, in the world: aim at it from outside.
	var m: Vector3 = walls[0]
	var target := r.pos + Vector2(m.x, m.y).rotated(r.rot) * r.scale
	var out := (target - r.pos).normalized()
	var start := target + out * 2.5
	var end := _walk(q, start, target)
	gt(end.distance_to(target), 0.15, "%s ruin: a body walking at its wall stops short (%.2f from it)" % [name, end.distance_to(target)])


func test_a_body_stops_at_a_croft_ruins_wall() -> void:
	_check(false)


func test_a_body_stops_at_a_tower_stumps_wall() -> void:
	_check(true)


## A drowned block's whole plan stops a body, the corners its own circle cannot
## reach included: a body stood inside the box, and the shoulder camera with it.
func test_a_body_stops_at_a_drowned_blocks_corner() -> void:
	var w := _world()
	var r: WorldProp = null
	for p in w.each_prop():
		if p.kind == PropKind.DROWNED_SHELL and PropModels.variant_of(p, w.seed_value, w.dress_country(floori(p.pos.x), floori(p.pos.y))) % RuinWalls.DrownedCity.SHELLS.size() != 3:
			r = p
			break
	check(r != null, "seed 7 has a drowned block")
	if r == null:
		return
	var q := WorldQuery.new(w)
	q.set_blocks(&"ruins", RuinWalls.of_world(w))
	var shape: Dictionary = RuinWalls.DrownedCity.SHELLS[PropModels.variant_of(r, w.seed_value, w.dress_country(floori(r.pos.x), floori(r.pos.y))) % RuinWalls.DrownedCity.SHELLS.size()]
	# Its canal face's corner, in the world: aim at it from out past it.
	var corner := Vector2(RuinWalls.DrownedCity.BLOCK_DEEP * 0.5, float(shape.d) * 0.5)
	var target := r.pos + corner.rotated(r.rot) * r.scale
	var out := (target - r.pos).normalized()
	var end := _walk(q, target + out * 2.5, target)
	gt(end.distance_to(target), 0.15, "a body walking at a drowned block's corner stops short (%.2f from it)" % end.distance_to(target))
