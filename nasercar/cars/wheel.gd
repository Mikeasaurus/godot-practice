extends Node2D

## Current "speed" of wheel (pixels/sec).
@export var speed: float = 0

# The current skid mark associated with this wheel.
var _current_skidmark: SkidMark = null
