extends GameSystem
## Night lights: village lamps, the windows of houses, fires, vents and kilns,
## and the player's lantern (the `lamp` action). docs/LOOK.md section 6: lamp and
## fire light ERASE THE HATCHING in their pool; light means safety, and the page
## shows it.
##
## A pool of at most SkyLight.MAX_LAMPS OmniLight3Ds follows the camera and is
## handed to the nearest lit sources (Compatibility draws each light as another
## pass, so the pool is the budget). The same positions and ranges go to the sky
## (SkyLight.lamps -> sky_lamps), so world.gdshader lifts the ink exactly where
## the warm light lands; sky_pool() cuts both into two hard steps with a
## stippled rim.
##
## Lit windows are small flat unshaded panes; flames get a few radiating ink
## strokes (rays.gdshader). Only things that burn give light; nobody glows.
##
## The glint list (Glints): every light near the camera, pooled or not, goes to
## the sky as a point to mirror in wet ground and to throw shafts into fog: lamps,
## fires, hearths, stolen neon, pylon beacons, machine lenses, the lantern.
## Machine light (beacons, neon on the machines' power, lenses) stutters with the
## sky's power after lightning (SkyLight.bolt.w).
##
## A LIVE MACHINE gets a pool too, and takes it from the same budget as a lamp:
## it was in the glint list alone, which only mirrors in WET ground, so a watcher
## at 23:00 with its optic burning left the ground under it exactly as dark as
## ten tiles away while a villager's lamp laid sixty pixels of light (art review,
## wave A finding 6). Its pool is COLD — the machines' own strip colour, the same
## one an intake or a checkpoint throws — and small, and it stutters on the
## machines' power: nothing about a machine's light means safety.

const RAYS := preload("res://src/render/weather/rays.gdshader")
## The machines' own light, written once (props/works.gd): a mast's cap, the pool
## it throws, its glint in wet ground and its shaft in fog are the same colour.
const Works := preload("res://src/models/props/works.gd")
## Tiles from the focus within which a source may take a light or show a glow.
const REACH := 17.0
const GLOW_REACH := 24.0
## What a surface looks like at the centre of a pool, as a display multiply on
## its albedo: lamplight is an ochre wash, dimmer than day. Divided by the
## sky's tint at runtime, so it stays warm under a blue night.
const WARM := Vector3(0.96, 0.74, 0.53)
const FIRE_WARM := Vector3(0.92, 0.58, 0.32)
## A house's door and window: hearth light, between a lamp and an open fire.
const HEARTH_WARM := Vector3(0.95, 0.66, 0.42)
const VENT_WARM := Vector3(0.80, 0.42, 0.24)
## What the ground round a vent looks like in FULL DAYLIGHT: over 1, because the
## crust round a hole into fire is brighter than the daylight beside it and a
## target under the sun asks for no light at all (burning_warm).
const VENT_DAY_WARM := Vector3(1.16, 1.05, 0.86)
## And how much of its reach it keeps in full daylight. By day the glow only
## beats the sun on the crust round the mouth; opened to its night radius it is
## a pale disc a dozen tiles across lying over the land, which is fog, not fire.
const VENT_DAY_REACH := 0.45
## The lantern is a hand light: a small pool, a little dimmer than a lamp.
## compensate() never divides by a sky tint channel darker than this.
const TINT_FLOOR := 0.45
## How steeply a pool falls off. Not the inverse square a real point source
## obeys: at that exponent a lamp is a hot spot with nothing round it, and what
## a lantern is FOR is the few tiles round your feet.
const ATTENUATION := 1.45

## --- A FLAME IS NOT A POINT ---------------------------------------------
##
## Two things were wrong with firelight and they have the same cause: a fire
## was being lit like a bulb.
##
## 1. It cast. A point light at the middle of a burning stack throws a hard
##    shadow of every stick in it, and the fire in the canon's night village
##    sat in a STARBURST of radial spokes across the gravel. Real firelight has
##    no crisp shadow of its own fuel, because the flame is bigger than the
##    fuel and comes from all round it. So a flame lights and casts nothing,
##    and the shadows in a camp are thrown by the lamps on the posts and by the
##    lantern in your hand -- which is also where the player is looking.
## 2. It ended. `omni_range` 3.2 put a visible boundary on the gravel where the
##    pool stopped. A flame's reach is much longer and its falloff much
##    steeper, so the core is the same size and the tail dies away with no edge
##    anywhere for the eye to find.
const FLAME_KINDS: Array[int] = [PropKind.FIRE, PropKind.KILN, PropKind.VENT, PropKind.HOUSE]
const FLAME_REACH := 1.9
const FLAME_ATTEN := 2.4


static func is_flame(kind: int) -> bool:
	return FLAME_KINDS.has(kind)
## What a light's level is worth in linear light (see _set_light).
const GAIN := 5.2
const LANTERN_RANGE := 3.2
## The colour each kind of light throws (pools and wet reflections). People's
## lamps, windows and fires are warm, and so is the flame in the player's
## salvaged lantern: the pool it lays is the colour of its own light and never a
## cold disc over a warm one (docs/LOOK.md section 6). Stolen neon belongs to the
## houses that wired it in (a few, not all).
const LANTERN_WARM := Vector3(1.0, 0.74, 0.46)
const NEON_SODIUM := Vector3(1.0, 0.52, 0.16)
const NEON_CYAN := Vector3(0.25, 0.95, 1.0)
const NEON_MAGENTA := Vector3(1.0, 0.25, 0.8)
const NEON_FIRE := Vector3(1.0, 0.45, 0.12)
const LANTERN_POWER := 0.8
## Where the lantern's light sits in the player's frame (+X ahead, +Z to the
## right): above and ahead of the hand that carries it, outside the body, so
## the figure's own faces turn toward it instead of all away.
const LANTERN_LIGHT := Vector3(0.42, 1.05, 0.44)

## Per source kind: [omni range in tiles, power, height of the light above the
## prop's foot]. The clean core of the pool on the ground is where attenuation
## >= POOL_CORE, about 0.66 of the range from the light; the ring reaches 0.79.
const SOURCES := {
	PropKind.LAMP: [3.8, 1.0, 1.7],
	PropKind.HOUSE: [2.3, 0.75, 0.9],
	PropKind.FIRE: [3.2, 0.9, 0.5],
	PropKind.VENT: [2.6, 0.6, 0.7],
	PropKind.KILN: [2.4, 0.55, 0.6],
	# The land's lights (landscape: props/remains.gd, props/works.gd), where their
	# models say they are (PropModels.glow_points by variant and country): the
	# stolen neon a shack wired in, a lookout's lamp, and the machines' cold
	# strips and flood, which run on the machines' power.
	PropKind.SHACK: [2.4, 0.6, 0.9],
	PropKind.FIRE_TOWER: [7.5, 0.55, 4.7],
	PropKind.INTAKE: [2.6, 0.45, 1.0],
	PropKind.PUMP_HOUSE: [2.4, 0.45, 1.0],
	PropKind.CHECKPOINT: [5.2, 0.8, 2.9],
	# The Slums' signage (props/signage.gd). A MURAL lights ONLY on the variants
	# that had a hoarding bolted over the painting: the bare ones return no glow
	# point at all and `PLACED_SOURCES` drops them, which is the whole difference
	# between paint and projection stated once and nowhere else. The sign itself
	# is `Towers.billboard`, hung on a wall like every other sign in the city.
	# THE HEIGHT HERE MUST MATCH WHERE THE MODEL'S NEON ACTUALLY IS. A PLACED
	# source takes its position from `PropModels.glow_points`, which reads the
	# hoarding's own geometry; this column is what `tests/sky/test_lamp_pools.gd`
	# measures the pool against. Let the two drift and the pool is tested at a
	# height the game never uses.
	#
	# And the pair has to make a pool at all. An earlier sign stood at 9.0 with a
	# reach of 9.0, and `pool_radius` answered exactly 0.0: an omni whose reach is
	# its own height lands NOTHING on the ground beneath it, so the brightest
	# thing in the landscape lit the street not at all while burning on its own
	# face. 2.7 against 5.0 puts a 1.88-tile core under the sign.
	PropKind.MURAL: [5.0, 0.7, 2.7],
}
## Sources whose light is the machines' own (cold, and the machines' colour).
const MACHINE_SOURCES: Array[int] = [PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.CHECKPOINT]
## Sources whose POOL runs on the machines' power, so a strike stutters it. A
## hearth, a lamp and a fire are nobody's grid and never stutter.
##
## The neon a shack stole off a machine is on this list: the tube itself is a
## `GroundColors.NEON` mark, which world.gdshader multiplies by `sky_power()`,
## so the tube, its pool, its glint in wet ground and its shafts in fog all
## stutter together. A hearth or a window in the same wall keeps burning.
##
## The Slums' signage is on this list because found.gdshader multiplies its
## emissive face by `sky_power()` whatever this array says: leaving the POOL out
## would stutter the panel and not the street under it, which is worse than
## either choice made whole.
const POWERED_SOURCES: Array[int] = [PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.CHECKPOINT, PropKind.SHACK,
	PropKind.MURAL]
