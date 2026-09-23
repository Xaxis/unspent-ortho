class_name UiMessages
extends RefCounted
## The HUD's message line, as data. The newest line sits lowest; up to MAX
## older ones stand above it, each fading on its own clock, so two things
## said close together are both read. The same line said again does not
## stack: it is refreshed and counted ("Took 2 timber. ×3").
##
## MAX is two, not three. In a landscape that presses with two or three
## hazards at once, plus hunger, plus the guide, three centred lines of body
## text sat across the bottom middle of the world nearly continuously, against
## docs/LOOK.md ("small, quiet readouts clipped to the corners"). What took
## the pressure lines off the glass is `gauge_for` below; two is the cap on
## what is left.

const MAX := 2
const HOLD := 2.2
const FADE := 0.6
## How fast a line already on screen gives way when a fight comes close.
const HUSH := 0.3

## line -> the readout that already says it (built once, on first ask).
static var _gauges := {}


## The gauge in the top right that is already saying `text`, or &"" for a line
## no readout says. The HUD drops such a line and flares the gauge instead
## (Hud.answer_with_gauge): the badges were saying it anyway, and a line of
## body text across the middle of the world is the loudest thing the UI owns.
##
## Built from the tables that own the words, so a new hazard or need line is
## covered the day it is written, never a copy that can drift.
static func gauge_for(text: String) -> StringName:
	if _gauges.is_empty():
		for id: Variant in Hazards.LINES:
			_gauges[String(Hazards.LINES[id])] = StringName(id)
		_gauges[Survival.HUNGRY_LINE] = &"hunger"
		_gauges[Survival.STARVING_LINE] = &"hunger"
		_gauges[Survival.LAMP_LOW_LINE] = &"lamp"
	return _gauges.get(text, &"")

## Oldest first: {text, count, age, now, hush}
var lines: Array[Dictionary] = []
## No text in a fight: while quiet (a hostile close), lines wait here, oldest
## first, and are said once it is over. Lines already on screen fade out in
## HUSH seconds; only a line said `now` stays.
var waiting: PackedStringArray = []
var quiet := false:
	set(v):
		if v and not quiet:
			for l in lines:
				if not l.now:
					l.age = maxf(l.age, HOLD)
					l.hush = true
		quiet = v
		if not quiet:
			for t in waiting:
				push(t)
			waiting.clear()


## `now` says it even in a fight (a refusal the player must hear at once).
## Let go of everything on the line. The player has been put somewhere else and
## nothing said about the last place is true of this one (Events.warped).
func clear() -> void:
	lines.clear()


func push(text: String, now: bool = false) -> void:
	if text == "":
		return
	if quiet and not now:
		if not waiting.has(text):
			waiting.append(text)
		while waiting.size() > MAX:
			waiting.remove_at(0)
		return
	if not lines.is_empty() and lines.back().text == text:
		lines.back().count += 1
		lines.back().age = 0.0
		lines.back().hush = false
		lines.back().now = now
		return
	lines.append({"text": text, "count": 1, "age": 0.0, "now": now, "hush": false})
	while lines.size() > MAX:
		lines.pop_front()


func step(delta: float) -> void:
	for l in lines:
		l.age += delta * (FADE / HUSH if l.hush else 1.0)
	while not lines.is_empty() and lines[0].age > HOLD + FADE:
		lines.pop_front()


static func alpha_at(age: float) -> float:
	if age < HOLD:
		return 1.0
	return clampf(1.0 - (age - HOLD) / FADE, 0.0, 1.0)


## What to draw, oldest first: [{text, alpha}]
func visible() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l in lines:
		var a := alpha_at(l.age)
		if a <= 0.0:
			continue
		var text: String = l.text
		if int(l.count) > 1:
			text += " ×%d" % l.count
		out.append({"text": text, "alpha": a})
	return out
