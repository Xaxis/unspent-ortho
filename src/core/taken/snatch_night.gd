class_name SnatchNight
extends RefCounted
## WHO THE PLAN COMES FOR (docs/STORY.md: the depots run the minds of people who
## have seen him, to predict him). A village whose people have seen him loses one
## of them to its region's yard: on the first small hours at least AFTER_HOURS
## (and up to AFTER_SPREAD more, per village) after it first saw him, and never
## while he is there. It is predicting him, so it comes when he is gone.
##
## Traced to something he did, as every raid is (48_raids' header): nobody who
## has not seen him is ever taken. Pure: world minutes in, world minutes out.

## Hours after a village first saw him before the plan may come for it, and the
## spread per village on top, so a coast seen in one walk is not emptied in one night.
const AFTER_HOURS := 12.0
const AFTER_SPREAD := 12.0
## The small hours it comes in, world clock hours [from, to).
const NIGHT_FROM := 1.0
const NIGHT_TO := 4.0
## Tiles from the village he has to be for it to come: past where its people are
## drawn (35_folk.FAR), so it is never staged in front of him.
const AWAY := 46.0

const _DAY := 1440.0


## The world minute the plan comes for village `village` of world `seed_value`,
## first seen by it at `seen_at`.
static func due(seen_at: float, seed_value: int, village: int) -> float:
	var h := Rng.hash01(seed_value, village, 0x5a7c)
	return _small_hours_from(seen_at + (AFTER_HOURS + h * AFTER_SPREAD) * 60.0, seed_value, village)


## Due again after he was last at the village at `was_there`: the next small hours.
static func after_him(was_there: float, seed_value: int, village: int) -> float:
	return _small_hours_from(was_there, seed_value, village)


## Whether it comes now: it is due, and he is not there.
static func comes(now: float, due_at: float, he_is_there: bool) -> bool:
	return now >= due_at and not he_is_there


## The first minute at or after `from` that falls at this village's own time in
## the small hours.
static func _small_hours_from(from: float, seed_value: int, village: int) -> float:
	var at_hour := NIGHT_FROM + Rng.hash01(seed_value, village, 0x5a7d) * (NIGHT_TO - NIGHT_FROM)
	var at := floorf(from / _DAY) * _DAY + at_hour * 60.0
	if at < from:
		at += _DAY
	return at
