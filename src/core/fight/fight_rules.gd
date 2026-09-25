class_name FightRules
## The fight's numbers and pure rules. Everything here is a function of its
## arguments, so tests pin the research numbers (design-extract §6.4, §7) and
## the actors only call in.

## Fixed simulation slice (125 Hz) and the most real time one frame may feed it.
const SLICE_MS := 8
const MAX_FRAME_MS := 100.0
## Brains think every 64 ms; moods and senses run on 100 ms beats.
const THINK_MS := 64
const BEAT_MS := 100

# --- hero ---
const HEALTH := 12
const PLATE_HEALTH := 3
## After any hit, even one that does no damage.
const HURT_IFRAMES_MS := 700
const WIND := 2400.0
const BRACE_WIND := 700.0
const WIND_REGEN := 500.0
const DODGE_COST := 700.0
## Dodge: 9 tiles/s decaying linearly to 45% over 170 ms (about 1.1 tiles).
const DODGE_SPEED := 9.0
const DODGE_END := 0.45
const DODGE_MS := 170
## Invulnerable in [50, 140) ms after the press: the first 50 and last 30 are exposed.
const DODGE_INVULN_FROM := 50
const DODGE_INVULN_TO := 140
## Swing and dodge both refused until this long after a dodge.
const DODGE_LOCK_MS := 420
## Grip: at least this long between pulls; held this long and you are carried.
const PULL_GAP_MS := 140
const HOLD_LIMIT_MS := 6000
## A press refused now is kept this long and tried again (never for pulls).
## The source had no buffer; a small one is the difference between a fight
## that feels read and one that feels dropped.
const BUFFER_MS := 90
## A blow that rings off plate throws the swinger back a little.
const RING_RECOIL := 3.0
const RING_RECOIL_MS := 90
## Running in a fight spends wind; below the floor you walk.
const RUN_WIND_COST := 220.0
const RUN_WIND_FLOOR := 350.0
## Swings turn toward a body this close to the facing (radians) and this far past reach.
const AIM_ASSIST_ANGLE := 1.05
const AIM_ASSIST_EXTRA := 1.0

# --- outcomes (design-extract §6.5) ---
const DOWNED_MINUTES := 180.0
## A body that comes round wakes at half health: at 3 (the source) any bite put
## a new player straight back down, and a point an hour kept them one bite from
## it for most of a morning.
const DOWNED_WAKE_HEALTH := 6
const CARRIED_MINUTES := 480.0
const CARRIED_RANGE := 300.0
const AWAY_DISTANCE := 8.0
const AWAY_MS := 2000
const NO_PROGRESS_MS := 10000
## A mended point of health per this many world minutes.
const MEND_MINUTES := 60.0
## By a fire a body mends four times as fast: where to go to get well.
const MEND_AT_FIRE_MINUTES := 15.0
## Wounded condition after a bad end, in world minutes.
const HURT_MINUTES := 600.0

# --- tools ---
## The edge at which a worn tool is noticed, once: Inventory.DULL_EDGE.
const DULL_EDGE := Inventory.DULL_EDGE
## One line for one state: the survival package says the same when work dulls it.
const DULL_LINE := Inventory.DULL_LINE
## A made edge at least this keen keeps a bite of 2 (when the tool has one):
## the start knife is half worn, and a knife that hits like a fist taught
## players that tools do not matter in a fight. Below it the edge is truly
## going and the blow blends toward bare hands.
const KEEN_EDGE := 2500
## A found weapon's charge, the item its `wick` counts.
const CHARGE := &"wick"

