extends Node

@onready var http_request = $HTTPRequest
@onready var username_input = $UsernameInput
@onready var score_label = $ScoreLabel
@onready var submit_button = $SubmitButton


func _ready() -> void:
	pass
	submit_button.pressed.connect(_on_submit_pressed)
	http_request.request_completed.connect(_on_request_completed)
	score_label.text = "Du fik %d i score!" % [Gamestate.user_score]

func _process(delta: float) -> void:
	pass

func _on_submit_pressed():
	Sound.play_sound("ButtonClicked")
	if username_input.text.length() == 0:
		return
	var data = {
		"username" : username_input.text,
		"highscore" : Gamestate.user_score
	}
	var payload = JSON.stringify(data)

	var _response = http_request.request(Gamestate.API_URL + "/highscores", Gamestate.headers, HTTPClient.METHOD_POST, payload)
	submit_button.disabled = true

func _on_request_completed(result, response_code, _headers, body):
	print("WE HERE")
	var response_text = body.get_string_from_utf8()
	print(response_text)
	var err = get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	print("Scene change result: ", err)

func _on_exit_button_pressed() -> void:
	Sound.play_sound("ButtonClicked")
	get_tree().quit()

func _on_restart_button_pressed() -> void:
	Sound.play_sound("ButtonClicked")
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
