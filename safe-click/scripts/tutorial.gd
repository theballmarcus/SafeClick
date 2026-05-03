extends Control

@onready var speech_text: RichTextLabel = $SpeechText
@onready var arrow = $Arrow
@onready var afsender_indhold = $AfsenderIndhold
@onready var emne_indhold = $EmneIndhold
@onready var titel_mail = $TitelMail
@onready var emne_mail = $EmneMail
@onready var mail_barriere = $ColorRect
@onready var indhold: RichTextLabel = $Indhold
@onready var boss = $Boss
@onready var speechbobble = $SpeechBobble
@onready var start_button = $StartButton
@onready var godkend_button = $GodkendButton
@onready var afvis_button = $AfvisButton
@onready var mail_button = $MailButton
@onready var url = $Url
@onready var hint = $Hint

@onready var snake = $"../../Game/Snake"
@onready var start_new_day_bar = $"../../Game/StartNewDayBar"
@onready var new_day_button = $"../../Game/NewDayButton"
@onready var time_label = $"../../Game/TimeLabel"
@onready var værktøjslinje = $"../../Game/MainArea/MailPanel/Baggrund/Værktøjslinje"
@onready var legit_button = $"../../Game/MainArea/MailPanel/LegitButton"
@onready var phishing_button = $"../../Game/MainArea/MailPanel/PhishingButton"
@onready var tool_button = $"../../Game/MainArea/MailPanel/AnimatedShape/ToolButton"
@onready var idea_button = $"../../Game/MainArea/MailPanel/AnimatedShape/IdeaButton"
@onready var hover_url_button = $"../../Game/MainArea/MailPanel/AnimatedShape/HoverUrlButton"
@onready var shape = $"../../Game/MainArea/MailPanel/AnimatedShape"
@onready var game = $"../../Game"

var scene_done: bool = false

var dialogue_lines: Array[String] = [
	"Velkommen til din Første dag på jobbet! På jobbet skal du tjekke firmaets indkommende mails for phishing.",
	"For at starte din arbejdsdag skal du klikke på startknappen. Herefter skal du vurdere om indkommende mails er ægte eller phishing mails.",
	"Du vil i løbet af dagen modtage mails i din indbakke. Klik på mailen, og afvis den, hvis du vurderer, at det er phishing, og videresend den, hvis det er en reel mail.",
	"Det kan være svært at identificere, om en mail er phishing med det blotte øje. Visse mails, som denne, indeholder links, der kan hjælpe dig med at træffe din endelige beslutning.",
	"For at åbne mailen skal du klikke på værktøjslinjen. Herefter vises to nye knapper. Papirklippen giver dig adgang til links i mailen, som kan hjælpe dig med at vurdere, om mailen er phishing eller legitim.",
	"Er det stadig svært, kan du klikke på lyspære-ikonet for at få et hint. Vær dog opmærksom på, at hvis du spørger mig om hjælp for tit, vil det reducere min vurdering af dig.",
	"Nu har du fået et hint og alle de værktøjer, du skal bruge. Prøv selv at afgøre, om mailen er phishing eller ej.",
	"Hovsa! det var vist forkert. Hvis du kigger i mailens domæne kan du se at det ene 'o' er erstattet af et '0'. Prøv at afvise mailen.",
	"Det var helt rigtigt! Du jo et naturtalent!",
	"Nu er tutorialen færdig. Du er klar til at starte spillet. Som din chef ønsker jeg dig held og lykke med din første arbejdsdag."
]

var dialogue_index: int = 0
var full_text: String = ""
var text_speed: float = 0.04

var is_typing: bool = false
var current_index: int = 0
var arrow_start_pos: Vector2
var arrow_pos_2: Vector2
var arrow_tween: Tween

var tool_button_active: bool = false
var hover_url_button_active: bool = false
var idea_button_active: bool = false
var can_choose_mail_type: bool = false
var free_mail_choice_mode: bool = false
var legit_button_active: bool = false
var phishing_button_active: bool = false
var last_dialogue: bool = false

