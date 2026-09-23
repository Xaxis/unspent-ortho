## Liss climbs the green towers, where the machines' roads stop. A local: colour, never load (docs/STORY.md).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"liss", "name": "Liss", "title": "a canopy-climber",
		"at": &"local_green_towers", "talk": &"liss", "trade": &"gatherer",
		"look": {"build": &"slight", "hair": &"dark", "hair_style": &"tail", "beard": &"none"},
		"wants": "To live somewhere the plan has not drawn.",
		"fears": "The day they find a way to look down through leaves.",
		"hides": "She has watched a surveyor stand at the treeline for a whole day and turn back.",
	})
