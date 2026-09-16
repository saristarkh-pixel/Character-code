extends CanvasLayer
# the end-of-run card. one scene for both endings — the caller supplies the
# words. runs on process_mode ALWAYS so it works with the tree frozen.

@export var fade_time: float = 0.3

@onready var root: Control = $Root
@onready var title_label: Label = $Root/Panel/PanelBox/Title
@onready var body_label: Label = $Root/Panel/PanelBox/Body
@onready var retry_button: Button = $Root/Panel/PanelBox/RetryButton
@onready var menu_button: Button = $Root/Panel/PanelBox/MenuButton

const MENU_PATH: String = "res://scenes/main_menu.tscn"

func _ready() -> void:
	visible = false
	retry_button.pressed.connect(_on_retry)
	menu_button.pressed.connect(_on_menu)
	for button: Button in root.find_children("*", "Button", true, false):
		button.mouse_entered.connect(_on_hover.bind(button, true))
		button.mouse_exited.connect(_on_hover.bind(button, false))

func _on_hover(button: Button, over: bool) -> void:
	button.pivot_offset = button.size / 2.0
	var tween: Tween = button.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE * (1.05 if over else 1.0), 0.08)

func show_card(title: String, body: String, retry_text: String) -> void:
	title_label.text = title
	body_label.text = body
	retry_button.text = retry_text
	visible = true
	root.modulate.a = 0.0
	get_tree().paused = true
	root.create_tween().tween_property(root, "modulate:a", 1.0, fade_time)
	retry_button.grab_focus()

# the night is the retry, not the whole story
func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

# unfreeze on the way out, or the menu loads paused and nothing responds
func _on_menu() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().change_scene_to_file(MENU_PATH)
