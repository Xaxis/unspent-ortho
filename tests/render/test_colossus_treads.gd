extends TestCase
## A COLOSSUS'S FOOT IN THE REGION (src/core/colossus/colossus_treads.gd,
## src/core/worldgen/gen_treads.gd, 19_colossi): the craters world generation
## cuts are where the feet really come down, every lap; a foot standing in one
## stops a body, puts out one caught under it and crushes what stands there; and
## the near foot is the far one's shape where one hands over to the other.

const Def := preload("res://src/core/colossus/colossus_def.gd")
const Route := preload("res://src/core/colossus/colossus_route.gd")
const Walk := preload("res://src/core/colossus/colossus_walk.gd")
const Treads := preload("res://src/core/colossus/colossus_treads.gd")
const FootModel := preload("res://src/models/colossus_foot_model.gd")
const GenTreads := preload("res://src/core/worldgen/gen_treads.gd")
const Model := preload("res://src/models/colossus_model.gd")

const BIG := 1840

static var _world: WorldData


## The shipped world on seed 7, grown once for the file.
func _grown() -> WorldData:
	if _world == null:
		_world = WorldGen.generate(7, BIG)
	return _world


func _treads(w: WorldData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: Dictionary in w.landmarks:
		if StringName(m.get("kind", &"")) == &"tread":
			out.append(m)
	return out


## Only a walker whose route passes over the island sets feet near it, and only
## a world big enough to be passed over gets any: a small world's one walker is
## out on the skyline.
func test_only_the_straddling_walker_wants_treads() -> void:
	eq(Treads.wanted(7, 256).size(), 0, "a small world wants none")
	var want: Array = Treads.wanted(7, BIG)
	gt(float(want.size()), 0.0, "the shipped world wants some")
	var legs := {}
	for row: Dictionary in want:
		eq(row.walker, &"tripod_c", "only the straddling walker")
		legs[row.leg] = true
	eq(legs.size(), want.size(), "each on a leg of its own")


## A TREAD IS WHERE THE FOOT REALLY STANDS: handed its treads, the walk puts
## that plant exactly on the crater, the foot stays there, facing one way, for
## the whole of its rest, and its three pads are the crater's three pads.
func test_the_foot_stands_in_its_own_tread() -> void:
	var d: RefCounted = Def.walkers(BIG)[2]
	var r: RefCounted = Route.make(d, 7, BIG)
	var row: Dictionary = Treads.wanted(7, BIG)[0]
	var at := Vector2(900.0, 700.0)
	var yaw := 0.4
	Treads.hand_over([d], [r], [{"kind": &"tread", "pos": at, "walker": d.id, "leg": row.leg, "j": row.j, "yaw": yaw, "floor": 2.5}])
	var k: int = row.leg
	var j: int = row.j
	var p := Walk.plant(d, r, k, j)
	near(Vector2(p.x, p.z).distance_to(at), 0.0, 1e-3, "the plant is the tread")
	near(p.y, 2.5, 1e-4, "on the crater floor")
	near(Walk.plant(d, r, k, j + r.cycles()).distance_to(p), 0.0, 1e-3, "and it is the same plant a lap on")
	var down := Treads.lands_at(d, r, k, j)
	var before: Array = Walk.foot(d, r, k, fposmod(down - 1.0 + r.offset, r.lap_minutes()))
	var after: Array = Walk.foot(d, r, k, fposmod(down + 1.0 + r.offset, r.lap_minutes()))
	gt(float(before[1]), 0.9, "a minute before, it is at the end of its swing")
	lt(float(after[1]), 0.0, "a minute after, it is down")
	# Through its whole rest: still, facing one way, pads on the crater's.
	var rest: float = float(d.cycle_minutes) * (1.0 - d.swing_share()) - 2.0
	var want_pads := Treads.pads(d, at, yaw)
	var worst := 0.0
	var t := down + 1.0
	while t < down + rest:
		var pose: Dictionary = Walk.pose(d, r, t)
		var bone: Transform3D = pose.bones[3 + 3 * k]
		near(float(pose.yaws[k]), yaw, 1e-5, "facing the way it was set down")
		for toe: int in int(d.toes.size()):
			var tt: Vector3 = d.toe(toe)
			var sole := bone * (Vector3(cos(tt.x), 0.0, sin(tt.x)) * tt.y + Vector3(0.0, -float(d.ankle_up), 0.0))
			var pad: Vector3 = want_pads[toe]
			worst = maxf(worst, Vector2(sole.x, sole.z).distance_to(Vector2(pad.x, pad.y)) + absf(sole.y - 2.5))
		t += 17.0
	lt(worst, 1e-2, "every pad on its crater's pad, the whole rest (%.4f m off)" % worst)


## Over a tread, the walk says how high the foot is, coming down and going up.
func test_a_foot_coming_down_into_its_tread_is_seen_coming() -> void:
	var d: RefCounted = Def.walkers(BIG)[2]
	var r: RefCounted = Route.make(d, 7, BIG)
	var row: Dictionary = Treads.wanted(7, BIG)[0]
	Treads.hand_over([d], [r], [{"kind": &"tread", "pos": Vector2(900, 700), "walker": d.id, "leg": row.leg, "j": row.j, "yaw": 0.0, "floor": 1.0}])
	var down := Treads.lands_at(d, r, row.leg, row.j)
	var last := INF
	for m: float in [down - 30.0, down - 12.0, down - 4.0, down - 1.0]:
		var o: Array = Treads.over(d, r, m)
		eq(o.size(), 1, "coming down at %.0f" % (m - down))
		if o.size() == 1:
			lt(float(o[0].height), last, "lower every minute")
			last = float(o[0].height)
			check(not bool(o[0].planted), "not down yet")
	var now: Array = Treads.over(d, r, down + 5.0)
	eq(now.size(), 1, "and standing in it")
	if now.size() == 1:
		check(bool(now[0].planted), "down")
		near(float(now[0].height), 0.0, 1e-3, "on the floor")


## The near foot and the far body are one shape where they meet: the stub's
## radius at the seam is the far shin's there.
func test_the_near_foot_meets_the_far_leg_at_the_seam() -> void:
	var d: RefCounted = Def.walkers(BIG)[2]
	var sr: Vector2 = d.shin_r
	near(FootModel.radius_at(d, 0.0), sr.y, 1e-3, "the ankle end is the shin's tip")
	var t := 1.0 - FootModel.SEAM / float(d.shin)
	near(FootModel.radius_at(d, FootModel.SEAM), lerpf(sr.x, sr.y, pow(t, 0.8)), 1e-3, "at the seam, the far profile")
	var tris := 0
	for part: StringName in FootModel.PARTS:
		tris += FootModel.build(d, part).vertex_count() / 3
	lt(float(tris), 40000.0, "the near foot inside its budget (%d triangles)" % tris)
	lt(float(FootModel.PARTS.size()), 7.0, "in six draws or fewer")


## THE SOLE HAS A FRONT: set down facing the walk, its three toes are ahead of
## the ankle and its heel is behind it, so the print says which way it went.
func test_a_sole_points_the_way_it_walks() -> void:
	var d: RefCounted = Def.walkers(BIG)[2]
	var r: RefCounted = Route.make(d, 7, BIG)
	for k in 3:
		var yaw := Walk.natural_yaw(d, r, k, 3)
		var ahead := Vector2.from_angle(yaw)
		var pads := Treads.pads(d, Vector2.ZERO, yaw)
		eq(pads.size(), 4, "three toes and a heel")
		for i in 3:
			gt(Vector2(pads[i].x, pads[i].y).dot(ahead), 60.0, "toe %d ahead of the ankle" % i)
		lt(Vector2(pads[3].x, pads[3].y).dot(ahead), -60.0, "the heel behind it")
		gt(pads[3].z, pads[0].z, "and the heel is the widest print")


## THE CRATERS IN THE SHIPPED WORLD: the foot's pads stand on bared floor at one
## height, a body standing on that floor can climb out of it one level at a time
## (the land round it may have cliffs of its own; there must be SOME way out),
## and nothing anybody BUILT stands in one. What grew there is crushed at load
## (the game test below), because taking it out here would renumber every prop.
func test_the_world_is_cut_where_the_feet_come_down() -> void:
	var w := _grown()
	var rows := _treads(w)
	gt(float(rows.size()), 0.0, "seed 7 has treads")
	for m: Dictionary in rows:
		var floor_l := roundi(float(m.floor) / WorldData.STEP)
		for p: Vector3 in (m.pads as Array):
			var c := Vector2i(floori(p.x), floori(p.y))
			var i := c.y * w.size + c.x
			eq(w.level[i], floor_l, "a pad's floor is the tread's floor")
			eq(w.ground[i], Ground.CLINKER, "pressed ground under the pad")
			check(_climbs_out(w, c, Treads.rim_r(p) + 4.0), "a body on the floor of the crater at %s can climb out of it" % c)
			for q: WorldProp in w.props:
				if q.pos.distance_to(Vector2(p.x, p.y)) < p.z and q.kind in GenScatter.PLACED and q.solid >= 1.2 and q.id < _dressed_from(w):
					check(false, "a %s stands under a pad at %s" % [PropKind.NAMES[q.kind], q.pos])
					break


## THE PRESSURE RING LIES ON LAND: no tile it was laid on is sea, water, or
## within GenTreads.SHORE of either (a band of scree along the water is a beach
## the land never had). Asked of the tiles the ring itself recorded.
func test_the_pressure_ring_keeps_off_the_water() -> void:
	GenTreads.last_ring = PackedInt32Array()
	_world = null
	var w := _grown()
	var laid: PackedInt32Array = GenTreads.last_ring
	gt(float(laid.size()), 500.0, "the ring was laid (%d tiles)" % laid.size())
	var wet := 0
	var shore := 0
	for i in laid:
		if w.level[i] <= 0 or Ground.is_water(w.ground[i]):
			wet += 1
		elif GenTreads._shore(w, i % w.size, i / w.size):
			shore += 1
	eq(wet, 0, "no ring tile is water")
	eq(shore, 0, "and none is on the shore")


## The walk and the world agree: handed the world's treads, the only feet that
## ever come down on the island come down in them.
func test_the_only_feet_on_the_island_are_in_its_treads() -> void:
	var w := _grown()
	var defs: Array = Def.walkers(BIG)
	var routes: Array = []
	for d: RefCounted in defs:
		routes.append(Route.make(d, 7, BIG))
	Treads.hand_over(defs, routes, w.landmarks)
	gt(float(_treads(w).size()), 0.0, "there are treads to stand in")
	var seen := 0
	for i in defs.size():
		var d: RefCounted = defs[i]
		var r: RefCounted = routes[i]
		for k in 3:
			for j: int in int(r.cycles()):
				var p := Walk.plant(d, r, k, j)
				if p.x < 0.0 or p.z < 0.0 or p.x >= BIG or p.z >= BIG:
					continue
				check(not is_nan(r.tread_of(k, j).x), "%s leg %d plant %d on the island is a tread" % [d.id, k, j])
				seen += 1
	eq(seen, _treads(w).size(), "and every tread is stood in")


## The first id the tread stage appended (its own spoil and posts): everything
## before it was laid by the stages before, and must be where it was.
func _dressed_from(w: WorldData) -> int:
	for i in range(w.props.size() - 1, -1, -1):
		var q := w.props[i]
		var near_one := false
		for m: Dictionary in _treads(w):
			if q.pos.distance_to(m.pos as Vector2) < 260.0:
				near_one = true
		if not near_one or not (q.kind in [PropKind.DEBRIS, PropKind.WRECKAGE, PropKind.SURVEY]):
			return i + 1
	return 0


## Whether a body can walk from `from` to anywhere `reach` tiles off, stepping a
## level at most (WorldQuery's rule) over dry land.
func _climbs_out(w: WorldData, from: Vector2i, reach: float) -> bool:
	var seen := {from: true}
	var open: Array[Vector2i] = [from]
	while not open.is_empty():
		var at: Vector2i = open.pop_back()
		if Vector2(at - from).length() > reach:
			return true
		var l := w.level[at.y * w.size + at.x]
		for dv: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := at + dv
			if seen.has(n) or n.x < 0 or n.y < 0 or n.x >= w.size or n.y >= w.size:
				continue
			var i := n.y * w.size + n.x
			if w.level[i] <= 0 or Ground.is_water(w.ground[i]) or absi(w.level[i] - l) > 1:
				continue
			seen[n] = true
			open.append(n)
	return false


func _game(args: PackedStringArray) -> Game:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(args))
	return g


