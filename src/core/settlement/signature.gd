class_name Signature
extends RefCounted
## What a settlement gives off that a machine can sense (docs/VISION.md §9.4):
## light at night, noise, smoke, radio, power draw, the FOUND technology running
## inside the walls, and traffic in and out. Each channel is 0..1.
##
## This is the whole reason machines come. A settlement is engaged because of
## what it makes, never because of a clock, so every raid the player suffers can
## be traced back to a line on this object, and every line can be brought down
## by a decision: dim the lamps, kill the mast, bury the stolen cell, run dark
## and be poorer for it.

const CHANNELS: Array[StringName] = [&"light", &"noise", &"smoke", &"radio", &"power", &"found_tech", &"traffic"]

## How far each channel carries to a machine's senses. Radio travels furthest
## and a stolen cell answers a ping in the machines' own language; smoke is a
## day thing, light a night thing, and both are weighed by the hour before they
## reach here.
const CARRY := {
	&"light": 0.9,
	&"noise": 0.5,
	&"smoke": 0.8,
	&"radio": 1.0,
	&"power": 0.7,
	&"found_tech": 0.85,
	&"traffic": 0.5,
}

var light := 0.0
var noise := 0.0
var smoke := 0.0
var radio := 0.0
var power := 0.0
var found_tech := 0.0
var traffic := 0.0


func get_channel(name: StringName) -> float:
	match name:
		&"light": return light
		&"noise": return noise
		&"smoke": return smoke
		&"radio": return radio
		&"power": return power
		&"found_tech": return found_tech
		&"traffic": return traffic
	return 0.0


func set_channel(name: StringName, value: float) -> void:
	var v := clampf(value, 0.0, 1.0)
	match name:
		&"light": light = v
		&"noise": noise = v
		&"smoke": smoke = v
		&"radio": radio = v
		&"power": power = v
		&"found_tech": found_tech = v
		&"traffic": traffic = v


func add(name: StringName, amount: float) -> void:
	set_channel(name, get_channel(name) + amount)


## Take `amount` off every channel: what a spoofer, netting or shutters do. A
## decoy does not: it is read in the holding's place, not over it (`Settlement.lures`).
func mask(amount: float) -> void:
	for c in CHANNELS:
		set_channel(c, get_channel(c) - amount)


## What a machine at distance makes of the whole place, 0..1. The loudest thing
## dominates and the rest only add a little, so a settlement is given away by
## its one mistake rather than by the sum of its comforts: a radio mast left on
## is worse than a dozen quiet plots, and killing that one channel is worth
## doing.
func total() -> float:
	var top := 0.0
	var rest := 0.0
	for c in CHANNELS:
		var v: float = get_channel(c) * float(CARRY[c])
		if v > top:
			rest += top
			top = v
		else:
			rest += v
	return clampf(top + 0.25 * rest, 0.0, 1.0)


## The channel giving the place away, for what a machine reports and what a
## raiding party goes for first.
func loudest() -> StringName:
	var best: StringName = &""
	var top := 0.0
	for c in CHANNELS:
		var v: float = get_channel(c) * float(CARRY[c])
		if v > top:
			top = v
			best = c
	return best


func as_dict() -> Dictionary:
	var out := {}
	for c in CHANNELS:
		out[String(c)] = get_channel(c)
	return out


static func from_dict(d: Dictionary) -> Signature:
	var s := Signature.new()
	for c in CHANNELS:
		s.set_channel(c, float(d.get(String(c), 0.0)))
	return s
