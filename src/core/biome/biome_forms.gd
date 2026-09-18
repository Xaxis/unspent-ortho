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
	&"tower": {REACH: 2.1, HIGH: 7.4, LIT: true},
	&"stack": {REACH: 2.0, HIGH: 6.1, LIT: false},
	&"block": {REACH: 2.4, HIGH: 4.6, LIT: true},
	&"shell": {REACH: 2.0, HIGH: 4.6, LIT: false},
	&"arcade": {REACH: 2.3, HIGH: 4.8, LIT: false},
	&"spire": {REACH: 1.7, HIGH: 9.6, LIT: false},
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
const PLANS: Array[StringName] = [&"ring", &"row"]

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
	return r


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