func _ready() -> void:
	arrow.visible = false
	start_button.disabled = true
	godkend_button.disabled = true
	afvis_button.disabled = true
	mail_button.disabled = true
	arrow_start_pos = arrow.position
	play_dialogue(dialogue_lines[dialogue_index])
	snake.visible = false
	shape.visible = false
	snake.process_mode = Node.PROCESS_MODE_DISABLED
	indhold.bbcode_enabled = true
	indhold.text = "Din pakke er blevet tilbageholdt, da den ikke er blevet tildelt en adresse. Du bliver dermed nødt til at betale 9kr i gebyr. Klik [u]her[/u] for at betale gebyret."

func play_dialogue(new_text: String) -> void:
	full_text = new_text
	speech_text.text = full_text
	speech_text.visible_characters = 0
	
	current_index = 0
	is_typing = true
	
	if dialogue_index == 4:
		if arrow_tween:
			arrow_tween.kill()
		show_arrow(Vector2(512, 476))
		arrow.rotation_degrees = 90
		
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
	if dialogue_index == 4:
		tool_button_active = true
	if dialogue_index == 5:
		idea_button_active = true
	if dialogue_index == 6:
		can_choose_mail_type = true
	if dialogue_index == 8:
		last_dialogue = true
		
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if tool_button_active and _mouse_is_over_tool_button(event.position):
			_on_tool_button_pressed()
			return
		if hover_url_button_active and _mouse_is_over_hover_url_button(event.position):
			_on_hover_url_button_pressed()
			return
		if idea_button_active and _mouse_is_over_idea_button(event.position):
			_on_idea_button_pressed()
			return
		if legit_button_active and _mouse_is_over_legit_button(event.position):
			_on_godkend_button_pressed()
			return
		if phishing_button_active and _mouse_is_over_phishing_button(event.position):
			_on_afvis_button_pressed()
			return
			
		handle_click()

	if event.is_action_pressed("ui_accept"):
		handle_click()

func handle_click() -> void:
	if is_typing:
		is_typing = false
		speech_text.visible_characters = full_text.length()
		return
		
	if dialogue_index == 3:
		dialogue_index = 4
		play_dialogue(dialogue_lines[4])
		return
	
	if dialogue_index == 6 and can_choose_mail_type:
		can_choose_mail_type = false
		free_mail_choice_mode = true
		
		boss.visible = false
		speechbobble.visible = false
		speech_text.visible = false
		
		tool_button_active = true
		hover_url_button_active = true
		idea_button_active = true
		legit_button_active = true
		phishing_button_active = true
		
		godkend_button.disabled = false
		afvis_button.disabled = false
		return
		
	if dialogue_index == 8 and last_dialogue:
		last_dialogue = false
		dialogue_index = 9
		play_dialogue(dialogue_lines[9])
		scene_done = true
		return
	if scene_done:
		get_tree().change_scene_to_file("res://scenes/Game.tscn")
		return
		
	else:
		if dialogue_index < 1:
				dialogue_index += 1
				
				if dialogue_index == 1:
					show_arrow(Vector2(285,476))
				
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
	mail_barriere.visible = true
	titel_mail.visible = true
	emne_mail.visible = true
	start_button.disabled = true
	start_new_day_bar.visible = false
	new_day_button.visible = false
	show_arrow(Vector2(405,212))
	
	arrow.rotation_degrees = 180
	
	if arrow_tween:
		arrow_tween.kill()
	
	arrow_tween = create_tween()
	arrow_tween.set_loops()
	arrow_tween.tween_property(arrow, "position", arrow_start_pos + Vector2(-12, 0), 0.4)
	arrow_tween.tween_property(arrow, "position", arrow_start_pos, 0.4)
	
	dialogue_index = 2
	play_dialogue(dialogue_lines[2])
		
func _on_mail_button_pressed() -> void:
	arrow.visible = false
	speechbobble.visible = false
	boss.visible = false
	speech_text.visible = false
	
	afsender_indhold.visible = true
	emne_indhold.visible = true
	indhold.visible = true
	værktøjslinje.visible = true
	tool_button.visible = true
	legit_button.visible = true
	phishing_button.visible = true
	time_label.visible = true
	shape.visible = true
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("c3c3c396")
	style.corner_radius_top_left = 60
	style.corner_radius_top_right = 60
	style.corner_radius_bottom_left = 60
	style.corner_radius_bottom_right = 60

	shape.add_theme_stylebox_override("panel", style)
	shape.size = game.circle_size
	
	mail_button.disabled = true
	
	boss.position = Vector2(1035, 505)
	speechbobble.position = Vector2(908, 258)
	speechbobble.scale.x = -1
	speech_text.position = Vector2(561, 281)
	
	await get_tree() .create_timer(0.0).timeout
	boss.visible = true
	speechbobble.visible = true
	speech_text.visible = true
	tool_button_active = false
	tool_button.disabled = false
	time_label.visible = false
	
	dialogue_index = 3
	play_dialogue(dialogue_lines[3])
	
