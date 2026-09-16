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
## The same, with where: the playtest heard "nearby" and could not tell which way.
const LINES_FROM := [
	"Something is working off to the %s, out of sight.",
	"A machine is at work somewhere to the %s.",
	"You hear something working to the %s, and cannot see it.",
]
const COMPASS := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]


## Compass words for the way from `from` to `to` (tile space: x east, y south).
static func bearing_words(from: Vector2, to: Vector2) -> String:
	var a := (to - from).angle()
	return COMPASS[posmod(roundi(a / (PI * 0.25)), 8)]


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


static func line_for(m: MobState, player: Vector2 = Vector2.INF) -> String:
	if not player.is_finite():
		return LINES[m.id % LINES.size()]
	return LINES_FROM[m.id % LINES_FROM.size()] % bearing_words(player, m.pos)
