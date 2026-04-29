extends Node

const save_game := false
const SAVE_PATH := "user://savegame.json"
const DAY_DURATION := 20.0 # 4 minutes
const MIN_MAILS_PER_DAY := 6
const MAX_MAILS_PER_DAY := 7
const UNANSWERED_MAIL_PENALTY := 3
const MAX_FETCH_RETRIES := 3
const MAIL_ITEM_SCENE := preload("res://graphics/assets/MailItem.tscn")
const WORK_START_HOUR := 8
const WORK_END_HOUR := 15
const WORK_START_MINUTES := WORK_START_HOUR * 60
const WORK_END_MINUTES := WORK_END_HOUR * 60
const WORKDAY_MINUTES := WORK_END_MINUTES - WORK_START_MINUTES

var day_mail_pool: Array = []
var inbox_mails: Array = []
var current_mail: Dictionary = {}
var score := 0
var day := 1
var rank := "Trainee"
var day_running := false
var time_left := 0.0
var spawn_times: Array = []
var failed_mails := []


var boss_shown := false
var employee_fired := false
var max_score := 0

var expanded := false
var circle_size := Vector2(39, 39)
var rect_size := Vector2(155, 39)

@onready var inbox_container = $MainArea/Mails
@onready var day_label = $TopBar/TopPanel/StatsMenu/TextureRect/DayLabel
@onready var time_label = $TimeLabel
@onready var score_label = $TopBar/TopPanel/StatsMenu/TextureRect/ScoreLabel
@onready var rank_label = $TopBar/TopPanel/StatsMenu/TextureRect/RankLabel
@onready var subject_label = $MainArea/MailPanel/MailContent/SubjectLabel
@onready var sender_label = $MainArea/MailPanel/MailContent/SenderLabel
@onready var body_text = $MainArea/MailPanel/MailContent/BodyText
@onready var hover_url_button = $MainArea/MailPanel/AnimatedShape/HoverUrlButton
@onready var hover_url_label = $MainArea/MailPanel/MailContent/HoverUrlLabel
@onready var legit_button = $MainArea/MailPanel/LegitButton
@onready var phishing_button = $MainArea/MailPanel/PhishingButton
@onready var feedback_label = $FeedbackLabel
@onready var next_mail_button = $NextMailButton
@onready var new_day_button = $NewDayButton
@onready var dayplaying_sprite = $Sprite2D
@onready var SettingsMenu = $TopBar/TopPanel/SettingsMenu
@onready var StatsMenu = $TopBar/TopPanel/StatsMenu
@onready var calender_label = $TopBar/TopPanel/Calender/CalenderLabel
@onready var toolbar = $"MainArea/MailPanel/Baggrund/Værktøjslinje"
@onready var tool_button = $MainArea/MailPanel/AnimatedShape/ToolButton
@onready var day_playing_icon = $DayPlaying
@onready var day_bar = $StartNewDayBar
@onready var start_day_label = $StartNewDayBar/StartNyDag

@onready var feedback_menu = $BossFeedback
@onready var boss_label = $BossFeedback/SpeechBubble/BossLabel
@onready var boss_n = $BossFeedback/BossN
@onready var boss_g = $BossFeedback/BossG
@onready var boss_s = $BossFeedback/BossS
var boss_qoute_queue := []

@onready var shape = $MainArea/MailPanel/AnimatedShape
@onready var idea_button = $MainArea/MailPanel/AnimatedShape/IdeaButton
@onready var hint_label = $MainArea/MailPanel/AnimatedShape/IdeaButton/HintLabel

@onready var snake_game = $Snake

@onready var post_highscore_elem = $PostHighscore

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
	
	toolbar.visible = false
	legit_button.visible = false
	phishing_button.visible = false
	tool_button.visible = false
	time_label.visible = false

func _process(delta):
	if not day_running:
		time_label.text = "Kl. 08:00"
		return
	time_left -= delta
	while spawn_times.size() > 0 and DAY_DURATION - time_left >= spawn_times[0]:
		spawn_times.pop_front()
		spawn_random_mail()
	if time_left <= 0 and boss_shown == false:
		time_left = 0
		end_day()
	day_label.text = "Dag: %d (%.0fs)" % [day, max(time_left,0)]
	time_label.text = "Kl. %s" % get_current_clock_time()

