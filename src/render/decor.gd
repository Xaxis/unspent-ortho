class_name Decor
extends RefCounted

var world: WorldData


func _init(w: WorldData) -> void:
	world = w


func build(_ch: TerrainMesher.Chunk) -> ArrayMesh:
	return null
