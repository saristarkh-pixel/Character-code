extends Node2D
# the level. one scene serves every day — GameState says which one it is.
# days 1 and 2 are a round trip: collect the honey on the hill, send the Moon
# its capsule, walk home. day 3 finds an empty hive, and the night starts there.

# anything below this y counts as fallen out of the world. the lowest ground
# you can stand on is at 3216, so only the floorless chasm reaches this.
@export var fall_limit: float = 3600.0
# a straight run across the whole map is already about 70 seconds, so this is
# a starting point until the chase has been played
@export var escape_seconds: float = 150.0
# the night begins at the summit, so a retry starts there too
@export var night_start: Vector2 = Vector2(20950, -1216)
# how much sky stays reachable above the terrain. without it the camera stops
# at the ground's top edge and the player is pinned to the top of the screen
# whenever they stand on the summit.
@export var sky_headroom: float = 420.0
# how hard the camera shakes during the chase, doubled once the clock panics
@export var chase_shake: float = 3.0
# how near a honey drop the player has to get before the camera shows it off.
# that happens for the first drop of the run only.
@export var honey_notice: float = 450.0

# the player's thoughts, from player-monologues. only spoken on talk_day.
@export var talk_day: int = 1
@export_multiline var wake_line: String = "* Yawn * Another work day. I've lost count at this point. Well, I gotta harvest the honey on the hill today."
# one per honey picked up, in pickup order. the fourth is skipped if the
# capsule has already gone up.
@export var honey_lines: PackedStringArray = [
	"Nice.",
	"Good, the jar is almost full.",
	"I have enough to feed the moon. Still gotta find one more hive for the company though.",
	"Time to feed the moon.",
]
@export_multiline var capsule_done_line: String = "Alright I think I'm done for today, let's head back home."
@export_multiline var home_line: String = "* Yawn * Home, sweet home."

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var terrain: TileMapLayer = $Terrain
@onready var hud: CanvasLayer = $HUD
@onready var card: CanvasLayer = $Card
@onready var cutscene: Node = $Cutscene
@onready var honey_drops: Node2D = $Honey
@onready var speech: Node2D = $Player/Speech
@onready var day_end: CanvasLayer = $DayEnd
@onready var capsule: Area2D = $Capsule
@onready var house: Sprite2D = $House
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
# the Moon's share has gone up in the capsule. the house ends the day only once
# this is done and every drop has been picked up.
var capsule_sent: bool = false
# set once the level stops taking input — day over, or the run is decided
var ended: bool = false

func _ready() -> void:
	house_door.body_entered.connect(_on_house_entered)
	hive.body_entered.connect(_on_hive_entered)
	rocket_area.body_entered.connect(_on_rocket_entered)
	capsule.launched.connect(_on_capsule_launched)
	_set_camera_limits()

	if GameState.escaping:
		_dress_night()
	else:
		_dress_day()
	_setup_minimap()

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

	if not ended and not player.input_locked and not GameState.honey_shown:
		_notice_honey()

	if clock_running and not ended:
		time_left -= delta
		hud.set_clock(time_left)
		if time_left <= 0.0:
			_lose()

func _process(_delta: float) -> void:
	if clock_running and not ended:
		var amount: float = chase_shake * (2.0 if time_left <= hud.panic_at else 1.0)
		camera.offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))

# the map in the hud corner shows only what the player is heading for: home and
# the honey by day, the hive on the last day, the rocket at night
func _setup_minimap() -> void:
	hud.setup_map(terrain, player)
	if GameState.escaping:
		hud.minimap.add_marker(rocket)
		return
	# the house sprite is 144px wide, far too big for the map at full size
	hud.minimap.add_marker(house, 0.25)
	for drop: Node2D in honey_drops.get_children():
		hud.minimap.add_marker(drop)
	# nothing to load on the last day, so the capsule isn't worth pointing at
	if GameState.is_final_day():
		hud.minimap.add_marker(hive)
	else:
		hud.minimap.add_marker(capsule)

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
		cutscene.play_opening(wake_line)

# entered on a retry after a failed escape — no cutscene, straight to the run
func _dress_night() -> void:
	sky_night.modulate.a = 1.0
	_fog_alpha(0.0, 1.0)
	moon.play("angry")
	hud.set_night()
	hud.hide_honey()
	_clear_honey()
	capsule.queue_free()
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

func _notice_honey() -> void:
	for drop: Node2D in honey_drops.get_children():
		if drop.global_position.distance_to(player.global_position) < honey_notice:
			GameState.honey_shown = true
			cutscene.show_honey(drop)
			return

func _on_honey_collected() -> void:
	honey_got += 1
	GameState.carrying = honey_got
	hud.set_honey(honey_got, honey_total)
	hud.bump()
	if GameState.day != talk_day or honey_got > honey_lines.size():
		return
	# "time to feed the moon" makes no sense once it has been fed
	if honey_got == honey_total and capsule_sent:
		return
	speech.say(honey_lines[honey_got - 1])

# the player loaded the capsule and it has flown. the Moon gets it a moment
# later. if the last drop is already in hand, that's the day's work done.
func _on_capsule_launched() -> void:
	await cutscene.play_capsule()
	capsule_sent = true
	if GameState.day == talk_day and honey_got == honey_total:
		speech.say(capsule_done_line)

# --- the beats ------------------------------------------------------------

# home after the Moon has been fed. the day is over.
func _on_house_entered(body: Node2D) -> void:
	if ended or GameState.escaping or not (body is CharacterBody2D):
		return
	if not capsule_sent or honey_got < honey_total:
		return
	_end_day()

func _end_day() -> void:
	ended = true
	player.input_locked = true
	if GameState.day == talk_day:
		await speech.say(home_line)
	await hud.fade_out()
	# the jar goes in the chest, then the next morning loads
	await day_end.play()
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
	# nothing left to find up here. the only place that matters now is the rocket.
	hud.minimap.clear_markers()
	hud.minimap.add_marker(rocket)
	capsule.queue_free()
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
	camera.offset = Vector2.ZERO
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
			"You left with the honey, back to the H1VE ship.\nThe Moon was never seen again.",
			"Run the night again")

func _lose() -> void:
	ended = true
	clock_running = false
	camera.offset = Vector2.ZERO
	player.input_locked = true
	hud.set_clock(0.0)
	# the number comes from escape_seconds so the card cannot go stale
	card.show_card("The Moon came down",
			"%d seconds was all the\ncredit you had left." % int(escape_seconds),
			"Run the night again")
