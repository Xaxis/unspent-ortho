class_name BiomeForms
extends RefCounted
## What a landscape's people BUILT: which shapes their buildings take, and how
## those buildings stand relative to each other and to the square.
##
## `BiomeDressing` let a landscape say what its things are MADE of. It could not
## say what SHAPE they are: `Houses.VARIANTS` was a fixed pack of eight coastal
## shapes and `GenScatter.HOUSE_MODELS` was that same eight written down a second
## time, so a landscape dressed head to foot in its own materials still raised a
## fishing village's silhouette. That is what blocks every urban landscape.
##
## It is declared as `BiomeDef.built`, and a landscape only writes down what it
## ARGUES WITH. `BiomeForms.of(index)` is the one door.
##
## THE FORM TABLE LIVES IN CORE ON PURPOSE. `HOUSE_MODELS`/`HOUSE_NEON` were
## duplicated into world gen because world gen holds no rendering and could not
## read `src/models/props/`; a test held the two copies equal. `FORMS` holds no
## geometry — a name, how much ground the thing stands on, how far up it goes,
## and whether somebody wired a machine's light into it — so world gen reads it
## directly and there is no second copy to drift. The geometry stays where it
## was, keyed by the same form id, and `tests/biome/test_forms.gd` fails if a
## form in the table has no builder or a builder has no row.
##
## What is deliberately NOT here: how many buildings a settlement has. That is
## the STOCK's own size — a settlement deals one form to each building so no two
## in it share a silhouette, so a landscape with six forms has at most six
## buildings, and a landscape that wanted more would be asking to repeat one.

## How much ground a building of this form stands on, in tiles: its collision
## radius, and what world gen keeps clear round it. A coastal house is 1.6.
const REACH := &"reach"
## How far up it goes, in world units, at the top of its highest part. Nothing
## reads this to draw — the model decides that — but a shadow, a fore-piece and
## a sight line all want to know before the model is built.
const HIGH := &"high"
## Somebody wired a machine's light into this one. World gen deals a lit form
## nearest the square, where a player standing in it is looking; the LIGHT never
## reads this (it asks `PropModels.neon_point` where the tube actually is).
const LIT := &"lit"

## Every building form there is. A landscape's `stock` names rows here.
##
## The first eight are the coastal fishing village this game was built round,
## in the order `Houses.build` dealt them as bare numbers, so every seed's
## village is the village it was. The rest are the mega city's: a landscape
## whose people build upward.
const FORMS := {
	# --- the open country: one storey, a hearth, a roof somebody re-laid -------
	&"washed": {REACH: 1.6, HIGH: 2.6, LIT: false},
	&"slated": {REACH: 1.6, HIGH: 2.5, LIT: true},
	&"long": {REACH: 1.6, HIGH: 2.3, LIT: false},
	&"but": {REACH: 1.6, HIGH: 2.1, LIT: false},
	&"cot": {REACH: 1.6, HIGH: 2.0, LIT: true},
	&"narrow": {REACH: 1.6, HIGH: 2.1, LIT: false},
	&"steading": {REACH: 1.6, HIGH: 2.8, LIT: false},
	&"half": {REACH: 1.6, HIGH: 2.2, LIT: false},
	# --- the city: storeys stacked, a frontage, somebody's sign burning -------
	&"tower": {REACH: 2.1, HIGH: 14.3, LIT: true},
	&"stack": {REACH: 2.0, HIGH: 10.6, LIT: true},
	&"block": {REACH: 2.4, HIGH: 4.6, LIT: true},
	&"shell": {REACH: 2.0, HIGH: 4.6, LIT: false},
	&"arcade": {REACH: 2.3, HIGH: 4.8, LIT: true},
	&"spire": {REACH: 1.7, HIGH: 16.3, LIT: true},
	# --- the crags: what was standing before the machines, lived in -----------
	# Few people and old ones (docs/LANDSCAPES.md §1 PEOPLE): a dry-stone round
	# under a conical turf-and-thatch roof, a timber lean-to built into a broken
	# tower's wall, and a byre sunk into the slope. None of them wired a
	# machine's light in: it is the one village with no stolen neon.
	&"roundhouse": {REACH: 1.9, HIGH: 3.0, LIT: false},
	&"lean_to_broch": {REACH: 2.1, HIGH: 2.8, LIT: false},
	&"byre": {REACH: 1.9, HIGH: 2.2, LIT: false},
	# --- the dead city: what people build INSIDE what fell (docs/LANDSCAPES.md
	# §4; src/models/props/metropolis.gd). A ground floor walled in with salvaged
	# doors inside a dead tower's frame, a shack on a fallen deck, rooms hung
	# inside a lift core with a rope ladder up it, shop fronts re-shuttered as
	# homes. Two carry a stolen tube: the infill and the loft.
	&"infill": {REACH: 2.2, HIGH: 4.0, LIT: true},
	&"deck_house": {REACH: 2.0, HIGH: 3.4, LIT: false},
	&"shaft_loft": {REACH: 1.6, HIGH: 6.5, LIT: true},
	&"stall_row": {REACH: 2.4, HIGH: 3.0, LIT: false},
}

