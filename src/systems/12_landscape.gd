extends GameSystem
## The landscape's live inputs: --stats, which prints what a frame cost just
## before a shot is taken. Wind for everything that sways (wind_strength) is the
## sky's: SkyLight is its one writer, so a storm's sway is never overwritten.


var _frames := 0
## Every frame's own milliseconds, for the distribution `--stats` reports. An
## AVERAGE cannot see a hitch and a hitch is what a player calls jumpy: 72 fps
## with one frame in twenty at 40 ms reads as stutter and averages as fine.
var _ms := PackedFloat32Array()

## Every system whose own script defines `_physics_process`, driven from here
## under `--stats` so each one can be timed separately. See `_driven_line`.
var _driven: Array[GameSystem] = []
var _driven_worst := PackedFloat32Array()

## The same for `_process`, over every node under the game rather than only the
## systems -- the view, the camera, the player and the HUD all have one, and the
## remaining spikes are on this side. See `_proc_line`.
var _pdriven: Array[Node] = []
var _pdriven_worst := PackedFloat32Array()

## THE WORST TICK CANNOT ANSWER A MEDIAN, AND p50 IS THE ROW STILL FAILING.
##
## The worst-per-node lines below were built for the hitch work, where the
## question was "which system put 224 ms into one frame", and for that the mean
## is exactly the wrong statistic (that file's own comment says why). But
## docs/PERF.md now fails on p50 — the TYPICAL frame — and a one-off 15 ms build
## cannot move a median however ugly it looks in a worst column. A spike and a
## floor are different questions and they need different numbers, so these keep
## the running total as well and `_mean_line` reports the floor.
##
## The sum of the means is the reading that decides where to look at all: if
## every driven node together costs 3 ms in a typical frame while p50 is 11.7,
## the median is NOT in this half of the engine and no amount of work here will
## move it.
var _pdriven_total := PackedFloat32Array()
var _driven_total := PackedFloat32Array()
var _driven_ticks := 0
var _pdriven_ticks := 0


func setup(g: Game) -> void:
	super.setup(g)


## WHICH SYSTEM IS THE SPIKE. Nothing in Godot answers that: `TIME_PHYSICS_PROCESS`
## is the whole pass, so a 224 ms tick names no culprit and the search becomes
## reading twenty-five files. So the pass is driven from here instead and each
## system timed on its own -- which found `24_holds` at **224.6 ms against
## 30_mobs' 0.7**, a 320x gap between first and second place (#126, docs/PERF.md).
##
## **ASK THE SCRIPT, NOT THE NODE.** `has_method("_physics_process")` answers true
## for a virtual every Node declares, so it would hand back all twenty-five and
## this would drive systems that never defined one. `get_script_method_list()`
## lists only what the script itself declares.
##
## Order is preserved exactly: `game.systems` IS tree order, and every system
## that defines `_physics_process` is numbered above 12, so none runs earlier
## than it did. Only under `--stats`, so a played game is untouched.
func started() -> void:
	if game == null or not game.options.stats:
		return
	for s: GameSystem in game.systems:
		if s == self:
			continue
		var src: Script = s.get_script()
		if src == null:
			continue
		for m: Dictionary in src.get_script_method_list():
			if String(m.get("name", "")) == "_physics_process":
				s.set_physics_process(false)
				_driven.append(s)
				break
	_driven_worst.resize(_driven.size())
	_driven_total.resize(_driven.size())
	_gather_process(game)
	_pdriven_worst.resize(_pdriven.size())
	_pdriven_total.resize(_pdriven.size())


## Depth-first, parent before children, which IS the order Godot runs `_process`
## in -- so driving the whole pass from one place preserves it exactly. Nothing
## else is left with a `_process`, so there is nothing to interleave wrongly with.
##
## **WHAT THIS DOES NOT COVER, said out loud rather than implied**: a node that
## joins the tree after `started()` -- a mob, a raid party -- keeps its own
## `_process` and is neither driven nor timed. That is exactly the population
## that could be the cost, so `_proc_line` prints how many nodes it is actually
## driving. An instrument that quietly covers most of the candidates reads the
## same as one that covers all of them.
func _gather_process(n: Node) -> void:
	if n != self:
		var src: Script = n.get_script()
		if src != null:
			for m: Dictionary in src.get_script_method_list():
				if String(m.get("name", "")) == "_process":
					n.set_process(false)
					_pdriven.append(n)
					break
	for c: Node in n.get_children():
		_gather_process(c)


