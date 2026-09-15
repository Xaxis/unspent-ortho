class_name UiLettering
## Big letters cut from the 5x7 font: each font pixel becomes a block of
## `px` screen pixels, outer corners are rounded off by one pixel so strokes
## read as lettered rather than enlarged, and a little ink is worn away.


static func width(text: String, px: int) -> int:
	var w := 0
	for i in text.length():
		w += (UiFont.glyph_width(text[i]) + 1) * px
	return w - px


## seed 0 draws clean; any other seed wears a few pixels out of the strokes
## (in `wear`, usually the paper colour).
static func draw(ci: CanvasItem, text: String, at: Vector2i, px: int, col: Color, seed: int, wear: Color = UiTheme.PAPER) -> void:
	var x := at.x
	for i in text.length():
		var ch := text[i]
		var rows := UiFont.glyph(ch)
		for r in rows.size():
			for c in rows[r].length():
				if rows[r][c] != "#":
					continue
				var bx := x + c * px
				var by := at.y + r * px
				var up := _on(rows, r - 1, c)
				var down := _on(rows, r + 1, c)
				var left := _on(rows, r, c - 1)
				var right := _on(rows, r, c + 1)
				# An outer corner with no neighbour on either side loses its pixel.
				var tl := 1 if not up and not left else 0
				var tr := 1 if not up and not right else 0
				var bl := 1 if not down and not left else 0
				var br := 1 if not down and not right else 0
				ci.draw_rect(Rect2(bx, by + 1, px, px - 2), col, true)
				ci.draw_rect(Rect2(bx + tl, by, px - tl - tr, 1), col, true)
				ci.draw_rect(Rect2(bx + bl, by + px - 1, px - bl - br, 1), col, true)
				if seed != 0 and Rng.hash01(seed, bx, by, 1) < 0.3:
					var wx := bx + 1 + int(Rng.hash01(seed, bx, by, 2) * (px - 2))
					var wy := by + 1 + int(Rng.hash01(seed, bx, by, 3) * (px - 2))
					ci.draw_rect(Rect2(wx, wy, 1, 1), Color(wear, 0.5), true)
		x += (UiFont.glyph_width(ch) + 1) * px


static func _on(rows: PackedStringArray, r: int, c: int) -> bool:
	return r >= 0 and r < rows.size() and c >= 0 and c < rows[r].length() and rows[r][c] == "#"
