class_name SaveStaging
## A save on disk made to look like one from another build, so that the proofs
## that a save is REFUSED have something real to refuse. No boot flag can fake
## one: the file has to be written by the save code and then aged, or it is not
## the thing the player has on their disk.
##
##   SaveStaging.age(path, &"version")    back to a version-1 file, carrying no
##                                        stamp at all — what every save written
##                                        before WorldStamp existed looks like
##   SaveStaging.age(path, &"landscape")  the stamp left as this build's, but the
##                                        header saying the player stood in
##                                        another landscape: what a worldgen
##                                        stage that moved looks like on load,
##                                        which no stamp can see (SaveCore.disagrees)
##
## Returns "" or why it could not. The data line, the picture and every other
## field are left exactly as they were: the file stays whole and honest about
## what it is. Reached only from a tour's `stale` command and from
## tests/save/stale_save.gd; nothing in a played game calls it.

const WAYS: Array[StringName] = [&"version", &"landscape"]


static func age(path: String, way: StringName) -> String:
	if not WAYS.has(way):
		return "no way of ageing a save called %s" % way
	if not FileAccess.file_exists(path):
		return "no save at %s" % path
	var f := FileAccess.open_compressed(path, FileAccess.READ, SaveFile.MODE)
	if f == null:
		return "cannot read %s" % path
	var head: Variant = JSON.parse_string(f.get_line())
	var body := f.get_line()
	f = null
	if not (head is Dictionary):
		return "%s has no header" % path
	var header: Dictionary = head
	match way:
		&"version":
			header["version"] = SaveFile.OLDEST
			header.erase("stamp")
		&"landscape":
			header["landscape"] = other_land(str(header.get("landscape", "")))
	# Taken again over the changed header, so the file is whole: what is being
	# staged is an older save, never a damaged one.
	header["head_md5"] = SaveFile.header_md5(header)
	var err := SaveFile.store(path, PackedStringArray([JSON.stringify(header, "", false, true), body]))
	return "" if err == OK else error_string(err)


## Any landscape this registry has that is not this one.
static func other_land(id: String) -> String:
	for d in BiomeRegistry.land():
		if String(d.id) != id:
			return String(d.id)
	return id
