extends GameSystem
## A machine beaten is a body to strip (docs/SALVAGE.md E3). Its plate and the
## parts it carried stay on it where it fell (MobState.spoils, put there by
## 40_fight and 56_economy), and the use key takes them off one at a time: a few
## seconds of the hands and minutes of the clock each, and as loud as a pick on
## plate, so whatever the noise brings is the price of what is on it. Nothing is
## in the pack until it has been stripped; a body nobody strips comes apart where
## it lay (FightSim.CARCASS_MS).
##
## One press, one owner (Survival.words_nearer_than): words in front of him and a
## thing under his hands that a press would take from both keep the key, so a
## body is stripped only when it is the nearest thing the key could mean.
##
## Look at it: tools/test.sh test_carcass.

## Tiles past a body's own radius the hands reach.
const REACH := 0.9
## Real seconds of the hands a piece takes, and minutes of the clock.
const STRIP_SECONDS := 2.2
const STRIP_MINUTES := 8.0
## How often the stripping is heard while it goes on (32_disposition's beat).
const NOISE_EVERY := 0.7

var sim: FightSim
## The body the key would strip now, or null.
var reachable: MobState = null
## The body being stripped, and how far into the piece.
var _on: MobState = null
var _work := 0.0
var _noise_left := 0.0
var _use_was := false
var _spent_frame := -1


func started() -> void:
	sim = game.player.sim if game.player != null else null


func _process(delta: float) -> void:
	if sim == null or game.player == null:
		return
	reachable = _in_reach()
	var down := Keys.down(&"use") and not game.input_blocked()
	var edge := down and not _use_was
	_use_was = down
	if _on != null:
		_carry_on(delta, down)
		return
	if edge and reachable != null and _wins() and not Survival.busy(game) and not _spent_before():
		_spent_frame = Engine.get_process_frames()
		_start(reachable)


## The nearest beaten machine with something still on it, in reach and in front.
func _in_reach() -> MobState:
	var p := sim.hero.pos
	var ahead := Vector2.from_angle(game.player.facing)
	var best: MobState = null
	var best_d := INF
	for m in sim.mobs:
		if m.alive or m.removed or m.spoils.is_empty() or not m.machine:
			continue
		var to := m.pos - p
		var edge := to.length() - m.radius
		if edge > REACH:
			continue
		if edge > 0.3 and to.length() > 0.01 and ahead.dot(to.normalized()) < 0.2:
			continue
		if edge < best_d:
			best_d = edge
			best = m
	return best


func _edge(m: MobState) -> float:
	return m.pos.distance_to(sim.hero.pos) - m.radius


## The body has the press when nothing he means more is there: words in front,
## or a thing under the hands that a press would take from (Harvest.target) and
## that he faces more squarely. Judged as `Survival.use_target` judges two props
## (its edge, and 0.6 a unit of turning away), so a body lying beside him never
## takes the press from the bush he is facing (holdfast.tour, its berries).
func _wins() -> bool:
	if reachable == null:
		return false
	var d := _edge(reachable)
	if Survival.words_nearer_than(game, d):
		return false
	var h := Harvest.target(game)
	if h.is_empty() or not (StringName(str(h.get("state", &""))) in [Harvest.WORKABLE, Harvest.OTHER_TOOL, Harvest.YOURS]):
		return true
	var take := h.get("prop") as WorldProp
	if take == null:
		return true
	var p := game.player.pos
	var c := game.query.reach_circle(take, p)
	var to_take := Vector2(c.x, c.y) - p
	var take_score := _score(to_take.length() - c.z, to_take)
	return _score(d, reachable.pos - p) < take_score


## How much the press means something `edge` tiles off in the direction `to`.
func _score(edge: float, to: Vector2) -> float:
	var ahead := Vector2.from_angle(game.player.facing)
	var dot := ahead.dot(to.normalized()) if to.length() > 0.01 else 1.0
	return edge + (1.0 - dot) * 0.6


## A system numbered before this one spent the press (a door, a shaft).
func _spent_before() -> bool:
	for sys in game.systems:
		if sys == self:
			break
		if sys.has_method(&"use_spent") and bool(sys.call(&"use_spent")):
			return true
	return false


func _start(m: MobState) -> void:
	_on = m
	_work = 0.0
	_noise_left = 0.0
	game.body.busy_until = Survival.now_real() + STRIP_SECONDS
	if game.player.model != null:
		game.player.model.play_action(&"work", STRIP_SECONDS)


## The piece under way: it finishes, and while the key is held the next begins;
## walked away from or let go, it stops where it is.
func _carry_on(delta: float, held: bool) -> void:
	if _on.removed or _on.spoils.is_empty() or _edge(_on) > REACH + 0.4:
		_on = null
		return
	_work += delta
	_noise_left -= delta
	if _noise_left <= 0.0:
		_noise_left = NOISE_EVERY
		sim.make_noise(sim.hero.pos, Survival.noise_radius(game, &"break"))
	if _work < STRIP_SECONDS:
		return
	_strip(_on)
	if held and not _on.spoils.is_empty():
		_start(_on)
	else:
		_on = null


## One piece off the body and into the hands; the last one leaves a frame that
## comes apart where it lay.
func _strip(m: MobState) -> void:
	var row: Dictionary = m.spoils.pop_front()
	var id := StringName(row.get("item", &""))
	var n := int(row.get("count", 1))
	game.clock.skip(STRIP_MINUTES)
	Events.time_skipped.emit(STRIP_MINUTES, &"work")
	if id != &"" and n > 0 and not Items.def(id).is_empty():
		game.inventory.add(id, n)
		Events.took.emit(id, n)
		# An elite part is the reason the fight was worth having: it is said out
		# loud, once, in the words of the thing itself.
		if EliteStock.is_elite(id):
			Events.message.emit("Out of it: %s." % Items.display_name(id))
	Events.sfx.emit(&"took", game.world.to_3d(m.pos))
	if m.spoils.is_empty():
		# Nothing left on it: it lies its ordinary time from now, then goes.
		m.dead_at = sim.now - maxf(0.0, float(m.stat("linger", 30.0)) * 1000.0 - 1500.0)


## The prompt the press would answer (UiLink.use_hint).
func use_line() -> String:
	if reachable == null or _on != null or not _wins() or Survival.ask_pending(game):
		return ""
	var warn := " (a machine will hear)" if Survival.would_be_heard(game, &"break") else ""
	return "%s - strip%s" % [String(reachable.kind).replace("_", " "), warn]


## Whether this frame's press began stripping: it was the body's, so the words and
## the ground under the hands wait for the next.
func use_spent() -> bool:
	return _spent_frame == Engine.get_process_frames()


## For a tour: `carcass` while a body with something on it is in reach.
func tour_seen(what: StringName) -> bool:
	return what == &"carcass" and reachable != null
