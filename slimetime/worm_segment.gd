extends RigidBody2D

class_name WormSegment

# Direction that the segment will try to point towards (for standing on
# a surface)
var stand_angle: float = NAN
# Optional connections to other segments.
var front_segment: WormSegment = null
#var back_segment: WormSegment = null
var segment_spacing: float = 30.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#$AnimatedSprite2D.play()
	pass

func set_front_segment (segment: WormSegment) -> void:
	front_segment = segment
#func set_back_segment (segment: WormSegment) -> void:
#	back_segment = segment

# Get normal to any surface that's contacted.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	pass
	if state.get_contact_count() > 0:
		stand_angle = state.get_contact_local_normal(0).angle() + PI/2
		gravity_scale = 0.0
	else:
		pass
		stand_angle = NAN
		gravity_scale = 1.0

# Internal helper function - apply necessary forces to keep this segment "attached" to another one.
func _apply_attach (other: WormSegment, direction: int) -> void:
	var to_other: Vector2 = position - other.position
	var distance: float = to_other.length()
	print (self, other, distance)
	if distance > segment_spacing:
		var f: float = (distance - segment_spacing) * mass * -10
		#apply_central_force(f*to_other.normalized())
		set_deferred("position",position-(distance-segment_spacing)*to_other.normalized())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Apply a torque to align the body segment with a surface.
	if is_finite(stand_angle):
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
	# Apply a force to stick the feet to a surface.
	if is_finite(stand_angle):
		var f: Vector2 = Vector2.from_angle(stand_angle+PI/2)
		apply_central_force(100*f*mass)  # Why does force have to be 100 times stronger than gravity to avoid slipping?
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
