class_name SoundBank
extends RefCounted
## Every sound the game can play, by key, generated on demand and cached.
##
## A key is "name" or "name:variant" (step_sand:2). SHEET is the mix sheet: for
## each sound its category (which fixes rate, looping, bus, high-pass and the
## window tests hold it to), the level it is HEARD at in dB relative to the
## weather bed at full strength (SoundMix.REF_DBFS), and how many variants
## exist. render() measures what the recipe made and sets the call gain that
## puts it at that level, so a recipe edit never silently re-balances the mix,
## and a recipe that needs an absurd gain fails its test instead.
##
## Recipes live in SoundMachines, SoundBeds, SoundEffects, SoundSignals,
## SoundCreatures and SoundWork; emitted names reach the sheet through
## SoundNames. The score's stems (score_<landscape>_<layer>) are rows of their
## own, answered by ScoreStems, and are stereo. render() is pure and
## thread-safe. At run time one shared bank bakes on WorkerThreadPool or,
## without threads, one short sound per frame, and the score a few milliseconds
## per frame (ScoreRender stops and resumes) in its short form
## (ScoreStems.SHORT_BARS), so a browser without threads hears the score within
## seconds of waking instead of a quarter of a minute.
##
## Two lanes. The world's sounds (a blow, a machine's warning, a footfall) are
## never kept waiting by the score: every score key queues behind every other
## key (urgent only among score keys), a score job never takes the last free
## worker, and without threads a frame serves the queue's one-shot before it
## gives the score its slice.
##
## Cold code and the pool. A GDScript operator on operands the compiler could
## not type (a Dictionary value, an element of a plain Array, a Variant) has no
## evaluator until it first runs: the engine looks one up then and writes it
## into the bytecode behind a mutex, signature word first and the eight-byte
## pointer last, and every later run reads it back with no barrier at all
## (gdscript_vm.cpp, OPCODE_OPERATOR, 4.7.2). Two workers reaching one such
## operator together read a null or half-written pointer and jump through it.
## Three crash reports on this machine (2026-09-18, -19, -23) fault on the pool
## at that one instruction, the last under test_bank's held stems, released in
## lockstep; the "propagate_notification on /root" they print first is the
## crash handler broadcasting NOTIFICATION_CRASH from the faulting worker and
## meeting the node thread guard, not anything in this package touching the
## tree. The bank cannot mend the engine. What it can do is never hand two
## workers identical cold work in lockstep, which is the one shape the fault
## has been seen in: a lane bakes ONE thing at a time until something has
## actually rendered through it on this bank (a cache file read runs none of
## the code and warms nothing), and the score lane waits for an empty world
## lane while it is cold; only then do the caps above apply. What a first
## render leaves cold, a voice or an effect it did not use, two later jobs
## could still meet at the same instant, so this narrows the race rather than
## closing it; the closure is typed operands in everything a worker runs, and
## nothing can hold that from GDScript.

const PEAK := 0.89
## Workers the world's sounds may hold at once.
const MAX_TASKS := 2
## Workers the score may hold at once: this many, and one more only while no
## other sound is baking. Either way one worker is left free for the world's.
const SCORE_TASKS := 1
## Where one sound alone may peak after its call gain and bus (dBFS): under the
## Master limiter's -0.5, so the limiter only ever meets sums. A recipe whose
## crest would carry it over has its transients limited at bake time.
const CEILING_DBFS := -1.5
## Bake-time limiter release per category (s): short for transients, long for
## thunder's roll.
const RELEASE := {&"event": 0.008, &"step": 0.006, &"ui": 0.006, &"scatter": 0.02, &"thunder": 0.25}
## Without worker threads these bake on the main thread (short one-shots, one a
## frame); beds, machines and weather would freeze a frame for a tenth of a
## second or more, so they are only played when the disk cache already holds
## them. On the web there is no disk cache (use_disk_cache), so a browser with
## no SharedArrayBuffer has the score and the one-shots and NO ambient beds at
## all: their recipes are whole-buffer Synth chains and cannot stop and resume
## the way ScoreRender does. Giving that build its shore and its hum means
## either making the Synth primitives resumable or shipping a pre-baked cache
## in the pck (about 15 MB of PCM for every bed and weather loop, so a chosen
## few); the score is sliced today, the beds are not.
const MAIN_THREAD_CATEGORIES: Array[StringName] = [&"event", &"step", &"ui", &"scatter"]
## Categories rendered by a resumable ScoreRender: without threads they bake a
## slice at a time on the main thread (score_budget_usec a frame).
const SCORE_CATEGORIES: Array[StringName] = [&"score_drone", &"score_pad", &"score_pulse", &"score_texture", &"score_grid", &"score_dissonance", &"score_cue"]
## What one frame gives the main-thread baking, one-shot and score slice
## together, and the most it ever gives.
const SCORE_BUDGET_USEC := 3000
const SCORE_BUDGET_MAX_USEC := 8000
## Without threads the score takes at most this share of the frame it is in
## (budget_for, set by 75_music from the frame's own delta). A browser labouring
## at twenty frames a second then builds the score nearly three times as fast as
## one at sixty, and neither ever loses a frame to it: the slice is always a
## fifth of a frame, never a fixed cost that a slow frame pays over and over.
const SCORE_BUDGET_SHARE := 0.2

