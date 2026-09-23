## Wren keeps a light below ground and listens to the river. A local: colour, never load (docs/STORY.md).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"wren", "name": "Wren", "title": "a lampwright",
		"at": &"local_limestone_caves", "talk": &"wren", "trade": &"keeper",
		"look": {"build": &"slight", "hair": &"dark", "hair_style": &"long", "beard": &"none"},
		"wants": "To hear the end of what the hum is counting.",
		"fears": "Light, near the water.",
		"hides": "She has heard something under the caves counting, and never got past its number.",
	})
