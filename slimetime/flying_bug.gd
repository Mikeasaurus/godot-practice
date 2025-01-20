extends Bug

class_name FlyingBug

# Initial velocity of bug
var starting_velocity: float = 200
# Springiness factor
var springiness: float = 1

func _ready() -> void:
	super()
	apply_central_impulse(Vector2(starting_velocity,0))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	super(delta)
	if is_slimed: return
	# Move the beetle
	var dx: float = global_position.x - starting_position.x
	var f: float = -springiness * dx
	apply_central_force(Vector2(f,0))
	# Seems to be some dampening, so keep pushing it.
	if abs(dx) < 5:
		if linear_velocity.x > 0:
			apply_central_impulse(Vector2(starting_velocity-linear_velocity.x,0))
		else:
			apply_central_impulse(Vector2(-starting_velocity-linear_velocity.x,0))
	# Angle it in direction of motion.
	var angle: float
	if linear_velocity.x > 0:
		angle = -60.0
	else:
		angle = 60.0
	# Smooth transition of angle near extremes of path.
	if abs(linear_velocity.x) <= 20:
		angle *= abs(linear_velocity.x)/20
	$AnimatedSprite2D.global_rotation_degrees = angle

# Predict where the bug will be at the given time offset.
# Helps with slime targeting.
func predict_location (t: float) -> Vector2:
	var x0: Vector2 = global_position
	var v0: Vector2 = linear_velocity
	var xc: Vector2 = starting_position
	var a: float = sqrt(springiness)
	return 1/a * sin(a*t) * v0 + cos(a*t) * (x0-xc) + xc
