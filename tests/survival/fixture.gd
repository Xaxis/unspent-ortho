extends RefCounted
## A Game with no nodes drawn: world, query, clock, body, inventory and a bare
## Player, enough for every Survival rule. Tests build one, work it, and free it.
##   const Fx := preload("res://tests/survival/fixture.gd")
##   var g := Fx.flat()          # a 40x40 flat grass field, player at its middle
##   var p := Fx.put(g, PropKind.PINE, Vector2(1.2, 0))   # a pine just east of the player
##   ...
##   Fx.done(g)


## A flat field: level 2 grass, sea round the rim, no villages.
static func flat(size: int = 40, hour: float = 8.0) -> Game:
	var w := WorldData.new(11, size)
	for y in size:
		for x in size:
			var i := y * size + x
			var rim := x == 0 or y == 0 or x == size - 1 or y == size - 1
			w.level[i] = -1 if rim else 2
			w.ground[i] = Ground.DEEP_WATER if rim else Ground.GRASS
			w.country[i] = Country.SEA if rim else Country.COAST
	w.spawn = Vector2(size * 0.5 + 0.5, size * 0.5 + 0.5)
	return from_world(w, hour)


static func from_world(w: WorldData, hour: float = 8.0) -> Game:
	var g := Game.new()
	g.options = BootOptions.new()
	g.world = w
	g.query = WorldQuery.new(w)
	g.clock = WorldClock.new(hour)
	g.body = Body.new()
	g.body.fed_until = g.clock.minutes + 6.0 * 60.0
	g.inventory = Inventory.new()
	g.inventory.add(&"knife")
	g.inventory.set_held(&"knife")
	g.inventory.set_edge(&"knife", 5000)
	var p := Player.new()
	p.world = w
	p.query = g.query
	p.pos = w.spawn
	p.facing = 0.0
	g.player = p
	SurvivalState.of(g).woke_at = g.clock.minutes - 60.0
	return g


## A prop at an offset from the player (tile units).
static func put(g: Game, kind: int, offset: Vector2) -> WorldProp:
	return Survival.add_prop(g, kind, g.player.pos + offset)


## Stand in front of a prop, facing it, from direction `from` (unit vector, prop -> player).
static func face(g: Game, prop: WorldProp, from: Vector2 = Vector2(-1, 0)) -> void:
	g.player.pos = prop.pos + from.normalized() * (prop.solid + Tuning.PLAYER_RADIUS + 0.15)
	g.player.facing = (prop.pos - g.player.pos).angle()


## Use and finish at once; returns whether the work started.
static func take(g: Game) -> bool:
	var ok := Survival.use(g)
	if not SurvivalState.of(g).job.is_empty():
		Survival.finish_work(g)
	return ok


static func done(g: Game) -> void:
	g.player.free()
	g.free()
