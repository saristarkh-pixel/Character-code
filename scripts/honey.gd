extends Area2D
# one honey drop. bobs where it sits, and pops when the player walks into it.
# it does not keep score itself — it just says it was taken and the level
# counts.

signal collected

# how far it bobs and how long a full up-and-down takes
@export var bob_height: float = 7.0
@export var bob_time: float = 1.4

@onready var sprite: Sprite2D = $Sprite2D

var bob: Tween

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	bob = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(sprite, "position:y", -bob_height, bob_time * 0.5)
	bob.tween_property(sprite, "position:y", 0.0, bob_time * 0.5)

func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	collected.emit()
	Sfx.play("honey")
	# stop it being taken twice while the pop is still playing
	set_deferred("monitoring", false)
	bob.kill()

	var pop: Tween = create_tween()
	pop.set_parallel(true)
	pop.tween_property(sprite, "scale", sprite.scale * 1.6, 0.16)
	pop.tween_property(sprite, "modulate:a", 0.0, 0.16)
	pop.set_parallel(false)
	pop.tween_callback(queue_free)
