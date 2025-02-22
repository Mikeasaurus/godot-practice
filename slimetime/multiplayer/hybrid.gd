extends Node2D

# Adapted from https://github.com/godotengine/godot-demo-projects/blob/4.2-31d1c0c/networking/websocket_multiplayer/script/combo.gd
func _enter_tree() -> void:
	get_tree().set_multiplayer(MultiplayerAPI.create_default_interface(), str(get_path()) + "/ServerScreen")
	get_tree().set_multiplayer(MultiplayerAPI.create_default_interface(), str(get_path()) + "/ClientScreen")
func _exit_tree() -> void:
	get_tree().set_multiplayer(null, str(get_path()) + "/ServerScreen")
	get_tree().set_multiplayer(null, str(get_path()) + "/ClientScreen")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Disable worm on server side (not needed, and don't want to process keyboard controls in here).
	$ServerScreen/Worm._alive = false
	# Also disable the worm's camera
	$ServerScreen/Worm/WormFront/Sprites/Camera2D.enabled = false
	# Set up multiplayer stuff.
	$ServerScreen._make_server()
	$ClientScreen._make_client(Globals.invite)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if $ClientScreen.multiplayer.multiplayer_peer.get_connection_status() == 2:
		$ClientScreen.say_hello.rpc_id(1)
	pass
