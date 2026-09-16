extends Area2D
# the capsule that takes the Moon its honey. once the player carries enough,
# standing next to it shows a prompt, and the interact key loads it and sends
# it up, the same way the rocket leaves at the end. the level hears about it
# through launched and does the rest.

signal launched

# honey the player has to be carrying before the capsule takes it
@export var honey_needed: int = 3
# how far it flies before it is gone, and how long that takes
@export var rise: float = 1000.0
@export var rise_time: float = 1.8
# how long it sits with the hatch open before it takes off
@export var board_time: float = 0.7

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var prompt: Label = $Prompt

# the player, while they stand in range
var player: CharacterBody2D
var gone: bool = false

func _ready() -> void:
	prompt.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		player = body

func _on_body_exited(body: Node2D) -> void:
	if body == player:
		player = null

func usable() -> bool:
	return player != null and not gone and GameState.carrying >= honey_needed

# the prompt follows whether the capsule can be used right now, so it turns up
# the moment the third honey is picked up while standing here
func _process(_delta: float) -> void:
	prompt.visible = usable() and not player.input_locked

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and usable() and not player.input_locked:
		get_viewport().set_input_as_handled()
		_launch()

func _launch() -> void:
	gone = true
	prompt.hide()
	var pilot: CharacterBody2D = player
	pilot.input_locked = true
	Sfx.play("capsule")
	sprite.play("boarding")
	await get_tree().create_timer(board_time, false).timeout

	sprite.play("launch")
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position:y", sprite.position.y - rise, rise_time)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, rise_time) \
			.set_trans(Tween.TRANS_QUAD)
	await tween.finished
	# hidden too, so the map stops drawing it
	sprite.hide()
	pilot.input_locked = false
	launched.emit()
