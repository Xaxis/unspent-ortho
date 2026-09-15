class_name UiMessages
extends RefCounted
## The HUD's message line, as data. The newest line sits lowest; up to MAX
## older ones stand above it, each fading on its own clock, so two things
## said close together are both read. The same line said again does not
## stack: it is refreshed and counted ("Took 2 timber. ×3").

const MAX := 3
const HOLD := 2.2
const FADE := 0.6

## Oldest first: {text, count, age}
var lines: Array[Dictionary] = []
## No text in a fight: while quiet (a hostile close), lines wait here, oldest
## first, and are said once it is over.
var waiting: PackedStringArray = []
var quiet := false:
	set(v):
		quiet = v
		if not quiet:
			for t in waiting:
				push(t)
			waiting.clear()


## `now` says it even in a fight (a refusal the player must hear at once).
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
		return
	lines.append({"text": text, "count": 1, "age": 0.0})
	while lines.size() > MAX:
		lines.pop_front()


func step(delta: float) -> void:
	for l in lines:
		l.age += delta
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
