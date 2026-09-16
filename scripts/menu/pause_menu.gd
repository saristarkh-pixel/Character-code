extends CanvasLayer
# the in-game pause screen. esc opens and closes it and the tree freezes
# underneath. this node runs on process_mode ALWAYS so it keeps listening,
# and so its fade tween keeps running, while everything else is stopped.
#
# esc is ui_cancel, which godot binds by default, so nothing had to be added
# to the input map.

const MENU_PATH: String = "res://scenes/main_menu.tscn"

@export var fade_time: float = 0.12

@onready var root: Control = $Root
@onready var resume_button: Button = $Root/Panel/PanelBox/ResumeButton

func _ready() -> void:
	visible = false
	resume_button.pressed.connect(resume)
	$Root/Panel/PanelBox/MenuButton.pressed.connect(_quit_to_menu)
	for button: Button in root.find_children("*", "Button", true, false):
		button.mouse_entered.connect(_on_hover.bind(button, true))
		button.mouse_exited.connect(_on_hover.bind(button, false))
		button.pressed.connect(Sfx.play.bind("select"))

func _on_hover(button: Button, over: bool) -> void:
	button.pivot_offset = button.size / 2.0
	var tween: Tween = button.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE * (1.05 if over else 1.0), 0.08)

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# something else froze the tree — an ending card, say. leave it alone.
	if get_tree().paused and not visible:
		return
	get_viewport().set_input_as_handled()
	if visible:
		resume()
	else:
		pause()

func pause() -> void:
	get_tree().paused = true
	visible = true
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, fade_time)
	# so the arrow keys work straight away without reaching for the mouse
	resume_button.grab_focus()

func resume() -> void:
	get_tree().paused = false
	var tween: Tween = root.create_tween()
	tween.tween_property(root, "modulate:a", 0.0, fade_time)
	tween.tween_callback(func() -> void: visible = false)

# unfreeze on the way out, or the menu loads paused and nothing responds
func _quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_PATH)
