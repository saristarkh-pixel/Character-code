extends Node2D
# the level. one scene serves every day — GameState says which one it is.
# days 1 and 2 are a round trip: collect the honey on the ridge, carry it
# home, feed the Moon. day 3 finds an empty hive, and the night starts there.

# anything below this y counts as fallen out of the world
@export var fall_limit: float = 1400.0
@export var escape_seconds: float = 70.0
# the night begins at the summit, so a retry starts there too
@export var night_start: Vector2 = Vector2(1850, 320)
# how much sky stays reachable above the terrain. without it the camera stops
# at the ground's top edge and the player is pinned to the top of the screen
# whenever they stand on the summit.
@export var sky_headroom: float = 420.0

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var terrain: TileMapLayer = $Terrain
@onready var hud: CanvasLayer = $HUD
@onready var card: CanvasLayer = $Card
@onready var cutscene: Node = $Cutscene
@onready var honey_drops: Node2D = $Honey
@onready var house_lock: StaticBody2D = $HouseLock
@onready var house_door: Area2D = $HouseDoor
@onready var hive: Area2D = $Hive
@onready var rocket: AnimatedSprite2D = $Rocket
@onready var rocket_area: Area2D = $RocketArea
@onready var moon: AnimatedSprite2D = $Background/Moon/MoonSprite
@onready var sky_night: Sprite2D = $SkyLayer/SkyNight
# the clouds are a panel plus a mirrored copy of it, in day and night. the
# mirror is what makes the 320px art tile without a visible seam.
@onready var fog_day: Sprite2D = $Background/Fog/FogDay
@onready var fog_day_mirror: Sprite2D = $Background/Fog/FogDayMirror
@onready var fog_night: Sprite2D = $Background/Fog/FogNight
@onready var fog_night_mirror: Sprite2D = $Background/Fog/FogNightMirror

var start_position: Vector2
var honey_total: int = 0
var honey_got: int = 0
var time_left: float = 0.0
var clock_running: bool = false
# set once the level stops taking input — day over, or the run is decided
var ended: bool = false

func _ready() -> void:
	house_door.body_entered.connect(_on_house_entered)
	hive.body_entered.connect(_on_hive_entered)
	rocket_area.body_entered.connect(_on_rocket_entered)
	_set_camera_limits()

	if GameState.escaping:
		_dress_night()
	else:
		_dress_day()

	# recorded after dressing, because the night moves the player to the summit
	start_position = player.position
	# the camera has no real position until the tree has run a frame, so the
	# snap onto the player has to wait for one
	camera.reset_smoothing.call_deferred()
	hud.fade_in()

# the camera box comes from the painted terrain rather than hand-set numbers,
# so it stays right when the map changes. the bottom is the point of it —
# without it you can see under the floor.
func _set_camera_limits() -> void:
	var used: Rect2i = terrain.get_used_rect()
	var step: Vector2 = Vector2(terrain.tile_set.tile_size) * terrain.scale
	camera.limit_left = int(used.position.x * step.x)
	camera.limit_right = int(used.end.x * step.x)
	camera.limit_bottom = int(used.end.y * step.y)
	camera.limit_top = int(used.position.y * step.y - sky_headroom)

func _physics_process(delta: float) -> void:
	if player.position.y > fall_limit:
		respawn()

	if clock_running and not ended:
		time_left -= delta
		hud.set_clock(time_left)
		if time_left <= 0.0:
			_lose()

# the tilemap only stops you where there are tiles, so walking off the left
# edge drops you forever. this is the floor under that. the clock does not
# stop for it.
func respawn() -> void:
	player.position = start_position
	# without this you land carrying all the speed of the fall
	player.velocity = Vector2.ZERO
	# and without this the camera glides the whole way back
	camera.reset_smoothing()

# --- dressing -------------------------------------------------------------

func _dress_day() -> void:
	sky_night.modulate.a = 0.0
	_fog_alpha(1.0, 0.0)
	moon.play("day")
	hud.set_day(GameState.day)

	# the third morning is the one with nothing on the ridge
	if GameState.is_final_day():
		_clear_honey()
	_wire_honey()
	hud.set_honey(honey_got, honey_total)

	if GameState.day == 1 and not GameState.seen_opening:
		GameState.seen_opening = true
		cutscene.play_opening()
	else:
		house_lock.queue_free()

# entered on a retry after a failed escape — no cutscene, straight to the run
func _dress_night() -> void:
	sky_night.modulate.a = 1.0
	_fog_alpha(0.0, 1.0)
	moon.play("angry")
	hud.set_night()
	hud.hide_honey()
	_clear_honey()
	house_lock.queue_free()
	player.position = night_start
	_start_clock()

# the cloud layer is a panel and its mirror, day and night, so a cross-fade
# has to move all four together
func _fog_alpha(day: float, night: float) -> void:
	fog_day.modulate.a = day
	fog_day_mirror.modulate.a = day
	fog_night.modulate.a = night
	fog_night_mirror.modulate.a = night

# --- honey ----------------------------------------------------------------

# counted from the scene rather than hard-coded, so adding a drop in the
# editor is all it takes
func _wire_honey() -> void:
	honey_total = honey_drops.get_child_count()
	for drop: Node in honey_drops.get_children():
		drop.collected.connect(_on_honey_collected)

# removed rather than freed, so the count below reads 0 in the same frame
func _clear_honey() -> void:
	for drop: Node in honey_drops.get_children():
		honey_drops.remove_child(drop)
		drop.queue_free()

func _on_honey_collected() -> void:
	honey_got += 1
	GameState.carrying = honey_got
	hud.set_honey(honey_got, honey_total)
	hud.bump()

# --- the beats ------------------------------------------------------------

# home with the honey. the day is over.
func _on_house_entered(body: Node2D) -> void:
	if ended or GameState.escaping or not (body is CharacterBody2D):
		return
	if GameState.carrying <= 0:
		return
	_end_day()

func _end_day() -> void:
	ended = true
	player.input_locked = true
	await hud.fade_out()
	GameState.end_day()
	get_tree().reload_current_scene()

# the hive on the third day. nothing in it, and the sun goes down.
func _on_hive_entered(body: Node2D) -> void:
	if ended or GameState.escaping or not (body is CharacterBody2D):
		return
	if not GameState.is_final_day():
		return
	_begin_night()

func _begin_night() -> void:
	GameState.begin_escape()
	hud.set_night()
	hud.hide_honey()
	await cutscene.play_moon_wakes()
	_start_clock()

func _start_clock() -> void:
	time_left = escape_seconds
	clock_running = true
	hud.show_clock()
	hud.set_clock(time_left)

# --- endings --------------------------------------------------------------

func _on_rocket_entered(body: Node2D) -> void:
	if ended or not GameState.escaping or not (body is CharacterBody2D):
		return
	_win()

func _win() -> void:
	ended = true
	clock_running = false
	player.input_locked = true
	# the pilot is aboard, so the one standing outside goes away
	player.anim.hide()
	rocket.play("boarding")
	await get_tree().create_timer(0.7, false).timeout
	rocket.play("launch")
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(rocket, "position:y", rocket.position.y - 1000.0, 1.8)
	await tween.finished
	card.show_card("You got out",
			"It was never a gift. It was rent.\nYou stopped paying, so you left.",
			"Run the night again")

func _lose() -> void:
	ended = true
	clock_running = false
	player.input_locked = true
	hud.set_clock(0.0)
	card.show_card("The Moon came down",
			"Seventy seconds was all the\ncredit you had left.",
			"Run the night again")
