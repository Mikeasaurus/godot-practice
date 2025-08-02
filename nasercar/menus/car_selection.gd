extends Control

var selection: CarSelectionPanel = null

# This is copied from the title screen, on server instance.
var _races: Dictionary = {}

# Signal that gets sent when the player is ready to start a single player race.
signal singleplayer_race (car: Car)

# Signal for when the player is ready to start a multiplayer race.
signal multiplayer_race (race_id: int, participants: Dictionary)

# Signal that gets sent when the race stats should be re-read by the parent scene.
signal refresh_race (race_id: int)

# Signal for displaying an error message on the main screen.
signal error_message (msg: String)

# Helper methods: convert between panel index and car name.
var car_names: Array[String]
func index2name (panel_index: int) -> String:
	if panel_index < 0: return ""
	return car_names[panel_index]
func name2index (name: String) -> int:
	if name == "": return -1
	return car_names.find(name)
func panel2index (panel: CarSelectionPanel) -> int:
	return car_names.find(panel.car.display_name)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for panel in $MarginContainer/CenterContainer/VBoxContainer/GridContainer.get_children() as Array[CarSelectionPanel]:
		panel.selected.connect(func(): _panel_selected(panel))
		car_names.append(panel.car.display_name)
	# Server side setup.
	if multiplayer.get_unique_id() == 1:
		multiplayer.peer_disconnected.connect(_player_bailed)

func _panel_selected (panel: CarSelectionPanel) -> void:
	# If this is a multiplayer game, then need to delegate car selection through the server.
	if multiplayer.get_unique_id() != 1:
		var panel_index: int = panel2index(panel)
		_try_selecting_car.rpc_id(1,panel_index)
		return
	if selection != null and selection != panel:
		selection.unselect()
	selection = panel
	panel.select()
	if $MarginContainer/CenterContainer/VBoxContainer/HBoxContainer/RaceButton.disabled:
		$MarginContainer/CenterContainer/VBoxContainer/HBoxContainer/RaceButton.disabled = false

# Called when the user backs out of car selection.
func _on_back_button_pressed() -> void:
	# For multiplayer games, need to let the server know that we're backing out.
	if multiplayer.get_unique_id() != 1:
		_bail.rpc_id(1)
	MenuHandler.deactivate_menu()

# Helper function - face out the screen.
# Can also be triggered from a server process for multiplayer games.
var _fadeout_time: float = 1.0
@rpc("authority","reliable")
func _fadeout() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self,"modulate",Color.BLACK,_fadeout_time)
	await tween.finished

# Called when the user clicks the "Race" button.
func _on_race_button_pressed() -> void:
	# Disable any further button presses.
	$MarginContainer/CenterContainer/VBoxContainer/HBoxContainer/BackButton.disabled = true
	$MarginContainer/CenterContainer/VBoxContainer/HBoxContainer/RaceButton.disabled = true
	# If this is a single player game, send signal back to parent scene that we're ready.
	if multiplayer.get_unique_id() == 1:
		await _fadeout()
		singleplayer_race.emit(selection.car)
		MenuHandler.deactivate_menu()
	# If this is a multiplayer game, delegate to the server for sending the signal to
	# its parent scene.
	else:
		_try_starting_race.rpc_id(1)
# Called from client to server, to request the race to start.
@rpc("any_peer","reliable")
func _try_starting_race() -> void:
	var player_id: int = multiplayer.get_remote_sender_id()
	# This is probably not necessary, but make sure this player is a host for a race.
	if player_id not in _races: return
	var race_id: int = player_id
	# Send some signals to all participating players.
	var participants: Dictionary = _races[race_id]
	for p in participants.keys():
		var value: Array = participants[p]
		# value is [handle,car_name]
		var car_name: String = value[1]
		# If there are any peers left who have not selected a kart, then politely cancel them out.
		if car_name == "":
			_cancel.rpc_id(p,"Sorry, the race has already started.")
		# Otherwise, fade out their screen as a heads-up that the race is beginning.
		_fadeout.rpc_id(p)
	# Remove the entry from the list of races (can't join anymore).
	_races.erase(race_id)
	refresh_race.emit(race_id)
	await get_tree().create_timer(_fadeout_time).timeout
	multiplayer_race.emit(race_id, participants)

