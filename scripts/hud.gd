extends CanvasLayer
# the in-game hud. day, honey counter, the escape clock, and a black rect
# used to fade between days.

# how long the control hint stays up, and how long it takes to go
@export var hint_hold: float = 3.5
@export var hint_fade: float = 0.8
@export var day_fade: float = 0.5
# the clock turns this colour and starts pulsing when time is nearly up
@export var panic_color: Color = Color(0.976, 0.412, 0.322, 1)
@export var panic_at: float = 10.0
# the honey icon is a jar strip, empty to full, one frame every 24px
@export var jar_frames: int = 4
@export var icon_scale: float = 2.0

@onready var count_label: Label = $Root/HoneyCount
@onready var day_label: Label = $Root/DayLabel
@onready var clock_label: Label = $Root/ClockLabel
@onready var hint_label: Label = $Root/HintLabel
@onready var icon: Sprite2D = $Root/HoneyIcon
@onready var fade: ColorRect = $Root/Fade
# the level map: the square in the top-right corner, and the whole level on M
@onready var minimap: Control = $Root/Minimap
@onready var full_map: Control = $Root/FullMap

var panicking: bool = false

func _ready() -> void:
	clock_label.hide()
	fade.modulate.a = 0.0
	var tween: Tween = hint_label.create_tween()
	tween.tween_interval(hint_hold)
	tween.tween_property(hint_label, "modulate:a", 0.0, hint_fade)

func set_day(day: int) -> void:
	day_label.text = "Day %d" % day

# the night has no day number, it has a name
func set_night() -> void:
	day_label.text = "Night"

func set_honey(got: int, total: int) -> void:
	count_label.text = "%d / %d" % [got, total]
	# the jar fills up as the drops come in, full on the last one
	var fill: int = 0
	if total > 0:
		fill = roundi(float(got) / float(total) * float(jar_frames - 1))
	icon.region_rect.position.x = 1 + fill * 24

# a quick bump on the icon so a pickup registers even if you were not
# looking at the corner
func bump() -> void:
	var tween: Tween = icon.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", Vector2.ONE * icon_scale * 1.4, 0.08)
	tween.tween_property(icon, "scale", Vector2.ONE * icon_scale, 0.16)

# the night has no honey to count, so the corner goes quiet
func hide_honey() -> void:
	count_label.hide()
	icon.hide()

func show_clock() -> void:
	clock_label.show()

# seconds left, as m:ss. goes red and starts beating near the end.
func set_clock(seconds: float) -> void:
	var left: int = int(ceilf(maxf(seconds, 0.0)))
	clock_label.text = "%d:%02d" % [left / 60, left % 60]
	if seconds <= panic_at and not panicking:
		panicking = true
		clock_label.add_theme_color_override("font_color", panic_color)
		# set here rather than in _ready, the label has no size until laid out
		clock_label.pivot_offset = clock_label.size / 2.0
		var tween: Tween = clock_label.create_tween().set_loops()
		tween.tween_property(clock_label, "scale", Vector2(1.12, 1.12), 0.25)
		tween.tween_property(clock_label, "scale", Vector2.ONE, 0.25)

# black out and back, for the gap between one day and the next
func fade_out() -> void:
	var tween: Tween = fade.create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, day_fade)
	await tween.finished

func fade_in() -> void:
	fade.modulate.a = 1.0
	var tween: Tween = fade.create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, day_fade)
	await tween.finished

# the level hands over its terrain and player once; the full map shares what
# the corner map baked, markers included
func setup_map(terrain: TileMapLayer, player: Node2D) -> void:
	minimap.setup(terrain, player)
	full_map.share(minimap)
