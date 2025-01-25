extends Control

var options_scene: PackedScene = load("res://options_menu.tscn")
var options_menu: Control
var credits_scene: PackedScene = load("res://credits_menu.tscn")
var credits_menu: Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	options_menu = options_scene.instantiate()
	options_menu.hide()
	options_menu.pop_menu.connect(_return_from_submenu)
	add_sibling.call_deferred(options_menu)
	credits_menu = credits_scene.instantiate()
	credits_menu.hide()
	credits_menu.pop_menu.connect(_return_from_submenu)
	add_sibling.call_deferred(credits_menu)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_new_game_button_pressed() -> void:
	get_tree().change_scene_to_file("res://screen.tscn")


func _on_options_button_pressed() -> void:
	$MarginContainer.hide()
	$NestedMenuHandler.activate_menu(options_menu)

func _on_credits_button_pressed() -> void:
	$MarginContainer.hide()
	$NestedMenuHandler.activate_menu(credits_menu)

func _return_from_submenu() -> void:
	$NestedMenuHandler.deactivate_menu()
	$MarginContainer.show()

# A hack to redraw the MarginContainer when returning from a submenu from the escape key.
# In that case, there's no "Back" button press to get a signal from, so have to trap the key stroke?
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_toggle") and len($NestedMenuHandler.menu_stack) == 0:
		$MarginContainer.show()
