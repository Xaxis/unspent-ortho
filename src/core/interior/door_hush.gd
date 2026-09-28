class_name DoorHush
extends RefCounted
## A ROOM FALLS QUIET WHEN A MACHINE PASSES ITS DOOR (docs/MIDDENS_ROOMS.md, the
## face settlement: "the settlement stops talking when one passes"). Nothing
## outside runs while the player is in a pocket: a door clears the fight's bodies
## (20_realms.enter) and puts the outside's systems to sleep. So the machines
## outside are SNAPSHOT at the door, each with its round, and walked on along it
## while the player is in: a pure function of the snapshot and the seconds since.
##
##   DoorHush.snapshot(mobs, door, reach) -> Array[Dictionary]
##       every live machine within `reach` of `door`: {kind, a, b, u, dir,
##       speed, hears}, its round the line a..b, `u` how far along it, `dir` +1
##       toward b, `speed` the pace it walks its round at, `hears` its hearing
##   DoorHush.at(s, seconds) -> Vector2    where a snapshot stands after `seconds`
##   DoorHush.toward_b(s, seconds) -> bool the way it is going then
##   DoorHush.quiet(snaps, door, seconds) -> float
##       1 while any is within its hearing of the door, easing to 0 by FADE
##       tiles past it: the room holds its breath as long as it could be heard
##   DoorHush.weight(row) -> &"light" | &"mid" | &"heavy"
##       its weight class, by the size its roster row gives it: what its
##       footfalls through the heap sound like (SoundEffects `passing_*`)
##   DoorHush.entered(snaps, door, from, to) -> Array[int]
##       the snapshots that came within their hearing of the door between the
##       two times: each is heard to pass once, as it comes

## Tiles past a machine's hearing over which the hush lets go.
const FADE := 2.0
## A round is walked at this share of a body's pace (Brains, its idle round).
const ROUND_SHARE := 0.6


static func snapshot(mobs: Array, door: Vector2, reach: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: Variant in mobs:
		var ms := m as MobState
		if ms == null or not ms.alive or ms.removed or not ms.machine:
			continue
		if ms.pos.distance_to(door) > reach:
			continue
		var a := ms.line_a
		var b := ms.line_b
		var ab := b - a
		var len := ab.length()
		var u := clampf((ms.pos - a).dot(ab / len), 0.0, len) if len > 0.01 else 0.0
		out.append({"kind": ms.kind, "weight": weight(ms.row), "a": a, "b": b, "u": u, "dir": 1.0 if ms.line_to_b else -1.0,
			"speed": maxf(0.0, ms.pace * ROUND_SHARE), "hears": float(ms.row.get("hears", 6)),
			"stands": ms.pos if len <= 0.01 else Vector2.INF})
	return out


## How far along a..b after `seconds`, and the way it is going, folded back at
## each end as a round is walked.
static func _along(s: Dictionary, seconds: float) -> Vector2:
	var len := (s.b as Vector2).distance_to(s.a)
	if len <= 0.01:
		return Vector2(0.0, 1.0)
	var d := float(s.u) + float(s.dir) * float(s.speed) * maxf(0.0, seconds)
	var loop := 2.0 * len
	var f := fposmod(d, loop)
	return Vector2(f, 1.0) if f <= len else Vector2(loop - f, -1.0)


## By its drawn size, radius times height: a runner (0.39) is light, a sorter
## (0.83) middling, a harvester (1.44) or anything as big heavy.
const LIGHT_BELOW := 0.5
const HEAVY_FROM := 1.0
static func weight(row: Dictionary) -> StringName:
	var size := float(row.get("radius", 0.5)) * float(row.get("height", 1.0))
	if size < LIGHT_BELOW:
		return &"light"
	return &"mid" if size < HEAVY_FROM else &"heavy"


static func entered(snaps: Array[Dictionary], door: Vector2, from: float, to: float) -> Array[int]:
	var out: Array[int] = []
	for i in snaps.size():
		var s := snaps[i]
		var hears := float(s.hears)
		if at(s, from).distance_to(door) > hears and at(s, to).distance_to(door) <= hears:
			out.append(i)
	return out


static func at(s: Dictionary, seconds: float) -> Vector2:
	var stands: Vector2 = s.get("stands", Vector2.INF)
	if stands.is_finite():
		return stands
	var a: Vector2 = s.a
	var b: Vector2 = s.b
	return a + (b - a).normalized() * _along(s, seconds).x


static func toward_b(s: Dictionary, seconds: float) -> bool:
	return _along(s, seconds).y > 0.0


static func quiet(snaps: Array[Dictionary], door: Vector2, seconds: float) -> float:
	var q := 0.0
	for s: Dictionary in snaps:
		var d := at(s, seconds).distance_to(door)
		var hears := float(s.hears)
		q = maxf(q, 1.0 - clampf((d - hears) / FADE, 0.0, 1.0))
	return q
