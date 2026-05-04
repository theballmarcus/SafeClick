extends Node2D

@onready var http_request = $HTTPRequest
@onready var highscore_panel = $Highscore/HighscoreEntries
@onready var mouse_icon = $SafeClick/Mouse
@onready var mail_animation = $SafeClick/AnimatedSprite2D

const HIGHSCORE_ITEM_SCENE := preload("res://graphics/assets/HighscoreItem.tscn")

func _ready() -> void:
	update_highscores()
	# Fetch first batch of mails
	if Gamestate.mails.size() == 0:
		Gamestate.fetch_mails()
	
	click_loop()
	
func update_highscores():
	http_request.request_completed.connect(_on_request_completed)
	var _response = http_request.request(Gamestate.API_URL + "/highscores", Gamestate.headers, HTTPClient.METHOD_GET)
	
func _on_request_completed(result, response_code, _headers, body):
	if result != OK:
		return

	var response_text = body.get_string_from_utf8()

	var data = JSON.new()
	var response_json = data.parse(response_text)

	if response_json == OK:

		if "highscores" in data.data:

			for n in highscore_panel.get_children():
				n.queue_free()

			var highscores = data.data["highscores"]

			for i in range(min(highscores.size(), 10)):

				var entry = highscores[i]
				var item = HIGHSCORE_ITEM_SCENE.instantiate()

				item.get_node("Control/Username").text = entry["username"]
				item.get_node("Control/Score").text = str(int(entry["highscore"]))

				var number = item.get_node("Control/Number")

				if i == 0:
					number.text = "🥇"
					number.add_theme_font_size_override("font_size", 34)
				elif i == 1:
					number.text = "🥈"
					number.add_theme_font_size_override("font_size", 34)
				elif i == 2:
					number.text = "🥉"
					number.add_theme_font_size_override("font_size", 34)
				else:
					number.text = "   " + str(i + 1)
					number.position.y = 18
					
				highscore_panel.add_child(item)

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

func _on_start_button_pressed() -> void:
	Sound.play_sound("ButtonClicked")
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_quit_button_pressed() -> void:
	Sound.play_sound("ButtonClicked")
	get_tree().quit()

func _on_tutorial_button_pressed() -> void:
	Sound.play_sound("ButtonClicked")
	get_tree().change_scene_to_file("res://scenes/Tutorial.tscn")

func _on_leaderboard_button_pressed() -> void:
	$Button.visible = true
	$Label.visible = true
	$ColorRect.visible = true
	$Panel.visible = true
	$LeaderboardButton.visible = false

func _on_button_pressed() -> void:
	$Button.visible = false
	$Label.visible = false
	$ColorRect.visible = false
	$Panel.visible = false
	$LeaderboardButton.visible = true
