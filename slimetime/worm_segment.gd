extends RigidBody2D

class_name WormSegment

# Attraction point.  Either for gravity or for sticking to a surface.
var gravity_point: Vector2 = Vector2.ZERO

# Direction that the segment will try to point towards (for standing on a surface)
var stand_angle: float = NAN
# When the last time that the segement was touching a surface.
var last_stand: float = 0.0
# Optional connections to other segments.
var front_segment: RigidBody2D = null
var segment_spacing: float = 30.0

# Current direction of the segment.
var current_direction: String = "right"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	gravity_point = global_position + Vector2(0,100)

func set_front_segment (segment: RigidBody2D) -> void:
	front_segment = segment

# Helper method - flip the segment in the opposite direction.
# Maybe there's a better way to do this?
# can't find a way to do this to all child nodes in one shot, need to
# do each one individually?
func flip_segment() -> void:
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

# Helper method: return true if the segement is flipped (turned around in other
# direction)
func is_flipped() -> bool:
	return current_direction == "left"

# Helper method - get the normalized direction that the segment is facing.
# Based on stand_angle value (orientation that the segment *should* have).
# May be different from current rotation value, if it the segment is in the
# process of adjusting to a new surface normal.
func get_facing_direction():
	var angle: float = $AnimatedSprite2D.global_rotation
	if is_finite(stand_angle):
		angle = stand_angle
	var facing: Vector2 = Vector2.from_angle(angle)
	# If segment is horizontally flipped, then flip sign of direction.
	if is_flipped():
		facing *= -1
	return facing

# Get normal to any surface that's contacted.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var n = state.get_contact_count()
	if n > 0:
		# Sum up all contact normals.
		# Should make it less jittery when transitioning from one surface to another?
		var v: Vector2 = Vector2.ZERO
		for i in range(n):
			v  += state.get_contact_local_normal(i)
		stand_angle = v.angle() + PI/2
		gravity_point = global_position - state.get_contact_local_normal(0)*100
		last_stand = Time.get_ticks_msec()
	# Disabled this code, because it was causing the head to "nod" forward too
	# much when going over a hill.
	#elif Time.get_ticks_msec() - last_stand > 100:
	#	stand_angle = NAN

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var gp: Vector2 = gravity_point
	# Apply a torque to align the body segment with a surface.
	# If not on a surface, point it toward segment in front.
	var target_angle: float = $AnimatedSprite2D.global_rotation
	if is_finite(stand_angle):
		target_angle = stand_angle
	elif front_segment != null:
		# Old code that used same angle as front segment.
		# Caused weird shear force effect.  Keeping here for reference of how
		# to access a child of another object.
		#target_angle = front_segment.get_node("AnimatedSprite2D").global_rotation
		# New code that points toward segment in front.
		var target_vector: Vector2 = front_segment.global_position - global_position
		# If segment is flipped, then flip sign of vector.
		if is_flipped(): target_vector *= -1
		target_angle = target_vector.angle()
	var angle_diff: float = target_angle - $AnimatedSprite2D.global_rotation
	while angle_diff < -PI: angle_diff += 2*PI
	while angle_diff > PI: angle_diff -= 2*PI
	if abs(angle_diff) / delta <= 10.0:
		$AnimatedSprite2D.global_rotation = target_angle
	else:
		$AnimatedSprite2D.global_rotation += 10.0 * delta * sign(angle_diff)
	# The following actions are contingent on have a segment in front.
	if front_segment != null:
		var to_other: Vector2 = front_segment.global_position - global_position
		# Flip direction if segment ahead has turned around and moved past this one.
		if to_other.dot(get_facing_direction()) < 0:
			flip_segment()
		# Apply a force to bring the segment to the correct distance to the front neighbour.
		var distance: float = to_other.length()
		if distance > segment_spacing:
			linear_velocity = (distance - segment_spacing) * to_other.normalized() * 10
	# Check if moving, need to animate legs?
	if linear_velocity.length() > 10:
		$AnimatedSprite2D.play()
	else:
		$AnimatedSprite2D.pause()
	# Check for user-driven movement, if this is the front (leader) segment.
	if front_segment == null:
		if Input.is_action_pressed("move_right") and is_finite(stand_angle):
			# Lead the gravity point in the direction of travel.
			# Motion will be from an effect of this force.
			gp += (gravity_point - global_position).rotated(-PI/2).normalized() * 50
			# Check if the sprites need to be flipped around.
			# Check if the sprites need to be flipped around.
			if current_direction == "left":
				flip_segment()
		elif Input.is_action_pressed("move_left") and is_finite(stand_angle):
			# Lead the gravity point in the direction of travel.
			# Motion will be from an effect of this force.
			gp -= (gravity_point - global_position).rotated(-PI/2).normalized() * 50
			# Check if the sprites need to be flipped around.
			if current_direction == "right":
				flip_segment()
		# If on a surface, but no key pressed, hit the brakes on movement.
		elif is_finite(stand_angle) and linear_velocity.length() > 10:
			gp -= linear_velocity.normalized()*100
	# Apply the force to keep stuck to a surface / move in a direction.
	apply_central_force((gp-global_position).normalized()*200)
	# Visual aid for centre of force, for debugging.
	$GravityPoint.global_position = gp
