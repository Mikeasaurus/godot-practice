extends Control

# Tell parent screen to ignore any pause key, because it's still the leftover
# "unpause" signal, not a new signal.
signal ignore_pausekey

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_toggle"):
		ignore_pausekey.emit()
		unpause_game()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func unpause_game () -> void:
	hide()
	get_tree().paused = false