func _physics_process(delta: float) -> void:
	_driven_ticks += 1
	for i in _driven.size():
		var began := Time.get_ticks_usec()
		_driven[i].call(&"_physics_process", delta)
		var took := float(Time.get_ticks_usec() - began) / 1000.0
		_driven_total[i] += took
		# Steady play only, for the reason spelled out over the `_process` twin:
		# a worst that includes the world's first ticks answers "what did loading
		# cost" under a heading that says "what does a bad frame cost".
		if _driven_ticks > WARM_MOST and took > _driven_worst[i]:
			_driven_worst[i] = took


## The WORST tick each system took, dearest first. The worst and not the mean,
## for the reason the whole of docs/PERF.md exists: a 224 ms tick once a second
## averages to about 4 ms and reads as nothing at all.
##
## **THIS TIMES EACH CALL ITSELF RATHER THAN ASKING THE ENGINE, AND THAT IS THE
## POINT.** `TIME_PROCESS` and `TIME_PHYSICS_PROCESS` cannot attribute a frame at
## all: measured over a 199-frame run, each of them **changed 4 times**. They are
## not per-frame values that lag by one, they are a sample taken about twice a
## second and held flat in between. So `proc 29 + phys 126` printed beside a
## 132 ms frame is not that frame's split -- it is whatever the sample happened to
## hold, which is why five separated spikes all read an identical `proc 78`.
##
## A line was built here that "aligned" those by reading them a frame later, and
## it was false precision: no offset fixes a value that is not computed per frame.
## It first said the cost was outside every `_process` this game owns while the
## whole of it sat in a `_physics_process`, and when it later pointed AT physics
## it was right by coincidence, on evidence just as bad. **When an engine counter
## will not answer the question, time the thing yourself instead of hunting the
## offset that makes the counter honest.** `stats_line` still prints one
## end-of-run sample of each, which is all they ever honestly were.
func _driven_line() -> String:
	if _driven.is_empty():
		return ""
	var rows: Array = []
	for i in _driven.size():
		rows.append([_driven_worst[i], (_driven[i].get_script() as Script).resource_path.get_file()])
	rows.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	var out := PackedStringArray()
	for r: Array in rows.slice(0, 6):
		out.append("%s %.1f" % [String(r[1]), float(r[0])])
	return "\nworld physics worst per system in steady play (ms): " + ", ".join(out)


## WHAT A SYSTEM SAYS ABOUT ITS OWN TICK, if it has anything to say. The lines
## above name a system and a millisecond; a system whose tick is several calls
## can break its own number down further, and only it knows where the seams are.
##
## Duck-typed like `tour_seen` rather than a base-class method, so a system that
## has nothing to add writes nothing and this file needs no list of which do.
## The same move as driving the pass from here in the first place: when the
## number you have names no culprit, go one level in rather than guessing.
func _own_lines() -> String:
	var out := ""
	for s: GameSystem in _driven:
		if is_instance_valid(s) and s.has_method(&"stats_line"):
			out += String(s.call(&"stats_line"))
	return out


## The same for the `_process` pass, and the count is part of the reading: it
## says how much of the frame this line can actually see (`_gather_process`).
func _proc_line() -> String:
	if _pdriven.is_empty():
		return ""
	var rows: Array = []
	for i in _pdriven.size():
		if not is_instance_valid(_pdriven[i]):
			continue
		var src := _pdriven[i].get_script() as Script
		rows.append([_pdriven_worst[i], src.resource_path.get_file()])
	rows.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	var out := PackedStringArray()
	for r: Array in rows.slice(0, 8):
		out.append("%s %.1f" % [String(r[1]), float(r[0])])
	return "\nworld proc worst per node in steady play (ms, %d driven): " % _pdriven.size() + ", ".join(out)


