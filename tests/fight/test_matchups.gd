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


func _hopeless(shoulder: bool) -> Array[String]:
	var out: Array[String] = []
	for k in common_machines():
		for tool in weapons():
			var won := false
			for s in STARTS:
				if G.gate(true, s * 2, k, 1, [], SECONDS, tool, CHARGES, 1000, shoulder).won:
					won = true
					break
			if not won:
				out.append("%s vs %s" % [tool, k])
	return out


func test_every_weapon_beats_every_common_machine() -> void:
	gt(common_machines().size(), 10, "the roster's machines are found")
	gt(weapons().size(), 20, "the weapons are found")
	var hopeless := _hopeless(false)
	print("  info %d weapons x %d machines, hopeless: %s" % [weapons().size(), common_machines().size(), hopeless])
	eq(hopeless.size(), 0, "no weapon is hopeless against a common machine: %s" % [hopeless])


## And as a player over the shoulder knows the fight (tests/fight/shoulder_reader.gd):
## what is in the eye's cone, what is heard, what was seen a moment ago.
func test_every_weapon_beats_every_common_machine_over_the_shoulder() -> void:
	var hopeless := _hopeless(true)
	print("  info over the shoulder, %d weapons x %d machines, hopeless: %s" % [weapons().size(), common_machines().size(), hopeless])
	eq(hopeless.size(), 0, "no weapon is hopeless over the shoulder either: %s" % [hopeless])