## rate, loop, bus, hp (4th-order high-pass corner, Hz), window (heard dB),
## stereo (interleaved; default mono).
##
## The score sits under the world: at full density its layers together are
## heard near -7 dB (the weather bed is 0), a quiet stretch under -15. Synths
## keep the laptop rule like everything else: drones imply their octave below
## with harmonics, and nothing carries its weight under 120 Hz.
const CATEGORIES := {
	&"machine": {"rate": 44100, "loop": true, "bus": &"Machines", "hp": 110.0, "window": [-7.0, 1.0]},
	&"bed": {"rate": 22050, "loop": true, "bus": &"Ambience", "hp": 100.0, "window": [-10.0, -2.0]},
	&"weather": {"rate": 22050, "loop": true, "bus": &"Ambience", "hp": 100.0, "window": [-3.0, 2.0]},
	&"scatter": {"rate": 22050, "loop": false, "bus": &"Ambience", "hp": 110.0, "window": [-15.0, -3.0]},
	&"event": {"rate": 44100, "loop": false, "bus": &"SFX", "hp": 90.0, "window": [-4.0, 5.0]},
	&"step": {"rate": 44100, "loop": false, "bus": &"SFX", "hp": 90.0, "window": [-8.0, -5.0]},
	&"thunder": {"rate": 22050, "loop": false, "bus": &"SFX", "hp": 55.0, "window": [6.0, 10.0]},
	&"ui": {"rate": 44100, "loop": false, "bus": &"UI", "hp": 150.0, "window": [-18.0, -6.0]},
	&"score_drone": {"rate": 11025, "loop": true, "stereo": false, "bus": &"Music", "hp": 130.0, "window": [-18.0, -8.0]},
	&"score_pad": {"rate": 16000, "loop": true, "stereo": true, "bus": &"Music", "hp": 110.0, "window": [-16.0, -7.0]},
	&"score_pulse": {"rate": 16000, "loop": true, "stereo": true, "bus": &"Music", "hp": 120.0, "window": [-18.0, -9.0]},
	&"score_texture": {"rate": 16000, "loop": true, "stereo": false, "bus": &"Music", "hp": 150.0, "window": [-22.0, -10.0]},
	&"score_grid": {"rate": 16000, "loop": true, "stereo": true, "bus": &"Music", "hp": 150.0, "window": [-20.0, -9.0]},
	&"score_dissonance": {"rate": 16000, "loop": true, "stereo": false, "bus": &"Music", "hp": 120.0, "window": [-18.0, -9.0]},
	&"score_cue": {"rate": 22050, "loop": false, "stereo": true, "bus": &"Music", "hp": 110.0, "window": [-14.0, -5.0]},
}

