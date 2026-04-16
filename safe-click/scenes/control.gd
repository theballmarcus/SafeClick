extends Control

@onready var speech_text: RichTextLabel = $SpeechText
@onready var arrow = $Arrow
@onready var afsender = $Afsender
@onready var emne = $Emne
@onready var indhold = $Indhold
@onready var boss = $Boss
@onready var speechbobble = $SpeechBobble
@onready var start_button = $StartButton
@onready var godkend_button = $GodkendButton
@onready var afvis_button = $AfvisButton
@onready var start_button_grey = $StartButtonGrey

var dialogue_lines: Array[String] = [
	"Velkommen til din Første dag på jobbet! På jobbet skal du tjekke firmaets indkommende mails for phishing",
	"For at starte din arbejdsdag skal du klikke på startknappen. Herefter skal du vurdere om kommende mail er ægte eller phishing.",
	"Hovsa! det var vist forkert. Hvis du kigger i mailens domæne kan du se at det ene 'o' er erstattet af et '0'. Prøv at afvis mailen",
	"Det var helt rigtigt! Du jo et naturtalent!"
]

var dialogue_index: int = 0
var full_text: String = ""
var text_speed: float = 0.04

var is_typing: bool = false
var current_index: int = 0
var arrow_start_pos: Vector2
var arrow_tween: Tween

func _ready() -> void:
	arrow.visible = false
	start_button.disabled = true
	godkend_button.disabled = true
	afvis_button.disabled = true
	start_button_grey.visible = false
	arrow_start_pos = arrow.position
	play_dialogue(dialogue_lines[dialogue_index])

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

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		handle_click()

	if event.is_action_pressed("ui_accept"):
		handle_click()

func handle_click() -> void:
	if is_typing:
		is_typing = false
		speech_text.visible_characters = full_text.length()
		
		if dialogue_index == 1:
			start_button.disabled = false
	else:
		if dialogue_index < 1:
				dialogue_index += 1
				
				if dialogue_index == 1:
					show_arrow()
				
				play_dialogue(dialogue_lines[dialogue_index])

func show_arrow() -> void:
	arrow.visible = true
	arrow.position = arrow_start_pos
	
	if arrow_tween:
		arrow_tween.kill()
	
	arrow_tween = create_tween()
	arrow_tween.set_loops()
	arrow_tween.tween_property(arrow, "position", arrow_start_pos + Vector2(0, -12), 0.4)
	arrow_tween.tween_property(arrow, "position", arrow_start_pos, 0.4)

func _on_startbutton_pressed() -> void:
	afsender.visible = true
	emne.visible = true
	indhold.visible = true
	arrow.visible = false
	speechbobble.visible = false
	boss.visible = false
	speech_text.visible = false
	start_button_grey.visible = true
	
	godkend_button.disabled = false
	afvis_button.disabled = false
	
	
	
func _on_godkend_button_pressed() -> void:
	speechbobble.visible = true
	boss.visible = true
	speech_text.visible = true
	
	
	play_dialogue(dialogue_lines[2])
	
	godkend_button.disabled = true

func _on_afvis_button_pressed() -> void:
	speechbobble.visible = true
	boss.visible = true
	speech_text.visible = true
	afsender.visible = false
	emne.visible = false
	indhold.visible = false
	
	play_dialogue(dialogue_lines[3])
