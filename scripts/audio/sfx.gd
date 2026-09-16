extends Node
# every sound effect in the game, played by name. registered as the Sfx
# autoload so menus, the player and cutscenes all reach it the same way, and
# so a sound started just before a scene change keeps playing through it.
# where a name has several files, one is picked at random each time.

const DIR: String = "res://assets/audio/sfx/"

const SOUNDS: Dictionary = {
	"step": ["Step 1.mp3", "Step 2.mp3", "Step 3.mp3", "Step 4.mp3"],
	"jump": ["Jump 1.mp3", "Jump 2.mp3", "Jump 3.mp3", "Jump 4.mp3"],
	"walljump": ["Walljump 1.mp3", "Walljump 2.mp3", "Walljump 3.mp3", "Walljump 4.mp3"],
	"jump_combo": ["Jump combo.mp3"],
	# the night versions of the three above, used once the moon is chasing you
	"jump_night": ["MOONjump 1.mp3", "MOONjump 2.mp3", "MOONjump3.mp3", "MOONjump 4.mp3"],
	"walljump_night": ["MOONwalljump 1.mp3", "MOONwalljump 2.mp3", "MOONwalljump 3.mp3", "MOONwalljump4.mp3"],
	"jump_combo_night": ["MOONjump combo.mp3"],
	"honey": ["Honey pickup sound.mp3"],
	"capsule": ["Sending a capsule.mp3"],
	"moon_smile": ["Moon smiling sound effect.mp3"],
	"day_end_piano": ["End of day cutscene piano.mp3"],
	"day_end_box": ["End of day cutscene honey-box.mp3"],
	"select": ["Selecting an option (menu).mp3"],
}

# how many sounds can overlap. footsteps and jumps pile up fast.
@export var voices: int = 8
# a small random pitch shift so repeated sounds don't sound identical
@export var pitch_jitter: float = 0.05

var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	# menu clicks still have to sound while the tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key: String in SOUNDS:
		var list: Array[AudioStream] = []
		for file: String in SOUNDS[key]:
			list.append(load(DIR + file))
		streams[key] = list
	for i in voices:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		players.append(player)

# plays the named sound on the first free voice. if every voice is busy the
# one that started longest ago is cut off.
func play(key: String) -> AudioStreamPlayer:
	if not streams.has(key):
		print("sfx: no sound called ", key)
		return null
	var player: AudioStreamPlayer = players[0]
	for p: AudioStreamPlayer in players:
		if not p.playing:
			player = p
			break
	# keep the list ordered oldest-first, so players[0] is the one to steal
	players.erase(player)
	players.append(player)
	player.stream = streams[key].pick_random()
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()
	return player

# the night swaps the player's movement sounds for the moon versions
func play_move(key: String) -> void:
	play(key + "_night" if GameState.escaping else key)
