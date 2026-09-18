class_name HoloView
extends Node3D
## Light standing in the air over a city street (docs/LOOK.md law 2; the owner's
## direction for the Slums: "holograms and advertising and technology
## everywhere").
##
## THE BOARDS ARE NOT THE HOLOGRAMS. `ForeKinds`' sign arm hangs a lit enamel
## board out over a lane, which is advertising and is a lit SURFACE. This is the
## other half and it is a different thing: a column of light with nothing holding
## it up, projected off a roof. Nothing in this game had one in any form.
##
## WHAT IT IS HUNG ON. A hologram belongs to a BUILDING — somebody paid for it
## and it stands over their roof — so it is dealt to the props a landscape built
## upward (`BiomeForms`, the forms in `FORMS`), by the prop's own id, and a
## landscape says what share of its buildings carry one (`BiomeDef.holograms`).
## Nothing is placed in open air by a tile hash, which is the rule the whole
## depth layer keeps: a floating thing with no anchor is not mysterious under an
## orthographic camera, it is a bug, and the player is right to read it as one.
##
## WHY IT CANNOT HIDE ANYTHING, with no cut of its own: it is additive and writes
## no depth, so whatever is behind it is still drawn and still readable through
## it. That is not a saving, it is the reason it is allowed to stand where a
## solid thing would have to stipple out.
##
## The colour is the street's, and it is dealt the way the signs are: sodium,
## mercury and dirty warm white carry it, and the magenta is a COMMERCIAL ACCENT
## dealt rarely (`Towers.SIGN_COLOURS` and the reasoning in slums.gd's header —
## the machines own the violet band and the city may not spend it).

const Towers := preload("res://src/models/props/towers.gd")

## What a hologram may be, in the order the materials are built. SODIUM and dirty
## warm white carry it, and the magenta is dealt rarely as a commercial accent.
##
## THE MERCURY GREEN IS LEFT OUT ON PURPOSE, and the reason is the fiction before
## it is the palette. Mercury is what a municipality stopped maintaining — a
## stairwell, an underpass, a sign nobody replaced — and an advertisement is the
## one thing in this city that still has money in it. It stays on the boards,
## where it is a wall somebody lit; it does not project.
const COLOURS: Array[Color] = [Towers.SIGN_SODIUM, Towers.SIGN_COLOURS[2], Towers.SIGN_MAGENTA]

## How far from the focus a building is asked at all. The pieces are tall, so
## this is wider than the frame's own corner and one is never seen to appear.
const REACH := 24.0
## How many may stand at once, whatever the landscape asks for. A city where
## every roof projects is a fairground.
const MOST := 10
## The column, in tiles, and how far over the roof its foot sits.
const WIDE := 2.6
const TALL := 4.4
const LIFT := 0.7
## Tiles the focus must move before the list is gathered again.
const RESTEP := 0.5

## Salts, so no two decisions about one building share a stream.
const S_TAKE := 0xC0
const S_COLOUR := 0xC1
const S_SIZE := 0xC2
const S_TURN := 0xC3

var world: WorldData
var query: WorldQuery
## 0..1 of this landscape's buildings that carry one. 0 builds nothing at all.
var share := 0.0
var drawn := 0

static var _mesh: ArrayMesh = null

var _pool: Array[MeshInstance3D] = []
var _live := 0
var _mats: Array[ShaderMaterial] = []
var _last := Vector2(INF, INF)
var _keys := PackedInt64Array()


func setup(w: WorldData, q: WorldQuery) -> void:
	world = w
	query = q
	# ONE MATERIAL PER COLOUR. An instance uniform was tried first and silently
	# did nothing through `material_override`: the deal was changed and the frame
	# came back identical, pixel for pixel. Four materials cannot fail that way,
	# and four is the whole palette.
	_mats.clear()
	for c: Color in COLOURS:
		var m := ShaderMaterial.new()
		m.shader = preload("res://src/render/depth/holo.gdshader")
		m.set_shader_parameter("holo_tint", Vector3(c.r, c.g, c.b))
		# Over the ground, the track marks and a flier's pool, under the people and
		# the hit marks: a hologram is in the air, and a body standing in front of
		# one is in front of it. Transparent world geometry at the default 0 is not
		# dimmed, it is ABSENT (CLAUDE.md).
		m.render_priority = 13
		_mats.append(m)


func rebind(w: WorldData, q: WorldQuery) -> void:
	world = w
	query = q
	_last = Vector2(INF, INF)