## The stock a landscape that argues with nothing builds: the fishing village,
## dressed by `BiomeDressing` in whatever that landscape is made of. It is not
## "the coast's" — a bog builds these shapes out of bog timber and black slate —
## but it IS one storey and a hearth, which is the thing an urban landscape has
## to be able to argue with.
const PLAIN: Array[StringName] = [&"washed", &"slated", &"long", &"but", &"cot", &"narrow", &"steading", &"half"]
## The city's: a stock that stands up rather than out.
const RAISED: Array[StringName] = [&"tower", &"stack", &"block", &"shell", &"arcade", &"spire"]

## The most forms one landscape's settlement may deal. It is the model cache's
## key packing that sets the ceiling (`PropModels.MAX_VARIANTS`: a form past it
## collides with the next prop kind's first model and silently draws that), and
## core may not read a renderer, so the number is named here and
## `tests/biome/test_forms.gd` fails if the two ever disagree.
const MOST := 16

## How buildings stand.
##   &"ring"  detached, scattered round a square, each turned to face it. A place
##            people walked out from: every building has ground on all four sides.
##   &"row"   a frontage — two lines either side of a street running through the
##            square, each building square to the line and its neighbours hard up
##            against it. A place people walk THROUGH.
const PLANS: Array[StringName] = [&"ring", &"row", &"block"]

## How far the nearest building stands off the square's middle, in tiles, when a
## landscape does not argue. The ring's number is the one every seed's village
## was laid at.
const RING_APART := 5.8
const ROW_APART := 3.6
## How much room a plan keeps round each building whatever its form wants. A ring
## village stands its houses well apart; a frontage stands them shoulder to
## shoulder and lets the forms' own reach be the whole of the spacing.
const RING_ROOM := 2.0
const ROW_ROOM := 0.0

# --- what a landscape declares -------------------------------------------------

## The building forms a settlement here is built of, one dealt to each building.
var stock: Array[StringName] = []
## How they stand (`PLANS`).
var plan: StringName = &""
## How far the nearest one stands off the middle, in tiles. 0 takes the plan's.
var apart := 0.0
## How many buildings a settlement here raises, as (least, most). `Vector2i()`
## takes the STOCK's own size, which is what every landscape did before a city
## existed and is still right for a village.
##
## THE STOCK'S SIZE WAS THE COUNT, AND THAT WAS EXACTLY RIGHT UNTIL A CITY ASKED.
## One form dealt to each building so no two in a settlement share a silhouette
## is a good rule and it stays; what it cannot survive is being the ANSWER to a
## different question. Six forms meant six buildings, so the most a landscape
## could raise was however many shapes somebody had modelled -- and a metropolis
## is not a village with more shapes, it is the same shapes many times over.
var buildings := Vector2i(0, 0)
## How far apart two buildings of the SAME form must stand, in tiles. 0 is the
## old rule: never repeat, so a settlement can be no bigger than its stock.
##
## A real city repeats itself and it is not a defect: what the no-repeat rule was
## protecting against is two identical silhouettes SIDE BY SIDE, which reads as a
## stamp. Stated as a distance, the protection survives and the city is possible.
var repeat_apart := 0.0