## name: [category, heard dB, variants]
const SHEET := {
	# Machines at level 1.0 (standing on it). The warden is the quietest.
	&"machine_watcher": [&"machine", -3.5, 1],
	&"machine_longlegs": [&"machine", -3.0, 1],
	&"machine_harvester": [&"machine", -1.0, 1],
	&"machine_cutter": [&"machine", -2.0, 1],
	&"machine_hauler": [&"machine", -2.0, 1],
	&"machine_warden": [&"machine", -6.5, 1],
	&"machine_sweeper": [&"machine", -3.0, 1],
	&"machine_dredger": [&"machine", -2.5, 1],
	&"machine_lineman": [&"machine", -4.0, 1],
	&"machine_flock": [&"machine", -3.5, 1],
	&"machine_runner": [&"machine", -4.0, 1],
	&"machine_clerk": [&"machine", -6.0, 1],
	# Country beds at weight 1 (deep inside the country). The snowfield is the quietest.
	&"bed_shore": [&"bed", -3.0, 1],
	&"bed_wind": [&"bed", -4.0, 1],
	&"bed_pines": [&"bed", -4.0, 1],
	&"bed_moss": [&"bed", -5.0, 1],
	&"bed_snowfield": [&"bed", -7.5, 1],
	&"bed_bones": [&"bed", -4.5, 1],
	&"bed_burning": [&"bed", -3.5, 1],
	&"bed_river": [&"bed", -5.0, 1],
	# Machinery nobody switched off, carried on still night air from far away.
	&"bed_far_works": [&"bed", -9.0, 1],
	# What the dystopia sounds like where it stands: wreckage in the wind, an
	# installation humming at you, the plan's machines far off, broken gutters.
	&"bed_wreck": [&"bed", -6.5, 1],
	&"bed_hum": [&"bed", -7.0, 1],
	&"bed_far_drone": [&"bed", -9.5, 1],
	&"bed_colossus": [&"bed", -6.0, 1],
	&"bed_gutter": [&"bed", -8.0, 1],
	# Weather beds at full strength. Rain is the reference.
	&"weather_rain": [&"weather", 0.0, 1],
	&"weather_storm": [&"weather", 1.5, 1],
	&"weather_gust": [&"weather", -1.5, 1],
	&"weather_hail": [&"weather", -0.5, 1],
	&"weather_snow": [&"weather", -2.5, 1],
	&"weather_sand": [&"weather", 0.5, 1],
	&"weather_blizzard": [&"weather", 1.5, 1],
	&"weather_ash": [&"weather", -2.5, 1],
	# Rain as the surface it falls on: turf is weather_rain; these share its strength.
	&"weather_rain_metal": [&"weather", -0.5, 1],
	&"weather_rain_leaves": [&"weather", -1.0, 1],
	&"weather_rain_water": [&"weather", -1.0, 1],
	# Scattered over the beds.
	&"pines_snap": [&"scatter", -8.0, 4],
	&"pines_creak": [&"scatter", -9.0, 3],
	&"moss_drip": [&"scatter", -9.5, 4],
	&"moss_bloop": [&"scatter", -10.0, 2],
	&"snow_creak": [&"scatter", -10.0, 3],
	&"bones_tick": [&"scatter", -9.0, 3],
	&"burning_crackle": [&"scatter", -10.0, 4],
	&"burning_thud": [&"scatter", -6.0, 2],
	&"shore_gull": [&"scatter", -7.0, 3],
	&"fog_horn": [&"scatter", -5.0, 1],
	&"heat_tick": [&"scatter", -11.0, 3],
	&"bird_song": [&"scatter", -11.0, 6],
	&"pines_drip": [&"scatter", -10.0, 4],
	&"moss_wisp": [&"scatter", -12.5, 3],
	&"wire_sing": [&"scatter", -11.0, 3],
	&"wreck_knock": [&"scatter", -8.0, 4],
	&"chain_clink": [&"scatter", -11.0, 3],
	&"relay_click": [&"scatter", -11.5, 4],
	&"arc_snap": [&"scatter", -9.5, 3],
	&"gutter_drip": [&"scatter", -10.0, 4],
	&"thunder_roll": [&"scatter", -5.0, 2],
	# Footfalls, one family per ground. **THE WHOLE FAMILY CAME DOWN 4.0 dB**
	# (owner, 2026-09-19: "way too loud by default"). They were at -3.0, which in
	# this sheet's own units is three decibels under a RAINSTORM (weather_rain is
	# 0.0) — for the one sound the game makes twice a second, all game, at zero
	# distance, because the player's own feet are never attenuated. Nothing else
	# is both that loud and that frequent: a machine's alert sits at 0.0 and
	# happens when a machine alerts.
	#
	# The category window came down with them, and that is the real correction:
	# `step` had been given `event`'s window verbatim, so the mix was declaring a
	# footfall to be an event-loud thing. It is not. It is closer to the ambient
	# layer, and it has its own window now.
	#
	# **WHY 4.0 AND NOT MORE, WHICH IS A REAL LIMIT AND NOT A PREFERENCE.**
	# `test_interface_is_quietest_and_thunder_is_loudest` holds the interface
	# under the quietest world sound, and the quietest UI row is -8.0. Take the
	# steps past about -7.5 and the slate starts shouting over your own feet,
	# which is a worse mix than the one being fixed. Going further means moving
	# the interface too, and nobody asked for that.
	#
	# The ground-to-ground spread is untouched: shingle still crunches half a
	# decibel over grass, and water is still the loudest thing to walk in.
	&"step_sand": [&"step", -7.0, 4],
	&"step_grass": [&"step", -7.0, 4],
	&"step_heath": [&"step", -7.0, 4],
	&"step_mud": [&"step", -7.0, 4],
	&"step_needles": [&"step", -7.5, 4],
	&"step_snow": [&"step", -7.0, 4],
	&"step_ice": [&"step", -7.0, 4],
	&"step_stone": [&"step", -7.0, 4],
	&"step_gravel": [&"step", -6.5, 4],
	&"step_shingle": [&"step", -6.5, 4],
	&"step_ash": [&"step", -7.5, 4],
	&"step_clinker": [&"step", -7.0, 4],
	&"step_dirt": [&"step", -7.5, 4],
	&"step_wood": [&"step", -7.0, 4],
	&"step_water": [&"step", -6.0, 4],
	# The fight.
	&"swing": [&"event", -1.0, 3],
	&"whiff": [&"event", -2.0, 2],
	&"hit_flesh": [&"event", 3.0, 3],
	&"hit_plate": [&"event", 2.0, 3],
	&"dodge": [&"event", -2.0, 2],
	&"grip": [&"event", 2.0, 1],
	&"pull": [&"event", 0.0, 2],
	&"machine_down": [&"event", 2.0, 1],
	&"alert": [&"event", 0.0, 1],
	&"downed": [&"event", 2.0, 1],
	# What a machine does to you (SoundSignals): each alert is its own bed made urgent.
	&"alert_watcher": [&"event", 0.0, 1],
	&"alert_longlegs": [&"event", 0.5, 1],
	&"alert_harvester": [&"event", 1.0, 1],
	&"alert_cutter": [&"event", 1.0, 1],
	&"alert_hauler": [&"event", 0.5, 1],
	&"alert_warden": [&"event", -2.5, 1],
	&"alert_sweeper": [&"event", -1.0, 1],
	&"alert_dredger": [&"event", 0.5, 1],
	&"alert_lineman": [&"event", 0.0, 1],
	&"alert_flock": [&"event", -0.5, 1],
	&"alert_runner": [&"event", -1.0, 1],
	&"alert_clerk": [&"event", -1.5, 1],
	&"watcher_call": [&"event", 1.0, 1],
	&"second_act": [&"event", 3.0, 1],
	&"loose": [&"event", 0.0, 1],
	&"snatch_flock": [&"event", 1.0, 1],
	&"snatch_warden": [&"event", 2.0, 1],
	&"snatch_clerk": [&"event", 0.0, 1],
	# The tell before a strike: the fight is read by ear (SoundSignals).
	&"windup": [&"event", 0.0, 1],
	&"windup_watcher": [&"event", 0.0, 1],
	&"windup_longlegs": [&"event", 0.5, 1],
	&"windup_harvester": [&"event", 1.0, 1],
	&"windup_cutter": [&"event", 1.0, 1],
	&"windup_hauler": [&"event", 0.5, 1],
	&"windup_warden": [&"event", -2.0, 1],
	&"windup_sweeper": [&"event", -1.0, 1],
	&"windup_dredger": [&"event", 0.5, 1],
	&"windup_lineman": [&"event", 0.0, 1],
	&"windup_flock": [&"event", -0.5, 1],
	&"windup_runner": [&"event", -0.5, 1],
	&"windup_clerk": [&"event", -1.5, 1],
	# The living (SoundCreatures).
	&"dog_bark": [&"event", 1.0, 3],
	&"dog_growl": [&"event", 0.5, 2],
	&"bull_snort": [&"event", 2.0, 2],
	&"bull_paw": [&"event", 1.0, 2],
	&"gull_cry": [&"event", -1.0, 3],
	&"snatch_gull": [&"event", 0.0, 2],
	&"beast_down": [&"event", 1.0, 1],
	# Taking and making.
	&"break": [&"event", 1.0, 3],
	&"dig": [&"event", -1.0, 3],
	&"fell": [&"event", 1.0, 3],
	&"cut": [&"event", -2.0, 3],
	&"gather": [&"event", -3.0, 3],
	&"craft": [&"event", -1.0, 1],
	&"eat": [&"event", -3.0, 1],
	&"fire": [&"event", -1.0, 1],
	&"splash": [&"event", 1.0, 1],
	&"tree_fall": [&"event", 3.0, 1],
	&"pickup": [&"event", -3.0, 1],
	&"lamp_on": [&"event", -3.0, 1],
	&"lamp_off": [&"event", -3.5, 1],
	&"door": [&"event", -1.0, 1],
	# Hands at work (SoundWork).
	&"refuse": [&"event", -2.5, 1],
	&"scrape": [&"event", -2.0, 2],
	&"tap": [&"event", -2.0, 2],
	&"turn": [&"event", -1.0, 2],
	&"hone": [&"event", -2.0, 1],
	&"reedge": [&"event", 0.0, 1],
	&"build_fire": [&"event", -1.0, 1],
	&"build_bench": [&"event", 0.0, 1],
	&"build_kiln": [&"event", 0.0, 1],
	&"sleep": [&"event", -4.0, 1],
	&"tool_snap": [&"event", 1.5, 2],
	# Thunder only sits above everything.
	&"thunder": [&"thunder", 8.0, 2],
	&"thunder_far": [&"thunder", 6.5, 2],
	# A colossus landing: through the ground, then through the air. Thunder's
	# category, because it is the one sound bigger than thunder.
	&"colossus_step": [&"thunder", 7.0, 2],
	&"colossus_boom": [&"thunder", 6.0, 2],
	# The interface is the quietest thing in the mix.
	&"ui_move": [&"ui", -12.0, 1],
	&"ui_accept": [&"ui", -9.0, 1],
	&"ui_back": [&"ui", -9.0, 1],
	&"ui_refuse": [&"ui", -9.0, 1],
	&"book_open": [&"ui", -10.0, 1],
	&"book_close": [&"ui", -10.0, 1],
	# The slate (SoundSlate): synthetic, a little broken.
	&"ui_slate_click": [&"ui", -13.0, 1],
	&"ui_slate_confirm": [&"ui", -10.0, 1],
	&"ui_slate_back": [&"ui", -10.5, 1],
	&"ui_slate_deny": [&"ui", -10.0, 1],
	&"ui_slate_wake": [&"ui", -8.0, 1],
	&"ui_slate_sleep": [&"ui", -11.0, 1],
	&"ui_slate_switch": [&"ui", -12.0, 1],
	&"ui_slate_whine": [&"ui", -9.0, 1],
	&"ui_slate_ping": [&"ui", -8.0, 1],
}


