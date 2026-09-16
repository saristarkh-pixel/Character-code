extends Node2D
# the player's thoughts, typed out in orange above their head. a long line is
# broken into rows, and the rows appear one at a time: the row being typed
# always sits just above the head, and the finished ones get pushed up. the
# text holds long enough to read, then fades. the camera leans in while
# anything is being said, but the player keeps control the whole time.
# say() returns once its line is gone, so a cutscene can await lines in a row.

signal line_finished

# the look of the text: font, orange, and the outline that makes the glow
@export var settings: LabelSettings
@export var chars_per_second: float = 30.0
# how long a finished line stays up: a floor, plus a little per character
@export var min_hold: float = 2.0
@export var hold_per_char: float = 0.045
@export var fade_time: float = 0.3
# how far the camera zooms in while a line is up (1.2 = 20% closer)
@export var talk_zoom: float = 1.2
@export var zoom_time: float = 0.4
# the glow is the text outline, pulsing between these two alphas
@export var glow_low: float = 0.2
@export var glow_high: float = 0.55
@export var glow_period: float = 1.2

# a VBoxContainer that grows upward from this node, so rows stack on top
@onready var lines: VBoxContainer = $Lines
@onready var camera: Camera2D = $"../Camera2D"

# a line is on screen. later calls wait for it to finish.
var busy: bool = false
# set while something else is steering the camera zoom, so lines starting or
# ending in the meantime leave it alone
var zoom_held: bool = false
var zoom_tween: Tween

func _ready() -> void:
	# the pulse edits the outline colour, so this node gets its own copy
	settings = settings.duplicate()
	var glow: Tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	glow.tween_method(_set_glow, glow_low, glow_high, glow_period * 0.5)
	glow.tween_method(_set_glow, glow_high, glow_low, glow_period * 0.5)

func _set_glow(alpha: float) -> void:
	var color: Color = settings.outline_color
	color.a = alpha
	settings.outline_color = color

func say(text: String) -> void:
	# lines queue up rather than cutting each other off
	while busy:
		await line_finished
	busy = true
	if not zoom_held:
		zoom_to(talk_zoom)
	lines.modulate.a = 1.0

	# type the rows one by one. each row is laid out at its full width before
	# it starts, so its centre never shifts while the letters come in.
	for row_text: String in _wrap(text):
		var row := Label.new()
		row.label_settings = settings
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
		row.text = row_text
		row.visible_ratio = 0.0
		lines.add_child(row)
		var typing: Tween = create_tween()
		typing.tween_property(row, "visible_ratio", 1.0,
				maxf(0.05, float(row_text.length()) / chars_per_second))
		await typing.finished

	var tween: Tween = create_tween()
	tween.tween_interval(maxf(min_hold, float(text.length()) * hold_per_char))
	tween.tween_property(lines, "modulate:a", 0.0, fade_time)
	await tween.finished

	for row: Node in lines.get_children():
		lines.remove_child(row)
		row.queue_free()
	busy = false
	line_finished.emit()
	# a queued line picks up inside emit() and sets busy again, so only zoom
	# back out when nothing else is waiting to be said
	if not busy and not zoom_held:
		zoom_to(1.0)

# greedy word wrap against the row width, measured with the real font so the
# breaks match what gets drawn
func _wrap(text: String) -> PackedStringArray:
	var rows := PackedStringArray()
	var width: float = lines.size.x
	var row: String = ""
	for word: String in text.split(" ", false):
		var candidate: String = word if row.is_empty() else row + " " + word
		if row.is_empty() or _width_of(candidate) <= width:
			row = candidate
		else:
			rows.append(row)
			row = word
	if not row.is_empty():
		rows.append(row)
	return rows

func _width_of(text: String) -> float:
	return settings.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			settings.font_size).x + settings.outline_size

# also called by cutscenes that want the zoom to move faster than the default.
# killing the running tween first stops two tweens fighting over the zoom.
func zoom_to(amount: float, time: float = -1.0) -> void:
	if zoom_tween:
		zoom_tween.kill()
	zoom_tween = camera.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	zoom_tween.tween_property(camera, "zoom", Vector2.ONE * amount,
			zoom_time if time < 0.0 else time)
