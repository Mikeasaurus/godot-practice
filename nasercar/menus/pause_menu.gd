extends Control

signal _done (quit:bool)

func run () -> bool:
	show()
	var quit: bool = await _done
	# If unpausing (and continuing game), hide the pause menu.
	if not quit:
		hide()
	# Otherwise, hide the elements but keep the fade-out.
	else:
		$MarginContainer/CenterContainer/VBoxContainer.hide()
	return quit

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_toggle"):
		_done.emit(false)

func _on_quit_button_pressed() -> void:
	_done.emit(true)
