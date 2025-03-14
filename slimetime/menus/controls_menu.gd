extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Globals.touchscreen_controls:
		$MarginContainer/CenterContainer/VBoxContainer/GridContainer_keyboard_controls.hide()
		$MarginContainer/CenterContainer/VBoxContainer/GridContainer_touchscreen.show()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_back_button_pressed() -> void:
	MenuHandler.deactivate_menu()
