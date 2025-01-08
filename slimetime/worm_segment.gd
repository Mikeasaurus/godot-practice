extends RigidBody2D

class_name WormSegment

# Signal to indicate the segment has landed on a surface
signal landed

# Remember contact direction of the last surface that was attached to.
var last_surface_normal: Vector2
# Remember a surface reference point (to help correct trajectory if starting to leave surface).
var last_surface_reference: Vector2
# Indicates if currently standing on a surface (to determine if user can control
# movement)
var on_surface: bool
# Indicates if the feet should "stick" strongly to a surface that it touches.
var sticky_feet: bool


# Direction that the segment is pointing towards
var facing_direction: Vector2
# Direction that the segment's feet are in.
# Only general direction of this is used.  facing_direction will determine exact angles.
var feet_direction: Vector2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set gravity, so segment will start falling onto the surface below
	# if it's placed above the ground.
	last_surface_normal = Vector2(0,1)
	last_surface_reference = Vector2.ZERO
	# Set the direction that the segment is facing toward.
	facing_direction = Vector2(1,0)
	# Set the feet direction.
	feet_direction = Vector2(0,1)
	# Ready to land and stick to a surface.
	on_surface = false
	sticky_feet = true

# Helper method - flip the segment in the opposite direction.
# Maybe there's a better way to do this?
# can't find a way to do this to all child nodes in one shot, need to
# do each one individually?
func flip_segment() -> void:
	# Flip the components.
	$AnimatedSprite2D.flip_h = not $AnimatedSprite2D.flip_h
	$AnimatedSprite2D/Outline.flip_h = not $AnimatedSprite2D/Outline.flip_h
	$AnimatedSprite2D/Body.flip_h = not $AnimatedSprite2D/Body.flip_h
	$AnimatedSprite2D/Top.flip_h = not $AnimatedSprite2D/Top.flip_h
	# Change sign of horizontal offset.
	$AnimatedSprite2D.offset.x *= -1
	$AnimatedSprite2D/Outline.offset.x *= -1
	$AnimatedSprite2D/Body.offset.x *= -1
	$AnimatedSprite2D/Top.offset.x *= -1
func is_flipped() -> bool:
	return $AnimatedSprite2D.flip_h

# Helper method - update sprite based on current facing direction and feet direction.
func update_sprite() -> void:
	var orientation: Vector2 = facing_direction
	# Check if need to flip the segment around.
	# Y direction is flipped (positive downward), so sign check for cross
	# product is flipped as well.
	var need_flip: bool = feet_direction.cross(facing_direction) > 0
	if need_flip != is_flipped():
		flip_segment()
	if is_flipped():
		orientation *= -1
	$AnimatedSprite2D.global_rotation = orientation.angle()
	# Update feet direction.
	var v: Vector2 = orientation.rotated(PI/2)
	if v.dot(feet_direction) > 0:
		feet_direction = v
	else:
		feet_direction = -v

# Get normal to any surface that's contacted, align direction vectors accordingly.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not sticky_feet: return
	var n = state.get_contact_count()
	if n > 0:
		# Sum up all contact normals.
		# Should make it less jittery when transitioning from one surface to another?
		var v: Vector2 = Vector2.ZERO
		for i in range(n):
			v  += state.get_contact_local_normal(i)
		# Stand upright on surface.
		last_surface_normal = -v.normalized()
		last_surface_reference = global_position + last_surface_normal * 50
		feet_direction = last_surface_normal
		# Update facing direction based on feet direction.
		if feet_direction.cross(facing_direction) < 0:
			facing_direction = feet_direction.rotated(-PI/2)
		else:
			facing_direction = feet_direction.rotated(PI/2)
		if not on_surface:
			landed.emit()  # For playing landing sound (handled in worm_front)
		on_surface = true
