class_name PckList
## The file paths inside a Godot 4 .pck (format 2 to 4), read from its directory,
## so a test can say what an export ships without mounting it.


static func paths(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var base := 0
	if f.get_buffer(4).get_string_from_ascii() != "GDPC":
		# A pack embedded at the end of an executable: its header ends the file.
		f.seek(f.get_length() - 12)
		var offset := f.get_64()
		if f.get_buffer(4).get_string_from_ascii() != "GDPC":
			return out
		base = f.get_length() - 12 - offset
		f.seek(base + 4)
	var version := f.get_32()
	f.get_32()
	f.get_32()
	f.get_32()
	var flags := 0
	var dir_offset := 0
	if version >= 2:
		flags = f.get_32()
		f.get_64()
	if version >= 3:
		dir_offset = f.get_64()
	if version >= 3:
		# Flag 2: the directory offset is relative to the file, not the pack.
		f.seek(dir_offset if flags & 2 else base + dir_offset)
	else:
		for i in 16:
			f.get_32()
	var count := f.get_32()
	for i in count:
		var n := f.get_32()
		out.append(f.get_buffer(n).get_string_from_utf8())
		f.get_64()
		f.get_64()
		f.get_buffer(16)
		if version >= 2:
			f.get_32()
	return out
