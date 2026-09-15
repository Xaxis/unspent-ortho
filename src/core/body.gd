class_name Body
extends RefCounted
## The player's condition, as data. Fight logic (src/core/fight/) owns health,
## wind and the fight-state fields; survival logic (src/core/survival/) owns
## hunger, wet, load and sleep. The HUD only reads.

# --- fight (health in whole points; wind in the source's units) ---
var max_health := 12
var health := 12
var max_wind := 2400.0
var wind := 2400.0
## Game-clock-independent, in seconds of real time (fight runs on real time).
var invuln_until := 0.0
var stun_until := 0.0
## >0 while something has hold of the player (ensnare). Pulls remaining.
var grip := 0
var grip_since := 0.0
## In a dodge's burst this instant (the view and HUD may show it).
var dodging := false
## World minute until which the body is wounded (a bad end to a fight, a spraying).
var hurt_until := 0.0
## Times a warden has held the player: each meeting costs more (fight owns).
var arrests := 0

# --- survival ---
## World minute until which the player is fed. Hungry when clock passes it.
var fed_until := 0.0
var wet := 0.0 # 0..1
var load := 0.0 # sum of bulk carried
var tired := 0.0 # 0..1

## Multiplier on walking speed from hunger, load, wet, hurt. Survival writes, player reads.
var move_factor := 1.0
## The player's lamp is lit: undoes the dark for machine sight, lights the ground.
var lamp_lit := false
## Times a machine has filed the player (manipulate): machine sight grows with it.
var filed := 0

## Busy until this real time (working, eating): movement is refused.
var busy_until := 0.0


## 0 fed, 1 peckish, 2 hungry, 3 starving. `now` is world minutes.
## (source: fed 14 h after eating, peckish until 20 h, hungry until 30 h)
func hunger_level(now: float) -> int:
	var over := now - fed_until
	if over <= 0.0:
		return 0
	if over < 360.0:
		return 1
	if over < 960.0:
		return 2
	return 3
