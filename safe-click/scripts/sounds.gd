extends Node
const MAX_PLAYERS = 16
var players: Array
var backgroundMusic
var sounds = {
	"ButtonClicked": preload("res://sounds/ButtonClickSound.mp3"),
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
			player.volume_db = linear_to_db(0.1)
			player.play()
			return player
	push_warning("All audio players busy, couldn't play: %s" % sound_name)
	
func linear_to_db(value):
	if value <= 0:
		return -80  
	return 20 * log(value)
