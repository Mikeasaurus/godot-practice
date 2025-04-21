extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


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
	var server: String = Globals.check_invite(invite)
	if server == "":
		stderr.text = "Invalid invite code"
		return
	if len(handle) == 0:
		stderr.text = "Please enter a display name"
		return
	# Store connection info.
	Globals.invite = invite
	Globals.handle = handle
	# Establish a connection to the server.
	multiplayer.multiplayer_peer = null
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	var peer := WebSocketMultiplayerPeer.new()
	peer.create_client("ws://"+Globals.check_invite(Globals.invite)+":1156")
	multiplayer.multiplayer_peer = peer
	# Stop user from trying to connect while establishing a connection.
	$MarginContainer/CenterContainer/VBoxContainer/HBoxContainer/ConnectButton.disabled = true
func _error_message (msg: String) -> void:
	var stderr: Label = $MarginContainer/CenterContainer/VBoxContainer/ErrorLabel
	stderr.text = msg
	$MarginContainer/CenterContainer/VBoxContainer/HBoxContainer/ConnectButton.disabled = false
func _on_connection_failed():
	_error_message ("Connection failed")
# This is called when the server connection is tested, and is a working server.
func _on_connected_to_server():
	# Get server info.
	Globals.server_info.connect(_on_server_info_received)
	Globals.request_server_info()
func _on_server_info_received (info: Dictionary) -> void:
	# Make sure we have a compatible version.
	if info['version'] != Globals.version:
		_error_message ("Server requires version %s to connect."%info['version'])
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		return
	# Clear this menu off the stack.
	MenuHandler.deactivate_menu()
	# Start the main game screen, which should detect the client / server info above (held in global state).
	Globals.is_client = true
	# Disconnect this test connection, start main screen to establish full connection.
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://screen.tscn")
func _on_server_button_pressed() -> void:
	Globals.is_server = true
	# Clear this menu off the stack.
	MenuHandler.deactivate_menu()
	# Start the main game screen, which should detect the client / server info above (held in global state).
	get_tree().change_scene_to_file("res://screen.tscn")
