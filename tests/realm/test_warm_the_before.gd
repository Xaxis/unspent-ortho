extends TestCase
## THE BEFORE IS RAISED ONCE A GATE IS OPEN (20_realms `_warm_the_before`), so
## the press at the gate goes straight through instead of standing him behind
## the crossing page for the whole raise. Shafts were warmed from the start of
## a game and on approach; the gates into 2029 never were, and every first
## crossing waited out a world (36 s on desktop at 1840, about twice that on the
## web).

const Sx := preload("res://tests/save/save_fixture.gd")
const Realms := preload("res://src/systems/20_realms.gd")
const SEED := 1
const SIZE := 256


func _clear() -> void:
	Story.forget()
	RealmWorlds.forget()
	RealmWorlds.settle()


## A gate's beat, landed long ago as `--beats` stages it, so the gate is open.
func _game(beats: String) -> Game:
	var args := ["--seed=%d" % SEED, "--size=%d" % SIZE, "--weather=clear:0"]
	if beats != "":
		args.append("--beats=" + beats)
	var g := Sx.game(tree, args)
	# Past the opening frames (WARM_AFTER) and a look round (LOOK_EVERY).
	await frames(6)
	await tree.create_timer(Realms.LOOK_EVERY * 3.0).timeout
	return g


func _before_begun() -> bool:
	return RealmWorlds.going(SEED, SIZE, Realm.ERA) or RealmWorlds.ready(SEED, SIZE, Realm.ERA)


func test_the_before_is_raised_once_a_gate_is_open_with_no_press() -> void:
	_clear()
	Sx.use_root("warm-before-open")
	var g := await _game(String(StoryGates.GATES[0].opens))
	gt(StoryGates.open(g.world).size(), 0, "a gate is open")
	check(_before_begun(), "and the Before is being raised before anybody reaches it")
	Sx.end(g)
	_clear()


func test_no_gate_open_raises_no_before() -> void:
	_clear()
	Sx.use_root("warm-before-shut")
	var g := await _game("")
	eq(StoryGates.open(g.world).size(), 0, "no gate is open on the first morning")
	check(not _before_begun(), "and nothing raises the Before")
	Sx.end(g)
	_clear()


## Never on the web: a third world in a wasm heap that never shrinks, which a
## threaded game has already taken to 1,555 MB, and an out-of-memory there ends
## the player's game. The guard it replaced read the engine's memory counter,
## which is 0 in the release build the web ships, and let every raise through.
func test_the_web_never_raises_it_early() -> void:
	check(not Realms.warms_early(true), "on the web the press raises the Before")
	check(Realms.warms_early(false), "on the desktop it is raised once a gate is open")
