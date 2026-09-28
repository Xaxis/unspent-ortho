extends TestCase
## A BODY IS NEVER PUT WHERE IT CANNOT MOVE. The move (WorldQuery._fits) asks
## every corner of a body to be a step from the tile under its middle; a body
## put down with one corner on the terrace above is refused every step that
## leaves that corner in its tile, and at a walk no frame's step does: it stands
## frozen. So every path that PLACES the player (not walks it) goes through
## Player.place -> WorldQuery.stand_at, which puts it down whole (body_fits).
## Found by a tour: `near keeper` stood the player so on seed 1's snowfield.

const F := preload("res://tests/fight/fixture.gd")
const Sx := preload("res://tests/save/save_fixture.gd")
const R := Tuning.PLAYER_RADIUS
## About one frame of a walk.
const STEP := 0.066


## Moves in eight directions a frame's step from `p`: how many of them go anywhere.
static func _ways_out(q: WorldQuery, p: Vector2) -> int:
	var n := 0
	for i in 8:
		var to := q.move_body(p, Vector2.from_angle(TAU * i / 8.0) * STEP, R, null, true, FightSim.HERO_TALL)
		n += int(to.distance_to(p) > 1e-4)
	return n


## A flat world with a terrace two levels up east of x = 20.
static func _stepped() -> WorldData:
	var w := F.flat_world(48)
	for y in 48:
		for x in range(20, 48):
			w.level[y * 48 + x] = 4
	return w


func test_a_corner_on_the_step_above_freezes_a_body_and_stand_at_puts_it_down_whole() -> void:
	var w := _stepped()
	var q := WorldQuery.new(w)
	# Its middle below the step, its east corners on it.
	var bad := Vector2(20.0 - 0.1, 24.5)
	check(not q.body_fits(bad, R, null, true, FightSim.HERO_TALL), "a body with a corner on the step does not fit")
	eq(_ways_out(q, bad), 0, "and stood there it cannot take a step any way (the freeze)")
	var put := q.stand_at(bad, R, null, true, FightSim.HERO_TALL)
	check(q.body_fits(put, R, null, true, FightSim.HERO_TALL), "stand_at puts it down whole (%s)" % put)
	lt(put.distance_to(bad), 0.6, "a step from where it was asked for (%.2f)" % put.distance_to(bad))
	gt(float(_ways_out(q, put)), 4.0, "and from there it walks off (%d ways of 8)" % _ways_out(q, put))
	# A body that already fits is left where it was put.
	eq(q.stand_at(Vector2(10.5, 10.5), R, null, true, FightSim.HERO_TALL), Vector2(10.5, 10.5), "a spot that fits is kept")


## Every write of the player's place outside the move is Player.place's own. A
## new path that writes `hero.pos =` or `player.pos =` itself has skipped the
## check, and this names it.
const MOVES := {
	# The move itself, and the body the fight makes from the placed player.
	"src/core/fight/fight_sim.gd": true,
	"src/actors/player.gd": true,
	"src/systems/30_mobs.gd": true,
	# A leap, a climb, a pull: moved each frame by its own motion, and put
	# down through Player.place when it lands.
	"src/systems/54_gear.gd": true,
}


func test_every_placement_of_the_player_goes_through_place() -> void:
	var re := RegEx.create_from_string("\\b(hero|player|pl)\\.pos\\s*=[^=]")
	var files: Array[String] = []
	_gd_files("res://src", files)
	gt(float(files.size()), 50.0, "the source was read (%d files)" % files.size())
	for f in files:
		var rel := f.trim_prefix("res://")
		if MOVES.has(rel):
			continue
		var n := 0
		for line in FileAccess.get_file_as_string(f).split("\n"):
			n += 1
			if re.search(line) != null and not line.strip_edges().begins_with("#"):
				fail("%s:%d places the player itself; put it down with Player.place: %s" % [rel, n, line.strip_edges()])


static func _gd_files(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_gd_files(dir.path_join(sub), out)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))


## A standable tile with the tile east of it two or more levels up: a spot with
## its middle below and its east corners on the step.
static func _edge(w: WorldData, q: WorldQuery, from: Vector2) -> Vector2:
	var cx := floori(from.x)
	var cy := floori(from.y)
	for r in 80:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var x := cx + dx
				var y := cy + dy
				if not q.standable(x, y) or not q.standable(x + 1, y) or Ground.is_water(w.ground_at(x, y)):
					continue
				if w.level_at(x + 1, y) - w.level_at(x, y) >= 2 and w.level_at(x, y) > 0:
					var p := Vector2(x + 1 - 0.1, y + 0.5)
					if not q.body_fits(p, R, null, true, FightSim.HERO_TALL):
						return p
	return Vector2.INF


func test_each_path_puts_the_player_down_where_it_can_walk_off() -> void:
	Sx.use_root("stand-at")
	var g := Sx.game(tree, ["--seed=1", "--hour=10", "--weather=clear:0"])
	var q := g.query
	var bad := _edge(g.world, q, g.player.pos)
	check(bad.is_finite(), "a terrace edge near the start (%s)" % bad)
	if not bad.is_finite():
		Sx.end(g)
		return
	eq(_ways_out(q, bad), 0, "the edge spot freezes a body stood on it")
	var paths := {
		"load": func() -> void: SaveCore.load_player(g, {"pos": [bad.x, bad.y], "facing": 0.0}),
		"dev jump": func() -> void: DevCheats.teleport(g, bad),
		"the hours going by": func() -> void: Sx.system(g, "40_fight").call(&"_put_hero", bad, 0.0),
		"a craft's step": func() -> void: Sx.system(g, "44_crafts").call(&"_put_body", bad),
	}
	# A tour's jump, where the game runs one (every other path -- a door, a warp,
	# a respawn, a pad's edge -- calls Player.place, which the scan above holds).
	var tour := Sx.system(g, "98_tour")
	if tour != null:
		paths["a tour's jump"] = func() -> void: tour.call(&"_teleport", bad)
	for name: String in paths:
		g.player.place(g.world.spawn)
		(paths[name] as Callable).call()
		var at := g.player.hero.pos
		check(at.distance_to(g.player.pos) < 1e-4, "%s: the fight body and the drawn one agree" % name)
		check(q.body_fits(at, R, null, true, FightSim.HERO_TALL), "%s: put down whole (%s, asked %s)" % [name, at, bad])
		gt(float(_ways_out(q, at)), 2.0, "%s: and it walks off (%d ways of 8)" % [name, _ways_out(q, at)])
	# The start: a new body set up on the edge.
	var p := Player.new()
	p.setup(g.world, q, bad, g.view.world_material())
	check(q.body_fits(p.pos, R, null, true, FightSim.HERO_TALL), "a start on the edge is put down whole (%s)" % p.pos)
	p.free()
	Sx.end(g)
