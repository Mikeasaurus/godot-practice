extends Path2D

## Speed at which the platform moves (pixels/second)
@export var velocity: float = 300.0

enum Direction { FORWARD, BACKWARD }
var _direction: Direction = Direction.FORWARD
var _length: float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_length = curve.get_baked_length()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Check if direction needs to be changed
	if _direction == Direction.FORWARD and $PathFollow2D.progress >= _length:
		_direction = Direction.BACKWARD
	elif _direction == Direction.BACKWARD and $PathFollow2D.progress <= 0:
		_direction = Direction.FORWARD
	# Determine velocity to use (usually full speed, but slow down near the ends of the path).
	var dx: float
	if $PathFollow2D.progress <= 100:
		dx = ($PathFollow2D.progress + 10)/110 * velocity * delta
	elif $PathFollow2D.progress >= _length-100:
		dx = (_length - $PathFollow2D.progress + 10) / 110 * velocity * delta
	else:
		dx = velocity * delta
	# Move the platform.
	if _direction == Direction.FORWARD:
		$PathFollow2D.progress += dx
	elif _direction == Direction.BACKWARD:
		$PathFollow2D.progress -= dx
