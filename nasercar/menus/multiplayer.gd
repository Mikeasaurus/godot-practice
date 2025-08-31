extends Control

@onready var _handle: LineEdit = $MarginContainer/CenterContainer/VBoxContainer/HBoxContainer2/Handle

signal leave_server

# Signal to send when a session is ready to be joined.
signal join_race (race_id: int, handle: String)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$RaceEntrySpawner.spawn_function = _spawn_race_entry

func _on_back_button_pressed() -> void:
	leave_server.emit()
	MenuHandler.deactivate_menu()

# Player wants to start their own multiplayer session.
func _on_new_button_pressed() -> void:
	_create_new_race.rpc_id(1,_handle.text)
	MenuHandler.deactivate_menu()
	join_race.emit(multiplayer.get_unique_id(),_handle.text)
@rpc("any_peer","reliable")
func _create_new_race (handle: String) -> void:
	var id: int = multiplayer.get_remote_sender_id()
	var entry = $RaceEntrySpawner.spawn(id)
	entry.get_node("VBoxContainer/Host").text = "%s is starting a new race"%handle
	$MarginContainer/CenterContainer/VBoxContainer/ScrollContainer/VBoxContainer/NoRacesLabel.hide()

# Called when a new line is added to the list of available races.
# Where is race id going to be stored?
func _spawn_race_entry (id: int):
	var entry = load("res://menus/multiplayer_join_line.tscn").instantiate()
	entry.get_node("JoinButton").pressed.connect(func ():
		MenuHandler.deactivate_menu()
		join_race.emit(id,_handle.text)
	)
	entry.name = str(id)
	return entry

# Print the information message when list of current races becomes empty.
func _on_v_box_container_child_exiting_tree(_node: Node) -> void:
	var vbox: VBoxContainer = $MarginContainer/CenterContainer/VBoxContainer/ScrollContainer/VBoxContainer
	if len(vbox.get_children()) == 2:  # 2 = the (hidden) label, and the last race in the list being removed.
		vbox.get_node("NoRacesLabel").show()
	pass # Replace with function body.
