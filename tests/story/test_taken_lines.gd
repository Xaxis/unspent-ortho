extends TestCase
## What is said on the glass when the plan takes somebody, and when a yard going
## dark, a road walked or a road that ended badly settles it (`StoryContent.TAKEN`,
## said by `src/systems/45_taken.gd`).
##
## Two rules, and both were found by somebody being wrong first. A line takes ONE
## `%s` because a line that took two would put the writing of a sentence in the
## hands of whoever emits it. And the glass is not the village: these are said in
## the moment by somebody watching, and what a village says about the same person
## is `SUBARCS`, said later, in a doorway, by somebody who knew them. If those two
## ever become one, the second one stops being worth walking back for.

## Every moment the record can reach, and what the system calls it.
const KEYS := ["took", "freed", "freed_many", "out", "home", "lost", "lost_to"]


func test_every_moment_a_record_can_reach_has_a_line() -> void:
	for k: String in KEYS:
		check(StoryContent.TAKEN.has(k), "the glass has words for %s" % k)
		var line := str(StoryContent.TAKEN.get(k, ""))
		eq(line.count("%s"), 1, "%s takes exactly one name: %s" % [k, line])
		check(line.ends_with(".") and line.length() > 12, "%s is a sentence: %s" % [k, line])
		# What goes in is usually a phrase and not a name, so a line that opens
		# with it opens in lower case — and it says so under a picture of the
		# thing happening. Caught in a real frame, held here so it cannot come
		# back the next time somebody writes a line in a hurry.
		check(not line.begins_with("%s"), "%s does not open on a name: %s" % [k, line])


## A person is never handed a verdict on the glass. The world reports; the story
## is what people make of it afterwards, and nobody is asked to account for a
## walk that went wrong (StorySubarc, the escort's third ending).
func test_nothing_on_the_glass_grades_him() -> void:
	for k: String in KEYS:
		var line := str(StoryContent.TAKEN.get(k, "")).to_lower()
		for ugly: String in ["fail", "lost them", "you did", "your fault", "too late", "should"]:
			check(not line.contains(ugly), "%s says what happened, not what it was worth: %s" % [k, line])


## The glass and the village say different things about one person, or walking
## back to a village to be told what you already read is a wasted walk.
func test_the_glass_and_the_village_are_not_the_same_words() -> void:
	var said: Array[String] = []
	for goal: StringName in StoryContent.SUBARCS:
		var words: Dictionary = StoryContent.SUBARCS[goal]
		for part: String in ["ask", "thanks", "kept", "lost", "lost_to"]:
			for l: String in words.get(part, []):
				said.append(l)
				check(not l.begins_with("%s"), "%s.%s does not open on a name: %s" % [goal, part, l])
	for k: String in KEYS:
		var line := str(StoryContent.TAKEN.get(k, ""))
		check(not said.has(line), "%s is the glass's own line and nobody's dialogue" % k)
