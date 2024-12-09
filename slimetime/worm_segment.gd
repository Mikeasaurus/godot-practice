extends RigidBody2D

class_name WormSegment

# Attraction point.  Either for gravity or for sticking to a surface.
var gravity_point: Vector2 = Vector2.ZERO
# Indicates if currently standing on a surface (to determine if user can control
# movement)
var on_surface: bool = false
# Keep track of the orientation angle, to stop it from rolling with the collision circle.
var orientation: float = 0.0
# When the last time that the segement was touching a surface.
var last_stand: float = 0.0
# Optional connections to other segments.
var front_segment: RigidBody2D = null
var back_segment: RigidBody2D = null
var segment_spacing: float = 30.0

# Current direction of the segment.
# Relative to the direction of its feet.
var current_direction: String = "right"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set gravity, so segment will start falling onto the surface below
	# if it's placed above the ground.
	gravity_point = global_position + Vector2(0,100)

# Helper methods to associate this segment with neighbouring segments.
# Called by a higher-level scene which will manage the overall worm.
func set_front_segment (segment: RigidBody2D) -> void:
	front_segment = segment
func set_back_segment (segment: RigidBody2D) -> void:
	back_segment = segment

# Helper method - flip the segment in the opposite direction.
# Maybe there's a better way to do this?
# can't find a way to do this to all child nodes in one shot, need to
# do each one individually?
func flip_segment(adjust_zorder=true) -> void:
	# Get width of the segment, and current offset.
	var w = $AnimatedSprite2D/Outline.texture.get_width()
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
	# Update current direction (so other segments can compare against it)
	if current_direction == "left":
		current_direction = "right"
	else:
		current_direction = "left"
	# Put all layers ahead, so outline is visible while turning around.
	# This will have to be re-adjusted back down when all segments have high z-index.
	if adjust_zorder:
		if back_segment == null:
			z_index = front_segment.z_index
		elif back_segment != null:
			if back_segment.current_direction != current_direction:
				z_index = back_segment.z_index + 5
			# If turned around back and forth quickly, and re-aligned with segment
			# behind, then restore old z order.
			else:
				z_index = back_segment.z_index

# Helper method: return true if the segement is flipped (turned around in other
# direction)
func is_flipped() -> bool:
	return current_direction == "left"

# Helper method - get current rotation of sprite.
# (not segment rotation, which is affected by rolling collision circle).
func get_orientation() -> float:
	return $AnimatedSprite2D.global_rotation
# Helper method - set orientation of sprite.
func set_orientation(angle: float) -> void:
	if angle < 0: angle += 2*PI
	if angle >= 2*PI: angle -= 2*PI
	$AnimatedSprite2D.global_rotation = angle
	# Save this orientation for cases where it should be held fixed
	# (when no other context for determining the best orientation)
	orientation = angle

# Helper method - get the normalized direction that the segment is facing.
func get_facing_direction():
	var angle: float = get_orientation()
	var facing: Vector2 = Vector2.from_angle(angle)
	# If segment is horizontally flipped, then flip sign of direction.
	if is_flipped():
		facing *= -1
	return facing
# Helper method - get downward direction relative from the sprite.
func get_downward_direction():
	var angle: float = get_orientation() - PI/2
	var downward: Vector2 = Vector2.from_angle(angle)
	return downward

