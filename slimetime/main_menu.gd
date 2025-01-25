extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_new_game_button_pressed() -> void:
	get_tree().change_scene_to_file("res://screen.tscn")


func _on_options_button_pressed() -> void:
	$MarginContainer.hide()
	$NestedMenuHandler.activate_menu($OptionsMenu)


func _on_options_menu_back() -> void:
	$NestedMenuHandler.deactivate_menu()
	$MarginContainer.show()
