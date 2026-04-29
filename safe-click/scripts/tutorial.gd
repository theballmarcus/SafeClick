extends Control

@onready var speech_text: RichTextLabel = $SpeechText
@onready var arrow = $Arrow
@onready var afsender_indhold = $AfsenderIndhold
@onready var emne_indhold = $EmneIndhold
@onready var titel_mail = $TitelMail
@onready var emne_mail = $EmneMail
@onready var mail_barriere = $ColorRect
@onready var indhold = $Indhold
@onready var boss = $Boss
@onready var speechbobble = $SpeechBobble
@onready var start_button = $StartButton
@onready var godkend_button = $GodkendButton
@onready var afvis_button = $AfvisButton
@onready var mail_button = $MailButton
@onready var start_button_grey = $StartButtonGrey
@onready var snake = $"../../Game/Snake"

var scene_done: bool = false

var dialogue_lines: Array[String] = [
	"Velkommen til din Første dag på jobbet! På jobbet skal du tjekke firmaets indkommende mails for phishing.",
	"For at starte din arbejdsdag skal du klikke på startknappen. Herefter skal du vurdere om indkommende mails er ægte eller phishing mails.",
	"Du vil i løbet af dagen modtage mails i din indbakke. Klik på mailen, og afvis den, hvis du vurderer, at det er phishing, og videresend den, hvis det er en reel mail.",
	"Hovsa! det var vist forkert. Hvis du kigger i mailens domæne kan du se at det ene 'o' er erstattet af et '0'. Prøv at afvise mailen.",
	"Det var helt rigtigt! Du jo et naturtalent!"
]

var dialogue_index: int = 0
var full_text: String = ""
var text_speed: float = 0.04

var is_typing: bool = false
var current_index: int = 0
var arrow_start_pos: Vector2
var arrow_pos_2: Vector2
var arrow_tween: Tween

func _ready() -> void:
	arrow.visible = false
	start_button.disabled = true
	godkend_button.disabled = true
	afvis_button.disabled = true
	mail_button.disabled = true
	start_button_grey.visible = false
	arrow_start_pos = arrow.position
	play_dialogue(dialogue_lines[dialogue_index])
	snake.visible = false
	snake.process_mode = Node.PROCESS_MODE_DISABLED

func play_dialogue(new_text: String) -> void:
	full_text = new_text
	speech_text.text = full_text
	speech_text.visible_characters = 0
	
	current_index = 0
	is_typing = true
	
	show_text()

func show_text() -> void:
	while current_index < full_text.length() and is_typing:
		current_index += 1
		speech_text.visible_characters = current_index
		await get_tree().create_timer(text_speed).timeout
	
	speech_text.visible_characters = full_text.length()
	is_typing = false
	
	if dialogue_index == 1:
		start_button.disabled = false
	if dialogue_index == 2:
		mail_button.disabled = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		handle_click()

	if event.is_action_pressed("ui_accept"):
		handle_click()

func handle_click() -> void:
	if is_typing:
		is_typing = false
		speech_text.visible_characters = full_text.length()
		return
		
	if scene_done:
		get_tree().change_scene_to_file("res://scenes/Game.tscn")
		return
		
		if dialogue_index == 1:
			start_button.disabled = false
	else:
		if dialogue_index < 1:
				dialogue_index += 1
				
				if dialogue_index == 1:
					show_arrow(Vector2(1130,472))
				
				play_dialogue(dialogue_lines[dialogue_index])

func show_arrow(new_pos:Vector2) -> void:
	arrow.visible = true
	arrow_start_pos = new_pos
	arrow.position = arrow_start_pos
	
	if arrow_tween:
		arrow_tween.kill()
	
	arrow_tween = create_tween()
	arrow_tween.set_loops()
	arrow_tween.tween_property(arrow, "position", arrow_start_pos + Vector2(0, -12), 0.4)
	arrow_tween.tween_property(arrow, "position", arrow_start_pos, 0.4)

func _on_startbutton_pressed() -> void:
	start_button_grey.visible = true
	mail_barriere.visible = true
	titel_mail.visible = true
	emne_mail.visible = true
	
	show_arrow(Vector2(400,212))
	
	arrow.rotation_degrees = 180
	
	if arrow_tween:
		arrow_tween.kill()
	
	arrow_tween = create_tween()
	arrow_tween.set_loops()
	arrow_tween.tween_property(arrow, "position", arrow_start_pos + Vector2(-12, 0), 0.4)
	arrow_tween.tween_property(arrow, "position", arrow_start_pos, 0.4)
	
	dialogue_index = 2
	play_dialogue(dialogue_lines[2])
	
	var tween = create_tween()
	var target_position_boss = Vector2(657, 485)
	var target_position_speechbobble = Vector2(778, 211)
	var target_position_speech_text = Vector2(799, 234)
	
	tween.tween_property(boss, "position", target_position_boss, 1.0)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(speechbobble, "position", target_position_speechbobble, 1.0)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(speech_text, "position", target_position_speech_text, 1.0)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
		
func _on_mail_button_pressed() -> void:
	arrow.visible = false
	speechbobble.visible = false
	boss.visible = false
	speech_text.visible = false
	afsender_indhold.visible = true
	emne_indhold.visible = true
	indhold.visible = true

	godkend_button.disabled = false
	afvis_button.disabled = false

	boss.position = Vector2(197, 485)
	speechbobble.position = Vector2(318, 211)
	speech_text.position = Vector2(339, 234)
	
	dialogue_index = 3
	play_dialogue(dialogue_lines[3])

func _on_godkend_button_pressed() -> void:
	speechbobble.visible = true
	boss.visible = true
	speech_text.visible = true
	godkend_button.disabled = true
	scene_done = true

func _on_afvis_button_pressed() -> void:
	speechbobble.visible = true
	boss.visible = true
	speech_text.visible = true
	afsender_indhold.visible = false
	emne_indhold.visible = false
	indhold.visible = false
	mail_barriere.visible = false
	titel_mail.visible = false
	emne_mail.visible = false
	dialogue_index = 4
	play_dialogue(dialogue_lines[4])
	scene_done = true
