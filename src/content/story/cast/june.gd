## June Marr, his daughter, the Covenant's Speaker. Never the lead (docs/STORY.md).
## She is there only once her name has been said to him, and she is met in her
## own house, the one nearest the Covenant, at her table (StoryRooms.KEEPERS).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"june", "name": "June", "title": "the Speaker",
		"at": &"the_covenant", "talk": &"june", "trade": &"keeper",
		"look": {"build": &"woman", "hair": &"white", "hair_style": &"bun", "beard": &"none"},
		"appears_when": &"june_named",
		"wants": "Her peace to hold.",
		"fears": "Losing what she built.",
		"hides": "She knows the voice that comforts her is his.",
	})
