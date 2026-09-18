## Teague, the crew's demolitions man. His children died when the hunters answered
## a works his own side broke.
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"teague", "name": "Teague", "title": "the crew's demolitions man",
		"at": &"the_camp", "talk": &"teague", "trade": &"digger",
		"look": {"build": &"heavy", "hair": &"red", "hair_style": &"crop", "beard": &"full"},
		"may_join": true,
		"wants": "Revenge for Lise and Tam.",
		"fears": "Another village burning for the crew.",
		"hides": "He sells the crew's roads to the Covenant, so it can clear a village before the crew hits its works.",
	})