# Handle remote updates of kart selections
# This is called on the server when the user clicks on a kart in multiplayer context.
# Based on information I found online, RPC calls are handled in sequence, so no race
# condition can be triggered when multiple peers select the same car at the same time.
# https://forum.godotengine.org/t/rpc-thread-safety-across-peers/112505
@rpc("any_peer","reliable")
func _try_selecting_car (panel_index: int) -> void:
	var car_name: String = index2name(panel_index)
	var player_id: int = multiplayer.get_remote_sender_id()
	var handle: String
	# Find the race that this player is joining.
	for race_id in _races.keys():
		if player_id in _races[race_id]:
			var r: Dictionary = _races[race_id]
			# Check if the car is already in use.
			for value in r.values():
				# Each player stores a [handle,car] entry for the race.
				if value[1] == car_name:
					return  # Car already taken
			# Car available, so register this car for the player, and update menu
			# visuals for all peers.
			handle = r[player_id][0]
			var old_car_name: String = r[player_id][1]
			r[player_id][1] = car_name
			for p in r.keys():
				# Tell other peers that this car is now taken.
				_update_panel.rpc_id(p,panel_index,true,player_id,handle)
				# Also, free up previously taken car.
				if old_car_name != "":
					_update_panel.rpc_id(p,name2index(old_car_name),false,-1,"")
			# If this player is also the host, then they can join the race whenever they're ready.
			if player_id == race_id:
				_enable_race_button.rpc_id(player_id)

# This is called by a new peer to request updated status of the selection panels.
@rpc("any_peer","reliable")
func _sync_panels () -> void:
	var id: int = multiplayer.get_remote_sender_id()
	# Figure out which race this player is interested in.
	for race_id in _races.keys():
		if id in _races[race_id]:
			var r: Dictionary = _races[race_id]
			# Start by clearing the status of all cars.
			for car_name in car_names:
				_update_panel.rpc_id(id, name2index(car_name), false, -1, "")
			# For all cars that are already taken, update the panel visual.
			for player_id in r.keys():
				var value = r[player_id]
				var handle: String = value[0]
				var car_name: String = value[1]
				if car_name == "": continue
				_update_panel.rpc_id(id, name2index(car_name), true, player_id, handle)

# This is called on the client to update visuals (for when cars are already taken).
@rpc("authority","reliable")
func _update_panel (panel_index: int, is_taken: bool, player_id: int, handle: String) -> void:
	var my_id: int = multiplayer.get_unique_id()
	var panel: CarSelectionPanel = $MarginContainer/CenterContainer/VBoxContainer/GridContainer.get_children()[panel_index]
	# Car is taken by somebody else
	if is_taken and player_id != my_id:
		panel.disable()
		panel.overlay(handle)
	# Car is taken by this player
	elif is_taken and player_id == my_id:
		panel.enable()
		if selection != null and selection != panel:
			selection.unselect()
		selection = panel
		selection.select()
		panel.overlay(handle)
	else:
		panel.unselect()
		panel.enable()
		panel.no_overlay()
# This is called from the server to the client, when they're allowed to click the "Race" button.
@rpc("authority","reliable")
func _enable_race_button () -> void:
	$MarginContainer/CenterContainer/VBoxContainer/HBoxContainer/RaceButton.disabled = false

# If joining into a multiplayer game, update the status of all karts.
func _on_visibility_changed() -> void:
	if visible:
		# If this was faded out, then bring it back.
		modulate = Color.WHITE
		# Clear any previously selected car (it's not actually selected anymore).
		if selection != null:
			selection.unselect()
			selection = null
		# Enable "Back" button (may have been disabled in previous interaction with this scene).
		$MarginContainer/CenterContainer/VBoxContainer/HBoxContainer/BackButton.disabled = false
		if multiplayer.get_unique_id() != 1:
			# Ask server about which cars are already taken and which ones are available.
			_sync_panels.rpc_id(1)
			# No joining race until a car is selected.
			$MarginContainer/CenterContainer/VBoxContainer/HBoxContainer/RaceButton.disabled = true

# Handle cancellations (if a host or other player bails).
# Calls from peer to server side.
@rpc("any_peer","reliable")
func _bail () -> void:
	var player_id: int = multiplayer.get_remote_sender_id()
	_player_bailed(player_id)
# This is also from server side.
func _player_bailed (player_id: int) -> void:
	# If this player was hosting a race, then bail on the whole race.
	if player_id in _races:
		_race_bailed(player_id)
		return
	# Otherwise, just clear out the player and free any selected kart.
	for race_id in _races.keys():
		var r: Dictionary = _races[race_id]
		if player_id in r:
			var car_name: String = r[player_id][1]
			if car_name != "":
				for p in r.keys():
					_update_panel.rpc_id(p,name2index(car_name),false,-1,"")
			r.erase(player_id)
			refresh_race.emit(race_id)
# This is also from server side.
func _race_bailed (race_id: int) -> void:
	# Kick out all players.
	for player_id in _races[race_id].keys():
		# Assuming the host would have already left this screen by the time this even happens,
		# so don't need to "cancel" their screen.
		if player_id != race_id:
			_cancel.rpc_id(player_id,"The race was cancelled by the host.")
	# Clear out the race.
	_races.erase(race_id)
	refresh_race.emit(race_id)
# This is called from server to client, to tell them that the race is cancelled.
@rpc("authority","reliable")
func _cancel (msg: String) -> void:
	error_message.emit(msg)
	MenuHandler.deactivate_menu()

#TODO: timer for multiplayer kart selection (if not the host)
