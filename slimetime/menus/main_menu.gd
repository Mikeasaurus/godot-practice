extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MenuHandler.done_submenus.connect(_return_from_submenu)
	# Print version info.
	$VersionLabel.text = "Slime Time v" + Globals.version
	# Can't "quit" from web version.
	if OS.get_name() == "Web":
		$MarginContainer/CenterContainer/VBoxContainer/QuitButton.hide()
	else:
		$MarginContainer/CenterContainer/VBoxContainer/DownloadButton.hide()
	# If running in headless mode, then immediately start the server.
	if DisplayServer.get_name() == "headless":
		Globals.is_server = true
		get_tree().call_deferred("change_scene_to_file","res://screen.tscn")

func _on_new_game_button_pressed() -> void:
	get_tree().change_scene_to_file("res://screen.tscn")

func _on_multiplayer_button_pressed() -> void:
	$MarginContainer.hide()
	MenuHandler.activate_menu($MultiplayerMenu)

func _on_options_button_pressed() -> void:
	$MarginContainer.hide()
	MenuHandler.activate_menu($OptionsMenu)

func _on_credits_button_pressed() -> void:
	$MarginContainer.hide()
	MenuHandler.activate_menu($CreditsMenu)

# When submenus are done, need to show the main menu again.
func _return_from_submenu() -> void:
	$MarginContainer.show()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_download_button_pressed() -> void:
	$MarginContainer.hide()
	MenuHandler.activate_menu($DownloadMenu)
