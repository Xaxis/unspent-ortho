extends GameSystem
## THE HUSH (docs/HUSH.md): what haunts a landscape that declares
## `BiomeDef.hush` (the crags), on its own stone circles (HushSites). Nothing
## here is explained, gates anything, or is read by the story: colour, never
## load. This system grows by slices; the machines' part is the fight's.

## How far a tour looks for a ring to stand at.
const TOUR_REACH := 160.0
## The places `tour_place` answers (test_tour_claims holds every tour to them).
const TOUR_PLACES: Array[String] = ["hush_ring", "nobodys_light", "ring_answer"]
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
## Nobody's lights (H4): up to three, each an OmniLight3D lent to 15_lights'
## budget with its glow in the fog, drawn where Hush.nobody puts them.
const LIGHTS_SYSTEM := preload("res://src/systems/15_lights.gd")
var _lamps: Array[OmniLight3D] = []
var _lamps_on := 0
## The rings answering (H5): the night each ring last answered, by ring id; the
## one answering now, its order, how far in; and the light the stones give back.
var _answered: Dictionary = {}
var _ans_ring: HushSites.Ring
var _ans_order := PackedInt32Array()
var _ans_t := -1.0
var _ans_light: OmniLight3D
var answered_count := 0
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
	_stand_lights()
	_answer(delta)
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
		&"ring_answering":
			return _ans_t >= 0.0
		&"ring_answered":
			return answered_count > 0 and _ans_t < 0.0
		&"nobodys_light":
			return _lamps_on > 0
		&"stone_turned":
			for v: float in _turn.values():
				if v != 0.0:
					return true
			return false
	return false


## `near hush_ring`: the centre of the nearest ring, so a tour stands in it by
## name and never at a coordinate.
func tour_place(what: String) -> Vector2:
	if game == null or game.world == null or game.player == null:
		return Vector2.INF
	# `near nobodys_light`: stay where you are, turned toward the nearest.
	if what == "nobodys_light":
		return game.player.pos if _lamps_on > 0 else Vector2.INF
	# `near ring_answer`: stay, turned toward the stone answering now.
	if what == "ring_answer":
		return game.player.pos if _ans_t >= 0.0 else Vector2.INF
	if what != "hush_ring":
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



## NOBODY'S LIGHTS (H4): on a hush landscape's fog nights, where Hush.nobody
## says, and nowhere else; never on a road.
func _stand_lights() -> void:
	var at: Vector2 = game.player.pos
	var here := BiomeRegistry.by_index(game.world.country_at(floori(at.x), floori(at.y)))
	var pts := PackedVector2Array()
	var fog := game.sky.fog.z if game.sky != null else 0.0
	if here != null and here.hush and Hush.lit(Weather.night_fall(game.clock.hour()), fog):
		var rings := PackedVector3Array()
		for r: HushSites.Ring in _rings:
			rings.append(Vector3(r.centre.x, r.centre.y, r.radius))
		for p: Vector2 in Hush.nobody(game.world.seed_value, Hush.night_of(game.clock.minutes), game.clock.minutes, at, rings):
			if not game.world.on_road(floori(p.x), floori(p.y)):
				pts.append(p)
	while _lamps.size() < pts.size():
		_lamps.append(_make_lamp())
	_lamps_on = pts.size()
	for i in _lamps.size():
		var l := _lamps[i]
		l.visible = i < pts.size()
		if i < pts.size():
			var p := pts[i]
			l.position = Vector3(p.x, game.world.height_at(p) + 1.1, p.y)


func _make_lamp() -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Hush.LIGHT_COLOR
	l.light_energy = 1.4
	l.omni_range = 7.0
	l.shadow_enabled = false
	# Steady: no flicker and no spokes. A person's flame wavers and a machine's
	# light is ruled; this is neither.
	# Screen pixels: a small steady star, straight strokes only.
	l.add_child(LIGHTS_SYSTEM.rays(Hush.LIGHT_COLOR, 2.0, 11.0, 0.0, 4.0))
	game.view.add_child(l)
	for sys: Node in game.systems:
		if sys.has_method(&"lend"):
			sys.call(&"lend", l, false, 1)
			break
	return l


func _exit_tree() -> void:
	if _ans_light != null:
		_lamps.append(_ans_light)
	if game != null:
		for l: OmniLight3D in _lamps:
			for sys: Node in game.systems:
				if sys.has_method(&"take_back"):
					sys.call(&"take_back", l)
	_lamps.clear()



## Which way `near nobodys_light` turns the player: toward the nearest light.
func tour_face(what: String) -> float:
	if what == "ring_answer" and _ans_t >= 0.0 and _ans_light != null:
		return (Vector2(_ans_light.position.x, _ans_light.position.z) - game.player.pos).angle()
	if what != "nobodys_light" or _lamps_on == 0:
		return NAN
	var at: Vector2 = game.player.pos
	var best := _lamps[0]
	for i in _lamps_on:
		if Vector2(_lamps[i].position.x, _lamps[i].position.z).distance_to(at) < Vector2(best.position.x, best.position.z).distance_to(at):
			best = _lamps[i]
	return (Vector2(best.position.x, best.position.z) - at).angle()



## THE RINGS ANSWER (H5): the lamp held in a ring at night, or a fire lit within
## its stones, and the stones give the light back one after another, once a night.
func _answer(delta: float) -> void:
	if _ans_t >= 0.0:
		_ans_t += delta
		var a := Hush.answering(_ans_t, _ans_order.size())
		if a.x < 0.0:
			_ans_t = -1.0
			_ans_light.visible = false
			return
		var p := game.world.prop(_ans_ring.stones[_ans_order[int(a.x)]])
		if p != null:
			_ans_light.position = Vector3(p.pos.x, game.world.height_at(p.pos) + 1.4, p.pos.y)
		_ans_light.light_energy = 3.2 * a.y
		_ans_light.visible = a.y > 0.02
		return
	if _in == 0:
		return
	var ring: HushSites.Ring = null
	for r: HushSites.Ring in _rings:
		if r.id == _in:
			ring = r
	if ring == null:
		return
	var night := Hush.night_of(game.clock.minutes)
	var lit := game.body != null and game.body.lamp_lit
	if not lit:
		for q: WorldProp in game.query.props_near(ring.centre, ring.radius):
			if q.kind == PropKind.FIRE and not game.world.depleted.has(q.id):
				lit = true
				break
	if not Hush.may_answer(Weather.night_fall(game.clock.hour()), lit, int(_answered.get(ring.id, -1)), night):
		return
	_answered[ring.id] = night
	_ans_ring = ring
	_ans_order = Hush.answer_order(game.world.seed_value, ring.id, night, ring.stones.size())
	_ans_t = 0.0
	answered_count += 1
	if _ans_light == null:
		_ans_light = _make_lamp()
		_ans_light.omni_range = 5.0
