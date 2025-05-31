extends RigidBody2D

## Top speed of car (pixels/second)
@export var max_speed: float = 1500.0

## Acceleration (pixels/second/second)
@export var acceleration: float = 500.0

## Drag (as deceleration)
@export var deceleration: float = acceleration/3

## Brake power (pixels/second/second)
@export var brakes: float = acceleration*2

## How far the wheels can turn in one direction (degrees)
@export var max_wheel_angle: float = 30.0

## How fast the wheels can turn (degrees/sec)
@export var wheel_turn_speed: float = 120.0

## Coefficient of friction for wheels.  Relative to acceleration force.
## Should be > 1.0 or car will always be skidding.
@export var friction: float = 2.0

## Whether this car is allowed to move.
var moveable: bool = false

enum CarType {PLAYER, CPU}
## Type of car
@export var type: CarType = CarType.CPU

## The path to follow if this is a CPU.
@export var path: Path2D = null
var _pathfollow: PathFollow2D = null

# For playing crashing sound.
var _crashing: bool = false

var _contact: bool = false
var _contact_normal: Vector2 = Vector2.ZERO

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Raise the z_index so effects like skid marks appear beneath it.
	z_index = 1

# Let this car be playable by the local user.
func make_playable () -> void:
	type = CarType.PLAYER
	$Camera2D.enabled = true
	$Arrow.show()
	# Make own engine sound louder.
	$EngineSound.volume_db = 1.0

# Make this car follow a predetermined path
# (as local CPU).
func make_cpu (track_path: Path2D) -> void:
	type = CarType.CPU
	path = track_path
	_pathfollow = PathFollow2D.new()
	path.add_child(_pathfollow)
	#_pathfollow.add_child(_rect)
	var offset: Vector2 = global_position - path.curve.get_point_position(0)
	#TODO: more robost with starting orientation.
	_pathfollow.v_offset = offset.x

