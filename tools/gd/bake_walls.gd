extends SceneTree
## Writes src/core/prop_walls_table.gd from the models (tools/gd/prop_walls_bake.gd).
## Run through tools/bake_walls.sh.

const Bake := preload("res://tools/gd/prop_walls_bake.gd")
const OUT := "res://src/core/prop_walls_table.gd"


func _init() -> void:
	var src := Bake.table_source()
	if not src.contains("const OF := {"):
		push_error("bake_walls: the bake failed; %s is left as it was" % OUT)
		quit(1)
		return
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f == null:
		push_error("bake_walls: cannot write %s" % OUT)
		quit(1)
		return
	f.store_string(src)
	f.close()
	print("bake_walls: wrote %s (%d bytes)" % [OUT, src.length()])
	quit(0)
