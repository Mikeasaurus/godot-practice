extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MenuHandler.done_submenus.connect(_return_from_submenu)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_new_game_button_pressed() -> void:
	get_tree().change_scene_to_file("res://screen.tscn")

func _on_options_button_pressed() -> void:
	$MarginContainer.hide()
	MenuHandler.activate_menu($OptionsMenu)

func _on_credits_button_pressed() -> void:
	$MarginContainer.hide()
	MenuHandler.activate_menu($CreditsMenu)

# When submenus are done, need to show the main menu again.
func _return_from_submenu() -> void:
	$MarginContainer.show()
