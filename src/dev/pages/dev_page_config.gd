class_name DevPageConfig
extends DevPage
## Master configurations: which is in use, every setting it holds (edits are
## live and marked in violet until kept), and keeping, copying, pasting and
## playing it. On the machine the game is built on a configuration is kept in
## the repository's configs/; anywhere else on this device (user://dev/configs).


func heading() -> String:
	return "CONFIGURATION"


func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var name := GameConfig.active if GameConfig.active != "" else "none"
	out.append(item(&"use", "in use", name, {"steps": true, "tone": "dev"}))
	var group := ""
	for r: Dictionary in ConfigSchema.ROWS:
		if r.group != group:
			group = r.group
			out.append(header(group))
		var id: String = r.id
		var v: Variant = GameConfig.value(id)
		var kind := str(r.kind)
		var steps := kind in ["bool", "choice", "int"]
		var extra := {"steps": steps, "edited": GameConfig.edits.has(id), "setting": id}
		if kind == "targets":
			extra["steps"] = false
		out.append(item(StringName(id), str(r.label), ConfigChoices.show(id, v), extra))
	out.append(header("this configuration"))
	var stamped := GameConfig.source == &"stamp"
	out.append(item(&"play", "play it: a new game"))
	out.append(item(&"keep", "keep the edits", "", {"enabled": GameConfig.active != "" and not stamped and not GameConfig.edits.is_empty(),
		"why": "Nothing to keep." if GameConfig.edits.is_empty() else "Keep it under a name first."}))
	out.append(item(&"keep_as", "keep as a new one", ""))
	out.append(item(&"forget", "forget the edits", "", {"enabled": not GameConfig.edits.is_empty(), "why": "Nothing to forget."}))
	out.append(item(&"copy", "copy it out", "json"))
	out.append(item(&"paste", "paste one in", "json"))
	return out


func confirm(row: Dictionary) -> void:
	var id := String(row.id)
	if row.has("setting"):
		var kind := str(ConfigSchema.row(id).kind)
		match kind:
			"text":
				screen.edit_text(row.id, str(GameConfig.value(id)), 40, func(text: String) -> void: report(_setting(id, text)))
			"kit", "fit":
				screen.push_page(DevPageKit.new().for_setting(id))
			"targets":
				screen.push_page(DevPageKit.new().for_setting(id))
			_:
				side(row, 1)
		return
	match row.id:
		&"use":
			refuse("Left and right choose another.")
		&"play":
			if GameConfig.edits.is_empty() or screen.ask("play", "Again: it plays with the edits, kept or not."):
				DevPlay.config(game if game != null else title)
		&"keep":
			report(_said(GameConfig.keep(), "Kept %s." % GameConfig.active))
		&"keep_as":
			screen.edit_text(&"keep_as", _suggest(), 24, func(text: String) -> void:
				report(_said(GameConfig.keep_as(text.strip_edges()), "Kept as %s." % text.strip_edges())))
		&"forget":
			GameConfig.forget_edits()
			report("Forgotten.")
		&"copy":
			DisplayServer.clipboard_set(GameConfig.export_text())
			report("Copied %s." % (GameConfig.active if GameConfig.active != "" else "the settings"))
		&"paste":
			_paste()


func side(row: Dictionary, dir: int) -> void:
	if row.id == &"use":
		if not GameConfig.edits.is_empty():
			refuse("Keep or forget the edits first.")
			return
		var names := Array(GameConfig.names())
		names.push_front("")
		var at := names.find(GameConfig.active)
		var next := str(names[posmod(at + dir, names.size())])
		if DevMode.exported() and next != "" and str(GameConfig.resolve(next).settings.get("dev.access", "off")) == "off" \
				and not screen.ask("off:" + next, "Again: %s shuts dev mode until the game is started again." % next):
			return
		var why := GameConfig.use(next)
		if why != "":
			refuse(why)
			return
		DevMode.write_state()
		Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
		return
	if not row.has("setting"):
		return
	var id: String = row.setting
	if not (str(ConfigSchema.row(id).kind) in ["bool", "choice", "int"]):
		return
	var why := GameConfig.set_value(id, ConfigChoices.step(id, GameConfig.value(id), dir))
	if why != "":
		refuse(why)
		return
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)


func keys(row: Dictionary) -> Array:
	if row.has("setting"):
		var kind := str(ConfigSchema.row(str(row.setting)).kind)
		if kind in ["text"]:
			return [["e", "write"], ["esc", "back"]]
		if kind in ["kit", "fit", "targets"]:
			return [["e", "open"], ["esc", "back"]]
		return [["a d", "change"], ["esc", "back"]]
	if row.get("id") == &"use":
		return [["a d", "another"], ["esc", "back"]]
	return super(row)