## A FOOT STANDING IN ITS TREAD, IN A RUNNING GAME: its pads stop a body; a body
## put under one is put out at its edge; a thing standing where a pad is, is
## crushed; and before the foot comes down none of that is so.
func test_a_planted_foot_stops_puts_out_and_crushes() -> void:
	var g := _game(PackedStringArray(["--seed=7", "--place=tread0", "--colossus=2@tread0+30", "--hour=12", "--weather=clear:0"]))
	var sys: Node = g.get_node("19_colossi")
	var row: Dictionary = {}
	for m: Dictionary in g.world.landmarks:
		if StringName(m.get("kind", &"")) == &"tread":
			row = m
			break
	check(not row.is_empty(), "the world has a tread")
	if row.is_empty():
		g.free()
		return
	var pad: Vector3 = (row.pads as Array)[0]
	var c := Vector2(pad.x, pad.y)
	# Something left standing where the pad comes down, before the first frame
	# of this game -- which is what a loaded game's first frame is.
	var left := Survival.add_prop(g, PropKind.CAIRN, c + Vector2(4.0, 2.0))
	sys._process(1.0 / 60.0)
	check(bool(sys.tour_seen(&"colossus_tread")), "the staged foot stands in it")
	check(not g.query.blocks_at(c).is_empty(), "the pad stops a body")
	check(g.world.depleted.has(left.id) and is_inf(float(g.world.depleted[left.id])), "what stood under the pad is crushed, for good")
	# A body put under it.
	g.player.pos = c + Vector2(3.0, 0.0)
	g.player.hero.pos = g.player.pos
	sys._process(1.0 / 60.0)
	gt(g.player.pos.distance_to(c), pad.z, "put out from under the pad (%.1f from its middle)" % g.player.pos.distance_to(c))
	near(g.player.hero.pos.distance_to(g.player.pos), 0.0, 1e-4, "the fight body with it")
	g.free()
	# The same place a world hour before the foot comes down: open ground -- and
	# still bare, because what grew in the craters is crushed at load whether the
	# foot is in them or not.
	var g2 := _game(PackedStringArray(["--seed=7", "--place=tread0", "--colossus=2@tread0-60", "--hour=12", "--weather=clear:0"]))
	var sys2: Node = g2.get_node("19_colossi")
	sys2.started()
	sys2._process(1.0 / 60.0)
	check(not bool(sys2.tour_seen(&"colossus_tread")), "an hour before, no foot stands in it")
	check(not bool(sys2.tour_seen(&"colossus_blocks")), "and nothing stops a body there")
	var standing := 0
	for q: WorldProp in g2.world.props:
		for pp: Vector3 in (row.pads as Array):
			if q.pos.distance_to(Vector2(pp.x, pp.y)) < pp.z and not g2.world.depleted.has(q.id):
				standing += 1
	eq(standing, 0, "nothing stands where a pad comes down")
	g2.free()