func start_new_day():
	new_day_button.disabled = true
	feedback_label.text = "Henter mails..."
	clear_mail_view()
	clear_inbox_ui()
	inbox_mails.clear()
	current_mail = {}

	var target_mail_count := randi_range(MIN_MAILS_PER_DAY, MAX_MAILS_PER_DAY)
	await _prepare_day_mail_pool(target_mail_count)

	if day_mail_pool.is_empty():
		day_running = false
		feedback_label.text = "Kunne ikke starte dag: ingen mails tilgaengelige"
		new_day_button.visible = true
		new_day_button.disabled = false
		return

	day_running = true
	time_left = DAY_DURATION
	generate_spawn_times(day_mail_pool.size())
	new_day_button.visible = false
	new_day_button.disabled = false
	calender_label.text = "%d" % day
	time_label.text = "Kl. %s" % get_current_clock_time()
	feedback_label.text = "Dag %d startet" % day
	call_deferred("_prefetch_next_day_mails")
	
	snake_game.stop()
	failed_mails.clear()

func generate_spawn_times(count: int):
	spawn_times.clear()
	if count <= 0:
		return
	spawn_times.append(randf_range(1.0, 5.0))
	
	for i in range(count - 1):
		spawn_times.append(randf_range(5.0, DAY_DURATION - 5.0))
	spawn_times.sort()

func spawn_random_mail():
	if day_mail_pool.is_empty():
		return

	var mail = day_mail_pool.pop_front().duplicate(true)
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
	var cur_body_text = mail["body"].replace('[l]', '[url][color=blue]').replace('[/l]', '[/color]s[/url]')
	body_text.text = cur_body_text
	hover_url_button.visible = str(mail["real_url"]) != ""
	hover_url_label.visible = false
	hover_url_label.text = "URL: %s" % mail["real_url"]
	legit_button.disabled = false
	phishing_button.disabled = false
	hint_label.visible = false

func evaluate_choice(player_says_phishing):
	if current_mail.is_empty(): return
	var correct = current_mail["is_phishing"]
	if player_says_phishing == correct:
		score += 10
		feedback_label.text = "Korrekt! " + current_mail["hint"]
	else:
		score -= 5
		feedback_label.text = "Forkert. " + current_mail["hint"]
		failed_mails.append(current_mail)
		
	Gamestate.finished_mails.append(current_mail)
	var answered_id := int(current_mail.get("id", -1))
	if answered_id != -1:
		_remove_mail_from_unanswered_by_id(answered_id)
	inbox_mails.erase(current_mail)
	var node = current_mail["ui_node"]
	if is_instance_valid(node): node.queue_free()
	current_mail = {}
	clear_mail_view()
	update_rank()
	update_topbar()
	_select_next_mail()

func _select_next_mail():
	if inbox_mails.is_empty():
		return

	var first = inbox_mails[0]
	var first_id := int(first.get("id", -1))
	for item in inbox_container.get_children():
		var item_mail: Dictionary = item.get_meta("mail_data", {})
		if int(item_mail.get("id", -1)) == first_id:
			open_mail(first, item)
			return