## Sources placed at their model's own glow point, lit only on the variants that have one.
const PLACED_SOURCES: Array[int] = [PropKind.SHACK, PropKind.FIRE_TOWER, PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.CHECKPOINT,
	PropKind.MURAL]
## The machines' cold strip light, for a pool and a glint. It is the SAME light
## as the strip on the machine that casts it (`Works.STRIP`), so the pool on the
## ground and the geometry throwing it can never disagree: this was an inlined
## saturated cyan and it made an intake the loudest thing in a village at night.
static var MACHINE_COLD := Works.light(Works.STRIP)

var lights: Array[OmniLight3D] = []
## One entry per light-giving prop: {prop, at: Vector3, range, power, warm, kind, h, h2}.
var sources: Array[Dictionary] = []
var lantern: Node3D
var lantern_light: OmniLight3D
## The one light that says what the hand can reach (see _light_the_reach).
var reach_light: OmniLight3D
var _reach_t := 0.0
var _indexed := 0
## Which cell of the world each indexed source sits in: cell key -> its places
## in `sources`. See `_near` for why this exists.
var _cells: Dictionary = {}
var _assigned: Array = [] # per pool light: source Dictionary or null
var _refresh := 0.0
var _glows: Dictionary = {} # prop id -> Node3D
## The world `sources` indexes, and every other world's index, kept by world.
var _indexed_world: WorldData = null
## LIGHTS ANOTHER SYSTEM OWNS AND THIS ONE BUDGETS: a room's window suns, its
## sky fills and its lanterns (21_doors). The lender aims them and sets their
## energy; this system decides which of them SHOW and which CAST, out of the same
## tier row as every lamp here (`Quality` `lamps` and `shadow_lights`), so one
## place enforces the budget however many packages make lights. A light's
## energy is its asking to be on; `rank` orders who is dropped first when the
## row runs out (lower goes first). {light, casts, rank}
var _lent: Array[Dictionary] = []
var _index_of: Dictionary = {}
var _glow_mat: StandardMaterial3D
var _time := 0.0
var _lamp_down := false
## Sources and machines near the camera that may glint, refreshed with the pool.
var _glint_near: Array[Dictionary] = []
## Live machines in pool reach, as sources: mob instance id -> source Dictionary.
var _machine_srcs: Dictionary = {}
var _machine_near: Array[Dictionary] = []
## What went to the sky last frame (Glints.pick output), for tests.
var glint_list: Array[Dictionary] = []
## A mast's beacon and a working part, as light. Both are read off props/works.gd
## so the cap, the pool it throws, the glint in wet ground and the fog shaft agree:
## the beacon used to be an inlined crimson-orange here while the geometry it came
## out of was already the dull violet of the machines' arc, and the light is what a
## player actually sees at two hundred tiles.
static var BEACON := Works.light(Works.BEACON)
static var LENS_GLINT := Works.light(Works.WORKING)
## How strongly each light throws shafts into fog (Glints `shaft`). A fire, whose
## strokes already flicker out of it, throws none; a lamp, a beacon or the
## lantern, which draw their own strokes, only a weak few; a window, a neon
## tube or a machine strip, which draw none, throw the most.
const SHAFT_RAYED := 0.3
const SHAFT_LENS := 0.5
const SHAFT_MACHINE := 0.8
## A live machine's own pool: the range in tiles and how hard it lays it. Small
## and weak beside a lamp (3.8, 1.0) — a machine is read by its lens, not by the
## ground it lights — but the ground under it can no longer be as dark as the
## ground ten tiles off.
const MACHINE_POOL := Vector2(2.6, 1.0)
## How much of its pool a VENT keeps in full daylight. A lamp keeps none — that
## rule is right and stays — but the Burning's vents are open fire in the ground
## and must reach the ground they are in at every hour (docs/LOOK.md).
const VENT_DAY := 1.5
## How far inside the frame a machine must stand for `await machine` to say the
## shot holds it: an eighth of the screen in from every edge. (The comment here
## said a fifth, for a number that has been 0.12 all along.)
const TOUR_MARGIN := 0.12
## Which buildings wired a machine's light in used to be written down twice — a
## bare [1, 4] here and the same [1, 4] in `GenScatter.HOUSE_NEON` — because
## world gen holds no rendering and could not read a model. It is one answer in
## core now, `BiomeForms.of(country).lit()`, which world gen reads directly and
## which is the landscape's OWN: a city's lit form is not a fishing village's.
## Nothing in this file ever read the list (the light asks the MODEL where its
## tube is, `PropModels.neon_point`), so it is simply gone.
## -1 not looked yet, 0 no, 1 yes: whether PropModels says where its lights are.


func setup(g: Game) -> void:
	super.setup(g)
	if g.options.lamp:
		g.body.lamp_lit = true
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.vertex_color_use_as_albedo = true
	# THE ONE COLOUR DOOR, for the one material in this package that is not a
	# shader and so cannot call `matter_albedo()`. The vertex colours here are
	# palette sRGB — the player's lantern, every lit window pane, every door slit
	# — and this flag was never set, so on Forward+ they went into a linear
	# ALBEDO raw and burned about a stop and a half bright and flat, while the web
	# build got them right. `unshaded` is not an exemption: render_probe.gd
	# measured the encode on an unshaded quad, which IS this case. Decided the
	# same way `sky_linear` is, because it is the same decision.
	_glow_mat.vertex_color_is_srgb = Quality.forward_plus()
	_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# HOW MANY LOCAL LIGHTS EXIST is the quality tier's business (`Quality.ROWS`
	# `lamps`), not the shader pool's. This built `SkyLight.MAX_LAMPS - 1` = seven
	# for the game's whole life, and MAX_LAMPS is 8 only because `sky_lamps` packs
	# into two mat4s for a pass LANTERN deleted. Every settlement has been over
	# that ceiling since before the rebuild -- eleven sources in a coast green,
	# eight in the city -- and it never showed where there is a sun.
	for i in Quality.lamp_count() - 1:
		lights.append(_new_light("lamp_%d" % i))
		_assigned.append(null)
	lantern_light = _new_light("lantern_light")
	reach_light = _new_light("reach_light")
	reach_light.omni_attenuation = 2.2
	reach_light.shadow_enabled = false
	lantern = _lantern_mesh()
	var lr := rays(Palette.COPPER[4], 2.0, 4.0, 0.15, 4.0)
	lr.position = Vector3(0, 0.08, 0)
	lantern.add_child(lr)
	add_child(lantern)
	_indexed_world = g.world
	_index_sources()
	_update(0.0, true)


## --- What the hand can reach --------------------------------------------
##
## "You can take this" said as LIGHT rather than as a mark on the glass, which
## is what the whole direction is for: in a world that is lit and not drawn, the
## right way to say a thing is workable is that the thing LIGHTS UP.
##
## The RULE is not reimplemented here and must not be. `Survival.use_target`
## says WHICH thing the `use` key would work right now, and
## `Survival.describe_target` says what it would do or why it would not; this
## only reads those two and decides what colour to put on the answer.
## (The state arrives as the tail of a sentence, which is the one thing here
## that ought to change: whoever owns `src/core/survival` should publish it as
## a value. Until then this reads the string the rule already publishes rather
## than working the state out again, which would be two rules.)
##
## Three states have to be told apart at a glance, at night, in weather:
const REACH_WORKABLE := Vector3(0.62, 0.86, 0.72)   ## a cool catch: take it
const REACH_NO_TOOL := Vector3(0.95, 0.52, 0.22)    ## warm and low: wrong hand
const REACH_SPENT := Vector3(0.34, 0.36, 0.44)      ## almost nothing: picked over
## How far it carries and how hard. Small on purpose: it is a CATCH on the thing
## in front of you, not a pool round it, so it never reads as a second lamp.
## The power is divided by GAIN because it goes out through _set_light like
## every other light and must NOT be one: at a lamp's gain it was a pale green
## aura round the player that was the brightest thing in the Burning at dusk.
const REACH_RANGE := 1.05
const REACH_POWER := 0.62 / GAIN
## Picked over is a hint that something WAS here, so it is barely lit at all.
const REACH_SPENT_POWER := 0.14 / GAIN
## It breathes, slowly, because a steady light on the ground is a lamp and a
## breathing one is an offer. A machine's light never does this (LOOK.md: the
## machines' light is exact and unwavering; a person's is unsteady) -- and this
## is the game speaking to the player, which is the one light that is neither.
const REACH_BREATH := 1.9


