extends Node

# Global parameters

# Current version of the game.
var version: String = "0.1.0"

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
func set_worm_back_colour(c: Color):
	worm_back_colour = c
	worm_colour_updated.emit()
func set_worm_front_colour(c: Color):
	worm_front_colour = c
	worm_colour_updated.emit()
func set_worm_outline_colour(c: Color):
	worm_outline_colour = c
	worm_colour_updated.emit()
func set_worm_icon_bg_colour(c: Color):
	worm_icon_bg_colour = c
	worm_colour_updated.emit()
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

var chat_font: FontFile = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Find the best font to use.
	if ResourceLoader.exists(("res://fonts/ProximaSoft/ProximaSoft-SemiBold.woff2")):
		chat_font = load("res://fonts/ProximaSoft/ProximaSoft-SemiBold.woff2")
	else:
		chat_font = load("res://fonts/nautica-rounded/nautica-rounded.semibold.ttf")

# Delegate requests for adding slime splatter particles to the screen.
# There are multiple contexts in which the splatter could be generated, and it
# ultimately has to be managed by the Screen instance.  So this signal acts as
# an intermediary to get that splatter to happen.
@warning_ignore("unused_signal")  # This signal is actually used, just in other scenes.
signal request_splatter (pos: Vector2, direction: Vector2)

# Multiplayer information.
var is_client: bool = false
var is_server: bool = false
var invite: String = ""
var handle: String = ""
func check_invite (code: String) -> String:
	if len(code) != 8: return ''
	var table: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	code = code.to_upper()
	var n: int = 0
	for i in range(len(code)):
		n = n * 36 + table.find(code[i])
	n = (n*1000000) % (36**8-19)
	if (n >= 2**32): return ''
	if n < 0: return ''
	var s: String = str(n%256)
	for i in range(3):
		n >>= 8
		s = str(n%256) + '.' + s
	return s
func make_invite (s: String) -> String:
	var table: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var n: int = 0
	for x in s.split('.'):
		n <<= 8
		n += int(x)
	n = (n*17345149)%(36**8-19)
	n = (n*541)%(36**8-19)
	n = (n*241)%(36**8-19)
	var a: Array[String] = []
	for i in range(8):
		@warning_ignore("integer_division")
		a.append(table[n/(36**(7-i))])
		n %= (36**(7-i))
	return str(''.join(a))

# Reset global variables (when game restarts).
func reset () -> void:
	is_client = false
	is_server = false
