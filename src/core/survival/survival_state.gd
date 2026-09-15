class_name SurvivalState
extends RefCounted
## Survival's own state for one running game: the work in hand, what has been
## taken from which prop, when the body last woke, what the player built.
## Lives on the Game node as metadata so no shared file needs a field for it;
## reach it only through SurvivalState.of(game).
##
## Keys into `taken` and `spent` are "prop_id:option_index" (Takes options).

const META := &"survival_state"

## The work being done: {prop: WorldProp, index: int, option: Dictionary,
## tool: StringName, minutes: float, done_at: float (real seconds)}. Empty when idle.
var job: Dictionary = {}
## Takes so far of an option since it last grew back.
var taken: Dictionary = {}
## Options left standing but picked over: key -> world minute they come back (INF = never).
var spent: Dictionary = {}
## World minute the body last woke (tired after Condition.TIRED_AFTER_H).
var woke_at := 0.0
## World minute the body stays wet until.
var wet_until := -INF
## A campfire asked for by `use` on open ground, waiting for the second press:
## {at: Vector2 where it would go, until: real seconds}. Empty when not asked.
var build_ask: Dictionary = {}
## Stations the player put in the world, in order.
var built: Array[WorldProp] = []
## Real-seconds accumulator for the regrowth sweep.
var sweep_in := 0.0
## World minutes of light left in the flask inside the lamp (a carried `oil` refills it).
var lamp_oil := Condition.LAMP_FLASK_MINUTES
## World minute the lamp's burn was last settled (-INF: not yet).
var lamp_at := -INF
## Work left at stations to finish in world time: station prop id -> {prop,
## station, recipe, makes, done (world minute), pos}. Survival.set_going / collect.
var cooking: Dictionary = {}
## Real seconds a nudge line was last said (line -> seconds).
var nudged: Dictionary = {}
## The hunger level last announced (2 hungry, 3 starving), and since when starving.
var hunger_said := 0
var starving_since := INF
## The low-oil line has been said for this flask.
var lamp_low_said := false


static func of(game: Node) -> SurvivalState:
	if not game.has_meta(META):
		var s := SurvivalState.new()
		game.set_meta(META, s)
	return game.get_meta(META)


static func key(prop_id: int, index: int) -> String:
	return "%d:%d" % [prop_id, index]
