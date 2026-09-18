## Hannah Marr, an ER doctor, in 2029. Stands in the Before (Realm.ERA), relived through a gate
## (docs/STORY.md §6).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"hannah", "name": "Hannah", "title": "his wife",
		"at": &"then_home", "talk": &"hannah", "trade": &"keeper",
		"look": {"build": &"woman", "hair": &"dark", "hair_style": &"bun", "beard": &"none"},
		"wants": "The truth from him.",
		"fears": "That the truth is worse than the lie.",
		"hides": "She found his second phone and never asked.",
	})
