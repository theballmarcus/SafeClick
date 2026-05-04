extends Node
const MAX_PLAYERS = 16
var players: Array
var master_volume := 0.2
var volume_multiplier := 0.2
var is_muted := false
var backgroundMusic
var sounds = {
	"ButtonClicked": preload("res://sounds/ButtonClickSound.mp3"),
	"SnakeEat": preload("res://sounds/SnakeEat.mp3"),
	"SnakeGameover": preload("res://sounds/SnakeGameOver.mp3")
}

func _ready():
	for i in MAX_PLAYERS:
		var player = AudioStreamPlayer.new()
		add_child(player)
		players.append(player)
	backgroundMusic = AudioStreamPlayer.new()
	add_child(backgroundMusic)
	
func play_sound(sound_name: String):
	if not sounds.has(sound_name):
		push_warning("Sound not found: %s" % sound_name)
		return
	var sound = sounds[sound_name]

	for player in players:
		if not player.playing:
			player.stream = sound
			player.volume_db = linear_to_db(0 if is_muted else master_volume)
			player.play()
			return player
	push_warning("All audio players busy, couldn't play: %s" % sound_name)
	
	
func linear_to_db(value):
	if value <= 0:
		return -80  
	return 20 * log(value)

func update_volume():
	is_muted = master_volume <= 0.01
	var vol = 0.0 if is_muted else master_volume
	var db = lerp(-40, 0, vol) 
	for player in players:
		player.volume_db = db
	backgroundMusic.volume_db = db
