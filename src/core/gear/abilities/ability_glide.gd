class_name AbilityGlide
extends Ability
## A wing of mended plate: FOUND panels bound to a MADE frame with cord
## (docs/LOOK.md). It opens only where there is something to step off, and it
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


## The nearest lip over a drop deeper than the wing falls in its SECONDS, and
## the way off it: {at, dir}, or {} within `reach`. For tours, which stand a
## body there by name (`ledge glide`), never by coordinate.
static func find_deep(world: WorldData, query: WorldQuery, near: Vector2, reach: int = 64) -> Dictionary:
	if world == null:
		return {}
	var need := ceili(FALL * SECONDS / WorldData.STEP) + 2
	var cx := floori(near.x)
	var cy := floori(near.y)
	for r in range(0, reach + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var tx := cx + dx
				var ty := cy + dy
				if not world.in_bounds(tx, ty) or (query != null and not query.standable(tx, ty)):
					continue
				var at := Vector2(tx + 0.5, ty + 0.5)
				var here := world.level_at(tx, ty)
				for i in 8:
					var dir := Vector2.from_angle(TAU * float(i) / 8.0)
					# Where the wing's seconds run out: still that far below the lip.
					var below := at + dir * SPEED * SECONDS
					var bx := floori(below.x)
					var by := floori(below.y)
					if not world.in_bounds(bx, by) or here - world.level_at(bx, by) < need:
						continue
					if query != null and not query.standable(bx, by):
						continue
					# And nothing along the way rises to meet the wing first.
					var clear := true
					var d := 3.0
					while clear and d < SPEED * SECONDS:
						var q := at + dir * d
						clear = world.in_bounds(floori(q.x), floori(q.y)) and here - world.level_at(floori(q.x), floori(q.y)) >= need
						d += 1.0
					if not clear:
						continue
					if launch(world, query, at, dir) != Vector2.ZERO:
						return {"at": at, "dir": dir}
	return {}


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
	ctx.motion = AbilityMotion.glide(ctx.pos(), dir, SPEED, FALL, SECONDS, start)
	ctx.draw(&"glide", {"dir": dir, "at": ctx.pos()})
	return true