func _mouse_is_over_tool_button(mouse_pos: Vector2) -> bool:
	var rect := Rect2(tool_button.global_position, tool_button.size)
	return rect.has_point(mouse_pos)
func _mouse_is_over_hover_url_button(mouse_pos: Vector2) -> bool:
	var rect := Rect2(hover_url_button.global_position, hover_url_button.size)
	return rect.has_point(mouse_pos)
func _mouse_is_over_idea_button(mouse_pos: Vector2) -> bool:
	var rect := Rect2(idea_button.global_position, idea_button.size)
	return rect.has_point(mouse_pos)
func _mouse_is_over_legit_button(mouse_pos: Vector2) -> bool:
	var rect := Rect2(legit_button.global_position, legit_button.size)
	return rect.has_point(mouse_pos)
func _mouse_is_over_phishing_button(mouse_pos: Vector2) -> bool:
	var rect := Rect2(phishing_button.global_position, phishing_button.size)
	return rect.has_point(mouse_pos)
	
func _on_tool_button_pressed() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("c3c3c396")
	style.corner_radius_top_left = 60
	style.corner_radius_top_right = 60
	style.corner_radius_bottom_left = 60
	style.corner_radius_bottom_right = 60
	
	shape.visible = true
	shape.add_theme_stylebox_override("panel", style)

	if not free_mail_choice_mode:
		show_arrow(Vector2(566, 476))
		tool_button_active = false
		hover_url_button_active = true
		
		shape.size = game.circle_size
		game.expanded = false
	else:
		arrow.visible = false
	
	game.toggle_shape()

	if free_mail_choice_mode:
		tool_button_active = true
		hover_url_button_active = true
		idea_button_active = true
	
func _on_hover_url_button_pressed() -> void:
	url.visible = true
	hint.visible = false
	
	if not free_mail_choice_mode:
		hover_url_button_active = false
		arrow.visible = false
		
		dialogue_index = 5
		play_dialogue(dialogue_lines[5])
		
		show_arrow(Vector2(675,655))
		arrow.rotation_degrees = 180
		
		if arrow_tween:
			arrow_tween.kill()
		arrow_tween = create_tween()
		arrow_tween.set_loops()
		arrow_tween.tween_property(arrow, "position", arrow_start_pos + Vector2(-12, 0), 0.4)
		arrow_tween.tween_property(arrow, "position", arrow_start_pos, 0.4)

	game._on_hover_url_pressed()
	
func _on_idea_button_pressed() -> void:
	url.visible = false
	hint.visible = true
	
	if not free_mail_choice_mode:
		idea_button_active = false
		arrow.visible = false
		
		dialogue_index = 6
		play_dialogue(dialogue_lines[6])

func _on_godkend_button_pressed() -> void:
	speechbobble.visible = true
	boss.visible = true
	speech_text.visible = true
	godkend_button.disabled = true
	
	
	dialogue_index = 7
	play_dialogue(dialogue_lines[7])

func _on_afvis_button_pressed() -> void:
	tool_button_active = false
	hover_url_button_active = false
	idea_button_active = false
	legit_button_active = false
	phishing_button_active = false
	free_mail_choice_mode = false
	can_choose_mail_type = false

	url.visible = false
	hint.visible = false
	arrow.visible = false

	godkend_button.disabled = true
	afvis_button.disabled = true
	tool_button.disabled = true
	
	speechbobble.visible = true
	boss.visible = true
	speech_text.visible = true
	
	afsender_indhold.visible = false
	emne_indhold.visible = false
	indhold.visible = false
	mail_barriere.visible = false
	titel_mail.visible = false
	emne_mail.visible = false
	
	dialogue_index = 8
	last_dialogue = false
	play_dialogue(dialogue_lines[8])
