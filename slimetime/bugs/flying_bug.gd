extends Bug

class_name FlyingBug

## How the bug turns when changing direction.
## (either tilt in the direction, or flip entirely)
@export_enum("tilt","flip") var turn_style: String = "tilt"

## Initial velocity of bug
@export var starting_velocity: Vector2 = Vector2(200,0)
## Springiness factor
@export var springiness: Vector2 = Vector2(1,1)

## Amount to tilt in degrees (if using tilting motion)
@export var tilt_angle: float = 60

func _ready() -> void:
	super()
	apply_central_impulse(starting_velocity)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	super(delta)
	if is_eaten: return
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
			angle = -tilt_angle
		else:
			angle = tilt_angle
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

func _on_respawn_timer_timeout() -> void:
	super()
	synced_linear_velocity = starting_velocity
