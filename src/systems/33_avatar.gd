extends GameSystem
## The player's own body: the one made on the character page before the game
## began (UiCharacterScreen), put on the figure that walks the coast, kept in the
## save, and handed to the gear system to dress (AvatarState, GearLook).
##
## Where it comes from, first that applies: a loaded save's (key `avatar`), the
## character page's (`BootOptions.avatar`), `--look` tokens (a shot or a tour),
## and otherwise the base body. Numbered before 35_folk and 54_gear so the body is
## on before anything dresses it.
##
## A tour answers with `avatar:KEY=VALUE`: the figure walking the coast has that
## (build=heavy, hair_style=long, skin=fair...), which is the page and the world
## agreeing about who this is.


func setup(g: Game) -> void:
	super.setup(g)
	var state := AvatarState.of(g)
	state.look = AvatarState.bare(_chosen(g.options))
	_put_on()
	SaveGame.register(&"avatar", _save, _load)


static func _chosen(o: BootOptions) -> Dictionary:
	if o == null:
		return PersonLook.BASE.duplicate(true)
	if not o.avatar.is_empty():
		return o.avatar
	if o.look != "":
		return load("res://src/systems/35_folk.gd").call("parse_look", o.look, o.seed_value)
	return PersonLook.BASE.duplicate(true)


## The body on the walking figure. Gear goes on over it afterwards (54_gear), and
## again whenever the loadout changes.
func _put_on() -> void:
	if game.player == null or game.player.model == null:
		return
	game.player.model.set_look(AvatarState.of(game).look)


func _save() -> Variant:
	return {"look": JSON.parse_string(JSON.stringify(AvatarState.of(game).look))}


func _load(v: Variant) -> void:
	if not (v is Dictionary) or not ((v as Dictionary).get("look") is Dictionary):
		return
	# Loads apply in registration order, and this registers before 54_gear: the body
	# goes back on first, and the gear's own load dresses it again over the top.
	AvatarState.of(game).look = AvatarState.bare((v as Dictionary).look)
	_put_on()


func tour_seen(what: StringName) -> bool:
	var s := String(what)
	if not s.begins_with("avatar:") or game.player == null or game.player.model == null:
		return false
	var kv := s.substr(7).split("=")
	if kv.size() != 2:
		return false
	return String(game.player.model.look.get(kv[0], "")) == kv[1]
