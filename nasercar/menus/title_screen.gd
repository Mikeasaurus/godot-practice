extends Control

@onready var _naomi := $CarSelection/MarginContainer/CenterContainer/VBoxContainer/GridContainer/Naomi

# List of all race instances running / being created.
# (for server side).
# Key is host player id, values are dictionaries of participants.
var _races: Dictionary = {}
# Table of currently running races.
# (also for server side).
# Key is race number, values are the nodes containing the races.
var _running_races: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var notracks: Array[TileMapLayer] = []
	$NaserCar.add_to_track($Path2D,notracks)
	$NaserCar.make_local_cpu()
	_reset_car()
	$CarTimer.start()
	MenuHandler.done_submenus.connect(_reset_and_start_timer)
	$CarSelection.singleplayer_race.connect(start_race)
	# Need to unlock Naomi kart.
	_naomi.hide()
	# If this is configured as a headless server, then set up the connection.
	if DisplayServer.get_name() == "headless":
		_make_server()
	# Error messages from other screens, when returning.
	$MultiplayerCarSelection.error_message.connect(_error_message)
	# Handles cases where the player needs to disconnect from the server.
	# (going back to single-player mode).
	$Multiplayer.leave_server.connect(_leave_server)
	$MultiplayerCarSelection.leave_server.connect(_leave_server)
	# Spawn a race in multiplayer context.
	$MultiplayerSpawner.spawn_function = _spawn_multiplayer_race

# Multiplayer server setup.
func _make_server () -> void:
	# Set up server, listening for incoming peers.
	multiplayer.multiplayer_peer = null
	#multiplayer.peer_disconnected.connect(_on_client_disconnected)
	var peer := WebSocketMultiplayerPeer.new()
	if "--local" in OS.get_cmdline_user_args():
		peer.create_server(1157)
	else:
		#NOTE: remote server should be run with the command-line options --headless --max-fps=45
		# Need to run without a display, and also limit the fps to avoid excessive
		# jitter when syncing game state via Websocket/TCP.
		var key := load("res://cert/privkey.key")
		var cert := load("res://cert/fullchain.crt")
		var tls_options := TLSOptions.server(key,cert)
		peer.create_server(1157,"*",tls_options)
	multiplayer.multiplayer_peer = peer
	# Turn off the Naser car for server instance, otherwise it gets synchronized to all the players and
	# they see an extra car floating around the screen!
	_reset_car()
	# Propogate multiplayer race info to car selection menu.
	$MultiplayerCarSelection._races = _races
	$MultiplayerCarSelection.refresh_race.connect(_refresh_race)
	# Signals for starting the race.
	$MultiplayerCarSelection.multiplayer_race.connect(_start_multiplayer_race)

func _reset_car() -> void:
	$NaserCar.set_deferred("global_position",Vector2(-53,-75))
	$NaserCar.set_deferred("linear_velocity",Vector2.ZERO)
	$NaserCar.freeze = true
	$NaserCar.show()
	$NaserCar.stop()
	$CarTimer.stop()
func _reset_and_start_timer() -> void:
	_reset_car()
	$CarTimer.start()

func _on_help_pressed() -> void:
	_reset_car()
	MenuHandler.activate_menu($Help)

func _on_single_player_pressed() -> void:
	_reset_car()
	MenuHandler.activate_menu($CarSelection)

# When multiplayer is clicked, need to start a connection to the server.
func _on_multiplayer_pressed() -> void:
	multiplayer.multiplayer_peer = null
	if not multiplayer.connected_to_server.is_connected(_launch_multiplayer_menu):
		multiplayer.connected_to_server.connect(_launch_multiplayer_menu)
	var peer := WebSocketMultiplayerPeer.new()
	if "--local" in OS.get_cmdline_user_args():
		peer.create_client("ws://localhost:1157")
	else:
		peer.create_client("wss://nasercar.mikeasaurus.ca:1157")
	multiplayer.multiplayer_peer = peer
# This is called once the server process is established.
func _launch_multiplayer_menu() -> void:
	_reset_car()
	MenuHandler.activate_menu($Multiplayer)

func _on_car_timer_timeout() -> void:
	$NaserCar.freeze = false
	$NaserCar.go()

# Called within server (from kart selection screen back to main screen) to indicate
# a race is ready to start.
func _start_multiplayer_race(race_id: int, participants: Dictionary) -> void:
	# Construct a list of all race participants, starting with the host.
	var player_ids: Array[int] = [race_id]
	for player_id in participants.keys():
		if player_id not in player_ids:
			player_ids.append(player_id)
	# Find a free index for the race.
	# Starting at index 1 instead of 0, to always start in an offset.
	# (avoids visual glitches where things spawn starting at the origin).
	var index: int = 1
	while index in _running_races:
		index += 1
	var race: World = $MultiplayerSpawner.spawn([index,player_ids,"res://tracks/default.tscn"])
	var player_names: Array[String] = []
	for player_id in participants.keys():
		player_names.append(participants[player_id][0])
	print ("Starting multiplayer race ", race_id, " at index ", index, " with players ", "," .join(player_names), ".")
	_running_races[index] = race
	# Configure the race with the given participants.
	if multiplayer.get_unique_id() == 1:  # Why do I need to check this???
		race.setup_race(participants)
		# Free the race object once all players have left the game.
		await race.quit
		print ("Finished multiplayer race ", race_id)
		_running_races.erase(index)
		race.queue_free()

