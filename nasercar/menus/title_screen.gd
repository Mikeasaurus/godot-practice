extends Control

@onready var _naomi := $CarSelection/MarginContainer/CenterContainer/VBoxContainer/GridContainer/Naomi

# List of all race instances running / being created.
# (for server side).
var _races: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var notracks: Array[TileMapLayer] = []
	$NaserCar.add_to_track($Path2D,notracks)
	$NaserCar.make_cpu()
	_reset_car()
	$CarTimer.start()
	MenuHandler.done_submenus.connect(_reset_and_start_timer)
	$CarSelection.race.connect(start_race)
	# Need to unlock Naomi kart.
	_naomi.hide()
	if DisplayServer.get_name() == "headless":
		_make_server()

# Multiplayer server setup.
func _make_server () -> void:
	# Set up server, listening for incoming peers.
	multiplayer.multiplayer_peer = null
	#multiplayer.peer_disconnected.connect(_on_client_disconnected)
	var peer := WebSocketMultiplayerPeer.new()
	if "--local" in OS.get_cmdline_user_args():
		peer.create_server(1157)
	else:
		var key := load("res://cert/privkey.key")
		var cert := load("res://cert/fullchain.crt")
		var tls_options := TLSOptions.server(key,cert)
		peer.create_server(1157,"*",tls_options)
	multiplayer.multiplayer_peer = peer
	# Propogate multiplayer race info to car selection menu.
	$CarSelection._races = _races

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

func start_race (player_car: Car) -> void:
	# Load up the race track.
	var race: World = load("res://world.tscn").instantiate()
	# Set up the player car based on the car type chosen.
	# Can't just set player_car as the one we're given - it has to be one of the instantiated
	# scenes in the race.
	for car in race.get_node("Cars").get_children() as Array[Car]:
		if car.display_name == player_car.display_name:
			race.player_car = car
	add_child(race)
	# Turn off Naser car visual.
	# Do this after a bit of a delay, because there's a call to _reset_and_start_timer around the same
	# time as this (from MenuHandler) that would cause the Naser car to start on its own.
	#
	$NaserCar.call_deferred("hide")
	await get_tree().create_timer(0.1).timeout
	$NaserCar.call_deferred("hide")
	_reset_car()
	#
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

# This is called once the player selects a multiplayer race to join.
# This is called from peer instance.  Need to coordinate with the server.
func _on_multiplayer_join_race(race_id: int, handle: String) -> void:
	_peer_joining_race.rpc_id(1, race_id, handle)
	# Open car selection menu with multiplayer context.
	_reset_car()
	MenuHandler.activate_menu($CarSelection)
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
	# Update count for the race.
	var race_list: VBoxContainer = $Multiplayer/MarginContainer/CenterContainer/VBoxContainer/ScrollContainer/VBoxContainer
	race_list.get_node(str(race_id)).get_node("VBoxContainer/NumPlayers").text = "%d player(s) joined so far"%len(_races[race_id])
