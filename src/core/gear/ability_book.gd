class_name AbilityBook
extends RefCounted
## The abilities a loadout has fitted, their cooldowns, and the one place a cost
## is paid. The system feeds it input and time; every rule about whether an
## ability may fire is here, so a test can fire all five without a device.
##
## Order of refusal, so the slate always says the first true reason: not fitted,
## still cooling, no charge, no breath, then whatever the ability itself says.

var fitted: Array[StringName] = []
## id -> the real second it may fire again.
var ready_at: Dictionary = {}
## Instances live as long as the game, so a scan that is running survives a refit.
var _made: Dictionary = {}


## Fit exactly these (Gear.abilities_of). Cooldowns of ones taken off are kept:
## swapping a module out and back in is not a way to skip a cooldown.
func fit(ids: Array[StringName]) -> void:
	fitted = ids.duplicate()


func has(id: StringName) -> bool:
	return fitted.has(id)


func ability(id: StringName) -> Ability:
	if not _made.has(id):
		var a := Abilities.make(id)
		if a == null:
			return null
		_made[id] = a
	return _made[id]


## Every fitted ability, in the order the loadout gave them.
func all() -> Array[Ability]:
	var out: Array[Ability] = []
	for id in fitted:
		var a := ability(id)
		if a != null:
			out.append(a)
	return out


func cooldown_left(id: StringName, now: float) -> float:
	return maxf(0.0, float(ready_at.get(id, -1.0)) - now)


func ready(id: StringName, now: float) -> bool:
	return cooldown_left(id, now) <= 0.0


## Fire it. Returns &"" if it fired, else why not (Ability.refusal_line says it).
func press(id: StringName, ctx: AbilityCtx) -> StringName:
	var a := ability(id)
	if a == null or not has(id):
		return &"nothing"
	if not ready(id, ctx.now):
		return &"cooling"
	var inv: Inventory = ctx.game.inventory if ctx.game != null else null
	if a.charges > 0 and (inv == null or inv.count(&"wick") < a.charges):
		return &"no_charge"
	var hero: Hero = ctx.game.player.hero if ctx.game != null and ctx.game.player != null else null
	if a.wind > 0.0 and hero != null and hero.wind < a.wind:
		return &"winded"
	var why := a.refusal(ctx)
	if why != &"":
		return why
	if not a.on_press(ctx):
		return &"nothing"
	if a.charges > 0 and inv != null:
		inv.remove(&"wick", a.charges)
	if a.wind > 0.0 and hero != null:
		hero.wind = maxf(0.0, hero.wind - a.wind)
	ready_at[id] = ctx.now + a.cooldown
	return &""


func hold_down(id: StringName, ctx: AbilityCtx, delta: float) -> void:
	var a := ability(id)
	if a != null and has(id) and a.hold:
		a.on_hold(ctx, delta)


## Every fitted ability's passive, once a frame.
func step(ctx: AbilityCtx, delta: float) -> void:
	for a in all():
		a.passive(ctx, delta)


## What the slate's gear page shows: [{id, name, ready, note}] in fitted order.
func rows(now: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in all():
		var left := cooldown_left(a.id, now)
		out.append({"id": a.id, "name": a.name, "ready": left <= 0.0,
			"note": a.note if left <= 0.0 else "%.0fs" % ceilf(left)})
	return out


## JSON-safe: cooldowns are kept as how long is left, so a load never hands back
## a cooldown measured on a clock that has since restarted.
func save(now: float) -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in ready_at:
		var left := cooldown_left(id, now)
		if left > 0.0:
			out[String(id)] = left
	return out


func load_from(v: Variant, now: float) -> void:
	ready_at.clear()
	if not (v is Dictionary):
		return
	for k: String in (v as Dictionary):
		ready_at[StringName(k)] = now + float((v as Dictionary)[k])
