class_name Roster
## Everything that hunts, holds, files or steals from the player, as data.
## Numbers are the source game's content (design-extract §8, and its threats
## table): speeds in the source's tiles/s for a player walking 5 (scaled by
## FightRules.SPEED_SCALE at use), `quick` the close-quarters speed x 100,
## bites in ms and tiles. Names are working names until the story rewrite.
##
## Schema:
##   model: StringName       FigureModel.create(model)
##   machine: bool           FOUND: plated, never flinches, drops scrap
##   approach: StringName    errand | charge | rush | dart
##   part: StringName        working part side: front back left right none
##   pace, dash: float       tiles/s (source scale); quick: int close-quarters x100
##   radius, height: float   hit body (tiles) and figure height (world units)
##   life: int               source life (machines scaled, see FightRules)
##   sees, hears, racket     tiles; reach: tiles at which it starts attacking
##   ready, forget: int      beats (100 ms) before chasing / before giving up
##   tether, safe: float     how far from home it will chase / flee to
##   nerve: int              flees at or below this % health (100 = never)
##   stagger: bool           knocked back and stunned by blows (animals)
##   invuln: int             ms of i-frames after a hurt (capped)
##   turns: int              charge: re-aim pause = 420 ms x turns
##   stretch: int            errand: tiles each way along its line (0 = stands)
##   touch: int              contact damage (bodies without a bite)
##   bite, then: Dictionary  Blow dicts; then replaces bite at then_at (fraction)
##   hits: Dictionary        darts: {minutes, again, cap, hurts, food, files}
##   takes: float            extra world minutes when it downs you
##   drops: int              scrap when killed
##   linger: float           seconds the dead lie
##   chance: int             spawn weight; per 200 ms roll, hash % 2000 < sum
##   where: Dictionary       countries[], grounds[], green_min, green_max,
##                           day_min, hours [from, to), weather[], calm, rise,
##                           near_props[] (PropKind names within 4 tiles), wet
##   keeps_to: Array         ground names it may move on (a dredger keeps to water)
##   through: bool           moves through the player's body (charges, sweepers)
##   sight_only: bool        notices by eye alone

## Standing water and the mud at its edge: where a dredger may go (a bank of turf is the answer to one).
const WET := ["water", "blackwater", "river", "mud", "marsh", "shallow", "tarn"]
## The five countries that are not burning.
const GREEN_COUNTRIES := ["coast", "moss", "pinewood", "snowfield", "bonelands"]

