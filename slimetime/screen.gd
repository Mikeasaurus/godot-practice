extends Node2D

var is_game_over: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect the menu toggle key for pausing / unpausing the game.
	MenuHandler.pause.connect(pause_game)
	MenuHandler.done_submenus.connect(unpause_game)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

# Listen for some keys.
func _input(event: InputEvent) -> void:
	if Globals.debug_keys and event.is_action_pressed("instakill"):
		game_over()
	elif is_game_over == true and (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		restart()
		
func _on_worm_ate_bug() -> void:
	Globals.score += 100
	$Overlay/Score.text = "Score:\n %d"%Globals.score

# Trigger a game over screen.
func game_over () -> void:
	$Worm.explode()
	$GameOverScreen/Label.text = "GAME OVER\nScore: %d\n\nPress any key / click to restart"%Globals.score
	$GameOverScreen.visible = true
	# Fade in the "GAME OVER" text.
	var tween: Tween = get_tree().create_tween()
	tween.tween_interval(1.0)
	tween.tween_property($GameOverScreen/Label, "theme_override_colors/font_color", Color.WHITE, 1.0)
	# Delay before waiting for a key press to restart.
	# "await" idea copied from ProjectEruption.
	await get_tree().create_timer(2.0).timeout
	is_game_over = true

# Restart the game after a game over screen.
func restart () -> void:
	get_tree().paused = false  # Unpause the game.
	Globals.reset()  # Reset global state (score, etc.)
	get_tree().change_scene_to_file("res://menus/main_menu.tscn")

# Bring up pause menu.
func pause_game () -> void:
	# Ignore the pause functionality if in a game over state.
	if is_game_over: return
	get_tree().paused = true
	MenuHandler.activate_menu($Overlay/PauseMenu)

func unpause_game () -> void:
	get_tree().paused = false
