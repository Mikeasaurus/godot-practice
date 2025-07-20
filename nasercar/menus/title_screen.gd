extends Control

@onready var _naomi := $CarSelection/MarginContainer/CenterContainer/VBoxContainer/GridContainer/Naomi

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

# Multiplayer client setup.
#TODO
# This is called when a server connection is no longer needed.
func _disconnect_from_server() -> void:
	pass
func _join_multiplayer_race (race) -> void:
	pass

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