# This is called to create a multiplayer race among all peers.
# "data" is the race_id, and dictionary containing all players / karts for the race.
func _spawn_multiplayer_race (data: Array) -> Node:
	var race: Node
	var index: int = data[0]
	var player_ids: Array[int] = data[1]
	var track_scene_path: String = data[2]
	# For the server and participating peers, this will be the fully constructed race.
	var player_id: int = multiplayer.get_unique_id()
	if player_id == 1 or player_id in player_ids:
		race = load("res://world.tscn").instantiate()
		# Each race is offset so that they don't overlap in the coordinate space.
		# So that rigid bodies from different races don't collide with each other... haha.
		race.global_position.x = 100000*index
		var track: Track = load(track_scene_path).instantiate()
		# Set up participants for track (for synchronization of peers).
		# Don't need the specific cars, just the player ids.
		var participants: Dictionary = {}
		for id in player_ids:
			participants[id] = null
		# Need to defer call to this, otehrwise the itemblocks don't show up as children and don't get set up?
		track.call_deferred('setup',participants)
		race.set_track(track)
	# For other peers, just put a simple dummy object here.
	else:
		race = Node.new()
		#race = load("res://world.tscn").instantiate()
		#race.process_mode = Node.PROCESS_MODE_DISABLED
	# Set a consistent name for this race across all peers.
	# Use the id of the host player (first entry).
	race.name = str(player_ids[0])
	return race

func start_race (player_car: Car) -> void:
	# Set up the player car based on the car type chosen.
	# For single-player games, player id is just 1.
	var participants: Dictionary = {1:["Player",player_car.display_name]}
	# Load up the race track.
	var race: World = load("res://world.tscn").instantiate()
	add_child(race)
	var track: Track = load("res://tracks/default.tscn").instantiate()
	# Need to defer call to this, otehrwise the itemblocks don't show up as children and don't get set up?
	track.call_deferred('setup',participants)
	race.set_track(track)
	race.setup_race(participants)
	# Turn off Naser car visual.
	# Do this after a bit of a delay, because there's a call to _reset_and_start_timer around the same
	# time as this (from MenuHandler) that would cause the Naser car to start on its own.
	#
	$NaserCar.call_deferred("hide")
	await get_tree().create_timer(0.1).timeout
	MenuHandler.done_submenus.disconnect(_reset_and_start_timer)
	$NaserCar.call_deferred("hide")
	_reset_car()
	#
	# Let the race finish, and get the player's final place in the race.
	var place: int
	place = await race.quit
	if place == 1 and not _naomi.visible:
		$Naomi.process_mode = Node.PROCESS_MODE_INHERIT
		$NaserCar.call_deferred("hide")
		MenuHandler.activate_menu($Naomi)
		await get_tree().create_timer(0.1).timeout
		$NaserCar.call_deferred("hide")
		_reset_car()
		_naomi.show()
	else:
		call_deferred("_reset_and_start_timer")
	race.queue_free()
	# Restore Naser car.
	MenuHandler.done_submenus.connect(_reset_and_start_timer)
	_reset_and_start_timer()

# This is called once the player selects a multiplayer race to join.
# This is called from peer instance.  Need to coordinate with the server.
func _on_multiplayer_join_race(race_id: int, handle: String) -> void:
	_peer_joining_race.rpc_id(1, race_id, handle)
	# Open car selection menu with multiplayer context.
	_reset_car()
	MenuHandler.activate_menu($MultiplayerCarSelection)
# Server side - bookkeeping for current races.
@rpc("any_peer","reliable")
func _peer_joining_race(race_id: int, handle: String) -> void:
	# Get id of the peer that's joining.
	var id: int = multiplayer.get_remote_sender_id()
	# If this race doesn't exist yet, then create it.
	if race_id not in _races:
		_races[race_id] = {}
	# No kart selected, so just a handle for now.
	_races[race_id][id] = [handle,""]
	_refresh_race (race_id)
# Called when the race stats should be updated.
# Called from server to itself.
func _refresh_race (race_id) -> void:
	# Update count for the race.
	var race_list: VBoxContainer = $Multiplayer/MarginContainer/CenterContainer/VBoxContainer/ScrollContainer/VBoxContainer
	# Update info on the race.
	if race_id in _races:
		race_list.get_node(str(race_id)).get_node("VBoxContainer/NumPlayers").text = "%d player(s) joined so far"%len(_races[race_id])
	# Or clear it out if it no longer exists.
	else:
		race_list.get_node(str(race_id)).queue_free()
# Briefly displays an error message at the top of the screen.
func _error_message (msg: String) -> void:
	var e: Label = $MarginContainer/CenterContainer/VBoxContainer/ErrorMessage
	e.modulate = Color.WHITE
	e.text = msg
	var tween: Tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(e,"modulate",Color.hex(0xffffff00),3.0)

# Disconnect from any multiplayer instance.
func _leave_server () -> void:
	if multiplayer.get_unique_id() != 1:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
