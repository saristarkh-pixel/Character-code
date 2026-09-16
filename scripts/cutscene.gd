extends Node
# the scripted beats. each one takes the keyboard off the player, runs a
# sequence, and hands it back. no framework, just awaits.

@export var sky_fade: float = 2.0
@export var moon_rise: float = 2.4

@onready var player: CharacterBody2D = $"../Player"
@onready var dialogue: CanvasLayer = $"../Dialogue"
@onready var camera: Camera2D = $"../Player/Camera2D"
@onready var moon: AnimatedSprite2D = $"../Background/Moon/MoonSprite"
@onready var sky_night: Sprite2D = $"../SkyLayer/SkyNight"
# the clouds are a panel plus its mirror, so every fade moves four sprites
@onready var fog_day: Sprite2D = $"../Background/Fog/FogDay"
@onready var fog_day_mirror: Sprite2D = $"../Background/Fog/FogDayMirror"
@onready var fog_night: Sprite2D = $"../Background/Fog/FogNight"
@onready var fog_night_mirror: Sprite2D = $"../Background/Fog/FogNightMirror"
@onready var house_lock: StaticBody2D = $"../HouseLock"

# day 1. you are held at the house until this is over.
func play_opening() -> void:
	player.input_locked = true
	await get_tree().create_timer(0.6, false).timeout
	await dialogue.say("Another morning.")
	await dialogue.say("The hive is up on the ridge. It always is.")
	await dialogue.say("Collect the honey. Bring it home. Feed the Moon.")
	await dialogue.say("That is how it goes.")
	# the box that kept you indoors is not needed again
	if is_instance_valid(house_lock):
		house_lock.queue_free()
	player.input_locked = false

# night of the third day, at the empty summit. the sky goes dark, and the
# thing that was always up there is not up there.
func play_moon_wakes() -> void:
	player.input_locked = true
	await dialogue.say("Nothing. The hive is empty.")

	# dusk. the clouds thin out so nothing is in the way of what comes next.
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sky_night, "modulate:a", 1.0, sky_fade)
	tween.tween_property(fog_night, "modulate:a", 1.0, sky_fade)
	tween.tween_property(fog_night_mirror, "modulate:a", 1.0, sky_fade)
	tween.tween_property(fog_day, "modulate:a", 0.0, sky_fade)
	tween.tween_property(fog_day_mirror, "modulate:a", 0.0, sky_fade)
	tween.tween_property(moon, "modulate:a", 0.0, sky_fade * 0.5)
	await tween.finished

	# look up. the camera lifts and there is nothing to see.
	var look: Tween = camera.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	look.tween_property(camera, "offset:y", -220.0, 1.2)
	await look.finished
	await dialogue.say("The Moon is not there.")
	await get_tree().create_timer(1.0, false).timeout

	# and then it is.
	moon.play("night")
	moon.position.y -= 260.0
	var rise: Tween = create_tween()
	rise.set_parallel(true)
	rise.tween_property(moon, "modulate:a", 1.0, moon_rise * 0.6)
	rise.tween_property(moon, "position:y", moon.position.y + 260.0, moon_rise) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await rise.finished
	await get_tree().create_timer(0.8, false).timeout

	# it changes
	moon.play("transform")
	await moon.animation_finished
	moon.play("angry")
	await dialogue.say("It has not been fed.")
	await dialogue.say("RUN.")

	# camera back on the player, and go
	var back: Tween = camera.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(camera, "offset:y", 0.0, 0.5)
	await back.finished
	player.input_locked = false
