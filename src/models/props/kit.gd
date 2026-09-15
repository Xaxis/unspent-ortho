extends RefCounted
## The two pens a prop is drawn with (docs/ART.md law 3): `made` for
## world.gdshader (hatched, by hand) and `found` for found.gdshader (ruled,
## clean). Builders put each part in the kit it belongs to.

var made := MeshKit.new()
var found := MeshKit.new()


func _init() -> void:
	found.style = Ink.NONE
	found.style2 = Ink.NONE
