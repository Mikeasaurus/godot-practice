extends Node2D

# Adapted from https://github.com/godotengine/godot-demo-projects/blob/4.2-31d1c0c/networking/websocket_multiplayer/script/combo.gd
func _enter_tree() -> void:
	get_tree().set_multiplayer(MultiplayerAPI.create_default_interface(), str(get_path()) + "/ClientScreen")
func _exit_tree() -> void:
	get_tree().set_multiplayer(null, str(get_path()) + "/ClientScreen")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set up multiplayer stuff.
	$ClientScreen._make_client(Globals.invite)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
