extends Node

const save_game := false
const SAVE_PATH := "user://savegame.json"
const DAY_DURATION := 120.0 # 4 minutes
const MIN_MAILS_PER_DAY := 6
const MAX_MAILS_PER_DAY := 7
const MAIL_ITEM_SCENE := preload("res://graphics/assets/MailItem.tscn")
const WORK_START_HOUR := 8
const WORK_END_HOUR := 15
const WORK_START_MINUTES := WORK_START_HOUR * 60
const WORK_END_MINUTES := WORK_END_HOUR * 60
const WORKDAY_MINUTES := WORK_END_MINUTES - WORK_START_MINUTES

var mails: Array = []
var pending_pool: Array = []
var inbox_mails: Array = []
var finished_mails: Array = []
var current_mail: Dictionary = {}
var score := 0
var day := 1
var rank := "Trainee"
var day_running := false
var time_left := 0.0
var spawn_times: Array = []

@onready var inbox_container = $MainArea/Mails
@onready var day_label = $TopBar/TopPanel/StatsMenu/TextureRect/DayLabel
@onready var time_label = $TimeLabel
@onready var score_label = $TopBar/TopPanel/StatsMenu/TextureRect/ScoreLabel
@onready var rank_label = $TopBar/TopPanel/StatsMenu/TextureRect/RankLabel
@onready var subject_label = $MainArea/MailPanel/MailContent/SubjectLabel
@onready var sender_label = $MainArea/MailPanel/MailContent/SenderLabel
@onready var body_text = $MainArea/MailPanel/MailContent/BodyText
@onready var hover_url_button = $MainArea/MailPanel/MailContent/HoverUrlButton
@onready var hover_url_label = $MainArea/MailPanel/MailContent/HoverUrlLabel
@onready var legit_button = $MainArea/MailPanel/MailContent/LegitButton
@onready var phishing_button = $MainArea/MailPanel/MailContent/PhishingButton
@onready var feedback_label = $FeedbackLabel
@onready var next_mail_button = $NextMailButton
@onready var new_day_button = $NewDayButton
@onready var dayplaying_sprite = $Sprite2D
@onready var SettingsMenu = $TopBar/TopPanel/SettingsMenu
@onready var StatsMenu = $TopBar/TopPanel/StatsMenu
@onready var calender_label = $TopBar/TopPanel/Calender/CalenderLabel


func _ready():
	load_mail_data()
	legit_button.pressed.connect(_on_legit_pressed)
	phishing_button.pressed.connect(_on_phishing_pressed)
	hover_url_button.pressed.connect(_on_hover_url_pressed)
	new_day_button.pressed.connect(start_new_day)
	new_day_button.visible = true
	clear_mail_view()
	update_topbar()
	SettingsMenu.visible = false
	StatsMenu.visible = false

func _process(delta):
	if not day_running:
		time_label.text = "Kl. 08:00"
		return
	time_left -= delta
	while spawn_times.size() > 0 and DAY_DURATION - time_left >= spawn_times[0]:
		spawn_times.pop_front()
		spawn_random_mail()
	if time_left <= 0:
		time_left = 0
		end_day()
	day_label.text = "Dag: %d (%.0fs)" % [day, max(time_left,0)]
	time_label.text = "Kl. %s" % get_current_clock_time()

func start_new_day():
	day_running = true
	time_left = DAY_DURATION
	inbox_mails.clear()
	finished_mails.clear()
	clear_inbox_ui()
	clear_mail_view()
	generate_spawn_times()
	new_day_button.visible = false
	calender_label.text = "%d" % day
	time_label.text = "Kl. %s" % get_current_clock_time()
	#feedback_label.text = "Dag %d startet" % day

func generate_spawn_times():
	spawn_times.clear()
	var count = randi_range(MIN_MAILS_PER_DAY, MAX_MAILS_PER_DAY)
	spawn_times.append(randf_range(1.0, 5.0))
	
	for i in count - 1:
		spawn_times.append(randf_range(5.0, DAY_DURATION - 5.0))
	spawn_times.sort()