## Light whatever the `use` key would work right now, in the colour of what it
## would do. Nothing is lit when the key would do nothing.
func _light_the_reach(delta: float) -> void:
	if reach_light == null:
		return
	_reach_t += delta
	var t: WorldProp = Survival.use_target(game)
	if t == null or game.input_blocked():
		reach_light.visible = false
		return
	var said := Survival.describe_target(game)
	var rgb := REACH_WORKABLE
	var power := REACH_POWER
	if said.ends_with(" - picked over") or said.ends_with(" - under water"):
		rgb = REACH_SPENT
		power = REACH_SPENT_POWER
	elif said.ends_with(" - no tool") or said.ends_with(" - too hard"):
		rgb = REACH_NO_TOOL
	var breath := 0.82 + 0.18 * sin(_reach_t * REACH_BREATH)
	var at := game.world.to_3d(t.pos) + Vector3(0.0, 0.34 * maxf(t.scale, 0.5), 0.0)
	_set_light(reach_light, at, REACH_RANGE * maxf(t.scale, 0.7), rgb * power * breath)


func _new_light(n: String) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = n
	l.shadow_enabled = false
	l.shadow_bias = 0.035
	l.shadow_normal_bias = 1.1
	# It falls off the way light falls off. It used to have NO distance decay at
	# all -- a flat disc inside a hard range window, because sky_pool() cut it
	# into two steps afterwards anyway. There is no sky_pool any more; a lamp is
	# a lamp.
	l.omni_attenuation = ATTENUATION
	# A lamp has to be ABLE to glint. Specular was off, which is why wet ground
	# mirrored nothing and a machine's flank caught nothing: it was the one
	# thing standing between this game and a reflection.
	l.light_specular = 1.0
	# Water used to be cut out of every lamp's mask, because a lamp on water was
	# a flat glow disc and a glow disc on the sea is absurd. A lamp on water is
	# a STREAK now -- water is the smoothest thing in the world and the light is
	# in it, not on it -- so the sea takes lamplight like everything else, and a
	# fire on the shore is in the water in front of it.
	l.visible = false
	add_child(l)
	return l


## Put a light another system made under this system's budget (see `_lent`).
func lend(l: Light3D, casts: bool, rank: int) -> void:
	l.visible = false
	l.shadow_enabled = false
	_lent.append({"light": l, "casts": casts, "rank": rank})
	_lent.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.rank) > int(b.rank))


## Take a lent light back off the budget (its owner is about to free it).
func take_back(l: Light3D) -> void:
	for i in range(_lent.size() - 1, -1, -1):
		if _lent[i].light == l:
			_lent.remove_at(i)


## How many local lights are on now, this system's and lent ones together, and
## how many of them cast: what the tier row holds to (tests/render, tests/interior).
func local_lights_on() -> Vector2i:
	var on := 0
	var casting := 0
	var all: Array[Light3D] = []
	for l: OmniLight3D in lights:
		all.append(l)
	all.append(lantern_light)
	for d: Dictionary in _lent:
		all.append(d.light as Light3D)
	for l: Light3D in all:
		if l != null and is_instance_valid(l) and l.visible:
			on += 1
			if l.shadow_enabled:
				casting += 1
	return Vector2i(on, casting)


## Which lent lights show: those asking (energy over nothing), best rank first,
## as many as the row leaves after this system's own pool and the lantern.
func _show_lent() -> void:
	var room := Quality.lamp_count()
	for l: OmniLight3D in lights:
		if l.visible:
			room -= 1
	if lantern_light != null and lantern_light.visible:
		room -= 1
	for d: Dictionary in _lent:
		var l := d.light as Light3D
		if l == null or not is_instance_valid(l):
			continue
		var asks := l.light_energy > 0.01
		l.visible = asks and room > 0
		if l.visible:
			room -= 1


## Which of the live lights cast a shadow, nearest the player first.
##
## THE TIER DECIDES HOW MANY (`Quality.ROWS.shadow_lights`), and this system is
## its only enforcer -- 0 on the web means lamps and fires light and cast
## nothing, 16 on ultra means every one of them does. Nearest-first, because the
## shadow the player can see is the one at their feet, and a light whose shadow
## is turned off does not dim: it goes on lighting exactly as it did.
func _cast_shadows(focus: Vector3) -> void:
	var allow := int(Quality.current().get("shadow_lights", 0))
	var live: Array[Light3D] = []
	for i in lights.size():
		var l: OmniLight3D = lights[i]
		if not l.visible:
			continue
		# A FLAME CASTS NOTHING (see FLAME_KINDS). It is the biggest light in a
		# camp and the one the player looks at longest, and a point light in the
		# middle of a burning stack throws a hard shadow of every stick in it.
		var src: Variant = _assigned[i] if i < _assigned.size() else null
		if src != null and is_flame(int((src as Dictionary).get("kind", -1))):
			l.shadow_enabled = false
			continue
		live.append(l)
	if lantern_light != null and lantern_light.visible:
		# The player's own lantern casts first, whatever else is near: it is the
		# one light they carry, and its shadow is the one they are steering by.
		live.insert(0, lantern_light)
	# A lent light that asks to cast competes for the same allowance.
	for d: Dictionary in _lent:
		var ll := d.light as Light3D
		if ll == null or not is_instance_valid(ll) or not ll.visible:
			continue
		if bool(d.casts):
			live.append(ll)
		else:
			ll.shadow_enabled = false
	live.sort_custom(func(a: Light3D, b: Light3D) -> bool:
		return a.global_position.distance_squared_to(focus) < b.global_position.distance_squared_to(focus))
	for i in live.size():
		live[i].shadow_enabled = i < allow


func toggle_lantern() -> void:
	if not game.body.lamp_lit:
		# Settle the unlit time first: survival burns oil once a second from its
		# last settle, so a clock that jumped since (a tour's `hour`) would
		# otherwise drain the flask the moment the lamp is lit.
		Survival.burn_lamp(game)
	game.body.lamp_lit = not game.body.lamp_lit
	Events.sfx.emit(&"lamp_on" if game.body.lamp_lit else &"lamp_off", game.player.position)


func _process(delta: float) -> void:
	# Polled and edge-detected here, not taken as an input event: a key, a pad
	# and a tour's `tap lamp` all arrive this way, however short the press.
	var down := Input.is_action_pressed("lamp")
	if down and not _lamp_down and game != null and not game.input_blocked():
		toggle_lantern()
	_lamp_down = down
	_update(delta, false)
	_light_the_reach(delta)


## 0..1: how far people have lit up. Lamps go on before full dark and out after
## first light: up over 19:00-20:30, down over 05:00-06:30 — OR whenever there is
## a lid over the landscape, whatever the clock says.
##
## People light up because it is DARK, and until a landscape could have something
## between it and the sun that was the same thing as because it is LATE. It is
## not: under a smog dome the street never gets the sun, and read off the clock
## alone every lamp in a city went out at half past six in the morning and left
## it a flat brown murk until seven at night — measured on the slums, seed 7,
## where midnight was by a long way the better picture. The lid is
## `SkyLight.last_lid()` (`BiomeDef.sky_shut`), and it is taken as a floor rather
## than a replacement, so nothing about an open landscape's evening moves.
static func lamps_wanted(hour: float) -> float:
	return maxf(_lamps_by_clock(hour), SkyLight.last_lid())


