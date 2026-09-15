class_name Condition
## The body's survival rules as pure functions of numbers (design-extract §5,
## §6.1-6.2). Survival calls these with the game's state; tests call them bare.
##
## The source charged a worn body in step cost:
##   cost = 2 + laden(+1 at creel, +2 at 2x creel) + hunger(peckish 1, hungry 2,
##          starving 4) + tired 1 + wet 1 + hurt 1
##   seconds per tile = 0.20 x (1 + 0.25 x (cost - 2)), clamped 0.16..0.45
## Here the same cost becomes a multiplier on walking speed, so a worn body is
## slower and never stopped: move_factor = 0.20 / seconds, floored at 0.20/0.45.

## Hours a meal lasts at most: you are full 14 h after you last ate. (source)
const FED_HOURS := 14.0
const MIN_FACTOR := 0.20 / 0.45
## Awake this long and the body is tired. (source)
const TIRED_AFTER_H := 18.0
## Wet lasts this long after the rain stops or you leave the water. (source)
const WET_MINUTES := 90.0
## Sleep is refused from 07:00 to 16:59, and within 4 h of waking. (source)
const SLEEP_REFUSED_FROM := 7.0
const SLEEP_REFUSED_UNTIL := 17.0
const SLEEP_AFTER_WAKING_H := 4.0
## Wake at 06:00 under a roof, 08:00 without. (source)
const WAKE_ROOF := 6.0
const WAKE_OUT := 8.0
## Starving on your feet: you sit down for a shift, and wake as if you ate 7 h ago. (source)
const COLLAPSE_MINUTES := 480.0
const COLLAPSE_ATE_AGO_H := 7.0
## Eating takes this many world minutes. (source)
const EAT_MINUTES := 10.0


## Step-cost extra over ordinary walking.
static func step_extra(load: float, creel: float, hunger_level: int, tired: bool, wet: bool, hurt: bool) -> int:
	var extra := 0
	if load >= creel * 2.0:
		extra += 2
	elif load >= creel:
		extra += 1
	extra += [0, 1, 2, 4][clampi(hunger_level, 0, 3)]
	extra += int(tired) + int(wet) + int(hurt)
	return extra


static func move_factor(extra: int) -> float:
	var seconds := clampf(0.20 * (1.0 + 0.25 * extra), 0.16, 0.45)
	return clampf(0.20 / seconds, MIN_FACTOR, 1.0)


## fed_until after eating something that feeds `hours`: the last meal moves
## forward by that much, but never past now (you cannot eat ahead).
static func fed_after_eating(fed_until: float, now: float, hours: float) -> float:
	var ate := fed_until - FED_HOURS * 60.0
	ate = minf(ate + hours * 60.0, now)
	return ate + FED_HOURS * 60.0


## Hours of food that would make the body full right now.
static func hours_to_full(fed_until: float, now: float) -> float:
	return maxf(0.0, (now + FED_HOURS * 60.0 - fed_until) / 60.0)


## The food to eat from `foods` (ids): the biggest meal that is not wasted,
## else the smallest. &"" if none.
static func best_food(foods: Array[StringName], need_hours: float) -> StringName:
	var best := &""
	var best_feeds := -1.0
	var smallest := &""
	var smallest_feeds := INF
	for id in foods:
		var f := Items.feeds(id)
		if f <= 0.0:
			continue
		if f <= need_hours + 0.01 and f > best_feeds:
			best = id
			best_feeds = f
		if f < smallest_feeds:
			smallest = id
			smallest_feeds = f
	return best if best != &"" else smallest


static func is_tired(now: float, woke_at: float) -> bool:
	return now - woke_at >= TIRED_AFTER_H * 60.0


## Why sleep is refused, or &"" if it is allowed. `sheltered` = by a fire or in a village.
static func sleep_refusal(now: float, woke_at: float, sheltered: bool) -> StringName:
	if not sheltered:
		return &"exposed"
	var h := fposmod(now, 1440.0) / 60.0
	if h >= SLEEP_REFUSED_FROM and h < SLEEP_REFUSED_UNTIL:
		return &"day"
	if now - woke_at < SLEEP_AFTER_WAKING_H * 60.0:
		return &"awake"
	return &""


static func sleep_line(why: StringName) -> String:
	match why:
		&"exposed":
			return "Not out here, with no fire."
		&"day":
			return "It is too light to sleep."
		&"awake":
			return "You are not tired yet."
	return ""


## The world minute of the next waking after `now`.
static func wake_minute(now: float, roof: bool) -> float:
	var wake_h := WAKE_ROOF if roof else WAKE_OUT
	var day_start := floorf(now / 1440.0) * 1440.0
	var t := day_start + wake_h * 60.0
	if t <= now:
		t += 1440.0
	return t


## Weather kinds that wet a body out in them (names as Weather.at returns them).
static func wets(kind: String, strength: float) -> bool:
	return strength >= 0.25 and kind in ["rain", "storm", "snow", "hail", "sleet", "drizzle"]