func _setting(id: String, value: String) -> String:
	var why := GameConfig.set_value(id, value)
	return "!" + why if why != "" else ""


static func _said(why: String, done: String) -> String:
	return "!" + why if why != "" else done


## A name not yet taken, after the one in use: playtest-2, playtest-3...
func _suggest() -> String:
	var base := GameConfig.active if GameConfig.active != "" and GameConfig.source != &"stamp" else "mine"
	var cut := base.rfind("-")
	if cut > 0 and base.substr(cut + 1).is_valid_int():
		base = base.left(cut)
	var names := GameConfig.names()
	for n in range(2, 100):
		var name := "%s-%d" % [base, n]
		if not names.has(name):
			return name
	return base


func _paste() -> void:
	var text := DisplayServer.clipboard_get()
	var parsed := GameConfig.parse(text, "pasted")
	if not parsed.ok:
		refuse("The clipboard holds no configuration.")
		return
	var problems := ConfigChoices.problems(parsed.settings)
	if not problems.is_empty():
		refuse(problems[0])
		return
	var name := str(parsed.get("name", "pasted"))
	if not GameConfig.valid_name(name):
		name = "pasted"
	if GameConfig.exists(name) and not screen.ask("paste", "Again: it writes over %s." % name):
		return
	GameConfig.forget_edits()
	for id: String in parsed.settings:
		GameConfig.set_value(id, parsed.settings[id])
	report(_said(GameConfig.keep_as(name), "Pasted in as %s." % name))


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var row := screen.menu.selected()
	var y := r.position.y + 8
	y = panel_heading(ci, r, y, GameConfig.active if GameConfig.active != "" else "no configuration", true)
	y = panel_pair(ci, r, y, "from", _where())
	if GameConfig.chain.size() > 1:
		y = panel_pair(ci, r, y, "built on", " on ".join(GameConfig.chain.slice(1)))
	y = panel_pair(ci, r, y, "edits", str(GameConfig.edits.size()) if not GameConfig.edits.is_empty() else "none", VIOLET if not GameConfig.edits.is_empty() else UiTheme.TEXT)
	y += 8
	if row.has("setting"):
		var s := ConfigSchema.row(str(row.setting))
		y = panel_heading(ci, r, y, str(s.label))
		y = panel_wrapped(ci, r, y, str(s.note), UiTheme.TEXT)
		y = panel_pair(ci, r, y, "takes hold", _applies(str(s.applies)))
		y = panel_pair(ci, r, y, "default", ConfigChoices.show(str(row.setting), ConfigSchema.default_of(str(row.setting))))
		if GameConfig.edits.has(str(row.setting)):
			y = panel_pair(ci, r, y, "kept", ConfigChoices.show(str(row.setting), GameConfig.kept_value(str(row.setting))))
		y = panel_pair(ci, r, y, "key", str(row.setting), UiTheme.TEXT_DIM)
		return
	match row.get("id", &""):
		&"use":
			y = panel_wrapped(ci, r, y, "Left and right put another configuration in use: its rules take hold now, and a new game starts as it says.")
			var names := GameConfig.names()
			y = panel_pair(ci, r, y, "here", ", ".join(names) if not names.is_empty() else "none")
		&"play":
			y = panel_wrapped(ci, r, y, "A new game on this configuration's island, started as it says, with its saves kept apart from the player's (user://dev-saves/).")
		&"keep", &"keep_as":
			y = panel_wrapped(ci, r, y, "Written to %s. Only what differs from what it is built on is written." % _dir_words())
		&"copy":
			y = panel_wrapped(ci, r, y, "Every setting that differs from a default, as JSON on the clipboard: it pastes in whole on any other copy of the game.")
		&"paste":
			y = panel_wrapped(ci, r, y, "A configuration copied out of another copy of the game, checked against this one's content, kept under its own name.")


const VIOLET := Color("#b3a8ea")


func _where() -> String:
	match GameConfig.source:
		&"stamp":
			return "this build's stamp"
		&"user":
			return "this device"
		&"file":
			return "configs/"
	return "every default"


func _dir_words() -> String:
	return "configs/ in the repository" if DevMode.local() else "this device"


static func _applies(when: String) -> String:
	match when:
		"live":
			return "now"
		"new":
			return "a new game"
		"boot":
			return "the next start"
		"build":
			return "a build"
	return when