# Get normal to any surface that's contacted.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var n = state.get_contact_count()
	if n > 0:
		# Sum up all contact normals.
		# Should make it less jittery when transitioning from one surface to another?
		var v: Vector2 = Vector2.ZERO
		for i in range(n):
			v  += state.get_contact_local_normal(i)
		gravity_point = global_position - v.normalized()*100
		last_stand = Time.get_ticks_msec()
		on_surface = true
	elif Time.get_ticks_msec() - last_stand > 100:
		#TODO: orient with gravity points of neighbouring segments?
		gravity_point = global_position + Vector2(0,100)
		on_surface = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Check if need to flip direction of the segment.
	# Follow the orientation of the segment in front, if it has moved past this one.
	# Note: very front segment is not flipped here, it's determine from change in
	# direction from user controls.
	if front_segment != null:
		var to_other: Vector2 = front_segment.global_position - global_position
		# Flip direction if segment ahead has turned around and moved past this one.
		if to_other.dot(get_facing_direction()) < 0:
			if current_direction != front_segment.current_direction:
				flip_segment()
		# Fail safe: if in a weird state where we are upside down w.r.t. the segment in front,
		# then re-adjust.
		# This happens sometimes if second segment gets ahead of head... don't know why.
		# But easy enough to fix I guess.
		var v1 = Vector2.from_angle(get_orientation())
		var v2 = Vector2.from_angle(front_segment.get_orientation())
		if v1.dot(v2) < 0:
			flip_segment(false)
			set_orientation(get_orientation()+PI)
	
	# Adjust the rotation of the segment so it's aligned w.r.t. to segment
	# in front and/or behind.
	var alignment_vector: Vector2 = Vector2.from_angle(orientation)
	# Case 1: this is the front segment (check if no segments ahead).
	if front_segment == null and back_segment != null:
		if get_facing_direction().dot(global_position - back_segment.global_position) > 0:
			# Only if far enough distance.
			if (global_position - back_segment.global_position).length() > segment_spacing * 0.9:
				alignment_vector = global_position - back_segment.global_position
				if is_flipped():
					alignment_vector *= -1
	# Case 2: this is an inner segment.
	if front_segment != null and back_segment != null:
		# Only if this segment is actually in-between the other segments.
		# (not if in process of turning whole body around in a different direction).
		if (global_position-back_segment.global_position).dot(front_segment.global_position-global_position) > 0:
			# Only if far enough distance.
			if (front_segment.global_position - back_segment.global_position).length() > segment_spacing * 0.9:
				alignment_vector = front_segment.global_position - back_segment.global_position
				if is_flipped():
					alignment_vector *= -1
	# Case 3: this is the tail segment (check if no segments behind).
	if back_segment == null and front_segment != null:
		if get_facing_direction().dot(front_segment.global_position - global_position) > 0:
			# Only if far enough distance.
			if (front_segment.global_position - global_position).length() > segment_spacing * 0.9:
				alignment_vector = front_segment.global_position - global_position
				if is_flipped():
					alignment_vector *= -1
	# Instantaneous adjustment to the new alignment.
	set_orientation(alignment_vector.angle())
	
	# Check if moving, need to animate legs?
	if linear_velocity.length() > 10:
		$AnimatedSprite2D.play()
	else:
		$AnimatedSprite2D.pause()
		
	# The following code controls force of movement for the segments.
	
	# This variable defines a force point of attraction for the segment.
	# Could be force of gravity, or a force sticking the segment to a surface.
	# Initialized with current attraction point, can be updated to include
	# other forces further below.
	var gp: Vector2 = gravity_point

	# Bring the segment to the correct distance to the front neighbour.
	if front_segment != null:
		var to_other: Vector2 = front_segment.global_position - global_position
		var distance: float = to_other.length()
		if distance > segment_spacing * 1.05:
			# Close the gap.
			# Instantaneous.  I had too many problems with other approaches:
			# - Using a force was too springy.
			# - Setting a linear velocity mostly worked, but doing so negated any
			#   other forces (gravity) from being applied.
			var dx: Vector2 = to_other.normalized() * (distance - segment_spacing)
			global_position += dx
			# Set linear velocity to give it its own momentum.
			# Average it with current velocity to dampen any sudden jumps
			# (e.g. at start when segments need to self-adjust to right spacing)
			#TODO: use proper function to add impulse?
			linear_velocity = 0.9 * linear_velocity + 0.1 * dx / delta
			# Adjust z-order
			# (fail safe for when it doesn't work otherwise)
			if current_direction == front_segment.current_direction:
				z_index = front_segment.z_index

		# If close enough to front segment, and on a surface, then turn off any further velocity
		# in that particular direction.
		if distance <= segment_spacing * 0.9:
			var dx: Vector2 = to_other.normalized()
			if linear_velocity.dot(dx) > 10:
				linear_velocity -= linear_velocity.dot(dx) * dx

	# If disattached from a surface, but neighbouring segment(s) are attached,
	# then apply an attachment force to this segment.
	if not on_surface and front_segment != null and front_segment.on_surface:
		#print ("re-attach", self)
		gp = front_segment.gravity_point - front_segment.global_position + global_position

	# Generate a force of motion in response to user input (front segment only)
	if front_segment == null:
		if Input.is_action_pressed("move_right") and on_surface:
			# Lead the gravity point in the direction of travel.
			# Motion will be from an effect of this force.
			gp += (gravity_point - global_position).rotated(-PI/2).normalized() * 50
			# Check if the sprites need to be flipped around.
			# Check if the sprites need to be flipped around.
			if current_direction == "left":
				flip_segment()
		elif Input.is_action_pressed("move_left") and on_surface:
			# Lead the gravity point in the direction of travel.
			# Motion will be from an effect of this force.
			gp -= (gravity_point - global_position).rotated(-PI/2).normalized() * 50
			# Check if the sprites need to be flipped around.
			if current_direction == "right":
				flip_segment()
		# If on a surface, but no key pressed, hit the brakes on movement.
		elif on_surface and linear_velocity.length() > 10:
			gp -= linear_velocity.normalized()*100
	# Apply the force.
	if true or front_segment == null:
		apply_central_force((gp-global_position).normalized()*200)

	# Visual aid for centre of force, for debugging.
	$GravityPoint.global_position = gp
