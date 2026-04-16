extends Node2D

@export var grid_size := 32
@export var board_width := 20
@export var board_height := 15
@export var tick_rate := 0.12

var score := 0
var game_over := false
var direction := Vector2i.RIGHT
var next_direction := Vector2i.RIGHT
var snake := []
var grow_pending := 0
var food := Vector2i.ZERO

@onready var timer: Timer = $Timer
@onready var score_label: Label = $ScoreLabel
@onready var game_over_label: Label = $UI/GameOverLabel

func _ready():
	randomize()
	timer.timeout.connect(_on_tick)
	start_game()

func start_game():
	score = 0
	game_over = false
	direction = Vector2i.RIGHT
	next_direction = Vector2i.RIGHT
	snake = [Vector2i(5,5), Vector2i(4,5), Vector2i(3,5)]
	grow_pending = 0
	spawn_food()
	score_label.text = "Score: 0"
	game_over_label.visible = false
	timer.wait_time = tick_rate
	timer.start()
	scale = Vector2.ONE
	rotation = 0
	queue_redraw()

func spawn_food():
	food = Vector2i(randi() % board_width, randi() % board_height)
	while food in snake:
		food = Vector2i(randi() % board_width, randi() % board_height)

func _on_tick():
	if game_over:
		return

	direction = next_direction
	var head = snake[0] + direction

	if head.x < 0 or head.y < 0 or head.x >= board_width or head.y >= board_height:
		crash()
		return

	if head in snake:
		crash()
		return

	snake.push_front(head)

	if head == food:
		score += 1
		score_label.text = "Score: %d" % score
		grow_pending += 1
		Sound.play_sound("SnakeEat")
		spawn_food()
	
	if grow_pending > 0:
		grow_pending -= 1
	else:
		snake.pop_back()

	queue_redraw()

func crash():
	Sound.play_sound("SnakeGameover")

	game_over = true
	timer.stop()
	game_over_label.visible = true
	var tween = create_tween()
	modulate = Color.WHITE
	tween.tween_property(self, "modulate", Color(1, 0.15, 0.15), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.10)
	
	await get_tree().create_timer(1.0).timeout
	if visible == true:
		start_game()

func _unhandled_input(event):
	if event.is_action_pressed("ui_up") and direction != Vector2i.DOWN:
		next_direction = Vector2i.UP
	elif event.is_action_pressed("ui_down") and direction != Vector2i.UP:
		next_direction = Vector2i.DOWN
	elif event.is_action_pressed("ui_left") and direction != Vector2i.RIGHT:
		next_direction = Vector2i.LEFT
	elif event.is_action_pressed("ui_right") and direction != Vector2i.LEFT:
		next_direction = Vector2i.RIGHT
	elif event.is_action_pressed("ui_accept") and game_over:
		start_game()

func _draw():
	draw_rect(Rect2(Vector2.ZERO, Vector2(board_width * grid_size, board_height * grid_size)), Color(0.08,0.08,0.08), true)

	for x in board_width:
		for y in board_height:
			draw_rect(Rect2(x * grid_size, y * grid_size, grid_size - 1, grid_size - 1), Color(0.12,0.12,0.12), false)

	var food_center = Vector2(food * grid_size) + Vector2.ONE * grid_size / 2.0
	draw_circle(food_center, grid_size * 0.32, Color.RED)

	for i in range(snake.size()):
		var pos = Vector2(snake[i] * grid_size)
		var color = Color.LIME_GREEN if i == 0 else Color.GREEN
		draw_rect(Rect2(pos, Vector2(grid_size, grid_size)), color, true)
		draw_rect(Rect2(pos, Vector2(grid_size, grid_size)), Color.BLACK, false, 2)

func start():
	visible = true
	set_process(true)
	set_physics_process(true)
	timer.start()
	game_over = false

func stop():
	timer.stop()
	set_process(false)
	set_physics_process(false)
	visible = false
