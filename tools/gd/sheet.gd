extends SceneTree
## Contact sheet: every PNG in --now (and its namesake in --prev, if given) laid
## out in a grid, prev left and now right, so a change in how the game looks is
## seen in one image.
##   godot --headless --path . -s tools/gd/sheet.gd -- --now=shots/canon/now --prev=shots/canon/prev --out=shots/canon/sheet.png
## Each frame is scaled to --w pixels wide (default 480). Frames that differ from
## prev by more than --tol (mean absolute channel difference, 0..255, default 3)
## get a rust rim; unchanged frames a thin ink rim; frames new since prev a
## pale rim. Prints one line per frame with its difference.
##
## Two renderers side by side (tools/canon.sh --web) are the same frames with a
## different question, so the same sheet answers it with three more options:
##   --label-prev=TEXT --label-now=TEXT  say what each side IS, in the game's own
##                        face, on every cell (a pair nobody labelled is a pair
##                        somebody reads backwards)
##   --pairs=DIR          also write each pair at the size a player sees it, one
##                        base frame (1920x1080) a side, to DIR/<name>.png
##   --cols=N             pairs per row on the sheet (default 2 paired, 4 alone)
## and each line also gives the mean luma of both sides, because "the same place
## on a worse night" is first of all a question of how dark it came out.

const BASE := Vector2i(1920, 1080)
const GAP := 8
const INK := Color("#e8dcc0")
const BAND := Color(0.04, 0.04, 0.06, 0.78)


func _initialize() -> void:
	var now_dir := ""
	var prev_dir := ""
	var out := "shots/sheet.png"
	var w := 480
	var tol := 3.0
	var cols := 0
	var label_prev := ""
	var label_now := ""
	var pairs_dir := ""
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		match kv[0]:
			"now": now_dir = kv[1]
			"prev": prev_dir = kv[1]
			"out": out = kv[1]
			"w": w = kv[1].to_int()
			"tol": tol = kv[1].to_float()
			"cols": cols = kv[1].to_int()
			"label-prev": label_prev = kv[1]
			"label-now": label_now = kv[1]
			"pairs": pairs_dir = kv[1]
	var root := ProjectSettings.globalize_path("res://")
	now_dir = now_dir if now_dir.is_absolute_path() else root.path_join(now_dir)
	if prev_dir != "":
		prev_dir = prev_dir if prev_dir.is_absolute_path() else root.path_join(prev_dir)
	if pairs_dir != "":
		pairs_dir = pairs_dir if pairs_dir.is_absolute_path() else root.path_join(pairs_dir)
		DirAccess.make_dir_recursive_absolute(pairs_dir)
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
	if cols <= 0:
		cols = 2 if pair else 4
	var rows := ceili(float(names.size()) / cols)
	var pad := 6
	var sheet := Image.create(cols * (cell_w + pad) + pad, rows * (h + pad) + pad, false, Image.FORMAT_RGB8)
	sheet.fill(Color("#1e1c2e"))
	var changed := 0
	for i in names.size():
		var cx := pad + (i % cols) * (cell_w + pad)
		var cy := pad + (i / cols) * (h + pad)
		var now_full := _load(now_dir.path_join(names[i]), BASE.x, BASE.y)
		var now := _scaled(now_full, w, h)
		var rim := Color("#454263")
		var diff := -1.0
		var lumas := ""
		var title := names[i].get_basename()
		# Caption type scales with the cell, so a small sheet stays legible.
		var small := maxi(1, int(round(w / 640.0)))
		if pair:
			var prev_path := prev_dir.path_join(names[i])
			if FileAccess.file_exists(prev_path):
				var prev_full := _load(prev_path, BASE.x, BASE.y)
				var prev := _scaled(prev_full, w, h)
				sheet.blit_rect(prev, Rect2i(0, 0, w, h), Vector2i(cx, cy))
				diff = _diff(prev, now)
				lumas = "  luma %5.1f | %5.1f" % [_luma(prev), _luma(now)]
				rim = Color("#c47438") if diff > tol else Color("#454263")
				if diff > tol:
					changed += 1
				if label_prev != "":
					_caption(sheet, Vector2i(cx, cy), "%s  %s" % [title, label_prev], small)
				if pairs_dir != "":
					_write_pair(pairs_dir.path_join(names[i]), prev_full, now_full,
						"%s  %s" % [title, label_prev], "%s  %s" % [title, label_now])
			else:
				rim = Color("#e8dcc0")
			sheet.blit_rect(now, Rect2i(0, 0, w, h), Vector2i(cx + w + 6, cy))
			_frame(sheet, Rect2i(cx + w + 6, cy, w, h), rim)
			if label_now != "":
				_caption(sheet, Vector2i(cx + w + 6, cy), label_now, small)
		else:
			sheet.blit_rect(now, Rect2i(0, 0, w, h), Vector2i(cx, cy))
			_frame(sheet, Rect2i(cx, cy, w, h), rim)
		print("sheet %-32s %s%s" % [names[i], ("new" if pair and diff < 0.0 else ("diff %.1f" % diff if pair else "")), lumas])
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	print("sheet %d frames, %d changed -> %s" % [names.size(), changed, out])
	if pairs_dir != "":
		print("sheet pairs at %dx%d a side -> %s" % [BASE.x, BASE.y, pairs_dir])
	quit(0)


## A frame at the base's size, whatever it was saved at: a tour's desktop frames
## are 2x nearest, a web build's are 1x, and both hold the same 1920x1080 image.
func _load(path: String, w: int, h: int) -> Image:
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGB8)
	if img.get_width() != w or img.get_height() != h:
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return img


func _scaled(img: Image, w: int, h: int) -> Image:
	var out := img.duplicate() as Image
	out.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return out


func _write_pair(path: String, left: Image, right: Image, left_label: String, right_label: String) -> void:
	var img := Image.create(BASE.x * 2 + GAP, BASE.y, false, Image.FORMAT_RGB8)
	img.fill(Color("#1e1c2e"))
	img.blit_rect(left, Rect2i(Vector2i.ZERO, BASE), Vector2i.ZERO)
	img.blit_rect(right, Rect2i(Vector2i.ZERO, BASE), Vector2i(BASE.x + GAP, 0))
	_caption(img, Vector2i.ZERO, left_label, 2)
	_caption(img, Vector2i(BASE.x + GAP, 0), right_label, 2)
	img.save_png(path)


## Words in the slate's own face on a dark band, top-left of a cell.
func _caption(img: Image, at: Vector2i, text: String, scale: int) -> void:
	var unit := UiFont.PITCH * scale
	var tw := UiFont.width(text) * scale
	var th := UiFont.ROWS * unit
	var band := Rect2i(at, Vector2i(tw + 12 * scale, th + 8 * scale))
	for y in range(band.position.y, band.end.y):
		for x in range(band.position.x, band.end.x):
			if x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(BAND.r, BAND.g, BAND.b), BAND.a))
	var pen := at + Vector2i(6 * scale, 4 * scale)
	for i in text.length():
		var ch := text[i]
		var rows := UiFont.glyph_cut(ch)
		for r in rows.size():
			for x in rows[r].length():
				if rows[r][x] != "#":
					continue
				for sy in scale:
					for sx in scale:
						_px(img, pen.x + x * scale + sx, pen.y + r * scale + sy, INK)
		pen.x += (UiFont.glyph_width(ch) + 1) * unit if not rows.is_empty() else 3 * unit


func _luma(img: Image) -> float:
	var total := 0.0
	var n := 0
	for y in range(0, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			var c := img.get_pixel(x, y)
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return total / maxf(1.0, n) * 255.0


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
