class_name JumpPlan
extends RefCounted
## One jump, planned whole before the feet leave the ground (Jump.plan): every
## point of the arc and the height of the body at each, where it lands and what
## kind of jump that made it. Replayed by `AbilityMotion.jump`, so what is drawn
## and what a test measured are the same arc.

var from := Vector2.ZERO
var to := Vector2.ZERO
var dir := Vector2.ZERO
var from_level := 0
var to_level := 0
var from_height := 0.0
var to_height := 0.0
## The body's position and its height in the world (not above the ground) at
## every `Jump.DT` of the arc, the take-off first and the landing last.
var points: PackedVector2Array = PackedVector2Array()
var heights: PackedFloat32Array = PackedFloat32Array()
var seconds := 0.0
## Jump.HOP UP ACROSS DOWN DIVE
var kind: StringName = &"hop"
## The first planning came down deeper than a jump may drop (the planner re-plans).
var too_deep := false


## Where the body is `t` seconds into the arc, and how high: [Vector2, float].
func at(t: float) -> Array:
	if points.is_empty():
		return [from, from_height]
	var f := clampf(t / Jump.DT, 0.0, float(points.size() - 1))
	var i := floori(f)
	var j := mini(i + 1, points.size() - 1)
	var u := f - float(i)
	return [points[i].lerp(points[j], u), lerpf(heights[i], heights[j], u)]


## The highest the body gets above where it took off.
func peak() -> float:
	var top := from_height
	for h: float in heights:
		top = maxf(top, h)
	return top - from_height
