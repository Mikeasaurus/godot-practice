extends RigidBody2D

# Initial velocity of bug
var starting_velocity: float = 200
# Springiness factor
var springiness: float = 1

# Original position of bug.
var starting_position: Vector2

# Whether bug is flying or inactive.
var is_flying: bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimatedSprite2D.play()
	starting_position = global_position
	apply_central_impulse(Vector2(starting_velocity,0))
	is_flying = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not is_flying:
		apply_central_force(Vector2(0,Globals.gravity))
		return
	# For debugging - force bug to be in "slimed" state.
	if Input.is_action_pressed("slime_all"):
		get_slimed()
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

# Change state of the bug so it's in a dormant, slimed state.
func get_slimed () -> void:
	is_flying = false
	$AnimatedSprite2D.play("slimed")

func _on_body_entered(body: Node) -> void:
	if "get_collision_layer" in body:
		if body.get_collision_layer() == 2 and is_flying:
			get_slimed()