# Allow this car to start moving.
func go () -> void:
	moveable = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:

	# Arrow pointing to player needs to stay oriented upward.
	$Arrow.global_rotation = 0
	$Arrow.scale = 2*Vector2(1/$Camera2D.zoom.x, 1/$Camera2D.zoom.y)
	$Arrow.offset.y = -60*$Camera2D.zoom.y

	var dr: float = wheel_turn_speed * delta / 180 * PI
	var max_r: float = max_wheel_angle / 180 * PI

	#######################################################
	# Path-following for CPUs
	#######################################################
	if type == CarType.CPU and _pathfollow != null:
		# Make sure our target point is far enough ahead.
		var target_direction: Vector2 = _pathfollow.global_position - global_position
		var dx: float = target_direction.length()
		if dx < 10:
			_pathfollow.progress += 300
		else:
			_pathfollow.progress += (300/dx) * linear_velocity.length() * delta
		var angle: float = target_direction.angle() - global_rotation
		for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight]:
			# Target angle of wheel (from wheel frame of reference).
			var target_angle: float = target_direction.angle() - PI/2 - rotation
			# Difference in angle between wheel and target path.
			var angle_diff: float = target_angle - wheel.rotation
			if angle_diff >= PI: angle_diff -= 2*PI
			elif angle_diff <= -PI: angle_diff += 2*PI
			if angle_diff < 0:
				if wheel.rotation > -max_r:
					wheel.rotation -= dr
			elif angle_diff > 0:
				if wheel.rotation < max_r:
					wheel.rotation += dr

	#######################################################
	# Wheel-turning for player
	#######################################################
	if type == CarType.PLAYER:
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
	# Movement
	#######################################################
	var go_pressed: bool = Input.is_action_pressed("go")
	var stop_pressed: bool = Input.is_action_pressed("stop")
	var reverse_pressed: bool = Input.is_action_pressed("reverse")
	# Keep track of how fast wheels are spinning (fastest one).
	# Value is used for things like zoom level and engine pitch.
	var fastest_wheel_speed: float = 0.0
	# Check if any wheels end up skidding, so a sound can play.
	var skidding: bool = false
	for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight, $Wheels/RearLeft, $Wheels/RearRight]:
		# Velocity of point where wheel connects to car
		var wheel_velocity: Vector2 = linear_velocity + wheel.position.rotated(rotation+PI/2) * angular_velocity
		# Direction that wheel is pointing.
		var wheel_direction: Vector2 = Vector2.from_angle(wheel.global_rotation + PI/2)
		var wheel_orthogonal_direction: Vector2 = Vector2.from_angle(wheel.global_rotation)
		# Infer current wheel speed based on speed w.r.t. ground.
		var current_speed: float = wheel_velocity.dot(wheel_direction)
		# Update speed based on user input.
		var new_speed: float = current_speed
		# Player hitting the gas, or CPU (which always hits gas).
		var f: Vector2 = Vector2.ZERO
		if moveable:
			if (type == CarType.PLAYER and go_pressed) or type == CarType.CPU:
				new_speed += acceleration * delta
			# Player hitting the brakes?
			elif (type == CarType.PLAYER and stop_pressed):
				if new_speed > 0: new_speed -= brakes * delta
				elif new_speed < 0: new_speed += brakes * delta
				# To avoid "quivering"
				if abs(new_speed) < brakes * delta: new_speed = current_speed * 0.5
			# Player backing up?
			elif (type == CarType.PLAYER and reverse_pressed):
				new_speed -= acceleration * delta
			# Slow down from air drag.
			else:
				if new_speed > 0: new_speed -= deceleration * delta
				elif new_speed < 0: new_speed += deceleration * delta
				# To avoid "quivering"
				if abs(new_speed) < deceleration * delta: new_speed = current_speed * 0.5
			# Keep track of fastest wheel, the speed will be used for other things
			# further down.
			if abs(new_speed) > fastest_wheel_speed:
				fastest_wheel_speed = abs(new_speed)
			# Calculate the force to apply to get the wheel to the new speed.
			f = mass/4.0 * (new_speed-current_speed) / delta * wheel_direction
		
		# Apply friction force orthogonal to wheel direction.
		current_speed = wheel_velocity.dot(wheel_orthogonal_direction)
		var mag: float = mass/4.0 * current_speed/delta
		# Dampen the magnitude so it's not a completely sudden stop in a single timestep.
		# That would case some weird glitching.
		mag *= 0.5
		# Combine static friction force and force of motion from engine.
		f += mag * -wheel_orthogonal_direction

		# Limit the static friction force magnitude.
		if f.length() > mass*acceleration*friction:
			f = f.limit_length(mass*acceleration*friction)
			skidding = true
			if wheel._current_skidmark == null:
				wheel._current_skidmark = load("res://cars/skid_mark.tscn").instantiate()
				add_sibling(wheel._current_skidmark)
			wheel._current_skidmark.add_skid(wheel.global_position)
		else:
			wheel._current_skidmark = null

		apply_force(f, wheel.position.rotated(rotation))

	if skidding and not $TireSquealSound.playing:
		$TireSquealSound.play(2.0)
	if not skidding and $TireSquealSound.playing:
		$TireSquealSound.stop()

	#######################################################
	# Zoom out camera the faster the car is going.
	#######################################################
	var z: float = 2.0 / (1 + 2*fastest_wheel_speed / max_speed)
	var zoom_limit: float = 0.1 * delta
	if z < $Camera2D.zoom.x:
		$Camera2D.zoom.x = z
		$Camera2D.zoom.y = z
	# When car slowing down, zoom back in.
	# But limit speed of zoom to avoid issues when speed suddenly drops.
	elif z-zoom_limit > $Camera2D.zoom.x:
		$Camera2D.zoom.x += zoom_limit
		$Camera2D.zoom.y += zoom_limit
	else:
		$Camera2D.zoom.x = z
		$Camera2D.zoom.y = z
		

	#######################################################
	# Engine sound
	#######################################################
	if fastest_wheel_speed <= 0.05 * max_speed:
		$EngineSound.pitch_scale = 0.5
	else:
		$EngineSound.pitch_scale = 1 + fastest_wheel_speed / max_speed

# Detect collision with an obstacle.
# Triggers code above for moving around the obstacle.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if state.get_contact_count() > 0:
		_contact = true
		_contact_normal = state.get_contact_local_normal(0)

func _on_body_entered(body: Node) -> void:
	if _crashing: return  # Only play sound once during a crashing period.
	$CrashSound.play()
	$CrashSoundTimer.start()
	_crashing = true

func _on_crash_sound_timer_timeout() -> void:
	_crashing = false
