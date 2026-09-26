class_name AbilityScan
extends Ability
## A reader lens stolen out of a machine's own head: for a few seconds it puts
## ink marks on every working part within reach, and on what each machine thinks
## of you. It is how a player learns where a body is soft before the fight
## starts, and it is FOUND, so the marks are clean and exact, never hatched.

const SECONDS := 6.0
const COOLDOWN := 9.0
const REACH := 20.0
## Seconds between the read being laid again while the scan stands. The system
## holds each mark a little longer than this, so the read never blinks out and
## never piles up: what a player sees is ONE bracket on the part, following the
## machine, for the whole six seconds.
const BEAT := 0.45

## Real second the scan runs out (kept on the ability, so refitting keeps it).
var until := -1.0
var _next_beat := 0.0


func _init() -> void:
	id = &"scan"
	name = "scan"
	action = &"ability_scan"
	cooldown = COOLDOWN
	note = "r  reads parts"


func active(now: float) -> bool:
	return now < until


func refusal(ctx: AbilityCtx) -> StringName:
	if ctx.game == null:
		return &"nothing"
	if active(ctx.now):
		return &"already"
	return &""


## How far a scan reads with this kit fitted (an icelens reads further).
static func reach_of(kit: FightKit) -> float:
	return REACH * (FightKit.ICELENS_REACH if kit != null and kit.icelens else 1.0)


## What the read says of a body, beyond its part: only a dart has a line, since
## a dart is not there to be fought (it snatches and outruns a sprint), and the
## answer to it is getting out of its sight while it stands challenging.
static func advice(row: Dictionary) -> String:
	if row.get("approach", &"") == &"dart":
		return "It takes and goes. Break its sight."
	return ""


func _reach(ctx: AbilityCtx) -> float:
	if ctx.game == null or ctx.game.player == null or ctx.game.player.hero == null:
		return REACH
	return reach_of(ctx.game.player.hero.kit)


func on_press(ctx: AbilityCtx) -> bool:
	until = ctx.now + SECONDS
	_next_beat = ctx.now
	ctx.draw(&"scan", {"reach": _reach(ctx), "seconds": SECONDS, "beat": BEAT})
	return true


## While it stands, the marks are laid again on the beat so they never fade out
## mid-scan; the system draws them where the machines are now.
func passive(ctx: AbilityCtx, _delta: float) -> void:
	if not active(ctx.now) or ctx.now < _next_beat:
		return
	_next_beat = ctx.now + BEAT
	ctx.draw(&"scan_beat", {"reach": _reach(ctx), "beat": BEAT, "left": until - ctx.now})
