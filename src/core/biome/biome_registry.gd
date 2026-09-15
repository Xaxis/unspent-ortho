class_name BiomeRegistry
## Contract (M2 biomes package implements): the landscape type at a place.
## Until it lands, types are derived from the six M1 countries so readers can be
## written against this API today.
##
##   BiomeRegistry.at(world, tile_pos) -> BiomeDef
##   BiomeRegistry.get_def(id) -> BiomeDef or null
##   BiomeRegistry.all() -> Array[BiomeDef]

static var _defs: Dictionary = {}


static func all() -> Array[BiomeDef]:
	_ensure()
	var out: Array[BiomeDef] = []
	for k: StringName in _defs:
		out.append(_defs[k])
	return out


static func get_def(id: StringName) -> BiomeDef:
	_ensure()
	return _defs.get(id, null)


static func at(w: WorldData, p: Vector2) -> BiomeDef:
	_ensure()
	var c := w.country_at(floori(p.x), floori(p.y))
	return _defs.get(StringName(Country.NAMES[c]), _defs[&"coast"])


static func _ensure() -> void:
	if not _defs.is_empty():
		return
	var hazards := {
		&"sea": {&"wet": 1.0},
		&"coast": {&"wet": 0.3},
		&"moss": {&"wet": 0.6, &"toxins": 0.1},
		&"pinewood": {&"dark": 0.4},
		&"snowfield": {&"cold": 0.7},
		&"bonelands": {&"heat": 0.3},
		&"burning": {&"heat": 0.7, &"fumes": 0.5},
	}
	for i in Country.COUNT:
		var d := BiomeDef.new()
		d.id = StringName(Country.NAMES[i])
		d.display_name = Country.NAMES[i]
		d.hazards = hazards.get(d.id, {})
		d.hatch = Ink.COUNTRY_STYLE[i]
		_defs[d.id] = d
