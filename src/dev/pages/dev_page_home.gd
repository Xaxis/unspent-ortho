class_name DevPageHome
extends DevPage
## The dev app's first page: every other page, what each stands at, and on the
## panel what this build is and where the player stands.


## A page by its row id here (--dev=PAGE, a key that goes straight to one).
static func page_for(id: StringName) -> DevPage:
	match id:
		&"go": return DevPageGo.new()
		&"time": return DevPageTime.new()
		&"body": return DevPageBody.new()
		&"give": return DevPageGive.new()
		&"spawn": return DevPageSpawn.new()
		&"view": return DevPageView.new()
		&"config": return DevPageConfig.new()
		&"notes": return DevPageNotes.new()
		&"builds": return DevPageBuilds.new()
		&"proofs": return DevPageProofs.new()
	return null


## Counts that read files (notes, the shelf) are read again at most this often (s).
const COUNT_EVERY := 2.0

var _notes := 0
var _shelf := 0
var _counted_at := -INF


func heading() -> String:
	return "HOME"


func _count() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _counted_at < COUNT_EVERY:
		return
	_counted_at = now
	_notes = DevNotes.list().size()
	_shelf = DevBuilds.shelf().size()


func rows() -> Array[Dictionary]:
	_count()
	var out: Array[Dictionary] = []
	if game != null:
		out.append(header("in play"))
		out.append(item(&"go", "go", BiomeRegistry.at(game.world, game.player.pos).display_name.to_lower()))
		out.append(item(&"time", "time and sky", game.clock.label()))
		out.append(item(&"body", "body", _body_value()))
		out.append(item(&"give", "things", "%d carried" % game.inventory.items.size()))
		out.append(item(&"spawn", "bodies", "file %s" % String(DevCheats.file_here(game).level)))
		out.append(item(&"view", "view", "zoom %s" % str(snappedf(game.camera.view_height, 0.1))))
	out.append(header("the game"))
	out.append(item(&"config", "configuration", (GameConfig.active if GameConfig.active != "" else "none") + ("*" if not GameConfig.edits.is_empty() else ""),
		{"edited": not GameConfig.edits.is_empty()}))
	out.append(item(&"notes", "notes", "%d kept" % _notes))
	out.append(header("this machine"))
	out.append(local_only(item(&"builds", "builds", _builds_value())))
	out.append(local_only(item(&"proofs", "proofs", _proofs_value())))
	out.append(header(""))
	out.append(item(&"away", "put dev mode away", "", {"tone": "dev"}))
	return out


func confirm(row: Dictionary) -> void:
	if row.id == &"away":
		if DevMode.access() == &"open":
			refuse("This configuration keeps dev mode open.")
			return
		DevMode.disarm()
		Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
		screen.close()
		return
	var p := page_for(row.id)
	if p != null:
		screen.push_page(p)


func keys(_row: Dictionary) -> Array:
	return [["e", "open"], ["`", "shut"], ["esc", "back"]]


func _body_value() -> String:
	var flags := PackedStringArray()
	if float(GameConfig.value("rules.harm")) <= 0.0:
		flags.append("unhurt")
	if DevSession.fed:
		flags.append("fed")
	if DevSession.unseen:
		flags.append("unseen")
	if DevSession.sheltered:
		flags.append("sheltered")
	return " ".join(flags) if not flags.is_empty() else "%d health" % game.body.health


func _builds_value() -> String:
	if not DevMode.local():
		return ""
	DevJobs.poll()
	if DevJobs.running() and str(DevJobs.job.kind) in ["make", "keep", "deploy", "prove"]:
		return "%s %ds" % [str(DevJobs.job.label), roundi(DevJobs.seconds())]
	return "%d on the shelf" % _shelf


func _proofs_value() -> String:
	if not DevMode.local():
		return ""
	if DevJobs.running() and str(DevJobs.job.kind) in ["gate", "tour", "tests", "canon"]:
		return "%s %ds" % [str(DevJobs.job.label), roundi(DevJobs.seconds())]
	for i in range(DevJobs.history.size() - 1, -1, -1):
		var h: Dictionary = DevJobs.history[i]
		if str(h.kind) in ["gate", "tour", "tests", "canon"]:
			return "%s %s" % [str(h.label), "ok" if int(h.code) == 0 else "failed"]
	return ""


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var y := r.position.y + 8
	y = panel_heading(ci, r, y, "this build", true)
	y = panel_pair(ci, r, y, "build", DevReadout.build_line())
	y = panel_pair(ci, r, y, "runs as", DevMode.host())
	y = panel_pair(ci, r, y, "config", DevReadout.config_line())
	y = panel_pair(ci, r, y, "dev mode", "%s%s" % [String(DevMode.access()), ", armed" if DevMode.armed and DevMode.access() == &"chord" else ""])
	if game != null:
		y += 6
		y = panel_heading(ci, r, y, "here")
		for pair: Array in DevReadout.pairs(game):
			y = panel_pair(ci, r, y, pair[0], pair[1])
	y += 6
	y = panel_heading(ci, r, y, "keys")
	for pair: Array in [["`", "this app, from anywhere"], ["f2", "a note, now"], ["f3", "the readout on the edge"], ["f4", "a picture, nothing of the slate"]]:
		UiSlate.key_cap(ci, Vector2i(panel_x(r) + 4, y - 1), pair[0])
		UiDraw.text(ci, Vector2i(panel_x(r) + 26, y), pair[1], UiTheme.TEXT_DIM)
		y += 13
