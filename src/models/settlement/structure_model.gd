class_name StructureModel
extends Node3D
## One piece of a holding, drawn (docs/VISION.md §9, docs/ART.md §10 and §12).
##
## Two meshes and no more: one MADE (world.gdshader — hatched, crooked, earth and
## sand) and one FOUND (found.gdshader — ruled, riveted, unhatched violet plate
## with amber where a machine still runs). A first shelter has only the first; a
## hut has both, which is what MENDED means and why the join is composed on
## rather than hidden. A spinner has a third node, because a rotor that turns
## when there is wind in it says the holding has power before any readout does.
##
## Look at them:
##   tools/shot.sh shots/settlement/gallery.png --scene=gallery --filter=hut
##   tools/shot.sh shots/settlement/noon.png --holding=hut,plot,palisade --seed=1
##
## **A hearth is not drawn here.** It is put into the world as the game's own
## campfire (`PropKind.FIRE`), so it lights the yard, warms a body, can be slept
## by and sounds like a fire, none of which a model of my own would do. The
## holding only records that it has one, what it costs to keep and that its smoke
## gives the place away.

const Shelter := preload("res://src/models/settlement/settle_shelter.gd")
const Ground := preload("res://src/models/settlement/settle_ground.gd")
const Power := preload("res://src/models/settlement/settle_power.gd")
const Defence := preload("res://src/models/settlement/settle_defence.gd")

## Drawings per kind. Eight is the props' own cap and the same reasoning: enough
## that no two pieces in a yard are the same, few enough that the meshes for a
## whole holding are baked once and shared by every piece of a kind.
const VARIANTS := 8
## How fast a spinner's rotor turns at full power (radians a second). Slow enough
## to read as a bodged thing rather than a fan.
const SPIN_FULL := 2.6

var kind := StructureKind.LEAN_TO
var variant := 0
var ruined := false
## A machine's own light still burning on this piece: a battery with charge in it,
## a mast with power. Off, the lens is dead and cold.
var lit := false
var _made: MeshInstance3D
var _found: MeshInstance3D
var _rotor: Node3D
var _spin := 0.0
## kind|variant|ruined|lit -> [made mesh, found mesh, rotor mesh or null]
static var _cache: Dictionary = {}


static func create(piece_kind: int, piece_variant: int) -> StructureModel:
	var m := StructureModel.new()
	m.kind = piece_kind
	m.variant = piece_variant % VARIANTS
	m.name = "piece_%s" % StructureKind.display_name(piece_kind).replace(" ", "_")
	return m


## Whether this package draws the kind at all. A hearth is the world's own fire
## (see the header), so nothing here draws one.
static func drawn(piece_kind: int) -> bool:
	return piece_kind != StructureKind.HEARTH and StructureKind.buildable(piece_kind)


## `made` is the world material (`WorldView.world_material`). Left null — as the
## gallery does — the made half takes whatever the scene fills in.
func build(made: Material) -> void:
	_made = MeshInstance3D.new()
	_made.name = "made"
	if made != null:
		_made.material_override = made
	add_child(_made)
	_found = MeshInstance3D.new()
	_found.name = "found"
	_found.material_override = PropModels.found_material()
	add_child(_found)
	if kind == StructureKind.WIND_SPINNER:
		_rotor = Node3D.new()
		_rotor.name = "rotor"
		var blades := MeshInstance3D.new()
		blades.name = "blades"
		blades.material_override = PropModels.found_material()
		_rotor.add_child(blades)
		add_child(_rotor)
	set_process(_rotor != null)
	_apply()


func set_ruined(on: bool) -> void:
	if on == ruined:
		return
	ruined = on
	_apply()


func set_lit(on: bool) -> void:
	if on == lit:
		return
	lit = on
	_apply()


## How hard the wind is in it, 0..1. A spinner standing still in still air is the
## holding saying it has no power tonight.
func set_spin(share: float) -> void:
	_spin = clampf(share, 0.0, 1.0) * SPIN_FULL


func _process(delta: float) -> void:
	if _rotor != null and _spin > 0.0:
		_rotor.rotate_x(_spin * delta)


func _apply() -> void:
	var meshes := _meshes(kind, variant, ruined, lit)
	if _made != null:
		_made.mesh = meshes[0]
	if _found != null:
		_found.mesh = meshes[1]
	if _rotor != null:
		(_rotor.get_child(0) as MeshInstance3D).mesh = meshes[2]
		_rotor.position = Power.HUB_RUINED if ruined else Power.HUB


static func _meshes(piece_kind: int, v: int, broken: bool, on: bool) -> Array:
	var key := "%d|%d|%d|%d" % [piece_kind, v, int(broken), int(on)]
	if _cache.has(key):
		return _cache[key]
	var made := MeshKit.new()
	var found := MeshKit.new()
	var rotor: MeshKit = null
	match piece_kind:
		StructureKind.LEAN_TO:
			Shelter.lean_to(made, v, broken)
		StructureKind.HUT:
			Shelter.hut_made(made, v, broken)
			Shelter.hut_found(found, v, broken)
		StructureKind.STORE:
			Shelter.store(made, v, broken)
		StructureKind.PLOT:
			Ground.plot(made, v, broken)
		StructureKind.CATCHMENT:
			Ground.catchment_made(made, v, broken)
			Ground.catchment_found(found, v, broken)
		StructureKind.WIND_SPINNER:
			Power.spinner_made(made, v, broken)
			Power.spinner_found(found, v, broken)
			rotor = MeshKit.new()
			Power.spinner_rotor(rotor, v, broken)
		StructureKind.BATTERY_STACK:
			Power.battery_made(made, v, broken)
			Power.battery_found(found, v, broken, on)
		StructureKind.RADIO_MAST:
			Power.mast_made(made, v, broken)
			Power.mast_found(found, v, broken, on)
		StructureKind.PALISADE:
			Defence.palisade(made, v, broken)
		StructureKind.PLATE_WALL:
			Defence.plate_wall_made(made, v, broken)
			Defence.plate_wall_found(found, v, broken)
		StructureKind.NETTING:
			Defence.netting(made, v, broken)
		_:
			if drawn(piece_kind):
				push_warning("no drawing for structure %s" % StructureKind.display_name(piece_kind))
	var out: Array = [made.build(), found.build(), rotor.build() if rotor != null else null]
	_cache[key] = out
	return out


## Every piece a player can build, and each of them wrecked beside itself: what a
## raid leaves is half of what a settlement is, so it is reviewed next to the
## thing it was (docs/ART.md §10, damage is drawn and not tinted).
##
##   tools/shot.sh shots/settlement/gallery.png --scene=gallery --filter=holding
static func gallery() -> Array:
	var out: Array = []
	for piece_kind: int in StructureKind.BUILDABLE:
		if not drawn(piece_kind):
			continue
		for broken: bool in [false, true]:
			out.append(_shown(piece_kind, 3, broken,
				"holding %s%s" % [StructureKind.display_name(piece_kind), " wrecked" if broken else ""]))
	# Four huts side by side: the proof that nothing here is prefabricated.
	for v in 4:
		out.append(_shown(StructureKind.HUT, v, false, "holding hut %d" % v))
	return out


static func _shown(piece_kind: int, v: int, broken: bool, label: String) -> Dictionary:
	var m := StructureModel.create(piece_kind, v)
	m.lit = true
	m.build(null)
	m.set_ruined(broken)
	m.set_spin(0.0)
	var holder := Node3D.new()
	holder.add_child(m)
	return {"name": label, "node": holder}