func spawn_random_mail():
	if mails.is_empty(): return
	var mail = mails[randi_range(0, mails.size()-1)].duplicate(true)
	inbox_mails.append(mail)
	var item = MAIL_ITEM_SCENE.instantiate()
	item.set_meta("mail_data", mail)
	item.get_node("Control").get_node("Emne").text = mail["subject"]
	item.get_node("Control").get_node("Afsender").text = mail["sender_name"]

	item.get_node("Control").gui_input.connect(func(event): if event is InputEventMouseButton and event.pressed: open_mail(mail, item))
	inbox_container.add_child(item)
	if current_mail.is_empty():
		open_mail(mail, item)

func open_mail(mail, item):
	current_mail = mail
	current_mail["ui_node"] = item
	subject_label.text = mail["subject"]
	sender_label.text = "Fra: %s <%s>" % [mail["sender_name"], mail["sender_email"]]
	body_text.text = mail["body"]
	hover_url_button.visible = str(mail["real_url"]) != ""
	hover_url_label.visible = false
	hover_url_label.text = "URL: %s" % mail["real_url"]
	legit_button.disabled = false
	phishing_button.disabled = false

func evaluate_choice(player_says_phishing):
	if current_mail.is_empty(): return
	var correct = current_mail["is_phishing"]
	if player_says_phishing == correct:
		score += 10
		feedback_label.text = "Korrekt! " + current_mail["hint"]
	else:
		score -= 5
		feedback_label.text = "Forkert. " + current_mail["hint"]
	finished_mails.append(current_mail)
	inbox_mails.erase(current_mail)
	var node = current_mail["ui_node"]
	if is_instance_valid(node): node.queue_free()
	current_mail = {}
	clear_mail_view()
	update_rank()
	update_topbar()
	_select_next_mail()

func _select_next_mail():
	if inbox_mails.size() > 0:
		var first = inbox_mails[0]
		open_mail(first, inbox_container.get_child(0))

func end_day():
	day_running = false
	time_left = 0
	time_label.text = "Kl. 15:00"
	feedback_label.text = "Dag færdig. Tryk for næste dag."
	new_day_button.visible = true
	day += 1
	save_progress()

func clear_inbox_ui():
	for c in inbox_container.get_children(): c.queue_free()

func clear_mail_view():
	subject_label.text = ""
	sender_label.text = ""
	body_text.text = "Ingen mail valgt"
	hover_url_button.visible = false
	hover_url_label.visible = false

func _on_hover_url_pressed(): hover_url_label.visible = not hover_url_label.visible
func _on_legit_pressed(): evaluate_choice(false)
func _on_phishing_pressed(): evaluate_choice(true)

func update_topbar():
	score_label.text = "Point: %d" % score
	rank_label.text = "Rank: %s" % rank

func update_rank():
	if score >= 50: rank = "IT-Support"
	elif score >= 20: rank = "Medarbejder"
	else: rank = "Trainee"

func load_mail_data():
	var file = FileAccess.open("res://data/mails.json", FileAccess.READ)
	if file: mails = JSON.parse_string(file.get_as_text())

func save_progress():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"score":score,"day":day,"rank":rank}))
	
func get_current_clock_time() -> String:
	var elapsed := DAY_DURATION - time_left
	var progress: float = clamp(elapsed / DAY_DURATION, 0.0, 1.0)
	var current_minutes := WORK_START_MINUTES + int(progress * WORKDAY_MINUTES)
	if current_minutes > WORK_END_MINUTES:
		current_minutes = WORK_END_MINUTES
	var hours := current_minutes / 60
	var minutes := current_minutes % 60

	return "%02d:%02d" % [hours, minutes]
	
#Buttons
func _on_settings_button_pressed() -> void:
	SettingsMenu.visible = not SettingsMenu.visible
	Sound.play_sound("ButtonClicked")

func _on_close_settings_button_pressed() -> void:
	SettingsMenu.visible = false
	Sound.play_sound("ButtonClicked")

func _on_stats_button_pressed() -> void:
	StatsMenu.visible = not StatsMenu.visible
	Sound.play_sound("ButtonClicked")

func _on_close_stats_button_pressed() -> void:
	StatsMenu.visible = false
	Sound.play_sound("ButtonClicked")
