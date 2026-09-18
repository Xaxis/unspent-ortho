## Otto Vey keeps the war's archive at the Covenant's seat, across the water.
## He is the stop Vera sends Elias to, and the lead down to what lies below.
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"otto", "name": "Otto", "title": "the archivist",
		"at": &"the_archive", "talk": &"otto", "trade": &"keeper",
		"look": {"build": &"old", "hair": &"white", "hair_style": &"thin", "beard": &"full"},
		"wants": "The record kept, all of it, whatever it costs him.",
		"fears": "That nobody will ever read it.",
		"hides": "He took the Covenant's rations to leave the Speaker's name out of the record.",
	})
