extends SceneTree
## Contact sheet: every PNG in --now (and its namesake in --prev, if given) laid
## out in a grid, prev left and now right, so a change in how the game looks is
## seen in one image.
##   godot --headless --path . -s tools/gd/sheet.gd -- --now=shots/canon/now --prev=shots/canon/prev --out=shots/canon/sheet.png
## Each frame is scaled to --w pixels wide (default 480). Frames that differ from
## prev by more than --tol (mean absolute channel difference, 0..255, default 3)
## get a rust rim; unchanged frames a thin ink rim; frames new since prev a
## pale rim. Prints one line per frame with its difference.

func _initialize() -> void:
	var now_dir := ""
	var prev_dir := ""
	var out := "shots/sheet.png"
	var w := 480
	var tol := 3.0
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		match kv[0]:
			"now": now_dir = kv[1]
			"prev": prev_dir = kv[1]
			"out": out = kv[1]
			"w": w = kv[1].to_int()
			"tol": tol = kv[1].to_float()
	var root := ProjectSettings.globalize_path("res://")
	now_dir = now_dir if now_dir.is_absolute_path() else root.path_join(now_dir)
	if prev_dir != "":
		prev_dir = prev_dir if prev_dir.is_absolute_path() else root.path_join(prev_dir)
	out = out if out.is_absolute_path() else root.path_join(out)
	var names: PackedStringArray = []
	var d := DirAccess.open(now_dir)
	if d == null:
		printerr("sheet: no dir ", now_dir)
		quit(1)
		return
	for f in d.get_files():
		if f.ends_with(".png"):
			names.append(f)
	names.sort()
	if names.is_empty():
		printerr("sheet: no frames in ", now_dir)
		quit(1)
		return
	var pair := prev_dir != ""
	var h := int(w * 9.0 / 16.0)
	var cell_w := (w * 2 + 6) if pair else w
	var cols := 2 if pair else 4
	var rows := ceili(float(names.size()) / cols)
	var pad := 6
	var sheet := Image.create(cols * (cell_w + pad) + pad, rows * (h + pad) + pad, false, Image.FORMAT_RGB8)
	sheet.fill(Color("#1e1c2e"))
	var changed := 0
	for i in names.size():
		var cx := pad + (i % cols) * (cell_w + pad)
		var cy := pad + (i / cols) * (h + pad)
		var now := _load(now_dir.path_join(names[i]), w, h)
		var rim := Color("#454263")
		var diff := -1.0
		if pair:
			var prev_path := prev_dir.path_join(names[i])
			if FileAccess.file_exists(prev_path):
				var prev := _load(prev_path, w, h)
				sheet.blit_rect(prev, Rect2i(0, 0, w, h), Vector2i(cx, cy))
				diff = _diff(prev, now)
				rim = Color("#c47438") if diff > tol else Color("#454263")
				if diff > tol:
					changed += 1
			else:
				rim = Color("#e8dcc0")
			sheet.blit_rect(now, Rect2i(0, 0, w, h), Vector2i(cx + w + 6, cy))
			_frame(sheet, Rect2i(cx + w + 6, cy, w, h), rim)
		else:
			sheet.blit_rect(now, Rect2i(0, 0, w, h), Vector2i(cx, cy))
			_frame(sheet, Rect2i(cx, cy, w, h), rim)
		print("sheet %-32s %s" % [names[i], ("new" if pair and diff < 0.0 else ("diff %.1f" % diff if pair else ""))])
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	print("sheet %d frames, %d changed -> %s" % [names.size(), changed, out])
	quit(0)


func _load(path: String, w: int, h: int) -> Image:
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGB8)
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return img


func _diff(a: Image, b: Image) -> float:
	var total := 0.0
	var n := 0
	for y in range(0, a.get_height(), 3):
		for x in range(0, a.get_width(), 3):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			n += 3
	return total / maxf(1.0, n) * 255.0


func _frame(img: Image, r: Rect2i, c: Color) -> void:
	for x in range(r.position.x - 2, r.end.x + 2):
		for t in 2:
			_px(img, x, r.position.y - 1 - t, c)
			_px(img, x, r.end.y + t, c)
	for y in range(r.position.y - 2, r.end.y + 2):
		for t in 2:
			_px(img, r.position.x - 1 - t, y, c)
			_px(img, r.end.x + t, y, c)


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)
