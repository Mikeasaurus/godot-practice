extends Button

# Handle escape key trigger.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_toggle"):
		pressed.emit()