"""
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:

	# Modify rotation / flip of the segment

	# Adjust the rotation of the segment so it's aligned w.r.t. to segment
	# in front and/or behind.

	# Case 1: this is the front segment (check if no segments ahead).
	if front_segment == null and back_segment != null:
		# Use back segment to define alignment, if far enough distance.
		var v: Vector2 = global_position - back_segment.global_position
		if v.length() > segment_spacing * 0.9:
			if v.dot(facing_direction) > 0:
				facing_direction = v.normalized()
			else:
				facing_direction = -v.normalized()
		# Otherwise, will be aligned to ground based (handled in _integrate_forces)

	# Case 2: this is an inner segment.
	if front_segment != null and back_segment != null:
		# Only if this segment is actually in-between the other segments.
		# (not if in process of turning whole body around in a different direction).
		if (global_position-back_segment.global_position).dot(front_segment.global_position-global_position) > 0:
			# Only if far enough distance.
			if (front_segment.global_position - back_segment.global_position).length() > segment_spacing * 0.9:
				facing_direction = (front_segment.global_position - back_segment.global_position).normalized()
	# Case 3: this is the tail segment (check if no segments behind).
	if back_segment == null and front_segment != null:
		if (front_segment.global_position - global_position).length() > segment_spacing * 0.9:
			facing_direction = (front_segment.global_position - global_position).normalized()

	# Adjust feet to be same direction as segment in front.
	if front_segment != null:
		feet_direction = front_segment.feet_direction

	# Adjust z-order if facing opposite direction from segement behind.
	# I.e., moving in opposite direction, visually in front of other segments.
	if back_segment != null:
		if facing_direction.dot(back_segment.facing_direction) < 0:
			z_index = back_segment.z_index + 5
		else:
			z_index = back_segment.z_index
	# Flip and adjust z-order if being passed by front segment from other direction.
	if front_segment != null:
		var v: Vector2 = front_segment.global_position - global_position
		if v.dot(facing_direction) < 0:
			facing_direction *= -1
			# Update z-order unless front is turned around, then let it stay in front.
			if front_segment.facing_direction.dot(v) > 0 and back_segment != null:
				z_index = front_segment.z_index

	# Apply new orientation
	update_sprite()

	# Check if moving, need to animate legs?
	if on_surface and linear_velocity.length() > 10:
		$AnimatedSprite2D.play()
	else:
		$AnimatedSprite2D.pause()

# Helper method - Set the velocity along the given direction.
# Velocity in orthogonal direction is left untouched.
func set_velocity_in_direction (direction: Vector2, vel: float) -> void:
	# Normalized direction of effect
	var v: Vector2 = direction.normalized()
	# Target linear velocity
	var lv: Vector2 = linear_velocity
	# Strip out current velocity along that direction.
	lv -= lv.dot(v) * v
	# Add in desired velocity
	lv += vel * v
	# Adjust the velocity through an impulse.
	apply_central_impulse(lv-linear_velocity)

# The following code controls force of movement for the segments.
func _physics_process(delta: float) -> void:
	# This variable defines a force point of attraction for the segment.
	# Could be force of gravity, or a force sticking the segment to a surface.
	# Initialized with current attraction point, can be updated to include
	# other forces further below.
	var gd: Vector2 = last_surface_normal

	# Bring the segment to the correct distance to the front neighbour.
	if front_segment != null:
		# Figure out where this segment would be w.r.t. the front one, at the end of this
		# time step.
		var v2: Vector2 = front_segment.global_position + front_segment.linear_velocity*delta
		var v1: Vector2 = global_position + linear_velocity*delta
		# Calculate the distance, and apply a correction if distance would be too large.
		var to_other: Vector2 = v2 - v1
		var distance: float = to_other.length()
		if distance > segment_spacing * 1.05:
			# Close the gap.
			# Instantaneous.  I had too many problems with other approaches:
			# - Using a force was too springy.
			# - Setting a linear velocity mostly worked, but doing so negated any
			#   other forces (gravity) from being applied.
			var vel: float = (distance-segment_spacing)/delta*0.5
			# If velocity if above some threshold, then may need to un-stick from a surface
			# to allow the correction to take place.
			if vel > 1000.0 and on_surface:
				release_from_surface()
			set_velocity_in_direction(to_other, vel)

		# If close enough to front segment, then turn off any further velocity
		# in that particular direction.
		if distance <= segment_spacing * 0.9:
			set_velocity_in_direction(to_other, 0.0)

	# Avoid moving in direction that would cause segments to jack-knife.
	if not on_surface and front_segment != null and front_segment.front_segment != null:
		var x1a: Vector2 = global_position
		var x2a: Vector2 = front_segment.global_position
		var x3a: Vector2 = front_segment.front_segment.global_position
		var v1a: Vector2 = (x1a-x2a).normalized()
		var v2a: Vector2 = (x3a-x2a).normalized()
		var cosa: float = v2a.dot(v1a)
		var x1b: Vector2 = global_position + linear_velocity*delta
		var x2b: Vector2 = front_segment.global_position + front_segment.linear_velocity*delta
		var x3b: Vector2 = front_segment.front_segment.global_position + front_segment.front_segment.linear_velocity*delta
		var v1b: Vector2 = (x1b-x2b).normalized()
		var v2b: Vector2 = (x3b-x2b).normalized()
		var cosb: float = v2b.dot(v1b)
		# Check if segments are at a steep angle, and getting steeper.
		if cosa > -0.5 and cosb > cosa:
			# Turn off motion in that direction.
			set_velocity_in_direction(x3b-x1b,0)

	# If disattached from a surface, but neighbouring segment(s) are attached,
	# then apply an attachment force to this segment.
	if not on_surface and front_segment != null and front_segment.on_surface:
		gd = front_segment.last_surface_normal

	# Keep segments from drifting away from surface.
	if on_surface and last_surface_reference != Vector2.ZERO:
		set_velocity_in_direction(global_position-last_surface_reference,0.0)

	# Generate a force of motion in response to user input (front segment only)
	if front_segment == null:
		# Determine direction to move in, based on direction specified by user.
		var move_direction: Vector2 = Vector2.ZERO
		if Input.is_action_pressed("move_right"):
			move_direction += Vector2(1,0)
		if Input.is_action_pressed("move_left"):
			move_direction += Vector2(-1,0)
		if Input.is_action_pressed("move_down"):
			move_direction += Vector2(0,1)
		if Input.is_action_pressed("move_up"):
			move_direction += Vector2(0,-1)
		# Check if there's any user-driven movement, and if it's not orthogonal
		# to surface.
		if move_direction != Vector2.ZERO:
			var cos_angle: float = move_direction.normalized().dot(facing_direction)
			if abs(cos_angle) >= 0.5 and on_surface:
				# If going in opposite direction to before, need to invert direction that we're facing.
				if move_direction.dot(facing_direction) < 0:
					facing_direction *= -1
				gd += facing_direction
		# If no user-driven movement, then hit the brakes on momentum so the worm
		# doesn't keep gliding forward.
		elif on_surface:
			gd -= linear_velocity.normalized()
	if Input.is_action_just_pressed("jump") and on_surface:
		# Apply impulse to launch the segment in the air.
		release_from_surface()
		# Stop rotating the collision circles.
		# Otherwise it sometimes makes the worm fly off in unexpected directions.
		apply_torque_impulse(-angular_velocity)
		# Apply jump force.
		apply_central_impulse((facing_direction-feet_direction) * 300)
		# Apply jump sound.  Only do once (not for all segments.
		if front_segment == null:
			$JumpSound.play()
		# Turn worm around if on a steep surface (wall jumping).
		if abs(facing_direction.x) <= 0.2:
			feet_direction *= -1
	# Apply the force.
	apply_central_force(gd.normalized()*Globals.gravity)

	# Visual aid for centre of force, for debugging.
	$GravityPoint.global_position = global_position + gd
"""
# Helper function - release segment from a surface so it has time for reacting to
# impulses or other forces (such as to initiate a jump).
func release_from_surface () -> void:
	sticky_feet = false
	on_surface = false
	last_surface_reference = Vector2.ZERO
	# Re-enable a gravitational force
	last_surface_normal = Vector2(0,1)
	$JumpTimer.start()
# Callback function, called shortly after jump was initiated.
# Re-enables "sticking" to surfaces, for when worm lands from the jump.
func _on_jump_timer_timeout() -> void:
	sticky_feet = true
