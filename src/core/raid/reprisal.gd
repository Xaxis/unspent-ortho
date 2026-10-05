class_name Reprisal
extends RefCounted
## WE BREAK THEIR WORKS, THEY BURN A VILLAGE (Vera; slice 2 step 3). A housing
## broken on a yard that still stands is filed as sabotage, and the yard puts its
## hunters on the road (48_raids `_target_for`): to the nearest roof on the yard's
## own body; else to his own fire there, his CAMP or the HOLDING his people live
## in; else nowhere, and nobody is sent. MARCH_MINUTES later (longer for a target
## past REACH, `march_minutes`) it burns, unless the yard has gone dark in the
## meantime. A dark yard sends nobody and calls back whoever it sent (Maren: "So
## we're let be"), which is what Interference.lose already says of a region with
## no plant left to keep it.
##
## Pure: 48_raids asks it and says what it answers. One party a yard at a time.

## World minutes the yard's hunters take to reach the roof: the player's window
## to put the yard dark, or to meet them on the road.
const MARCH_MINUTES := 90.0
## How far a roof may be for the hunters to reach it in MARCH_MINUTES.
const REACH := 150.0
## World minutes a march takes per tile past REACH: the pace the march keeps
## inside it, kept past it, so a far roof gives the player the same window per
## tile of road to put the yard dark or meet them on it. Sent at once over three
## hundred tiles, a march that still took ninety minutes would outrun him.
const MARCH_PACE := MARCH_MINUTES / REACH


## How long a march from `from` to `roof` takes, in world minutes.
static func march_minutes(from: Vector2, roof: Vector2) -> float:
	return MARCH_MINUTES + maxf(0.0, from.distance_to(roof) - REACH) * MARCH_PACE

## What the hunters are sent for, which the glass says (StoryContent.reprisal_says):
## a village's roof; his camp, a place of his where nobody else lives; his
## holding, where the people he brought live; or nothing, and nobody goes.
const ROOF := &"roof"
const CAMP := &"camp"
const HOLDING := &"holding"
const NONE := &"none"

## Region id -> {"roof": where they are going, "kind": what it is, "due": world
## minute, "from": the yard, "minutes": how long its march takes}.
var marching: Dictionary = {}


## The nearest house to `yard` among `props` (a windowed query round the yard),
## or Vector2.INF where there is no roof to burn. `gone` is the world's depleted
## ids: a house already burned is a shell, and the hunters go past it.
static func nearest_roof(props: Array[WorldProp], yard: Vector2, gone: Dictionary = {}) -> Vector2:
	var best := Vector2.INF
	for q in props:
		if q.kind != PropKind.HOUSE or gone.has(q.id):
			continue
		if not best.is_finite() or q.pos.distance_to(yard) < best.distance_to(yard):
			best = q.pos
	return best


## A housing broken on region `region`'s live yard: its hunters leave for `roof`.
## False when a party of that yard is already on the road.
func send(region: int, roof: Vector2, now: float, yard: Vector2 = Vector2.INF, kind: StringName = ROOF) -> bool:
	if marching.has(region) or not roof.is_finite() or kind == NONE:
		return false
	var from := yard if yard.is_finite() else roof
	var minutes := march_minutes(from, roof)
	marching[region] = {"roof": roof, "kind": kind, "due": now + minutes, "from": from, "minutes": minutes}
	return true


## What region `region`'s hunters are on the road for, or NONE.
func kind_of(region: int) -> StringName:
	return StringName(marching[region].get("kind", ROOF)) if marching.has(region) else NONE


## Where region `region`'s party is on the road at world minute `now`: walked
## evenly from its yard to the roof over the march. INF when none is out.
func on_road(region: int, now: float) -> Vector2:
	if not marching.has(region):
		return Vector2.INF
	var m: Dictionary = marching[region]
	var gone := clampf(1.0 - (float(m.due) - now) / float(m.get("minutes", MARCH_MINUTES)), 0.0, 1.0)
	return (m.from as Vector2).lerp(m.roof, gone)


## The yard has gone dark: whoever it sent comes back, and nothing burns.
func call_off(region: int) -> void:
	marching.erase(region)


## The marches that have arrived by world minute `now`, each {"roof", "kind"};
## each is answered once.
func burning_now(now: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for region: int in marching.keys():
		var m: Dictionary = marching[region]
		if now >= float(m.due):
			out.append({"roof": m.roof, "kind": StringName(m.get("kind", ROOF))})
			marching.erase(region)
	return out


func save() -> Dictionary:
	var rows: Array = []
	for region: int in marching:
		var m: Dictionary = marching[region]
		rows.append([region, SaveCodec.vec2(m.roof), SaveCodec.num(float(m.due)), SaveCodec.vec2(m.from),
			SaveCodec.num(float(m.get("minutes", MARCH_MINUTES))), String(m.get("kind", ROOF))])
	return {"marching": rows}


func load_from(d: Dictionary) -> void:
	marching.clear()
	for row: Variant in d.get("marching", []):
		if row is Array and (row as Array).size() >= 3:
			var roof := SaveCodec.to_vec2(row[1])
			var from := SaveCodec.to_vec2(row[3]) if (row as Array).size() >= 4 else roof
			var minutes := SaveCodec.to_num(row[4]) if (row as Array).size() >= 5 else MARCH_MINUTES
			var kind := StringName(str(row[5])) if (row as Array).size() >= 6 else ROOF
			marching[SaveCodec.to_int(row[0])] = {"roof": roof, "kind": kind, "due": SaveCodec.to_num(row[2]),
				"from": from, "minutes": minutes}