# --- machines ---
## Made tools could never spend a machine's source life (60-90 against a
## billhook's 2); the rebuild wants a machine beaten by finding its side, so
## a machine's fight health is its life scaled by this. Animals keep theirs.
const MACHINE_LIFE_SCALE := 1.0 / 6.0
## Source i-frames (400-600 ms) outlast a knife's lockout, so every other good
## swing did nothing. Capped so a blow read right always lands.
const MOB_IFRAMES_CAP_MS := 360
## A blow that reaches a machine's working part stalls it this long (a tell in
## progress is lost), at most once in STALL_EVERY_MS: hit, hit, then get out.
## 600 ms leaves room for the second blow of a knife (420 ms lockout) to land
## before it is working again; at 280 the second swing met the next bite.
const STALL_MS := 600
const STALL_EVERY_MS := 1500
## Radians per second a machine turns while it is spent after a bite (the
## bite's cooldown) and while it stands between runs. Slower than a player
## walking round it at close quarters (3.4 tiles/s at ~1.2 tiles is ~2.8 rad/s),
## so the working side is reachable in the window and nowhere else.
const RECOVER_TURN := 1.1
## A machine's bite that met the player is over this soon: no overcommit to punish.
const LANDED_RECOVERY_MS := 160
## Its cooldown after a bite that landed is this, so its next tell
## starts after the player has control back (knockback stun, then the hurt
## i-frames): at 400 one landed bite chained into the next before the player
## could move.
const LANDED_COOLDOWN_MS := 950
const PAUSE_TURN := 1.0
## A real hit on a machine: the part flares this long, still lit, then goes dark
## for PART_DARK_MS. In that order, or the flare is drawn on a part already out.
const PART_FLARE_MS := 150.0
const PART_DARK_MS := 240.0
## World-layer speeds (pace, dash) were tiles/s for a player walking 5; ours walks 3.4.
const SPEED_SCALE := 0.68


## World minutes to mend one point of health: an hour, or a quarter of one by a fire.
static func mend_minutes(by_fire: bool) -> float:
	return MEND_AT_FIRE_MINUTES if by_fire else MEND_MINUTES


static func max_health(plated: bool) -> int:
	return HEALTH + (PLATE_HEALTH if plated else 0)


## (2400 + 700 brace) x clamp(body condition, 0.35, 1). move_factor stands in
## for the source's step cost: a worn body is slower and shorter of wind alike.
static func max_wind(braced: bool, move_factor: float) -> float:
	return (WIND + (BRACE_WIND if braced else 0.0)) * clampf(move_factor, 0.35, 1.0)


## max(1, 1 + (dmg - 1) x edge / 10000), whole points; a tool of 2 or more
## keeps at least 2 while its edge is KEEN_EDGE or better.
static func damage_at_edge(tool_dmg: int, edge: int) -> int:
	var d := maxi(1, int(floor(1.0 + (tool_dmg - 1) * clampf(edge / 10000.0, 0.0, 1.0))))
	if edge >= KEEN_EDGE:
		d = maxi(d, mini(tool_dmg, 2))
	return d


## Dodge burst speed `ms` after the press (0 once the burst is over).
static func dodge_speed(ms: float) -> float:
	if ms < 0.0 or ms >= DODGE_MS:
		return 0.0
	return DODGE_SPEED * lerpf(1.0, DODGE_END, ms / DODGE_MS)


static func dodge_invulnerable(ms: float) -> bool:
	return ms >= DODGE_INVULN_FROM and ms < DODGE_INVULN_TO


## Which side of a body a point is on: &"front" &"right" &"back" &"left".
## The source took the world side (|dx| >= |dy| -> east/west, ties to x) and
## rotated it by a four-way facing. Bodies here face any angle, so the offset
## is turned into the body's frame first and the same test is made there;
## for a facing on an axis it is the source rule.
static func side_of(body_pos: Vector2, body_facing: float, from: Vector2) -> StringName:
	var local := (from - body_pos).rotated(-body_facing)
	if absf(local.x) >= absf(local.y):
		return &"front" if local.x >= 0.0 else &"back"
	# Facing +x, +y (south) is the body's right hand.
	return &"right" if local.y > 0.0 else &"left"


