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
##   crosses: StringName     what DEEP water is to it: &"swim" (it goes in after
##                           you) or &"fly" (it goes over); absent, the waterline
##                           stops it, which is most of the roster (src/core/swim.gd)
##   role: StringName        its place in the machines' plan (Roles): worker keeper
##                           watcher hunter recycler. The role decides the default
##                           disposition, what turns it, its sight cone and whether
##                           it fights at all. Omitted, it is read from `disposition`.
##   disposition: StringName hostile (default) | indifferent | observant | wary (VISION §2):
##                           an indifferent worker goes about its round until struck
##                           or stood in the way of; a hostile one hunts. What a live
##                           body thinks of the player is the role plus the region's
##                           interference (Disposition.of); this is its starting point.
##   overrun: float          a machine's bite carries it on through its recovery at
##                           quick x this (the overcommit that shows its back)
##   recover_turn: float     rad/s it turns while spent after a bite (FightRules.RECOVER_TURN)
##   guarded: bool           its (front) part throws a blow off like plate unless the
##                           machine is open: spent, stalled or not roused (FightSim.reaches_part)
##   through: bool           moves through the player's body (charges, sweepers)
##   sight_only: bool        notices by eye alone
##   sentinel: StringName    this body is a landscape's keeper: the design id in
##                           src/core/sentinel/designs/ whose phases drive it

## Standing water and the mud at its edge: where a dredger may go (a bank of turf is the answer to one).
const WET := ["water", "blackwater", "river", "mud", "marsh", "shallow", "tarn"]
## What a dredger keeps to once it is hunting: the same wet ground, and the deep
## it can swim. It is never PUT OUT in the deep (`where.grounds` is WET), so the
## sea is where it follows you to and not where it comes from.
const WET_AND_DEEP := ["water", "blackwater", "river", "mud", "marsh", "shallow", "tarn", "deep water"]
## The five countries that are not burning.
const GREEN_COUNTRIES := ["coast", "moss", "pinewood", "snowfield", "bonelands"]

