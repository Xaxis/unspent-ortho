class_name Interference
extends RefCounted
## What the plan's network in one region makes of the player (docs/VISION.md §2).
## One number per network, 0 calm .. 1 hunted. Sabotage, theft, killing workers,
## being filed and breaking curfew raise it; time, distance, hiding and a
## misread signature lower it. Its level is read region-wide: at wary the
## workers look up, at hostile they stop working and come, at hunted the
## network sends hunters.
##
## A network is a region's works and what serves them: one per REGION, so two
## snowfields on opposite coasts keep separate files on the player and robbing
## one does not make the other come for you. `network` is the only place that
## knows how a region is identified.
##
## Pure data: the disposition system owns one of these, saves it and reads it.

## What each cause adds (0..1). The machines are barely functioning: one theft
## is nothing to a network, a dead worker is most of the way to wary.
const CAUSES := {
	&"blocked": 0.02,
	&"trespass": 0.05,
	&"curfew": 0.06,
	&"theft": 0.10,
	&"sabotage": 0.16,
	&"filed": 0.14,
	&"killed_machine": 0.13,
	&"killed_worker": 0.22,
}

## Network ids for tiles with no region recorded (off the map, or a world made
## before regions existed): negative, so they can never collide with a region id.
const REGIONLESS := -1

## Levels a region is read at, coldest first.
const LEVELS: Array[StringName] = [&"calm", &"wary", &"hostile", &"hunted"]
const THRESHOLDS: Array[float] = [0.0, 0.26, 0.56, 0.84]

## It falls this much per world hour with the player somewhere in the region
## and nothing happening. The machines are barely functioning and their memory
## is short: a file the player walks away from goes cold in minutes, because a
## region that can never be left is a wall, not a gap to live in.
const DECAY_PER_HOUR := 0.09
## Nothing has the player any more: the file has nothing to feed on and cools
## faster. Down in cover with it, faster still; and with a spoofed signature
## the whole file is read as one of their own.
const UNSEEN_DECAY := 1.5
const HIDDEN_DECAY := 1.9
const SPOOF_DECAY := 3.2
## Far from where it last rose (or out of the region), it cools at full rate;
## standing at the scene it barely cools at all.
const COOL_DISTANCE := 64.0
const AT_THE_SCENE := 0.3
## A cause counts at most this often (world minutes), so one long job of
## stripping a mast is one theft, not eight.
const SAME_CAUSE_GAP := 20.0

## network id -> 0..1.
var levels: Dictionary = {}
## network id -> the tile where it last rose.
var scenes: Dictionary = {}
## "network|cause" -> the world minute it last counted.
var counted: Dictionary = {}


## The plan network at a tile: the region it stands in (`WorldData.regions`, one
## connected run of one landscape type). Off the map, or in a world made before
## regions were recorded, the landscape type stands in for it, so an old save
## still reads one file per landscape rather than none.
static func network(world: WorldData, p: Vector2) -> int:
	if world == null:
		return 0
	var x := floori(p.x)
	var y := floori(p.y)
	var r := world.region_at(x, y)
	if r >= 0:
		return r
	return REGIONLESS - world.country_at(x, y)


static func level_of(v: float) -> int:
	var lvl := 0
	for i in THRESHOLDS.size():
		if v >= THRESHOLDS[i]:
			lvl = i
	return lvl


static func name_of(v: float) -> StringName:
	return LEVELS[level_of(v)]


func value(net: int) -> float:
	return float(levels.get(net, 0.0))


func level(net: int) -> int:
	return level_of(value(net))


func level_name(net: int) -> StringName:
	return LEVELS[level(net)]


## Raise a network by a cause. Returns how much it actually rose (0 when the
## same cause has already counted recently).
func raise(net: int, cause: StringName, at: Vector2, minutes: float) -> float:
	var add: float = CAUSES.get(cause, 0.0)
	if add <= 0.0:
		return 0.0
	var key := "%d|%s" % [net, cause]
	if counted.has(key) and minutes - float(counted[key]) < SAME_CAUSE_GAP:
		return 0.0
	counted[key] = minutes
	var before := value(net)
	levels[net] = clampf(before + add, 0.0, 1.0)
	scenes[net] = at
	return value(net) - before


## Time passing. `hours` world hours; `hidden` the player is in cover and
## unseen; `spoofed` their signature reads as one of the machines' own;
## `player_net` and `at` where they are (a network cools at full rate once they
## are far from the scene, or out of the region); `unseen` nothing on the coast
## has them, which is the relief a player who has fought off what was sent
## after them can reach by breaking contact.
func decay(hours: float, hidden: bool, spoofed: bool, player_net: int, at: Vector2, unseen: bool = false) -> void:
	if hours <= 0.0:
		return
	var scale := 1.0
	if hidden:
		scale *= HIDDEN_DECAY
	elif unseen:
		scale *= UNSEEN_DECAY
	if spoofed:
		scale *= SPOOF_DECAY
	for net: int in levels.keys():
		var away := 1.0
		if net == player_net and scenes.has(net):
			var d: float = (scenes[net] as Vector2).distance_to(at)
			away = lerpf(AT_THE_SCENE, 1.0, clampf(d / COOL_DISTANCE, 0.0, 1.0))
		var v := maxf(0.0, float(levels[net]) - DECAY_PER_HOUR * scale * away * hours)
		if v <= 0.0:
			levels.erase(net)
			scenes.erase(net)
		else:
			levels[net] = v


## The highest network on the map, and which it is: [net, value].
func worst() -> Array:
	var best_net := -1
	var best := 0.0
	for net: int in levels:
		if float(levels[net]) > best:
			best = float(levels[net])
			best_net = net
	return [best_net, best]


func save() -> Dictionary:
	var out := {}
	var scene_out := {}
	for net: int in levels:
		out[str(net)] = float(levels[net])
	for net: int in scenes:
		scene_out[str(net)] = SaveCodec.vec2(scenes[net])
	return {"levels": out, "scenes": scene_out}


func load(data: Dictionary) -> void:
	levels.clear()
	scenes.clear()
	counted.clear()
	for k: String in data.get("levels", {}):
		levels[int(k)] = float(data.levels[k])
	for k: String in data.get("scenes", {}):
		scenes[int(k)] = SaveCodec.to_vec2(data.scenes[k])
