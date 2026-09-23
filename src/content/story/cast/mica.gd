## Mica rakes the salt behind the machines' own rakes. A local: colour, never load (docs/STORY.md).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"mica", "name": "Mica", "title": "a brine-raker",
		"at": &"local_salt_flats", "talk": &"mica", "trade": &"gatherer",
		"look": {"build": &"woman", "hair": &"fair", "hair_style": &"crop", "beard": &"none"},
		"wants": "Salt enough to trade.",
		"fears": "The glare, and going blind in it.",
		"hides": "She has watched the salt's keeper stop every dusk and face one way, like somebody waiting.",
	})
