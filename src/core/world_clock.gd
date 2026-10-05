class_name WorldClock
extends RefCounted
## One clock, and it is the world's: game minutes since day 0, 00:00. Real
## seconds drive it at Tuning.MINUTES_PER_SECOND. Walking buys no time; only
## deliberate jumps (sleep, being carried off) call skip(). (owner ruling 9)

var minutes := 0.0
## World minutes to a real second (a configuration's `rules.clock` sets it).
var rate := Tuning.MINUTES_PER_SECOND
## THE SET PIECE'S SHARE OF THE RATE (43_climb's only writer): while a climb holds
## the world it runs at this share of `rate`, the day, hunger, the keepers, the
## raids and the light all together, and the walkers keep the whole of it
## (`walk_lead`), so the climb's gait stays in real seconds. 1 the rest of the time.
var set_piece := 1.0
## World minutes the walkers have walked past this clock: what set pieces held
## back from the world and not from them. Saved with the clock (SaveCore).
var walk_lead := 0.0


func _init(start_hour: float = Tuning.START_HOUR) -> void:
	minutes = start_hour * 60.0


func advance(real_seconds: float) -> void:
	minutes += real_seconds * rate * set_piece
	walk_lead += real_seconds * rate * (1.0 - set_piece)


## The walkers' own minute: the world's, and the lead the set pieces gave them.
## The one truth for walker time (19_colossi `minutes()` reads it, and nothing
## outside src/core/colossus computes a walker's pose from `minutes`:
## tests/core/test_walker_time.gd).
func walk_minutes() -> float:
	return minutes + walk_lead


func skip(game_minutes: float) -> void:
	minutes += game_minutes


func day() -> int:
	return floori(minutes / 1440.0)


func hour() -> float:
	return fposmod(minutes, 1440.0) / 60.0


func label() -> String:
	var h := floori(hour())
	var m := floori(fposmod(minutes, 60.0))
	return "day %d  %02d:%02d" % [day() + 1, h, m]