## WHAT A TYPICAL FRAME SPENDS, which is the question p50 asks and the worst
## lines cannot answer. Sorted by mean, and the TOTAL is the headline: it says
## how much of the median frame this instrument can see at all.
func _mean_line() -> String:
	if _pdriven.is_empty() or _pdriven_ticks == 0:
		return ""
	var rows: Array = []
	var sum := 0.0
	for i in _pdriven.size():
		if not is_instance_valid(_pdriven[i]):
			continue
		var mean := _pdriven_total[i] / float(_pdriven_ticks)
		sum += mean
		rows.append([mean, (_pdriven[i].get_script() as Script).resource_path.get_file()])
	rows.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	var out := PackedStringArray()
	for r: Array in rows.slice(0, 8):
		out.append("%s %.2f" % [String(r[1]), float(r[0])])
	var phys := 0.0
	if _driven_ticks > 0:
		for i in _driven.size():
			phys += _driven_total[i] / float(_driven_ticks)
	return "\nworld typical frame (ms): proc driven %.2f over %d frames, phys driven %.2f -- " % [sum, _pdriven_ticks, phys] + ", ".join(out)


func _process(_delta: float) -> void:
	_pdriven_ticks += 1
	# Driven FIRST, and before the early return, because a frame this file bails
	# out of is still a frame every other node has to run in.
	for i in _pdriven.size():
		if not is_instance_valid(_pdriven[i]):
			continue
		var began := Time.get_ticks_usec()
		_pdriven[i].call(&"_process", _delta)
		var took := float(Time.get_ticks_usec() - began) / 1000.0
		_pdriven_total[i] += took
		# STEADY PLAY ONLY, and the two halves of this stats block disagreed about
		# that for as long as both have existed. `frame_line` takes `warm_frames`
		# off the front before it reports a percentile; this worst took every frame
		# including the world's first, so the same printout answered "what does a
		# bad frame of PLAY cost" and "what did LOADING cost" in adjacent lines,
		# under one heading, with nothing saying which was which.
		#
		# It is not a cosmetic mismatch. It sent me to fix the wrong thing: the
		# chunk apply showed 9.8 ms worst, I cut it to 3.0 and measured no change
		# in the spikes, because the 9.8 was the world's first frames and not a
		# frame anybody plays. The same line put `24_holds` at 22.8 ms, which is
		# its one chapter refresh at world entry and never happens again.
		#
		# `WARM_MOST` rather than `warm_frames` because that one reads a finished
		# run and this is a live tick; it is the same allowance the warm-up is
		# capped at, so the two lines now disagree by at most the frames the run
		# was ALLOWED to spend landing.
		if _pdriven_ticks > WARM_MOST and took > _pdriven_worst[i]:
			_pdriven_worst[i] = took
	if game == null or game.view == null:
		return
	_tell_camera_how_tall_it_builds()
	_frames += 1
	if game.options.stats:
		# Only the frame's own delta is worth keeping per frame. The engine's
		# TIME_PROCESS / TIME_PHYSICS_PROCESS monitors were collected here too and
		# are not per-frame values -- see `_driven_line`'s header for the
		# measurement that retired them.
		_ms.append(_delta * 1000.0)
	# The renderer does not time itself unless asked, and it must be asked BEFORE
	# the frame that is read: `stats_line` runs at frames-1, so switching this on
	# here gives it several frames of measurement to report.
	if game.options.stats and _frames == 1:
		var vp := game.view.get_viewport()
		if vp != null:
			RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	if game.options.stats and _frames == maxi(3, game.options.frames - 1):
		# What the frame was actually drawn by, before what it cost: a tier that
		# quietly stepped down, or a machine that never got Forward+, changes every
		# number on the next line and is invisible otherwise (docs/LOOK.md).
		# "world " first: tools/shot.sh only forwards lines that begin `world ` or
		# `shot `, so a line named anything else is printed and thrown away.
		var px := Quality.render_pixels()
		print("world render: %s, quality %s, world %dx%d of %dx%d, slate pitch %d, caps %d" % [
			"forward_plus" if Quality.forward_plus() else "gl_compatibility",
			Quality.current_id(), px.x, px.y, UiBase.SIZE.x, UiBase.SIZE.y,
			UiBase.PITCH, UiFont.CAP])
		print(stats_line(game.view))
		print(frame_line(_ms) + _driven_line() + _proc_line() + _mean_line() + _own_lines())


