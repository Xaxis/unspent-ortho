## Ruth Calloway, his CIA handler, in 2029. Stands in the Before (Realm.ERA), relived through a gate
## (docs/STORY.md).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"ruth", "name": "Ruth", "title": "a woman who faces the door",
		"at": &"then_meet", "talk": &"ruth", "trade": &"keeper",
		"look": {"build": &"woman", "hair": &"grey", "hair_style": &"crop", "beard": &"none", "coat": &"long"},
		"wants": "Her country first.",
		"fears": "Losing the asset before the program pays.",
		"hides": "She signed off on THRESHOLD knowing it could kill him.",
	})