## The declared fields, in the order `WorldStamp` spells them.
##
## Written out by hand rather than read off `get_property_list()`, which is what
## it was. The order of that list is the engine's to decide and nothing promises
## it survives an export — and if it does not, the SAME landscape stamps
## differently in the desktop build and the web one, so a save made in either is
## refused by name in the other. There is no way to notice that from the editor.
## The cost of writing it down is that a field added here and not added below is
## silently outside the stamp; `tests/biome/test_forms.gd` fails on exactly that,
## so the boring version cannot drift either way.
func stamped() -> PackedStringArray:
	return PackedStringArray(["stock", "plan", "apart", "buildings", "repeat_apart"])


# --- the one door ---------------------------------------------------------------

static var _rows: Array[BiomeForms] = []


## The resolved built forms of landscape index `c`. Built once per registry;
## read from world gen and from the chunk workers, so it holds nothing but names.
static func of(c: int) -> BiomeForms:
	var rows := _rows
	if rows.size() != BiomeRegistry.count():
		rows = _build()
	return rows[clampi(c, 0, rows.size() - 1)]


static func _build() -> Array[BiomeForms]:
	var out: Array[BiomeForms] = []
	for d: BiomeDef in BiomeRegistry.all():
		out.append(resolve(d))
	# Assigned whole, as BiomeDressing's is: a worker reading this while another
	# builds it sees either the old array or the new one, never a half-filled one.
	_rows = out
	return out


## One landscape's built forms, declared and derived. Public so a test can ask
## what a landscape that declares nothing builds.
static func resolve(d: BiomeDef) -> BiomeForms:
	var r := BiomeForms.new()
	var s: BiomeForms = d.built if d.built != null else BiomeForms.new()
	r.stock = s.stock.duplicate() if not s.stock.is_empty() else PLAIN.duplicate()
	r.plan = s.plan if s.plan != &"" else &"ring"
	if s.apart > 0.0:
		r.apart = s.apart
	else:
		r.apart = ROW_APART if r.plan == &"row" else RING_APART
	r.buildings = s.buildings
	r.repeat_apart = s.repeat_apart
	return r


## How many buildings this settlement raises, as (least, most), resolved. A
## landscape that says nothing gets the stock's own size, which is the rule every
## village in this game was laid by.
func how_many() -> Vector2i:
	if buildings.x > 0 and buildings.y >= buildings.x:
		return buildings
	var most := stock.size()
	return Vector2i(mini(5, most), mini(8, most))


## May this settlement deal one form to two buildings? Only if it said how far
## apart they have to stand.
func repeats() -> bool:
	return repeat_apart > 0.0


## How many parallel streets this settlement is laid on. One for everything that
## is not a `block`, which is what makes `row` and `ring` come out exactly as they
## did. A block plan takes as many as its building count needs, because a city
## with thirty buildings on one street is a ribbon and not a city.
func lanes() -> int:
	if plan != &"block":
		return 1
	return clampi(ceili(float(how_many().y) / float(PER_LANE)), 2, MOST_LANES)


## Tiles between the middles of two streets. Wide enough that the frontages
## backing onto each other do not touch: a street's own half width each side,
## plus a building's width each side, plus a yard between the backs.
func block_deep() -> float:
	return widest() * 4.0 + STREET_WIDE * 2.0 + BACKS


## Spots a single street offers: four to a rank (two sides, two ways) over the
## ranks a frontage runs (`GenScatter.ROW_RANKS` + the one at the junction).
const PER_LANE := 16
## No more streets than a player can hold as one place. Past this a settlement is
## not a city, it is the whole island built over, and the region is the unit that
## is supposed to say that.
const MOST_LANES := 5
## Half a street's width in tiles, duplicated from `GenScatter.ROW_STREET` because
## core holds no world gen; `tests/biome/test_forms.gd` fails if the two drift.
const STREET_WIDE := 2.6
## The yard between two frontages that back onto each other.
const BACKS := 1.6


