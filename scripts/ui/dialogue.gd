extends CanvasLayer
# one line of text at the bottom of the screen, revealed a letter at a time.
# say() does not return until the player has pressed on, so a cutscene can
# just await it in a row.

signal advanced

@export var chars_per_second: float = 34.0

@onready var root: Control = $Root
@onready var label: Label = $Root/Panel/Line

# only listen while a line is actually up
var waiting: bool = false

func _ready() -> void:
	root.hide()

func _input(event: InputEvent) -> void:
	if not waiting:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		advanced.emit()

func say(text: String) -> void:
	label.text = text
	label.visible_ratio = 0.0
	root.show()
	var tween: Tween = create_tween()
	tween.tween_property(label, "visible_ratio", 1.0,
			maxf(0.25, float(text.length()) / chars_per_second))
	waiting = true
	await advanced
	# the first press finishes the reveal rather than skipping the line
	if tween.is_running():
		tween.kill()
		label.visible_ratio = 1.0
		await advanced
	waiting = false
	root.hide()

# a line that reads itself and moves on, for beats with no reason to wait
func say_for(text: String, hold: float) -> void:
	label.text = text
	label.visible_ratio = 0.0
	root.show()
	var tween: Tween = create_tween()
	tween.tween_property(label, "visible_ratio", 1.0,
			maxf(0.25, float(text.length()) / chars_per_second))
	await tween.finished
	await get_tree().create_timer(hold, false).timeout
	root.hide()
