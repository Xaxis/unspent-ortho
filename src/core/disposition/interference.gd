class_name Interference
extends RefCounted
## What the plan's network in one region makes of the player (docs/VISION.md).
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
	# STRIPPING A REGION IS NOTICED, and it is the smallest cause in the list on
	# purpose. One seam is nothing; a landscape worked out is the plan losing a
	# resource it had surveyed, and what files it is the ACCUMULATION.
	#
	# This is the load-bearing half of what makes a chapter a game rather than a
	# checklist (docs/VISION.md). The three demands are not three chores: a
	# region gets more dangerous the more of it you take, so by the time you have
	# mined what the place asks for it is wary or worse, and the only thing that
	# ends that is taking the keeper or putting the yard dark — which is the very
	# work you needed the mining to be equipped for. You dig yourself into the
	# danger to earn the means of ending it.
	#
	# 0.04 against a chapter's ceiling of twelve seams is 0.48, which crosses
	# `wary` and stops just under `hostile`: the place turns on you while you work
	# it and never sends hunters for mining alone.
	&"quarried": 0.04,
	&"sabotage": 0.16,
	&"filed": 0.14,
	&"killed_machine": 0.13,
	&"killed_worker": 0.22,
	# A BAD END IS FILED (mechanics improvement 4): put down or carried off, the
	# player is a body the network has had in its hands. Less than a theft, so a
	# bad night does not turn a region on its own; enough that a second one does.
	&"downed": 0.09,
}

## VIOLENCE HAS A SOCIAL PRICE, AND THE PRICE IS WHO SAW IT. The same blow is one
## machine's word for it in an empty bog and a street's worth of filings in a
## city, because the plan's network is only ever as good as what reports to it.
## So a witnessed cause is multiplied by the people who watched it happen, and
## `WITNESSED` is the closed list of what a crowd can actually SEE: a blow, a
## body. Theft in a doorway, a curfew broken and being filed are not on it —
## nobody watching a street can tell those happened at all.
##
## With nobody there `witness_scale` is 1.0, so every landscape that is not a
## crowd behaves exactly as it did before this existed. In a full street one
## swing at a machine (`sabotage`, 0.16) carries a network from calm past
## `hostile`, which is the whole point: where the machines are not hunting
## anybody, the swing is the expensive answer and almost never the right one.
const WITNESSED: Array[StringName] = [&"sabotage", &"killed_machine", &"killed_worker"]
## IT TAKES A CROWD, and below one nothing changes AT ALL. Two people in a lane
## are not a crowd, and pricing them as one would quietly re-tune the stealth
## economy of every village in the game — which is how this was first written,
## and `tests/disposition/test_in_game.gd` caught it by measuring a dead worker
## on the coast at 0.32 where the table says 0.22. So the count starts here, and
## every landscape that is not a city is left exactly as it was.
##
## This is the same threshold `35_folk.CROWD_BLIND` uses to decide that nobody
## looks up any more, and deliberately so: the number of people it takes before
## a stranger stops being an event is the number it takes before a street can
## testify. Core holds no systems, so it is written twice on purpose and
## `tests/models/test_street_crowd.gd` fails if the two ever drift apart.
const WITNESS_CROWD := 8
const WITNESS_EACH := 0.20
## Past this many, another onlooker tells the network nothing it does not have.
const WITNESS_MOST := 20
## How near a person has to be to have seen it. The play camera shows 26.7 x 17.9
## tiles of ground, so this is "in the same street", not "on the same island".
const WITNESS_REACH := 9.0

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

## A NETWORK WITH NOTHING RUNNING IT. Its depot has been put out, or its keeper
## is down (`Events.works_broken`, `Events.sentinel_fell`): the file is still
## open and the machines standing in the region still read it, but there is no
## plant left to keep it and nothing left to send. So it cools fast and it can
## never reach `hunted` again — being hunted means a yard picking bodies and
## putting them on you, and the yard is dark.
##
## This is the whole reward for the set piece. Breaking a depot does not make a
## region safe; it makes it a region that can no longer come after you.
const LOST_DECAY := 2.6
## Just under `hostile`, so a lost region still stiffens when robbed and never
## dispatches.
const LOST_CEILING := 0.55

## network id -> 0..1.
var levels: Dictionary = {}
## network id -> the tile where it last rose.
var scenes: Dictionary = {}
## network id -> true, for networks whose plant has gone. Saved: a region stays
## lost for the rest of the game.
var lost: Dictionary = {}
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


## What `n` onlookers multiply a WITNESSED cause by: 1.0 until there are enough
## of them to be a crowd, and climbing from there. At `WITNESS_MOST` one swing at
## a machine carries a calm network past `hostile` on its own.
static func witness_scale(n: int) -> float:
	if n < WITNESS_CROWD:
		return 1.0
	return 1.0 + WITNESS_EACH * float(clampi(n, 0, WITNESS_MOST) - WITNESS_CROWD + 1)


func value(net: int) -> float:
	return float(levels.get(net, 0.0))


func level(net: int) -> int:
	return level_of(value(net))


func level_name(net: int) -> StringName:
	return LEVELS[level(net)]


## Raise a network by a cause. Returns how much it actually rose (0 when the
## same cause has already counted recently). `witnesses` is how many people
## watched it happen, which multiplies the causes a crowd can see (WITNESSED).
func raise(net: int, cause: StringName, at: Vector2, minutes: float, witnesses: int = 0) -> float:
	var add: float = CAUSES.get(cause, 0.0)
	if add <= 0.0:
		return 0.0
	if witnesses > 0 and WITNESSED.has(cause):
		add *= witness_scale(witnesses)
	var key := "%d|%s" % [net, cause]
	if counted.has(key) and minutes - float(counted[key]) < SAME_CAUSE_GAP:
		return 0.0
	counted[key] = minutes
	var before := value(net)
	levels[net] = clampf(before + add, 0.0, LOST_CEILING if is_lost(net) else 1.0)
	scenes[net] = at
	return value(net) - before


## This network's plant has gone. Called once, and it holds for the game.
func lose(net: int) -> void:
	lost[net] = true
	if levels.has(net):
		levels[net] = minf(float(levels[net]), LOST_CEILING)


func is_lost(net: int) -> bool:
	return lost.has(net)


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
		var here := scale * (LOST_DECAY if is_lost(net) else 1.0)
		var v := maxf(0.0, float(levels[net]) - DECAY_PER_HOUR * here * away * hours)
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
	var lost_out: Array = []
	for net: int in lost:
		lost_out.append(net)
	return {"levels": out, "scenes": scene_out, "lost": lost_out}


func load(data: Dictionary) -> void:
	levels.clear()
	scenes.clear()
	counted.clear()
	lost.clear()
	for k: String in data.get("levels", {}):
		levels[int(k)] = float(data.levels[k])
	for k: String in data.get("scenes", {}):
		scenes[int(k)] = SaveCodec.to_vec2(data.scenes[k])
	for net: Variant in data.get("lost", []):
		lost[int(net)] = true
