extends Node2D

@onready var http_request = $HTTPRequest
@onready var highscore_panel = $Highscore/HighscoreEntries
@onready var mouse_icon = $SafeClick/Mouse
@onready var mail_animation = $SafeClick/AnimatedSprite2D

const HIGHSCORE_ITEM_SCENE := preload("res://graphics/assets/HighscoreItem.tscn")


func _ready() -> void:
	$StartButton.pressed.connect(_on_start_pressed)
	$QuitButton.pressed.connect(_on_quit_pressed)
	
	update_highscores()
	# Fetch first batch of mails
	if Gamestate.mails.size() == 0:
		Gamestate.fetch_mails()
	
	click_loop()

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

func play_click_animation():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(mouse_icon, "scale", Vector2(0.9, 0.9), 0.15)
	mail_animation.play()
	await tween.finished
	var tween2 = create_tween().set_parallel(true)
	tween2.tween_property(mouse_icon, "scale", Vector2(1, 1), 0.15)

	
func click_loop():
	while true:
		play_click_animation()
		await get_tree().create_timer(2.5).timeout
