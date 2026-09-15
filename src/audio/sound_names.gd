class_name SoundNames
## What emitters say, and the sound it means. Packages emit Events.sfx with the
## name that reads best where they are (menu_select, work_tap, alert_dog,
## build_kiln); this is the one table that turns those names into sounds on the
## sheet, so a new name is a line here and never an edit in another package.
## A name that resolves to &"" is ignored silently, whether unknown or silent on
## purpose (a prop regrowing out of sight).
##
## Patterns, after exact sheet names and ALIAS:
##   work_<verb>      the verb's own sound (break dig fell cut gather scrape tap turn)
##   build_<station>  BUILD[station], else the bench's knocking
##   alert_<model>    a machine's own registering call, a creature's cry, else alert
##   snatch_<model>   that machine's taking, a creature's, else grip
##   windup_<model>   the machine's tell before it strikes, a creature's, else windup
##   step_<family>    that footfall, else dirt
##
## The fight emits alert, snatch and windup bare, at the mob (or at the player it
## took from); the audio system finds the nearest mob there and asks for_mob().

const ALIAS := {
	&"menu_move": &"ui_move",
	&"menu_select": &"ui_accept",
	&"menu_back": &"ui_back",
	&"refused": &"ui_refuse",
	&"open_book": &"book_open",
	&"close_book": &"book_close",
	&"took": &"pickup",
	&"make": &"craft",
	&"collapse": &"downed",
	&"killed": &"machine_down",
	&"called": &"watcher_call",
	&"regrow": &"",
	# survival: the lamp guttering out is the lamp going off.
	&"lamp_out": &"lamp_off",
	# survival: a tool breaking in the hand is its own snap, not a gather.
	&"work_broken": &"tool_snap",
	# survival: asking where to build is a question on the page, not the build.
	&"build_ask": &"ui_move",
	&"ask_fire": &"ui_move",
	# fight: a taking with no mob found to say whose.
	&"snatch": &"grip",
}

## Emitted bare by the fight; the sound depends on which mob is there.
const BY_MOB: Array[StringName] = [&"alert", &"snatch", &"windup"]

const BUILD := {&"fire": &"build_fire", &"bench": &"build_bench", &"kiln": &"build_kiln"}

## Living things answer with their own voice.
const CREATURE_ALERT := {&"dog": &"dog_bark", &"bull": &"bull_snort", &"gull": &"gull_cry", &"gulls": &"gull_cry"}
const CREATURE_SNATCH := {&"gull": &"snatch_gull", &"gulls": &"snatch_gull"}
const KILLED_CREATURE := {&"gull": &"gull_cry", &"gulls": &"gull_cry"}
const CREATURE_WINDUP := {&"dog": &"dog_growl", &"bull": &"bull_paw", &"gull": &"gull_cry", &"gulls": &"gull_cry"}

## Every name the other packages emit, read from their branches (fight 6b535b3,
## survival fb44cc0, sky b03a26e, ui 8d551c4), including the ones they build at
## run time (work_<verb> from survival's takes, hone/reedge from its recipes).
## Literal emits in src/ are also checked by a test that reads the source, so
## after a merge a new name cannot slip into silence unnoticed.
const EMITTED: Array[StringName] = [
	# brief
	&"swing", &"whiff", &"hit_flesh", &"hit_plate", &"dodge", &"grip", &"pull", &"break", &"dig",
	&"fell", &"cut", &"gather", &"craft", &"eat", &"fire", &"splash", &"ui_move", &"ui_accept",
	&"ui_back", &"thunder", &"step_sand", &"step_grass", &"step_stone", &"step_snow",
	# fight (40_fight.gd)
	&"loose", &"second_act", &"alert", &"windup", &"watcher_call", &"machine_down", &"snatch",
	&"downed",
	# survival (survival.gd, crafting.gd, takes.gd verbs, recipes.gd actions)
	&"build_ask", &"ask_fire", &"refuse", &"work_break", &"work_dig", &"work_fell", &"work_cut", &"work_gather",
	&"work_scrape", &"work_tap", &"work_turn", &"took", &"work_broken", &"sleep", &"build_fire",
	&"build_bench", &"build_kiln", &"regrow", &"lamp_out", &"collapse", &"make", &"hone", &"reedge",
	# sky (10_sky.gd, 15_lights.gd)
	&"lamp_on", &"lamp_off",
	# ui
	&"menu_move", &"menu_select", &"open_book", &"close_book", &"refused",
]

## Names that resolve to nothing on purpose (tests tell these from typos).
const SILENT: Array[StringName] = [&"regrow"]

static var _cache: Dictionary = {}


## The sheet name for an emitted name, or &"" (ignore it).
static func resolve(name: StringName) -> StringName:
	if _cache.has(name):
		return _cache[name]
	var out := _resolve(name)
	_cache[name] = out
	return out


static func _resolve(name: StringName) -> StringName:
	if SoundBank.SHEET.has(name):
		return name
	if ALIAS.has(name):
		return ALIAS[name]
	var s := String(name)
	if s.begins_with("work_"):
		var verb := StringName(s.substr(5))
		return verb if SoundBank.SHEET.has(verb) else &"gather"
	if s.begins_with("build_"):
		return BUILD.get(StringName(s.substr(6)), &"build_bench")
	if s.begins_with("alert_"):
		var model := StringName(s.substr(6))
		var machine := SoundMachines.kind_of(model)
		if machine != &"" and SoundBank.SHEET.has(StringName("alert_" + String(machine))):
			return StringName("alert_" + String(machine))
		return CREATURE_ALERT.get(_creature(model), &"alert")
	if s.begins_with("snatch_"):
		var model := StringName(s.substr(7))
		var machine := SoundMachines.kind_of(model)
		if machine != &"":
			var key := StringName("snatch_" + String(machine))
			return key if SoundBank.SHEET.has(key) else &"grip"
		return CREATURE_SNATCH.get(_creature(model), &"grip")
	if s.begins_with("windup_"):
		var model := StringName(s.substr(7))
		var machine := SoundMachines.kind_of(model)
		if machine != &"":
			return StringName("windup_" + String(machine))
		return CREATURE_WINDUP.get(_creature(model), &"windup")
	if s.begins_with("step_"):
		return &"step_dirt"
	return &""


## The sound for a bare alert, snatch or windup done by a mob of roster id
## `kind` (&"" when no mob was found: the generic sound).
static func for_mob(verb: StringName, kind: StringName) -> StringName:
	if kind == &"":
		return resolve(verb)
	return resolve(StringName(String(verb) + "_" + String(kind)))


## "dog.yard" -> dog, "gulls" -> gulls: the model before the variety.
static func _creature(model: StringName) -> StringName:
	var s := String(model).to_lower()
	var dot := s.find(".")
	return StringName(s.substr(0, dot) if dot >= 0 else s)


## What a death sounds like: a machine's light going out, or a body going down.
## kind is the roster id Events.killed carries.
## A gull is too light to go down like a beast: it cries once and is gone.
static func killed_sound(kind: StringName) -> StringName:
	if SoundMachines.kind_of(kind) != &"":
		return &"machine_down"
	return KILLED_CREATURE.get(_creature(kind), &"beast_down")