## The plate rule: a blow counts only from the working part's side.
## Reaches = no plate || blow cuts || SideOf(target, swinger) == part.
static func reaches(part: StringName, body_pos: Vector2, body_facing: float, swinger_pos: Vector2, cuts: bool = false) -> bool:
	if part == &"none" or part == &"" or cuts:
		return true
	return side_of(body_pos, body_facing, swinger_pos) == part


## Levels apart at which two bodies are out of each other's blows: a walk steps
## one level, so one level is the same fight, and a ledge (two, what a jump goes
## up) stands a body off from every bite and every swing, both ways. What comes
## down off a ledge is the drop strike's, not a swing's.
const LEDGE_LEVELS := 2


## Can a blow pass between a body on `a_level` and one on `b_level`?
static func levels_meet(a_level: int, b_level: int) -> bool:
	return absi(a_level - b_level) < LEDGE_LEVELS


## Does the blow box of an owner at `o` facing `facing` (with body radius `orad`)
## overlap a round body of radius `trad` at `t`?
static func box_hits(o: Vector2, facing: float, orad: float, b: Blow, t: Vector2, trad: float) -> bool:
	var local := (t - o).rotated(-facing)
	var fx := clampf(local.x, 0.0, orad + b.reach)
	var fy := clampf(local.y, -b.width * 0.5, b.width * 0.5)
	return local.distance_squared_to(Vector2(fx, fy)) <= trad * trad


## Nightfall 0..1, and it is the SAME CURVE THE SKY FALLS ON (`Weather.night_fall`,
## 18:30-21:00 eased at both ends). This is the fight's door onto it — the senses,
## the hazards, the dark hand's reach, the lamp and Survival.in_the_dark all come
## through here — and until this wave it was a different curve: flat zero until
## 20:00, then a straight ramp. The source had them together because the source's
## evening was that one hour; A2 widened the LOOK of dusk to two and a half hours
## and left the BODY on the old line, so a player stood on a snowfield at seven in
## a visibly deep dusk carrying noon's cold, and `Hazards`' own docstring — "a
## snowfield at noon is felt; the same snowfield at dusk bites" — was false for
## exactly the hour a player reads as dusk.
##
## What it costs: night's terms arrive earlier and more gently. At 19:00 it is
## 0.10 where it was 0; at 20:00 0.65 where it was 0; at 20:30 0.90 where it was
## 0.50; at 21:00 and after, unchanged. So cold and dark begin to tell during the
## evening the player can see, machines see less through the same gloom their own
## sky is drawn in, and no hour of the evening is a step any more.
static func nightfall(hour: float) -> float:
	return Weather.night_fall(hour)


## 0, 1 or 2: load at or over a creel (40), two creels.
static func laden_tier(carried: float) -> int:
	if carried >= 80.0:
		return 2
	if carried >= 40.0:
		return 1
	return 0


## Wearing a piece of salvage kit for `slot`. A bag that keeps one worn piece
## (`worn`, the survival package's) is asked for that; a bag without one counts
## any carried piece, so kit works before and after the two are merged.
static func wears(inv: Inventory, slot: StringName) -> bool:
	return inv != null and inv.wears(slot)
	if &"worn" in inv:
		var worn: StringName = inv.get(&"worn")
		return worn != &"" and Items.def(worn).get("kit", &"") == slot
	for id: StringName in inv.items:
		if Items.def(id).get("kit", &"") == slot:
			return true
	return false


## Wear a tool by `uses` through Inventory.wear (survival's edge rules, which
## also remember the one notice). True the time the edge goes dull.
static func wear(inv: Inventory, id: StringName, uses: int) -> bool:
	if inv == null or id == &"" or not inv.has(id):
		return false
	return inv.wear(id, uses)


## Spend a found weapon's charges from the bag. False (and nothing spent) when there are too few.
static func spend_charges(inv: Inventory, wick: int) -> bool:
	if wick <= 0:
		return true
	if inv == null or not inv.has(CHARGE, wick):
		return false
	return inv.remove(CHARGE, wick)
