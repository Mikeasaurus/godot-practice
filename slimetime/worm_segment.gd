extends RigidBody2D

var stand_angle = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#$AnimatedSprite2D.play()
	pass

# Get normal to any surface that's contacted.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	pass
	if state.get_contact_count() > 0:
		stand_angle = state.get_contact_local_normal(0).angle() + PI/2
		#rotation = stand_angle

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Calculate target angle.
	var target_angle = stand_angle
	# Find how far away we are from that angle.
	var angle_diff = target_angle - rotation
	if angle_diff < -PI: angle_diff += 2*PI
	if angle_diff > PI: angle_diff -= 2*PI
	# Apply a torque proportional to that difference, to get us to the
	# desired angle.
	#apply_torque(-10000)
	var computed_inertia = 1./PhysicsServer2D.body_get_direct_state(get_rid()).inverse_inertia
	#print (computed_inertia)
	#apply_torque(50*computed_inertia*angle_diff)
	apply_torque_impulse(computed_inertia*angle_diff)
	
