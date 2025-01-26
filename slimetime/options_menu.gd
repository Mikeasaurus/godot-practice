extends Control

signal pop_menu
signal push_menu

var controls_scene: PackedScene = load("res://controls_menu.tscn")
var controls_menu: Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect volume slider to global volume control signal.
	$MarginContainer/CenterContainer/VBoxContainer/GridContainer/VolumeHSlider.value = Globals.volume
	$MarginContainer/CenterContainer/VBoxContainer/GridContainer/VolumeHSlider.value_changed.connect(Globals.set_volume)
	$MarginContainer/CenterContainer/VBoxContainer/GridContainer/GraphicsOptionButton.selected = Globals.graphics_level
	# Align camera for worm preview.
	# By default it's centered on the front torso, need to center on actual middle of worm.
	$MarginContainer/CenterContainer/VBoxContainer/GridContainer/VBoxContainer/SubViewPortContainer/SubViewport/Worm/WormFront/AnimatedSprite2D/Camera2D.offset = Vector2(-32,-25)
	# Set up controls submenu
	controls_menu = controls_scene.instantiate()
	controls_menu.hide()
	controls_menu.pop_menu.connect(pop_menu.emit)
	add_sibling.call_deferred(controls_menu)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_back_button_pressed() -> void:
	pop_menu.emit()


func _on_graphics_option_button_item_selected(index: int) -> void:
	Globals.graphics_level = index

func _on_controls_button_pressed() -> void:
	push_menu.emit(controls_menu)
