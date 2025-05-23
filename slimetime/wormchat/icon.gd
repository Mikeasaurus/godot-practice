extends CenterContainer

class_name Icon

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var default_colours: Array[Color] = [
		Globals.original_worm_body_colour,
		Globals.original_worm_back_colour,
		Globals.original_worm_front_colour,
		Globals.original_worm_outline_colour,
		Globals.original_worm_icon_bg_colour
	]
	update_colours(default_colours)

# Use the current user's colours for the worm.
func use_local_colours() -> void:
	update_colours([
		Globals.worm_body_colour,
		Globals.worm_back_colour,
		Globals.worm_front_colour,
		Globals.worm_outline_colour,
		Globals.worm_icon_bg_colour
	])

# Update colours of the icon.
func update_colours (icon_colours: Array[Color]) -> void:
	if len(icon_colours) == 0: return
	var body: Color = icon_colours[0]
	var back: Color = icon_colours[1]
	var front: Color = icon_colours[2]
	var outline: Color = icon_colours[3]
	var bg: Color = icon_colours[4]
	$Body.modulate = body
	$Top.modulate = back
	$Belly.modulate = front
	$AppendageOutline.modulate = outline
	$Eyes.modulate = outline
	$Mouth.modulate = body
	$Outline.modulate = outline
	$Background.modulate = bg
