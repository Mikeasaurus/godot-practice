extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_back_button_pressed() -> void:
	MenuHandler.deactivate_menu()

func _on_connect_button_pressed() -> void:
	var stderr: Label = $MarginContainer/CenterContainer/VBoxContainer/ErrorLabel
	var invite: String = $MarginContainer/CenterContainer/VBoxContainer/GridContainer/InviteCodeLineEdit.text
	var handle: String = $MarginContainer/CenterContainer/VBoxContainer/GridContainer/DisplayNameLineEdit.text
	stderr.text = ""
	if len(invite) == 0:
		stderr.text = "Please enter an invite code"
		return
	if len(handle) == 0:
		stderr.text = "Please enter a display name"
		return
	# Store connection info.
	Globals.invite = invite
	Globals.handle = handle
	# Clear this menu off the stack.
	MenuHandler.deactivate_menu()
	# Start the main game screen, which should detect the client / server info above (held in global state).
	Globals.is_client = true
	get_tree().change_scene_to_file("res://screen.tscn")
func _on_server_button_pressed() -> void:
	Globals.is_server = true
	# Clear this menu off the stack.
	MenuHandler.deactivate_menu()
	# Start the main game screen, which should detect the client / server info above (held in global state).
	get_tree().change_scene_to_file("res://screen.tscn")
