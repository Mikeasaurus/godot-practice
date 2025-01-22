extends Bug

class_name FlyingBug

# How the bug turns when changing direction.
# (either tilt in the direction, or flip entirely)
@export_enum("tilt","flip") var turn_style: String = "tilt"

# Initial velocity of bug
@export var starting_velocity: Vector2 = Vector2(200,0)
# Springiness factor
@export var springiness: Vector2 = Vector2(1,1)

func _ready() -> void:
	super()
	apply_central_impulse(starting_velocity)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	super(delta)
	if is_slimed: return
	# Move the beetle
	var dx: Vector2 = global_position - starting_position
	var f: Vector2 = -springiness * dx
	apply_central_force(f)
	# Seems to be some dampening, so keep pushing it.
	if abs(dx.x) < 5:
		if linear_velocity.x > 0:
			apply_central_impulse(Vector2(starting_velocity.x-linear_velocity.x,0))
		else:
			apply_central_impulse(Vector2(-starting_velocity.x-linear_velocity.x,0))
	if abs(dx.y) < 5:
		if linear_velocity.y > 0:
			apply_central_impulse(Vector2(0,starting_velocity.y-linear_velocity.y))
		else:
			apply_central_impulse(Vector2(0,-starting_velocity.y-linear_velocity.y))
	# Angle it in direction of motion.
	if turn_style == "tilt":
		var angle: float
		if linear_velocity.x > 0:
			angle = -60.0
		else:
			angle = 60.0
		# Smooth transition of angle near extremes of path.
		if abs(linear_velocity.x) <= 20:
			angle *= abs(linear_velocity.x)/20
		$AnimatedSprite2D.global_rotation_degrees = angle
	# Or check if flipping should be done.
	elif turn_style == "flip":
		if linear_velocity.x < 0:
			$AnimatedSprite2D.flip_h = true
		else:
			$AnimatedSprite2D.flip_h = false

# Predict where the bug will be at the given time offset.
# Helps with slime targeting.
func predict_location (t: float) -> Vector2:
	var x0: Vector2 = global_position
	var v0: Vector2 = linear_velocity
	var xc: Vector2 = starting_position
	var a: Vector2 = Vector2(sqrt(springiness.x),sqrt(springiness.y))
	var location_x: float = 1/a.x * sin(a.x*t) * v0.x + cos(a.x*t) * (x0.x-xc.x) + xc.x
	var location_y: float = 1/a.y * sin(a.y*t) * v0.y + cos(a.y*t) * (x0.y-xc.y) + xc.y
	return Vector2(location_x,location_y)
