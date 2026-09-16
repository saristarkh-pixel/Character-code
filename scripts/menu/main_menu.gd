extends Node2D
# the main menu. four buttons over a diorama built from the game's own tiles
# and props, plus options and credits panels that fade in over a dim.

const LEVEL_PATH: String = "res://scenes/level_01.tscn"

# how long a panel takes to fade in or out
@export var fade_time: float = 0.14
# how much a button grows when the mouse is over it
@export var hover_scale: float = 1.05

@onready var buttons: VBoxContainer = $UI/Control/Buttons
@onready var dim: ColorRect = $UI/Control/Dim
@onready var options_panel: PanelContainer = $UI/Control/OptionsPanel
@onready var credits_panel: PanelContainer = $UI/Control/CreditsPanel
@onready var music_slider: HSlider = $UI/Control/OptionsPanel/OptionsBox/MusicSlider
@onready var sfx_slider: HSlider = $UI/Control/OptionsPanel/OptionsBox/SfxSlider
@onready var fullscreen_button: Button = $UI/Control/OptionsPanel/OptionsBox/FullscreenButton
@onready var quit_button: Button = $UI/Control/Buttons/QuitButton

# the panel currently up, or null on the plain menu
var open_panel: PanelContainer = null

func _ready() -> void:
	dim.hide()
	options_panel.hide()
	credits_panel.hide()

	$UI/Control/Buttons/StartButton.pressed.connect(_on_start)
	$UI/Control/Buttons/OptionsButton.pressed.connect(open_panel_node.bind(options_panel))
	$UI/Control/Buttons/CreditsButton.pressed.connect(open_panel_node.bind(credits_panel))
	quit_button.pressed.connect(_on_quit)
	$UI/Control/OptionsPanel/OptionsBox/BackButton.pressed.connect(close_panels)
	$UI/Control/CreditsPanel/CreditsBox/BackButton.pressed.connect(close_panels)

	music_slider.value_changed.connect(_on_volume_changed.bind("Music"))
	sfx_slider.value_changed.connect(_on_volume_changed.bind("SFX"))
	fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	# start the controls where the game actually is, without firing their
	# signals and writing the same values straight back
	music_slider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))))
	sfx_slider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))))
	_write_fullscreen_text()

	# quit does nothing in a browser, so hide it on web builds
	if OS.has_feature("web"):
		quit_button.hide()

	_wire_hover()
	# so the arrow keys work the moment the menu opens, without a click first
	$UI/Control/Buttons/StartButton.grab_focus()

# a small grow under the mouse, so the buttons feel alive
func _wire_hover() -> void:
	for panel: Control in [buttons, options_panel, credits_panel]:
		for button: Button in panel.find_children("*", "Button", true, false):
			button.mouse_entered.connect(_on_hover.bind(button, true))
			button.mouse_exited.connect(_on_hover.bind(button, false))
			button.pressed.connect(Sfx.play.bind("select"))

func _on_hover(button: Button, over: bool) -> void:
	# set here rather than in _ready because the button has no size until the
	# container has laid it out
	button.pivot_offset = button.size / 2.0
	var tween: Tween = button.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE * (hover_scale if over else 1.0), 0.08)

# esc backs out of an open panel
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and open_panel != null:
		close_panels()
		get_viewport().set_input_as_handled()

func _on_start() -> void:
	# a new run always begins on the first morning, whatever the last one did
	GameState.reset()
	get_tree().change_scene_to_file(LEVEL_PATH)

# only one panel is ever up, and the dim under it swallows clicks meant for
# the buttons behind
func open_panel_node(panel: PanelContainer) -> void:
	if open_panel == panel:
		close_panels()
		return
	if open_panel != null:
		open_panel.hide()
	open_panel = panel
	_fade_in(dim)
	_fade_in(panel)
	panel.find_children("*", "Button", true, false)[0].grab_focus()

func close_panels() -> void:
	if open_panel == null:
		return
	_fade_out(open_panel)
	_fade_out(dim)
	open_panel = null
	$UI/Control/Buttons/OptionsButton.grab_focus()

func _fade_in(node: Control) -> void:
	node.modulate.a = 0.0
	node.show()
	node.create_tween().tween_property(node, "modulate:a", 1.0, fade_time)

func _fade_out(node: Control) -> void:
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 0.0, fade_time)
	tween.tween_callback(node.hide)

func _on_quit() -> void:
	get_tree().quit()

# music and sound effects each have their own bus and slider. the slider runs
# 0 to 1, the bus wants decibels.
func _on_volume_changed(value: float, bus_name: String) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), linear_to_db(value))

# a plain button rather than a CheckButton, because a CheckButton draws its
# tick from the default theme's icons and there is no pixel art for one
func _on_fullscreen_pressed() -> void:
	var on: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if on else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_write_fullscreen_text()

func _write_fullscreen_text() -> void:
	var on: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_button.text = "Fullscreen: On" if on else "Fullscreen: Off"