class Baked:
	extends RefCounted
	var key: StringName
	var name: StringName
	var variant := 0
	var category: StringName
	var rate := 44100
	var loop := false
	## Interleaved left and right (score stems); samples then hold two per frame.
	var stereo := false
	var bus: StringName
	## Level it is heard at (sheet), and the call gain that achieves it.
	var heard := 0.0
	var gain_db := 0.0
	var samples: PackedFloat32Array
	var pcm: PackedByteArray
	var stream: AudioStreamWAV
	var ms := 0
	## How far its transients were limited at bake to fit under CEILING_DBFS.
	var limited_db := 0.0
	## Loaded from the disk cache rather than generated this run.
	var from_disk := false


class Job:
	extends RefCounted
	var key: StringName
	var result: Baked
	var task := -1
	## A cache file to read instead of rendering, and to write after (or "").
	var cache_path := ""
	## Score keys: what makes the stem's ScoreRender (the bank's score_job).
	var score := Callable()
	## Bars to cut a score loop to: 0 for every bar of it, the short form without
	## threads (ScoreStems.SHORT_BARS).
	var bars := 0
	## Whether the recipe or the stem actually ran (a cache hit ran neither): what
	## the bank's cold-start rule counts (the header).
	var rendered := false

	func run() -> void:
		if cache_path != "":
			result = SoundBank.load_cached(key, cache_path)
			if result != null:
				return
		rendered = true
		if score.is_valid():
			var stem: ScoreRender = score.call(key, bars)
			stem.run()
			result = SoundBank.from_score(stem)
		else:
			result = SoundBank.render(key)
		if result.pcm.is_empty():
			result.pcm = Synth.to_pcm16(result.samples)
		if cache_path != "":
			SoundBank.save_cached(result, cache_path)


static var _shared: SoundBank

