class_name PropTable
extends RefCounted
## A world's props as packed columns, one row per prop in `WorldData.props`
## order (section by section, then the ones set down later). A WorldProp object
## costs about 1.3 KB resident and a row about 38 B, and a shipped world holds
## ~130k props: the columns are what a streamed world keeps, and WorldProps are
## made from them only where something needs one (the streaming design, S7).
##
## Rows are exact copies: rot, scale and solid are 64-bit like the object's own
## floats, pos a Vector2 like its own, so a view made from a row is the object.
## `solid` is its own column because it is not SOLID[kind] * scale for houses
## (their footprint follows the model) or the plan's works (scale-free).
## `shown` is sparse: only a prop being worked down is not whole.

var kind := PackedByteArray()
var pos := PackedVector2Array()
var rot := PackedFloat64Array()
var scale := PackedFloat64Array()
var solid := PackedFloat64Array()
var variant := PackedInt32Array()
## Row -> the share of the prop still there, for rows under 1.
var shown := {}


static func of(props: Array[WorldProp]) -> PropTable:
	var t := PropTable.new()
	t.kind.resize(props.size())
	t.pos.resize(props.size())
	t.rot.resize(props.size())
	t.scale.resize(props.size())
	t.solid.resize(props.size())
	t.variant.resize(props.size())
	for i in props.size():
		t._write(i, props[i])
	return t


func size() -> int:
	return kind.size()


func append(p: WorldProp) -> void:
	var i := size()
	kind.resize(i + 1)
	pos.resize(i + 1)
	rot.resize(i + 1)
	scale.resize(i + 1)
	solid.resize(i + 1)
	variant.resize(i + 1)
	_write(i, p)


## Bytes the columns hold (not counting `shown`, which is a handful).
func bytes() -> int:
	return kind.size() + pos.size() * 8 + (rot.size() + scale.size() + solid.size()) * 8 + variant.size() * 4


func _write(i: int, p: WorldProp) -> void:
	assert(p.kind >= 0 and p.kind < 256, "a prop kind fits a byte")
	kind[i] = p.kind
	pos[i] = p.pos
	rot[i] = p.rot
	scale[i] = p.scale
	solid[i] = p.solid
	variant[i] = p.variant
	if p.shown < 1.0:
		shown[i] = p.shown
	else:
		shown.erase(i)
