class_name TrackGround
## What a ground keeps of what walked on it (owner, 2026-09-17: "depending on
## terrain foot and track prints should be left behind player"). The RULE only:
## where a mark is made is TrackPath's, and how one is drawn is TrackMarks'.
##
## A row per ground that takes a mark; a ground with no row keeps nothing (rock,
## road, floor, gravel, scree, limestone, clinker, ice, water):
##   mark       &"print" a foot pressed in; &"scuff" a foot dragged over loose
##              stones; &"flatten" growth bent down and springing back
##   depth      0..1 how plainly it reads, fresh
##   lasts      world minutes until it is gone on a still day
##   fills      weather families that fill it in faster (Weather.family)
##   white      the ground is white: only the hollow is shaded, since the rim it
##              pushed up is as white as the ground
##   rough      0..1 how rough its surface is: a wet rim catches the sun, dry ash
##              does not
##
## Weather fills a mark `FILL` times faster at full strength, so a blizzard takes
## a line of prints in minutes and a still night keeps them till morning. World
## minutes, not seconds: a night slept is a night's filling.

const PRINT := &"print"
const SCUFF := &"scuff"
const FLATTEN := &"flatten"
const FILL := 6.0

const WET: Array[StringName] = [&"rain", &"storm"]

static var _rows: Dictionary = {}


static func rows() -> Dictionary:
	if _rows.is_empty():
		_rows = {
			Ground.SAND: _row(PRINT, 0.55, 240.0, [&"rain", &"storm", &"dust"], false, 0.9),
			Ground.MUD: _row(PRINT, 0.8, 480.0, WET, false, 0.35),
			Ground.PEAT: _row(PRINT, 0.7, 480.0, WET, false, 0.5),
			Ground.SNOW: _row(PRINT, 0.85, 420.0, [&"snow", &"blizzard"], true, 0.65),
			Ground.ASH: _row(PRINT, 0.65, 360.0, [&"rain", &"storm", &"ash", &"dust"], false, 0.97),
			Ground.SALT: _row(PRINT, 0.7, 300.0, [&"rain", &"storm", &"dust"], true, 0.8),
			Ground.PAN: _row(PRINT, 0.55, 300.0, [&"rain", &"storm", &"dust"], false, 0.85),
			Ground.MOSS: _row(PRINT, 0.35, 120.0, WET, false, 0.7),
			Ground.BONE: _row(SCUFF, 0.3, 90.0, [&"dust"], false, 0.9),
			Ground.SWARF: _row(SCUFF, 0.35, 150.0, [], false, 0.45),
			Ground.SHINGLE: _row(SCUFF, 0.28, 45.0, [], false, 0.8),
			Ground.GRASS: _row(FLATTEN, 0.55, 30.0, WET, false, 0.8),
			Ground.HEATH: _row(FLATTEN, 0.55, 40.0, [], false, 0.85),
			Ground.NEEDLES: _row(FLATTEN, 0.58, 50.0, [], false, 0.9),
		}
	return _rows


static func _row(mark: StringName, depth: float, lasts: float, fills: Array, white: bool, rough: float) -> Dictionary:
	return {"mark": mark, "depth": depth, "lasts": lasts, "fills": fills, "white": white, "rough": rough}


## The row for a ground, or {} for one that keeps nothing.
static func of(ground: int) -> Dictionary:
	return rows().get(ground, {})


## How much of a mark's life `minutes` of world time spends under `weather`
## ({kind, strength}, Weather's shape): its share of `lasts`, sped by what fills it.
static func wear(row: Dictionary, minutes: float, weather: Dictionary) -> float:
	if row.is_empty() or minutes <= 0.0:
		return 0.0
	var rate := 1.0
	var family := Weather.family(StringName(str(weather.get("kind", &"clear"))))
	if (row.fills as Array).has(family):
		rate += FILL * clampf(float(weather.get("strength", 0.0)), 0.0, 1.0)
	return minutes * rate / float(row.lasts)
