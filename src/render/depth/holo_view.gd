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
## The tallest roof that may carry one, in world units. Not a taste: at 57
## degrees of pitch a column's foot spends `foot * cos(pitch)` of the half-frame
## before it is any distance away, so past about six units of roof there is no
## distance AHEAD of the player that puts it on the glass at all. See `hung_on`.
const ROOF_MOST := 6.0
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
## How many are IN FRAME, not how many were placed. It meant the latter, and the
## two numbers were 4 and 0: every one of them hung above the top edge while this
## read a confident four (task #116). A count of things built is never evidence
## that anything was drawn -- so this is now set from what the camera answers.
var drawn := 0
## How many buildings within `REACH` carry one at all, before the frame has its
## say. `drawn` alone cannot tell "nothing qualifies here" from "everything that
## qualifies is off the glass", and those want opposite fixes.
var considered := 0
## Every qualifying roof height found this gather, so a street that shows nothing
## can say WHY without a second run.
var roofs := PackedFloat32Array()
## Where each candidate's column really landed on the glass this gather. Filled
## only under UNSPENT_HOLO_DEBUG: it is a formatted string per candidate per
## gather, which is not a thing to pay for in play.
static var _debug := OS.has_environment("UNSPENT_HOLO_DEBUG")
var spans := PackedStringArray()
## The camera to ask. 17_holo hands it over; null in a headless run, where
## nothing is being looked at and every candidate is kept as before.
##
## It is asked rather than computed from constants because the frame MOVES: the
## zoom (`+`/`-` in play) and the target lean both change what fits, and the
## third-person glide (#121) will drop the pitch, which lifts everything further
## up the screen. A baked reach would be wrong the moment any of those ran.
var cam: Camera3D = null

static var _mesh: ArrayMesh = null

var _pool: Array[MeshInstance3D] = []
var _live := 0
var _mats: Array[ShaderMaterial] = []
var _last := Vector2(INF, INF)
## The camera's view size and pitch when the list was last gathered, because
## what fits is the camera's answer and it changes without the player moving.
var _last_shape := Vector2(INF, INF)
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
	var high := forms.fact(v, BiomeForms.HIGH, 0.0)
	if high < 4.0:
		return false
	# AND NOT OVER THE TALLEST, which is the half this had no way to know. The
	# column's foot sits `high + LIFT` up, and under a camera pitched 57 degrees
	# height and distance BOTH carry a thing up the screen and add -- so a foot
	# 15.0 up (a `tower`) or 17.0 (a `spire`) is above the top edge at EVERY
	# distance ahead of the player, and a `stack` at 11.3 survives 1.6 tiles.
	# Measured against a real camera, not derived: tests/render/test_read_reach.gd.
	#
	# So the fiction and the frame disagree here, and the frame wins: the city's
	# towers are too tall to advertise on. `ROOF_MOST` keeps the ones that leave a
	# band worth walking through -- a foot of 5.3 is in frame 5.5 tiles ahead and
	# 12.4 behind. Raising it does not buy more advertising, it buys more of the
	# invisible kind, which is what this cost before (#116: four placed, every one
	# of them between 562 and 1665 pixels above the glass).
	if high > ROOF_MOST:
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


## One building's column: where its foot hangs and how far it stands up from
## there. Kept in ONE place so the frame test below and `_place` cannot drift —
## a filter that measured a different column from the one drawn would hide the
## wrong ones and be very hard to see.
func _column_of(p: WorldProp, country: int) -> Dictionary:
	var forms := BiomeForms.of(country)
	var v := PropModels.variant_of(p, world.seed_value, country)
	var size := 0.8 + Rng.hash01(world.seed_value, p.id, S_SIZE) * 0.5
	var high := forms.fact(v, BiomeForms.HIGH, 4.0)
	return {
		"foot": world.to_3d(p.pos) + Vector3(0.0, high + LIFT, 0.0),
		"size": size,
	}


