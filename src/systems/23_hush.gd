extends GameSystem
## THE HUSH (docs/HUSH.md): what haunts a landscape that declares
## `BiomeDef.hush` (the crags), on its own stone circles (HushSites). Nothing
## here is explained, gates anything, or is read by the story: colour, never
## load. This system grows by slices; the machines' part is the fight's.

## How far a tour looks for a ring to stand at.
const TOUR_REACH := 160.0
## The names `tour_place` answers (tests/tours/test_tour_claims reads them).
const TOUR_PLACES: Array[String] = ["hush_ring"]
## How far round the player rings are looked for (a ring's stones turn only
## within it), and how often (seconds).
const LOOK := 40.0
const EVERY := 0.25

## THE QUIET, 0..1 (Hush.level), read off the group `&"hush"` by 70_audio (the
## beds and the scatter fall away, the player's own sounds stay) and 10_sky (the
## wind, the sway and the drifting fog hold still), so neither knows this exists.
var quiet := 0.0

var _rings: Array[HushSites.Ring] = []
var _look_in := 0.0
## The ring the player is in (its id), or 0; visits a ring has had this game.
var _in := 0
var _visits: Dictionary = {}
## The answer running: seconds since coming in, when it waits and holds; t < 0
## for none.
var _t := -1.0
var _span := Vector2.ZERO
## `--hush=always`: every visit answers, at any hour, for a proof tour.
var _always := false
## Each ring stone's laid rot (the first time it was near), and the turn it
## stands at now (Hush.turned), by prop id.
var _laid: Dictionary = {}
var _turn: Dictionary = {}
## The longest a stone's turn held the main thread (its chunk's props are
## rebaked on a worker, WorldView.refresh_props_soon), usec.
var turn_usec_max := 0


func setup(g: Game) -> void:
	super.setup(g)
	add_to_group(&"hush")
	_always = g.options != null and g.options.hush == "always"


func _process(delta: float) -> void:
	if game == null or game.world == null or game.player == null:
		return
	_look_in -= delta
	if _look_in <= 0.0:
		_look_in = EVERY
		_rings = HushSites.near(game.world, game.query, game.player.pos, LOOK)
		_stand_stones()
	var now := 0
	for r: HushSites.Ring in _rings:
		if HushSites.inside(r, game.player.pos):
			now = r.id
			break
	if now != _in:
		_in = now
		if now != 0:
			_enter(now)
	if _t >= 0.0:
		_t += delta
		quiet = Hush.level(_t, _span.x, _span.y)
		if _t >= Hush.ends(_span.x, _span.y):
			_t = -1.0
			quiet = 0.0


func _enter(ring: int) -> void:
	var visit := int(_visits.get(ring, 0))
	_visits[ring] = visit + 1
	if _t >= 0.0:
		return
	var day := game.clock.day()
	var night := Weather.night_fall(game.clock.hour())
	var fog := game.sky.fog.z if game.sky != null else 0.0
	if _always or Hush.answers(game.world.seed_value, ring, day, visit, night, fog):
		_span = Hush.span(game.world.seed_value, ring, day, visit)
		_t = 0.0


## `await hush_quiet`: the world has fallen silent; `hush_gone` once it is back.
func tour_seen(what: StringName) -> bool:
	match what:
		&"hush_quiet":
			return quiet >= 0.999
		&"hush_gone":
			return _t < 0.0
		&"stone_turned":
			for v: float in _turn.values():
				if v != 0.0:
					return true
			return false
	return false


## `near hush_ring`: the centre of the nearest ring, so a tour stands in it by
## name and never at a coordinate.
func tour_place(what: String) -> Vector2:
	if what != "hush_ring" or game == null or game.world == null or game.player == null:
		return Vector2.INF
	var r := HushSites.nearest(game.world, game.query, game.player.pos, TOUR_REACH)
	return r.centre if r != null else Vector2.INF



## THE STONES (H2): each ring near stands its epoch's stones -- one turned, the
## rest as laid -- but a stone only moves while it is off screen, so the one
## that is different is found by looking back.
func _stand_stones() -> void:
	if game.camera == null or game.view == null:
		return
	var epoch := floori(game.clock.minutes / Hush.EPOCH)
	for r: HushSites.Ring in _rings:
		var t := Hush.turned(game.world.seed_value, r.id, r.stones.size(), epoch)
		for k in r.stones.size():
			var id := r.stones[k]
			var p := game.world.prop(id)
			if p == null:
				continue
			if not _laid.has(id):
				_laid[id] = p.rot
				_turn[id] = 0.0
			var want := t.y if k == int(t.x) else 0.0
			if is_equal_approx(float(_turn[id]), want):
				continue
			var foot := Vector3(p.pos.x, game.world.height_at(p.pos), p.pos.y)
			if CameraRig.sees_ground(game.camera, foot, 1.0, 3.0):
				continue
			_turn[id] = want
			game.world.turn_prop(id, float(_laid[id]) + want)
			var t0 := Time.get_ticks_usec()
			game.view.refresh_props_soon(game.world.prop(id))
			turn_usec_max = maxi(turn_usec_max, Time.get_ticks_usec() - t0)
			if game.options != null and game.options.tour != "":
				print("tour hush: a stone of ring %d turned by %.1f degrees; %d us to ask, the longest swap so far %d us" % [r.id, rad_to_deg(want), Time.get_ticks_usec() - t0, game.view.rebake_swap_usec_max])
