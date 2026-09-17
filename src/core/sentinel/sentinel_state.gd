class_name SentinelState
extends RefCounted
## One sentinel INSTANCE: the keeper of one region (`WorldData.regions`, which is
## what a sentinel keys on — CLAUDE.md, the Regions row). It outlives its body:
## the body is put out when the player comes near and culled again when they
## leave, and everything the fight did to it — the health it is down to, the phase
## it reached, whether it fell and how — lives here and is saved.
##
## Pure data and the small rules that belong to one instance. The system
## (44_sentinels) fills in the look, steps the ways and puts out the body.

var region := -1
var design: StringName = &""
var land: StringName = &""
## Where it stands: the plan's work it keeps, or its region's heart.
var lair := Vector2.ZERO
var health := 0
var max_health := 0
var phase := 0
## It has met the player at least once (its body has been put out and roused).
var woken := false
## It no longer keeps this region, and which way it was taken (SentinelWay.id()).
var fallen := false
var how: StringName = &""
## The hulk it left has been laid in the world (saved with the world; laid once).
var hulk_laid := false

# --- live, not saved --------------------------------------------------------

## Its body while one is out, and the beacon the score reads.
var body: MobState = null
## The ground it last stood on and the sim ms it stepped onto it.
var ground_was := -1
var ground_since := 0.0
## The sim ms its feeds went out (INF while it still has one), how many stand now,
## and how many stood the first time it was looked at.
var dark_since := INF
var feeds := 0
var feeds_at_first := -1
## The sim ms the player came inside its guard with a spoofed signature.
var spoof_since := INF
## How far each way has come, 0..1, for a slate and for a test.
var progress: Dictionary = {}


func health_fraction() -> float:
	return clampf(float(health) / maxf(1.0, float(max_health)), 0.0, 1.0)


func alive() -> bool:
	return not fallen and health > 0


## It holds this ground: inside its reach, and still standing.
func holds(p: Vector2, reach: float) -> bool:
	return not fallen and lair.distance_to(p) <= reach


func save() -> Dictionary:
	return {
		"region": region, "design": String(design), "land": String(land),
		"lair": SaveCodec.vec2(lair), "health": health, "max_health": max_health,
		"phase": phase, "woken": woken, "fallen": fallen, "how": String(how),
		"hulk_laid": hulk_laid,
	}


static func from_save(d: Dictionary) -> SentinelState:
	var s := SentinelState.new()
	s.region = SaveCodec.to_int(d.get("region", -1))
	s.design = StringName(str(d.get("design", "")))
	s.land = StringName(str(d.get("land", "")))
	s.lair = SaveCodec.to_vec2(d.get("lair", []))
	s.health = SaveCodec.to_int(d.get("health", 0))
	s.max_health = SaveCodec.to_int(d.get("max_health", 0))
	s.phase = SaveCodec.to_int(d.get("phase", 0))
	s.woken = bool(d.get("woken", false))
	s.fallen = bool(d.get("fallen", false))
	s.how = StringName(str(d.get("how", "")))
	s.hulk_laid = bool(d.get("hulk_laid", false))
	return s
