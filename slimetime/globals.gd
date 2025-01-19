extends Node

# Global parameters

# Strength of gravity
var gravity: float = 500

# How fast slime shoots out.
var slime_speed: float = 1000.0

# Current score
var score: int = 0

# Enable debug keys
var debug_keys: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


# Reset global variables (when game restarts).
func reset () -> void:
	score = 0