# --- the questions world gen and the model builders ask --------------------------

## The form the `v`th building of this landscape's settlement takes.
func form(v: int) -> StringName:
	if stock.is_empty():
		return PLAIN[0]
	return stock[posmod(v, stock.size())]


## One fact about that form.
func fact(v: int, key: StringName, fallback: float) -> float:
	var row: Variant = FORMS.get(form(v))
	if row == null:
		return fallback
	return float((row as Dictionary).get(key, fallback))


## The tallest thing this landscape's people build, in world units.
##
## Asked by anything that has to CLEAR a building rather than place one — the
## camera's near focus is the first, because "how tall may a thing be and stay
## sharp" was a constant fitted to the one-storey stock (2.8 at the most) and the
## city put a 16.3 spire in front of it. A number like that belongs to the stock
## that decides it, so a landscape added later cannot silently breach a rule
## nobody thought to restate.
func tallest() -> float:
	var most := 0.0
	for f: StringName in (stock if not stock.is_empty() else PLAIN):
		var row: Variant = FORMS.get(f)
		if row != null:
			most = maxf(most, float((row as Dictionary).get(HIGH, 0.0)))
	return most


## How much ground the `v`th building stands on, in tiles.
func reach(v: int) -> float:
	return fact(v, REACH, PropKind.SOLID[PropKind.HOUSE])


## The widest of them, which is what a settlement here has to be laid out for.
## Known before a single building is placed, unlike any one building's form:
## world gen places first and deals afterwards, so that the lit one comes out
## nearest the square.
func widest() -> float:
	var out := 0.0
	for i in stock.size():
		out = maxf(out, reach(i))
	return out


## How much room this plan keeps round each building, whatever the forms want.
func room() -> float:
	return maxf(ROW_ROOM if plan == &"row" else RING_ROOM, widest())


## Which of this landscape's forms wired a machine's light in, as indices into
## the stock — the one door world gen and the lights both read, in place of the
## two hand-written lists that used to say [1, 4] in two files.
func lit() -> Array[int]:
	var out: Array[int] = []
	for i in stock.size():
		if fact(i, LIT, 0.0) > 0.0:
			out.append(i)
	return out


## Its people build upward: something in the stock stands more than two storeys.
## What decides whether a settlement here is walked round or walked through.
func raised() -> bool:
	for i in stock.size():
		if fact(i, HIGH, 0.0) > 4.0:
			return true
	return false


# --- what a landscape got wrong --------------------------------------------------

## Problems with one landscape's declared forms, as lines for
## `BiomeRegistry.problems()`. A form nobody models and a plan nobody lays are
## both silent otherwise: the settlement goes up, in somebody else's shapes.
static func problems(d: BiomeDef) -> PackedStringArray:
	var out := PackedStringArray()
	var w := "biome %s: " % d.id
	var s := d.built
	if s == null:
		return out
	for f: StringName in s.stock:
		if not FORMS.has(f):
			out.append(w + "nobody builds a %s" % f)
	if s.stock.size() > MOST:
		out.append(w + "builds %d forms, which is more than the model cache can tell apart (%d)" % [s.stock.size(), MOST])
	var seen := {}
	for f: StringName in s.stock:
		if seen.has(f):
			out.append(w + "deals %s twice, so two of its buildings share a silhouette" % f)
		seen[f] = true
	if s.stock.size() == 1:
		out.append(w + "builds one form, so every building in it is the same building")
	if s.plan != &"" and not PLANS.has(s.plan):
		out.append(w + "lays its settlement out as a %s, which is no plan" % s.plan)
	if s.apart < 0.0:
		out.append(w + "stands its buildings %.1f tiles off the square" % s.apart)
	return out