## Is any of this column inside the picture? ASKED of the camera, never worked
## out from constants: the mesh spans 0..1 in y, so the node's origin is the
## foot and the top is one `TALL * size` above it, and both are unprojected.
##
## No camera (a headless run) keeps everything, which is what this did before.
func _in_frame(p: WorldProp, country: int) -> bool:
	if cam == null:
		return true
	var vp := cam.get_viewport()
	if vp == null:
		return true
	var rect := vp.get_visible_rect().size
	var col := _column_of(p, country)
	var foot: Vector3 = col.foot
	var size := float(col.size)
	# Behind the eye is not in frame, and `unproject_position` answers anyway with
	# a mirrored position that can land inside the rect (flier_view says the rest).
	if (cam.global_transform.affine_inverse() * foot).z > -cam.near:
		return false
	var lo := cam.unproject_position(foot)
	var hi := cam.unproject_position(foot + Vector3(0.0, TALL * size, 0.0))
	if _debug:
		spans.append("foot(%.0f,%.0f)top(%.0f,%.0f)of%dx%d" % [lo.x, lo.y, hi.x, hi.y, int(rect.x), int(rect.y)])
	# Screen y grows DOWNWARD, so the column's top is the SMALLER y. It is in the
	# picture when that span crosses the glass at all.
	if hi.y > rect.y or lo.y < 0.0:
		return false
	# Pixels per world unit through the one door, not off `cam.size`: this is a
	# sixth site of that division and neither audit of them caught it, because it
	# is spelled as a ratio rather than as a texel.
	var half_w := WIDE * size * 0.5 / maxf(CameraRig.units_per_pixel_of(cam, rect.y), 1e-6)
	return maxf(lo.x, hi.x) + half_w >= 0.0 and minf(lo.x, hi.x) - half_w <= rect.x


func follow(focus: Vector2) -> void:
	if world == null or query == null or share <= 0.0:
		_hide_from(0)
		return
	# The focus is not the only thing that decides the list any more: what fits
	# is the camera's, so a player standing still and zooming (or leaning onto a
	# target) has to be gathered again or the street keeps the old answer.
	# Keyed on what a PIXEL covers rather than on `cam.size`, for the same reason
	# as the width above: under the lens `size` never moves, so a zoom would not
	# invalidate this and the street would keep an answer gathered for a frame
	# that no longer exists. The pitch half already caught a lean; the zoom half
	# did not, and only under a projection nothing ships yet.
	var shape := Vector2(CameraRig.units_per_pixel_of(cam, 1080.0), cam.global_rotation.x) \
			if cam != null else Vector2.ZERO
	if focus.distance_to(_last) < RESTEP and shape.is_equal_approx(_last_shape):
		return
	_last = focus
	_last_shape = shape
	var found: Array = []
	considered = 0
	roofs.clear()
	spans.clear()
	for p: WorldProp in query.props_near(focus, REACH):
		if world.depleted.has(p.id):
			continue
		var country := maxi(Country.COAST, world.country_at(floori(p.pos.x), floori(p.pos.y)))
		if p.kind == PropKind.HOUSE:
			var f := BiomeForms.of(country)
			roofs.append(f.fact(PropModels.variant_of(p, world.seed_value, country),
				BiomeForms.HIGH, 0.0))
		if not hung_on(p, world.seed_value, country, share):
			continue
		considered += 1
		# The frame decides, not the radius. A hologram's FOOT is already
		# `high + LIFT` off the ground, and under this camera height and distance
		# both carry a thing UP the screen and ADD -- so one over a `spire` (foot
		# 17.0) is off the top at EVERY distance ahead of the player, and one over
		# a `block` (foot 5.3) only survives 5.5 tiles. Measured against a real
		# camera in tests/render/test_read_reach.gd. `REACH` still bounds the
		# gather, because asking the world for props is the expensive half.
		if not _in_frame(p, country):
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


## The i-th standing column, for anything that wants to ask the camera where it
## really landed rather than trust `drawn`.
func node_at(i: int) -> MeshInstance3D:
	return _pool[i] if i >= 0 and i < _live else null


func _hide_from(from: int) -> void:
	for i in range(from, _live):
		_pool[i].visible = false
	_live = mini(_live, from)


func _place(i: int, p: WorldProp, country: int) -> void:
	var col := _column_of(p, country)
	var node := _slot(i)
	var size := float(col.size)
	var turn := Rng.hash01(world.seed_value, p.id, S_TURN) * TAU
	node.global_transform = Transform3D(
		Basis(Vector3.UP, turn).scaled(Vector3(WIDE * size, TALL * size, WIDE * size)),
		col.foot)
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
