extends HBoxContainer

class_name Text

@export var maximum_width: float = 500
var text: String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$CenterVBox/Center/Label.text = text

# Apply line wrapping.
func _on_label_resized() -> void:
	var label: Label = $CenterVBox/Center/Label
	if label.size.x > maximum_width:
		label.custom_minimum_size = Vector2(maximum_width,0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
