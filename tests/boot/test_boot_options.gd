extends TestCase
## What a run is started with. A loop that passed a tour's options as ONE quoted
## word booted seed 41101 -- every digit in "--seed=4 --hour=11 ..." -- at the
## default hour with a knife in hand and the sky left to the rules, and the tour
## failed as if the game broke under load (integ-cam, 2026-09-24).


func test_options_run_together_are_refused_by_name() -> void:
	var o := BootOptions.parse(PackedStringArray(["--seed=4 --hour=11 --weather=clear:0 --held=axe_felling"]))
	eq(o.problems.size(), 1, "the joined argument is a problem, said in words: %s" % str(o.problems))
	check(o.problems.size() > 0 and o.problems[0].contains("several options"), "and the words say what is wrong")
	check(o.seed_value != 41101, "and it is never read as a seed made of every digit in it")


func test_options_given_one_to_a_word_are_read() -> void:
	var o := BootOptions.parse(PackedStringArray(["--seed=4", "--hour=11", "--weather=clear:0", "--held=axe_felling"]))
	check(o.problems.is_empty(), "nothing to say: %s" % str(o.problems))
	eq(o.seed_value, 4)
	eq(o.hour, 11.0)
	eq(o.weather, "clear:0")
	eq(o.held, "axe_felling")


func test_a_value_with_a_space_in_it_is_not_a_problem() -> void:
	# Only a second OPTION inside one argument is refused, not a space.
	var o := BootOptions.parse(PackedStringArray(["--place=green towers"]))
	check(o.problems.is_empty(), "a name with a space in it is one option: %s" % str(o.problems))
