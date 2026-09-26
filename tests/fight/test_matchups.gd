extends TestCase
## NO HOPELESS MATCHUP: every weapon beats every common machine with good play.
## A matchup may be hard; it is never a wall. One machine roused five tiles off,
## the crowd reader (tests/fight/crowd_reader.gd) holding the weapon, twenty
## charges for a found one, four starts round the compass: at least one is won
## inside the limit. The slate may call a matchup poor; that is advice.
##
## Common machines: every roster machine that spawns (chance above 0) and is not
## a keeper's body (Roster.sentinel_of) or a dart. A dart (warden, clerk) comes to
## take and go and is not there to be fought (Spawner.DART_SHARE); its matchup is
## getting out of its sight in the challenge.

const G := preload("res://tests/fight/test_crowd_reader.gd")

const STARTS := 4
const SECONDS := 90.0
const CHARGES := 20


static func common_machines() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in Roster.kinds():
		var r := Roster.row(k)
		if r.get("machine", false) and Roster.sentinel_of(k) == &"" and r.get("approach", &"") != &"dart" and int(r.get("chance", 0)) > 0:
			out.append(k)
	return out


## Every item with a swing that is a weapon or a tool to fight with.
static func weapons() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in Items.DEFS:
		var d: Dictionary = Items.DEFS[id]
		if d.has("swing") and d.get("tool", false):
			out.append(id)
	return out


func test_every_weapon_beats_every_common_machine() -> void:
	var kinds := common_machines()
	var tools := weapons()
	gt(kinds.size(), 10, "the roster's machines are found")
	gt(tools.size(), 20, "the weapons are found")
	var hopeless: Array[String] = []
	for k in kinds:
		for tool in tools:
			var won := false
			for s in STARTS:
				if G.gate(true, s * 2, k, 1, [], SECONDS, tool, CHARGES).won:
					won = true
					break
			if not won:
				hopeless.append("%s vs %s" % [tool, k])
	print("  info %d weapons x %d machines, hopeless: %s" % [tools.size(), kinds.size(), hopeless])
	eq(hopeless.size(), 0, "no weapon is hopeless against a common machine: %s" % [hopeless])
