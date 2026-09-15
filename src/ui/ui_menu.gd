class_name UiMenu
extends RefCounted
## The menu standard, as data: one list; up/down choose and wrap; a held
## direction repeats after 0.35 s, then every 0.06 s. Header rows are skipped.
## Faded rows (enabled = false) are still selectable: confirming one plays
## `refused` and says why, so the player learns what the row needs.
##
## A row is a Dictionary: {header: ...} for a heading, otherwise anything the
## screen wants, with optional `enabled: bool` (default true).

const REPEAT_DELAY := 0.35
const REPEAT_EVERY := 0.06

var rows: Array[Dictionary] = []
## Index into rows of the chosen row; -1 when nothing is selectable.
var index := -1

var _hold_dir := 0
var _hold_time := 0.0
var _next_repeat := 0.0


static func selectable(row: Dictionary) -> bool:
	return not row.has("header")


static func enabled(row: Dictionary) -> bool:
	return bool(row.get("enabled", true))


## Replace the rows. The choice stays on the row whose `key` value matches the
## previously chosen row's (so eating the last mussel does not jump the cursor
## to the top), else on the same position, else on the first selectable row.
func set_rows(new_rows: Array[Dictionary], key: String = "id") -> void:
	var old_value: Variant = selected().get(key) if index >= 0 else null
	var old_index := index
	rows = new_rows
	index = -1
	if old_value != null:
		for i in rows.size():
			if selectable(rows[i]) and rows[i].get(key) == old_value:
				index = i
				return
	if old_index >= 0:
		for i in range(mini(old_index, rows.size() - 1), -1, -1):
			if selectable(rows[i]):
				index = i
				return
	for i in rows.size():
		if selectable(rows[i]):
			index = i
			return


func selected() -> Dictionary:
	if index < 0 or index >= rows.size():
		return {}
	return rows[index]


## One step up (-1) or down (+1), wrapping, skipping headers. True if it moved.
func move(dir: int) -> bool:
	if index < 0 or dir == 0:
		return false
	var i := index
	for n in rows.size():
		i = posmod(i + signi(dir), rows.size())
		if selectable(rows[i]):
			var moved := i != index
			index = i
			return moved
	return false


## Moves due this frame for a direction held on the device (0 = released).
## The first frame of a press moves once; holding repeats per the standard.
func hold(dir: int, delta: float) -> int:
	if dir == 0:
		_hold_dir = 0
		return 0
	if dir != _hold_dir:
		_hold_dir = dir
		_hold_time = 0.0
		_next_repeat = REPEAT_DELAY
		return 1
	_hold_time += delta
	var n := 0
	while _hold_time >= _next_repeat:
		n += 1
		_next_repeat += REPEAT_EVERY
	return n


## Treat `dir` as already held, so a key that was down when the menu opened
## does not scroll it until released and pressed again.
func absorb(dir: int) -> void:
	_hold_dir = dir
	_hold_time = 0.0
	_next_repeat = INF if dir != 0 else REPEAT_DELAY
