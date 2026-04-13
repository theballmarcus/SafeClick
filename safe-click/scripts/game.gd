extends Node

const save_game := false
const SAVE_PATH := "user://savegame.json"

var mails: Array = []
var current_index: int = 0
var score: int = 0
var day: int = 1
var rank: String = "Trainee"

@onready var day_label: Label = $TopBar/HBoxContainer/DayLabel
@onready var score_label: Label = $TopBar/HBoxContainer/ScoreLabel
@onready var rank_label: Label = $TopBar/HBoxContainer/RankLabel

@onready var subject_label: Label = $MainArea/MailPanel/VBoxContainer/SubjectLabel
@onready var sender_label: Label = $MainArea/MailPanel/VBoxContainer/SenderLabel
@onready var suspicion_label: Label = $MainArea/MailPanel/VBoxContainer/SuspicionLabel
@onready var body_text: RichTextLabel = $MainArea/MailPanel/VBoxContainer/BodyText
@onready var hover_url_button: Button = $MainArea/MailPanel/VBoxContainer/HoverUrlButton
@onready var hover_url_label: Label = $MainArea/MailPanel/VBoxContainer/HoverUrlLabel
@onready var legit_button: Button = $MainArea/MailPanel/VBoxContainer/ActionButtons/LegitButton
@onready var phishing_button: Button = $MainArea/MailPanel/VBoxContainer/ActionButtons/PhishingButton
@onready var feedback_label: Label = $FeedbackLabel
@onready var next_mail_button: Button = $NextMailButton

func _ready() -> void:
	load_mail_data()
	load_progress()

	hover_url_button.pressed.connect(_on_hover_url_pressed)
	legit_button.pressed.connect(_on_legit_pressed)
	phishing_button.pressed.connect(_on_phishing_pressed)
	next_mail_button.pressed.connect(_on_next_mail_pressed)

	next_mail_button.disabled = true
	hover_url_label.visible = false
	feedback_label.text = ""

	update_topbar()
	show_current_mail()

func load_mail_data() -> void:
	var file := FileAccess.open("res://data/mails.json", FileAccess.READ)
	if file == null:
		push_error("Kunne ikke åbne mails.json")
		return

	var content := file.get_as_text()
	var parsed = JSON.parse_string(content)

	if parsed == null:
		push_error("JSON kunne ikke parses")
		return

	mails = parsed

func show_current_mail() -> void:
	if current_index >= mails.size():
		subject_label.text = "Inbox tom"
		sender_label.text = ""
		suspicion_label.text = ""
		body_text.text = "Du har gennemgået alle mails for denne prototype."
		hover_url_button.visible = false
		hover_url_label.visible = false
		legit_button.disabled = true
		phishing_button.disabled = true
		next_mail_button.disabled = true
		feedback_label.text = "Dag færdig."
		return

	var mail: Dictionary = mails[current_index]

	subject_label.text = mail["subject"]
	sender_label.text = "Fra: %s <%s>" % [mail["sender_name"], mail["sender_email"]]
	print(mail["body"])
	body_text.text = mail["body"]

	var has_link := str(mail["real_url"]) != ""
	hover_url_button.visible = has_link
	hover_url_label.visible = false
	hover_url_label.text = "URL: %s" % mail["real_url"]

	legit_button.disabled = false
	phishing_button.disabled = false
	next_mail_button.disabled = true
	feedback_label.text = ""

func _on_hover_url_pressed() -> void:
	hover_url_label.visible = not hover_url_label.visible

func _on_legit_pressed() -> void:
	evaluate_choice(false)

func _on_phishing_pressed() -> void:
	evaluate_choice(true)

func evaluate_choice(player_says_phishing: bool) -> void:
	if current_index >= mails.size():
		return

	var mail: Dictionary = mails[current_index]
	var correct_answer: bool = mail["is_phishing"]

	legit_button.disabled = true
	phishing_button.disabled = true
	next_mail_button.disabled = false

	if player_says_phishing == correct_answer:
		score += 10
		feedback_label.text = "Korrekt! " + mail["hint"]
	else:
		score -= 5
		feedback_label.text = "Forkert. " + mail["hint"]

	update_rank()
	update_topbar()
	save_progress()

func _on_next_mail_pressed() -> void:
	current_index += 1
	show_current_mail()
	save_progress()

func update_topbar() -> void:
	day_label.text = "Dag: %d" % day
	score_label.text = "Point: %d" % score
	rank_label.text = "Rank: %s" % rank

func update_rank() -> void:
	if score >= 50:
		rank = "IT-Support"
	elif score >= 20:
		rank = "Medarbejder"
	else:
		rank = "Trainee"

func save_progress() -> void:
	var data := {
		"score": score,
		"day": day,
		"rank": rank,
		"current_index": current_index
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var content := file.get_as_text()
	var parsed = JSON.parse_string(content)

	if parsed == null:
		return
		
	if save_game == true:
		score = parsed.get("score", 0)
		day = parsed.get("day", 1)
		rank = parsed.get("rank", "Trainee")
		current_index = parsed.get("current_index", 0)