var threaded := true
## Keep float samples after baking (tools and tests); the game drops them.
var keep_samples := false
## False in screenshot runs: nothing bakes, so nothing plays.
var enabled := true
## Baked PCM kept between runs, under a folder per recipe version, so a second
## start plays at once. Empty = no disk (tests and tools never touch it).
var cache_dir := ""
var _cache_version_dir := ""
var _done: Dictionary = {}
var _jobs: Dictionary = {}
## The world's sounds, then the score's: a score key never waits in front of another.
var _queue: Array[StringName] = []
var _score_queue: Array[StringName] = []
var _pumped_frame := -1
var _on_disk: Dictionary = {}
## Whether a world sound, and a score stem, has rendered through this bank yet.
## Until one has, its lane puts one job on the pool at a time (the header).
var _warm_world := false
var _warm_score := false
## Makes the job for a score key: (key, bars) -> ScoreRender, where bars is 0
## for the whole loop and the short form without threads (score_bars). A test
## hands in a small one.
var score_job: Callable = ScoreStems.job
## Without threads: the score stem being built a slice a frame, its cache path,
## and once built, the sound it made (written to disk and turned into a stream
## on the frames after, never on the frame that finished it).
var _slow: ScoreRender
var _slow_path := ""
var _slow_baked: Baked
## What this frame's main-thread baking may spend (budget_for).
var score_budget_usec := SCORE_BUDGET_USEC
## Microseconds the last pump() spent on the main thread (the no-thread budget is held to it).
var last_pump_usec := 0
## Units of score work (blocks, slices) the last pump() advanced. Load lowers
## it, never raises it, so a test can hold the slicing to it without a clock.
var last_pump_units := 0


static func shared() -> SoundBank:
	if _shared == null:
		_shared = SoundBank.new()
	return _shared


func _init() -> void:
	threaded = not OS.has_feature("web") or OS.has_feature("threads")


# ------------------------------------------------------------------ catalog

static func base_name(key: StringName) -> StringName:
	var s := String(key)
	var c := s.find(":")
	return StringName(s.substr(0, c)) if c >= 0 else key


static func variant_of(key: StringName) -> int:
	var s := String(key)
	var c := s.find(":")
	return s.substr(c + 1).to_int() if c >= 0 else 0


## [category, heard dB, variants] for a name: the sheet's, or a score stem's; [] when unknown.
static func row(name: StringName) -> Array:
	if SHEET.has(name):
		return SHEET[name]
	return ScoreStems.sheet_row(name)


static func has_sound(key: StringName) -> bool:
	return not row(base_name(key)).is_empty()


static func variants(name: StringName) -> int:
	var r := row(name)
	return int(r[2]) if not r.is_empty() else 0


static func category_of(name: StringName) -> StringName:
	var r := row(name)
	return r[0] if not r.is_empty() else &""


static func is_score(name: StringName) -> bool:
	return category_of(name) in SCORE_CATEGORIES


## The key for a name and a variant number (wrapped into range).
static func key_for(name: StringName, variant: int) -> StringName:
	var v := variants(name)
	if v <= 1:
		return name
	return StringName("%s:%d" % [name, posmod(variant, v)])


## Every name: the sheet's, then the score's for the landscapes it has entries for.
static func all_names() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in SHEET:
		out.append(k)
	out.append_array(ScoreStems.names())
	return out