## Whether THIS building carries one. Deterministic and stable for the life of
## the world, so a save opens on the same street it closed on.
static func hung_on(p: WorldProp, seed_value: int, country: int, share_of: float) -> bool:
	if p.kind != PropKind.HOUSE or share_of <= 0.0 or country < 0:
		return false
	var forms := BiomeForms.of(country)
	var v := PropModels.variant_of(p, seed_value, country)
	# Only what a landscape built UPWARD. A hologram over a cottage is a joke.
	if not BiomeForms.FORMS.has(forms.form(v)):
		return false
	if forms.fact(v, BiomeForms.HIGH, 0.0) < 4.0:
		return false
	return Rng.hash01(seed_value, p.id, S_TAKE) < share_of


## The colour this one throws: SODIUM and dirty warm white, with the magenta
## dealt one time in six as a commercial accent and never as the ground note
## (slums.gd: the machines own the violet band, and what makes the most crowded
## frame in the game legible is that the one violet thing in it is a machine).
##
## THE MERCURY GREEN IS LEFT OUT ON PURPOSE, and the reason is the fiction before
## it is the palette. Mercury is what a municipality stopped maintaining — a
## stairwell, an underpass, a sign nobody replaced — and an advertisement is the
## one thing in this city that still has money in it. It stays on the boards,
## where it is a wall somebody lit; it does not project.
##
## The frame agreed: the first version dealt it and the column came out reading
## teal against a sodium street, which is the exact palette slums.gd's own header
## refuses ("a purple-to-teal gradient is the most copied palette in this genre
## and says nothing about this place").
static func colour_of(p: WorldProp, seed_value: int) -> int:
	var h := Rng.hash01(seed_value, p.id, S_COLOUR)
	if h > 0.84:
		return 2
	return 0 if h < 0.55 else 1


func follow(focus: Vector2) -> void:
	if world == null or query == null or share <= 0.0:
		_hide_from(0)
		return
	if focus.distance_to(_last) < RESTEP:
		return
	_last = focus
	var found: Array = []
	for p: WorldProp in query.props_near(focus, REACH):
		if world.depleted.has(p.id):
			continue
		var country := maxi(Country.COAST, world.country_at(floori(p.pos.x), floori(p.pos.y)))
		if not hung_on(p, world.seed_value, country, share):
			continue
		found.append([p.pos.distance_squared_to(focus), p, country])
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var want := mini(found.size(), MOST)
	# Nothing changed: the same buildings in the same order, so every transform
	# already on the pool is still right.
	var keys := PackedInt64Array()
	keys.resize(want)
	for i in want:
		keys[i] = (found[i][1] as WorldProp).id
	if keys == _keys:
		return
	_keys = keys
	for i in want:
		_place(i, found[i][1] as WorldProp, int(found[i][2]))
	_hide_from(want)
	drawn = want
	_live = want


func _hide_from(from: int) -> void:
	for i in range(from, _live):
		_pool[i].visible = false
	_live = mini(_live, from)


func _place(i: int, p: WorldProp, country: int) -> void:
	var forms := BiomeForms.of(country)
	var v := PropModels.variant_of(p, world.seed_value, country)
	var high := forms.fact(v, BiomeForms.HIGH, 4.0)
	var node := _slot(i)
	var size := 0.8 + Rng.hash01(world.seed_value, p.id, S_SIZE) * 0.5
	var turn := Rng.hash01(world.seed_value, p.id, S_TURN) * TAU
	var base := world.to_3d(p.pos)
	node.global_transform = Transform3D(
		Basis(Vector3.UP, turn).scaled(Vector3(WIDE * size, TALL * size, WIDE * size)),
		base + Vector3(0.0, high + LIFT, 0.0))
	# The colour is the MATERIAL, dealt by the building's own id; the scan's phase
	# comes off the instance's place in the world inside the shader, so nothing
	# has to be set per instance at all.
	node.material_override = _mats[colour_of(p, world.seed_value) % _mats.size()]
	node.visible = true


func _slot(i: int) -> MeshInstance3D:
	while _pool.size() <= i:
		var m := MeshInstance3D.new()
		m.mesh = mesh()
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_pool.append(m)
	return _pool[i]


## Two quads crossed at a right angle, in a unit box: x and z across, y 0..1 up.
## Crossed rather than billboarded because the play camera's yaw is fixed and a
## billboard that turns with a target lean would be the one thing in the frame
## that moved when the camera did.
static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var k := MeshKit.new()
	for s in 2:
		var a := float(s) * PI * 0.5
		var d := Vector2(cos(a), sin(a)) * 0.5
		# Flat white: the colour and the scan's seed both arrive per instance.
		var c := Color(1.0, 1.0, 1.0, 1.0)
		k.quad(Vector3(-d.x, 0.0, -d.y), Vector3(d.x, 0.0, d.y),
			Vector3(d.x, 1.0, d.y), Vector3(-d.x, 1.0, -d.y), c)
	_mesh = k.build()
	return _mesh


## Only the tests want this; a running game shares the one mesh for its life.
static func forget() -> void:
	_mesh = null
