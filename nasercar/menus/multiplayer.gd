extends Control

# Signal to send when a session is ready to be joined.
signal join_race (race_id: int)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$RaceEntrySpawner.spawn_function = _spawn_race_entry

func _on_back_button_pressed() -> void:
	MenuHandler.deactivate_menu()

# Player wants to start their own multiplayer session.
func _on_new_button_pressed() -> void:
	_create_new_race.rpc_id(1)
	join_race.emit(multiplayer.get_unique_id())

@rpc("any_peer","reliable")
func _create_new_race () -> void:
	var id: int = multiplayer.get_remote_sender_id()
	$RaceEntrySpawner.spawn(id)
	$MarginContainer/CenterContainer/VBoxContainer/ScrollContainer/VBoxContainer/NoRacesLabel.hide()

# Called when a new line is added to the list of available races.
# Where is race id going to be stored?
func _spawn_race_entry (id: int):
	var entry = load("res://menus/multiplayer_join_line.tscn").instantiate()
	entry.get_node("JoinButton").pressed.connect(func (): join_race.emit(id))
	entry.name = str(id)
	return entry
