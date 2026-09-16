class_name Blow
extends RefCounted
## One kind of blow: a held tool's swing, fists, or a machine's bite. Timings in
## milliseconds; distances in tiles. The box it sweeps starts at the owner's
## centre and runs `radius + reach` forward along the locked facing, `width`
## across (design-extract §7.2).
##
## Windows, from the moment it was thrown (`at`):
##   [0, windup)                         windup   (the tell)
##   [windup, windup + active)           active   (the box is live)
##   [.., + recovery)                    recovery (committed, no box)
##   [.., + cooldown)                    cooldown (free to move, not to swing)

var windup := 70
var active := 80
var recovery := 110
var cooldown := 180
var reach := 0.6
var width := 0.8
var dmg := 1
## Knockback speed in tiles/s, decaying linearly to 0 over knock_ms; also stuns for knock_ms.
var knock := 2.5
var knock_ms := 120
## Movement multiplier while committed (windup + active + recovery).
var creep := 0.35
## >0: a seizing bite. Sets the target's grip to this many pulls, does no damage.
var grip := 0
## Reaches past plate (a found edge). No made tool has it.
var cuts := false
## The work verb of the tool that threw it (&"cut" pulls twice against a grip).
var verb: StringName = &""
## Wind a swing of this blow costs: 120 + 60 x bulk (design-extract §6.4).
var wind_cost := 180.0
## A found weapon's charges spent per swing (0 = made, spends nothing).
var wick := 0


func committed() -> int:
	return windup + active + recovery


func lockout() -> int:
	return windup + active + recovery + cooldown


## &"windup" &"active" &"recovery" &"cooldown" or &"" (over) for `elapsed` ms since thrown.
func phase(elapsed: float) -> StringName:
	if elapsed < 0.0:
		return &""
	if elapsed < windup:
		return &"windup"
	if elapsed < windup + active:
		return &"active"
	if elapsed < committed():
		return &"recovery"
	if elapsed < lockout():
		return &"cooldown"
	return &""


## True when the live window [at + windup, at + windup + active) overlaps the slice [t0, t1).
func live_in(at: float, t0: float, t1: float) -> bool:
	var a := at + windup
	var b := a + active
	return a < t1 and t0 < b


## From an item-style dict: {swing: [w, a, r, c], reach, width, dmg, knock, knock_ms, creep, grip, cuts}.
static func from_dict(d: Dictionary) -> Blow:
	var b := Blow.new()
	var sw: Array = d.get("swing", [])
	if sw.size() == 4:
		b.windup = int(sw[0])
		b.active = int(sw[1])
		b.recovery = int(sw[2])
		b.cooldown = int(sw[3])
	b.reach = float(d.get("reach", b.reach))
	b.width = float(d.get("width", b.width))
	b.dmg = int(d.get("dmg", b.dmg))
	b.knock = float(d.get("knock", b.knock))
	b.knock_ms = int(d.get("knock_ms", b.knock_ms))
	b.creep = float(d.get("creep", b.creep))
	b.grip = int(d.get("grip", 0))
	b.cuts = bool(d.get("cuts", false))
	return b


## Bare hands: 70/80/110/180 ms, reach 0.6, width 0.8, dmg 1, knock 2.5 for 120 ms, creep 0.35.
static func fists() -> Blow:
	var b := Blow.new()
	b.verb = &""
	b.wind_cost = 120.0
	return b


## The blow of whatever is held. A tool with no swing stats swings like fists
## but with its own bulk. Damage blends toward bare hands as the edge wears:
## max(1, 1 + (dmg - 1) x edge / 10000), whole points.
static func for_item(id: StringName, edge: int = 10000) -> Blow:
	if id == &"":
		return fists()
	var d := Items.def(id)
	var b := from_dict(d) if d.has("swing") else fists()
	b.verb = d.get("verb", &"")
	var bulk: float = d.get("bulk", 1.0)
	b.wind_cost = 120.0 + 60.0 * bulk
	b.wick = int(d.get("wick", 0))
	# A found weapon has no edge to lose: it is charged or it is dry.
	b.dmg = int(d.get("dmg", 1)) if b.wick > 0 else FightRules.damage_at_edge(int(d.get("dmg", 1)), edge)
	return b


func copy() -> Blow:
	var b := Blow.new()
	for p: String in ["windup", "active", "recovery", "cooldown", "reach", "width", "dmg", "knock", "knock_ms",
			"creep", "grip", "cuts", "verb", "wind_cost", "wick"]:
		b.set(p, get(p))
	return b


## The same blow thrown with too few charges: it still swings, and does what a fist does.
func dry() -> void:
	dmg = 1
	cuts = false