## The camera's near focus clears the tallest thing a landscape BUILDS, and only
## this file is in a position to say what that is: the camera package may not know
## about landscapes and the biome package may not know about cameras.
##
## The TALLEST of what can be in frame, not what is underfoot, and the difference
## is the whole point: the buildings this rule is about stand at the near edge of
## the picture, which on a border is the other landscape. Asking the tile the
## player is standing on would keep the city's towers blurred until they had
## walked past them, which is exactly the frame that started this.
##
## Five samples round the frame's own reach — cheap, and it cannot be wrong about
## a landscape it can see. The camera eases the change itself, so the number
## arriving a little early and leaving a little late is also the pull that reads
## best walking in.
const LOOK_ROUND := 16.0

func _tell_camera_how_tall_it_builds() -> void:
	if game.camera == null or game.world == null:
		return
	var w := game.world
	var p: Vector2 = game.player.pos if game.player != null else w.spawn
	var high := 0.0
	for d: Vector2 in [Vector2.ZERO, Vector2(LOOK_ROUND, 0.0), Vector2(-LOOK_ROUND, 0.0),
			Vector2(0.0, LOOK_ROUND), Vector2(0.0, -LOOK_ROUND)]:
		var x := clampi(floori(p.x + d.x), 0, w.size - 1)
		var y := clampi(floori(p.y + d.y), 0, w.size - 1)
		high = maxf(high, BiomeForms.of(w.country_at(x, y)).tallest())
	game.camera.clear_lift = high


## **AN INSTRUMENT THAT CANNOT REPORT ITS OWN GAP FAILS TOWARD GREEN**, which is
## the whole reason `unaccounted` is on this line. The mesher profiles its seven
## stages and nothing profiled `Decor.build_arrays` or `bake_props`, which are
## WorldView's work and not the mesher's — so the line named 36 ms of a 46 ms
## build and read as complete. Somebody (me) then quoted those six stages as the
## cost of a chunk and planned an afternoon against them. The residual is what
## makes that impossible: if everything is named it is ~0, and if it is not, the
## line says so instead of quietly summing to less than the total.
## **AND THE `fps` THIS LINE USED TO END WITH WAS THE SAME MISTAKE IN ITS OWN
## LAST FIELD.** `Performance.TIME_FPS` is frames in the last SECOND, and a shot
## renders a handful of frames after a twelve-second world gen, so it printed
## `fps 1` for a frame carrying 165 draw calls. It is not wrong about itself --
## the process really did render about one frame in that second -- it is
## answering a question nobody asked, and it reads exactly like a framerate.
## Believing it cost an hour hunting a stall that was not there, on the same
## night `ForePerf`'s header already said in writing that this number lies.
##
## **AND THE LINE NOW ACCOUNTS FOR THE WHOLE FRAME, not just the chunks**, which
## is the same rule as `unaccounted` one paragraph up. `proc` and `phys` are what
## the main thread spent on every node and every physics tick. They are here
## because the night this field was fixed, play was at 5 fps with `proc` at 88 ms
## and render CPU at 0.40 -- and nothing printed said so, so the chase started at
## the renderer, which was the one part doing its job. A line that reports only
## the part you own will send the next person to the part you own.
##
## The honest replacement is the one thing a shot CAN know: what the renderer
## measured for the frame it just drew. The GPU half is left off because Metal
## through MoltenVK answers zero here (`ForePerf` again), and a nought is worse
## than a silence -- the next person would believe it.
static func stats_line(view: WorldView) -> String:
	var n := maxf(1.0, view.build_count)
	var pr := view.stage_usec()
	# prof 0,1,2,3,4,5,7 are times; 6 is the vertex count, which was collected
	# on every chunk since the mesher was written and read by nothing.
	var mesher_ms := (pr[0] + pr[1] + pr[2] + pr[3] + pr[4] + pr[5] + pr[7]) / 1000.0
	var gap := view.build_ms - view.main_ms - mesher_ms - view.decor_ms - view.props_ms
	return "world stats: draw calls %d, objects %d, primitives %d, chunks %d (parked %d, far %d/%d avg %.1f ms, main avg %.1f max %.1f), chunk build avg %.1f ms max %.1f ms over %d (main thread avg %.1f max %.1f; mesher fill %.1f shore %.1f tiles %.1f lattice %.1f cells %.1f water %.1f arrays %.1f decor %.1f props %.1f unaccounted %.1f), verts %d, frame: proc %.1f ms, phys %.1f ms, render cpu %s" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		view.chunk_count(), view.parked_count(),
		view.far.block_count() if view.far != null else 0, view.far_wanted(),
		view.far_ms / maxf(1.0, view.far_count),
		view.far_main_ms / maxf(1.0, view.far_count),
		view.far_main_ms_max,
		view.build_ms / n, view.build_ms_max, view.build_count,
		view.main_ms / n, view.main_ms_max,
		pr[0] / 1000.0 / n, pr[1] / 1000.0 / n, pr[2] / 1000.0 / n, pr[7] / 1000.0 / n, pr[3] / 1000.0 / n, pr[4] / 1000.0 / n, pr[5] / 1000.0 / n,
		view.decor_ms / n, view.props_ms / n, gap / n, int(pr[6] / n),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		_render_cpu(view)]


