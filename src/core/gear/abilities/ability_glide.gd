class_name AbilityGlide
extends Ability
## A wing of mended plate: FOUND panels bound to a MADE frame with cord
## (docs/ART.md §10). It opens only where there is something to step off, and it
## carries the body out over ground a walk could never get down, which is what
## makes a mesa or a sea cliff a door instead of a wall.

## Tiles ahead a drop is looked for, and the levels that count as one.
const LOOK := 3.5
const DROP_LEVELS := 2
const SPEED := 5.2
## World units of height lost per second: the land falls away faster than this.
const FALL := 0.55
const SECONDS := 6.0
const COOLDOWN := 3.0


func _init() -> void:
	id = &"glide"
	name = "glide"
	action = &"ability_glide"
	cooldown = COOLDOWN
	note = "g  off a height"


## The way off, if there is one: the direction to launch along, or ZERO.
## Pure, so a test can stand a body on a cliff and ask.
static func launch(world: WorldData, query: WorldQuery, at: Vector2, dir: Vector2) -> Vector2:
	if world == null or dir.length() < 0.01:
		return Vector2.ZERO
	var d := dir.normalized()
	var here := world.level_at(floori(at.x), floori(at.y))
	var step := 0.5
	var travelled := step
	while travelled <= LOOK:
		var p := at + d * travelled
		var l := world.level_at(floori(p.x), floori(p.y))
		if here - l >= DROP_LEVELS:
			return d
		# A rise in the way is a wall, not a launch.
		if l - here >= DROP_LEVELS:
			return Vector2.ZERO
		if query != null and not query.standable(floori(p.x), floori(p.y)):
			return Vector2.ZERO
		travelled += step
	return Vector2.ZERO


func refusal(ctx: AbilityCtx) -> StringName:
	var b := ctx.body()
	if b == null or ctx.game == null:
		return &"nothing"
	if b.grip > 0:
		return &"held"
	if launch(ctx.game.world, ctx.game.query, ctx.pos(), ctx.heading()) == Vector2.ZERO:
		return &"no_drop"
	return &""


func on_press(ctx: AbilityCtx) -> bool:
	var dir := launch(ctx.game.world, ctx.game.query, ctx.pos(), ctx.heading())
	if dir == Vector2.ZERO:
		return false
	var start := ctx.game.world.height_at(ctx.pos())
	ctx.motion = AbilityMotion.glide(dir, SPEED, FALL, SECONDS, start)
	ctx.draw(&"glide", {"dir": dir, "at": ctx.pos()})
	return true
