extends GameSystem
## Night lights: village lamps, the windows of houses, fires, vents and kilns,
## and the player's lantern (the `lamp` action). docs/ART.md section 6: lamp and
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
## The lantern is a hand light: a small pool, a little dimmer than a lamp.
## compensate() never divides by a sky tint channel darker than this.
const TINT_FLOOR := 0.45
const LANTERN_RANGE := 3.2
## The colour each kind of light throws (pools and wet reflections). People's
## lamps, windows and fires are warm, and so is the flame in the player's
## salvaged lantern: the pool it lays is the colour of its own light and never a
## cold disc over a warm one (docs/ART.md section 6). Stolen neon belongs to the
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
const POWERED_SOURCES: Array[int] = [PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.CHECKPOINT, PropKind.SHACK]
## Sources placed at their model's own glow point, lit only on the variants that have one.
const PLACED_SOURCES: Array[int] = [PropKind.SHACK, PropKind.FIRE_TOWER, PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.CHECKPOINT]
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
var _indexed := 0
var _assigned: Array = [] # per pool light: source Dictionary or null
var _refresh := 0.0
var _glows: Dictionary = {} # prop id -> Node3D
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
## Stolen neon on the machines' power: magenta tube colour (props/houses.gd).
const NEON_TUBE := Vector3(1.0, 0.25, 0.8)
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
## House variants that wired a machine's light over the door (props/houses.gd:
## washed form 1 and slated form 0). Until PropModels.glow_points says so per
## variant, the list lives here.
const NEON_HOUSE_VARIANTS: Array[int] = [1, 4]
## -1 not looked yet, 0 no, 1 yes: whether PropModels says where its lights are.


func setup(g: Game) -> void:
	super.setup(g)
	if g.options.lamp:
		g.body.lamp_lit = true
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.vertex_color_use_as_albedo = true
	_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in SkyLight.MAX_LAMPS - 1:
		lights.append(_new_light("lamp_%d" % i))
		_assigned.append(null)
	lantern_light = _new_light("lantern_light")
	lantern = _lantern_mesh()
	var lr := rays(Palette.COPPER[4], 2.0, 4.0, 0.15, 4.0)
	lr.position = Vector3(0, 0.08, 0)
	lantern.add_child(lr)
	add_child(lantern)
	_index_sources()
	_update(0.0, true)


func _new_light(n: String) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = n
	l.shadow_enabled = false
	# No distance decay, only the range window: a broad even pool with a firm
	# edge, which sky_pool() cuts into hard steps.
	l.omni_attenuation = 0.0
	l.light_specular = 0.0
	# Water is on its own layer and never takes lamplight (SkyLight.LAYER_WATER).
	l.light_cull_mask = 0xFFFFF & ~SkyLight.LAYER_WATER
	l.visible = false
	add_child(l)
	return l


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


## 0..1: how far people have lit up. Lamps go on before full dark and out after
## first light: up over 19:00-20:30, down over 05:00-06:30.
static func lamps_wanted(hour: float) -> float:
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


## How little light there is, whatever the cause: the hour, and a sky too dark
## for the hour (a storm). 0 in full day, 1 in the dead of night. This is the
## shader's sky_gloom() on the CPU side, and nothing artificial — no pool, no
## lantern light — shows above it: a lamp lit at noon is a flame in the hand and
## lays nothing on the ground (docs/ART.md section 6).
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


func _index_sources() -> void:
	var props := game.world.props
	while _indexed < props.size():
		var p: WorldProp = props[_indexed]
		_indexed += 1
		if not SOURCES.has(p.kind) and p.kind != PropKind.PYLON:
			# Any other kind whose model says where its lights are (a relay's
			# beacon, an array's strip) glints on the machines' power.
			var pts := _glow_points_cached(p.kind)
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
			if PLACED_SOURCES.has(p.kind):
				var variant := PropModels.pick_variant(p.kind, Rng.hash_ints(game.world.seed_value, p.id, 90))
				var country := maxi(Country.COAST, game.world.country_at(floori(p.pos.x), floori(p.pos.y)))
				var pts := PropModels.glow_points(p.kind, variant, country)
				if pts.is_empty():
					# A dead pump, a shack with nothing wired in: no light to give.
					continue
				local = pts[0].at
				var c: Color = pts[0].color
				s.neon = Vector3(c.r, c.g, c.b)
			if p.kind == PropKind.HOUSE:
				# Just outside the front wall, before the window and door.
				var front := _front_of(p.kind)
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
				PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.CHECKPOINT: s.warm = MACHINE_COLD
				_: s.warm = WARM
			if p.kind == PropKind.HOUSE and NEON_HOUSE_VARIANTS.has(PropModels.pick_variant(p.kind, Rng.hash_ints(game.world.seed_value, p.id, 90))):
				var front := _front_of(p.kind)
				s.neon_at = game.world.to_3d(p.pos) + Basis(Vector3.UP, -p.rot) * (Vector3(front.x, 1.05, front.z) * p.scale)
		else:
			s.at = game.world.to_3d(p.pos) + Vector3(0, 4.05 * p.scale, 0)
			s.range = 0.0
			s.power = 0.0
			s.warm = WARM
		sources.append(s)


