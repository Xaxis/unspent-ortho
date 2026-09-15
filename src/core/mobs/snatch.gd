class_name Snatch
## What a dart takes when it reaches the player (design-extract §7.4): time,
## food, a wound, or a record. Nothing to fight; the answer is the weather,
## the hour, a hedge, or catching it first. Pure over the body and the bag;
## the caller charges the minutes to the clock.

## Returns {minutes: float, line: String, hurt: bool, took: StringName}.
static func apply(kind: StringName, body: Body, inv: Inventory, now_minutes: float) -> Dictionary:
	var hits: Dictionary = Roster.row(kind).get("hits", {})
	var result := {"minutes": 0.0, "line": String(hits.get("line", "")), "hurt": false, "took": &""}
	if hits.get("arrest", false):
		# Each meeting costs more than the last, up to the cap.
		var minutes := minf(float(hits.get("cap", 240.0)), float(hits.get("minutes", 60.0)) + float(hits.get("again", 0.0)) * body.arrests)
		body.arrests += 1
		result.minutes = minutes
	elif hits.has("minutes"):
		result.minutes = float(hits.minutes)
	if hits.get("hurts", false):
		body.hurt_until = maxf(body.hurt_until, now_minutes + result.minutes + FightRules.HURT_MINUTES)
		result.hurt = true
	if hits.has("food"):
		var food := first_food(inv)
		if food == &"":
			result.line = String(hits.get("empty_line", ""))
		else:
			inv.remove(food, int(hits.food))
			result.took = food
	return result


static func first_food(inv: Inventory) -> StringName:
	if inv == null:
		return &""
	var ids: Array = inv.items.keys()
	ids.sort()
	for id: StringName in ids:
		if float(Items.def(id).get("feeds", 0.0)) > 0.0:
			return id
	return &""


## A clerk that got clear with what it read: machines see the player further.
static func file(body: Body) -> void:
	body.filed += 1
