extends Control

# Shortcuts to the colour picker buttons.
var _back: ColorPickerButton
var _body: ColorPickerButton
var _front: ColorPickerButton
var _outline: ColorPickerButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Adjust camera so whole worm is centered in the subview.
	$MarginContainer/CenterContainer/VBoxContainer/SubViewportContainer/SubViewport/Worm/WormFront/Sprites/Camera2D.offset = Vector2(-70,-49)
	# Initialize the colour selectors with the original colours.
	_back = $MarginContainer/CenterContainer/VBoxContainer/GridContainer/BackColorPickerButton
	_body = $MarginContainer/CenterContainer/VBoxContainer/GridContainer/BodyColorPickerButton
	_front = $MarginContainer/CenterContainer/VBoxContainer/GridContainer/FrontColorPickerButton
	_outline = $MarginContainer/CenterContainer/VBoxContainer/GridContainer/OutlineColorPickerButton
	_back.color = Globals.worm_back_colour
	_body.color = Globals.worm_body_colour
	_front.color = Globals.worm_front_colour
	_outline.color = Globals.worm_outline_colour
	# Update worm whenever new colours are selected.
	_back.color_changed.connect(Globals.set_worm_back_colour)
	_body.color_changed.connect(Globals.set_worm_body_colour)
	_front.color_changed.connect(Globals.set_worm_front_colour)
	_outline.color_changed.connect(Globals.set_worm_outline_colour)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_back_button_pressed() -> void:
	MenuHandler.deactivate_menu()

func _on_back_reset_button_pressed() -> void:
	Globals.worm_back_colour = Globals.original_worm_back_colour
	_back.color = Globals.original_worm_back_colour

func _on_body_reset_button_pressed() -> void:
	Globals.worm_body_colour = Globals.original_worm_body_colour
	_body.color = Globals.original_worm_body_colour

func _on_front_reset_button_pressed() -> void:
	Globals.worm_front_colour = Globals.original_worm_front_colour
	_front.color = Globals.original_worm_front_colour

func _on_outline_reset_button_pressed() -> void:
	Globals.worm_outline_colour = Globals.original_worm_outline_colour
	_outline.color = Globals.original_worm_outline_colour
