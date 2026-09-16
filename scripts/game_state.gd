extends Node
# the one thing that survives a scene change: which day it is, what the
# player is carrying, and whether the moon has woken up yet.
# registered as the GameState autoload in project.godot.

signal day_changed(day: int)

# how many days you feed the moon before there is nothing left to feed it
const FINAL_DAY: int = 3

var day: int = 1
# honey in hand. picked up at the summit, handed over at the house.
var carrying: int = 0
# the night of the final day — the run for the rocket
var escaping: bool = false
# the opening plays once, not again after a failed escape
var seen_opening: bool = false

# back to the first morning. the menu calls this so a second playthrough does
# not start halfway through the story.
func reset() -> void:
	day = 1
	carrying = 0
	escaping = false
	seen_opening = false

func is_final_day() -> bool:
	return day >= FINAL_DAY

# the honey is handed over at the house and the sun comes up again. only days
# 1 and 2 end this way — day 3 never finds any honey to hand over.
func end_day() -> void:
	carrying = 0
	day += 1
	day_changed.emit(day)

# day 3, empty summit. from here on the level loads as night.
func begin_escape() -> void:
	carrying = 0
	escaping = true
