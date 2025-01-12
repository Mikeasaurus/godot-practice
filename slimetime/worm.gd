extends Node2D

signal ate_bug

# Array to hold individual worm segments.
var segments: Array[WormSegment] = []
# How far apart the segments should be.
var segment_spacing: float = 30.0

@export var worm_segment_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Organize the segments into an ordered array.
	# Note: When I tried to set this from within the declaration of "segments", the
	# elements were all null.  Have to wait until runtime for these references to exist?
	segments.append_array([$WormFront, $WormSegment3, $WormSegment2, $WormSegment1, $WormTail])

func _input(_event: InputEvent) -> void:
	# Check if we need to shoot some slime.
	if Input.is_action_just_pressed("shoot_slime"):
		# Tell head segment to shoot some slime.
		segments[0].shoot_slime()
	# Debug action... grow the worm on command.
	if Input.is_action_just_pressed("grow"):
		# Add a new segment, just behind the front segment.
		var segment: WormSegment = worm_segment_scene.instantiate()
		add_child(segment)
		segment.global_position = (segments[0].global_position + segments[1].global_position) / 2
		segments.insert(1,segment)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Modify rotation / flip of the segments

	# Adjust the rotation of the segments so they're aligned w.r.t. to segment
	# in front and/or behind.

	var segment: WormSegment
	var front_segment: WormSegment
	var back_segment: WormSegment
	var v: Vector2

	# Align front segment
	segment = segments[0]
	back_segment = segments[1]
	v = segment.global_position - back_segment.global_position
	if v.length() > segment_spacing * 0.9:
		if v.dot(segment.facing_direction) > 0:
			segment.facing_direction = v.normalized()
		else:
			segment.facing_direction = -v.normalized()
	# Otherwise, will be aligned to ground based (handled in _integrate_forces)

	# Align inner segments
	for i in range(1,len(segments)-1):
		segment = segments[i]
		back_segment = segments[i+1]
		front_segment = segments[i-1]
		# Only if this segment is actually in-between the other segments.
		# (not if in process of turning whole body around in a different direction).
		if (segment.global_position-back_segment.global_position).dot(front_segment.global_position-segment.global_position) > 0:
			# Only if far enough distance.
			if (front_segment.global_position - back_segment.global_position).length() > segment_spacing * 0.9:
				segment.facing_direction = (front_segment.global_position - back_segment.global_position).normalized()

	# Align tail segment.
	segment = segments[-1]
	front_segment = segments[-2]
	if (front_segment.global_position - segment.global_position).length() > segment_spacing * 0.9:
		segment.facing_direction = (front_segment.global_position - segment.global_position).normalized()

	# Adjust feet to be same direction as segment in front.
	for i in range(1,len(segments)):
		segments[i].feet_direction = segments[i-1].feet_direction
		segments[i].update_sprite()

	# Adjust z-order if facing opposite direction from segment behind.
	# I.e., moving in opposite direction, visually in front of other segments.
	for i in range(len(segments)-2,-1,-1):
		segment = segments[i]
		back_segment = segments[i+1]
		if segment.facing_direction.dot(back_segment.facing_direction) < 0:
			segment.z_index = back_segment.z_index + 5
		else:
			segment.z_index = back_segment.z_index
	# Flip and adjust z-order if being passed by front segment from other direction.
	for i in range(1,len(segments)):
		segment = segments[i]
		front_segment = segments[i-1]
		v = front_segment.global_position - segment.global_position
		if v.dot(segment.facing_direction) < 0:
			segment.facing_direction *= -1
			# Update z-order unless front is turned around, then let it stay in front.
			if front_segment.facing_direction.dot(v) > 0 and back_segment != null:
				segment.z_index = front_segment.z_index

	# Update segment sprites.
	for s in segments:
		s.update_sprite()

