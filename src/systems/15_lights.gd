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

const RAYS := preload("res://src/render/weather/rays.gdshader")
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
}

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
				_: s.warm = WARM
		else:
			s.at = game.world.to_3d(p.pos)
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
	var tint: Vector3 = game.sky.last_tint
	var sun: float = game.sky.last_energy
	var want := lamps_wanted(hour)
	# Lamps are lit before dark, but a pool of light only tells once the dark
	# has come: at dusk a lamp is a flame, not a spotlight.
	# A lightning flash drowns the lamps: the page shows, not the pools.
	var dark := pool_dark(hour) * (1.0 - clampf(game.sky.flash * 1.6, 0.0, 1.0))
	var pools: Array[Vector4] = []
	for i in lights.size():
		var l := lights[i]
		var src: Variant = _assigned[i]
		if src == null:
			l.visible = false
			continue
		var s: Dictionary = src
		var kind := int(s.kind)
		var level: float = s.power
		if kind == PropKind.FIRE or kind == PropKind.VENT or kind == PropKind.KILN:
			# Fires burn by day too, but their light only tells after dusk.
			level *= 0.12 + 0.88 * dark
		else:
			level *= want * dark
		# A flicker changes how bright the pool is, never how big: the ink's
		# edge must not crawl.
		level *= _flicker(s)
		if _set_light(l, s.at, s.range, compensate(s.warm, tint, sun) * level) and dark > 0.25:
			pools.append(Vector4(s.at.x, s.at.y, s.at.z, s.range))
	var lit := game.body.lamp_lit
	lantern.visible = lit
	if lit:
		var p := game.player
		var hand := Basis(Vector3.UP, -p.facing) * Vector3(0.12, 0.52, 0.34)
		lantern.position = p.position + hand
		lantern.rotation.y = -p.facing
		lantern.position.y += sin(_time * 5.0) * 0.03 * clampf(p.speed / 3.0, 0.0, 1.0)
		# The lantern's floor: in any gloom it lifts the ground a little. (source 0.45)
		var night := maxf(dark, 0.45)
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
	else:
		lantern_light.visible = false
	pools.resize(mini(pools.size(), SkyLight.MAX_LAMPS))
	game.sky.lamps = pools


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
	# Beacons blink: a second on in three, never in step with each other.
	for id: int in _glows:
		var n: Node3D = _glows[id]
		if n.has_meta("blink"):
			n.visible = fposmod(_time + float(n.get_meta("blink")) * 3.0, 3.0) < 1.1


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