# Forste gange der korer viser det chefen. Anden gang lukker det menuen og bliver klar til naste dag.
func end_day():
	if employee_fired == true:
		post_highscore_elem.visible = true
		return
		
	if boss_shown == false:
		day += 1
		boss_shown = true

		show_boss()
		return
	
	if boss_qoute_queue.size() > 0:
		print(boss_qoute_queue)
		print("should update")
		boss_label.text = boss_qoute_queue[0]
		boss_qoute_queue.pop_front()
		return
	
	calender_label.text = "%d" % day
	day_running = false
	time_left = 0
	var unanswered_removed := _remove_unanswered_mails_and_apply_penalty()
	inbox_mails.clear()
	current_mail = {}
	clear_inbox_ui()
	clear_mail_view()
	day_mail_pool.clear()
	spawn_times.clear()
	time_label.text = "Kl. 15:00"
	if unanswered_removed > 0:
		feedback_label.text = "Dag faerdig. %d ubesvarede mails gav -%d point." % [unanswered_removed, unanswered_removed * UNANSWERED_MAIL_PENALTY]
	else:
		feedback_label.text = "Dag faerdig. Tryk for naeste dag."
	new_day_button.visible = true
	new_day_button.disabled = false
	update_rank()
	update_topbar()
	save_progress()
	
	toolbar.visible = false
	legit_button.visible = false
	phishing_button.visible = false
	tool_button.visible = false
	time_label.visible = false
	day_playing_icon.visible = false
	day_bar.visible = true
	hover_url_button.visible = false
	shape.visible = false
	
	start_day_label.text = "Start ny dag!"
	start_day_label.add_theme_font_size_override("font_size", 20)
	
	boss_shown = false
	feedback_menu.visible = false
	snake_game.start()
	
func show_boss():
	feedback_menu.visible = true
	# calculate score. 
	# if score <= 60%, its bad
	# if score > 60% and <= 90%, its ok
	# if score > 90%, its good
	# Based on max_score

	# Then pick random qoute from Gamestate.BOSS_QUOTES based on performance
	var performance: float = (float(score) / max(float(max_score), 1.0)) * 100.0
	#performance = 100
	var quote_pool := []
	
	var qoute_feedback_pre := ""
	var qoute_feedback 
	
	if failed_mails.size() > 0:
		qoute_feedback_pre = Gamestate.boss_feedback[randi() % Gamestate.boss_feedback.size()]
		qoute_feedback = failed_mails[randi() % failed_mails.size()]
		
	print("Performance: %f" % performance)
	if performance <= 30:
		# WE FIRE THE EMPLOYEE
		Gamestate.user_score = score
		employee_fired = true
		quote_pool = Gamestate.boss_fired

	elif performance <= 60:
		quote_pool = Gamestate.boss_comments["bad"]
		boss_s.visible = true
		boss_qoute_queue.append(qoute_feedback_pre)
		boss_qoute_queue.append("Mail fra %s\n%s" % [qoute_feedback["sender_name"], qoute_feedback["hint"]])
		
	elif performance <= 90:
		quote_pool = Gamestate.boss_comments["ok"]
		boss_n.visible = true
		boss_qoute_queue.append(qoute_feedback_pre)
		boss_qoute_queue.append("Mail fra %s\n%s" % [qoute_feedback["sender_name"], qoute_feedback["hint"]])
	else:
		quote_pool = Gamestate.boss_comments["good"]
		boss_g.visible = true
	
	var quote = quote_pool[randi() % quote_pool.size()]
	boss_label.text = quote


func _prepare_day_mail_pool(target_count: int) -> void:
	day_mail_pool.clear()
	if target_count <= 0:
		return

	await _ensure_mail_supply(target_count)
	if Gamestate.mails.is_empty():
		return

	var shuffled_mails: Array = Gamestate.mails.duplicate(true)
	shuffled_mails.shuffle()
	var count: int = min(target_count, shuffled_mails.size())
	max_score += count * 10
	for i in range(count):
		day_mail_pool.append(shuffled_mails[i])

func _ensure_mail_supply(required_count: int) -> void:
	var retries := 0
	while Gamestate.mails.size() < required_count and retries < MAX_FETCH_RETRIES:
		retries += 1
		var started_fetch: bool = Gamestate.fetch_mails(day)
		if not started_fetch:
			break
		var fetch_result = await Gamestate.mails_fetched
		var fetch_success: bool = fetch_result[0]
		var added_count: int = int(fetch_result[1])
		if not fetch_success or added_count <= 0:
			break

func _prefetch_next_day_mails() -> void:
	var next_day: int = min(day + 1, 10)
	var _started: bool = Gamestate.fetch_mails(next_day, MAX_MAILS_PER_DAY)

func _on_boss_button_pressed() -> void:	
	if not boss_shown:
		return

	end_day()

func _remove_mail_from_unanswered_by_id(mail_id: int) -> bool:
	for i in range(Gamestate.mails.size() - 1, -1, -1):
		if int(Gamestate.mails[i].get("id", -1)) == mail_id:
			Gamestate.mails.remove_at(i)
			return true
	return false

