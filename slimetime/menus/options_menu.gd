extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect volume slider to global volume control signal.
	$MarginContainer/CenterContainer/VBoxContainer/GridContainer/VolumeHSlider.value = Globals.volume
	$MarginContainer/CenterContainer/VBoxContainer/GridContainer/VolumeHSlider.value_changed.connect(Globals.set_volume)
	$MarginContainer/CenterContainer/VBoxContainer/GridContainer/GraphicsOptionButton.selected = Globals.graphics_level
	# For multiplayer, use icon for colour scheme.
	if Globals.is_client:
		$MarginContainer/CenterContainer/VBoxContainer/GridContainer/VBoxContainer/SubViewPortContainer.hide()
		var icon := $MarginContainer/CenterContainer/VBoxContainer/GridContainer/VBoxContainer/Icon
		icon.use_local_colours()
		Globals.worm_colour_updated.connect(icon.use_local_colours)
		icon.show()
	# For single player, use a view of the full worm.
	else:
		# Align camera for worm preview.
		# By default it's centered on the front torso, need to center on actual middle of worm.
		$MarginContainer/CenterContainer/VBoxContainer/GridContainer/VBoxContainer/SubViewPortContainer/SubViewport/Worm/WormFront/Sprites/Camera2D.offset = Vector2(-32,-25)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_back_button_pressed() -> void:
	MenuHandler.deactivate_menu()

func _on_graphics_option_button_item_selected(index: int) -> void:
	Globals.graphics_level = index

func _on_controls_button_pressed() -> void:
	MenuHandler.activate_menu($ControlsMenu)

func _on_edit_appearance_button_pressed() -> void:
	MenuHandler.activate_menu($AppearanceMenu)
