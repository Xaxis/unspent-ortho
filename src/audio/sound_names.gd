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
	# hazards: the body answering a pressure, in sounds the world already has.
	# A voice of its own for each (breath, a cough, a counter) is the audio
	# package's to make; until then these read right and nothing is silent.
	&"hazard_cold": &"snow_creak",
	&"hazard_heat": &"heat_tick",
	&"hazard_fumes": &"whiff",
	&"hazard_em": &"relay_click",
	&"hazard_wet": &"gutter_drip",
	&"hazard_ring": &"wire_sing",
	# The slate is what warns you a pressure has begun to bite, and a dull knock
	# is what a place taking a point off you sounds like. Neither is a blow.
	&"hazard_warn": &"ui_slate_whine",
	&"hazard_drain": &"hit_flesh",
	# gear: a spring coil, a wing of plate, a lens reading, a magnet line, a
	# stolen signet answering their challenge in their own voice.
	&"ability_dash": &"dodge",
	&"ability_glide": &"scrape",
	&"ability_land": &"dodge",
	&"ability_scan": &"ui_slate_ping",
	&"ability_grapple": &"grip",
	&"ability_spoof": &"watcher_call",
	&"ability_refused": &"ui_slate_deny",
	# crafts: stepping onto a deck of plate and spars, stepping off it into the
	# shallows, a hull coming apart under a body, and a wreck taken back for its
	# parts. Each wants a voice of its own on the sheet (a pole in water, a lift
	# duct dying); until then these read right and nothing is silent.
	&"craft_board": &"scrape",
	&"craft_off": &"splash",
	&"craft_wreck": &"tool_snap",
	&"craft_salvage": &"break",
	&"craft_refused": &"ui_slate_deny",
	# disposition: a works sounding off over the land when its network files
	# something. A watcher's signal tone, heard from a long way away; it wants a
	# horn of its own on the sheet.
	&"works_horn": &"watcher_call",
	# works: a steel edge worked into a housing, the housing giving, and a whole
	# yard losing its power. Each wants a voice of its own on the sheet (a prise
	# and a groan of plate, a bank of strips dying together); until then these
	# read right and nothing is silent.
	&"works_prise": &"wreck_knock",
	&"works_part": &"arc_snap",
	&"works_dark": &"machine_down",
	# landmarks: a place found from a distance, and a cache opened at one. The
	# finding is the slate marking it, which is a slate sound; the opening is the
	# same hands on the same kind of plate the works is made of.
	&"landmark_found": &"ui_slate_ping",
	&"landmark_open": &"break",
	# raids: the world saying a step is coming, and the small sounds of a plan
	# being kept about a place. Each wants a voice of its own on the sheet — a
	# line of lights coming on over the land, a set gone to static, a stake
	# driven in — and until there is one these read right and nothing is silent.
	&"raid_horizon": &"fog_horn",
	&"raid_drone": &"alert_flock",
	&"raid_static": &"arc_snap",
	&"raid_keeper": &"watcher_call",
	&"raid_notice": &"relay_click",
	&"raid_jammed": &"relay_click",
	# A record got home, and a party loading up what was left lying in the yard.
	# The first is the only thing in the game that raises attention by a whole
	# unit and it happens over the horizon, so it has to be heard.
	&"raid_filed": &"snatch_clerk",
	&"raid_loot": &"pickup",
	&"raid_record": &"pickup",
	&"raid_break": &"break",
	&"raid_snatch": &"grip",
	# defences: a stolen repeater on a crib of logs, and a hand on a switch.
	&"turret_fire": &"arc_snap",
	&"turret_aim": &"relay_click",
	&"piece_switch": &"relay_click",
	# a jump: the push off, the two feet coming down, and the water taking a dive.
	&"jump": &"dodge",
	&"jump_land": &"dodge",
	&"jump_dive": &"splash",
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
	# disposition (32_disposition.gd)
	&"works_horn",
	# works and landmarks (34_works.gd, 22_landmarks.gd)
	&"works_prise", &"works_part", &"works_dark", &"landmark_found", &"landmark_open",
	# ui
	&"menu_move", &"menu_select", &"open_book", &"close_book", &"refused",
	# slate (src/ui, src/systems/90_ui.gd)
	&"ui_slate_click", &"ui_slate_confirm", &"ui_slate_back", &"ui_slate_deny", &"ui_slate_wake",
	&"ui_slate_sleep", &"ui_slate_switch", &"ui_slate_whine", &"ui_slate_ping",
	# crafts (44_crafts.gd)
	&"craft_board", &"craft_off", &"craft_wreck", &"craft_salvage", &"craft_refused",
	# hazards and gear (52_hazards.gd, 54_gear.gd)
	&"hazard_cold", &"hazard_heat", &"hazard_fumes", &"hazard_em", &"hazard_wet",
	&"hazard_ring", &"hazard_warn", &"hazard_drain", &"ability_dash", &"ability_glide", &"ability_land",
	&"ability_scan", &"ability_grapple", &"ability_spoof", &"ability_refused",
	# defences (46_settlements.gd, 47_defences.gd)
	&"turret_fire", &"turret_aim", &"piece_switch",
	# the jump (54_gear.gd)
	&"jump", &"jump_land", &"jump_dive",
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
