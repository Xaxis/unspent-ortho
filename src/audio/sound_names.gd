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
##   snatch_<model>   that machine's taking, else grip
##   step_<family>    that footfall, else dirt

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
}

const BUILD := {&"fire": &"build_fire", &"bench": &"build_bench", &"kiln": &"build_kiln"}

## Living things answer with their own voice.
const CREATURE_ALERT := {&"dog": &"dog_bark", &"bull": &"bull_snort", &"gull": &"gull_cry", &"gulls": &"gull_cry"}

## Every name the other packages were seen emitting (fight, survival, sky, ui,
## on their branches), plus the brief's own list. A test holds that each one
## resolves, so an integration never merges into silence.
const EMITTED: Array[StringName] = [
	# brief
	&"swing", &"whiff", &"hit_flesh", &"hit_plate", &"dodge", &"grip", &"pull", &"break", &"dig",
	&"fell", &"cut", &"gather", &"craft", &"eat", &"fire", &"splash", &"ui_move", &"ui_accept",
	&"ui_back", &"thunder", &"step_sand", &"step_grass", &"step_stone", &"step_snow",
	# fight
	&"loose", &"second_act", &"watcher_call", &"killed", &"alert_watcher", &"alert_longlegs",
	&"alert_harvester", &"alert_flock", &"alert_runner", &"alert_cutter", &"alert_hauler",
	&"alert_warden", &"alert_sweeper", &"alert_dredger", &"alert_lineman", &"alert_clerk",
	&"alert_dog", &"alert_bull", &"alert_gull", &"snatch_flock", &"snatch_warden", &"snatch_clerk",
	&"snatch_gull",
	# survival
	&"refuse", &"work_break", &"work_dig", &"work_fell", &"work_cut", &"work_gather",
	&"work_scrape", &"work_tap", &"work_turn", &"took", &"sleep", &"build_fire", &"build_bench",
	&"build_kiln", &"collapse", &"make", &"hone", &"reedge",
	# sky
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
		var key := StringName("snatch_" + String(machine if machine != &"" else _creature(model)))
		return key if SoundBank.SHEET.has(key) else &"grip"
	if s.begins_with("step_"):
		return &"step_dirt"
	return &""


## "dog.yard" -> dog, "gulls" -> gulls: the model before the variety.
static func _creature(model: StringName) -> StringName:
	var s := String(model).to_lower()
	var dot := s.find(".")
	return StringName(s.substr(0, dot) if dot >= 0 else s)


## What a death sounds like: a machine's light going out, or a body going down.
## kind is the roster id Events.killed carries.
static func killed_sound(kind: StringName) -> StringName:
	return &"machine_down" if SoundMachines.kind_of(kind) != &"" else &"beast_down"
