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

## Coefficient of friction for wheels.  Relative to acceleration force.
## Should be > 1.0 or car will always be skidding.
@export var friction: float = 10

## Whether this car is user controllable.
@export var controllable: bool = false

## Whether this car is allowed to move.
var moveable: bool = false

## The path to follow if this is a CPU.
@export var path: Path2D = null
var _pathfollow: PathFollow2D = null

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
	controllable = true
	$Camera2D.enabled = true
	$Arrow.show()
	# Make own engine sound louder.
	$EngineSound.volume_db = 1.0

# Make this car follow a predetermined path
# (as local CPU).
func make_cpu (track_path: Path2D) -> void:
	# Make a copy of the track path, so we can add our own PathFollow2D.
	#path = track_path.duplicate()
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
	# Zoom out camera the faster the car is going.
	var z: float = 2.0 / (1 + 2*abs($Wheels/FrontLeft.speed) / max_speed)
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
		
	# Arrow pointing to player needs to stay oriented upward.
	$Arrow.global_rotation = 0
	$Arrow.scale = 2*Vector2(1/$Camera2D.zoom.x, 1/$Camera2D.zoom.y)
	$Arrow.offset.y = -60*$Camera2D.zoom.y

	var dr: float = wheel_turn_speed * delta / 180 * PI
	var max_r: float = max_wheel_angle / 180 * PI

	if controllable and moveable:
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
	if _pathfollow != null and moveable:
		# Make sure our target point is far enough ahead.
		var target_direction: Vector2 = _pathfollow.global_position - global_position
		var dx: float = target_direction.length()
		if dx < 10:
			_pathfollow.progress += 300
		else:
			_pathfollow.progress += (300/dx) * linear_velocity.length() * delta
		# Go go go
		for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight, $Wheels/RearLeft, $Wheels/RearRight]:
			if wheel.speed < max_speed:
				wheel.speed += acceleration * delta
		# ... in right direction
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
	# Engine sound
	#######################################################
	var speed: float = 0.
	for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight, $Wheels/RearLeft, $Wheels/RearRight]:
		speed += wheel.speed
	speed = abs(speed)/4
	if speed <= 0.05 * max_speed:
		$EngineSound.pitch_scale = 0.5
	else:
		$EngineSound.pitch_scale = 1 + speed / max_speed

func _physics_process(delta: float) -> void:
	if not moveable: return
	# If colliding with a surface, then apply some extra forces to help get
	# *off* of that surface.
	# Without this code, the car has a tendency to align itself perpendicular to
	# the collision surface, and getting stuck there until backing up (which
	# can take a while for the wheels to slow down and reverse).
	if _contact:
		apply_impulse(mass*max_speed*0.1*_contact_normal)
		for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight, $Wheels/RearLeft, $Wheels/RearRight]:
			if abs(wheel.speed) > max_speed * 0.01:
				wheel.speed *= 0.5
		_contact = false
		return
	#######################################################
	# Calculate movement (based on wheel speed and ground friction)
	# Also handle wheel skidding effect here.
	#######################################################
	var skidding: bool = false
	for wheel in [$Wheels/FrontLeft, $Wheels/FrontRight, $Wheels/RearLeft, $Wheels/RearRight]:
		# Orientation of wheel.
		var rot: float = wheel.global_rotation + PI/2
		# Velocity of wheel axis (on car) w.r.t. ground.
		# If car has just crashed into something, then allow some angular velocity reglardless
		# of friction force (allow car to spin a bit).
		var car_v: Vector2
		if _crashing:
			car_v = linear_velocity + 0.1*wheel.position.rotated(rotation+PI/2) * angular_velocity
		# Otherwise, under normal circumstances car should avoid spinning freely.
		else:
			car_v = linear_velocity + wheel.position.rotated(rotation+PI/2) * angular_velocity
		# Velocity of wheel spinning (opposite to direction that car motion will be).
		var wheel_v: Vector2 = wheel.speed * -Vector2.from_angle(rot)
		# Net velocity of wheel against ground.
		var net_v: Vector2 = car_v + wheel_v
		# Force of friction should counteract this force.
		var f: Vector2 = mass/4.0/delta * -net_v
		# Cap the static friction force.
		var mag: float = f.length()
		if mag > mass * acceleration * friction:
			mag = mass * acceleration * friction
			f = f.limit_length(mag)
			# If static friction force was maxxed out, then there's some skidding
			# for the wheel.
			skidding = true
			if wheel._current_skidmark == null:
				wheel._current_skidmark = load("res://cars/skid_mark.tscn").instantiate()
				add_sibling(wheel._current_skidmark)
			wheel._current_skidmark.add_skid(wheel.global_position)
		# If static force was sufficient to stick wheel to ground, then there
		# is no skidding.
		else:
			wheel._current_skidmark = null

		if skidding and not $TireSquealSound.playing:
			$TireSquealSound.play(2.0)
		if not skidding and $TireSquealSound.playing:
			$TireSquealSound.stop()

		apply_force(f, wheel.position.rotated(rotation))

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if state.get_contact_count() > 0:
		_contact = true
		_contact_normal = state.get_contact_local_normal(0)
	else:
		_contact = false

func _on_body_entered(_body: Node) -> void:
	if _crashing: return  # Only play sound once during a crashing period.
	$CrashSound.play()
	$CrashSoundTimer.start()
	_crashing = true
func _on_crash_sound_timer_timeout() -> void:
	_crashing = false
