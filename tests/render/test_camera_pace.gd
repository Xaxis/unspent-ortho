extends TestCase
## THE PLAYER IS DRAWN MOVING EVENLY, AND THE FRAME DOES NOT CHASE A TERRACE STEP
## (owner, 10-14: "sometimes the camera is overly jerky or bouncy").

const TICK := 1000.0 / 60.0


## A body walking a steady 4 tiles a second, stepped as FightSim steps it (whole
## 8 ms slices inside 60 Hz physics ticks, the rest carried) and drawn at `fps`:
## per frame, how far it moved as drawn (DrawnPace) and where its slices left it.
static func _walk(fps: float, secs: float) -> Dictionary:
	var v := 4.0 / 1000.0
	var pace := DrawnPace.new()
	var now := 0.0
	var carry := 0.0
	var into := 0.0
	var frame := 1000.0 / fps
	var t := 0.0
	var drawn: Array[float] = []
	var raw: Array[float] = []
	var last_d := 0.0
	var last_r := 0.0
	while t < secs * 1000.0:
		t += frame
		into += frame
		while into >= TICK:
			into -= TICK
			carry += TICK
			while carry >= FightRules.SLICE_MS:
				carry -= FightRules.SLICE_MS
				now += FightRules.SLICE_MS
			pace.note(now, Vector2(v * now, 0.0))
		var d := pace.at(DrawnPace.real_ms(now, carry, into / TICK, TICK)).x
		var r := v * now
		if t > 200.0:
			drawn.append(d - last_d)
			raw.append(r - last_r)
		last_d = d
		last_r = r
	return {"drawn": drawn, "raw": raw, "want": v * frame}


static func _worst(steps: Array[float], want: float) -> float:
	var worst := 0.0
	for s in steps:
		worst = maxf(worst, absf(s - want) / want)
	return worst


func test_a_walking_body_is_drawn_moving_evenly_at_any_frame_rate() -> void:
	for fps: float in [60.0, 45.0, 144.0]:
		var w := _walk(fps, 3.0)
		var drawn: Array[float] = w.drawn
		var raw: Array[float] = w.raw
		lt(_worst(drawn, w.want), 0.02, "at %d frames a second each frame moves it its own speed" % fps)
		gt(_worst(raw, w.want), 0.3, "where its slices leave it, it jumps at %d (the judder)" % fps)


func test_a_place_set_is_drawn_there_at_once() -> void:
	var p := DrawnPace.new()
	p.note(0.0, Vector2.ZERO)
	p.note(16.0, Vector2(0.06, 0.0))
	near(p.at(8.0).x, 0.03, 1e-6, "between two ticks it is drawn between")
	p.note(32.0, Vector2(5.0, 5.0))
	eq(p.at(20.0), Vector2(5.0, 5.0), "a jump (a teleport, a boarding) is not slid across")
	p.note(32.0, Vector2(6.0, 5.0))
	eq(p.at(10.0), Vector2(6.0, 5.0), "nor is a place set between slices")
	eq(DrawnPace.new().at(0.0), Vector2.INF, "a body never noted is drawn at its own place")


## From above, a terrace step is half a unit of height. The frame used to follow
## it at the follow rate, scrolling the whole picture each time a walk crossed a
## tile edge and settling again.
func test_the_frame_does_not_chase_a_terrace_step() -> void:
	var c := CameraRig.new()
	var dt := 1.0 / 60.0
	var at := Vector3.ZERO
	for i in 18:
		at = c._follow(at, Vector3(3.0, WorldData.STEP, 0.0), dt)
	gt(at.x, 2.8, "across the ground it follows him at once")
	lt(at.y, 0.15, "a step up is no scroll (%.2f in 0.3 s)" % at.y)
	for i in 30:
		at = c._follow(at, Vector3(3.0, WorldData.STEP * 4.0, 0.0), dt)
	gt(at.y, 1.2, "a climb of more than a step is followed (%.2f)" % at.y)
	# Over the shoulder the eye stands at his head: no slack there.
	c.set("_sh_t", 1.0)
	at = Vector3.ZERO
	for i in 18:
		at = c._follow(at, Vector3(0.0, WorldData.STEP, 0.0), dt)
	gt(at.y, 0.45, "over the shoulder the eye keeps to the head (%.2f)" % at.y)
	c.free()


## Indoors the frame leans 0.7 of each step back toward the room's middle
## (21_doors). Eased at another rate than the follow, the sum ran past where it
## settles and swung back on every step.
func test_a_room_frames_each_step_without_swinging_past() -> void:
	var c := CameraRig.new()
	var dt := 1.0 / 60.0
	var at := Vector3.ZERO
	c.frame_bias = Vector3(-0.7, 0.0, 0.0)
	var most := 0.0
	for i in 90:
		at = c._follow(at, Vector3(1.0, 0.0, 0.0), dt)
		c._ease_lean(dt)
		most = maxf(most, at.x + (c.get("_frame") as Vector3).x)
	lt(most, 0.31, "the frame comes to rest at 0.3 without passing it (%.3f)" % most)
	c.free()