## What the renderer measured for the frame it just drew, asked of the view's own
## viewport so it is the world being drawn and not some other one.
##
## **A clock that is not running says so.** Godot only times a viewport that was
## asked to (`viewport_set_measure_render_time`), and on this machine the GPU half
## answers zero even then -- so a bare `%.2f` here would print `0.00 ms` for a
## frame carrying 165 draw calls, which is the same lie as `fps 1` wearing better
## units. `ForePerf` learned this first and its header says why: saying nought
## when the clock is stopped is worse than saying nothing, because the next
## person believes a number.
static func _render_cpu(view: WorldView) -> String:
	var vp := view.get_viewport()
	if vp == null:
		return "unmeasured"
	var ms := RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid())
	return "%.2f ms" % ms if ms > 0.0 else "unmeasured"


## The frame budgets, and docs/PERF.md is why each one is the number it is. The
## headline: BotW targets a 33.3 ms frame, so OUR WORST MAY NOT EXCEED THEIR
## TARGET -- our worst frame no worse than their best.
##
## **EACH ONE IS A REFRESH INTERVAL AND IS WRITTEN AS ONE**, because two of them
## used to be written as the rounded decimal and rounded the WRONG WAY: 120 Hz is
## 8.3333 ms and `P50_MS` was 8.3, so a frame pacer delivering a perfect 120 fps
## failed the 120 Hz budget by three hundredths of a millisecond and printed
## "p50 8.3 ms ... PERF FAIL: p50" -- which reads as a broken printer, not as a
## bar set below its own target. `WORST_MS` 33.3 was the same against 30 Hz.
## Measured: the populated walk at `--quality=low` holds p50 = p95 = p99 = 8.3,
## the best thing this judge can ever be shown, and it was called a failure.
## `tests/render/test_frame_budget.gd` holds every budget to being reachable at
## the rate it names.
const P50_MS := 1000.0 / 120.0
const P95_MS := 1000.0 / 72.0
const P99_MS := 1000.0 / 60.0
const WORST_MS := 1000.0 / 30.0
## A frame four times its neighbours reads as a jolt however fast they were.
const WORST_OVER_P50 := 4.0
## The fewest steady frames this line will pass JUDGEMENT on. docs/PERF.md's own
## standard is "a run of at least 300 frames", and the numbers below are about
## VARIANCE -- p99 is a claim about one frame in a hundred, so five frames cannot
## contain one and `over 16.7 ms: 0 (0%)` off that sample is not a measurement,
## it is a rounding error wearing a verdict.
##
## AND THE DEFAULT MADE EVERY RUN THAT SAMPLE. `BootOptions.frames` is 8, so a
## plain `tools/shot.sh --stats` judged the game on five steady frames and printed
## PERF OK, and every perf figure taken in this repository before this const was
## added came off that. Measured on one walking run: at the default it reports
## p50 8.3, worst 11.0, nothing over budget, PERF OK -- and the SAME run at
## `--frames=600` reports p50 9.5, p99 16.7, worst 24.5 and 1% of frames over.
## The second is the game the owner is playing; the first is the reason he was
## told it was fine while it stuttered.
##
## So this reports the numbers and DECLINES the verdict, the way `cost_lt` refuses
## to judge a cost on a busy machine. A withheld verdict sends somebody to add
## `--frames`; a false green sends them away.
const JUDGE_LEAST := 300

## How many frames a run is allowed to spend warming up, and the ceiling on any
## one of them (docs/PERF.md: warm-up is a separate promise, not an exemption).
const WARM_MOST := 12
const WARM_CEILING_MS := 250.0


