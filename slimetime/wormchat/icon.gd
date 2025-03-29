extends CenterContainer

class_name Icon

var body: Color
var back: Color
var front: Color
var outline: Color
var bg: Color

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Body.modulate = body
	$Top.modulate = back
	$Belly.modulate = front
	$AppendageOutline.modulate = outline
	$Eyes.modulate = outline
	$Mouth.modulate = body
	$Outline.modulate = outline
	$Background.modulate = bg
