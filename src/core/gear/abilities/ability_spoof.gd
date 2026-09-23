class_name AbilitySpoof
extends Ability
## A signet taken whole out of a machine: for a few minutes it answers their
## challenge in their own language, and they read the body walking past as one
## of theirs (docs/VISION.md, the machines' records are corrupt and their
## signatures are misread; that failure is the player's tool).
##
## It writes `Body.spoof_until`, the contract the disposition package reads; the
## senses stop filing the body while it stands.

## Long enough to be a plan: to cross a works district, or to walk a thing past a
## checkpoint, rather than to dodge one machine.
const MINUTES := 20.0
const COOLDOWN := 30.0
const CHARGES := 1


func _init() -> void:
	id = &"spoof"
	name = "signature spoof"
	action = &"ability_spoof"
	cooldown = COOLDOWN
	charges = CHARGES
	lasts = MINUTES
	note = "v  reads as theirs"


static func spoofed(body: Body, minutes: float) -> bool:
	return body != null and body.spoof_until > minutes


func refusal(ctx: AbilityCtx) -> StringName:
	var b := ctx.body()
	if b == null:
		return &"nothing"
	if spoofed(b, ctx.minutes()):
		return &"already"
	return &""


func on_press(ctx: AbilityCtx) -> bool:
	var b := ctx.body()
	b.spoof_until = ctx.minutes() + MINUTES
	ctx.draw(&"spoof", {"at": ctx.pos(), "minutes": MINUTES})
	return true


## While it stands, the mark is renewed so the player can see they are still
## wearing someone else's name; when it runs out, one last mark says so.
func passive(ctx: AbilityCtx, _delta: float) -> void:
	var b := ctx.body()
	if b == null or b.spoof_until <= 0.0:
		return
	if spoofed(b, ctx.minutes()):
		ctx.draw(&"spoof_beat", {"left": b.spoof_until - ctx.minutes()})
	else:
		b.spoof_until = 0.0
		ctx.draw(&"spoof_ended", {})