## Where warm-up ends: the leading run of frames that miss the p99 budget, which
## on a real run is the first one or two while the world lands. Capped, so a
## pathological run cannot classify its whole self as warm-up and pass.
##
## **THIS EXISTS BECAUSE THE JUDGEMENT WAS WRONG WITHOUT IT, IN THE DIRECTION
## THAT MATTERS.** docs/PERF.md has always bounded warm-up separately, and this
## line took its percentiles over every frame including it -- so a run measuring
## p95 9.3 and p99 12.9 in steady play, both inside budget, printed PERF FAIL on
## the strength of frame 0. An instrument that cannot report a pass cannot be
## used to tell you when to stop working, and it teaches the reader to discount
## it, which is worse than printing nothing.
static func warm_frames(ms: PackedFloat32Array) -> int:
	var n := 0
	while n < ms.size() and n < WARM_MOST + 1 and ms[n] > P99_MS:
		n += 1
	return n


## WHAT A PLAYER CALLS JUMPY, stated as a distribution rather than an average.
## The worst frames are the whole complaint: a run that sits at 8 ms and spikes
## to 60 four times a second is unplayable and has a fine mean. The count is
## printed so a short run cannot pretend to be evidence.
##
## STEADY PLAY IS JUDGED AGAINST THE BUDGETS AND WARM-UP AGAINST ITS OWN BOUND,
## because they are different promises and a player meets them differently: the
## warm-up frames are seen once, the rest are lived with.
static func frame_line(ms: PackedFloat32Array) -> String:
	if ms.size() < 4:
		return "world frames: too few to say (%d)" % ms.size()
	var warm := warm_frames(ms)
	var warm_worst := 0.0
	for i in warm:
		warm_worst = maxf(warm_worst, ms[i])
	var steady := ms.slice(warm)
	if steady.size() < 4:
		return "world frames: too few after warm-up to say (%d of %d)" % [steady.size(), ms.size()]
	var a := Array(steady)
	a.sort()
	var pick := func(q: float) -> float: return float(a[clampi(int(q * (a.size() - 1)), 0, a.size() - 1)])
	var over := 0
	for v: float in a:
		if v > P99_MS:
			over += 1
	# WHERE the slow frames fall decides what kind of problem it is: bunched at the
	# start is warm-up a player sees once, spread through the run is a hitch they
	# live with. An average cannot tell those apart and they want opposite fixes.
	var where := PackedStringArray()
	for i in range(warm, ms.size()):
		if ms[i] > P99_MS:
			where.append("%d:%.0f" % [i, ms[i]])
	# JUDGED, not just reported. docs/PERF.md sets the budgets and the reason the
	# headline is the WORST frame: BotW's target frame is 33.3 ms, so ours may
	# never exceed it -- our worst no worse than their best. A line that prints a
	# number and leaves the reader to know whether it is good is half an
	# instrument.
	var p50: float = pick.call(0.5)
	var p95: float = pick.call(0.95)
	var p99: float = pick.call(0.99)
	var worst := float(a[-1])
	var bad := PackedStringArray()
	if p50 > P50_MS:
		bad.append("p50")
	if p95 > P95_MS:
		bad.append("p95")
	if p99 > P99_MS:
		bad.append("p99")
	if worst > WORST_MS:
		bad.append("worst")
	if p50 > 0.0 and worst / p50 > WORST_OVER_P50:
		bad.append("worst/p50")
	# Warm-up is judged too, on its own terms, so it can never be a hiding place:
	# a loading screen that is not over is still a loading screen.
	if warm > WARM_MOST:
		bad.append("warm-up frames")
	if warm_worst > WARM_CEILING_MS:
		bad.append("warm-up ceiling")
	return "world frames: n %d steady (+%d warm-up, worst %.0f ms), p50 %.1f ms, p95 %.1f, p99 %.1f, worst %.1f, worst/p50 %.1fx, over %.1f ms: %d (%.0f%%) -- %s\nworld slow frames (index:ms): %s" % [
		a.size(), warm, warm_worst, p50, p95, p99, worst, (worst / p50 if p50 > 0.0 else 0.0),
		P99_MS, over, 100.0 * over / a.size(),
		(("UNJUDGED: %d steady frames, %d wanted -- pass --frames=600" % [a.size(), JUDGE_LEAST])
			if a.size() < JUDGE_LEAST
			else ("PERF OK" if bad.is_empty() else "PERF FAIL: " + ", ".join(bad))),
		" ".join(where)]
