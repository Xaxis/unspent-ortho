## Corra burns charcoal in the pinewood and is out of the trees by dusk. A local: colour, never load (docs/STORY.md).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"corra", "name": "Corra", "title": "a charcoal-burner",
		"at": &"local_pinewood", "talk": &"corra", "trade": &"cutter",
		"look": {"build": &"woman", "hair": &"black", "hair_style": &"bun", "beard": &"none"},
		"wants": "The wood to stop getting smaller.",
		"fears": "Being caught moving after curfew.",
		"hides": "She knows what the machines put in the squares they cut.",
	})
