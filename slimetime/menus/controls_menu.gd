extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# If auto-target is being used, display modified controls.
	if Globals.auto_target:
		$MarginContainer/CenterContainer/VBoxContainer/GridContainer/ShootSlimeText.hide()
		$MarginContainer/CenterContainer/VBoxContainer/GridContainer/ShootSlimeText_autotarget.show()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_back_button_pressed() -> void:
	MenuHandler.deactivate_menu()
