extends Control

# Shortcuts to the colour picker buttons.
var _back: ColorPickerButton
var _body: ColorPickerButton
var _front: ColorPickerButton
var _outline: ColorPickerButton
var _bg: ColorPickerButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Adjust camera so whole worm is centered in the subview.
	$MarginContainer/CenterContainer/VBoxContainer/SubViewportContainer/SubViewport/Worm/WormFront/Sprites/Camera2D.offset = Vector2(-70,-49)
	# Initialize the colour selectors with the original colours.
	_back = $MarginContainer/CenterContainer/VBoxContainer/GridContainer/BackColorPickerButton
	_body = $MarginContainer/CenterContainer/VBoxContainer/GridContainer/BodyColorPickerButton
	_front = $MarginContainer/CenterContainer/VBoxContainer/GridContainer/FrontColorPickerButton
	_outline = $MarginContainer/CenterContainer/VBoxContainer/GridContainer/OutlineColorPickerButton
	_bg = $MarginContainer/CenterContainer/VBoxContainer/GridContainer/BGColorPickerButton
	_back.color = Globals.worm_back_colour
	_body.color = Globals.worm_body_colour
	_front.color = Globals.worm_front_colour
	_outline.color = Globals.worm_outline_colour
	_bg.color = Globals.worm_icon_bg_colour
	# Update worm whenever new colours are selected.
	_back.color_changed.connect(Globals.set_worm_back_colour)
	_body.color_changed.connect(Globals.set_worm_body_colour)
	_front.color_changed.connect(Globals.set_worm_front_colour)
	_outline.color_changed.connect(Globals.set_worm_outline_colour)
	_bg.color_changed.connect(Globals.set_worm_icon_bg_colour)
	# For multiplayer, use an icon instead of worm (for selecting icon background colour as well).
	if Globals.is_client:
		$MarginContainer/CenterContainer/VBoxContainer/SubViewportContainer.hide()
		var icon := $MarginContainer/CenterContainer/VBoxContainer/Icon
		icon.use_local_colours()
		Globals.worm_colour_updated.connect(icon.use_local_colours)
		icon.show()
		$MarginContainer/CenterContainer/VBoxContainer/GridContainer/BGLabel.show()
		$MarginContainer/CenterContainer/VBoxContainer/GridContainer/BGColorPickerButton.show()
		$MarginContainer/CenterContainer/VBoxContainer/GridContainer/BGResetButton.show()
		# Use icon background colour based on user's multiplayer handle.
		# Pseudo-randomly chosen, based on hash of handle.
		var icon_bg_colour: Color
		icon_bg_colour = Color.hex(0xffffffff)
		var h: int = hash(Globals.handle)
		icon_bg_colour.r8 -= (h%196); h /= 196
		icon_bg_colour.g8 -= (h%196); h /= 196
		icon_bg_colour.b8 -= (h%196); h /= 196
		# Set this colour within global scope, so other menus can use it too.
		Globals.worm_icon_bg_colour = icon_bg_colour
		Globals.original_worm_icon_bg_colour = icon_bg_colour
		_bg.color = Globals.worm_icon_bg_colour

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

func _on_bg_reset_button_pressed() -> void:
	Globals.worm_icon_bg_colour = Globals.original_worm_icon_bg_colour
	_bg.color = Globals.original_worm_icon_bg_colour
