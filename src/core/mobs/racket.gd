class_name Racket
## You hear a machine before you see it (design-extract §7.4): a machine at
## work is audible out to its `racket` (+4 with an aerial), and the first time
## one is heard while the camera cannot show it, the player is told, once.
## Pure; the mobs system asks each beat and says the line.

## Worn aerial: hears machines this much further.
const AERIAL := 4.0
## However many machines are about, no more than one such line in this long (real ms).
const QUIET_MS := 90000.0

const LINES := [
	"Something is working nearby, out of sight.",
	"A machine is at work somewhere close.",
	"You hear something working, and cannot see it.",
]


static func audible(m: MobState, player: Vector2, aerial: bool = false) -> bool:
	if not m.machine or not m.alive or m.removed:
		return false
	var racket: float = float(m.stat("racket", 0))
	if racket <= 0.0:
		return false
	return Senses.chebyshev(m.pos, player) <= racket + (AERIAL if aerial else 0.0)


## Should this body be announced now? True at most once per body; `last_told_ms`
## is when any body was last announced (real ms), `now_ms` is now.
static func should_tell(m: MobState, player: Vector2, visible: bool, aerial: bool, now_ms: float, last_told_ms: float) -> bool:
	if m.heard_told or visible or not audible(m, player, aerial):
		return false
	return now_ms - last_told_ms >= QUIET_MS


static func line_for(m: MobState) -> String:
	return LINES[m.id % LINES.size()]
