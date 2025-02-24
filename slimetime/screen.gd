extends Node2D

var is_game_over: bool = false

# Keep track of peer worms (if in multiplayer game)
var PeerWormFactory := preload("res://worm/worm.tscn")
var peer_worms := {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect the menu toggle key for pausing / unpausing the game.
	MenuHandler.pause.connect(pause_game)
	MenuHandler.done_submenus.connect(unpause_game)
	if Globals.touchscreen_controls:
		$Overlay/PauseButton.show()
		$Overlay/PauseButton.pressed.connect(pause_game)
	# Connect worm damage signal directly to game over screen.
	$Worm.hurt.connect(game_over)
	$Overlay/LogTimer.timeout.connect(_next_log)

# Make this screen a server process, listening for incoming connections.
func _make_server () -> void:
	multiplayer.multiplayer_peer = null
	multiplayer.peer_connected.connect(_on_client_connected)
	multiplayer.peer_disconnected.connect(_on_client_disconnected)
	var peer := WebSocketMultiplayerPeer.new()
	peer.create_server(1156)
	multiplayer.multiplayer_peer = peer
# Make this screen a client process, and connect to the specified server.
func _make_client (server) -> void:
	multiplayer.multiplayer_peer = null
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	var peer := WebSocketMultiplayerPeer.new()
	peer.create_client("ws://"+server+":1156")
	multiplayer.multiplayer_peer = peer
	# Set up name label for worm (but make invisible so it's not displayed lcoally).
	$Worm/WormFront/Sprites/NameLabel.text = Globals.handle
	$Worm/WormFront/Sprites/NameLabel.hide()
	# Transmit worm info at a regular interval to the server, so other peers can see current location.
	$TransmitTimer.timeout.connect(_send_worm_info)
	$TransmitTimer.start()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

# Listen for some keys.
func _input(event: InputEvent) -> void:
	if Globals.debug_keys and event.is_action_pressed("instakill"):
		game_over()
	elif is_game_over == true and (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		restart()
		
func _on_worm_ate_bug() -> void:
	Globals.score += 100
	$Overlay/Score.text = "Score:\n %d"%Globals.score

# Trigger a game over screen.
func game_over () -> void:
	if is_game_over: return  # Game Over screen already initiated?
	$Worm.explode()
	if Globals.touchscreen_controls:
		$GameOverScreen/Label.text = "GAME OVER\nScore: %d\n\nTap screen to restart"%Globals.score
	else:
		$GameOverScreen/Label.text = "GAME OVER\nScore: %d\n\nPress any key / click to restart"%Globals.score
	$GameOverScreen.visible = true
	# Fade in the "GAME OVER" text.
	var tween: Tween = get_tree().create_tween()
	tween.tween_interval(1.0)
	tween.tween_property($GameOverScreen/Label, "theme_override_colors/font_color", Color.WHITE, 1.0)
	# Delay before waiting for a key press to restart.
	# "await" idea copied from ProjectEruption.
	await get_tree().create_timer(2.0).timeout
	is_game_over = true

# Restart the game after a game over screen.
func restart () -> void:
	get_tree().paused = false  # Unpause the game.
	Globals.reset()  # Reset global state (score, etc.)
	MenuHandler.clear_menus()
	get_tree().change_scene_to_file("res://menus/main_menu.tscn")

# Bring up pause menu.
func pause_game () -> void:
	# Ignore the pause functionality if in a game over state.
	if is_game_over: return
	get_tree().paused = true
	MenuHandler.activate_menu($Overlay/PauseMenu)

func unpause_game () -> void:
	get_tree().paused = false


# Multiplayer functionality

# Keep track of all connected players (server only)
var players := {}
# Messages that appear on the top of the screen.
var logs := []
var next_log : int = 0
# Chat history
var chat := []

# Pass user information once connection is made.
func _on_connected_to_server () -> void:
	# Send our player info to the server.
	_send_player_info.rpc_id(1,Globals.handle,[Globals.worm_body_colour,Globals.worm_back_colour,Globals.worm_front_colour,Globals.worm_outline_colour])
	# Start the log message display, after a short delay to wait for our own connection message.
	await get_tree().create_timer(0.2).timeout
	_next_log()
	$Overlay/LogTimer.start()
func _on_client_connected (id) -> void:
	# When a client connects, synchronize their state.
	_startup_package.rpc_id(id,chat)
func _on_client_disconnected (id) -> void:
	_log.rpc("%s has left the server."%players[id][0])
	players.erase(id)
	_remove_peer_worm.rpc(id)
# Give new client all info needed to get started.
@rpc("reliable")
func _startup_package (chat_history):
	chat.append_array(chat_history)
@rpc("any_peer","reliable")
func _send_player_info (handle,colours) -> void:
	players[multiplayer.get_remote_sender_id()] = [handle,colours]
	_log.rpc("%s has joined the server."%handle)
# Send a system message to the clients.
@rpc("call_local","reliable")
func _log (msg: String) -> void:
	logs.append(msg)
	if multiplayer.is_server():
		print (msg)
# Triggered by LogTimer
func _next_log () -> void:
	if next_log < len(logs):
		$Overlay/LogLabel.text = logs[next_log]
		$Overlay/LogLabel.add_theme_color_override("font_color",Color(0,1,0,1))
		$Overlay/LogLabel.add_theme_color_override("font_outline_color",Color(0,0,0,1))
		next_log += 1
	else:
		# If no new messages, fade out the last message shown.
		var tween: Tween = get_tree().create_tween()
		tween.tween_property($Overlay/LogLabel, "theme_override_colors/font_color", Color(0,1,0,0), 1)
		tween.parallel().tween_property($Overlay/LogLabel, "theme_override_colors/font_outline_color", Color(0,0,0,0), 1)
# Send a message to the chat.
@rpc("any_peer","call_local","reliable")
func _send_chat (msg: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	# Encode bubble position, sender info.
	chat.append([players[sender],msg])
# Send worm info to others.
func _send_worm_info () -> void:
	_peer_worm_update.rpc($Worm.serialize())
@rpc("any_peer")
func _peer_worm_update (worm_info) -> void:
	var id: int = multiplayer.get_remote_sender_id()
	if id not in peer_worms:
		peer_worms[id] = PeerWormFactory.instantiate()
		peer_worms[id].passive()
		$Peers.add_child(peer_worms[id])
	peer_worms[id].deserialize(worm_info)
# Clean up when a peer leaves the game.
@rpc("reliable")
func _remove_peer_worm (id) -> void:
	peer_worms[id].queue_free()
	peer_worms.erase(id)
