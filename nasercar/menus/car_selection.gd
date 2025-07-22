extends Control

var selection: CarSelectionPanel = null

# This is copied from the title screen.
var _races: Dictionary = {}

# Signal that gets sent when the player is ready to start the race.
signal race (car: Car)

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

func _on_back_button_pressed() -> void:
	MenuHandler.deactivate_menu()

func _on_race_button_pressed() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self,"modulate",Color.BLACK,1.0)
	await tween.finished
	modulate = Color.WHITE
	hide()
	race.emit(selection.car)
	MenuHandler.deactivate_menu()

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

# This is called by a new peer to request updated status of the selection panels.
@rpc("any_peer","reliable")
func _sync_panels () -> void:
	var id: int = multiplayer.get_remote_sender_id()
	# Figure out which race this player is interested in.
	for race_id in _races.keys():
		if id in _races[race_id]:
			var r: Dictionary = _races[race_id]
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
	if is_taken and player_id != my_id:
		panel.disable()
	elif is_taken and player_id == my_id:
		panel.enable()
		if selection != null and selection != panel:
			selection.unselect()
		selection = panel
		selection.select()
	else:
		panel.unselect()
		panel.enable()

# If joining into a multiplayer game, update the status of all karts.
func _on_visibility_changed() -> void:
	if visible:
		if multiplayer.get_unique_id() != 1:
			_sync_panels.rpc_id(1)

#TODO: timer for multiplayer kart selection (if not the host)
