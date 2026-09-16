extends Area2D
# a spot on the map that makes the player think out loud the first time they
# walk into it. drop one in the level, size its shape, type the line.

@export_multiline var line: String = ""
# which day it speaks on. 0 means every day.
@export var day: int = 1

func _ready() -> void:
	if (day != 0 and day != GameState.day) or GameState.escaping:
		# nothing to say today, and nothing is said during the chase
		queue_free()
		return
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D) or line.is_empty():
		return
	# once per load
	set_deferred("monitoring", false)
	body.speech.say(line)
