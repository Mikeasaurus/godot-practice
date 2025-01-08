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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
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

"""
# The following code controls force of movement for the segments.
func _physics_process(delta: float) -> void:


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
