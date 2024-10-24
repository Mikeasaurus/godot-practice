extends Node

@export var invincible: bool
@export var note_scene: PackedScene
@export var meteor_scene: PackedScene
var screen_width
var score = 0

# State of the game.
# 0 = Waiting (title screen)?
# 1 = Playing
# 2 = Game Over
var game_state: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_width = get_viewport().get_visible_rect().size.x
	start()

func update_score() -> void:
	$SplashScreen.text = "SCORE: %d\n\nCLICK / TAP\nTO START"%score
	$Score.text = str(score)

func increase_score() -> void:
	score = score + 10
	update_score()

func start() -> void:
	game_state = 0
	$Bright.color.a = 0.0
	$Dark.color.a = 1.0
	$EndMessage.disable()
	$MeteorTimer.stop()
	$Score.hide()
	update_score()
	$SplashScreen.show()

func play() -> void:
	game_state = 1
	$Bright.color.a = 0.0
	$Dark.color.a = 0.0
	$EndMessage.disable()
	$MeteorTimer.start()
	score = 0
	update_score()
	$Score.show()
	$SplashScreen.hide()

func stop() -> void:
	$MeteorTimer.stop()

func _input(event):
	if game_state == 0 and event is InputEventMouseButton and event.pressed:
		play()
	if game_state == 1 and event is InputEventMouseButton and event.pressed:
		#print ($Note.position, event.position)
		# Spawn a new note.
		var note = note_scene.instantiate()
		# Start at the reference location.
		note.position = $NoteLaunch.position
		# Note will aim in the direction where the mouse was clicked.
		var velocity = event.position - $NoteLaunch.position
		if velocity.x != 0 or velocity.y != 0:
			velocity = velocity.normalized()
			velocity *= 1000
		note.linear_velocity = velocity
		add_child(note)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Brightnening of sky during game over
	if game_state == 2:
		if $Bright.color.a < 1.0:
			$Bright.color.a += 0.5 * delta
			if $Bright.color.a >= 1.0:
				$Score.hide()
				update_score()
				$SplashScreen.show()
		elif $Dark.color.a < 0.95:
			$Dark.color.a += 0.5 * delta
			if $Dark.color.a >= 0.95:
				$EndMessage.set_value(0.040)
		elif $Dark.color.a < 1.0:
			$Dark.color.a += 0.5 * delta
		#elif $EndMessage.get_value() > 0.0:
		#	$EndMessage.dec_value(0.05*delta)
		#elif $EndMessage.get_value() <= 0.0:
		#	game_state = 0
		else:
			game_state = 0

# Called when ready for another meteor to fall.
func _on_meteor_timer_timeout() -> void:
	var meteor = meteor_scene.instantiate()
	var margin = 50
	# Put meteor in a random x location on the screen
	meteor.position.x = round(randf()*(screen_width-2*margin)) + margin
	meteor.position.y = -100
	add_child(meteor)
	meteor.hit.connect(increase_score)


func _on_ground_gameover() -> void:
	if invincible: return
	game_state = 2
	stop()
