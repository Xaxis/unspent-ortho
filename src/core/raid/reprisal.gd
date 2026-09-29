class_name Reprisal
extends RefCounted
## WE BREAK THEIR WORKS, THEY BURN A VILLAGE (Vera; slice 2 step 3). A housing
## broken on a yard that still stands is filed as sabotage, and the yard puts its
## hunters on the road to the nearest roof: MARCH_MINUTES later the roof burns,
## unless the yard has gone dark in the meantime. A dark yard sends nobody and
## calls back whoever it sent (Maren: "So we're let be"), which is what
## Interference.lose already says of a region with no plant left to keep it.
##
## Pure: 48_raids asks it and says what it answers. One party a yard at a time.

## World minutes the yard's hunters take to reach the roof: the player's window
## to put the yard dark, or to meet them on the road.
const MARCH_MINUTES := 90.0
## How far from its yard a region's hunters will go for a roof.
const REACH := 150.0

## Region id -> {"roof": Vector2, "due": world minute, "from": the yard}.
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
func send(region: int, roof: Vector2, now: float, yard: Vector2 = Vector2.INF) -> bool:
	if marching.has(region) or not roof.is_finite():
		return false
	marching[region] = {"roof": roof, "due": now + MARCH_MINUTES, "from": yard if yard.is_finite() else roof}
	return true


## Where region `region`'s party is on the road at world minute `now`: walked
## evenly from its yard to the roof over the march. INF when none is out.
func on_road(region: int, now: float) -> Vector2:
	if not marching.has(region):
		return Vector2.INF
	var m: Dictionary = marching[region]
	var gone := clampf(1.0 - (float(m.due) - now) / MARCH_MINUTES, 0.0, 1.0)
	return (m.from as Vector2).lerp(m.roof, gone)


## The yard has gone dark: whoever it sent comes back, and nothing burns.
func call_off(region: int) -> void:
	marching.erase(region)


## Roofs whose hunters have arrived by world minute `now`; each is answered once.
func burning_now(now: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for region: int in marching.keys():
		var m: Dictionary = marching[region]
		if now >= float(m.due):
			out.append(m.roof)
			marching.erase(region)
	return out


func save() -> Dictionary:
	var rows: Array = []
	for region: int in marching:
		var m: Dictionary = marching[region]
		rows.append([region, SaveCodec.vec2(m.roof), SaveCodec.num(float(m.due)), SaveCodec.vec2(m.from)])
	return {"marching": rows}


func load_from(d: Dictionary) -> void:
	marching.clear()
	for row: Variant in d.get("marching", []):
		if row is Array and (row as Array).size() >= 3:
			var roof := SaveCodec.to_vec2(row[1])
			var from := SaveCodec.to_vec2(row[3]) if (row as Array).size() >= 4 else roof
			marching[SaveCodec.to_int(row[0])] = {"roof": roof, "due": SaveCodec.to_num(row[2]), "from": from}
