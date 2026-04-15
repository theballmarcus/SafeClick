extends Node2D

@onready var http_request = $HTTPRequest
@onready var highscore_panel = $Highscore/HighscoreEntries

const HIGHSCORE_ITEM_SCENE := preload("res://graphics/assets/HighscoreItem.tscn")


func _ready() -> void:
	$StartButton.pressed.connect(_on_start_pressed)
	$QuitButton.pressed.connect(_on_quit_pressed)
	
	update_highscores()
	# Fetch first batch of mails
	if Gamestate.mails.size() == 0:
		Gamestate.fetch_mails()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
	
	
func update_highscores():
	http_request.request_completed.connect(_on_request_completed)
	var _response = http_request.request(Gamestate.API_URL + "/highscores", Gamestate.headers, HTTPClient.METHOD_GET)
	
func _on_request_completed(result, response_code, _headers, body):
	print("Response code:", response_code)
	if result != OK:
		print("Request failed!")
		return
	var response_text = body.get_string_from_utf8()

	var data = JSON.new()
	var response_json = data.parse(response_text)
	if response_json == OK:
		if "highscores" in data.data.keys():
			print(data.data)
			
			for n in highscore_panel.get_children():
				#highscore.remove_child(n)
				pass
				
			for entry in data.data['highscores']:
				# fjern nodes i highscore som allerede er der
				var item = HIGHSCORE_ITEM_SCENE.instantiate()
				item.get_node("Control").get_node("Username").text = entry["username"]
				item.get_node("Control").get_node("Score").text = "%d" % entry["highscore"]

				highscore_panel.add_child(item)
	else:
		return
