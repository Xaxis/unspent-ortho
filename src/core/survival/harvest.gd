class_name Harvest
## What the use key would do to the thing in reach, as a state a highlight can be
## drawn from, and how much of a thing the taking has left standing (owner,
## 2026-09-17: "auto highlighted when the player is in position ... once
## harvested they proportionally disappear").
##
## Both are read off the rules the key itself runs on — `Survival.use_target`,
## the choice `Takes.choose` makes for what is in hand, `SurvivalState.taken` —
## so a highlight can never promise what the key will not do, and a rock can never
## look more broken than the takes it has had.
##
##   Harvest.target(game) -> {prop, state, verb, item, tool}    or {} with nothing in reach
##   Harvest.shown(game, prop) -> float                          0..1 of it still standing
##   Harvest.apply_shown(game, prop) -> bool                     write it on the prop; true if it changed
##
## States, in the words a player would use:
##   WORKABLE     the key works it now, with what is in hand
##   OTHER_TOOL   something carried would; the key takes it out and works it
##   TOO_HARD     nothing carried is hard enough
##   PICKED_OVER  its gatherable part is spent until it grows back
##   UNDER_WATER  the tide is over it
##   NO_TOOL      it wants a tool the player does not carry at all
##   YOURS        the heap the player left at their feet

const WORKABLE := &"workable"
const OTHER_TOOL := &"other_tool"
const TOO_HARD := &"too_hard"
const PICKED_OVER := &"picked_over"
const UNDER_WATER := &"under_water"
const NO_TOOL := &"no_tool"
const YOURS := &"yours"

## A thing the taking consumes is never drawn below this share of its size before
## it goes: the last take is what takes it away, not a shrink to nothing.
const SHOWN_LEAST := 0.25


## What the use key would do to what is in reach right now.
static func target(game: Game) -> Dictionary:
	if game == null or game.player == null or game.query == null:
		return {}
	var t := Survival.use_target(game)
	if t == null:
		return {}
	var state := SurvivalState.of(game)
	if state.left.has(t.id):
		return {"prop": t, "state": YOURS, "verb": &"take", "item": &"", "tool": &""}
	var c := Survival.choice_for(game, t)
	var o: Dictionary = c.get("option", {})
	var out := {"prop": t, "verb": StringName(str(o.get("verb", &""))), "item": StringName(str(o.get("item", &""))), "tool": &""}
	if bool(c.get("ok", false)):
		out["state"] = WORKABLE
		return out
	var alt := Survival.tool_for(game, t)
	if alt != &"":
		out["state"] = OTHER_TOOL
		out["tool"] = alt
		out["verb"] = Items.verb(alt)
		return out
	match StringName(str(c.get("why", &""))):
		&"hard":
			out["state"] = TOO_HARD
		&"spent":
			out["state"] = PICKED_OVER
		&"tide":
			out["state"] = UNDER_WATER
		_:
			out["state"] = NO_TOOL
	return out


## How much of `prop` the taking has left standing, 0..1. Only a take that
## CONSUMES the thing counts (`keep` false: a boulder broken, a vein worked out, a
## wreck stripped): gathering a bush's berries or a tree's deadfall leaves the
## bush and the tree whole. With two ways of consuming one thing (peat cut or dug)
## the further-gone one is what is left, since both are taking the same bank.
static func shown(game: Game, prop: WorldProp) -> float:
	if game == null or prop == null:
		return 1.0
	var state := SurvivalState.of(game)
	var gone := 0.0
	var opts := Takes.options(prop.kind)
	for i in opts.size():
		var o: Dictionary = opts[i]
		if bool(o.keep) or int(o.uses) <= 1:
			continue
		var taken := int(state.taken.get(SurvivalState.key(prop.id, i), 0))
		gone = maxf(gone, clampf(float(taken) / float(o.uses), 0.0, 1.0))
	return 1.0 - gone


## Size `prop` to what is left of it: the share is written on the prop, and the
## world view bakes it as a thing WORKED DOWN (`Broken`) — the same thing with a
## piece off it and a fresh face where the hammer went, not a smaller copy of
## itself. The footprint follows what is left, so a half-broken rock stops a body
## where it is drawn. Its size before any taking is remembered on first use and put
## back when it grows back. Returns true when anything changed (the caller
## refreshes the view).
static func apply_shown(game: Game, prop: WorldProp) -> bool:
	if game == null or prop == null:
		return false
	var state := SurvivalState.of(game)
	var share := shown(game, prop)
	if share >= 1.0:
		if not state.base_size.has(prop.id):
			return false
		var base: Vector2 = state.base_size[prop.id]
		state.base_size.erase(prop.id)
		var changed := not is_equal_approx(prop.solid, base.y) or not is_equal_approx(prop.shown, 1.0)
		game.world.set_scale(prop, base.x)
		game.world.set_solid(prop, base.y)
		game.world.set_shown(prop, 1.0)
		return changed
	if not state.base_size.has(prop.id):
		state.base_size[prop.id] = Vector2(prop.scale, prop.solid)
	var b: Vector2 = state.base_size[prop.id]
	var was := prop.shown
	game.world.set_shown(prop, share)
	# What is left stands where it stood: a rock worked down keeps most of its
	# footprint until the last go takes it away.
	game.world.set_solid(prop, b.y * lerpf(size_for(share), 1.0, 0.5))
	return not is_equal_approx(was, prop.shown)


## How wide what is left is, as a share of what it was: the square root, because a
## footprint is an area. The DRAWING works a thing down rather than in (`Broken`);
## this is only what the footprint it still stops a body with is measured against.
static func size_for(share: float) -> float:
	return maxf(SHOWN_LEAST, sqrt(clampf(share, 0.0, 1.0)))
