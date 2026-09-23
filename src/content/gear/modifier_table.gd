class_name ModifierTable
## What each module DECIDES, and which modules pay for or fight each other
## (docs/VISION.md §6.1, "Modifiers are the elegance").
##
## Every row says what the part changes about the way you play, in the words the
## slate will show. A module that only adds a number belongs in `Items.DEFS` and
## not here; a module that appears here has to change a decision: a new reach, a
## new opening, a resource to spend, a risk to take.
##
## Tags are the whole of how modifiers talk to each other. A part `gives` tags, a
## part `wants` one paid, and `PAIRS` says what happens when two tags meet. That
## keeps the combinations DATA: a new part is a row, and it starts combining and
## conflicting with everything already here without a line of new code.
##
## Each row says its decision twice: `decision` is the sentence, and `short` is
## what fits the ONE line the gear page has beside a socket. A page is not a
## manual: the sentence overran the panel and printed itself across the
## resistances, so `Modifiers.note` hands over the short one and a test measures
## it against the real font and the real panel.
##
## The tags:
##   loud    it shouts: you are easier to read and to find
##   quiet   it hushes: you are harder to read
##   hot     it runs hot, and the body wears that
##   cool    it carries heat away
##   charge  it holds or wins back the charges found tech eats
##   steady  it holds you where you put yourself
##   held    it holds you to what you are standing on
##   hidden  it wears the machines' own name
##   shed    it gives up part of itself instead of you
##   read    it reads what you could not see
##   quick   it moves you further than legs do
const MODS := {
	&"mod_wadding": {"decision": "the cold takes longer to find you", "short": "the cold comes slower",
		"gives": []},
	&"mod_filter": {"decision": "you can breathe where the air is against you", "short": "you can breathe here",
		"gives": []},
	&"mod_shade": {"decision": "you can look at the ground you are crossing", "short": "you can look ahead",
		"gives": []},
	&"mod_grip": {"decision": "the ring does not come back up the haft", "short": "no ring up the haft",
		"gives": [&"quiet"]},
	&"mod_wick": {"decision": "the ground in front of your feet is lit, and nothing further",
		"short": "your feet are lit",
		"gives": []},
	&"mod_foil": {"decision": "what they send through you goes round instead", "short": "it goes round you",
		"gives": [&"shed"]},
	&"mod_spring": {"decision": "one burst, further than a run, out of a standing start",
		"short": "a burst from standing",
		"gives": [&"quick"]},
	&"mod_signet": {"decision": "for a while you read to them as one of them",
		"short": "you read as theirs",
		"gives": [&"hidden"]},
	# --- the mended modifiers this package adds -------------------------------
	&"mod_gyro": {"decision": "a burst lands where you aimed it, and a blow does not turn you",
		"short": "a burst lands true",
		"gives": [&"steady"]},
	&"mod_clamp": {"decision": "you stay on the plate you are standing on",
		"short": "you stay on the plate",
		"gives": [&"held"]},
	&"mod_ablative": {"decision": "it burns off a layer instead of you, and does not grow back",
		"short": "it burns off, not you",
		"gives": [&"shed"]},
	&"mod_cooling": {"decision": "it carries heat out of the kit, so something that runs hot can be run",
		"short": "it carries heat away",
		"gives": [&"cool"]},
	&"mod_capacitor": {"decision": "it holds charges, so a found edge keeps swinging",
		"short": "it holds charges",
		"gives": [&"charge"]},
	&"mod_harmonic": {"decision": "it rings their plate instead of glancing off it, and they hear it",
		"short": "it rings their plate",
		"gives": [&"loud"]},
	&"mod_damp": {"decision": "you go quieter, and so do your blows",
		"short": "you go quieter",
		"gives": [&"quiet"]},
	&"mod_leech": {"decision": "it takes a charge back out of whatever it puts down",
		"short": "a kill gives a charge",
		"gives": [&"charge"]},
	&"mod_phase": {"decision": "it reads the working part through the plate over it",
		"short": "it reads through plate",
		"gives": [&"read"]},
	&"mod_lattice": {"decision": "every blow throws a shock, and the whole kit runs hot",
		"short": "every blow shocks",
		"gives": [&"hot", &"loud"], "wants": [&"cool"]},
}

## What happens when two tags are in one kit. `kind` is &"conflict" or &"combo";
## `effect` is read by `Modifiers.settle`:
##   scale  multiply what the kit resists (a cost)
##   add    combine more resistance in (a reward)
##   drop   an ability is lost
##
## A conflict is never a refusal. It is a price: you may wear both, and one of
## them stops doing all of its job. That is the decision.
const PAIRS: Array[Dictionary] = [
	# The lattice and the spoofer are VISION's own example: one shouts, the other
	# wears their name, and a name shouted is a name read.
	{"a": &"hidden", "b": &"loud", "kind": &"conflict", "effect": {"drop": &"spoof"},
		"line": "what shouts cannot also wear their name", "mark": "name shouted off"},
	# Anything that hushes is smothered by anything that rings.
	{"a": &"quiet", "b": &"loud", "kind": &"conflict", "effect": {"scale": {&"resonance": 0.5}},
		"line": "the ring comes through the hush", "mark": "rung through"},
	# Heat has to go somewhere. Unpaid, it comes out of what the kit was keeping
	# off you; paid by a cooling loop, it costs nothing — which is the combo.
	{"a": &"hot", "b": &"", "kind": &"conflict", "effect": {"scale": {&"heat": 0.5}},
		"line": "it runs hot with nothing to carry the heat away", "mark": "heat unpaid", "unless": &"cool"},
	{"a": &"hot", "b": &"cool", "kind": &"combo", "effect": {},
		"line": "the loop carries the lattice's heat", "mark": "heat paid"},
	# A bank and a leech coil are the charge build: the bank holds what the coil
	# takes, and the pair of them sit in a field better than either alone.
	{"a": &"charge", "b": &"charge", "kind": &"combo", "effect": {"add": {&"em": 0.2}},
		"line": "the bank holds what the coil wins back", "mark": "charge build"},
	# Braced and clamped: the ground can go out from under you and you stay put.
	{"a": &"steady", "b": &"held", "kind": &"combo", "effect": {"add": {&"collapse": 0.2}},
		"line": "braced and clamped, the floor can go", "mark": "braced"},
]


static func row(id: StringName) -> Dictionary:
	return MODS.get(id, {})


static func has(id: StringName) -> bool:
	return MODS.has(id)


static func ids() -> Array:
	return MODS.keys()


static func decision(id: StringName) -> String:
	return row(id).get("decision", "")


## The same thing in the width a socket's row has. Falls back to the sentence so a
## row that forgets one is caught by the test rather than by a blank line.
static func short(id: StringName) -> String:
	return row(id).get("short", decision(id))


static func gives(id: StringName) -> Array:
	return row(id).get("gives", [])


static func wants(id: StringName) -> Array:
	return row(id).get("wants", [])
