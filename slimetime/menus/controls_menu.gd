extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Globals.touchscreen_controls:
		$MarginContainer/CenterContainer/VBoxContainer/GridContainer_keyboard_controls.hide()
		$MarginContainer/CenterContainer/VBoxContainer/GridContainer_touchscreen.show()
	if not Globals.is_client:
		$MarginContainer/CenterContainer/VBoxContainer/GridContainer_keyboard_controls/ChatLabel.hide()
		$MarginContainer/CenterContainer/VBoxContainer/GridContainer_keyboard_controls/ChatText.hide()
		$MarginContainer/CenterContainer/VBoxContainer/GridContainer_touchscreen/ChatLabel.hide()
		$MarginContainer/CenterContainer/VBoxContainer/GridContainer_touchscreen/ChatText.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_back_button_pressed() -> void:
	MenuHandler.deactivate_menu()