# The following code controls force of movement for the segments.
func _physics_process(delta: float) -> void:
	# This variable defines a force point of attraction for the segments.
	# Could be force of gravity, or a force sticking the segment to a surface.
	# Initialized with current attraction points, can be updated to include
	# other forces further below.
	var gd: Array[Vector2]
	for s in segments: gd.append(s.last_surface_normal)

	# Bring the segment to the correct distance to the front neighbour.
	for i in range(1,len(segments)):
		var segment: WormSegment = segments[i]
		var front_segment: WormSegment = segments[i-1]
		# Figure out where this segment would be w.r.t. the front one, at the end of this
		# time step.
		var v2: Vector2 = front_segment.global_position + front_segment.linear_velocity*delta
		var v1: Vector2 = segment.global_position + segment.linear_velocity*delta
		# Calculate the distance, and apply a correction if distance would be too large.
		var to_other: Vector2 = v2 - v1
		var distance: float = to_other.length()
		if distance > segment_spacing * 1.05 and distance < segment_spacing * 10:
			# Close the gap.
			# Instantaneous.  I had too many problems with other approaches:
			# - Using a force was too springy.
			# - Setting a linear velocity mostly worked, but doing so negated any
			#   other forces (gravity) from being applied.
			var vel: float = (distance-segment_spacing)/delta*0.5
			# If velocity if above some threshold, then may need to un-stick from a surface
			# to allow the correction to take place.
			if vel > 1000.0 and segment.on_surface:
				segment.release_from_surface()
			# Limit the velocity (so things don't fly around the screen)
			if vel > 2000.0: vel = 2000.0
			segment.set_velocity_in_direction(to_other, vel)

		# If close enough to front segment, then turn off any further velocity
		# in that particular direction.
		if distance <= segment_spacing * 0.9:
			segment.set_velocity_in_direction(to_other, 0.0)

	# Avoid moving in direction that would cause segments to jack-knife.
	for i in range(2,len(segments)):
		var s1: WormSegment = segments[i]
		var s2: WormSegment = segments[i-1]
		var s3: WormSegment = segments[i-2]
		if s1.on_surface: continue
		var x1a: Vector2 = s1.global_position
		var x2a: Vector2 = s2.global_position
		var x3a: Vector2 = s3.global_position
		var v1a: Vector2 = (x1a-x2a).normalized()
		var v2a: Vector2 = (x3a-x2a).normalized()
		var cosa: float = v2a.dot(v1a)
		var x1b: Vector2 = s1.global_position + s1.linear_velocity*delta
		var x2b: Vector2 = s2.global_position + s2.linear_velocity*delta
		var x3b: Vector2 = s3.global_position + s3.linear_velocity*delta
		var v1b: Vector2 = (x1b-x2b).normalized()
		var v2b: Vector2 = (x3b-x2b).normalized()
		var cosb: float = v2b.dot(v1b)
		# Check if segments are at a steep angle, and getting steeper.
		if cosa > -0.5 and cosb > cosa:
			# Turn off motion in that direction.
			s1.set_velocity_in_direction(x3b-x1b,0)

	# If disattached from a surface, but neighbouring segment(s) are attached,
	# then apply an attachment force to this segment.
	for i in range(1,len(segments)):
		if (not segments[i].on_surface) and segments[i-1].on_surface:
			gd[i] = segments[i-1].last_surface_normal
	# Special case: head is disattached from surface, but some other segment is attached.
	# Use the surface reference of that segment to bring it toward an attachment point.
	if not segments[0].on_surface:
		for i in range(1,len(segments)):
			if segments[i].on_surface:
				gd[0] = (segments[i].last_surface_reference-segments[0].global_position).normalized()
				break

	# Keep segments from drifting away from surface.
	for s in segments:
		if s.on_surface and s.last_surface_reference != Vector2.ZERO:
			s.set_velocity_in_direction(s.global_position-s.last_surface_reference,0.0)

	# Generate a force of motion in response to user input (front segment only)
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
	# Movement only applies to front segment (other segments follow passively)
	var head: WormSegment = segments[0]
	# Check if there's any user-driven movement, and if it's not orthogonal
	# to surface.
	if move_direction != Vector2.ZERO:
		var cos_angle: float = move_direction.normalized().dot(head.facing_direction)
		if abs(cos_angle) >= 0.5 and head.on_surface:
			# If going in opposite direction to before, need to invert direction that we're facing.
			if move_direction.dot(head.facing_direction) < 0:
				head.facing_direction *= -1
			gd[0] += head.facing_direction
	# If no user-driven movement, then hit the brakes on momentum so the worm
	# doesn't keep gliding forward.
	else:
		for i in range(len(segments)):
			if segments[i].on_surface:
				gd[i] -= segments[i].linear_velocity.normalized()

	# Do a jump
	if Input.is_action_just_pressed("jump"):
		if segments[0].on_surface:
			# Apply jump sound.  Only once.
			$JumpSound.play()
			# Define the direction of jump, based on front segment.
			# All segments should be jumping in the same direction.
			var jump_impulse: Vector2 = (segments[0].facing_direction - segments[0].feet_direction) * 300
			for s in segments:
				# Apply impulse to launch the segment in the air.
				s.release_from_surface()
				# Stop rotating the collision circles.
				# Otherwise it sometimes makes the worm fly off in unexpected directions.
				s.apply_torque_impulse(-s.angular_velocity)
				# Apply jump force.
				s.apply_central_impulse(jump_impulse)
				# Turn worm around if on a steep surface (wall jumping).
				if abs(s.facing_direction.x) <= 0.2:
					s.feet_direction *= -1
	
	# Apply the force.
	for i in range(len(segments)):
		segments[i].apply_central_force(gd[i].normalized()*Globals.gravity)
		# Visual aid for centre of force, for debugging.
		segments[i].get_node("GravityPoint").global_position = segments[i].global_position + gd[i]



# Pass along signal when a bug is eaten.
func _on_worm_front_ate_bug() -> void:
	ate_bug.emit()
