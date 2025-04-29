extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Add URI to current version.
	$ColorRect/MarginContainer/CenterContainer/VBoxContainer/HBoxContainer/WindowsLinkButton.uri = "./slimetime-v%s.zip"%Globals.version
	$ColorRect/MarginContainer/CenterContainer/VBoxContainer/HBoxContainer/LinuxLinkButton.uri = "./slimetime-linux-v%s.zip"%Globals.version

func _on_back_button_pressed() -> void:
	MenuHandler.deactivate_menu()
