## Sabine Oduya, the crew's medic.
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"sabine", "name": "Sabine", "title": "the crew's medic",
		"at": &"the_camp", "talk": &"sabine", "trade": &"gatherer",
		"look": {"build": &"woman", "hair": &"black", "hair_style": &"tail", "beard": &"none"},
		"may_join": true,
		"wants": "Everyone alive.",
		"fears": "Another burial.",
		"hides": "She saw the body was new, and said nothing for weeks.",
	})
