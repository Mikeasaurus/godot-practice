extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_back_button_pressed() -> void:
	MenuHandler.deactivate_menu()
	
func _store_connection_info() -> void:
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
	Globals.invite = _check_code(invite)
	Globals.handle = handle
	# Clear this menu off the stack.
	MenuHandler.deactivate_menu()
	# Start the main game screen, which should detect the client / server info above (held in global state).
func _on_connect_button_pressed() -> void:
	_store_connection_info()
	get_tree().change_scene_to_file("res://multiplayer/client.tscn")
func _on_hybrid_button_pressed() -> void:
	_store_connection_info()
	get_tree().change_scene_to_file("res://multiplayer/hybrid.tscn")


func _check_code (code: String) -> String:
	var table: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	code = code.to_upper()
	var n: int = 0
	for i in range(len(code)):
		n = n * 36 + table.find(code[i])
	n = (n*1000000) % (36**8-19)
	if (n >= 2**32): return ''
	var s: String = str(n%256)
	for i in range(3):
		n >>= 8
		s = str(n%256) + '.' + s
	return s

func _create_server () -> void:
	var server := WebSocketMultiplayerPeer.new()
	if Globals.server != null:
		print ("Disconnecting old server before creating new one.")
		Globals.server.close()
	Globals.server = server
	Globals.is_multiplayer = true
	server.create_server(1156)

func _create_client (code: String) -> void:
	var client := WebSocketMultiplayerPeer.new()
	if Globals.client != null:
		print ("Disconnecting old client connection before creating new one.")
		Globals.client.close()
	Globals.client = client
	Globals.is_multiplayer = true
	client.create_client("ws://"+_check_code(code)+":1156")
