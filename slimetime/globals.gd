extends Node

# Global parameters

# Current version of the game.
var version: String = "0.1.1"

# Flag for testing multiplayer on localhost.
var localhost: bool = false

# Query server information.
# To use: connect the server_info signal, and then call request_server_info().
signal server_info (info: Dictionary)
func request_server_info () -> void:
	_request_server_info.rpc_id(1)
@rpc("any_peer","reliable")
func _request_server_info () -> void:
	if multiplayer.get_unique_id() != 1: return
	var id: int = multiplayer.get_remote_sender_id()
	receive_server_info.rpc_id(id,{'version':version})
@rpc("authority","reliable")
func receive_server_info (info: Dictionary) -> void:
	server_info.emit(info)

# Visibility range for sprites.
# Used for turning off processing / multiplayer synchronizing when far enough away.
# Make it the same size as the window.
# It could probably be about two thirds of this size for the way the camera will
# always centre the view, but this way it's easier to search/replace if the
# game resolution is ever changed.
var visibility_range: Vector2 = Vector2(1920,1080)

# Strength of gravity
var gravity: float = 500

# How fast slime shoots out.
var slime_speed: float = 1000.0

# Master volume control.
var volume: float = 100
# This could be connected to a control, via a signal.
func set_volume (level: float) -> void:
	volume = level
	AudioServer.set_bus_volume_db(0, (volume-100)/5)

# Graphics level (not used)
var graphics_level: int = 0

# Worm colour scheme
signal worm_colour_updated
func set_worm_body_colour(c: Color):
	worm_body_colour = c
	worm_colour_updated.emit()
	_eventually_save_state()
func set_worm_back_colour(c: Color):
	worm_back_colour = c
	worm_colour_updated.emit()
	_eventually_save_state()
func set_worm_front_colour(c: Color):
	worm_front_colour = c
	worm_colour_updated.emit()
	_eventually_save_state()
func set_worm_outline_colour(c: Color):
	worm_outline_colour = c
	worm_colour_updated.emit()
	_eventually_save_state()
func set_worm_icon_bg_colour(c: Color):
	worm_icon_bg_colour = c
	worm_colour_updated.emit()
	_eventually_save_state()
var worm_body_colour: Color = Color.hex(0xff8e5bff): set = set_worm_body_colour
var worm_back_colour: Color = Color.hex(0xf15c61ff): set = set_worm_back_colour
var worm_front_colour: Color = Color.hex(0xfef0ccff): set = set_worm_front_colour
var worm_outline_colour: Color = Color.BLACK: set = set_worm_outline_colour
var worm_icon_bg_colour: Color = Color.WHITE: set = set_worm_icon_bg_colour
# Remember original colour values, in case they need to be reset.
var original_worm_body_colour: Color = worm_body_colour
var original_worm_back_colour: Color = worm_back_colour
var original_worm_front_colour: Color = worm_front_colour
var original_worm_outline_colour: Color = worm_outline_colour
var original_worm_icon_bg_colour: Color = worm_icon_bg_colour

# Enable debug keys
var debug_keys: bool = false

# Use touchscreen interface?
var touchscreen_controls: bool = DisplayServer.is_touchscreen_available()

# Remember if on-screen instructions were shown.
var showed_instructions: bool = false

var chat_font: FontFile = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Find the best font to use.
	if ResourceLoader.exists(("res://fonts/ProximaSoft/ProximaSoft-SemiBold.woff2")):
		chat_font = load("res://fonts/ProximaSoft/ProximaSoft-SemiBold.woff2")
	elif ResourceLoader.exists(("res://fonts/ProximaSoft/ProximaSoft-SemiBold.otf")):
		chat_font = load("res://fonts/ProximaSoft/ProximaSoft-SemiBold.otf")
	else:
		chat_font = load("res://fonts/nautica-rounded/nautica-rounded.semibold.ttf")
	_manage_persistent_state()

# Manage persistent game state.
var _save_state_timer: Timer
func _eventually_save_state() -> void:
	if _save_state_timer == null: return
	if not _save_state_timer.is_stopped():
		_save_state_timer.stop()
	_save_state_timer.start()
func _save_state() -> void:
	var state: Dictionary
	state['worm_body_colour'] = worm_body_colour.to_html()
	state['worm_back_colour'] = worm_back_colour.to_html()
	state['worm_front_colour'] = worm_front_colour.to_html()
	state['worm_outline_colour'] = worm_outline_colour.to_html()
	state['worm_icon_bg_colour'] = worm_icon_bg_colour.to_html()
	state['handle'] = handle
	var f: FileAccess = FileAccess.open("user://config.json",FileAccess.WRITE)
	f.store_line(JSON.stringify(state,"\t"))
func _manage_persistent_state() -> void:
	var f: FileAccess = FileAccess.open("user://config.json",FileAccess.READ)
	if f != null:
		var state: Dictionary = JSON.parse_string(f.get_as_text())
		worm_body_colour = Color.from_string(state['worm_body_colour'], original_worm_body_colour)
		worm_back_colour = Color.from_string(state['worm_back_colour'], original_worm_back_colour)
		worm_front_colour = Color.from_string(state['worm_front_colour'], original_worm_front_colour)
		worm_outline_colour = Color.from_string(state['worm_outline_colour'], worm_outline_colour)
		worm_icon_bg_colour = Color.from_string(state['worm_icon_bg_colour'], original_worm_icon_bg_colour)
		handle = state['handle']
	# Set up delay for saving state.
	# So we don't repeatedly write the file as properties like colour are updated.
	_save_state_timer = Timer.new()
	_save_state_timer.wait_time = 5.0
	_save_state_timer.one_shot = true
	_save_state_timer.timeout.connect(_save_state)
	add_child(_save_state_timer)

# Delegate requests for adding slime splatter particles to the screen.
# There are multiple contexts in which the splatter could be generated, and it
# ultimately has to be managed by the Screen instance.  So this signal acts as
# an intermediary to get that splatter to happen.
@warning_ignore("unused_signal")  # This signal is actually used, just in other scenes.
signal request_splatter (pos: Vector2, direction: Vector2)

# Multiplayer information.
var is_client: bool = false
var is_server: bool = false
var handle: String = "": set = _set_handle
func _set_handle (h: String) -> void:
	handle = h
	_eventually_save_state()

# Reset global variables (when game restarts).
func reset () -> void:
	is_client = false
	is_server = false
