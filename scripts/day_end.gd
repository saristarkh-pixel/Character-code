extends CanvasLayer
# the short scene at home that closes each day: the player walks in and puts
# the spare honey jar in the chest. drawn at 160x90 and shown at 7x, so it
# lands on whole pixels with a thin black border around it.

@export var fps: float = 10.0
# the frame where the jar lands on the chest, for the honey-box sound
@export var box_frame: int = 21
# a beat on the last frame before the next day loads
@export var hold: float = 0.6

@onready var sprite: AnimatedSprite2D = $Sprite

func _ready() -> void:
	visible = false
	sprite.frame_changed.connect(_on_frame_changed)

func _on_frame_changed() -> void:
	if sprite.is_playing() and sprite.frame == box_frame:
		Sfx.play("day_end_box")

func play() -> void:
	visible = true
	Sfx.play("day_end_piano")
	sprite.sprite_frames.set_animation_speed("default", fps)
	sprite.play("default")
	await sprite.animation_finished
	await get_tree().create_timer(hold, false).timeout
