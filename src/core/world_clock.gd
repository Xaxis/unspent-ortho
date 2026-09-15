class_name WorldClock
extends RefCounted
## One clock, and it is the world's: game minutes since day 0, 00:00. Real
## seconds drive it at Tuning.MINUTES_PER_SECOND. Walking buys no time; only
## deliberate jumps (sleep, being carried off) call skip(). (owner ruling 9)

var minutes := 0.0


func _init(start_hour: float = Tuning.START_HOUR) -> void:
	minutes = start_hour * 60.0


func advance(real_seconds: float) -> void:
	minutes += real_seconds * Tuning.MINUTES_PER_SECOND


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