static func _lamps_by_clock(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	if h >= 20.5 or h < 5.0:
		return 1.0
	if h >= 19.0:
		return smoothstep(19.0, 20.5, h)
	if h < 6.5:
		return 1.0 - smoothstep(5.0, 6.5, h)
	return 0.0


## 0..1 how much a pool of lamplight shows: nothing until dusk is well on,
## full from an hour after it.
static func pool_dark(hour: float) -> float:
	return clampf(Weather.night_fall(hour) * 1.4, 0.0, 1.0)


## How hard a thing that BURNS lights the ground, at darkness `dark` (0 noon, 1
## the dead of night). A fire and a kiln keep the general rule — they burn by day
## too, but their light only tells after dusk.
##
## A VENT does not. It is not a lamp and not a campfire: it is a hole into fire,
## and the ground round it is lit from underneath at every hour (docs/LOOK.md,
## "glow from below"). At noon the Burning was white-hot cores sitting on flat
## ground with nothing under them — the landscape's own fire touching none of its
## own land (art review, wave A finding 6).
##
## Its daylight floor has to be this high because it is competing with the SUN: a
## pool ADDS its energy to ground the sun already lights, so the 0.07 a vent had
## at noon moved the ground by two values out of 255. The floor fades out as the
## dark comes on, so the night — where the vents already read — keeps exactly the
## light it had.
static func burning_level(kind: int, power: float, dark: float) -> float:
	var level := power * (0.12 + 0.88 * dark)
	if kind == PropKind.VENT:
		return maxf(level, power * VENT_DAY * (1.0 - dark))
	return level


## What the ground under a burning thing looks like, as a display multiply on its
## albedo, at darkness `dark`.
##
## Every other light in the game aims BELOW daylight: a lamp's ochre wash is 0.96
## of the albedo, which is what a lamp does to a wall in the dark. compensate()
## works out the light needed to reach that target and finds, under a noon sun,
## that the answer is none — correctly, because a target under the sun is already
## met. So a vent's daylight floor was raising a level that was then multiplied by
## a colour of exactly zero, and the wash reached the ground only where the sky
## itself was dim: in the Burning's own smoke, which is the one place anyone had
## photographed it. On a clear noon it was still nothing.
##
## A hole into fire is not a lamp. The ground round it is brighter than the
## daylight beside it, so by day its target sits ABOVE 1 and compensate has
## something to solve for whatever the sun is doing. It eases back to the ochre
## wash as the dark comes on, where the fix was never needed.
static func burning_warm(kind: int, dark: float) -> Vector3:
	if kind != PropKind.VENT:
		return FIRE_WARM
	return VENT_DAY_WARM.lerp(VENT_WARM, clampf(dark, 0.0, 1.0))


## Does this source lay a wash on the ground at this darkness? A pool of light
## only tells once the dark has come: at dusk a lamp is a flame, not a spotlight.
## A vent is the exception, for the reason in burning_level().
static func lays_pool(kind: int, dark: float) -> bool:
	return kind == PropKind.VENT or dark > 0.25


## How little light there is, whatever the cause: the hour, and a sky too dark
## for the hour (a storm). 0 in full day, 1 in the dead of night. This is the
## shader's sky_gloom() on the CPU side, and nothing artificial — no pool, no
## lantern light — shows above it: a lamp lit at noon is a flame in the hand and
## lays nothing on the ground (docs/LOOK.md section 6).
static func gloom(hour: float, tint: Vector3, sun: float) -> float:
	var lum := (tint.x * 0.3 + tint.y * 0.59 + tint.z * 0.11) * clampf(sun, 0.0, 1.0)
	return clampf(maxf(SkyLight.low_light(hour), 1.0 - clampf(lum * 1.25, 0.0, 1.0)), 0.0, 1.0)


## Is this source burning at this hour? Lamps and windows light one by one;
## most houses go dark some time after midnight, a few keep a light all night.
static func source_lit(src: Dictionary, hour: float) -> bool:
	var want := lamps_wanted(hour)
	var h: float = src.h
	match int(src.kind):
		PropKind.FIRE, PropKind.VENT, PropKind.KILN:
			return true
		PropKind.LAMP:
			return want > 0.05 + 0.35 * h
		PropKind.SHACK, PropKind.FIRE_TOWER:
			return want > 0.1 + 0.3 * h
		PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.CHECKPOINT:
			return want > 0.3
		PropKind.HOUSE:
			if want <= 0.15 + 0.7 * h:
				return false
			var h2: float = src.h2
			if h2 < 0.72:
				var bed := fposmod(22.5 + h2 * 5.0, 24.0)
				var hh := fposmod(hour, 24.0)
				var asleep: bool = (hh >= bed or hh < 5.0) if bed > 5.0 else (hh >= bed and hh < 5.0)
				return not asleep
			return true
		PropKind.MURAL:
			# Advertising does not sleep. Every other light in this file is lit
			# when somebody WANTS it -- a lamp as the dark comes on, a house
			# until its people go to bed -- and this one is never switched off,
			# because nobody living under it decides. That is the landscape's
			# argument said in one `return true`.
			return true
	# A kind with no arm here IS NOT A LIGHT, however brightly its model glows.
	# That is how a billboard came to burn on its own face while laying nothing
	# on the street under it: a model's emission is per-vertex and knows nothing
	# about this file, so the two halves disagreed and neither raised anything.
	# A new light-giving kind needs an arm HERE, in `_update_glints` and in
	# `neon_colour`, or it lights nothing and mirrors in nothing.
	return false


## The linear light (colour times energy) a pool needs so that a surface under
## it shows `target` times its albedo on screen. The renderer shows
## srgb(lin(albedo * tint) * light), so the sky tint and the moon's own light
## (display level `sun`) are taken out in linear terms.
static func compensate(target: Vector3, tint: Vector3, sun: float) -> Vector3:
	var base := pow(clampf(sun, 0.0, 1.0), 2.2)
	var out := Vector3.ZERO
	for i in 3:
		# A tint below the floor is gloom (a storm at night): the pool does not
		# chase it, or lamps would blaze in the dark. The sky also lifts dark
		# washes at night, which the floor stands in for.
		out[i] = maxf(0.0, pow(target[i] / maxf(TINT_FLOOR, tint[i]), 2.2) - base)
	return out


## The renderer's OmniLight3D attenuation with omni_attenuation = 0, at
## distance d from a light of range `reach` (sky.gdshaderinc sky_omni()).
static func omni_attenuation(d: float, reach: float) -> float:
	if reach <= 0.0:
		return 0.0
	var nd := d / reach
	nd *= nd
	nd = maxf(1.0 - nd * nd, 0.0)
	return nd * nd


## Attenuation at which a pool's clean core ends and its dim ring ends
## (sky.gdshaderinc SKY_POOL_CORE, SKY_POOL_RING).
const POOL_CORE := 0.66
const POOL_RING := 0.32


## Radius on flat ground of a light `height` above it where the renderer's
## attenuation (1 - (d/range)^4)^2 falls to `level`: POOL_CORE for the clean
## core, POOL_RING for the ring round it.
static func pool_radius(reach: float, height: float, level: float = POOL_CORE) -> float:
	var d := reach * pow(1.0 - sqrt(level), 0.25)
	return sqrt(maxf(0.0, d * d - height * height))


## HOW THE LIGHTS NEAR THE PLAYER ARE FOUND, AND WHY IT IS NOT A SWEEP.
##
## `sources` is every light in the WORLD -- 1,865 of them on seed 4 -- and the
## three quarter-second passes below each want only the handful inside their own
## reach (`REACH` 17, `GLOW_REACH` 24, `Glints.REACH`). Each used to walk the
## whole array to find them, so one refresh tick was THREE full sweeps: measured
## walking seed 4 at 21:00, 3.3 ms typical and 8.5 ms worst, and all of it in
## ONE frame, four times a second. Against an 8.3 ms budget that is one frame in
## fifteen given over entirely to light, which is the shape the owner felt as
## "every second of running causes a small lurch".
##
## A prop never moves and worldgen never adds one, so WHICH CELL a source is in
## is fixed for the life of a world -- bucket it once as it is indexed. Sixteen
## tiles a cell, so even the widest reach is a 5x5 read.
const CELL := 16
## Keeps a cell key unique across any island this engine grows: the biggest
## world is 1,300 tiles, which is 82 cells.
const CELL_STRIDE := 4096


func _bucket(p: WorldProp) -> void:
	var key := floori(p.pos.y / float(CELL)) * CELL_STRIDE + floori(p.pos.x / float(CELL))
	if not _cells.has(key):
		_cells[key] = []
	(_cells[key] as Array).append(sources.size() - 1)


## Every source that COULD be within `reach` of `focus`. A cell straddles the
## edge, so this over-reads by up to a cell and each caller still measures the
## distance itself -- which they all did anyway, as their first act.
func _near(focus: Vector2, reach: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var span := int(ceil(reach / float(CELL)))
	var cx := floori(focus.x / float(CELL))
	var cy := floori(focus.y / float(CELL))
	for gy in range(cy - span, cy + span + 1):
		for gx in range(cx - span, cx + span + 1):
			var got: Variant = _cells.get(gy * CELL_STRIDE + gx)
			if got == null:
				continue
			for i: int in (got as Array):
				out.append(sources[i])
	return out


## A CROSSING HANDS THIS SYSTEM THE OTHER WORLD.
##
## `sources` is an index of the world just left: every entry names a prop on the
## old island, at coordinates that mean somewhere else here, and `_indexed` is a
## cursor into that world's prop list. Without this the new world's lights are
## never read at all while the old world's go on lighting ground they are not
## standing on. CLAUDE.md's realms row names "light index" as the example of a
## cache keyed on the world; this system never had the method.
func realm_changed(_from: StringName, _to: StringName) -> void:
	# EACH WORLD'S INDEX IS KEPT and handed back when that world comes back: a
	# door into a house and out again is the same coast, and indexing its every
	# light again cost 818 ms coming out (docs/interiors). Held weakly, so a world
	# nobody holds any more takes its index with it.
	if _indexed_world != null:
		_index_of[_indexed_world.get_instance_id()] = [weakref(_indexed_world), sources, _cells, _indexed]
	for k: int in _index_of.keys():
		if (_index_of[k][0] as WeakRef).get_ref() == null:
			_index_of.erase(k)
	var kept: Array = _index_of.get(game.world.get_instance_id(), [])
	if not kept.is_empty() and (kept[0] as WeakRef).get_ref() == game.world:
		sources = kept[1]
		_cells = kept[2]
		_indexed = kept[3]
	else:
		sources = [] as Array[Dictionary]
		_cells = {}
		_indexed = 0
	_indexed_world = game.world
	for i in _assigned.size():
		_assigned[i] = null
	for id: int in _glows.keys():
		(_glows[id] as Node).queue_free()
	_glows.clear()
	_glint_near.clear()
	_machine_near.clear()
	_machine_srcs.clear()
	_index_sources()
	# The next frame does the assigning, rather than a second _update here.
	_refresh = 0.0


func _index_sources() -> void:
	var props := game.world.props
	while _indexed < props.size():
		var p: WorldProp = props[_indexed]
		_indexed += 1
		if not SOURCES.has(p.kind) and p.kind != PropKind.PYLON:
			# Any other kind whose model says where its lights are (a relay's
			# beacon, an array's strip) glints on the machines' power.
			var pts := _points_for(p)
			if not pts.is_empty():
				var world_pts: Array[Vector3] = []
				var rgb: Array[Vector3] = []
				var base := game.world.to_3d(p.pos)
				for g: Dictionary in pts:
					world_pts.append(base + Basis(Vector3.UP, -p.rot) * ((g.at as Vector3) * p.scale))
					var c: Color = g.color
					rgb.append(Vector3(c.r, c.g, c.b))
				sources.append({"prop": p, "kind": p.kind, "h": Rng.hash01(game.world.seed_value, p.id, 0x11A), "h2": 0.0,
					"at": world_pts[0], "range": 0.0, "power": 0.0, "warm": WARM, "machine_points": world_pts, "machine_rgb": rgb, "blink": bool(pts[0].get("blink", false))})
				_bucket(p)
			continue
		var s := {
			"prop": p, "kind": p.kind,
			"h": Rng.hash01(game.world.seed_value, p.id, 0x11A),
			"h2": Rng.hash01(game.world.seed_value, p.id, 0x11B),
		}
		if SOURCES.has(p.kind):
			var spec: Array = SOURCES[p.kind]
			var base := game.world.to_3d(p.pos)
			var local := Vector3(0, float(spec[2]), 0)
			# `variant_of`, never the id's hash: world gen may have DEALT this
			# prop a model (WorldProp.variant), and a light read off the other one
			# puts the glow point, its colour and the "no light on this variant"
			# early-out on a model that is not the one on screen.
			#
			# Hoisted out of the branch below, because the HOUSE branch beside it
			# needed the same two numbers and could not see them: a hearth was
			# placed at the front wall of coast variant 0 whatever house the baker
			# had actually built.
			var country := maxi(Country.COAST, game.world.country_at(floori(p.pos.x), floori(p.pos.y)))
			var variant := PropModels.variant_of(p, game.world.seed_value, country)
			if PLACED_SOURCES.has(p.kind):
				var pts := PropModels.glow_points(p.kind, variant, country)
				if pts.is_empty():
					# A dead pump, a shack with nothing wired in: no light to give.
					continue
				local = pts[0].at
				var c: Color = pts[0].color
				s.neon = Vector3(c.r, c.g, c.b)
			if p.kind == PropKind.HOUSE:
				# Just outside the front wall, before the window and door.
				var front := _front_of(p.kind, variant, country)
				var out := Vector3(front.x, 0.0, front.z).normalized() * 0.5
				local = Vector3(front.x + out.x, float(spec[2]), front.z + out.z)
			# Props turn by -rot (a model faces +X; WorldView draws them so).
			s.at = base + Basis(Vector3.UP, -p.rot) * (local * p.scale)
			s.range = float(spec[0]) * lerpf(1.0, p.scale, 0.5)
			s.power = float(spec[1])
			match p.kind:
				PropKind.FIRE: s.warm = FIRE_WARM
				PropKind.VENT: s.warm = VENT_WARM
				PropKind.HOUSE: s.warm = HEARTH_WARM
				PropKind.SHACK: s.warm = (s.neon as Vector3).lerp(Vector3.ONE, 0.35)
				# The sign's own colour, barely pulled toward white: a billboard
				# is the brightest thing in the frame, so the street under it
				# must be the colour of the advertisement and not a generic warm
				# — that tint IS how the player reads which sign they are under.
				PropKind.MURAL: s.warm = (s.neon as Vector3).lerp(Vector3.ONE, 0.15)
				PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.CHECKPOINT: s.warm = MACHINE_COLD
				_: s.warm = WARM
		else:
			s.at = game.world.to_3d(p.pos) + Vector3(0, 4.05 * p.scale, 0)
			s.range = 0.0
			s.power = 0.0
			s.warm = WARM
		sources.append(s)
		_bucket(p)


## Where this house's stolen tube hangs and what colour it burns, read off the
## MODEL and then kept on the source: a tube that moved to a roof edge must not
## leave the light it throws pinned to the door wall, in the other lit house's
## colour (a2 review). Asked only of the houses near the camera and only once
## each — reading a model means building it, and the index walks every prop in
## the world, which cost 190 ms of the start when it was done up front.
func _tube_of(s: Dictionary) -> void:
	if s.has("neon_at") or bool(s.get("dark", false)):
		return
	var p: WorldProp = s.prop
	var country := maxi(Country.COAST, game.world.country_at(floori(p.pos.x), floori(p.pos.y)))
	var tube := PropModels.neon_point(p.kind, PropModels.variant_of(p, game.world.seed_value, country), country)
	if tube.is_empty():
		s.dark = true
		return
	s.neon_at = game.world.to_3d(p.pos) + Basis(Vector3.UP, -p.rot) * ((tube.at as Vector3) * p.scale)
	var tc: Color = tube.color
	s.neon_rgb = Vector3(tc.r, tc.g, tc.b)


## Where a house's lit front is, in its own frame: the middle of the glow points
## that are its OWN light. A stolen tube is somebody else's and hangs where the
## model runs it, so it must not drag the hearth's pool off the door.
static func _front_of(kind: int, variant: int, country: int) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for g: Dictionary in glow_points(kind, variant, country):
		if bool(g.get("neon", false)):
			continue
		sum += g.at as Vector3
		n += 1
	return Vector3.ZERO if n == 0 else sum / float(n)


func _update(delta: float, snap: bool) -> void:
	_time += delta
	var hour := game.clock.hour()
	var focus3 := game.camera.target if game.camera != null else game.player.position
	var focus := Vector2(focus3.x, focus3.z)
	_refresh -= delta
	if snap or _refresh <= 0.0:
		_refresh = 0.25
		_index_sources()
		_assign(focus, hour)
		_update_glows(focus, hour)
		_gather_glints(focus)
	_blink()
	var tint: Vector3 = game.sky.last_tint
	var sun: float = game.sky.last_energy
	var want := lamps_wanted(hour)
	# Lamps are lit before dark, but a pool of light only tells once the dark
	# has come: at dusk a lamp is a flame, not a spotlight.
	# A lightning flash drowns the lamps: the page shows, not the pools.
	var flash := 1.0 - clampf(game.sky.flash * 1.6, 0.0, 1.0)
	# How dark the HOUR is, before the flash is taken off it. A vent's daylight
	# floor is read off this: a flash is not daylight, and reading it as daylight
	# would make the one light with a daylight floor burn HARDER under lightning.
	# A roof is as dark as the hour ever gets. Under one the hour says nothing at
	# all, so a pool of lamplight tells at noon down there exactly as it does at
	# midnight up here (SkyLight.closed, src/core/realm, src/systems/20_realms.gd).
	# A lit lamp with no pool under it is not a lit street: a landscape with a lid
	# on it needs both, or the lamps come on at noon and lay nothing (`SkyLight.lid`).
	var hour_dark := maxf(pool_dark(hour), maxf(game.sky.closed, game.sky.lid))
	var dark := hour_dark * flash
	var pools: Array[Vector4] = []
	var pool_rgb: Array[Vector4] = []
	for i in lights.size():
		var l := lights[i]
		var src: Variant = _assigned[i]
		if src == null:
			l.visible = false
			continue
		var s: Dictionary = src
		if s.has("mob"):
			if not _machine_at(s):
				l.visible = false
				_assigned[i] = null
				continue
			var mlevel: float = float(s.power) * dark * clampf(game.sky.bolt.w, 0.0, 1.0)
			l.light_volumetric_fog_energy = FOG_NEON
			if _set_light(l, s.at, float(s.range), compensate(MACHINE_COLD, tint, sun) * mlevel) and dark > 0.25:
				pools.append(Vector4(s.at.x, s.at.y, s.at.z, float(s.range)))
				pool_rgb.append(Vector4(MACHINE_COLD.x, MACHINE_COLD.y, MACHINE_COLD.z, 0.0) * clampf(mlevel, 0.0, 1.2))
			continue
		var kind := int(s.kind)
		var level: float = s.power
		# Whether this source lays a wash on the ground at all right now.
		var lays := lays_pool(kind, dark)
		var warm: Vector3 = s.warm
		var reach: float = s.range
		if kind == PropKind.VENT:
			level = burning_level(kind, float(s.power), hour_dark) * flash
			warm = burning_warm(kind, hour_dark)
			reach = s.range * lerpf(VENT_DAY_REACH, 1.0, hour_dark)
		elif kind == PropKind.FIRE or kind == PropKind.KILN:
			level = burning_level(kind, float(s.power), dark)
		else:
			level *= want * dark
			if POWERED_SOURCES.has(kind):
				level *= clampf(game.sky.bolt.w, 0.0, 1.0)
		# A flicker changes how bright the pool is, never how big: the ink's
		# edge must not crawl.
		level *= _flicker(s)
		# A flame reaches much further and falls off much faster, so its core is
		# the same size and its tail has no edge on it anywhere (FLAME_KINDS).
		var flame := is_flame(kind)
		var lit_reach := reach * (FLAME_REACH if flame else 1.0)
		var atten := FLAME_ATTEN if flame else ATTENUATION
		l.light_volumetric_fog_energy = fog_scatter(s)
		if _set_light(l, s.at, lit_reach, compensate(warm, tint, sun) * level, atten) and lays:
			pools.append(Vector4(s.at.x, s.at.y, s.at.z, reach))
			var nc: Vector3 = neon_colour(s)
			pool_rgb.append(Vector4(nc.x, nc.y, nc.z, 0.0) * clampf(level, 0.0, 1.2))
	# NEAREST WINS THE SHADER'S POOL. More lamps burn now than `sky_lamps` can
	# carry: the tier's `lamps` row builds up to 32 OmniLights and the packed
	# global holds MAX_LAMPS. Which eight the sky was handed used to be the order
	# the light SLOTS happened to fill, which is stable per source and has nothing
	# to do with where the camera is — so a street of lit posts could crowd out
	# the machine standing next to the player, and three tests read a pool of zero
	# under a light that was burning in shot. Sorted by distance to the camera,
	# which is what `_assign` already does for the lights themselves.
	if pools.size() > SkyLight.MAX_LAMPS:
		var order: Array[int] = []
		for i in pools.size():
			order.append(i)
		var away := func(v: Vector4) -> float:
			return focus3.distance_squared_to(Vector3(v.x, v.y, v.z))
		order.sort_custom(func(a: int, b: int) -> bool: return away.call(pools[a]) < away.call(pools[b]))
		var near_pools: Array[Vector4] = []
		var near_rgb: Array[Vector4] = []
		for i in SkyLight.MAX_LAMPS:
			near_pools.append(pools[order[i]])
			near_rgb.append(pool_rgb[order[i]])
		pools = near_pools
		pool_rgb = near_rgb
	var lit := game.body.lamp_lit
	lantern.visible = lit
	if lit:
		var p := game.player
		var hand := Basis(Vector3.UP, -p.facing) * Vector3(0.12, 0.52, 0.34)
		lantern.position = p.position + hand
		lantern.rotation.y = -p.facing
		lantern.position.y += sin(_time * 5.0) * 0.03 * clampf(p.speed / 3.0, 0.0, 1.0)
		# The lantern's floor: in any gloom it lifts the ground a little (source
		# 0.45), and in daylight it lifts nothing at all — a lamp lit at noon must
		# not lay a disc on a bright land.
		var night := maxf(dark, 0.45 * maxf(gloom(hour, tint, sun), game.sky.closed))
		var at := p.position + Basis(Vector3.UP, -p.facing) * LANTERN_LIGHT
		# Where a lamp already lights the ground the lantern hardly adds, and its
		# pool draws in under the lamp's: two pools stacked read as two ruled
		# discs. Both ease with distance, so walking out of a lamp's light the
		# lantern's pool opens up around you rather than popping on.
		var covered := 0.0
		for pool in pools:
			covered = maxf(covered, omni_attenuation(p.position.distance_to(Vector3(pool.x, pool.y, pool.z)), pool.w))
		var under := smoothstep(0.05, 0.45, covered)
		night *= 1.0 - 0.9 * under
		var reach := LANTERN_RANGE * (1.0 - 0.6 * under)
		var rgb := compensate(WARM, tint, sun) * LANTERN_POWER * night * (0.94 + 0.06 * _flicker({"kind": PropKind.LAMP, "h": 0.5}))
		lantern_light.light_volumetric_fog_energy = FOG_WARM
		if _set_light(lantern_light, at, reach, rgb):
			# The player's own pool comes first: it is the one that matters.
			pools.push_front(Vector4(at.x, at.y, at.z, reach))
			pool_rgb.push_front(Vector4(LANTERN_WARM.x, LANTERN_WARM.y, LANTERN_WARM.z, 0.0) * night)
	else:
		lantern_light.visible = false
	pools.resize(mini(pools.size(), SkyLight.MAX_LAMPS))
	pool_rgb.resize(pools.size())
	game.sky.lamps = pools
	game.sky.lamp_colors = pool_rgb
	_show_lent()
	_cast_shadows(focus3)
	_update_glints(focus3, hour, lit)


## Every light near the camera as a glint candidate (Glints), lit as it is now.
func _update_glints(focus3: Vector3, hour: float, lantern_lit: bool) -> void:
	var power := clampf(game.sky.bolt.w, 0.0, 1.0)
	var want := lamps_wanted(hour)
	var cands: Array[Dictionary] = []
	for s: Dictionary in _glint_near:
		if s.has("mob"):
			# A mob freed since the last gather (killed, despawned) must be checked
			# before it is held in a typed variable.
			if not is_instance_valid(s.mob):
				continue
			var m: Node = s.mob
			if not bool(m.get("alive")):
				continue
			cands.append({"at": m.call("part_position"), "rgb": LENS_GLINT, "level": 0.55 * power, "shaft": SHAFT_LENS})
			continue
		var kind := int(s.kind)
		if s.has("machine_points"):
			var mp: Array[Vector3] = s.machine_points
			var mc: Array[Vector3] = s.machine_rgb
			# A beacon (a relay's) blinks like a pylon's, a second in three.
			var on := 1.0 if not s.get("blink", false) or fposmod(_time + float(s.h) * 3.0, 3.0) < 1.1 else 0.0
			for j in mp.size():
				cands.append({"at": mp[j], "rgb": mc[j], "level": 0.7 * power * on, "shaft": SHAFT_MACHINE})
			continue
		match kind:
			PropKind.PYLON:
				var blink := fposmod(_time + float(s.h) * 3.0, 3.0) < 1.1
				cands.append({"at": s.at, "rgb": BEACON, "level": (0.8 if blink and want > 0.3 else 0.0) * power, "shaft": SHAFT_RAYED})
			PropKind.FIRE, PropKind.VENT, PropKind.KILN:
				cands.append({"at": s.at, "rgb": neon_colour(s), "level": (0.9 if kind == PropKind.FIRE else 0.55) * _flicker(s), "shaft": 0.0 if kind == PropKind.FIRE else SHAFT_RAYED})
			PropKind.LAMP:
				cands.append({"at": s.at, "rgb": neon_colour(s), "level": (0.85 if source_lit(s, hour) else 0.0) * _flicker(s), "shaft": SHAFT_RAYED})
			PropKind.HOUSE:
				cands.append({"at": s.at, "rgb": neon_colour(s), "level": 0.5 if source_lit(s, hour) else 0.0})
				_tube_of(s)
				if s.has("neon_at"):
					cands.append({"at": s.neon_at, "rgb": s.neon_rgb, "level": 0.95 * smoothstep(0.2, 0.6, want) * power})
			PropKind.SHACK:
				cands.append({"at": s.at, "rgb": neon_colour(s), "level": (0.95 * power if source_lit(s, hour) else 0.0), "shaft": SHAFT_MACHINE})
			PropKind.FIRE_TOWER:
				cands.append({"at": s.at, "rgb": neon_colour(s), "level": (0.8 if source_lit(s, hour) else 0.0) * _flicker(s), "shaft": SHAFT_RAYED})
			PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.CHECKPOINT:
				cands.append({"at": s.at, "rgb": neon_colour(s), "level": (0.8 if source_lit(s, hour) else 0.0) * power, "shaft": SHAFT_MACHINE})
			PropKind.MURAL:
				# The loudest glint in the game, and the reason it is worth one of
				# the twelve slots: a streak in wet ground is as long as its light
				# stands HIGH (sky.gdshaderinc `neon_streak`), so a sign nine
				# units up lays a reflection several times a lamp post's. The
				# standing water holding the billboards is half the light in the
				# Slums and this line is where it comes from.
				cands.append({"at": s.at, "rgb": neon_colour(s), "level": 0.95 * power, "shaft": SHAFT_MACHINE})
	if lantern_lit:
		cands.append({"at": lantern.position + Vector3(0, 0.1, 0), "rgb": LANTERN_WARM, "level": 0.7, "shaft": SHAFT_RAYED})
	glint_list = Glints.pick(cands, focus3)
	var packed := Glints.pack(glint_list)
	game.sky.glints = packed[0]
	game.sky.glint_colors = packed[1]


var _glow_cache: Dictionary = {}


## Where THIS prop gives light, asked once per (kind, variant, country).
##
## The cache used to key on kind alone, which is why the bug above could not be
## corrected per prop even where the caller knew better: the first prop of a kind
## to be indexed decided for every other one in the world.
func _points_for(p: WorldProp) -> Array:
	var country := maxi(Country.COAST, game.world.country_at(floori(p.pos.x), floori(p.pos.y)))
	var variant := PropModels.variant_of(p, game.world.seed_value, country)
	var key := (p.kind * PropModels.MAX_VARIANTS + variant) * BiomeRegistry.SLOTS + country
	if not _glow_cache.has(key):
		_glow_cache[key] = glow_points(p.kind, variant, country)
	return _glow_cache[key]


## The sources and machines that could glint near the focus, nearest first.
func _gather_glints(focus: Vector2) -> void:
	_glint_near.clear()
	var near: Array = []
	for s in _near(focus, Glints.REACH):
		var p: WorldProp = s.prop
		if game.world.depleted.has(p.id):
			continue
		var d := p.pos.distance_squared_to(focus)
		if d <= Glints.REACH * Glints.REACH:
			near.append([d, s])
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i in mini(near.size(), 40):
		_glint_near.append(near[i][1])
	_machine_near.clear()
	var seen := {}
	if not is_inside_tree():
		_machine_srcs.clear()
		return
	for m in get_tree().get_nodes_in_group(&"mobs"):
		var mob := m as Mob
		if mob == null or mob.state == null or not bool(mob.state.row.get("machine", false)) or mob.state.row.get("part", &"none") == &"none":
			continue
		if mob.pos.distance_squared_to(focus) <= Glints.REACH * Glints.REACH:
			_glint_near.append({"mob": mob})
		if mob.pos.distance_squared_to(focus) <= REACH * REACH:
			# One dictionary per mob for as long as it is near, so the pool light
			# it is handed stays with it instead of jumping every quarter second.
			var key := mob.get_instance_id()
			if not _machine_srcs.has(key):
				_machine_srcs[key] = {"mob": mob, "kind": PropKind.CHECKPOINT, "h": 0.0, "h2": 0.0,
					"at": Vector3.ZERO, "range": MACHINE_POOL.x, "power": MACHINE_POOL.y, "warm": MACHINE_COLD}
			_machine_near.append(_machine_srcs[key])
			seen[key] = true
	for key: int in _machine_srcs.keys():
		if not seen.has(key):
			_machine_srcs.erase(key)


## Where a live machine's pool sits now: at its working part, dropped toward the
## ground it stands on, so the light lands under the body and not inside it.
## False once the body is gone or its lights are out.
func _machine_at(s: Dictionary) -> bool:
	# A body freed since the last gather (killed and cleared) must be checked
	# before it is held in a typed variable, or the assignment itself errors.
	if not is_instance_valid(s.mob):
		return false
	var mob: Node = s.mob
	if not bool(mob.get("alive")):
		return false
	var model := mob.get("model") as MachineModel
	if model == null or model.light_level() <= 0.0:
		return false
	var at: Vector3 = mob.call("part_position")
	s.at = Vector3(at.x, maxf((mob as Node3D).global_position.y + 0.35, at.y - 0.3), at.z)
	return true


## Tour awaits. `machine` is a live machine close enough and far enough inside
## the frame that a shot taken now would hold it; `machine:KIND` is that machine
## being of that kind.
##
## It lives here because this is the system that already keeps every live machine
## near the camera, for the pool each one lays. It exists because `walkto mob N`
## steers for at most N seconds and then returns true either way, so a proof
## frame staged with it is a timed nudge and not a guarantee: the machine-read
## tour's own wary-at-noon frame came out EMPTY on about half its runs, and was
## saved as proof of a read that nothing in the picture supported (wave A2
## review). A tour can now hold the shot until the body is there, and fail if it
## never comes.
func tour_seen(what: StringName) -> bool:
	var want := StringName(String(what).trim_prefix("machine:"))
	if want == what and what != &"machine":
		return false
	for m in get_tree().get_nodes_in_group(&"mobs"):
		var mob := m as Node
		if not bool(mob.get("alive")):
			continue
		if what != &"machine" and StringName(mob.get("kind")) != want:
			continue
		if (mob.get("model") as MachineModel) == null:
			continue
		if _framed(mob as Node3D):
			return true
	return false


## Is this body inside the middle of the frame, by enough that the few physics
## frames between an await and the shutter cannot carry it out?
##
## Worked out from the CAMERA alone — its own orthographic extent and the game's
## fixed 640x360 — and never from the viewport. A tool run's window is one pixel
## across (tools/_focus.sh: macOS has no off-screen to hide in), so a check that
## divided by the viewport's rect said yes to anything anywhere and shipped two
## frames with no machine in them, which is the very failure it was written for.
func _framed(mob: Node3D) -> bool:
	var cam := game.camera
	if cam == null or not cam.is_inside_tree():
		return false
	# The body's own middle, not its feet: a tall machine standing at the bottom
	# edge is a machine the frame holds.
	var at := mob.global_position + Vector3(0, 0.6, 0)
	if (cam.global_transform.affine_inverse() * at).z > -0.5:
		return false
	# ASK THE CAMERA WHERE IT LANDS. This was a half-extent off `cam.size` and a
	# spelled aspect, which is an ORTHOGRAPHIC pair of numbers: under the lens
	# `size` is a property the projection ignores and would answer 15.0 for ever.
	# `unproject_position` is right under either projection and follows a zoom and
	# a lean for free -- and under the play camera it is the same test, because
	# the inset is the same fraction of the same 16:9 frame.
	var rect: Vector2 = cam.get_viewport().get_visible_rect().size
	var s := cam.unproject_position(at)
	var in_x := rect.x * TOUR_MARGIN
	var in_y := rect.y * TOUR_MARGIN
	return s.x > in_x and s.x < rect.x - in_x and s.y > in_y and s.y < rect.y - in_y


static func neon_colour(s: Dictionary) -> Vector3:
	match int(s.kind):
		PropKind.LAMP:
			return Vector3(1.0, 0.72, 0.42)
		PropKind.HOUSE:
			return Vector3(1.0, 0.68, 0.4)
		PropKind.SHACK:
			return s.get("neon", NEON_MAGENTA)
		PropKind.MURAL:
			return s.get("neon", NEON_SODIUM)
		PropKind.FIRE_TOWER:
			return Vector3(1.0, 0.72, 0.42)
		PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.CHECKPOINT:
			return MACHINE_COLD
		_:
			return NEON_FIRE


## Returns whether the light is on. `atten` is how steeply it falls off; a
## flame's is steeper over a much longer reach, so its pool has no edge.
## HOW MUCH OF A LIGHT THE AIR CARRIES, BY KIND (fc, 2026-09-22, on frames). Stolen neon, a works strip and a machine's lens bleed their
## colour into the mist -- that glow hanging in the bog is the stolen light made
## visible. A street lamp, a window and a fire throw their light DOWN: at Godot's
## default every one of them scattered fully, and a street of them turned the
## slums' dark into one milky haze.
const FOG_NEON := 1.0
const FOG_WARM := 0.2


static func fog_scatter(s: Dictionary) -> float:
	if s.has("mob") or s.has("neon") or POWERED_SOURCES.has(int(s.get("kind", -1))):
		return FOG_NEON
	return FOG_WARM


func _set_light(l: OmniLight3D, at: Vector3, reach: float, rgb: Vector3,
		atten: float = ATTENUATION) -> bool:
	var e := maxf(rgb.x, maxf(rgb.y, rgb.z))
	if e < 0.01:
		l.visible = false
		return false
	l.visible = true
	l.position = at
	l.omni_attenuation = atten
	l.omni_range = reach
	# Godot takes light_color as sRGB and linearises it before shading; the
	# levels here are display values, so hand it the colour pre-encoded.
	l.light_color = Color(rgb.x / e, rgb.y / e, rgb.z / e).linear_to_srgb()
	# A lamp has to BEAT the night, or carrying one is a decoration. The gain is
	# what puts its pool a stop and a half over SkyLight.NIGHT_AMBIENT at the
	# foot of the post, and it is the number law 3 balances against: "night is
	# genuinely dark, which is what makes a lantern matter".
	# CompatTrim.lamp_gain: 1 on Forward+, the fitted count-back on Compatibility.
	l.light_energy = e * GAIN * CompatTrim.lamp_gain()
	return true


## Stepped, not smooth: a flame changes its mind a dozen times a second.
func _flicker(s: Dictionary) -> float:
	return flicker(s, _time)


## A light's flicker at `time` seconds: a multiply on its level, stepped.
static func flicker(s: Dictionary, time: float) -> float:
	var kind := int(s.kind)
	var h: float = s.h
	if kind == PropKind.FIRE:
		var step := floori(time * 11.0 + h * 50.0)
		# Linear light: a quarter of it shows as a few percent on screen.
		return 0.7 + 0.3 * Rng.hash01(step, int(h * 1000.0))
	if kind == PropKind.VENT:
		# A vent breathes.
		return 0.75 + 0.25 * sin(time * 1.3 + h * TAU)
	if kind == PropKind.HOUSE:
		# The hearth inside, seen through the door: a fire's flicker, gentled.
		var step := floori(time * 9.0 + h * 40.0)
		return 0.8 + 0.2 * Rng.hash01(step, int(h * 1000.0) + 3)
	if kind == PropKind.LAMP:
		var step := floori(time * 6.0 + h * 30.0)
		return 0.96 + 0.04 * Rng.hash01(step, 7)
	return 1.0


## Hand the pool to the nearest lit sources; a light keeps its source while that
## source is still wanted, so nothing jumps as the camera walks.
func _assign(focus: Vector2, hour: float) -> void:
	var wanted: Array = []
	for s in _near(focus, REACH):
		if float(s.range) <= 0.0:
			continue
		var p: WorldProp = s.prop
		if game.world.depleted.has(p.id):
			continue
		var d := p.pos.distance_squared_to(focus)
		if d > REACH * REACH or not source_lit(s, hour):
			continue
		wanted.append([d, s])
	# A live machine competes for the same pool on distance alone: the thing two
	# tiles away lighting the ground beats a window twelve tiles off, which is
	# what a player standing next to it would expect and what keeps the budget.
	for s in _machine_near:
		if not is_instance_valid(s.mob):
			continue
		var mob: Node = s.mob
		if not bool(mob.get("alive")):
			continue
		wanted.append([(mob.get("pos") as Vector2).distance_squared_to(focus), s])
	wanted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var chosen: Array = []
	for i in mini(wanted.size(), lights.size()):
		chosen.append(wanted[i][1])
	for i in _assigned.size():
		if _assigned[i] != null and not chosen.has(_assigned[i]):
			_assigned[i] = null
	for s: Dictionary in chosen:
		if _assigned.has(s):
			continue
		var free := _assigned.find(null)
		if free >= 0:
			_assigned[free] = s


func _update_glows(focus: Vector2, hour: float) -> void:
	var keep := {}
	for s in _near(focus, GLOW_REACH):
		var p: WorldProp = s.prop
		if p.pos.distance_squared_to(focus) > GLOW_REACH * GLOW_REACH or game.world.depleted.has(p.id):
			continue
		var on := false
		match int(s.kind):
			PropKind.PYLON:
				on = lamps_wanted(hour) > 0.3
			PropKind.HOUSE, PropKind.LAMP, PropKind.FIRE:
				on = source_lit(s, hour)
		if not on:
			continue
		keep[p.id] = true
		if not _glows.has(p.id):
			var n := _glow_node(s)
			if n != null:
				add_child(n)
				_glows[p.id] = n
	for id: int in _glows.keys():
		if not keep.has(id):
			(_glows[id] as Node).queue_free()
			_glows.erase(id)
	_blink()


## Beacons blink: a second on in three, never in step with each other. They run
## on the machines' power, so a strike stutters them. Every frame, so the
## stutter's beat is seen.
func _blink() -> void:
	var powered := game.sky.bolt.w > 0.5
	for id: int in _glows:
		var n: Node3D = _glows[id]
		if n.has_meta("blink"):
			n.visible = fposmod(_time + float(n.get_meta("blink")) * 3.0, 3.0) < 1.1 and powered


## Where a prop gives light, in ITS OWN frame -- the variant world gen dealt it,
## in the landscape it stands in.
##
## **THIS TOOK NO VARIANT AND NO COUNTRY, so every reader of it got coast variant
## 0.** `_index_sources` already had the rule written out twenty lines further
## down, on the branch that does it properly: a light read off the other model
## puts the glow point, its colour and the "no light on this variant" early-out
## on a model that is not the one on screen. The pool, the glow quad and the
## house's lit front all came through here, so all three agreed with each other
## and all three disagreed with the mesh the chunk baked -- a house lit where its
## tube is not, which is the trap `PropModels` own header names.
static func glow_points(kind: int, variant: int = 0, country: int = Country.COAST) -> Array:
	return PropModels.glow_points(kind, variant, country)


func _glow_node(s: Dictionary) -> Node3D:
	var p: WorldProp = s.prop
	var pts := _points_for(p)
	if pts.is_empty():
		return null
	var k := MeshKit.new()
	var root := Node3D.new()
	root.name = "glow_%d" % p.id
	root.transform = Transform3D(Basis(Vector3.UP, -p.rot).scaled(Vector3.ONE * p.scale), game.world.to_3d(p.pos))
	for g: Dictionary in pts:
		var at: Vector3 = g.at
		var sz: Vector2 = g.get("size", Vector2.ZERO)
		var col: Color = g.color
		if sz.x > 0.0:
			if g.get("box", false):
				k.block(at.x, at.y - sz.y * 0.5, at.z, sz.x, sz.y, sz.x, col, col)
			elif g.get("door", false):
				# A door left ajar: a lit slit down the latch side, not the whole leaf.
				var sx := sz.x * 0.25
				k.quad(at + Vector3(sz.x * 0.5 - sx, -sz.y * 0.5, 0.004), at + Vector3(sz.x * 0.5, -sz.y * 0.5, 0.004), at + Vector3(sz.x * 0.5, sz.y * 0.5, 0.004), at + Vector3(sz.x * 0.5 - sx, sz.y * 0.5, 0.004), col)
			else:
				k.quad(at + Vector3(-sz.x * 0.5, -sz.y * 0.5, 0.004), at + Vector3(sz.x * 0.5, -sz.y * 0.5, 0.004), at + Vector3(sz.x * 0.5, sz.y * 0.5, 0.004), at + Vector3(-sz.x * 0.5, sz.y * 0.5, 0.004), col)
		if g.has("rays"):
			var r: Array = g.rays
			var n := rays(col, float(r[0]), float(r[1]), float(r[2]), float(r[3]), float(s.h))
			n.position = at
			root.add_child(n)
	if k.vertex_count() > 0:
		var mi := MeshInstance3D.new()
		mi.mesh = k.build()
		mi.material_override = _glow_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	if p.kind == PropKind.PYLON:
		root.set_meta("blink", float(s.h))
	return root


## A flame's radiating strokes (rays.gdshader), sized in screen pixels.
static func rays(col: Color, inner: float, outer: float, flicker: float, spokes: float, seed_value: float = 0.0) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = RAYS
	mat.set_shader_parameter("color", col)
	mat.set_shader_parameter("inner", inner)
	mat.set_shader_parameter("outer", outer)
	mat.set_shader_parameter("flicker", flicker)
	mat.set_shader_parameter("spokes", spokes)
	mat.set_shader_parameter("seed", seed_value * 97.0)
	mat.render_priority = 5
	var mi := MeshInstance3D.new()
	mi.name = "rays"
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	return mi


## A small hand lantern: copper frame, a warm pane, a ring to carry it by. MADE,
## but drawn unshaded, because at night the lantern is the light.
func _lantern_mesh() -> Node3D:
	var k := MeshKit.new()
	k.prism(0, 0.0, 0, 0.065, 0.03, 0.06, 6, Palette.COPPER[1])
	k.prism(0, 0.03, 0, 0.05, 0.12, 0.045, 6, Palette.COPPER[4], Palette.EMBER[5])
	k.prism(0, 0.12, 0, 0.06, 0.16, 0.02, 6, Palette.COPPER[1])
	k.strut(Vector3(0, 0.16, 0), Vector3(0, 0.2, 0), 0.012, 4, Palette.COPPER[1])
	var mi := MeshInstance3D.new()
	mi.name = "lantern"
	mi.mesh = k.build()
	mi.material_override = _glow_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi
