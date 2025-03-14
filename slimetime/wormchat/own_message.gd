extends MarginContainer

class_name OwnMessage

var text: String

# Called when the node enters the scene tree for the first time.
func _enter_tree() -> void:
	$OwnText.text = text
