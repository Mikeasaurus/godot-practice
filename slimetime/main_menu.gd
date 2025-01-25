extends Control

var options_scene: PackedScene = load("res://options_menu.tscn")
var options_menu: Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	options_menu = options_scene.instantiate()
	options_menu.hide()
	options_menu.pop_menu.connect(_return_from_options_menu)
	add_sibling.call_deferred(options_menu)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_new_game_button_pressed() -> void:
	get_tree().change_scene_to_file("res://screen.tscn")


func _on_options_button_pressed() -> void:
	$MarginContainer.hide()
	$NestedMenuHandler.activate_menu(options_menu)

func _return_from_options_menu() -> void:
	$NestedMenuHandler.deactivate_menu()
	$MarginContainer.show()
