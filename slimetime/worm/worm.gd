extends Node2D

## Signal emitted when a bug has been eaten.  Allows things like score to be updated in parent scene.
signal ate_bug
## Signal emitted when damage is taken.  Parent scene could use this to update a health bar, or end the game.
signal hurt

# Array to hold individual worm segments.
var segments: Array[WormSegment] = []
# How far apart the segments should be.
var segment_spacing: float = 30.0

@export var worm_segment_scene: PackedScene

# For capturing jump events from _input, and handling them in _physics_process
var _jump_triggered: bool = false

# Remember movement key state, to maintain forward momentum when going around
# corners.  E.g., if holding down right arrow key to move right, and worm then
# turns a corner and up a wall, keep moving even though the proper key would now
# be the "up" arrow.
var _key_held: bool = false

# For capturing double-clicks / double-taps when the built-in detection fails.
# For instance, playing from iOS via the html5 interface doesn't seem to trigger
# either double_click or double_tap events!  Very annoying.
var _recent_click: bool = false

# Whether worm is alive or not.
var _alive: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Organize the segments into an ordered array.
	# Note: When I tried to set this from within the declaration of "segments", the
	# elements were all null.  Have to wait until runtime for these references to exist?
	segments.append_array([$WormFront, $WormSegment3, $WormSegment2, $WormSegment1, $WormTail])
	# Listen for damage taken by any of the segments.
	for segment in segments:
		segment.hurt.connect(_on_hurt)

func _input(event: InputEvent) -> void:
	if not _alive: return
	# Mouse / touch event
	if event is InputEventMouseButton and event.pressed:
		# This is a fallback for when automatic detection of double-click / double-tap fails.
		if Globals.touchscreen_controls and _recent_click:
			_jump_triggered = true
			return
		elif Globals.touchscreen_controls:
			_recent_click = true
			$DoubletapTimer.start()
		# For shooting slime, pass the general direction for shooting the slime.
		segments[0].shoot_slime(get_global_mouse_position())
	# Debug action... grow the worm on command.
	if Globals.debug_keys and event is InputEventKey and event.is_action_pressed("grow"):
		# Add a new segment, just behind the front segment.
		var segment: WormSegment = worm_segment_scene.instantiate()
		add_child(segment)
		segment.global_position = (segments[0].global_position + segments[1].global_position) / 2
		segments.insert(1,segment)
	# Capture jump from user input, wait for _physics_process to handle the details.
	# Double-click detection is only available from an InputEvent (not Input), so
	# this can't be detected directly in _physics_process.
	#TODO: remove this, since the manual detection (using timer) is already working.
	if Globals.touchscreen_controls:
		if (event is InputEventScreenTouch and event.double_tap) \
		  or (event is InputEventMouseButton and event.double_click):
			_jump_triggered = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if not _alive: return
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
			# Also, don't update zorder of tail (does not need to ever be in front of any other segments).
			if front_segment.facing_direction.dot(v) > 0 and i < len(segments)-1:
				segment.z_index = front_segment.z_index

	# Update segment sprites.
	for s in segments:
		s.update_sprite()

# The following code controls force of movement for the segments.
func _physics_process(delta: float) -> void:
	if not _alive:
		# Only apply gravity force if not alive.
		for s in segments:
			s.apply_central_force(Vector2(0,1)*Globals.gravity)
		return
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
			segment.set_relative_velocity_in_direction(to_other, vel)

		# If close enough to front segment, then turn off any further velocity
		# in that particular direction.
		if distance <= segment_spacing * 0.9:
			segment.set_relative_velocity_in_direction(to_other, 0.0)

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
			s1.set_relative_velocity_in_direction(x3b-x1b,0)

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
			s.set_relative_velocity_in_direction(s.global_position-s.last_surface_reference,0.0)

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
	# Quick hack for maintaining movement so long as a movement key is held down.
	if move_direction == Vector2.ZERO:
		_key_held = false
	elif _key_held:
		move_direction = segments[0].facing_direction
	# Check for mouse / touchscreen input as well.
	if Globals.touchscreen_controls and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var click_pos: Vector2 = get_global_mouse_position()
		var worm_pos: Vector2 = segments[0].global_position
		move_direction = (click_pos - worm_pos)
	# Movement only applies to front segment (other segments follow passively)
	var head: WormSegment = segments[0]
	# Check if there's any user-driven movement, and if it's not orthogonal
	# to surface.
	if move_direction != Vector2.ZERO:
		var cos_angle: float = move_direction.normalized().dot(head.facing_direction)
		if abs(cos_angle) >= 0.5 and head.on_surface:
			# If moving, and not on touchscreen, then must be holding down a movement key?
			if not Globals.touchscreen_controls:
				_key_held = true
			# If going in opposite direction to before, need to invert direction that we're facing.
			if move_direction.dot(head.facing_direction) < 0:
				head.facing_direction *= -1
			# If less than top speed, then add a little oomf.
			if head.relative_linear_velocity.dot(head.facing_direction.normalized()) < 400:
				gd[0] += head.facing_direction.normalized()*5
			else:
				gd[0] += head.facing_direction.normalized()
	# If no user-driven movement, then hit the brakes on momentum so the worm
	# doesn't keep gliding forward.
	else:
		for i in range(len(segments)):
			if segments[i].on_surface:
				# Add a little oomf to brakes if going fast.
				if head.relative_linear_velocity.dot(head.facing_direction.normalized()) > 100:
					gd[i] -= (segments[i].relative_linear_velocity).normalized()*5
				# Otherwise, use normal braking force to avoid glitching out with too much counterforce.
				else:
					gd[i] -= (segments[i].relative_linear_velocity).normalized()

	# Do a jump
	# Even though this is an "event" and may be more appropriately handled in _input,
	# I'm handling it here because this will interact with the worm's physics, and
	# I want those modifications to be done as synchronously as possible (all within _physics_process)
	# so there's no contention of forces/reactions or unexpected behaviour.
	if Input.is_action_just_pressed("jump") or _jump_triggered:
		_jump_triggered = false  # _jump_triggered is a flag to capture double-clicks from _input.
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
		segments[i].apply_central_force(gd[i]*Globals.gravity)
		# Visual aid for centre of force, for debugging.
		segments[i].get_node("GravityPoint").global_position = segments[i].global_position + gd[i]


# Explode the worm.
# (WHY???)
func explode () -> void:
	# Turn off all activity for the worm (slime shooting, walking, jumping, etc.)
	_alive = false
	# Detach the segments from any surface and add a random impulse to each segment.
	for s in segments:
		s.release_from_surface()
		s.apply_central_impulse(Vector2((randf()-0.5)*1000,(randf()-0.5)*1000))

# Pass along signal when a bug is eaten.
func _on_worm_front_ate_bug() -> void:
	ate_bug.emit()

# When user hasn't clicked/tapped in very recent past, then no longer waiting to
# detect a double-click / double-tap event.
func _on_doubletap_timer_timeout() -> void:
	_recent_click = false

# This is called when a worm segment sends a signal saying it took damage.
func _on_hurt() -> void:
	hurt.emit()
