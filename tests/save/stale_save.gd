extends SceneTree
## Age a save on disk into one from another build, by hand.
##
##   godot --headless --path . -s tests/save/stale_save.gd -- DIR [SLOT] [WAY]
##
## DIR is a folder under user:// (the same name a boot takes as --saves=DIR),
## SLOT defaults to 1, WAY to `version` (see SaveStaging for what each way does).
## The work is SaveStaging's, so what this does by hand and what a tour's `stale`
## command does are the same thing; tours/saves-elsewhere.tour needs neither.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("stale_save: a folder under user:// is needed")
		quit(1)
		return
	var slot := int(args[1]) if args.size() > 1 else 1
	var way := StringName(args[2]) if args.size() > 2 else &"version"
	var path := "user://".path_join(args[0]).path_join("slot_%d.save" % slot)
	var why := SaveStaging.age(path, way)
	if why != "":
		printerr("stale_save: %s" % why)
		quit(1)
		return
	var r := SaveFile.read_header(path)
	print("stale_save: %s is now version %d, read as %s" % [path, r.version, "ok" if r.ok else String(r.code)])
	# The landscape way leaves a file this build still reads: what it moved is
	# only caught once the world is grown (SaveCore.disagrees).
	quit(0 if (r.code == &"elsewhere" if way == &"version" else r.ok) else 1)
