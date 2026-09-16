class_name AbilityDash
extends Ability
## A spring coil in the gear throws the body a short way, fast, and leaves a
## trail of stipple behind it (docs/ART.md §7). It is breath, not magic: it
## costs wind, so it is a way out of one blow, never a way of travelling.

const SPEED := 12.0
const SECONDS := 0.22
const COOLDOWN := 1.8
const WIND := 320.0


func _init() -> void:
	id = &"dash"
	name = "dash"
	action = &"ability_dash"
	cooldown = COOLDOWN
	wind = WIND
	note = "q  burst"


func refusal(ctx: AbilityCtx) -> StringName:
	var b := ctx.body()
	if b == null:
		return &"nothing"
	if b.grip > 0:
		return &"held"
	if Time.get_ticks_msec() / 1000.0 < b.busy_until:
		return &"busy"
	return &""


func on_press(ctx: AbilityCtx) -> bool:
	var dir := ctx.heading()
	ctx.motion = AbilityMotion.dash(dir, SPEED, SECONDS)
	ctx.draw(&"dash", {"dir": dir, "at": ctx.pos()})
	return true
