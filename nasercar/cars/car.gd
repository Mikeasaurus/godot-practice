extends RigidBody2D

## Top speed of car (pixels/second)
@export var max_speed: float = 1500.0

## Acceleration (pixels/second/second)
@export var acceleration: float = 500.0

## Drag (as deceleration)
@export var deceleration: float = acceleration/3

## Brake power (pixels/second/second)
@export var brakes: float = acceleration

## How far the wheels can turn in one direction (degrees)
@export var max_wheel_angle: float = 30.0

## How fast the wheels can turn (degrees/sec)
@export var wheel_turn_speed: float = 120.0

## Whether this car is user controllable.
@export var controllable: bool = false

## The path to follow if this is a CPU.
@export var path: Path2D = null
var _pathfollow: PathFollow2D = null
var _rect: ColorRect = null

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Let this car be playable by the local user.
func make_playable () -> void:
	controllable = true
	$Camera2D.enabled = true

# Make this car follow a predetermined path
# (as local CPU).
func make_cpu (track_path: Path2D) -> void:
	# Make a copy of the track path, so we can add our own PathFollow2D.
	#path = track_path.duplicate()
	path = track_path
	_pathfollow = PathFollow2D.new()
	path.add_child(_pathfollow)
	_rect = ColorRect.new()
	_pathfollow.add_child(_rect)
	_rect.size = Vector2(40,40)
	_rect.position = Vector2(-20,-20)
	_rect.color = Color.RED
	#add_sibling(path)
	#path.global_position = global_position - path.curve.get_point_position(0)
	var offset: Vector2 = global_position - path.curve.get_point_position(0)
	#TODO: more robost with starting orientation.
	_pathfollow.v_offset = offset.x

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Zoom out camera the faster the car is going.
	var z: float = 2.0 / (1 + 2*abs($Wheels/FrontLeft.speed) / max_speed)
	$Camera2D.zoom.x = z
	$Camera2D.zoom.y = z

	var dr: float = wheel_turn_speed * delta / 180 * PI
	var max_r: float = max_wheel_angle / 180 * PI

	if controllable:
		#######################################################
		# Wheel turning
		#######################################################
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

	#######################################################
	# Path following for CPUs
	#######################################################
	if _pathfollow != null:
		# Make sure our target point is far enough ahead.
		#var target_direction: Vector2 = _pathfollow.global_position - global_position
		var target_direction: Vector2 = _rect.global_position - global_position
		var dx: float = target_direction.length()
		if dx < 100:
			_pathfollow.progress += 100 - dx
		# Go go go
		for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight, $Wheels/RearLeft, $Wheels/RearRight]:
			if wheel.speed < max_speed/10:
				wheel.speed += acceleration * delta
		# ... in right direction
		var angle: float = target_direction.angle() - global_rotation
		var angle_degrees: float = angle / PI * 180
		for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight]:
			#TODO
			#var target_angle: float = target_direction.angle() - PI/2 #- global_rotation
			wheel.global_rotation = target_direction.angle() - PI/2
			#if target_angle < wheel.global_rotation:
				#if wheel.rotation > -max_r:
					#print ("OK")
					#wheel.rotation -= dr
				#else:
					#print ("NOT OK")
			#elif target_angle > wheel.global_rotation:
				#if wheel.rotation < max_r:
					#wheel.rotation += dr
			#wheel.rotation = target_angle

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
