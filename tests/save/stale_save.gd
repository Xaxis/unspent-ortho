extends SceneTree
## Age a save on disk into one from before WorldStamp existed — a version-1
## file, which is what every save a player already has looks like. Used to prove
## by hand and by tour that such a save is caught and named rather than opened
## onto an island that moved (see tours/saves-elsewhere.tour).
##
##   godot --headless --path . -s tests/save/stale_save.gd -- DIR [SLOT]
##
## DIR is a folder under user:// (the same name a boot takes as --saves=DIR),
## SLOT defaults to 1. The save's data line, its picture and everything else are
## left exactly as they were: only the version goes back to 1, the stamp comes
## off, and the header's md5 is taken again, so the file is whole and honest
## about being old.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("stale_save: a folder under user:// is needed")
		quit(1)
		return
	var path := "user://".path_join(args[0]).path_join("slot_%d.save" % (int(args[1]) if args.size() > 1 else 1))
	if not FileAccess.file_exists(path):
		printerr("stale_save: no save at %s" % path)
		quit(1)
		return
	var f := FileAccess.open_compressed(path, FileAccess.READ, SaveFile.MODE)
	var head: Variant = JSON.parse_string(f.get_line())
	var body := f.get_line()
	f = null
	if not (head is Dictionary):
		printerr("stale_save: %s has no header" % path)
		quit(1)
		return
	var header: Dictionary = head
	header["version"] = 1
	header.erase("stamp")
	header["head_md5"] = SaveFile.header_md5(header)
	var err := SaveFile.store(path, PackedStringArray([JSON.stringify(header, "", false, true), body]))
	if err != OK:
		printerr("stale_save: %s not written (%s)" % [path, error_string(err)])
		quit(1)
		return
	var r := SaveFile.read_header(path)
	print("stale_save: %s is now version %d, read as %s" % [path, r.version, "ok" if r.ok else String(r.code)])
	quit(0 if r.code == &"elsewhere" else 1)