const DEFS := {
	&"watcher": {
		"model": &"watcher", "role": &"watcher", "machine": true, "approach": &"errand", "stretch": 0, "part": &"front",
		"pace": 0.1, "dash": 0.1, "radius": 0.35, "height": 1.8, "life": 60,
		"sees": 14, "hears": 0, "racket": 18, "reach": 10, "ready": 4, "forget": 30, "tether": 12, "safe": 12,
		"nerve": 100, "invuln": 500, "touch": 2, "sight_only": true, "calls": 18, "disposition": &"observant",
		"takes": 70.0, "drops": 1, "linger": 30.0, "chance": 3,
		"where": {"green_min": 20, "day_min": 2, "rise": true},
	},
	&"longlegs": {
		"model": &"longlegs", "role": &"hunter", "machine": true, "approach": &"charge", "turns": 4, "part": &"back",
		"pace": 7.0, "dash": 11.0, "quick": 340, "radius": 0.55, "height": 2.0, "life": 80,
		"sees": 10, "hears": 8, "racket": 20, "reach": 3, "ready": 3, "forget": 18, "tether": 34, "safe": 16,
		"nerve": 100, "invuln": 520, "through": true,
		"bite": {"swing": [540, 140, 320, 600], "reach": 1.6, "width": 1.4, "dmg": 4, "knock": 8.5, "knock_ms": 300},
		"takes": 110.0, "drops": 3, "linger": 40.0, "chance": 4,
		"where": {"green_min": 55, "day_min": 3},
	},
	# A first-hour machine on the coast fields: its blades are its working part,
	# so its opening is the long stand after a bite, the blades jammed, while it
	# grinds round. Life, bite and second act softened from the source (90, 4, 5
	# at a 300 ms tell) so a player who reads it wins with the start knife.
	&"harvester": {
		"model": &"harvester", "role": &"worker", "machine": true, "approach": &"charge", "turns": 1, "part": &"front",
		"pace": 4.0, "dash": 10.0, "quick": 380, "radius": 1.2, "height": 1.2, "life": 72,
		"sees": 9, "hears": 6, "racket": 22, "reach": 2, "ready": 3, "forget": 20, "tether": 40, "safe": 18,
		"nerve": 100, "invuln": 500, "through": true, "disposition": &"indifferent", "guarded": true,
		"bite": {"swing": [560, 150, 700, 900], "reach": 1.4, "width": 2.2, "dmg": 3, "knock": 8.0, "knock_ms": 300},
		# Its second act is faster and wider, but no harder: a first-hour worker at the
		# end of its strength does not take a player from half health to down in a second.
		"then_at": 0.35,
		"then": {"swing": [480, 170, 600, 700], "reach": 1.5, "width": 2.6, "dmg": 3, "knock": 9.0, "knock_ms": 320},
		"takes": 60.0, "drops": 2, "linger": 50.0, "chance": 5,
		"where": {"countries": ["coast"], "grounds": ["grass", "heath", "furrow"], "green_min": 22},
	},
	&"flock": {
		"model": &"flock", "role": &"hunter", "machine": true, "approach": &"dart", "part": &"none",
		# It passes over you low: water is nothing to it (Swim).
		"crosses": &"fly",
		"pace": 13.0, "dash": 18.0, "radius": 0.6, "height": 1.0, "life": 30,
		"sees": 16, "hears": 7, "racket": 12, "reach": 2, "ready": 2, "forget": 30, "tether": 22, "safe": 16,
		"nerve": 100, "invuln": 300,
		"hits": {"minutes": 90.0, "hurts": true, "line": "It passes over you low, and leaves you wet and stinging."},
		"takes": 300.0, "drops": 1, "linger": 20.0, "chance": 5,
		"where": {"countries": ["coast"], "grounds": ["mud", "grass", "furrow", "heath", "road"], "green_min": 20,
			"hours": [6, 19], "weather": ["fair", "grey", "fog", "clear", "overcast"], "calm": true},
	},
	# The first hunter most players meet: its drive is at its back, and its lunge
	# overruns, so the dodge that takes you out of the bite leaves its back to you.
	&"runner": {
		"model": &"runner", "role": &"hunter", "machine": true, "approach": &"rush", "part": &"back",
		"pace": 6.5, "dash": 6.5, "quick": 300, "radius": 0.3, "height": 1.3, "life": 45,
		"sees": 11, "hears": 10, "racket": 10, "reach": 1, "ready": 2, "forget": 20, "tether": 28, "safe": 12,
		"nerve": 100, "invuln": 400, "overrun": 0.9,
		"bite": {"swing": [420, 110, 380, 620], "reach": 1.0, "width": 0.9, "dmg": 2, "knock": 4.5, "knock_ms": 200},
		"takes": 35.0, "drops": 1, "linger": 25.0, "chance": 4,
		"where": {"grounds": ["road", "floor", "grass", "sand", "mud"], "green_min": 14, "hours": [6, 13]},
	},
	&"cutter": {
		"model": &"cutter", "role": &"worker", "machine": true, "approach": &"rush", "part": &"back",
		"pace": 5.5, "dash": 12.0, "quick": 300, "radius": 0.5, "height": 1.4, "life": 70,
		"sees": 11, "hears": 2, "racket": 16, "reach": 2, "ready": 2, "forget": 14, "tether": 26, "safe": 14,
		"nerve": 100, "invuln": 420, "overrun": 0.9, "disposition": &"indifferent",
		"bite": {"swing": [420, 120, 380, 620], "reach": 1.1, "width": 1.4, "dmg": 3, "knock": 6.0, "knock_ms": 240},
		"takes": 70.0, "drops": 2, "linger": 40.0, "chance": 5,
		"where": {"countries": ["bonelands"], "grounds": ["limestone", "rock", "gravel", "scree", "bone"], "green_min": 18},
	},
	&"hauler": {
		"model": &"hauler", "role": &"worker", "machine": true, "approach": &"charge", "turns": 5, "part": &"left",
		"pace": 4.5, "dash": 10.5, "quick": 300, "radius": 0.6, "height": 0.9, "life": 66,
		"sees": 8, "hears": 7, "racket": 19, "reach": 2, "ready": 3, "forget": 16, "tether": 36, "safe": 18,
		"nerve": 100, "invuln": 540, "through": true, "disposition": &"indifferent",
		"bite": {"swing": [600, 160, 600, 800], "reach": 1.5, "width": 2.0, "dmg": 4, "knock": 9.5, "knock_ms": 320},
		"then_at": 0.35,
		"then": {"swing": [320, 130, 240, 400], "reach": 1.2, "width": 1.4, "dmg": 3, "knock": 6.0, "knock_ms": 240},
		"takes": 50.0, "drops": 3, "linger": 35.0, "chance": 5,
		"where": {"countries": ["bonelands", "coast"], "green_min": 20},
	},
	&"warden": {
		"model": &"warden", "role": &"keeper", "machine": true, "approach": &"dart", "part": &"front",
		"pace": 6.0, "dash": 9.5, "radius": 0.45, "height": 1.6, "life": 55,
		"sees": 14, "hears": 9, "racket": 9, "reach": 2, "ready": 4, "forget": 25, "tether": 30, "safe": 10,
		"nerve": 100, "invuln": 400, "disposition": &"wary",
		"hits": {"minutes": 60.0, "again": 60.0, "cap": 240.0, "arrest": true,
			"line": "A warden stands you at the side of the track until it is done with you."},
		"takes": 240.0, "drops": 2, "linger": 30.0, "chance": 5,
		"where": {"countries": ["pinewood"], "green_min": 12, "hours": [20, 5]},
	},
	&"sweeper": {
		"model": &"sweeper", "role": &"worker", "machine": true, "approach": &"errand", "stretch": 7, "part": &"back",
		"pace": 5.0, "dash": 5.0, "radius": 0.5, "height": 1.0, "life": 50,
		"sees": 0, "hears": 0, "racket": 13, "reach": 3, "ready": 2, "forget": 10, "tether": 12, "safe": 10,
		"nerve": 100, "invuln": 400, "touch": 2, "through": true, "disposition": &"indifferent",
		"takes": 40.0, "drops": 1, "linger": 30.0, "chance": 5,
		"where": {"countries": ["pinewood"], "grounds": ["needles", "road", "mud", "floor", "grass"], "green_min": 12, "hours": [5, 11]},
	},
	&"dredger": {
		"model": &"dredger", "role": &"hunter", "machine": true, "approach": &"rush", "part": &"front",
		# The one machine the water does not stop: it was built to work in it, and
		# it is why swimming away is a good idea and never a safe one (Swim).
		"crosses": &"swim",
		"pace": 8.5, "dash": 13.0, "quick": 260, "radius": 0.65, "height": 0.6, "life": 85,
		"sees": 8, "hears": 13, "racket": 14, "reach": 2, "ready": 3, "forget": 12, "tether": 18, "safe": 12,
		"nerve": 100, "invuln": 460,
		"bite": {"swing": [380, 140, 280, 560], "reach": 1.3, "width": 1.6, "dmg": 0, "knock": 0.0, "knock_ms": 0, "grip": 4},
		"then_at": 0.45,
		"then": {"swing": [340, 160, 300, 420], "reach": 1.5, "width": 1.8, "dmg": 4, "knock": 8.0, "knock_ms": 300},
		"takes": 80.0, "drops": 2, "linger": 45.0, "chance": 5,
		"keeps_to": WET_AND_DEEP,
		"where": {"countries": ["moss", "coast"], "grounds": WET, "green_min": 16},
	},
	# `near_props` is the whole of what a lineman is, and it is a narrow gate on its
	# own: a pylon or pole within 4 tiles of snowfield ground is 188-431 tiles on a
	# 65536-tile island. `green_min` 34 on top of it left SIX on seed 1, and forty
	# minutes stood at the best of them rolled nothing — and a lineman is a worker,
	# so nothing ever SENDS one either, which left `line_coil` with no door at all.
	# 10 is the roster's own floor and says the one thing the gate was for: no
	# machine works the line inside a village. Measured, tiles at green_min
	# 0/10/34 — seed 1: 188/170/6, seed 4: 431/424/41, seed 7: 197/194/35.
	&"lineman": {
		"model": &"lineman", "role": &"worker", "machine": true, "approach": &"rush", "part": &"front",
		"pace": 4.0, "dash": 9.0, "quick": 320, "radius": 0.35, "height": 1.4, "life": 60,
		"sees": 12, "hears": 9, "racket": 11, "reach": 3, "ready": 3, "forget": 14, "tether": 24, "safe": 12,
		"nerve": 100, "invuln": 440, "disposition": &"indifferent",
		"bite": {"swing": [400, 120, 280, 520], "reach": 1.9, "width": 1.0, "dmg": 0, "knock": 0.0, "knock_ms": 0, "grip": 3},
		"takes": 45.0, "drops": 2, "linger": 25.0, "chance": 3,
		"where": {"countries": ["snowfield"], "grounds": ["snow", "ice", "rock", "gravel", "grass"], "green_min": 10, "near_props": ["pylon", "pole"]},
	},
	&"clerk": {
		"model": &"clerk", "role": &"watcher", "machine": true, "approach": &"dart", "part": &"none",
		"pace": 7.5, "dash": 14.0, "radius": 0.3, "height": 1.2, "life": 6,
		"sees": 15, "hears": 8, "racket": 0, "reach": 2, "ready": 5, "forget": 10, "tether": 20, "safe": 18,
		"nerve": 100, "invuln": 300, "disposition": &"observant",
		"hits": {"minutes": 15.0, "files": true, "line": "It looks you over from very close, and goes."},
		"takes": 60.0, "drops": 0, "linger": 20.0, "chance": 3,
		"where": {"countries": ["burning"], "grounds": ["ash", "clinker", "rock", "gravel", "mud", "road"]},
	},
	# A MACHINE THAT PASSES, in a city the settlement was accepted in. Drawn as a
	# person (src/models/machines/passer.gd) and answering as a machine, because
	# nothing that reads a body reads its model. `watcher` is the role and it is
	# the point: it files nothing and throws no blow, so unlike the clerk it does
	# not even take a count — it is here to BE the agreement, walking about in a
	# good coat, and `Roles.TURNS[WATCHER]` is empty so nothing the player does
	# turns it. The only one in the landscape not working.
	#
	# `errand` never lunges (Mob._lean) and the pace is a stroll: everybody else
	# on this street is somewhere they have to be, and it is not.
	&"passer": {
		"model": &"passer", "role": &"watcher", "machine": true, "approach": &"errand", "part": &"none",
		"passes": true,
		"pace": 1.6, "dash": 1.6, "radius": 0.34, "height": 1.7, "life": 40,
		"sees": 13, "hears": 7, "racket": 0, "reach": 2, "ready": 4, "forget": 12, "tether": 30, "safe": 14,
		"nerve": 100, "invuln": 320, "disposition": &"observant",
		# No `takes`: that is the minutes a body costs you when it DOWNS you, and
		# `TargetRead.powers` prints it as "carries you off". With no bite and no
		# hits this one can never down anybody, so the line was the read telling
		# the player a thing about this body that is not true — caught in the
		# tour's own frame of the read panel, which is what those frames are for.
		"drops": 0, "linger": 30.0, "chance": 3,
		# The city admits it through its own BiomeDef.roster; nowhere else has one.
		"where": {"countries": ["slums"], "grounds": ["road", "floor", "gravel", "rock"]},
	},
	&"dog.yard": {
		# A dog goes in after you: the beasts were never the ones the water stopped.
		"crosses": &"swim",
		"model": &"dog", "machine": false, "approach": &"rush", "part": &"none",
		"pace": 3.0, "dash": 7.5, "quick": 330, "radius": 0.3, "height": 0.5, "life": 4,
		"sees": 8, "hears": 14, "racket": 0, "reach": 1, "ready": 2, "forget": 24, "tether": 20, "safe": 12,
		"nerve": 34, "invuln": 500, "stagger": true,
		"bite": {"swing": [280, 90, 200, 380], "reach": 0.85, "width": 0.9, "dmg": 2, "knock": 5.0, "knock_ms": 220},
		"takes": 25.0, "drops": 0, "linger": 45.0, "chance": 4,
		"where": {"countries": GREEN_COUNTRIES, "green_max": 40},
	},
	&"dog.feral": {
		# A dog goes in after you: the beasts were never the ones the water stopped.
		"crosses": &"swim",
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
		# They sit on it (Swim).
		"crosses": &"fly",
		"pace": 7.0, "dash": 10.0, "radius": 0.22, "height": 0.4, "life": 1,
		"sees": 12, "hears": 8, "racket": 0, "reach": 1, "ready": 1, "forget": 6, "tether": 30, "safe": 10,
		"nerve": 100, "invuln": 300, "stagger": true,
		"hits": {"food": 1, "line": "A gull comes down on your bag and is gone with something in it.",
			"empty_line": "A gull comes down on your bag, finds nothing, and goes."},
		"takes": 0.0, "drops": 0, "linger": 8.0, "chance": 14,
		"where": {"countries": GREEN_COUNTRIES, "grounds": ["sand", "shingle", "gravel", "strand"], "hours": [6, 20]},
	},

	# --- The Frost Sea's own worker (docs/LANDSCAPES.md §2) -------------------
	# A low sled with a circular saw and one amber lens, working the ice for the
	# soundings line. It keeps to the frost sea and to the ice: the one machine
	# kind that works only there, which is what gives a landscape a machine of
	# its own (docs/ROADMAP.md M3, the plan layer). A worker: it turns on being
	# blocked or struck (Roles.TURNS) and on nothing else.
	#
	# Its errand is meant to run along the machines' survey bearing, and its cut
	# is meant to open a line of BLACKWATER behind it that refreezes over thirty
	# world minutes. Neither is here: an errand's line is snapped to the compass
	# by MobState, and the cut is shared system 5 (docs/LANDSCAPES.md, the
	# time-varying ground edit), which lands once for this, the listener's ring
	# and the tide together. Until then it is a sled that saws the ice and turns
	# on whoever gets in its way.
	&"icesaw": {
		"model": &"icesaw", "role": &"worker", "machine": true, "approach": &"errand", "stretch": 12, "part": &"front",
		"pace": 5.0, "dash": 6.0, "quick": 300, "radius": 0.55, "height": 0.95, "life": 58,
		"sees": 8, "hears": 5, "racket": 16, "reach": 2, "ready": 2, "forget": 12, "tether": 30, "safe": 14,
		"nerve": 100, "invuln": 420, "through": true, "disposition": &"indifferent", "overrun": 0.8,
		"bite": {"swing": [460, 130, 420, 640], "reach": 1.2, "width": 1.3, "dmg": 3, "knock": 7.0, "knock_ms": 260},
		# Chance 3, not a coast worker's 5: the plan's own things are the rarest
		# thing on this sea (frost_sea.gd's scatter says so of its works), and a
		# sled on every frame of ice would say the opposite.
		#
		# IT WORKS THE COLD HOURS. Sea ice is hardest before dawn and a cut made
		# then has closed behind the sled by morning, so the plan saws by night
		# and the sheet stays walkable for its rigs by day: a player crossing at
		# noon meets the refrozen leads, and at night the sled making them. That
		# is the collapse hazard the spec builds on (docs/LANDSCAPES.md §2),
		# stated as an hour. MEASURED, too: a sled that fits every ice tile by
		# day ends a roll early wherever the snowfield lineman's spawn ring
		# crosses the seam -- `Spawner.roll` returns at the FIRST tile anything
		# fits -- and tests/gear_economy/test_line_coil_door.gd went 14 to 12 of
		# 36,000 against a bar of more than 12, at chance 5 and at 3 alike. The
		# lineman is rolled at noon; the sled is never out then.
		"takes": 60.0, "drops": 2, "linger": 40.0, "chance": 3,
		"where": {"countries": ["frost_sea"], "grounds": ["ice"], "hours": [18, 6]},
	},

	# --- Sentinels: the keeper a landscape has (docs/VISION.md §3) ------------
	# A sentinel's body is a roster row like any other machine's, so everything
	# that already reads a machine takes it as one: the senses, the plan's
	# disposition, the fight, the enemy read under `z`. What makes it a sentinel
	# is its design (src/core/sentinel/designs/) and the PHASES that rewrite the
	# live body's own copy of this row as it comes apart (SentinelPhase) — the
	# working side moves, the bite changes, and the read changes with them.
	#
	# `hours: [0, 0]` is no hour of any day, so the coast's own rolls can never
	# put one out (Spawner.moment_fits); a keeper stands where its region's works
	# are and 44_sentinels is the only thing that wakes it. `drops: 0` for the
	# same reason: what a keeper gives comes off its table in src/core/loot.
	&"sentinel.coast": {
		"model": &"sentinel_reaper", "role": &"keeper", "machine": true, "approach": &"charge", "turns": 3,
		"part": &"front", "guarded": true, "sentinel": &"tide_reaper",
		"pace": 4.2, "dash": 8.5, "quick": 300, "radius": 1.35, "height": 2.6, "life": 132,
		"sees": 15, "hears": 11, "racket": 26, "reach": 3, "ready": 3, "forget": 26, "tether": 26, "safe": 14,
		"nerve": 100, "invuln": 520, "through": true, "disposition": &"wary", "overrun": 0.7,
		"bite": {"swing": [820, 170, 800, 900], "reach": 1.9, "width": 2.6, "dmg": 3, "knock": 9.0, "knock_ms": 320},
		"takes": 150.0, "drops": 0, "linger": 90.0, "chance": 0,
		"where": {"hours": [0, 0]},
	},
	&"sentinel.salt": {
		"model": &"sentinel_rake", "role": &"keeper", "machine": true, "approach": &"charge", "turns": 4,
		"part": &"back", "sentinel": &"pan_rake",
		"pace": 4.6, "dash": 9.0, "quick": 310, "radius": 1.3, "height": 3.0, "life": 114,
		"sees": 17, "hears": 8, "racket": 24, "reach": 3, "ready": 3, "forget": 24, "tether": 26, "safe": 14,
		"nerve": 100, "invuln": 500, "through": true, "disposition": &"wary", "overrun": 0.8,
		"bite": {"swing": [620, 150, 700, 820], "reach": 1.8, "width": 1.6, "dmg": 3, "knock": 8.0, "knock_ms": 300},
		"takes": 150.0, "drops": 0, "linger": 90.0, "chance": 0,
		"where": {"hours": [0, 0]},
	},
	# The Frost Sea's keeper (src/core/sentinel/designs/listener.gd). Its senses
	# are the one thing a phase cannot rewrite, so they are set here for the whole
	# fight: it hears further than anything else in the roster and sees less than
	# a worker, which is what makes crouching the answer to it out on open ice.
	&"sentinel.frost": {
		"model": &"sentinel_listener", "role": &"keeper", "machine": true, "approach": &"charge", "turns": 3,
		"part": &"back", "guarded": true, "sentinel": &"listener",
		"pace": 2.4, "dash": 6.0, "quick": 260, "radius": 1.4, "height": 2.4, "life": 124,
		"sees": 9, "hears": 20, "racket": 26, "reach": 3, "ready": 3, "forget": 26, "tether": 34, "safe": 14,
		"nerve": 100, "invuln": 520, "through": true, "disposition": &"wary", "overrun": 0.7,
		"bite": {"swing": [800, 160, 760, 880], "reach": 1.8, "width": 1.8, "dmg": 3, "knock": 8.0, "knock_ms": 300},
		"takes": 150.0, "drops": 0, "linger": 90.0, "chance": 0,
		"where": {"hours": [0, 0]},
	},
}


## The sentinel design this row's body belongs to (src/core/sentinel/), or &"":
## the one field that tells a keeper from an ordinary machine, so 44_sentinels can
## adopt one however it was put out (its own region's station, --spawn, a tour).
static func sentinel_of(kind: StringName) -> StringName:
	return row(kind).get("sentinel", &"")


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


## hostile indifferent observant wary; hostile when the row does not say.
static func disposition(kind: StringName) -> StringName:
	return row(kind).get("disposition", &"hostile")


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
