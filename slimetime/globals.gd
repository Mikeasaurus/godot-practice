extends Node

# Global parameters

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

# Current score
var score: int = 0

# Enable debug keys
var debug_keys: bool = true

# Use touchscreen interface?
var touchscreen_controls: bool = DisplayServer.is_touchscreen_available()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

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

# Reset global variables (when game restarts).
func reset () -> void:
	score = 0
	is_client = false
	is_server = false
