extends Control

signal quit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func _on_resume_button_pressed() -> void:
	MenuHandler.deactivate_menu()

func _on_options_button_pressed() -> void:
	# Start options sub-menu.
	MenuHandler.activate_menu($OptionsMenu)

func _on_quit_button_pressed() -> void:
	# Clear the pause menu off.
	MenuHandler.deactivate_menu()
	# Send signal for game to quit.
	quit.emit()