## Where a house's lit front is, in its own frame: the middle of its glow points.
static func _front_of(kind: int) -> Vector3:
	var pts := glow_points(kind)
	if pts.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for g: Dictionary in pts:
		sum += g.at as Vector3
	return sum / pts.size()


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
	var dark := pool_dark(hour) * (1.0 - clampf(game.sky.flash * 1.6, 0.0, 1.0))
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
			if _set_light(l, s.at, float(s.range), compensate(MACHINE_COLD, tint, sun) * mlevel) and dark > 0.25:
				pools.append(Vector4(s.at.x, s.at.y, s.at.z, float(s.range)))
				pool_rgb.append(Vector4(MACHINE_COLD.x, MACHINE_COLD.y, MACHINE_COLD.z, 0.0) * clampf(mlevel, 0.0, 1.2))
			continue
		var kind := int(s.kind)
		var level: float = s.power
		if kind == PropKind.FIRE or kind == PropKind.VENT or kind == PropKind.KILN:
			# Fires burn by day too, but their light only tells after dusk.
			level *= 0.12 + 0.88 * dark
		else:
			level *= want * dark
			if POWERED_SOURCES.has(kind):
				level *= clampf(game.sky.bolt.w, 0.0, 1.0)
		# A flicker changes how bright the pool is, never how big: the ink's
		# edge must not crawl.
		level *= _flicker(s)
		if _set_light(l, s.at, s.range, compensate(s.warm, tint, sun) * level) and dark > 0.25:
			pools.append(Vector4(s.at.x, s.at.y, s.at.z, s.range))
			var nc: Vector3 = neon_colour(s)
			pool_rgb.append(Vector4(nc.x, nc.y, nc.z, 0.0) * clampf(level, 0.0, 1.2))
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
		var night := maxf(dark, 0.45 * gloom(hour, tint, sun))
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
				if s.has("neon_at"):
					cands.append({"at": s.neon_at, "rgb": NEON_TUBE, "level": 0.95 * smoothstep(0.2, 0.6, want) * power})
			PropKind.SHACK:
				cands.append({"at": s.at, "rgb": neon_colour(s), "level": (0.95 * power if source_lit(s, hour) else 0.0), "shaft": SHAFT_MACHINE})
			PropKind.FIRE_TOWER:
				cands.append({"at": s.at, "rgb": neon_colour(s), "level": (0.8 if source_lit(s, hour) else 0.0) * _flicker(s), "shaft": SHAFT_RAYED})
			PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.CHECKPOINT:
				cands.append({"at": s.at, "rgb": neon_colour(s), "level": (0.8 if source_lit(s, hour) else 0.0) * power, "shaft": SHAFT_MACHINE})
	if lantern_lit:
		cands.append({"at": lantern.position + Vector3(0, 0.1, 0), "rgb": LANTERN_WARM, "level": 0.7, "shaft": SHAFT_RAYED})
	glint_list = Glints.pick(cands, focus3)
	var packed := Glints.pack(glint_list)
	game.sky.glints = packed[0]
	game.sky.glint_colors = packed[1]


var _glow_cache: Dictionary = {}


## PropModels.glow_points(kind), asked once per kind.
func _glow_points_cached(kind: int) -> Array:
	if not _glow_cache.has(kind):
		_glow_cache[kind] = glow_points(kind)
	return _glow_cache[kind]


## The sources and machines that could glint near the focus, nearest first.
func _gather_glints(focus: Vector2) -> void:
	_glint_near.clear()
	var near: Array = []
	for s in sources:
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


static func neon_colour(s: Dictionary) -> Vector3:
	match int(s.kind):
		PropKind.LAMP:
			return Vector3(1.0, 0.72, 0.42)
		PropKind.HOUSE:
			return Vector3(1.0, 0.68, 0.4)
		PropKind.SHACK:
			return s.get("neon", NEON_MAGENTA)
		PropKind.FIRE_TOWER:
			return Vector3(1.0, 0.72, 0.42)
		PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.CHECKPOINT:
			return MACHINE_COLD
		_:
			return NEON_FIRE


## Returns whether the light is on.
func _set_light(l: OmniLight3D, at: Vector3, reach: float, rgb: Vector3) -> bool:
	var e := maxf(rgb.x, maxf(rgb.y, rgb.z))
	if e < 0.01:
		l.visible = false
		return false
	l.visible = true
	l.position = at
	l.omni_range = reach
	# Godot takes light_color as sRGB and linearises it before shading, but the
	# world shader works in display values: hand it the colour pre-encoded.
	l.light_color = Color(rgb.x / e, rgb.y / e, rgb.z / e).linear_to_srgb()
	l.light_energy = e
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
	for s in sources:
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
	for s in sources:
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


## Where a prop gives light, in its own frame: PropModels.glow_points(kind),
## which follows the models' own shapes.
static func glow_points(kind: int) -> Array:
	return PropModels.glow_points(kind)


func _glow_node(s: Dictionary) -> Node3D:
	var p: WorldProp = s.prop
	var pts := glow_points(p.kind)
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