static func names_in(category: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for k in all_names():
		if category_of(k) == category:
			out.append(k)
	return out


## Every key, variants expanded.
static func all_keys() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in all_names():
		for i in maxi(1, variants(k)):
			out.append(key_for(k, i))
	return out


## Generates one sound: recipe, the category's high-pass (periodic for loops),
## peak normalisation, then the call gain for its sheet level. Pure: the same
## key gives the same samples on any thread.
static func render(key: StringName) -> Baked:
	if is_score(base_name(key)):
		var job := ScoreStems.job(key)
		job.run()
		return from_score(job)
	var t0 := Time.get_ticks_msec()
	var b := _header(key)
	var cat: Dictionary = CATEGORIES[b.category]
	var raw: PackedFloat32Array
	match b.category:
		&"machine":
			raw = SoundMachines.make(StringName(String(b.name).trim_prefix("machine_")))
		&"bed", &"weather", &"scatter":
			raw = SoundBeds.make(b.name, b.variant, b.rate)
		_:
			if SoundSignals.handles(b.name):
				raw = SoundSignals.make(b.name, b.variant, b.rate)
			elif SoundCreatures.handles(b.name):
				raw = SoundCreatures.make(b.name, b.variant, b.rate)
			elif SoundWork.handles(b.name):
				raw = SoundWork.make(b.name, b.variant, b.rate)
			elif SoundSlate.handles(b.name):
				raw = SoundSlate.make(b.name, b.variant, b.rate)
			else:
				raw = SoundEffects.make(b.name, b.variant, b.rate)
	Synth.highpass4(raw, b.rate, cat["hp"], b.loop)
	if not b.loop:
		raw = Synth.trim_tail(raw, b.rate)
		Synth.fade(raw, b.rate, 0.0008, 0.006)
	Synth.normalize(raw, PEAK)
	b.gain_db = _gain_for(raw, b)
	# Keep one sound under the Master limiter by its own crest: limit the
	# transients to the ceiling its gain allows, then take the gain again (the
	# loudest half-second hardly moves, so two or three rounds settle it).
	# A footfall's click is shaved and let go at once, so its body is untouched;
	# held sounds let go slower so the limiting never pumps.
	var release: float = RELEASE.get(b.category, 0.06)
	for _pass in 8:
		var allowed := db_to_linear(CEILING_DBFS - b.gain_db - SoundMix.bus_db(b.bus))
		if Synth.peak(raw) <= allowed:
			break
		Synth.limit(raw, b.rate, allowed * 0.97, minf(0.0015, release * 0.25), release, b.loop)
		b.gain_db = _gain_for(raw, b)
		b.limited_db = 20.0 * log(PEAK / maxf(1e-9, Synth.peak(raw))) / log(10.0)
	b.samples = raw
	b.ms = Time.get_ticks_msec() - t0
	return b


## A Baked with its sheet row, category, rate, loop, stereo and bus filled in.
static func _header(key: StringName) -> Baked:
	var b := Baked.new()
	b.key = key
	b.name = base_name(key)
	b.variant = variant_of(key)
	var r := row(b.name)
	if r.is_empty():
		r = [&"event", 0.0, 1]
	b.category = r[0]
	b.heard = r[1]
	var cat: Dictionary = CATEGORIES[b.category]
	b.rate = cat["rate"]
	b.loop = cat["loop"]
	b.stereo = bool(cat.get("stereo", false))
	b.bus = cat["bus"]
	return b


## The Baked of a finished score stem. Its measure was taken as it finished; the
## call gain puts it at its sheet level, and if its normalised peak would then
## cross the ceiling the whole stem is turned down (a score stem is never limited:
## its attacks are soft by design, and a test holds that under a decibel).
static func from_score(job: ScoreRender) -> Baked:
	var b := _header(job.key)
	b.samples = job.samples
	b.pcm = job.pcm
	var rms_db := 20.0 * log(maxf(1e-9, job.loudest)) / log(10.0)
	b.gain_db = b.heard + SoundMix.REF_DBFS - rms_db - SoundMix.bus_db(b.bus)
	var allowed_db := CEILING_DBFS - b.gain_db - SoundMix.bus_db(b.bus)
	var peak_db := 20.0 * log(PEAK) / log(10.0)
	if peak_db > allowed_db:
		b.limited_db = peak_db - allowed_db
		b.gain_db -= b.limited_db
	b.ms = roundi(job.busy_usec / 1000.0)
	return b


## The call gain (dB) that puts these samples at the sheet level after the bus.
static func _gain_for(raw: PackedFloat32Array, b: Baked) -> float:
	var rms_db := 20.0 * log(maxf(1e-9, Synth.loudest_rms(raw, b.rate, 0.5))) / log(10.0)
	return b.heard + SoundMix.REF_DBFS - rms_db - SoundMix.bus_db(b.bus)


# ------------------------------------------------------------------ disk

const CACHE_MAGIC := "USND"
const CACHE_FORMAT := 2
## Version folders kept; older ones (other branches, older recipes) are removed.
const CACHE_KEEP := 3


## A fingerprint of every recipe, the sheet, the game's version and the
## engine's: any edit to src/audio or the mix numbers gives a new cache folder,
## so a stale sound is never played. "" when the recipes cannot be read (then
## there is no disk cache at all, rather than one that could be stale).
static func recipe_version() -> String:
	return version_from(recipe_digests())


static func version_from(digests: PackedStringArray) -> String:
	if digests.is_empty():
		return ""
	var parts: PackedStringArray = [str(CACHE_FORMAT), str(SHEET), str(CATEGORIES), str(ScoreStems.LAYERS), str(SoundMix.REF_DBFS), str(SoundMix.BUSES), str(CEILING_DBFS),
		str(ProjectSettings.get_setting("application/config/version", "")), str(Engine.get_version_info().get("hash", "")), str(Engine.get_version_info().get("string", ""))]
	parts.append_array(digests)
	return "\n".join(parts).md5_text().substr(0, 16)


## One md5 per recipe script, whatever form the build keeps it in: the .gd
## source in the editor and in text exports; in a tokenised export the
## .gd.remap names the compiled file, and that file is hashed instead.
static func recipe_digests(folder: String = "res://src/audio") -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return out
	var files := dir.get_files()
	files.sort()
	for f in files:
		var path := folder.path_join(f)
		if f.ends_with(".gd") or f.ends_with(".gdc"):
			out.append(FileAccess.get_md5(path))
		elif f.ends_with(".gd.remap"):
			var target := remap_target(FileAccess.get_file_as_string(path))
			if target != "" and FileAccess.file_exists(target):
				out.append(FileAccess.get_md5(target))
	return out


## The path a Godot .remap file points at, or "".
static func remap_target(text: String) -> String:
	for line in text.split("\n"):
		var l := line.strip_edges()
		if l.begins_with("path") and l.contains("="):
			return l.substr(l.find("=") + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
	return ""


## Turn the disk cache on under `root` (the running game does, once).
func use_disk_cache(root: String) -> void:
	var version := recipe_version()
	# On the web user:// is IndexedDB, synced whole after every file closed: baked
	# PCM written from worker threads overlapped those syncs and failed them.
	if version == "" or OS.has_feature("web"):
		cache_dir = ""
		_cache_version_dir = ""
		return
	cache_dir = root
	_on_disk.clear()
	_cache_version_dir = root.path_join(version)
	DirAccess.make_dir_recursive_absolute(_cache_version_dir)
	_prune_cache(root)


## Where a baked sound is kept. A stem cut to `bars` is a different sound from
## the whole one, so it is a file of its own: a build with threads and one
## without never read each other's.
func _cache_path(key: StringName, bars: int = 0) -> String:
	if _cache_version_dir == "":
		return ""
	var stem := String(key).replace(":", "_")
	return _cache_version_dir.path_join(stem + (".usnd" if bars <= 0 else "_b%d.usnd" % bars))


func _prune_cache(root: String) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	var folders: Array = []
	for d in dir.get_directories():
		var marker := root.path_join(d)
		folders.append([FileAccess.get_modified_time(marker) if FileAccess.file_exists(marker) else _folder_time(marker), d])
	folders.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	for i in range(CACHE_KEEP, folders.size()):
		var gone := root.path_join(String(folders[i][1]))
		if gone == _cache_version_dir:
			continue
		var sub := DirAccess.open(gone)
		if sub != null:
			for f in sub.get_files():
				sub.remove(f)
		DirAccess.remove_absolute(gone)


static func _folder_time(path: String) -> int:
	var newest := 0
	var dir := DirAccess.open(path)
	if dir != null:
		for f in dir.get_files():
			newest = maxi(newest, FileAccess.get_modified_time(path.path_join(f)))
	return newest


## Writes a baked sound (its PCM, rate, loop and gain) atomically: to a
## temporary name, then renamed, so two games starting at once never read half
## a file.
static func save_cached(b: Baked, path: String) -> void:
	var tmp := "%s.%d.tmp" % [path, OS.get_thread_caller_id()]
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(CACHE_MAGIC.to_ascii_buffer())
	f.store_32(CACHE_FORMAT)
	f.store_32(b.rate)
	f.store_8((1 if b.loop else 0) | (2 if b.stereo else 0))
	f.store_float(b.gain_db)
	f.store_32(b.pcm.size())
	f.store_buffer(b.pcm)
	f.close()
	DirAccess.rename_absolute(tmp, path)


## The baked sound for `key` from its cache file, or null when missing or not
## what this build would make.
static func load_cached(key: StringName, path: String) -> Baked:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 17:
		return null
	if f.get_buffer(4).get_string_from_ascii() != CACHE_MAGIC or f.get_32() != CACHE_FORMAT:
		return null
	var b := _header(key)
	var cat: Dictionary = CATEGORIES[b.category]
	var rate := f.get_32()
	var flags := f.get_8()
	b.gain_db = f.get_float()
	var size := f.get_32()
	b.pcm = f.get_buffer(size)
	if b.pcm.size() != size or rate != int(cat["rate"]) or (flags & 1 == 1) != b.loop or (flags & 2 == 2) != b.stereo:
		return null
	b.from_disk = true
	return b


# ----------------------------------------------------------------- baking

## Queue a key for baking (no-op if baked or queued). urgent jumps its lane:
## any sound's the whole queue, a score stem's only the other score stems.
func request(key: StringName, urgent: bool = false) -> void:
	if not enabled or _done.has(key) or _jobs.has(key) or not has_sound(key):
		return
	if (_slow != null and _slow.key == key) or (_slow_baked != null and _slow_baked.key == key):
		return
	if not threaded and not bakes_here(key):
		return
	var lane := _score_queue if is_score(base_name(key)) else _queue
	var at := lane.find(key)
	if at >= 0:
		if urgent and at > 0:
			lane.remove_at(at)
			lane.push_front(key)
		return
	if urgent:
		lane.push_front(key)
	else:
		lane.append(key)


## The baked sound if ready, else null (and it is requested).
func get_baked(key: StringName, urgent: bool = false) -> Baked:
	var b: Baked = _done.get(key)
	if b == null:
		request(key, urgent)
	return b


## Whether this bank may bake `key` at all: with threads, anything; without,
## a short one-shot, a score stem (built a slice a frame), or anything its disk
## cache already holds (a file read).
func bakes_here(key: StringName) -> bool:
	var cat := category_of(base_name(key))
	if threaded or cat in MAIN_THREAD_CATEGORIES or cat in SCORE_CATEGORIES:
		return true
	if not _on_disk.has(key):
		var path := _cache_path(key, score_bars(key))
		_on_disk[key] = path != "" and FileAccess.file_exists(path)
	return _on_disk[key]


func is_ready(key: StringName) -> bool:
	return _done.has(key)


func pending() -> int:
	return _jobs.size() + _queue.size() + _score_queue.size() + (1 if _slow != null or _slow_baked != null else 0)


## Keys waiting, the world's first then the score's (tests and tools).
func queued() -> Array[StringName]:
	var out: Array[StringName] = []
	out.append_array(_queue)
	out.append_array(_score_queue)
	return out


## Drop a baked sound from memory (the disk cache keeps it): a landscape's score
## that has not been heard for minutes. Players holding its stream keep it alive
## until they let go.
func forget(key: StringName) -> void:
	_done.erase(key)


## Bake synchronously (tests, tools, and the no-thread fallback).
func bake_now(key: StringName) -> Baked:
	if _done.has(key):
		return _done[key]
	var job := _job(key)
	job.run()
	_queue.erase(key)
	_score_queue.erase(key)
	_finish(job)
	return _done[key]


func _job(key: StringName) -> Job:
	var job := Job.new()
	job.key = key
	if is_score(base_name(key)):
		job.score = score_job
		job.bars = score_bars(key)
	job.cache_path = _cache_path(key, job.bars)
	return job


## Bars this bank cuts a score loop to: every one of them with threads, the
## short form without (ScoreStems.SHORT_BARS), where a stem is built a few
## milliseconds a frame and a whole drone would arrive a quarter of a minute
## after the player did.
func score_bars(key: StringName) -> int:
	return 0 if threaded else ScoreStems.short_bars(key)


## Reap finished jobs and start new ones. Call once per frame; extra calls in
## the same frame do nothing.
func pump() -> void:
	var f := Engine.get_process_frames()
	if f == _pumped_frame:
		return
	_pumped_frame = f
	if not enabled:
		return
	for key: StringName in _jobs.keys():
		var job: Job = _jobs[key]
		if WorkerThreadPool.is_task_completed(job.task):
			WorkerThreadPool.wait_for_task_completion(job.task)
			_jobs.erase(key)
			_finish(job)
	if not threaded:
		var t0 := Time.get_ticks_usec()
		last_pump_units = 0
		_pump_main_thread()
		last_pump_usec = Time.get_ticks_usec() - t0
		return
	var score_jobs := 0
	for job: Job in _jobs.values():
		score_jobs += 1 if job.score.is_valid() else 0
	# A lane nothing has rendered through yet is one job wide (the header): its
	# code is cold, and two workers through cold code in lockstep is where the
	# engine's operator race faults.
	var world_cap := MAX_TASKS if _warm_world else 1
	while _jobs.size() - score_jobs < world_cap and not _queue.is_empty():
		_start(_queue.pop_front())
	# A score job leaves a worker free: a machine's call asked for mid-build finds one.
	var world_jobs := _jobs.size() - score_jobs
	var score_cap := SCORE_TASKS + (1 if world_jobs == 0 else 0)
	if not _warm_score:
		# A cold stem also shares the job's own entry and the synth with whatever
		# world sound is baking, so it waits for that lane to empty: the score
		# waits, the world never does.
		score_cap = 1 if world_jobs == 0 else 0
	while _queue.is_empty() and not _score_queue.is_empty() and score_jobs < score_cap and _jobs.size() + 1 < MAX_TASKS + SCORE_TASKS:
		_start(_score_queue.pop_front())
		score_jobs += 1


func _start(key: StringName) -> void:
	var job := _job(key)
	job.task = WorkerThreadPool.add_task(job.run, false, "bake %s" % job.key)
	_jobs[job.key] = job


## What the main-thread baking may spend in a frame of `delta` seconds: a share
## of it (SCORE_BUDGET_SHARE), never under SCORE_BUDGET_USEC and never over
## SCORE_BUDGET_MAX_USEC, so a hitch does not hand the score a whole frame.
func budget_for(delta: float) -> int:
	return clampi(roundi(delta * 1e6 * SCORE_BUDGET_SHARE), SCORE_BUDGET_USEC, SCORE_BUDGET_MAX_USEC)


## Without threads, inside score_budget_usec a frame: first one thing from the
## world's queue (a short one-shot or a cache file), so a blow or an alert asked
## for while the score builds is ready on the next frame; then, with what is
## left, a slice of the score stem being built. A finished stem is written to
## disk on the next frame and becomes a stream on the one after. A new stem is
## never started in a frame that already baked something.
func _pump_main_thread() -> void:
	var t0 := Time.get_ticks_usec()
	var served := false
	if not _queue.is_empty():
		bake_now(_queue[0])
		served = true
	elif not _score_queue.is_empty():
		# A score stem already on disk is only a file read.
		for key in _score_queue:
			if _on_disk_now(key):
				bake_now(key)
				served = true
				break
	if _slow_baked != null:
		if served:
			return
		if _slow_path != "":
			save_cached(_slow_baked, _slow_path)
			_slow_path = ""
			return
		var job := Job.new()
		job.key = _slow_baked.key
		job.result = _slow_baked
		_slow_baked = null
		_finish(job)
		return
	if _slow != null:
		var left := score_budget_usec - (Time.get_ticks_usec() - t0)
		if left <= 0:
			return
		var done := _slow.step(left)
		last_pump_units = _slow.last_units
		if done:
			_slow_baked = from_score(_slow)
			_slow = null
		return
	if served or _score_queue.is_empty():
		return
	var key: StringName = _score_queue.pop_front()
	var bars := score_bars(key)
	_slow = score_job.call(key, bars)
	_slow_path = _cache_path(key, bars)


func _on_disk_now(key: StringName) -> bool:
	var path := _cache_path(key, score_bars(key))
	if path == "":
		return false
	if not _on_disk.has(key):
		_on_disk[key] = FileAccess.file_exists(path)
	return _on_disk[key]


## Block until everything queued is baked (tools and tests).
func flush() -> void:
	while pending() > 0:
		for key: StringName in _jobs.keys():
			var job: Job = _jobs[key]
			WorkerThreadPool.wait_for_task_completion(job.task)
			_jobs.erase(key)
			_finish(job)
		_pumped_frame = -1
		pump()


## Take a sound rendered elsewhere (tests hand over what they already made).
func adopt(b: Baked) -> void:
	var job := Job.new()
	job.key = b.key
	job.result = b
	b.pcm = Synth.to_pcm16(b.samples)
	_queue.erase(b.key)
	_score_queue.erase(b.key)
	_finish(job)


## Forget what is queued; what is already baking finishes and is kept.
func drop_queue() -> void:
	_queue.clear()
	_score_queue.clear()


## Drop everything queued and wait out what is already running (quitting).
func cancel() -> void:
	_queue.clear()
	_score_queue.clear()
	_slow = null
	_slow_baked = null
	for key: StringName in _jobs.keys():
		var job: Job = _jobs[key]
		WorkerThreadPool.wait_for_task_completion(job.task)
		_finish(job)
	_jobs.clear()


func _finish(job: Job) -> void:
	var b := job.result
	b.stream = Synth.wav_from_pcm(b.pcm, b.rate, b.loop, b.stereo)
	if not keep_samples:
		b.samples = PackedFloat32Array()
	b.pcm = PackedByteArray()
	_done[job.key] = b
	if job.rendered:
		if job.score.is_valid():
			_warm_score = true
		else:
			_warm_world = true
