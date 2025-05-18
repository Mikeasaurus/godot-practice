extends RigidBody2D

## Top speed of car (pixels/second)
@export var max_speed: float = 1500.0

## Acceleration (pixels/second/second)
@export var acceleration: float = 1500.0

## Drag (as deceleration)
@export var deceleration: float = acceleration/3

## Brake power (pixels/second/second)
@export var brakes: float = acceleration

## How far the wheels can turn in one direction (degrees)
@export var max_wheel_angle: float = 30.0

## How fast the wheels can turn (degrees/sec)
@export var wheel_turn_speed: float = 120.0

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#######################################################
	# Wheel turning
	#######################################################
	var dr: float = wheel_turn_speed * delta / 180 * PI
	var max_r: float = max_wheel_angle / 180 * PI
	# Turn left
	if Input.is_action_pressed("turn_left"):
		for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight]:
			if wheel.rotation > -max_r:
				wheel.rotation -= dr
	# Turn right
	elif Input.is_action_pressed("turn_right"):
		for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight]:
			if wheel.rotation < max_r:
				wheel.rotation += dr
	# Re-center
	else:
		for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight]:
			if wheel.rotation < 0:
				wheel.rotation += 2*dr
			elif wheel.rotation > 0:
				wheel.rotation -= 2*dr
			if abs(wheel.rotation) <= 2*dr:
				wheel.rotation = 0

	#######################################################
	# Acceleration from wheels
	#######################################################
	if Input.is_action_pressed("go"):
		var dv: float = acceleration * delta
		for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight, $Wheels/RearLeft, $Wheels/RearRight]:
			if wheel.speed < max_speed:
				wheel.speed += dv
	elif Input.is_action_pressed("stop"):
		var dv: float = brakes * delta
		for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight, $Wheels/RearLeft, $Wheels/RearRight]:
			if wheel.speed > 0:
				wheel.speed -= dv
			elif wheel.speed < 0:
				wheel.speed += dv
			if abs(wheel.speed) <= dv:
				wheel.speed = 0
	elif Input.is_action_pressed("reverse"):
		var dv: float = acceleration * delta
		for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight, $Wheels/RearLeft, $Wheels/RearRight]:
			if wheel.speed > -max_speed:
				wheel.speed -= dv
	# Update free-moving wheels to current ground speed in their direction.
	elif false:
		for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight, $Wheels/RearLeft, $Wheels/RearRight]:
			var rot: float = wheel.global_rotation + PI/2
			wheel.speed = linear_velocity.dot(Vector2.from_angle(rot))
	else:
		var dv: float = deceleration * delta
		for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight, $Wheels/RearLeft, $Wheels/RearRight]:
			if wheel.speed > 0:
				wheel.speed -= dv
			elif wheel.speed < 0:
				wheel.speed += dv
			if abs(wheel.speed) <= dv:
				wheel.speed = 0
func _physics_process(delta: float) -> void:
	#######################################################
	# Calculate movement (based on wheel speed and ground friction)
	#######################################################
	for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight, $Wheels/RearLeft, $Wheels/RearRight]:
		# Difference in velocity between wheel and ground.
		var rot: float = wheel.global_rotation + PI/2
		#var rot: float = wheel.rotation + PI/2
		#TODO
		var actual_v: Vector2 = linear_velocity + wheel.position.rotated(rotation+PI/2) * angular_velocity
		var target_v: Vector2 = wheel.speed * Vector2.from_angle(rot)
		#var dv: Vector2 = wheel.speed * Vector2.from_angle(rot) - linear_velocity
		var dv: Vector2 = target_v - actual_v
		apply_force(mass/4.0/delta*dv, wheel.position.rotated(rotation))
	#print (linear_velocity, ' ', $Wheels/RearLeft.
