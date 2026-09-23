class_name CraftTiers
## How hard a thing is to make, and where (docs/VISION.md: "Craft difficulty
## matches the ladder"). A recipe names a station; the station is the difficulty.
##
##   0 hand    your two hands, anywhere
##   1 fire    the forge: heat, and something to quench in
##   2 bench   the bench: a vice, a drill, a straight edge
##   3 kiln    the furnace: hours at a heat you cannot hold by hand
##   4 jig     the machines' own shop, carried — a bench with a FOUND jig kept in
##             hand (`JIG_TOOL`, cut off a hunter). Nothing a person built reaches
##             this rung; you have to take it off them.
##
## The top two rungs can go wrong, which is the other half of difficulty: a
## prime piece is not only dear, it is a risk. What goes wrong is declared here
## and rolled DETERMINISTICALLY off the world seed and a count the save keeps, so
## a player cannot reload to reroll a bad pour.
##
## The wheel and the loom are a house's, not a ladder rung: they sit at the
## bench's difficulty because that is the work they are.

enum { HAND, FIRE, BENCH, KILN, JIG }

const NAMES: Array[StringName] = [&"hand", &"fire", &"bench", &"kiln", &"jig"]
## What a player is told the rung is.
const WORDS: Array[String] = ["by hand", "at a fire", "at a bench", "in a kiln",
	"at a bench, on their own jig"]
## The station each rung is worked at (the jig is worked at a bench).
const AT: Array[StringName] = [&"hand", &"fire", &"bench", &"kiln", &"bench"]
## The found tool the top rung is kept honest by: carried, never consumed.
const JIG_TOOL: StringName = &"fab_jig"
## Goes a recipe takes at each rung: what the slate says about the work, and the
## reason a relic is an afternoon and a haft is not.
const STEPS: Array[int] = [1, 2, 3, 4, 5]

## From this rung up, a pour can go wrong.
const RISK_FROM := KILN
## The odds of it going wrong, by rung.
const SPOIL: Array[float] = [0.0, 0.0, 0.0, 0.12, 0.2]
## What comes back when it does: the work is lost, the stock is not wholly lost.
const SPOIL_ITEM: StringName = &"spoil"
## Half the time a risky craft goes wrong it comes out FLAWED instead of ruined:
## the thing works, with one socket fewer. Only a piece that declares a flawed
## twin can come out that way (`GearTree`); anything else is simply spoiled.
const FLAWED_SHARE := 0.5


static func name_of(tier: int) -> StringName:
	return NAMES[clampi(tier, 0, NAMES.size() - 1)]


static func words(tier: int) -> String:
	return WORDS[clampi(tier, 0, WORDS.size() - 1)]


static func steps(tier: int) -> int:
	return STEPS[clampi(tier, 0, STEPS.size() - 1)]


## The rung a recipe sits on. A bench recipe that keeps the jig is the top rung.
static func of_recipe(r: Dictionary) -> int:
	var at := StringName(r.get("at", &"hand"))
	if at == &"bench" and (r.get("keeps", {}) as Dictionary).has(JIG_TOOL):
		return JIG
	match at:
		&"hand": return HAND
		&"fire": return FIRE
		&"kiln": return KILN
	# The wheel and the loom are a house's bench.
	return BENCH


static func risky(tier: int) -> bool:
	return tier >= RISK_FROM


static func spoil_chance(tier: int) -> float:
	return SPOIL[clampi(tier, 0, SPOIL.size() - 1)]


## How a pour came out: &"made", &"flawed" (the piece, one socket short) or
## &"spoiled" (the work lost, the stock back as SPOIL_ITEM). `n` counts the
## player's risky crafts, so the same seed and the same count always agree.
static func outcome(tier: int, has_flawed_twin: bool, seed_value: int, n: int) -> StringName:
	if not risky(tier):
		return &"made"
	if Rng.hash01(seed_value, n, 0x51A6) >= spoil_chance(tier):
		return &"made"
	if has_flawed_twin and Rng.hash01(seed_value, n, 0x51A7) < FLAWED_SHARE:
		return &"flawed"
	return &"spoiled"


## The line said when it goes wrong, so a player learns the rung has teeth.
static func said(outcome_id: StringName, what: String) -> String:
	match outcome_id:
		&"flawed": return "The %s came out flawed. It will work." % what
		&"spoiled": return "The %s came out wrong. What is left is scrap." % what
	return ""
