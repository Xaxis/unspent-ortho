## Tobias Kerr, who founded Cairn, in 2029. Stands in the Before (Realm.ERA), relived through a gate
## (docs/STORY.md).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"kerr", "name": "Kerr", "title": "Cairn's founder",
		"at": &"then_lab", "talk": &"kerr", "trade": &"keeper",
		"look": {"build": &"man", "hair": &"fair", "hair_style": &"crop", "beard": &"none"},
		"wants": "To be first.",
		"fears": "Second place.",
		"hides": "He took the CIA's money to keep HALCYON his.",
	})
