extends RigidBody2D

class_name WormSegment

# How fast the worm will walk on a surface (pixels/second)
@export var walking_speed: float = 100.0

# Keep memory of sticky feet force, even if momentarily detached.
var sticky_feet_force: Vector2 = Vector2.ZERO

# Attraction point.  Either for gravity or for sticking to a surface.
var gravity_point: Vector2 = Vector2.ZERO

# Direction that the segment will try to point towards (for standing on a surface)
var stand_angle: float = NAN
# Optional connections to other segments.
var front_segment: WormSegment = null
var segment_spacing: float = 30.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#$AnimatedSprite2D.play()
	print (position, $CollisionShape2D.position, $GravityPoint.position)
	gravity_point = Vector2(0,100)

func set_front_segment (segment: WormSegment) -> void:
	front_segment = segment

# Get normal to any surface that's contacted.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	pass
	if state.get_contact_count() > 0:
		stand_angle = state.get_contact_local_normal(0).angle() + PI/2
		#gravity_scale = 0.0
		$GravityTimer.stop()
	else:
		stand_angle = NAN
		if $GravityTimer.is_stopped():
			$GravityTimer.start()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var f: Vector2 = Vector2.ZERO
	# Apply a torque to align the body segment with a surface.
	if false and is_finite(stand_angle):
		var angle_diff: float = stand_angle - rotation
		if angle_diff < -PI: angle_diff += 2*PI
		if angle_diff > PI: angle_diff -= 2*PI
		# Apply a torque proportional to that difference, to get us to the
		# desired angle.
		#apply_torque(-10000)
		#var computed_inertia: float = 1./PhysicsServer2D.body_get_direct_state(get_rid()).inverse_inertia
		#print (computed_inertia)
		#apply_torque(50*computed_inertia*angle_diff)
		#apply_torque_impulse(computed_inertia*angle_diff)
		angular_velocity = angle_diff
	# Apply a force to bring the segment to the correct distance to the front and back neighbours.
	# TODO: revisit this for when the worm is turning around.
	if front_segment != null:
		var to_other: Vector2 = front_segment.position - position
		var distance: float = to_other.length()
		if distance > segment_spacing:
			#var f: float = (distance - segment_spacing) * mass * -10
			#apply_central_force(f*to_other.normalized())
			#set_deferred("position",position-(distance-segment_spacing)*to_other.normalized())
			linear_velocity = (distance - segment_spacing) * to_other.normalized()
	# Check for user-driven movement, if this is the front (leader) segment.
	if front_segment == null:
		if Input.is_action_pressed("move_right") and is_finite(stand_angle):
			#linear_velocity = 30 * Vector2.from_angle(stand_angle + PI/2)
			#apply_force(walking_speed * Vector2.from_angle(stand_angle), Vector2.from_angle(stand_angle-PI/2)*50)
			#f += walking_speed * Vector2.from_angle(stand_angle)
			#gravity_point = position + Vector2(100,100)
			#f = Vector2.from_angle(stand_angle-PI/2) * 10
			gravity_point = Vector2(100,100)
		elif is_finite(stand_angle):
			gravity_point = Vector2(0,100)
			#f = Vector2.from_angle(stand_angle-PI/2) * 10
		else:
			#f = Vector2(0,1) * 10
			gravity_point = Vector2(0,100)
	#TODO
	apply_central_force(gravity_point.normalized()*10)
	$GravityPoint.position = gravity_point

func _on_gravity_timer_timeout() -> void:
	pass
	#gravity_scale = 1.0
	#sticky_feet_force = Vector2.ZERO
