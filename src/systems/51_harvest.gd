extends GameSystem
## What the use key would take, marked on the thing itself, and what was taken,
## said on the HUD with its own mark (owner, 2026-09-17). Reachable as the system
## named "51_harvest".
##
## Three things kept apart, because the drawing of both is interim and the world's
## new look is going to replace it (docs/LOOK.md: under a lit world "this can be
## taken" is light falling on the thing, not a bracket drawn over it):
##
##   the RULE       Harvest.target — which thing, and whether the key works it now
##   the PLACEMENT  place() — where it stands, how tall, how wide: pure numbers
##   the DRAWING    UiHarvestMark and UiPickupFeed, which get the two above and
##                  nothing else, so either can be thrown away and redrawn
##
## A tour answers with `harvest_target`, `harvest_target:STATE` (Harvest's states),
## `picked_up`, `picked_up:ITEM` and `worked_down` (something half taken stands with a
## piece off it: `Broken`).

var mark: UiHarvestMark
var feed: UiPickupFeed
var _picked: Dictionary = {}
## Model height per kind|variant|country|worked step, measured once: a thing worked
## down is a shorter model, and the mark has to sit on what is drawn, not on what
## the thing was before the first go.
static var _tall: Dictionary = {}


func setup(g: Game) -> void:
	super.setup(g)
	mark = UiHarvestMark.new()
	mark.name = "harvest_mark"
	mark.game = g
	add_child(mark)
	feed = UiPickupFeed.new()
	feed.name = "pickup_feed"
	add_child(feed)
	Events.took.connect(_on_took)
	# Every material the land gives, drawn ahead off the main thread, so the first
	# stone taken does not stall a frame scanning its sketch.
	var given: Array[StringName] = []
	for kind: int in Takes.table():
		for o: Dictionary in Takes.options(kind):
			if not given.has(o.item):
				given.append(o.item)
			if not (o.bonus as Array).is_empty() and not given.has(o.bonus[0]):
				given.append(o.bonus[0])
	UiSketch.warm(given, UiPickupFeed.SKETCH)


func _exit_tree() -> void:
	if Events.took.is_connected(_on_took):
		Events.took.disconnect(_on_took)


func _process(_delta: float) -> void:
	if game == null or game.player == null or game.world == null:
		return
	mark.target = {}
	if not _may_mark():
		return
	var t := Harvest.target(game)
	if t.is_empty():
		return
	var p: WorldProp = t.prop
	t.merge(place(game, p), true)
	mark.target = t


## A mark is for the moment the key would do something to a thing, and for no
## other: not over an open app, a conversation, a craft's deck or the water.
func _may_mark() -> bool:
	if game.input_blocked() or game.player.ride != null:
		return false
	var hero: Hero = game.player.hero
	return hero == null or not (hero.swimming or hero.airborne)


func _on_took(item: StringName, count: int) -> void:
	# Only things: a count of "stores" collected is said by the holding's own page.
	if Items.def(item).is_empty() or count <= 0:
		return
	feed.add(item, count)
	_picked[item] = true
	_picked[&""] = true


# --- placement: pure numbers, no drawing ---------------------------------------------

## Where a thing the key would take stands, for whatever draws it: `base` (the
## ground under it, 3D), `height` (its top above that, as drawn) and `radius`
## (how wide it is on the ground).
static func place(game: Game, p: WorldProp) -> Dictionary:
	var base := game.world.to_3d(p.pos)
	var country := maxi(Country.COAST, game.world.country_at(floori(p.pos.x), floori(p.pos.y)))
	var variant := PropModels.variant_of(p, game.world.seed_value, country)
	var tall := _model_height(p.kind, variant, country, Broken.bucket(p.shown)) * p.scale
	var radius := maxf(p.solid, 0.35 * p.scale)
	return {"base": base, "height": maxf(0.25, tall), "radius": radius}


static func _model_height(kind: int, variant: int, country: int, worked: int) -> float:
	var key := "%d|%d|%d|%d" % [kind, variant, country, worked]
	if _tall.has(key):
		return float(_tall[key])
	var tpl := PropModels.template(kind, variant, country, worked)
	var top := 0.0
	for v: Vector3 in tpl.made_v:
		top = maxf(top, v.y)
	for v: Vector3 in tpl.found_v:
		top = maxf(top, v.y)
	for v: Vector3 in tpl.leaf_v:
		top = maxf(top, v.y)
	_tall[key] = top
	return top


func tour_seen(what: StringName) -> bool:
	var s := String(what)
	if s.begins_with("harvest_target:"):
		return not mark.target.is_empty() and String(mark.target.get("state", "")) == s.substr(15)
	if s.begins_with("picked_up:"):
		return _picked.has(StringName(s.substr(10)))
	match what:
		&"harvest_target":
			return not mark.target.is_empty()
		&"picked_up":
			return _picked.has(&"")
		&"worked_down":
			return not SurvivalState.of(game).base_size.is_empty()
	return false