const DEFS := {
	&"watcher": {
		"model": &"watcher", "machine": true, "approach": &"errand", "stretch": 0, "part": &"front",
		"pace": 0.1, "dash": 0.1, "radius": 0.35, "height": 1.8, "life": 60,
		"sees": 14, "hears": 0, "racket": 18, "reach": 10, "ready": 4, "forget": 30, "tether": 12, "safe": 12,
		"nerve": 100, "invuln": 500, "touch": 2, "sight_only": true, "calls": 18,
		"takes": 70.0, "drops": 1, "linger": 30.0, "chance": 3,
		"where": {"green_min": 20, "day_min": 2, "rise": true},
	},
	&"longlegs": {
		"model": &"longlegs", "machine": true, "approach": &"charge", "turns": 4, "part": &"back",
		"pace": 7.0, "dash": 11.0, "quick": 340, "radius": 0.55, "height": 2.0, "life": 80,
		"sees": 10, "hears": 8, "racket": 20, "reach": 3, "ready": 3, "forget": 18, "tether": 34, "safe": 16,
		"nerve": 100, "invuln": 520, "through": true,
		"bite": {"swing": [540, 140, 320, 600], "reach": 1.6, "width": 1.4, "dmg": 4, "knock": 8.5, "knock_ms": 300},
		"takes": 110.0, "drops": 3, "linger": 40.0, "chance": 4,
		"where": {"green_min": 55, "day_min": 3},
	},
	&"harvester": {
		"model": &"harvester", "machine": true, "approach": &"charge", "turns": 1, "part": &"front",
		"pace": 4.0, "dash": 10.0, "quick": 380, "radius": 1.2, "height": 1.2, "life": 90,
		"sees": 9, "hears": 6, "racket": 22, "reach": 2, "ready": 3, "forget": 20, "tether": 40, "safe": 18,
		"nerve": 100, "invuln": 500, "through": true,
		"bite": {"swing": [560, 150, 340, 620], "reach": 1.4, "width": 2.2, "dmg": 4, "knock": 8.0, "knock_ms": 300},
		"then_at": 0.6,
		"then": {"swing": [300, 170, 260, 380], "reach": 1.5, "width": 2.6, "dmg": 5, "knock": 9.0, "knock_ms": 320},
		"takes": 60.0, "drops": 2, "linger": 50.0, "chance": 5,
		"where": {"countries": ["coast"], "grounds": ["grass", "heath", "furrow"], "green_min": 22},
	},
	&"flock": {
		"model": &"flock", "machine": true, "approach": &"dart", "part": &"none",
		"pace": 13.0, "dash": 18.0, "radius": 0.6, "height": 1.0, "life": 30,
		"sees": 16, "hears": 7, "racket": 12, "reach": 2, "ready": 2, "forget": 30, "tether": 22, "safe": 16,
		"nerve": 100, "invuln": 300,
		"hits": {"minutes": 90.0, "hurts": true, "line": "It passes over you low, and leaves you wet and stinging."},
		"takes": 300.0, "drops": 1, "linger": 20.0, "chance": 5,
		"where": {"countries": ["coast"], "grounds": ["mud", "grass", "furrow", "heath", "road"], "green_min": 20,
			"hours": [6, 19], "weather": ["fair", "grey", "fog", "clear", "overcast"], "calm": true},
	},
	&"runner": {
		"model": &"runner", "machine": true, "approach": &"rush", "part": &"back",
		"pace": 6.5, "dash": 6.5, "quick": 300, "radius": 0.3, "height": 1.3, "life": 45,
		"sees": 11, "hears": 10, "racket": 10, "reach": 1, "ready": 2, "forget": 20, "tether": 28, "safe": 12,
		"nerve": 100, "invuln": 400,
		"bite": {"swing": [340, 110, 240, 460], "reach": 1.0, "width": 0.9, "dmg": 2, "knock": 4.5, "knock_ms": 200},
		"takes": 35.0, "drops": 1, "linger": 25.0, "chance": 4,
		"where": {"grounds": ["road", "floor", "grass", "sand", "mud"], "green_min": 14, "hours": [6, 13]},
	},
	&"cutter": {
		"model": &"cutter", "machine": true, "approach": &"rush", "part": &"back",
		"pace": 5.5, "dash": 12.0, "quick": 300, "radius": 0.5, "height": 1.4, "life": 70,
		"sees": 11, "hears": 2, "racket": 16, "reach": 2, "ready": 2, "forget": 14, "tether": 26, "safe": 14,
		"nerve": 100, "invuln": 420,
		"bite": {"swing": [420, 120, 300, 520], "reach": 1.1, "width": 1.4, "dmg": 3, "knock": 6.0, "knock_ms": 240},
		"takes": 70.0, "drops": 2, "linger": 40.0, "chance": 5,
		"where": {"countries": ["bonelands"], "grounds": ["limestone", "rock", "gravel", "scree", "bone"], "green_min": 18},
	},
	&"hauler": {
		"model": &"hauler", "machine": true, "approach": &"charge", "turns": 5, "part": &"left",
		"pace": 4.5, "dash": 10.5, "quick": 300, "radius": 0.6, "height": 0.9, "life": 75,
		"sees": 8, "hears": 7, "racket": 19, "reach": 2, "ready": 3, "forget": 16, "tether": 36, "safe": 18,
		"nerve": 100, "invuln": 540, "through": true,
		"bite": {"swing": [600, 160, 360, 660], "reach": 1.5, "width": 2.0, "dmg": 5, "knock": 9.5, "knock_ms": 320},
		"then_at": 0.35,
		"then": {"swing": [320, 130, 240, 400], "reach": 1.2, "width": 1.4, "dmg": 3, "knock": 6.0, "knock_ms": 240},
		"takes": 50.0, "drops": 3, "linger": 35.0, "chance": 5,
		"where": {"countries": ["bonelands", "coast"], "green_min": 20},
	},
	&"warden": {
		"model": &"warden", "machine": true, "approach": &"dart", "part": &"front",
		"pace": 6.0, "dash": 9.5, "radius": 0.45, "height": 1.6, "life": 55,
		"sees": 14, "hears": 9, "racket": 9, "reach": 2, "ready": 4, "forget": 25, "tether": 30, "safe": 10,
		"nerve": 100, "invuln": 400,
		"hits": {"minutes": 60.0, "again": 60.0, "cap": 240.0, "arrest": true,
			"line": "A warden stands you at the side of the track until it is done with you."},
		"takes": 240.0, "drops": 2, "linger": 30.0, "chance": 5,
		"where": {"countries": ["pinewood"], "green_min": 12, "hours": [20, 5]},
	},
	&"sweeper": {
		"model": &"sweeper", "machine": true, "approach": &"errand", "stretch": 7, "part": &"back",
		"pace": 5.0, "dash": 5.0, "radius": 0.5, "height": 1.0, "life": 50,
		"sees": 0, "hears": 0, "racket": 13, "reach": 3, "ready": 2, "forget": 10, "tether": 12, "safe": 10,
		"nerve": 100, "invuln": 400, "touch": 2, "through": true,
		"takes": 40.0, "drops": 1, "linger": 30.0, "chance": 5,
		"where": {"countries": ["pinewood"], "grounds": ["needles", "road", "mud", "floor", "grass"], "green_min": 12, "hours": [5, 11]},
	},
	&"dredger": {
		"model": &"dredger", "machine": true, "approach": &"rush", "part": &"front",
		"pace": 8.5, "dash": 13.0, "quick": 260, "radius": 0.65, "height": 0.6, "life": 85,
		"sees": 8, "hears": 13, "racket": 14, "reach": 2, "ready": 3, "forget": 12, "tether": 18, "safe": 12,
		"nerve": 100, "invuln": 460, "keeps_to": WET,
		"bite": {"swing": [380, 140, 280, 560], "reach": 1.3, "width": 1.6, "dmg": 0, "knock": 0.0, "knock_ms": 0, "grip": 4},
		"then_at": 0.45,
		"then": {"swing": [220, 160, 220, 300], "reach": 1.5, "width": 1.8, "dmg": 4, "knock": 8.0, "knock_ms": 300},
		"takes": 80.0, "drops": 2, "linger": 45.0, "chance": 5,
		"where": {"countries": ["moss", "coast"], "grounds": WET, "green_min": 16},
	},
	&"lineman": {
		"model": &"lineman", "machine": true, "approach": &"rush", "part": &"front",
		"pace": 4.0, "dash": 9.0, "quick": 320, "radius": 0.35, "height": 1.4, "life": 60,
		"sees": 12, "hears": 9, "racket": 11, "reach": 3, "ready": 3, "forget": 14, "tether": 24, "safe": 12,
		"nerve": 100, "invuln": 440,
		"bite": {"swing": [400, 120, 280, 520], "reach": 1.9, "width": 1.0, "dmg": 0, "knock": 0.0, "knock_ms": 0, "grip": 3},
		"takes": 45.0, "drops": 2, "linger": 25.0, "chance": 3,
		"where": {"countries": ["snowfield"], "grounds": ["snow", "ice", "rock", "gravel", "grass"], "green_min": 34, "near_props": ["pylon", "pole"]},
	},
	&"clerk": {
		"model": &"clerk", "machine": true, "approach": &"dart", "part": &"none",
		"pace": 7.5, "dash": 14.0, "radius": 0.3, "height": 1.2, "life": 6,
		"sees": 15, "hears": 8, "racket": 0, "reach": 2, "ready": 5, "forget": 10, "tether": 20, "safe": 18,
		"nerve": 100, "invuln": 300,
		"hits": {"minutes": 15.0, "files": true, "line": "It looks you over from very close, and goes."},
		"takes": 60.0, "drops": 0, "linger": 20.0, "chance": 3,
		"where": {"countries": ["burning"], "grounds": ["ash", "clinker", "rock", "gravel", "mud", "road"]},
	},
	&"dog.yard": {
		"model": &"dog", "machine": false, "approach": &"rush", "part": &"none",
		"pace": 3.0, "dash": 7.5, "quick": 330, "radius": 0.3, "height": 0.5, "life": 4,
		"sees": 8, "hears": 14, "racket": 0, "reach": 1, "ready": 2, "forget": 24, "tether": 20, "safe": 12,
		"nerve": 34, "invuln": 500, "stagger": true,
		"bite": {"swing": [280, 90, 200, 380], "reach": 0.85, "width": 0.9, "dmg": 2, "knock": 5.0, "knock_ms": 220},
		"takes": 25.0, "drops": 0, "linger": 45.0, "chance": 4,
		"where": {"countries": GREEN_COUNTRIES, "green_max": 40},
	},
	&"dog.feral": {
		"model": &"dog", "machine": false, "approach": &"rush", "part": &"none",
		"pace": 3.4, "dash": 7.5, "quick": 355, "radius": 0.3, "height": 0.5, "life": 6,
		"sees": 9, "hears": 14, "racket": 0, "reach": 1, "ready": 1, "forget": 24, "tether": 20, "safe": 14,
		"nerve": 18, "invuln": 500, "stagger": true,
		"bite": {"swing": [255, 90, 180, 320], "reach": 0.9, "width": 0.9, "dmg": 3, "knock": 5.5, "knock_ms": 240},
		"takes": 40.0, "drops": 0, "linger": 45.0, "chance": 6,
		"where": {"countries": GREEN_COUNTRIES, "green_min": 55, "day_min": 6},
	},
	&"bull.field": {
		"model": &"bull", "machine": false, "approach": &"charge", "turns": 3, "part": &"none",
		"pace": 3.5, "dash": 10.0, "quick": 470, "radius": 0.5, "height": 1.1, "life": 6,
		"sees": 7, "hears": 10, "racket": 0, "reach": 1, "ready": 3, "forget": 16, "tether": 30, "safe": 16,
		"nerve": 30, "invuln": 600, "stagger": true, "through": true,
		"bite": {"swing": [520, 130, 320, 600], "reach": 1.25, "width": 1.6, "dmg": 4, "knock": 9.0, "knock_ms": 320},
		"takes": 45.0, "drops": 0, "linger": 60.0, "chance": 5,
		"where": {"countries": ["coast", "pinewood", "bonelands"], "grounds": ["grass", "heath", "furrow"], "green_min": 10},
	},
	&"gulls": {
		"model": &"gull", "machine": false, "hostile": false, "approach": &"dart", "part": &"none",
		"pace": 7.0, "dash": 10.0, "radius": 0.22, "height": 0.4, "life": 1,
		"sees": 12, "hears": 8, "racket": 0, "reach": 1, "ready": 1, "forget": 6, "tether": 30, "safe": 10,
		"nerve": 100, "invuln": 300, "stagger": true,
		"hits": {"food": 1, "line": "A gull comes down on your bag and is gone with something in it.",
			"empty_line": "A gull comes down on your bag, finds nothing, and goes."},
		"takes": 0.0, "drops": 0, "linger": 8.0, "chance": 14,
		"where": {"countries": GREEN_COUNTRIES, "grounds": ["sand", "shingle", "gravel", "strand"], "hours": [6, 20]},
	},
}


static func has(kind: StringName) -> bool:
	return DEFS.has(kind)


static func row(kind: StringName) -> Dictionary:
	return DEFS.get(kind, {})


static func kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in DEFS:
		out.append(k)
	return out


## Short names as typed on the command line (--spawn=dog): the exact id or a prefix before the dot.
static func resolve(name: String) -> StringName:
	var sn := StringName(name)
	if DEFS.has(sn):
		return sn
	for k: StringName in DEFS:
		if String(k).begins_with(name + "."):
			return k
	return &""


## Fight health: a machine's source life scaled for made tools; an animal's as is.
static func health_of(kind: StringName) -> int:
	var r := row(kind)
	var life: int = r.get("life", 1)
	if r.get("machine", false):
		return maxi(1, roundi(life * FightRules.MACHINE_LIFE_SCALE))
	return life


static func bite(kind: StringName) -> Blow:
	var r := row(kind)
	if not r.has("bite"):
		return null
	var b := Blow.from_dict(r.bite)
	b.creep = 1.0
	return b


static func second_bite(kind: StringName) -> Blow:
	var r := row(kind)
	if not r.has("then"):
		return null
	var b := Blow.from_dict(r.then)
	b.creep = 1.0
	return b
