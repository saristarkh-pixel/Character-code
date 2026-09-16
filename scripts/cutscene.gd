extends Node
# the scripted beats. no framework, just awaits. lines are spoken through the
# player's speech, which types them above the head and zooms the camera in.

@export var sky_fade: float = 2.0
@export var moon_rise: float = 2.4
# how long after the capsule sound starts the Moon reacts to it
@export var capsule_time: float = 4.0
# the look at a honey drop: how close, how long the camera takes to get there,
# and how long it stays
@export var focus_zoom: float = 1.6
@export var focus_time: float = 0.6
@export var focus_hold: float = 1.0
# how long the camera takes to snap back from looking up when the chase starts
@export var chase_snap: float = 0.12

@onready var player: CharacterBody2D = $"../Player"
@onready var speech: Node2D = $"../Player/Speech"
@onready var camera: Camera2D = $"../Player/Camera2D"
@onready var moon: AnimatedSprite2D = $"../Background/Moon/MoonSprite"
@onready var sky_night: Sprite2D = $"../SkyLayer/SkyNight"
# the clouds are a panel plus its mirror, so every fade moves four sprites
@onready var fog_day: Sprite2D = $"../Background/Fog/FogDay"
@onready var fog_day_mirror: Sprite2D = $"../Background/Fog/FogDayMirror"
@onready var fog_night: Sprite2D = $"../Background/Fog/FogNight"
@onready var fog_night_mirror: Sprite2D = $"../Background/Fog/FogNightMirror"

# day 1. the player wakes up in the house. they can walk off straight away,
# the line just waits for the fade-in to finish.
func play_opening(line: String) -> void:
	await get_tree().create_timer(0.6, false).timeout
	await speech.say(line)

# the player comes near a honey drop: they stop, and the camera goes over to
# it for a moment so it is clear what they are here for
func show_honey(target: Node2D) -> void:
	player.input_locked = true
	speech.zoom_held = true
	speech.zoom_to(focus_zoom, focus_time)
	var pan: Tween = camera.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pan.tween_property(camera, "offset", target.global_position - player.global_position, focus_time)
	pan.tween_interval(focus_hold)
	pan.tween_callback(func() -> void:
		speech.zoom_held = false
		speech.zoom_to(speech.talk_zoom if speech.busy else 1.0, focus_time))
	pan.tween_property(camera, "offset", Vector2.ZERO, focus_time)
	await pan.finished
	player.input_locked = false

# the capsule has left (it plays its own sound). a moment later it reaches
# the Moon, and the Moon is pleased. the player keeps control throughout.
func play_capsule() -> void:
	await get_tree().create_timer(capsule_time, false).timeout

	# it arrived. the Moon swells for a moment. no smile sound here, that one
	# belongs to the Moon waking up.
	var size: Vector2 = moon.scale
	var smile: Tween = moon.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	smile.tween_property(moon, "scale", size * 1.15, 0.25)
	smile.tween_property(moon, "scale", size, 0.35)
	await smile.finished

# night of the third day, at the empty summit. the sky goes dark, and the
# thing that was always up there is not up there.
func play_moon_wakes() -> void:
	player.input_locked = true
	await speech.say("Nothing. The hive is empty.")

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
	await speech.say("The Moon is not there.")
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
	Sfx.play("moon_smile")
	await moon.animation_finished
	moon.play("angry")
	await speech.say("It has not been fed.")
	# the last line is said zoomed in, then the camera is thrown back down
	# onto the player and the run starts. the level shakes it from there.
	await speech.say("RUN.")
	speech.zoom_to(1.0, chase_snap)
	var back: Tween = camera.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	back.tween_property(camera, "offset:y", 0.0, chase_snap)
	await back.finished
	player.input_locked = false