func _remove_unanswered_mails_and_apply_penalty() -> int:
	var unanswered_removed := 0
	for mail in inbox_mails:
		var mail_id := int(mail.get("id", -1))
		if mail_id == -1:
			continue
		if _remove_mail_from_unanswered_by_id(mail_id):
			unanswered_removed += 1

	if unanswered_removed > 0:
		score -= unanswered_removed * UNANSWERED_MAIL_PENALTY

	return unanswered_removed

func clear_inbox_ui():
	for c in inbox_container.get_children(): c.queue_free()

func clear_mail_view():
	subject_label.text = ""
	sender_label.text = ""
	body_text.text = ""
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
	# Mail state is stored in Gamestate and fetched on demand at day start.
	pass

func save_progress():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"score":score,"day":day,"rank":rank}))
	
func get_current_clock_time() -> String:
	var elapsed := DAY_DURATION - time_left
	var progress: float = clamp(elapsed / DAY_DURATION, 0.0, 1.0)
	var current_minutes := WORK_START_MINUTES + int(progress * WORKDAY_MINUTES)
	if current_minutes > WORK_END_MINUTES:
		current_minutes = WORK_END_MINUTES
	var hours: int = int(float(current_minutes) / 60.0)
	var minutes: int = current_minutes % 60

	return "%02d:%02d" % [hours, minutes]
	
func toggle_shape():
	var tween = create_tween()

	if expanded:
		tween.set_parallel(true)
		tween.tween_property(idea_button, "modulate:a", 0.0, 0.1)
		tween.tween_property(hover_url_button, "modulate:a", 0.0, 0.15)
		tween.tween_callback(func():
			idea_button.visible = false
			hover_url_button.visible = false
		)
		tween.tween_property(shape, "size", circle_size, 0.25)
	else:
		hover_url_button.visible = true
		idea_button.visible = true
		hover_url_button.modulate.a = 0
		idea_button.modulate.a = 0
		tween.tween_property(shape, "size", rect_size, 0.35)
		tween.tween_interval(0.1)
		tween.tween_property(hover_url_button, "modulate:a", 1.0, 0.2)
		tween.tween_interval(0.1)
		tween.tween_property(idea_button, "modulate:a", 1.0, 0.2)
	expanded = !expanded
	
#Buttons
func _on_settings_button_pressed() -> void:
	SettingsMenu.visible = not SettingsMenu.visible
	StatsMenu.visible = false
	Sound.play_sound("ButtonClicked")

func _on_close_settings_button_pressed() -> void:
	SettingsMenu.visible = false
	Sound.play_sound("ButtonClicked")

func _on_stats_button_pressed() -> void:
	StatsMenu.visible = not StatsMenu.visible
	SettingsMenu.visible = false
	Sound.play_sound("ButtonClicked")

func _on_close_stats_button_pressed() -> void:
	StatsMenu.visible = false
	Sound.play_sound("ButtonClicked")

func _on_tool_button_pressed() -> void:
	toggle_shape()

func _on_idea_button_pressed() -> void:
	score -= 5
	if current_mail.size() == 0:
		hint_label.text = "\n Ingen mail er valgt!"
	else:
		hint_label.text = "Du spørger chefen om hjælp - han siger: \n" +  current_mail["hint"]
	if hint_label.visible == false:
		hint_label.visible = true
	else:
		hint_label.visible = false

func _on_new_day_button_pressed() -> void:
	toolbar.visible = true
	legit_button.visible = true
	phishing_button.visible = true
	tool_button.visible = true
	time_label.visible = true
	day_playing_icon.visible = true
	day_bar.visible = false
	var style = StyleBoxFlat.new()
	style.bg_color = Color("c3c3c396")
	style.corner_radius_top_left = 60
	style.corner_radius_top_right = 60
	style.corner_radius_bottom_left = 60
	style.corner_radius_bottom_right = 60
	shape.visible = true
	shape.add_theme_stylebox_override("panel", style)
	shape.size = circle_size
	hover_url_button.visible = false
